//! Ratified I03b: one argv parser and durable outcome mapping for all launchers.
use crate::{
    identity as target, runtime,
    store::{self, State},
};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

pub const HELP: &str = "usage: relay <session>:<window> [--] <message...>\n       relay status <attempt-id>\n       relay read <archive-id> [original|wire]\n       cc-msg [--] <message...>\n       codex-send [--] <message...>\n       codex-send-to <window> [--] <message...>\nRequires explicit role routing and ANGELSTAR_RELAY_STORE; sends require ANGELSTAR_RELAY_SOCKET and delivery authority. Missing message reads stdin for relay, cc-msg, codex-send. Prune/reuse/recover are deferred. Legacy operator/clear/keys modes refuse.\n";

#[derive(Debug, PartialEq, Eq)]
pub enum Operation {
    Help,
    Send {
        session: String,
        window: String,
        pane: Option<target::PaneId>,
        message: Option<String>,
    },
    Status(String),
    Read(String, bool),
}
type Env = HashMap<String, String>;
type Result<T> = std::result::Result<T, String>;
fn required(env: &Env, name: &str) -> Result<String> {
    env.get(name)
        .filter(|v| !v.is_empty())
        .cloned()
        .ok_or_else(|| format!("{name} is required"))
}
fn id(s: &str) -> Result<String> {
    if s.len() != 32
        || !s
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err("ID must be exactly 32 lowercase hex characters".into());
    }
    Ok(s.into())
}

