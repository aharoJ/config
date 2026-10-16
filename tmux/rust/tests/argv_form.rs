use std::collections::BTreeMap;
use std::path::Path;
use syn::parse::Parser;
use syn::visit::{self, Visit};
use syn::{Expr, Lit, Pat};

type Words = Vec<Option<String>>;

fn literal(expr: &Expr) -> Option<String> {
    match expr {
        Expr::Lit(value) => match &value.lit {
            Lit::Str(text) => Some(text.value()),
            _ => None,
        },
        Expr::Reference(value) => literal(&value.expr),
        Expr::Paren(value) => literal(&value.expr),
        Expr::MethodCall(value)
            if ["into", "to_owned", "to_string", "as_str"]
                .iter()
                .any(|name| value.method == *name) =>
        {
            literal(&value.receiver)
        }
        _ => None,
    }
}

fn words(expr: &Expr, bindings: &BTreeMap<String, Words>) -> Option<Words> {
    match expr {
        Expr::Array(array) => Some(array.elems.iter().map(literal).collect()),
        Expr::Reference(value) => words(&value.expr, bindings),
        Expr::Paren(value) => words(&value.expr, bindings),
        Expr::Path(value) => bindings.get(&value.path.get_ident()?.to_string()).cloned(),
        Expr::MethodCall(value) => words(&value.receiver, bindings),
        Expr::Macro(value) if value.mac.path.is_ident("vec") => {
            let expressions = syn::punctuated::Punctuated::<Expr, syn::Token![,]>::parse_terminated
                .parse2(value.mac.tokens.clone())
                .ok()?;
            Some(expressions.iter().map(literal).collect())
        }
        _ => None,
    }
}

#[derive(Default)]
struct Audit {
    bindings: BTreeMap<String, Words>,
    failures: Vec<String>,
    launches: usize,
}

impl Audit {
    fn invocation(&mut self, args: Words) {
        for (offset, arg) in args.iter().enumerate() {
            let Some(command) = arg.as_deref() else {
                continue;
            };
            if command == "run-shell"
                || (command == "if-shell"
                    && args.get(offset + 1).and_then(Option::as_deref) != Some("-F"))
            {
                self.failures.push(format!("{command} may execute a shell"));
            }
            if ![
                "new-session",
                "new-window",
                "split-window",
                "respawn-pane",
                "respawn-window",
            ]
            .contains(&command)
            {
                continue;
            }
            self.launches += 1;
            let tail = &args[offset + 1..];
            let tail = &tail[..tail
                .iter()
                .position(|a| a.as_deref() == Some(";"))
                .unwrap_or(tail.len())];
            if tail
                .iter()
                .position(|a| a.as_deref() == Some("--"))
                .is_none_or(|separator| tail.len() - separator - 1 < 2)
            {
                self.failures
                    .push(format!("{command} lacks explicit program argv"));
            }
        }
    }
}

impl<'ast> Visit<'ast> for Audit {
    fn visit_item_fn(&mut self, function: &'ast syn::ItemFn) {
        let outer = std::mem::take(&mut self.bindings);
        visit::visit_item_fn(self, function);
        self.bindings = outer;
    }

    fn visit_impl_item_fn(&mut self, function: &'ast syn::ImplItemFn) {
        let outer = std::mem::take(&mut self.bindings);
        visit::visit_impl_item_fn(self, function);
        self.bindings = outer;
    }

    fn visit_local(&mut self, local: &'ast syn::Local) {
        if let (Pat::Ident(name), Some(init)) = (&local.pat, &local.init) {
            if let Some(args) = words(&init.expr, &self.bindings) {
                self.bindings.insert(name.ident.to_string(), args);
            }
        }
        visit::visit_local(self, local);
    }

