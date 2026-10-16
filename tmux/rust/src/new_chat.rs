use crate::{composer, identity, new_guard as guard, runtime};
use sha2::{Digest, Sha256};
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::os::fd::AsRawFd;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;

#[derive(Debug)]
struct Failure(i32, String);
type Result<T> = std::result::Result<T, Failure>;
const REQUEST_TIMEOUT: Duration = Duration::from_secs(1);

fn fail(detail: impl Into<String>) -> Failure {
    Failure(
        1,
        format!(
            "REFUSE: {}; no target input was sent; safe to retry after the condition clears",
            detail.into()
        ),
    )
}
fn partial(detail: impl Into<String>) -> Failure {
    Failure(
        4,
        format!(
            "UNVERIFIED: delivery may be partial or unconfirmed: {}; do not resend automatically",
            detail.into()
        ),
    )
}
fn busy() -> Failure {
    Failure(5, "REFUSE: another relay is in progress; no target input was sent; safe to retry after the condition clears".into())
}
fn copy(pane: &str) -> Failure {
    Failure(2, format!("REFUSE: target {pane} is in copy mode; no target input was sent; safe to retry after the condition clears"))
}
fn draft(pane: &str, reason: &str) -> Failure {
    Failure(5, format!("REFUSE: target {pane} has {reason}; no target input was sent; safe to retry after the condition clears"))
}
fn tmux_error(error: String, changed: bool) -> Failure {
    if error.contains("outcome unproved") {
        Failure(3, "REFUSE: tmux server is unresponsive; delivery state is unknown; do not resend automatically".into())
    } else if changed {
        partial(error)
    } else {
        fail(error)
    }
}
fn pause(ms: u64) {
    std::thread::sleep(Duration::from_millis(ms));
}

fn valid_name(value: &str) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-'))
}

type Route = (PathBuf, String, String, Option<(String, String)>);

fn route(args: &[String]) -> Result<Route> {
    parse_route(
        args,
        std::env::var("TMUX").ok().as_deref(),
        std::env::var("CODEX_SEND_SESSION").ok().as_deref(),
    )
}

fn parse_route(args: &[String], tmux: Option<&str>, session: Option<&str>) -> Result<Route> {
    if args.len() != 1 && args.len() != 3 {
        return Err(Failure(
            1,
            "usage: codex-new-chat <window-name> [<model> <effort>]".into(),
        ));
    }
    let profile =
        if args.len() == 3 {
            Some(guard::profile(&args[1], &args[2]).ok_or_else(|| {
                fail(format!("unsupported model/effort: {} {}", args[1], args[2]))
            })?)
        } else {
            None
        };
    let tmux = tmux
        .filter(|v| !v.is_empty())
        .ok_or_else(|| fail("TMUX is not set"))?;
    let session = session.unwrap_or_default();
    if !valid_name(session) {
        return Err(fail("CODEX_SEND_SESSION is required and may contain only letters, digits, underscores, or hyphens"));
    }
    if !valid_name(&args[0]) {
        return Err(fail(
            "window name may contain only letters, digits, underscores, or hyphens",
        ));
    }
    let socket = tmux.rsplitn(3, ',').last().unwrap_or("");
    Ok((
        PathBuf::from(socket),
        session.to_owned(),
        args[0].clone(),
        profile,
    ))
}

