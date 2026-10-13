use std::process::Command;

#[derive(Debug, Default, PartialEq, Eq)]
struct Request {
    kind: String,
    session: String,
    window: String,
    pane: String,
    text: String,
    reason: String,
    id: String,
    expected: Option<String>,
    reads_stdin: bool,
    mode: String,
    keys: Vec<String>,
}

fn proposal_with_environment(
    entry: &str,
    mut args: &[&str],
    stdin: &str,
    origin_session: &str,
    environment: &[(&str, &str)],
) -> Request {
    let refuse = |reason: &str| Request {
        kind: "refuse".into(),
        reason: reason.into(),
        ..Request::default()
    };
    let normalize = |message: &str| {
        message
            .split(|c: char| c.is_whitespace() || matches!(c, '\u{1c}'..='\u{1f}'))
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join(" ")
    };
    if matches!(args, ["-h"] | ["--help"]) || (entry == "relay" && args.is_empty()) {
        return Request {
            kind: "help".into(),
            ..Request::default()
        };
    }
    let operator = matches!(args.first(), Some(&"--operator" | &"-O"));
    if operator {
        args = &args[1..];
    }
    let mut literal = args.first() == Some(&"--");
    if literal {
        args = &args[1..];
    }
    if entry == "relay" && !literal && args.first() == Some(&"status") {
        return match args {
            ["status"] => Request {
                kind: "status".into(),
                ..Request::default()
            },
            ["status", id] => Request {
                kind: "status".into(),
                id: (*id).into(),
                ..Request::default()
            },
            _ => refuse("status-arity"),
        };
    }
    let prefix = match entry {
        "cc-msg" => "CC_MSG",
        "agy-send-to" => "AGY_SEND",
        _ => "CODEX_SEND",
    };
    let env = |suffix: &str| {
        environment
            .iter()
            .find(|(key, _)| *key == format!("{prefix}_{suffix}"))
            .map(|(_, value)| *value)
            .filter(|value| !value.is_empty())
    };
    let default_window = match entry {
        "cc-msg" => "claude",
        "agy-send-to" => "agy",
        _ => "codex",
    };
    let mut request = Request {
        session: env("SESSION").unwrap_or(origin_session).into(),
        window: env("WINDOW").unwrap_or(default_window).into(),
        pane: env("PANE").unwrap_or("").into(),
        mode: if operator {
            "operator".into()
        } else {
            String::new()
        },
        ..Request::default()
    };
    if matches!(entry, "relay" | "codex-send-to" | "agy-send-to") {
        let Some(target) = args.first() else {
            return refuse("missing-target");
        };
        if entry == "relay" {
            let Some((session, window)) = target.rsplit_once(':') else {
                return refuse("invalid-route");
            };
            if session.is_empty() || window.is_empty() {
                return refuse("invalid-route");
            }
            request.session = session.into();
            request.window = window.into();
        } else {
            request.window = (*target).into();
        }
        args = &args[1..];
    }
    if request.session.is_empty() {
        return refuse("missing-session");
    }
    if !literal && request.mode.is_empty() && matches!(args.first(), Some(&"--operator" | &"-O")) {
        request.mode = "operator".into();
        args = &args[1..];
    }
    if !literal && args.first() == Some(&"--") {
        literal = true;
        args = &args[1..];
    }
    if !literal && args.first() == Some(&"--clear-draft") {
        request.kind = "clear".into();
        return match args {
            ["--clear-draft"] => request,
            ["--clear-draft", "--expect", expected] => {
                request.expected = Some((*expected).into());
                request
            }
            _ => refuse("incomplete-clear"),
        };
    }
    if !literal && args.first() == Some(&"--keys") {
        if args.len() == 1 {
            return refuse("missing-keys");
        }
        request.kind = "keys".into();
        request.keys = args[1..].iter().map(|v| (*v).into()).collect();
        return request;
    }
    if args.is_empty() {
        if matches!(entry, "codex-send-to" | "agy-send-to") {
            return refuse("missing-message");
        }
        request.reads_stdin = true;
        request.text = normalize(stdin);
    } else {
        request.text = normalize(&args.join(" "));
    }
    if request.text.is_empty() {
        let mut failure = refuse("empty-message");
        failure.reads_stdin = request.reads_stdin;
        return failure;
    }
    request.kind = if request.mode == "operator" && request.text.starts_with(['/', '!']) {
        "tui-command"
    } else {
        "task"
    }
    .into();
    request
}

fn proposal(entry: &str, args: &[&str], stdin: &str) -> Request {
    proposal_with_environment(entry, args, stdin, "source", &[])
}