    fn visit_expr_method_call(&mut self, call: &'ast syn::ExprMethodCall) {
        if let Some(arg) = call.args.first() {
            if call.method == "extend" {
                if let (Expr::Path(receiver), Some(args)) =
                    (call.receiver.as_ref(), words(arg, &self.bindings))
                {
                    if let Some(binding) = receiver
                        .path
                        .get_ident()
                        .and_then(|name| self.bindings.get_mut(&name.to_string()))
                    {
                        binding.extend(args);
                    }
                }
            } else if call.method != "arg" {
                if let Some(args) = words(arg, &self.bindings) {
                    self.invocation(args);
                }
            } else if call.method == "arg"
                && literal(arg).is_some_and(|arg| {
                    [
                        "new-session",
                        "new-window",
                        "split-window",
                        "respawn-pane",
                        "respawn-window",
                    ]
                    .contains(&arg.as_str())
                })
            {
                self.failures
                    .push("program launch must use an argv list".into());
            }
        }
        visit::visit_expr_method_call(self, call);
    }

    fn visit_expr_call(&mut self, call: &'ast syn::ExprCall) {
        for arg in &call.args {
            if let Some(args) = words(arg, &self.bindings) {
                self.invocation(args);
            }
        }
        visit::visit_expr_call(self, call);
    }

    fn visit_macro(&mut self, value: &'ast syn::Macro) {
        if value.path.is_ident("format") {
            if let Ok(arguments) =
                syn::punctuated::Punctuated::<Expr, syn::Token![,]>::parse_terminated
                    .parse2(value.tokens.clone())
            {
                if let Some(text) = arguments.first().and_then(literal) {
                    let mut args = text.split_whitespace();
                    match (args.next(), args.next()) {
                        (Some("run-shell"), _) | (Some("if-shell"), Some(_))
                            if !text.starts_with("if-shell -F ") =>
                        {
                            self.failures.push("formatted shell execution".into());
                        }
                        _ => (),
                    }
                }
            }
        }
        visit::visit_macro(self, value);
    }
}

fn audit(source: &str) -> Audit {
    let mut audit = Audit::default();
    audit.visit_file(&syn::parse_file(source).unwrap());
    audit
}

fn sources(path: &Path, failures: &mut Vec<String>, launches: &mut usize) {
    for entry in std::fs::read_dir(path).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            sources(&path, failures, launches);
        } else if path.extension().is_some_and(|extension| extension == "rs") {
            let audit = audit(&std::fs::read_to_string(&path).unwrap());
            *launches += audit.launches;
            failures.extend(
                audit
                    .failures
                    .into_iter()
                    .map(|failure| format!("{}: {failure}", path.display())),
            );
        }
    }
}

#[test]
fn crate_tmux_program_launches_are_argv_lists() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let mut failures = Vec::new();
    let mut launches = 0;
    for folder in ["src", "tests", "examples"] {
        sources(&root.join(folder), &mut failures, &mut launches);
    }
    assert!(launches >= 5, "launch inventory was not traversed");
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

#[test]
fn launch_audit_rejects_direct_and_built_command_strings() {
    for source in [
        r#"fn sample() { tmux(&["new-session", "-d", "/bin/sleep 120"]); }"#,
        r#"fn sample() { command.args(["new-window", "--", "exec fixture --ignored"]); }"#,
        r#"fn sample() { let mut argv = vec!["new-window".into(), "-d".into()]; argv.extend(["--".into(), command]); tmux(&argv.iter().map(String::as_str).collect::<Vec<_>>()); }"#,
        r#"fn sample() { tmux(&["if-shell", "true", "send-keys Enter"]); }"#,
        r#"fn sample() { command.args(["run-shell", "--", "/bin/sleep", "120"]); }"#,
        r#"fn sample() { let command = format!("if-shell true send-keys"); }"#,
    ] {
        assert!(!audit(source).failures.is_empty(), "{source}");
    }
    assert!(audit(
        r#"fn sample() { tmux(&["new-session", "--", "/path/with spaces/fixture", "hold"]); }"#
    )
    .failures
    .is_empty());
}
