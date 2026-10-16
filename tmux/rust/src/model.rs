use crate::{identity, model_guard as guard, model_payload as payload, runtime};
use sha2::{Digest, Sha256};
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use std::time::{Duration, Instant};

type Result<T> = std::result::Result<T, Failure>;
static SIGNAL: AtomicI32 = AtomicI32::new(0);
static INPUT: AtomicBool = AtomicBool::new(false);
extern "C" fn interrupted(signal: i32) {
    SIGNAL.store(signal, Ordering::Relaxed);
}
fn interruption() -> Result<()> {
    if SIGNAL.load(Ordering::Relaxed) == 0 {
        return Ok(());
    }
    Err(if INPUT.load(Ordering::Relaxed) {
        partial("interrupted; target input may remain")
    } else {
        refused("interrupted")
    })
}
fn uncertain(error: Failure) -> Failure {
    if matches!(error.code, 3 | 4) {
        error
    } else {
        partial(&error.message)
    }
}
#[derive(Debug)]
pub struct Failure {
    pub code: i32,
    pub message: String,
}
fn fail(code: i32, message: impl Into<String>) -> Failure {
    Failure {
        code,
        message: message.into(),
    }
}
fn refused(message: impl Into<String>) -> Failure {
    fail(
        1,
        format!(
            "REFUSE: {}; no target input was sent; safe to retry after the condition clears",
            message.into()
        ),
    )
}
fn draft(pane: &str, reason: &str) -> Failure {
    fail(5,format!("REFUSE: target {pane} has {reason}; no target input was sent; safe to retry after the condition clears"))
}
fn copy(pane: &str) -> Failure {
    fail(2,format!("REFUSE: target {pane} is in copy mode; no target input was sent; safe to retry after the condition clears"))
}
fn partial(message: &str) -> Failure {
    fail(4,format!("UNVERIFIED: delivery may be partial or unconfirmed: {message}; do not resend automatically"))
}
pub fn address(value: &str) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-'))
}
pub struct Context {
    ns: identity::Namespace,
    timeout: Duration,
}
impl Context {
    pub fn connect(socket: &Path) -> Result<Self> {
        let stream = std::os::unix::net::UnixStream::connect(socket)
            .map_err(|_| refused("cannot connect to tmux"))?;
        let mut pid = 0i32;
        let mut length = 4;
        if unsafe {
            libc::getsockopt(
                stream.as_raw_fd(),
                0,
                2,
                (&mut pid as *mut i32).cast(),
                &mut length,
            )
        } != 0
            || pid <= 0
        {
            return Err(refused("cannot identify tmux server"));
        }
        let process = identity::kernel_process(pid as u32)
            .ok_or_else(|| refused("cannot identify tmux server"))?;
        let executable = std::fs::canonicalize("/opt/homebrew/bin/tmux")
            .map_err(|_| refused("pinned tmux is unavailable"))?;
        let ns = identity::Namespace::connect(&executable, socket, process).map_err(refused)?;
        let timeout = Duration::from_secs(1);
        Ok(Self { ns, timeout })
    }
    pub fn ambient() -> Result<Self> {
        let context = std::env::var("TMUX")
            .ok()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| refused("TMUX is not set"))?;
        let mut parts = context.rsplitn(3, ',');
        parts.next();
        parts.next();
        let socket = parts
            .next()
            .ok_or_else(|| refused("invalid TMUX context"))?;
        Self::connect(Path::new(socket))
    }
    pub fn request(&self, args: &[&str]) -> Result<String> {
        interruption()?;
        self.ns.verify().map_err(refused)?;
        let executable = std::fs::canonicalize("/opt/homebrew/bin/tmux")
            .map_err(|_| refused("pinned tmux is unavailable"))?;
        let mut command = Command::new(executable);
        command.arg("-N").arg("-S").arg(self.ns.socket()).args(args);
        let result=runtime::capture_for(&mut command,self.timeout).map_err(|e| {
            if e=="command outcome unproved" {fail(3,"REFUSE: tmux server is unresponsive; delivery state is unknown; do not resend automatically")} else {refused(e)}
        })?;
        interruption()?;
        self.ns.verify().map_err(refused)?;
        String::from_utf8(result).map_err(|_| refused("invalid tmux response"))
    }
    pub fn display(&self, pane: &str, format: &str) -> Result<String> {
        let text = self.request(&[
            "display-message",
            "-p",
            "-t",
            pane,
            &format!("#{{pane_id}}|{format}"),
        ])?;
        let (found, text) = text
            .trim_end_matches('\n')
            .split_once('|')
            .ok_or_else(|| refused("cannot query target"))?;
        if found != pane {
            return Err(refused("target identity changed"));
        }
        Ok(text.into())
    }
    pub fn capture(&self, pane: &str) -> Result<String> {
        self.request(&["capture-pane", "-p", "-e", "-t", pane])
    }
    pub fn target(&self, session: &str, window: &str) -> Result<identity::Target> {
        let text = self.request(&["list-panes", "-a", "-F", identity::CAPTURE_FORMAT])?;
        let snapshot = identity::Snapshot::parse(text.as_bytes()).map_err(refused)?;
        let count = snapshot
            .targets
            .iter()
            .filter(|t| t.session_name == session && t.window.name == window)
            .count();
        match count {
            0 => return Err(refused(format!("no target window {session}:{window}"))),
            1 => (),
            _ => {
                return Err(refused(format!(
                    "target window {session}:{window} is ambiguous"
                )))
            }
        }
        identity::resolve(&snapshot, session, window, None).map_err(refused)
    }
}
struct Lock {
    path: PathBuf,
    _file: File,
}
impl Lock {
    fn acquire(context: &Context, pane: &str) -> Result<Self> {
        let socket = std::fs::metadata(context.ns.socket())
            .map_err(|_| refused("cannot establish target relay lock"))?;
        let key = format!(
            "{:x}",
            Sha256::digest(format!("{}:{}:{pane}", socket.dev(), socket.ino()).as_bytes())
        );
        let root = PathBuf::from(format!("/private/tmp/tmux-{}/relay-locks", unsafe {
            libc::geteuid()
        }));
        std::fs::create_dir_all(&root)
            .map_err(|_| refused("cannot establish target relay lock"))?;
        let path = root.join(key);
        let busy = || {
            fail(5,"REFUSE: another relay is in progress; no target input was sent; safe to retry after the condition clears")
        };
        for _ in 0..2 {
            match OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&path)
            {
                Ok(mut file) => {
                    writeln!(file, "{}", std::process::id())
                        .map_err(|_| refused("cannot write target relay lock"))?;
                    return Ok(Self { path, _file: file });
                }
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                    let pid = std::fs::read_to_string(&path)
                        .ok()
                        .and_then(|s| s.trim().parse().ok());
                    if pid.is_none_or(|pid| identity::kernel_process(pid).is_some()) {
                        return Err(busy());
                    }
                    std::fs::remove_file(&path).map_err(|_| busy())?;
                }
                Err(_) => return Err(refused("cannot establish target relay lock")),
            }
        }
        Err(busy())
    }
}
impl Drop for Lock {
    fn drop(&mut self) {
        if std::fs::read_to_string(&self.path)
            .ok()
            .is_some_and(|s| s.trim() == std::process::id().to_string())
        {
            let _ = std::fs::remove_file(&self.path);
        }
    }
}
const VIEW:&str="#{pane_in_mode}|#{pane_dead}|#{pane_pid}|#{pane_current_command}|#{pane_width}|#{pane_height}|#{session_name}|#{window_name}|#{pane_current_path}|#{cursor_x}|#{cursor_y}";
pub struct View {
    pub capture: String,
    pub x: usize,
    pub y: usize,
    pub width: usize,
    pub height: usize,
    pub command: String,
    pub cwd: String,
    pub in_mode: bool,
    state: String,
}
pub struct Switch {
    pub context: Context,
    pub target: identity::Target,
    pub pane: String,
    proof: String,
    baseline: Option<String>,
    pub settle: Option<String>,
    _lock: Lock,
}
impl Switch {
    pub fn open(session: &str, window: &str) -> Result<Self> {
        let context = Context::ambient()?;
        let target = context.target(session, window)?;
        let pane = target.selector();
        let command = context.display(&pane, "#{pane_current_command}")?;
        if command.is_empty() {
            return Err(refused("target process is unavailable"));
        }
        let lock = Lock::acquire(&context, &pane)?;
        let proof = target_proof(&context, &pane)?;
        Ok(Self {
            context,
            target,
            pane,
            proof,
            baseline: None,
            settle: None,
            _lock: lock,
        })
    }
    pub fn observe(&mut self, after_input: bool) -> Result<View> {
        let result = (|| {
            let problem = |s: &str| if after_input { partial(s) } else { refused(s) };
            let state = self.context.display(&self.pane, VIEW)?;
            let fields: Vec<_> = state.split('|').collect();
            if fields.len() != 11
                || !matches!(fields[0], "0" | "1")
                || fields[1] != "0"
                || fields[2] != self.target.pane.pid.to_string()
                || fields[3].is_empty()
                || fields[6] != self.target.session_name
                || fields[7] != self.target.window.name
            {
                return Err(problem("target identity changed"));
            }
            let number = |i: usize| {
                fields[i]
                    .parse::<usize>()
                    .map_err(|_| problem("cannot query target geometry"))
            };
            let mut view = View {
                capture: self.context.capture(&self.pane)?,
                x: number(9)?,
                y: number(10)?,
                width: number(4)?,
                height: number(5)?,
                command: fields[3].into(),
                cwd: fields[8].into(),
                in_mode: fields[0] == "1",
                state: state.clone(),
            };
            let after = self.context.display(&self.pane, VIEW)?;
            let stable = if after_input {
                after.split('|').take(9).eq(state.split('|').take(9))
            } else {
                after == state
            };
            if !stable {
                return Err(problem("target changed during capture"));
            }
            if after_input {
                let after: Vec<_> = after.split('|').collect();
                view.x = after[9]
                    .parse()
                    .map_err(|_| problem("invalid restored cursor"))?;
                view.y = after[10]
                    .parse()
                    .map_err(|_| problem("invalid restored cursor"))?;
            }
            let baseline = fields[1..9].join("|");
            if self.baseline.as_ref().is_some_and(|s| *s != baseline) {
                return Err(problem("target identity, dimensions or cwd changed"));
            }
            self.baseline = Some(baseline);
            if view.width <= 4 || view.height <= 6 {
                return Err(problem("target pane is too small to verify delivery"));
            }
            Ok(view)
        })();
        if after_input {
            result.map_err(uncertain)
        } else {
            result
        }
    }
    pub fn empty(&mut self) -> Result<View> {
        let mut deadline = None;
        for _ in 0..24 {
            let view = match self.observe(false) {
                Err(error) if error.message.contains("target changed during capture") => {
                    std::thread::sleep(Duration::from_millis(10));
                    continue;
                }
                result => result?,
            };
            if view.in_mode {
                return Err(copy(&self.pane));
            }
            if let Some(footer) = &self.settle {
                if !guard::check("settling-reset", &view.capture, footer) {
                    return Err(draft(&self.pane, "an unrecognized fresh-reset transition"));
                }
            }
            let glyph = guard::rows(&view.capture)
                .get(view.y)
                .and_then(|r| r.chars().next())
                .filter(|g| matches!(g, '›' | '»'));
            if let Some(glyph) = glyph {
                if payload::busy(&view.capture, glyph, view.y) {
                    return Err(draft(&self.pane, "an agent busy state"));
                }
                return match payload::input(&view.capture, glyph, view.x, view.y, view.width) {
                    0 => Ok(view),
                    1 => Err(draft(&self.pane, "a draft or unrecognized footer")),
                    _ => Err(refused(format!(
                        "cannot find Codex prompt in target {}",
                        self.pane
                    ))),
                };
            }
            let footer = guard::footer(&view.capture)
                .filter(|f| guard::check("settling-reset", &view.capture, f))
                .ok_or_else(|| draft(&self.pane, "an unrecognized composer glyph"))?;
            self.settle = Some(footer);
            let deadline = *deadline.get_or_insert_with(|| Instant::now() + Duration::from_secs(2));
            if Instant::now() >= deadline {
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        Err(draft(&self.pane, "an unsettled fresh-reset composer"))
    }
    fn identity_check(&self, after_input: bool) -> Result<()> {
        let proof = target_proof(&self.context, &self.pane).map_err(|error| {
            if after_input {
                uncertain(error)
            } else {
                error
            }
        })?;
        if proof != self.proof {
            return Err(if after_input {
                partial("Codex foreground process changed")
            } else {
                refused("Codex process identity changed before paste")
            });
        }
        Ok(())
    }
    fn condition(&self, view: &View, screen: &str) -> String {
        let f = guard::escape_format;
        let checks = vec![
            format!("#{{==:#{{pane_id}},{}}}", self.pane),
            "#{==:#{pane_in_mode},0}".to_owned(),
            "#{==:#{pane_dead},0}".to_owned(),
            format!("#{{==:#{{pane_pid}},{}}}", self.target.pane.pid),
            format!("#{{==:#{{pane_current_command}},{}}}", view.command),
            format!("#{{==:#{{session_name}},{}}}", f(&self.target.session_name)),
            format!("#{{==:#{{window_name}},{}}}", f(&self.target.window.name)),
            format!("#{{==:#{{pane_width}},{}}}", view.width),
            format!("#{{==:#{{pane_height}},{}}}", view.height),
            format!("#{{==:#{{pane_current_path}},{}}}", f(&view.cwd)),
            format!("#{{==:#{{cursor_x}},{}}}", view.x),
            format!("#{{==:#{{cursor_y}},{}}}", view.y),
            screen.into(),
        ];
        checks
            .into_iter()
            .reduce(|a, b| format!("#{{&&:{a},{b}}}"))
            .unwrap()
    }
    fn atomic(&self, view: &View, screen: &str, deliver: &str, after_input: bool) -> Result<()> {
        let delivered = format!(
            "{deliver} ; display-message -p -t {} '__MODEL_SENT__'",
            self.pane
        );
        let blocked = format!(
            "display-message -p -t {} '__MODEL_REFUSED__:#{{pane_id}}:#{{pane_in_mode}}'",
            self.pane
        );
        INPUT.store(true, Ordering::Relaxed);
        let receipt = self
            .context
            .request(&[
                "if-shell",
                "-F",
                "-t",
                &self.pane,
                &self.condition(view, screen),
                &delivered,
                &blocked,
            ])
            .map_err(uncertain)?;
        match receipt.trim_end_matches('\n') {
            "__MODEL_SENT__" => Ok(()),
            text if text == format!("__MODEL_REFUSED__:{}:1", self.pane) && !after_input => {
                Err(copy(&self.pane))
            }
            text if text == format!("__MODEL_REFUSED__:{}:0", self.pane) && !after_input => {
                Err(draft(&self.pane, "an unproven composer state"))
            }
            _ => Err(partial(
                "screen changed before guarded input or delivery is unknown",
            )),
        }
    }
    pub fn paste(&mut self, text: &str) -> Result<()> {
        self.identity_check(false)?;
        let view = self.empty()?;
        let fresh = self.empty()?;
        if view.state != fresh.state || view.capture != fresh.capture {
            return Err(draft(&self.pane, "an unproven composer state"));
        }
        if !payload::printable(text) || payload::cells(text).is_none_or(|n| n > view.width - 4) {
            return Err(refused(
                "payload would wrap and cannot be verified byte for byte",
            ));
        }
        self.identity_check(false)?;
        let buffer = format!("relay-{}", runtime::fresh_id().map_err(refused)?);
        self.context
            .request(&["set-buffer", "-b", &buffer, "--", text])?;
        let rows = guard::rows(&view.capture);
        let screen = guard::row_checks(&rows, 0, rows.len())
            .ok_or_else(|| refused("cannot build composer guard"))?;
        let result = self.atomic(
            &view,
            &screen,
            &format!("paste-buffer -p -d -t {} -b {buffer}", self.pane),
            false,
        );
        if result.is_err() {
            let _ = self.context.request(&["delete-buffer", "-b", &buffer]);
        }
        result
    }
    pub fn wait(&mut self, mode: &str, expected: &str) -> Result<View> {
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            let view = self.observe(true)?;
            if !view.in_mode && guard::check(mode, &view.capture, expected) {
                return Ok(view);
            }
            if Instant::now() >= deadline {
                return Err(partial(&format!(
                    "unrecognized {mode} screen; no further input sent"
                )));
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    pub fn key(&mut self, mode: &str, expected: &str, key: &str, previous: &View) -> Result<()> {
        if !matches!(
            key,
            "Enter" | "Up" | "Down" | "s" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
        ) {
            return Err(partial("unsupported selection key"));
        }
        self.identity_check(true)?;
        let view = self.observe(true)?;
        if view.in_mode
            || guard::digest(&view.capture) != guard::digest(&previous.capture)
            || !guard::check(mode, &view.capture, expected)
        {
            return Err(partial("screen changed before guarded key"));
        }
        let screen = guard::tmux_rows(&view.capture, &view.cwd)
            .ok_or_else(|| partial("cannot build atomic screen guard"))?;
        self.atomic(
            &view,
            &screen,
            &format!("send-keys -t {} {key}", self.pane),
            true,
        )
    }
    pub fn select(&mut self, mode: &str, expected: &str) -> Result<View> {
        let mut view = self.wait(mode, expected)?;
        for _ in 0..12 {
            let (selected, desired) = guard::picker(&view.capture, mode, expected)
                .ok_or_else(|| partial("unrecognized model/effort picker"))?;
            if selected == desired {
                return Ok(view);
            }
            let (key, next) = if selected < desired {
                ("Down", selected + 1)
            } else {
                ("Up", selected - 1)
            };
            self.key(mode, expected, key, &view)?;
            let deadline = Instant::now() + Duration::from_secs(5);
            loop {
                view = self.observe(true)?;
                let observed = guard::picker(&view.capture, mode, expected)
                    .ok_or_else(|| partial("picker changed to an unfamiliar screen"))?;
                if observed == (next, desired) {
                    break;
                }
                if observed != (selected, desired) {
                    return Err(partial("picker selection changed unexpectedly"));
                }
                if Instant::now() >= deadline {
                    return Err(partial("picker movement could not be verified"));
                }
                std::thread::sleep(Duration::from_millis(10));
            }
        }
        Err(partial("picker did not reach the required model/effort"))
    }
    pub fn idle(&mut self) -> Result<View> {
        self.identity_check(true)?;
        let view = self.observe(true)?;
        let glyph = guard::rows(&view.capture)
            .get(view.y)
            .and_then(|s| s.chars().next())
            .ok_or_else(|| partial("unrecognized restored composer glyph"))?;
        if view.in_mode
            || payload::input(&view.capture, glyph, view.x, view.y, view.width) != 0
            || payload::busy(&view.capture, glyph, view.y)
        {
            return Err(partial("restoration composer is not proven idle"));
        }
        Ok(view)
    }
}
pub fn target_proof(context: &Context, pane: &str) -> Result<String> {
    let state = context.display(pane, "#{pane_pid}|#{pane_current_command}|#{pane_dead}")?;
    let fields: Vec<_> = state.split('|').collect();
    if fields.len() != 3 || fields[1].is_empty() || fields[2] != "0" {
        return Err(refused("foreground process is not proven Codex"));
    }
    let pid = fields[0]
        .parse()
        .map_err(|_| refused("invalid target process"))?;
    let first = identity::Client::bind_codex(pid).map_err(refused)?;
    let proof = first.proof().map_err(refused)?;
    let second = identity::Client::bind_codex(pid).map_err(refused)?;
    if second.proof().map_err(refused)? != proof
        || context.display(pane, "#{pane_pid}|#{pane_current_command}|#{pane_dead}")? != state
    {
        return Err(refused("foreground process identity changed"));
    }
    Ok(proof)
}
pub fn run(args: &[String]) -> Result<String> {
    if !(2..=4).contains(&args.len()) {
        return Err(fail(
            1,
            "usage: codex-model <session> <window> [model=gpt-5.6-terra] [effort=max]",
        ));
    }
    let model = args
        .get(2)
        .filter(|s| !s.is_empty())
        .map_or("gpt-5.6-terra", String::as_str);
    let effort = args
        .get(3)
        .filter(|s| !s.is_empty())
        .map_or("max", String::as_str);
    if !guard::valid(model, effort) {
        return Err(refused(format!(
            "unsupported model/effort: {model} {effort}"
        )));
    }
    if !address(&args[0]) || !address(&args[1]) {
        return Err(refused(
            "session and window names may contain only letters, digits, underscores, or hyphens",
        ));
    }
    let mut switch = Switch::open(&args[0], &args[1])?;
    switch.empty()?;
    let before = switch.empty()?;
    let source = guard::footer(&before.capture)
        .filter(|s| guard::footer_parts(s).is_some())
        .ok_or_else(|| refused("unsupported source model/effort footer"))?;
    let expected = guard::desired(&source, model, effort)
        .ok_or_else(|| refused("cannot resolve requested model/effort"))?;
    switch.paste("/model")?;
    let view = switch.wait("model-slash", &source)?;
    switch.key("model-slash", &source, "Enter", &view)?;
    let view = switch.wait("models", &expected)?;
    let (_, desired) = guard::picker(&view.capture, "models", &expected)
        .ok_or_else(|| partial("unrecognized model picker"))?;
    switch.key("models", &expected, &(desired + 1).to_string(), &view)?;
    let view = switch.wait("efforts", &expected)?;
    if matches!(effort, "max" | "ultra") {
        switch.key("efforts", &expected, "5", &view)?;
        let view = switch.select("advanced", &expected)?;
        switch.key("advanced", &expected, "s", &view)?;
    } else {
        let view = switch.select("efforts", &expected)?;
        switch.key("efforts", &expected, "s", &view)?;
    }
    switch.wait("changed", &expected)?;
    switch.idle()?;
    Ok(format!(
        "MODEL ok ({}:{} {}); {model} {effort} for this session only verified",
        args[0], args[1], switch.pane
    ))
}
pub fn prepaste(args: &[String]) -> Result<()> {
    if args.len() != 8 {
        return Err(refused("invalid prepaste arguments"));
    }
    let context = Context::connect(Path::new(&args[0]))?;
    let pane = &args[1];
    let glyph = args[2]
        .chars()
        .next()
        .ok_or_else(|| refused("invalid glyph"))?;
    let x = args[3].parse().map_err(|_| refused("invalid cursor"))?;
    let y = args[4].parse().map_err(|_| refused("invalid cursor"))?;
    let width = args[5].parse().map_err(|_| refused("invalid width"))?;
    if args[6] != "strict" {
        return Err(refused("unsupported sender tier"));
    }
    let expected = format!("{x}:{y}:0:{width}");
    let fmt = "#{cursor_x}:#{cursor_y}:#{pane_in_mode}:#{pane_width}";
    if context.display(pane, fmt)? != expected {
        return Err(refused("composer changed"));
    }
    let capture = context.capture(pane)?;
    if payload::input(&capture, glyph, x, y, width) != 0
        || context.display(pane, fmt)? != expected
        || context.capture(pane)? != capture
    {
        return Err(refused("composer changed"));
    }
    Ok(())
}
fn guard_entry(args: &[String], capture: &str) -> (i32, String) {
    let mode = args.first().map_or("", String::as_str);
    let expected = args.get(1).map_or("", String::as_str);
    let result = (|| -> Option<(bool, String)> {
        Some(match mode {
            "validate" => (guard::valid(expected, args.get(2)?), String::new()),
            "digest" => (true, guard::digest(capture)),
            "glyph" => {
                let y = expected.parse::<usize>().ok()?;
                let rows = guard::rows(capture);
                let row = rows.get(y)?;
                let glyph = row.chars().next()?;
                if !matches!(glyph, '›' | '»')
                    || !(row == &glyph.to_string() || row.starts_with(&format!("{glyph} ")))
                {
                    return None;
                }
                (true, glyph.to_string())
            }
            "footer" => (true, guard::footer(capture)?),
            "desired" => (true, guard::desired(capture, expected, args.get(2)?)?),
            "tmux-rows" => (true, guard::tmux_rows(capture, expected)?),
            mode if mode.starts_with("navigate-") => {
                let (selected, desired) =
                    guard::picker(capture, mode.strip_prefix("navigate-")?, expected)?;
                (true, format!("{selected}:{desired}"))
            }
            "live" => {
                if args.len() != 8 {
                    return None;
                }
                let context = Context::connect(Path::new(&args[1])).ok()?;
                let pane = &args[2];
                if target_proof(&context, pane).ok()? != args[6]
                    || context
                        .display(pane, "#{pane_in_mode}:#{pane_current_path}")
                        .ok()?
                        != format!("0:{}", args[5])
                {
                    return None;
                }
                let capture = context.capture(pane).ok()?;
                (
                    guard::digest(&capture) == args[7]
                        && guard::check(&args[3], &capture, &args[4]),
                    String::new(),
                )
            }
            _ => (guard::check(mode, capture, expected), String::new()),
        })
    })();
    match result {
        Some((valid, output)) => (if valid { 0 } else { 1 }, output),
        None => (1, String::new()),
    }
}
pub fn entry(surface: &str, args: &[String]) -> Option<i32> {
    if ![
        "codex-model",
        "codex-model-guard",
        "codex-model-input-guard",
        "codex-model-payload-guard",
        "codex-model-target-guard",
    ]
    .contains(&surface)
    {
        return None;
    }
    if surface == "codex-model" {
        SIGNAL.store(0, Ordering::Relaxed);
        INPUT.store(false, Ordering::Relaxed);
        unsafe {
            for signal in [libc::SIGINT, libc::SIGTERM, libc::SIGPIPE] {
                libc::signal(signal, interrupted as *const () as libc::sighandler_t);
            }
        }
        return Some(match run(args) {
            Ok(output) => {
                println!("{output}");
                0
            }
            Err(error) => {
                eprintln!("{}", error.message);
                error.code
            }
        });
    }
    let mut capture = String::new();
    let reads = surface == "codex-model-input-guard"
        || (surface == "codex-model-guard" && !args.first().is_some_and(|s| s == "live"));
    if reads && std::io::stdin().read_to_string(&mut capture).is_err() {
        return Some(if surface == "codex-model-guard" { 1 } else { 2 });
    }
    let (code, output) = match surface {
        "codex-model-guard" => guard_entry(args, &capture),
        "codex-model-payload-guard" => payload::entry(args),
        "codex-model-input-guard" => {
            let code = (|| {
                if !(3..=5).contains(&args.len()) || args.get(4).is_some_and(|s| s != "strict") {
                    return None;
                }
                Some(payload::input(
                    &capture,
                    args[0].chars().next()?,
                    args[1].parse().ok()?,
                    args[2].parse().ok()?,
                    args.get(3).map_or(Some(10000), |s| s.parse().ok())?,
                ))
            })();
            (code.unwrap_or(2), String::new())
        }
        "codex-model-target-guard" => {
            let result = (|| {
                if !(2..=3).contains(&args.len()) {
                    return None;
                }
                let context = Context::connect(Path::new(&args[0])).ok()?;
                let proof = target_proof(&context, &args[1]).ok()?;
                if let Some(expected) = args.get(2) {
                    if expected != &proof {
                        return None;
                    }
                    Some(String::new())
                } else {
                    Some(proof)
                }
            })();
            result.map_or((1, String::new()), |s| (0, s))
        }
        _ => (1, String::new()),
    };
    if !output.is_empty() {
        if surface == "codex-model-payload-guard" {
            print!("{output}");
        } else {
            println!("{output}");
        }
    }
    Some(code)
}