fn pane(env: &Env, key: &str) -> Result<Option<target::PaneId>> {
    env.get(key)
        .map(|v| {
            let n = v
                .strip_prefix('%')
                .filter(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
                .ok_or_else(|| "pane must be exact %decimal".to_string())?;
            n.parse::<u64>()
                .map(target::PaneId)
                .map_err(|_| "invalid pane".into())
        })
        .transpose()
}

pub fn parse(surface: &str, args: &[String], env: &Env) -> Result<Operation> {
    if !["relay", "cc-msg", "codex-send", "codex-send-to"].contains(&surface) {
        return Err("unknown entry point".into());
    }
    if args == ["--help"] || args == ["-h"] || (surface == "relay" && args.is_empty()) {
        return Ok(Operation::Help);
    }
    if surface == "relay"
        && args
            .first()
            .is_some_and(|s| ["status", "read", "prune", "recover"].contains(&s.as_str()))
    {
        let verb = args[0].as_str();
        if matches!(verb, "prune" | "recover") {
            return Err("operation deferred; retained archive remains readable; no input".into());
        }
        if args.len() < 2 || args.len() > if verb == "read" { 3 } else { 2 } {
            return Err("invalid administrative arity".into());
        }
        let exact = id(&args[1])?;
        return Ok(match verb {
            "status" => Operation::Status(exact),
            _ => Operation::Read(
                exact,
                match args.get(2).map(String::as_str) {
                    None | Some("original") => false,
                    Some("wire") => true,
                    _ => return Err("read kind must be original or wire".into()),
                },
            ),
        });
    }
    let (session, window, selected, start) = match surface {
        "relay" => {
            let route = args.first().ok_or("missing route")?;
            if route.starts_with('-') {
                return Err("unsupported option".into());
            }
            let (s, w) =
                target::split_route(route).map_err(|_| "route must be exact session:window")?;
            (s.to_owned(), w.to_owned(), None, 1)
        }
        "cc-msg" => (
            required(env, "CC_MSG_SESSION")?,
            required(env, "CC_MSG_WINDOW")?,
            pane(env, "CC_MSG_PANE")?,
            0,
        ),
        "codex-send" => (
            required(env, "CODEX_SEND_SESSION")?,
            match env.get("CODEX_SEND_WINDOW") {
                Some(v) if v.is_empty() => return Err("empty CODEX_SEND_WINDOW".into()),
                Some(v) => v.clone(),
                None => "codex".into(),
            },
            pane(env, "CODEX_SEND_PANE")?,
            0,
        ),
        _ => {
            let w = args
                .first()
                .filter(|s| !s.is_empty() && !s.starts_with('-'))
                .ok_or("missing exact window")?;
            (
                required(env, "CODEX_SEND_SESSION")?,
                w.clone(),
                pane(env, "CODEX_SEND_PANE")?,
                1,
            )
        }
    };
    let tail = &args[start..];
    let literal = tail.first().is_some_and(|s| s == "--");
    let words = if literal { &tail[1..] } else { tail };
    if !literal && words.first().is_some_and(|s| s.starts_with('-')) {
        return Err("unsupported message option; use -- for literal text".into());
    }
    if surface == "codex-send-to" && words.is_empty() {
        return Err("codex-send-to requires argv message".into());
    }
    Ok(Operation::Send {
        session,
        window,
        pane: selected,
        message: (!words.is_empty()).then(|| words.join(" ")),
    })
}

pub fn outcome(state: State) -> i32 {
    match state {
        State::Submitted => 0,
        State::TerminalNoInput => 1,
        State::PendingNoInput => 6,
        _ => 4,
    }
}
static INTERRUPTED: AtomicBool = AtomicBool::new(false);
extern "C" fn interrupt(_: libc::c_int) {
    INTERRUPTED.store(true, Ordering::Relaxed);
}
fn wait_ms(env: &Env) -> Result<u64> {
    let ms = match env.get("ANGELSTAR_RELAY_WAIT_MS") {
        None => 30000,
        Some(s) if !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()) => {
            s.parse().map_err(|_| "invalid wait budget")?
        }
        _ => return Err("invalid wait budget".into()),
    };
    if ms == 0 || ms > 3600000 {
        return Err("wait budget must be 1..3600000 ms".into());
    }
    Ok(ms)
}
fn announcement(
    store: &mut store::Store,
    id: &str,
    out: &mut dyn Write,
    err: &mut dyn Write,
    status: bool,
) -> i32 {
    let a = match store.attempt(id) {
        Ok(a) => a,
        Err(e) => {
            let _ = writeln!(
                err,
                "relay: attempt {id}: {e:?}; do not infer retry authority"
            );
            return if status { 1 } else { 4 };
        }
    };
    let state = a.state();
    let result = serde_json::json!({"attempt":a.id,"archive":a.archive,"state":state,"peer":a.peer,"submission":if matches!(state,State::Submitted){"proved"}else{"unproved"},"receipt":"unproved"});
    if writeln!(out, "{result}").is_err() {
        let _ = writeln!(
            err,
            "relay: announcement failed; committed attempt {id} remains {state:?}"
        );
        if status {
            return 1;
        }
    }
    for t in &a.history {
        for d in &t.evidence.diagnostics {
            let _ = writeln!(err, "relay: {d}");
        }
    }
    if status {
        0
    } else {
        outcome(state)
    }
}
fn execute(
    op: Operation,
    env: &Env,
    input: &mut dyn Read,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> i32 {
    if op == Operation::Help {
        return if write!(out, "{HELP}").is_ok() { 0 } else { 1 };
    }
    let request: Result<i32> = (|| {
        let op = match op {
            Operation::Send {
                session,
                window,
                pane,
                message,
            } => {
                let original = match message {
                    Some(m) => m,
                    None => {
                        let mut m = String::new();
                        input.read_to_string(&mut m).map_err(|e| e.to_string())?;
                        m
                    }
                };
                runtime::normalize(&original)?;
                Operation::Send {
                    session,
                    window,
                    pane,
                    message: Some(original),
                }
            }
            op => op,
        };
        let milliseconds = if matches!(op, Operation::Send { .. }) {
            wait_ms(env)?
        } else {
            0
        };
        let path = PathBuf::from(required(env, "ANGELSTAR_RELAY_STORE")?);
        let mut store = store::Store::open(&path).map_err(|e| format!("store: {e:?}"))?;
        match op {
            Operation::Status(id) => Ok(announcement(&mut store, &id, out, err, true)),
            Operation::Read(id, wire) => {
                let bytes = store.read(&id, wire).map_err(|e| format!("read: {e:?}"))?;
                out.write_all(&bytes).map_err(|e| e.to_string())?;
                Ok(0)
            }
            Operation::Send {
                session,
                window,
                pane,
                message,
            } => {
                let original = message.ok_or("message missing")?;
                let ns = target::connect_delivery(&PathBuf::from(required(
                    env,
                    "ANGELSTAR_RELAY_SOCKET",
                )?))?;
                let prepared = runtime::Prepared::new(&ns, &session, &window, pane, &original)?;
                let budgets = store::Budgets {
                    stop_ms: 30,
                    drain_ms: 30,
                    reap_ms: 30,
                    decision_ms: 90,
                };
                let mut runtime = runtime::Runtime::accept(
                    &ns,
                    prepared,
                    &mut store,
                    original.as_bytes(),
                    budgets,
                )?;
                let id = runtime.ids().0.to_owned();
                let deadline = Instant::now() + Duration::from_millis(milliseconds);
                while !INTERRUPTED.load(Ordering::Relaxed) && Instant::now() < deadline {
                    match runtime.tick() {
                        Ok(
                            State::PendingNoInput | State::WaitingForFocusRelease | State::Pasted,
                        ) => std::thread::sleep(Duration::from_millis(10)),
                        Ok(_) => break,
                        Err(e) => {
                            let _ = writeln!(err, "relay: {e}; attempt {id}");
                            break;
                        }
                    }
                }
                let closed = runtime.close();
                drop(runtime);
                if let Err(e) = closed {
                    let _ = writeln!(
                        err,
                        "relay: cleanup/durability unresolved: {e}; attempt {id}"
                    );
                    let _ = announcement(&mut store, &id, out, err, false);
                    return Ok(4);
                }
                Ok(announcement(&mut store, &id, out, err, false))
            }
            Operation::Help => unreachable!(),
        }
    })();
    match request {
        Ok(code) => code,
        Err(e) => {
            let _ = writeln!(err, "relay: {e}");
            1
        }
    }
}
pub fn main_entry(surface: &str, args: &[String]) -> i32 {
    INTERRUPTED.store(false, Ordering::Relaxed);
    unsafe {
        libc::signal(libc::SIGINT, interrupt as *const () as libc::sighandler_t);
        libc::signal(libc::SIGTERM, interrupt as *const () as libc::sighandler_t);
    }
    let env: Env = std::env::vars_os()
        .filter_map(|(k, v)| Some((k.into_string().ok()?, v.into_string().ok()?)))
        .collect();
    match parse(surface, args, &env) {
        Ok(op) => execute(
            op,
            &env,
            &mut std::io::stdin().lock(),
            &mut std::io::stdout().lock(),
            &mut std::io::stderr().lock(),
        ),
        Err(e) => {
            eprintln!("relay: {e}");
            1
        }
    }
}
#[cfg(test)]
#[path = "../tests/support/cli.rs"]
mod tests;