struct Lock {
    _core: File,
    legacy: PathBuf,
    owner: String,
}
impl Lock {
    fn acquire(ns: &identity::Namespace, target: &identity::Target) -> Result<Self> {
        let generation = identity::kernel_process(target.pane.pid)
            .ok_or_else(|| fail("target process disappeared"))?
            .generation()
            .map_err(fail)?;
        let name = format!(
            "target-{}-{}-{generation}",
            ns.server().generation().map_err(fail)?,
            target.pane.id.0
        );
        let core =
            identity::open_at(ns.directory(), &name, libc::O_RDWR | libc::O_CREAT).map_err(fail)?;
        if unsafe { libc::flock(core.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0
            || core.metadata().map_err(|e| fail(e.to_string()))?.len() != 0
        {
            return Err(busy());
        }
        let meta = std::fs::metadata(ns.socket()).map_err(|e| fail(e.to_string()))?;
        let key = format!(
            "{:x}",
            Sha256::digest(
                format!("{}:{}:{}", meta.dev(), meta.ino(), target.selector()).as_bytes()
            )
        );
        let root = PathBuf::from(format!("/private/tmp/tmux-{}/relay-locks", unsafe {
            libc::geteuid()
        }));
        std::fs::DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(&root)
            .map_err(|e| fail(e.to_string()))?;
        let legacy = root.join(key);
        let owner = std::process::id().to_string();
        let temporary = root.join(format!(
            "newchat-{}-{}",
            owner,
            runtime::fresh_id().map_err(fail)?
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary)
            .map_err(|e| fail(e.to_string()))?;
        let result = (|| {
            writeln!(file, "{owner}").map_err(|e| fail(e.to_string()))?;
            for _ in 0..3 {
                match std::fs::hard_link(&temporary, &legacy) {
                    Ok(()) => {
                        return Ok(Self {
                            _core: core,
                            legacy: legacy.clone(),
                            owner: owner.clone(),
                        })
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                        let stale = std::fs::read_to_string(&legacy)
                            .ok()
                            .and_then(|s| s.trim().parse::<u32>().ok())
                            .is_some_and(|pid| pid > 0 && identity::kernel_process(pid).is_none());
                        if !stale {
                            return Err(busy());
                        }
                        std::fs::remove_file(&legacy).map_err(|_| busy())?;
                    }
                    Err(e) => return Err(fail(e.to_string())),
                }
            }
            Err(busy())
        })();
        let _ = std::fs::remove_file(temporary);
        result
    }
}
impl Drop for Lock {
    fn drop(&mut self) {
        if std::fs::read_to_string(&self.legacy).is_ok_and(|pid| pid.trim() == self.owner) {
            let _ = std::fs::remove_file(&self.legacy);
        }
    }
}

const STATE: &str = "#{pane_in_mode}|#{pane_dead}|#{pane_pid}|#{pane_current_command}|#{pane_width}|#{pane_height}|#{session_name}|#{window_name}|#{cursor_x}|#{cursor_y}|#{pane_tty}|#{pane_current_path}";

#[derive(Clone, Debug, PartialEq, Eq)]
struct State {
    mode: bool,
    dead: bool,
    pid: u32,
    command: String,
    width: usize,
    height: usize,
    session: String,
    window: String,
    x: usize,
    y: usize,
    tty: PathBuf,
    cwd: String,
}
impl State {
    fn read(ns: &identity::Namespace, pane: &str, changed: bool) -> Result<Self> {
        let text = ns
            .command_for(
                &["display-message", "-p", "-t", pane, STATE],
                REQUEST_TIMEOUT,
            )
            .map_err(|e| tmux_error(e, changed))?;
        let values: Vec<_> = text.trim_end_matches('\n').splitn(12, '|').collect();
        let parse = || -> Option<Self> {
            if values.len() != 12
                || !["0", "1"].contains(&values[0])
                || !["0", "1"].contains(&values[1])
            {
                return None;
            }
            Some(Self {
                mode: values[0] == "1",
                dead: values[1] == "1",
                pid: values[2].parse().ok()?,
                command: values[3].into(),
                width: values[4].parse().ok()?,
                height: values[5].parse().ok()?,
                session: values[6].into(),
                window: values[7].into(),
                x: values[8].parse().ok()?,
                y: values[9].parse().ok()?,
                tty: values[10].into(),
                cwd: values[11].into(),
            })
        };
        parse().ok_or_else(|| {
            if changed {
                partial("cannot inspect target")
            } else {
                fail("cannot inspect target")
            }
        })
    }
    fn same_target(&self, other: &Self) -> bool {
        !other.dead
            && !other.mode
            && self.pid == other.pid
            && self.command == other.command
            && self.width == other.width
            && self.height == other.height
            && self.session == other.session
            && self.window == other.window
            && self.tty == other.tty
            && self.cwd == other.cwd
    }
}

fn foreground(client: &identity::Client, state: &State) -> identity::Result<()> {
    client.verify()?;
    if client.glyph != '›' {
        return Err("foreground process is not proven Codex".into());
    }
    let (device, group, foreground) = identity::kernel_terminal(client.process_identity().pid)
        .ok_or("Codex terminal unavailable")?;
    let (root_device, _, root_foreground) =
        identity::kernel_terminal(state.pid).ok_or("pane terminal unavailable")?;
    if group == 0 || group != foreground || foreground != root_foreground || device != root_device {
        return Err("Codex foreground process changed".into());
    }
    Ok(())
}

struct Chat {
    ns: identity::Namespace,
    pane: String,
    before: State,
    client: identity::Client,
    _lock: Lock,
    capture: String,
    footer: String,
    changed: bool,
}
impl Chat {
    fn open(socket: &Path, session: &str, window: &str) -> Result<Self> {
        let ns = identity::connect_delivery(socket).map_err(|e| tmux_error(e, false))?;
        let raw = ns
            .command_for(
                &["list-panes", "-a", "-F", identity::CAPTURE_FORMAT],
                REQUEST_TIMEOUT,
            )
            .map_err(|e| tmux_error(e, false))?;
        let snapshot = identity::Snapshot::parse(raw.as_bytes()).map_err(fail)?;
        let targets: Vec<_> = snapshot
            .targets
            .iter()
            .filter(|t| t.session_name == session && t.window.name == window)
            .collect();
        if targets.is_empty() {
            return Err(fail(format!("no target window {session}:{window}")));
        }
        if targets.len() != 1 {
            return Err(fail(format!(
                "target window {session}:{window} is ambiguous"
            )));
        }
        let target = targets[0];
        let pane = target.selector();
        let before = State::read(&ns, &pane, false)?;
        let lock = Lock::acquire(&ns, target)?;
        let client = identity::Client::bind(target.pane.pid).map_err(fail)?;
        foreground(&client, &before).map_err(fail)?;
        if before.dead
            || before.pid != target.pane.pid
            || before.session != session
            || before.window != window
        {
            return Err(fail("target identity changed or target pane is dead"));
        }
        if before.width <= 4 || before.height <= 6 {
            return Err(fail("target pane is too small to verify delivery"));
        }
        Ok(Self {
            ns,
            pane,
            before,
            client,
            _lock: lock,
            capture: String::new(),
            footer: String::new(),
            changed: false,
        })
    }
    fn observe(&mut self) -> Result<State> {
        foreground(&self.client, &self.before).map_err(|e| {
            if self.changed {
                partial(e)
            } else {
                fail(e)
            }
        })?;
        let state = State::read(&self.ns, &self.pane, self.changed)?;
        if state.mode && !self.changed {
            return Err(copy(&self.pane));
        }
        if !self.before.same_target(&state) {
            return Err(if self.changed {
                partial("target identity, mode, dimensions or cwd changed")
            } else {
                fail("target identity, mode, dimensions or cwd changed")
            });
        }
        self.capture = self
            .ns
            .command_for(
                &["capture-pane", "-p", "-e", "-t", &self.pane],
                REQUEST_TIMEOUT,
            )
            .map_err(|e| tmux_error(e, self.changed))?;
        let after = State::read(&self.ns, &self.pane, self.changed)?;
        if !state.same_target(&after) {
            return Err(if self.changed {
                partial("target changed during capture")
            } else {
                fail("target changed during capture")
            });
        }
        Ok(after)
    }
    fn idle(&mut self) -> Result<()> {
        for _ in 0..24 {
            let before = State::read(&self.ns, &self.pane, self.changed)?;
            let after = self.observe()?;
            if (before.x, before.y) != (after.x, after.y) {
                pause(50);
                continue;
            }
            if guard::check("busy", &self.capture, "").is_some() {
                return Err(if self.changed {
                    partial("reset target entered a busy state")
                } else {
                    draft(&self.pane, "an agent busy state")
                });
            }
            match composer::classify(&self.capture, '›', after.x, after.y, after.width) {
                composer::Composer::EmptyCandidate => return Ok(()),
                composer::Composer::Draft => {
                    return Err(if self.changed {
                        partial("restoration composer is not proven idle")
                    } else {
                        draft(&self.pane, "a draft or unrecognized footer")
                    })
                }
                composer::Composer::Unrecognized => {
                    return Err(if self.changed {
                        partial("restoration composer is not proven idle")
                    } else {
                        fail(format!("cannot find Codex prompt in target {}", self.pane))
                    })
                }
            }
        }
        Err(if self.changed {
            partial("restoration composer changed during capture")
        } else {
            fail("target composer kept redrawing during inspection")
        })
    }
    fn check(&self, mode: &str, expected: &str) -> bool {
        guard::check(mode, &self.capture, expected).is_some()
    }
    fn dispatch(&mut self, condition: String, action: String) -> Result<()> {
        self.ns.verify().map_err(|e| tmux_error(e, self.changed))?;
        foreground(&self.client, &self.before).map_err(partial)?;
        let b = &self.before;
        let invariants = [
            ("pane_id", self.pane.clone()),
            ("pane_in_mode", "0".into()),
            ("pane_dead", "0".into()),
            ("pane_pid", b.pid.to_string()),
            ("pane_current_command", b.command.clone()),
            ("pane_width", b.width.to_string()),
            ("pane_height", b.height.to_string()),
            ("session_name", b.session.clone()),
            ("window_name", b.window.clone()),
            ("pane_current_path", b.cwd.clone()),
        ]
        .into_iter()
        .fold(condition, |condition, (key, value)| {
            format!(
                "#{{&&:{condition},#{{==:#{{{key}}},{}}}}}",
                guard::escape_format(&value)
            )
        });
        let yes = format!(
            "{action} ; display-message -p -t {} '__NEW_SENT__'",
            self.pane
        );
        let no = format!("display-message -p -t {} '__NEW_REFUSED__'", self.pane);
        let mut command = Command::new("/opt/homebrew/bin/tmux");
        command.arg("-N").arg("-S").arg(self.ns.socket()).args([
            "if-shell",
            "-F",
            "-t",
            &self.pane,
            &invariants,
            &yes,
            &no,
        ]);
        self.changed = true;
        let output =
            runtime::capture_for(&mut command, REQUEST_TIMEOUT).map_err(|e| tmux_error(e, true))?;
        self.ns.verify().map_err(|e| tmux_error(e, true))?;
        if output != b"__NEW_SENT__\n" {
            return Err(partial(
                "screen changed before guarded key or delivery is unknown",
            ));
        }
        Ok(())
    }
    fn key(&mut self, mode: &str, key: &str, expected: &str) -> Result<()> {
        self.observe()?;
        if !self.check(mode, expected) {
            return Err(partial(
                "screen changed before guarded key or delivery is unknown",
            ));
        }
        let condition = guard::check("tmux-rows", &self.capture, &self.before.cwd)
            .ok_or_else(|| partial("cannot build atomic screen guard"))?;
        let key = match key {
            "Enter" | "Up" | "Down" | "s" => key,
            "BSpace4" => "BSpace BSpace BSpace BSpace",
            _ => return Err(partial("unsupported restoration key")),
        };
        self.dispatch(condition, format!("send-keys -t {} {key}", self.pane))
    }
    fn literal(&mut self, text: &str) -> Result<()> {
        self.idle()?;
        let state = State::read(&self.ns, &self.pane, self.changed)?;
        let rows = guard::rows(&self.capture);
        let start = rows
            .iter()
            .enumerate()
            .take(state.y + 1)
            .rfind(|(_, row)| row.starts_with("› "))
            .map(|(i, _)| i)
            .ok_or_else(|| partial("cannot find literal composer"))?;
        let condition = guard::row_checks(&rows, start)
            .ok_or_else(|| partial("cannot build literal screen guard"))?;
        let condition = format!(
            "#{{&&:{condition},#{{&&:#{{==:#{{cursor_x}},{}}},#{{==:#{{cursor_y}},{}}}}}}}",
            state.x, state.y
        );
        self.dispatch(
            condition,
            format!("send-keys -l -t {} -- {}", self.pane, runtime::quote(text)),
        )
    }
    fn wait(&mut self, mode: &str, expected: &str) -> Result<()> {
        for _ in 0..40 {
            self.observe()?;
            if mode == "slash" && self.check("busy-slash", "") {
                self.key("busy-slash", "BSpace4", "")?;
                self.observe()?;
                if guard::rows(&self.capture)
                    .iter()
                    .any(|row| row.starts_with("› /n"))
                {
                    return Err(partial("busy pane: typed /new may remain as a draft"));
                }
                return Err(Failure(5, format!("REFUSE: target {} turned busy during reset; the typed /new was withdrawn and nothing was submitted", self.pane)));
            }
            if self.check(mode, expected) {
                return Ok(());
            }
            pause(100);
        }
        Err(partial(format!(
            "unrecognized {mode} screen; no further input sent"
        )))
    }
    fn select(&mut self, mode: &str, expected: &str) -> Result<()> {
        let navigate = format!("navigate-{mode}");
        for _ in 0..12 {
            self.wait(mode, expected)?;
            let indices = guard::check(&navigate, &self.capture, expected)
                .ok_or_else(|| partial("unrecognized model/effort picker"))?;
            let (selected, desired) = indices
                .split_once(':')
                .ok_or_else(|| partial("unrecognized picker coordinates"))?;
            let selected: usize = selected
                .parse()
                .map_err(|_| partial("unrecognized picker coordinates"))?;
            let desired: usize = desired
                .parse()
                .map_err(|_| partial("unrecognized picker coordinates"))?;
            if selected == desired {
                return Ok(());
            }
            let (direction, next) = if selected < desired {
                ("Down", selected + 1)
            } else {
                ("Up", selected - 1)
            };
            self.key(mode, direction, expected)?;
            let mut moved = false;
            for _ in 0..40 {
                self.observe()?;
                let observed = guard::check(&navigate, &self.capture, expected)
                    .ok_or_else(|| partial("picker changed to an unfamiliar screen"))?;
                if observed == format!("{next}:{desired}") {
                    moved = true;
                    break;
                }
                if observed != indices {
                    return Err(partial("picker selection changed unexpectedly"));
                }
                pause(100);
            }
            if !moved {
                return Err(partial("picker movement could not be verified"));
            }
        }
        Err(partial("picker did not reach the required model/effort"))
    }
    fn run(&mut self, profile: Option<(String, String)>) -> Result<&'static str> {
        self.observe()?;
        if self.check("menu", "") {
            if profile.is_none() {
                return Err(draft(&self.pane, "a pending checkout picker without a retained model/effort; specify <window> <model> <effort>"));
            }
            self.key("menu", "Enter", "")?;
            for _ in 0..40 {
                self.observe()?;
                if let Some(footer) = guard::check("footer", &self.capture, "") {
                    if self.check("direct-reset", &footer) {
                        self.footer = guard::desired(&footer, &profile).ok_or_else(|| {
                            partial("cannot resolve the requested recovery profile")
                        })?;
                        self.restore(&self.footer.clone())?;
                        return Ok("pending");
                    }
                }
                pause(100);
            }
            return Err(partial(
                "checkout picker was answered but the fresh composer was not verified",
            ));
        }
        self.idle()?;
        pause(40);
        self.idle()?;
        let samples = std::env::var("CODEX_NEW_BUSY_SAMPLES")
            .ok()
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(30);
        for _ in 0..samples {
            self.observe()?;
            if self.check("busy", "") {
                return Err(draft(&self.pane, "an agent busy state"));
            }
            pause(50);
        }
        self.idle()?;
        self.footer = guard::check("footer", &self.capture, "")
            .ok_or_else(|| fail("unrecognized model/cwd footer"))?;
        let footer = self.footer.clone();
        let desired = guard::desired(&footer, &profile)
            .ok_or_else(|| fail("cannot resolve requested model/effort"))?;
        if self.check("direct-reset", &footer) {
            self.footer = desired;
            self.restore(&self.footer.clone())?;
            return Ok("already");
        }
        if !self.check("supported-footer", &footer) {
            return Err(fail("unsupported model/effort; cannot prove restoration"));
        }
        self.literal("/new")?;
        self.wait("slash", &footer)?;
        self.key("slash", "Enter", &footer)?;
        let mut destination = None;
        for _ in 0..40 {
            self.observe()?;
            if self.check("menu", &footer) {
                destination = Some("menu");
                break;
            }
            if self.check("direct-reset", &footer) {
                destination = Some("reset");
                break;
            }
            pause(100);
        }
        match destination {
            Some("menu") => {
                self.key("menu", "Enter", &footer)?;
                self.wait("reset", &footer)?;
            }
            Some(_) => (),
            None => {
                return Err(partial(
                    "unrecognized menu or reset screen; no further input sent",
                ))
            }
        }
        self.footer = desired;
        self.restore(&self.footer.clone())?;
        Ok("reset")
    }
    fn restore(&mut self, footer: &str) -> Result<()> {
        if !self.check("fresh", footer) {
            let restore = guard::check("footer", &self.capture, "")
                .ok_or_else(|| partial("unrecognized reset model footer"))?;
            self.literal("/model")?;
            self.wait("model-slash", &restore)?;
            self.key("model-slash", "Enter", &restore)?;
            self.select("models", footer)?;
            self.key("models", "Enter", footer)?;
            self.select("efforts", footer)?;
            if footer.contains(" max · ") || footer.contains(" ultra · ") {
                self.key("efforts", "Enter", footer)?;
                self.select("advanced", footer)?;
                self.key("advanced", "s", footer)?;
            } else {
                self.key("efforts", "s", footer)?;
            }
        }
        self.wait("fresh", footer)?;
        self.wait("direct-reset", footer)?;
        self.idle()?;
        Ok(())
    }
}

pub(crate) fn entry(args: &[String]) -> i32 {
    let run = || -> Result<()> {
        let (socket, session, window, profile) = route(args)?;
        let mut chat = Chat::open(&socket, &session, &window)?;
        let result = chat.run(profile)?;
        let route = format!("{session}:{window} {}", chat.pane);
        let detail = match result {
            "pending" => format!(
                "resolved pending checkout picker; fresh context, requested model/effort and cwd verified ({})",
                chat.footer
            ),
            "already" => "already fresh, model and cwd verified".into(),
            _ => "fresh context, model and cwd verified".into(),
        };
        drop(chat);
        println!("NEW ok ({route}); {detail}");
        Ok(())
    };
    match run() {
        Ok(()) => 0,
        Err(Failure(code, detail)) => {
            eprintln!("{detail}");
            code
        }
    }
}

#[cfg(test)]
#[path = "../tests/support/codex_new_chat.rs"]
mod tests;