#[test]
fn candidate_environment_role_precedence() {
    for (entry, args, origin, environment, expected) in [
        (
            "cc-msg",
            vec!["text"],
            "origin",
            vec![
                ("CC_MSG_SESSION", "s"),
                ("CC_MSG_WINDOW", "w"),
                ("CC_MSG_PANE", "%9"),
            ],
            ("task", "s", "w", "%9"),
        ),
        (
            "codex-send",
            vec!["text"],
            "origin",
            vec![
                ("CODEX_SEND_SESSION", "s"),
                ("CODEX_SEND_WINDOW", "w"),
                ("CODEX_SEND_PANE", "%9"),
            ],
            ("task", "s", "w", "%9"),
        ),
        (
            "codex-send-to",
            vec!["explicit", "text"],
            "origin",
            vec![
                ("CODEX_SEND_SESSION", "s"),
                ("CODEX_SEND_WINDOW", "ignored"),
                ("CODEX_SEND_PANE", "%9"),
            ],
            ("task", "s", "explicit", "%9"),
        ),
        (
            "agy-send-to",
            vec!["explicit", "text"],
            "origin",
            vec![
                ("AGY_SEND_SESSION", "s"),
                ("AGY_SEND_WINDOW", "ignored"),
                ("AGY_SEND_PANE", "%9"),
            ],
            ("task", "s", "explicit", "%9"),
        ),
        (
            "relay",
            vec!["destination:seat", "text"],
            "origin",
            vec![
                ("CODEX_SEND_SESSION", "ignored"),
                ("CODEX_SEND_WINDOW", "ignored"),
                ("CODEX_SEND_PANE", "%9"),
            ],
            ("task", "destination", "seat", "%9"),
        ),
        (
            "cc-msg",
            vec!["text"],
            "origin",
            vec![
                ("CC_MSG_SESSION", ""),
                ("CC_MSG_WINDOW", ""),
                ("CC_MSG_PANE", ""),
            ],
            ("task", "origin", "claude", ""),
        ),
        (
            "cc-msg",
            vec!["text"],
            "origin",
            vec![
                ("CODEX_SEND_SESSION", "other"),
                ("AGY_SEND_WINDOW", "other"),
            ],
            ("task", "origin", "claude", ""),
        ),
        (
            "cc-msg",
            vec!["text"],
            "",
            vec![("CC_MSG_SESSION", "s")],
            ("task", "s", "claude", ""),
        ),
        (
            "relay",
            vec!["destination:seat", "text"],
            "",
            vec![],
            ("task", "destination", "seat", ""),
        ),
    ] {
        let got = proposal_with_environment(entry, &args, "", origin, &environment);
        assert_eq!(
            (
                got.kind.as_str(),
                got.session.as_str(),
                got.window.as_str(),
                got.pane.as_str()
            ),
            expected,
            "{entry} {environment:?}"
        );
    }
    assert_eq!(
        proposal_with_environment("cc-msg", &["text"], "", "", &[]).reason,
        "missing-session"
    );
    assert_eq!(
        proposal_with_environment("cc-msg", &["--help"], "", "", &[]).kind,
        "help"
    );
}

#[test]
fn candidate_python_whitespace_normalization_keeps_expected_text_exact() {
    for separator in [
        '\u{1c}', '\u{1d}', '\u{1e}', '\u{1f}', '\u{a0}', '\u{2029}', '\n',
    ] {
        let text = format!("a{separator}b");
        assert_eq!(proposal("cc-msg", &[&text], "").text, "a b");
        assert_eq!(proposal("cc-msg", &[], &text).text, "a b");
        assert_eq!(
            proposal("cc-msg", &["--clear-draft", "--expect", &text], "")
                .expected
                .as_deref(),
            Some(text.as_str())
        );
    }
}

#[test]
#[ignore = "test-only I03b proposal oracle; requires ANGELSTAR_ARGV_CASES and jq"]
fn candidate_argv_cases() {
    let path = std::env::var("ANGELSTAR_ARGV_CASES").unwrap();
    let query = ".cases[] | [.entry, (.argv|length), (.argv[]), (.stdin//\"\"), .expect.kind, (.expect.session//\"\"), (.expect.window//\"\"), (.expect.text//\"\"), (.expect.reason//\"\"), (.expect.id//\"\"), (.expect.expected_text//\"\"), (.expect.expected_text != null), (.expect.reads_stdin//false), (.expect.mode//\"\"), ((.expect.keys//[])|length), ((.expect.keys//[])[])] | .[] | tostring, \"\\u0000\"";
    let output = Command::new("jq")
        .args(["-j", query, &path])
        .output()
        .unwrap();
    assert!(output.status.success());
    let fields: Vec<&str> = std::str::from_utf8(&output.stdout)
        .unwrap()
        .split_terminator('\0')
        .collect();
    let mut at = 0;
    let mut count = 0;
    let mut mismatches = Vec::new();
    while at < fields.len() {
        let entry = fields[at];
        let length: usize = fields[at + 1].parse().unwrap();
        let args = &fields[at + 2..at + 2 + length];
        at += 2 + length;
        let keys_length: usize = fields[at + 11].parse().unwrap();
        let expected = Request {
            kind: fields[at + 1].into(),
            session: fields[at + 2].into(),
            window: fields[at + 3].into(),
            pane: String::new(),
            text: fields[at + 4].into(),
            reason: fields[at + 5].into(),
            id: fields[at + 6].into(),
            expected: (fields[at + 8] == "true").then(|| fields[at + 7].into()),
            reads_stdin: fields[at + 9] == "true",
            mode: fields[at + 10].into(),
            keys: fields[at + 12..at + 12 + keys_length]
                .iter()
                .map(|v| (*v).into())
                .collect(),
        };
        let got = proposal(entry, args, fields[at]);
        if got != expected {
            mismatches.push(format!(
                "{entry} {args:?}: got {got:?}, expected {expected:?}"
            ));
        }
        at += 12 + keys_length;
        count += 1;
    }
    assert_eq!(count, 44);
    assert!(
        mismatches.is_empty(),
        "{} /{count} mismatches:\n{}",
        mismatches.len(),
        mismatches.join("\n")
    );
}
