use crate::watch_support::*;
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicI32, Ordering};
use std::time::{Duration, Instant};

static SIGNAL: AtomicI32 = AtomicI32::new(0);
extern "C" fn interrupted(n: i32) {
    SIGNAL.store(n, Ordering::Relaxed);
}
const USAGE:&str="usage: pane-watch --pane <tmux-target> --ui codex [--hot-file FILE] [--ack-current] [--replace]";
const HOT:&str="Traceback|FAILED|REFUSE|cyber_policy|Conversation interrupted|rate limit|usage limit|git (commit|reset|clean|checkout|push|add -A)|Divergence|hard-cap";
const ASK:&str="HALT|Halted|halting|approval|approve|May I|may I|permission|authoriz|confirm|should I|Should I|do you want|Do you want|would you like|shall I|Shall I|let me know|waiting on you|waiting for you|exception request|proceed|OK to |Ok to |okay to |sign off|your call|need a decision|which do you|or should|[Ss]elect one|[Cc]hoose|[Pp]ick one|yes or no";
pub(super) struct Pattern(libc::regex_t, libc::locale_t);
impl Pattern {
    pub(super) fn new(s: &str) -> Result<Self> {
        let s = std::ffi::CString::new(s).map_err(|e| e.to_string())?;
        let mut r = unsafe { std::mem::zeroed() };
        let mut locale =
            unsafe { libc::newlocale(libc::LC_ALL_MASK, c"".as_ptr(), std::ptr::null_mut()) };
        if locale.is_null() {
            locale =
                unsafe { libc::newlocale(libc::LC_ALL_MASK, c"C".as_ptr(), std::ptr::null_mut()) };
        }
        if locale.is_null() {
            return Err("cannot initialise pattern locale".into());
        }
        let previous = unsafe { libc::uselocale(locale) };
        let status =
            unsafe { libc::regcomp(&mut r, s.as_ptr(), libc::REG_EXTENDED | libc::REG_NEWLINE) };
        unsafe {
            libc::uselocale(previous);
        }
        if status != 0 {
            unsafe {
                libc::freelocale(locale);
            }
            return Err("invalid regex in --hot-file".into());
        }
        Ok(Self(r, locale))
    }
    fn last(&self, s: &str) -> Option<String> {
        last_match(std::slice::from_ref(self), s)
    }
}
fn last_match(patterns: &[Pattern], s: &str) -> Option<String> {
    let c = std::ffi::CString::new(s).ok()?;
    let mut offset = 0;
    let mut found = None;
    while offset <= s.len() {
        let mut best = None;
        for pattern in patterns {
            let mut m: libc::regmatch_t = unsafe { std::mem::zeroed() };
            let previous = unsafe { libc::uselocale(pattern.1) };
            let matched = unsafe {
                libc::regexec(
                    &pattern.0,
                    c.as_ptr().add(offset),
                    1,
                    &mut m,
                    if offset == 0 { 0 } else { libc::REG_NOTBOL },
                )
            };
            unsafe {
                libc::uselocale(previous);
            }
            if matched == 0 {
                let next = (offset + m.rm_so as usize, offset + m.rm_eo as usize);
                if best.is_none_or(|(a, b)| next.0 < a || (next.0 == a && next.1 > b)) {
                    best = Some(next);
                }
            }
        }
        let Some((a, b)) = best else { break };
        if a != b {
            found = s.get(a..b).map(str::to_owned);
            offset = b;
        } else {
            let Some(ch) = s.get(b..)?.chars().next() else {
                break;
            };
            offset = b + ch.len_utf8();
        }
    }
    found
}
fn hot_patterns(raw: &str) -> Result<Vec<Pattern>> {
    let rows: Vec<_> = raw
        .split_terminator('\n')
        .filter(|s| !s.trim().is_empty())
        .map(Pattern::new)
        .collect::<Result<_>>()?;
    if rows.is_empty() {
        return Err("--hot-file has no patterns".into());
    }
    Ok(rows)
}
impl Drop for Pattern {
    fn drop(&mut self) {
        unsafe {
            libc::regfree(&mut self.0);
            libc::freelocale(self.1);
        }
    }
}
#[derive(Default, Debug, Clone)]
struct Frame {
    state: &'static str,
    op: String,
    sig: String,
    win: String,
    model: String,
    turn: String,
    bound: String,
    nothing: bool,
}
fn footer(s: &str) -> bool {
    s.trim_start().starts_with("Fast on · ")
        || s.trim_start().starts_with("Fast off · ")
        || s.trim_start().starts_with("Fast on - ")
        || s.trim_start().starts_with("Fast off - ")
}
fn prompt(s: &str) -> bool {
    s.trim()
        .strip_prefix(['›', '»'])
        .is_some_and(|s| s.trim() == "Ask Codex to do anything")
}
fn operator(s: &str) -> bool {
    s.starts_with(['›', '»'])
}
fn fingerprint(s: &str) -> String {
    format!("{:x}", Sha256::digest(s.as_bytes()))[..12].into()
}
fn extract(capture: &str, height: usize) -> Frame {
    let all: Vec<_> = capture.split_terminator('\n').collect();
    let rows = &all[all.len().saturating_sub(height)..];
    let mut f = Frame {
        state: "unknown",
        ..Frame::default()
    };
    f.op = rows
        .iter()
        .rev()
        .find(|s| operator(s) && !prompt(s))
        .copied()
        .unwrap_or("")
        .into();
    if !f.op.is_empty() {
        f.sig = fingerprint(&format!("op:{}", f.op));
    }
    let anchor = rows
        .iter()
        .enumerate()
        .rev()
        .filter(|(_, s)| prompt(s))
        .find_map(|(i, _)| {
            rows[i + 1..]
                .iter()
                .position(|s| !s.trim().is_empty())
                .map(|j| (i, i + 1 + j))
                .filter(|(_, j)| footer(rows[*j]))
        });
    let Some((i, j)) = anchor else {
        let markers = [
            "No action is required",
            "Codex will keep waiting",
            "Retry with a faster model",
            "Dismiss and keep waiting",
            "thinking a bit more about this request",
        ];
        let modal_rows = rows
            .iter()
            .enumerate()
            .filter(|(i, s)| *i + 12 >= rows.len() && markers.iter().any(|m| s.contains(m)))
            .count();
        let menus = rows
            .iter()
            .filter(|s| {
                let s = s.trim_start().trim_start_matches(['›', '»']).trim_start();
                ["1.", "2.", "3."].iter().any(|p| {
                    s.strip_prefix(p)
                        .is_some_and(|r| r.starts_with(char::is_whitespace))
                })
            })
            .count();
        if modal_rows >= 2 && menus >= 2 && !rows.iter().any(|s| footer(s)) {
            f.state = "modal";
        }
        return f;
    };
    let parts: Vec<_> = rows[j]
        .trim_start()
        .split(if rows[j].contains(" · ") {
            " · "
        } else {
            " - "
        })
        .collect();
    f.model = format!("{}, {}", parts[0], parts.get(1).unwrap_or(&""));
    let win: Vec<_> = rows[i.saturating_sub(2)..=i]
        .iter()
        .filter(|s| !s.trim().is_empty())
        .copied()
        .collect();
    let win = win[win.len().saturating_sub(2)..].join("\n");
    f.win = fingerprint(&win);
    f.state = if win.contains("Messages to be submitted after next tool call") {
        "queued"
    } else if win.contains("Working (") || win.contains("esc to interrupt") {
        "busy"
    } else {
        "idle"
    };
    let body: Vec<_> = rows[..i]
        .iter()
        .filter(|s| !s.trim().is_empty())
        .copied()
        .collect();
    let turn = if let Some(b) = body.iter().rposition(|s| operator(s)) {
        f.nothing = b + 1 == body.len();
        &body[b + 1..]
    } else {
        f.bound="no user-input turn boundary on screen; showing the last 40 rows, the request may be older than this".into();
        &body[body.len().saturating_sub(40)..]
    };
    f.turn = turn
        .iter()
        .filter(|s| !s.trim().chars().all(|c| c == '─'))
        .copied()
        .collect::<Vec<_>>()
        .join("\n");
    if f.op.is_empty() {
        f.sig = fingerprint(&format!("txt:{}", f.turn));
    }
    f
}
struct Monitor {
    ack: String,
    last_sig: String,
    prev_win: String,
    base_model: String,
    warned: String,
    dgw: String,
    hot_turn: String,
    hot_seen: HashSet<String>,
    unknowns: u32,
    idle: u32,
    static_run: u64,
    alerts: usize,
    next: u64,
    noreply_since: u64,
    noreply_sig: String,
    last_hb: u64,
    last_valid: u64,
    poll: u64,
    noreply: u64,
    heartbeat: u64,
    hot: Vec<Pattern>,
    ask: Pattern,
}
impl Monitor {
    fn new(
        initial: &Frame,
        ack: bool,
        poll: u64,
        noreply: u64,
        heartbeat: u64,
        hot: Vec<Pattern>,
        now: u64,
    ) -> Self {
        Self {
            ack: if ack {
                initial.sig.clone()
            } else {
                String::new()
            },
            last_sig: initial.sig.clone(),
            prev_win: initial.win.clone(),
            base_model: initial.model.clone(),
            warned: String::new(),
            dgw: String::new(),
            hot_turn: String::new(),
            hot_seen: HashSet::new(),
            unknowns: 0,
            idle: 0,
            static_run: 0,
            alerts: 0,
            next: 0,
            noreply_since: 0,
            noreply_sig: String::new(),
            last_hb: now,
            last_valid: now,
            poll,
            noreply,
            heartbeat,
            hot,
            ask: Pattern::new(ASK).unwrap(),
        }
    }
    fn reset_geometry(&mut self) {
        self.idle = 0;
        self.static_run = 0;
        self.prev_win.clear();
    }
    fn step(&mut self, mut f: Frame, now: u64) -> (Vec<String>, Option<i32>) {
        let mut out = vec![];
        if !f.win.is_empty() && f.win == self.prev_win {
            self.static_run += 1;
        } else {
            self.static_run = 0;
            self.dgw.clear();
        }
        self.prev_win = f.win.clone();
        let forced = !["idle", "unknown", "modal"].contains(&f.state) && self.static_run >= 3;
        if forced {
            f.state = "idle";
            if self.dgw != f.win {
                out.push(format!(
                    "NOTICE: the status row claims work but has not moved in {}s; disbelieving it",
                    self.static_run * self.poll
                ));
                self.dgw = f.win.clone();
            }
        }
        if !self.ack.is_empty()
            && (["busy", "queued"].contains(&f.state) || (!f.sig.is_empty() && f.sig != self.ack))
        {
            self.ack.clear();
        }
        if !f.model.is_empty() {
            if !self.base_model.is_empty() && self.base_model != f.model {
                out.push(format!(
                    "*** MODEL/CONFIG CHANGED: [{}] -> [{}] :: HALT AND SURFACE ***",
                    self.base_model, f.model
                ));
            }
            self.base_model = f.model.clone();
        }
        if f.state == "modal" {
            self.unknowns = 0;
            self.idle = 0;
            self.last_valid = now;
            if self.warned != "modal" {
                out.push("NOTICE: the agent is showing a service modal. It states no action is required and it will keep waiting. Not idle, not dead.".into());
                self.warned = "modal".into();
            }
            return (out, None);
        }
        if self.warned == "modal" {
            self.warned.clear();
        }
        if f.state == "unknown" {
            self.unknowns += 1;
            self.idle = 0;
            if self.unknowns >= 4 {
                out.push(format!("The 'codex' grammar stopped recognising this pane for {}s. It may have exited, been replaced, or be rendering something this grammar cannot read.",self.unknowns as u64*self.poll));
                return (out, Some(2));
            }
            return (out, None);
        }
        self.unknowns = 0;
        self.last_valid = now;
        if !f.bound.is_empty() && f.bound != self.warned {
            out.push(format!("NOTICE: {}", f.bound));
            self.warned = f.bound.clone();
        }
        if f.sig != self.last_sig {
            self.idle = 0;
            self.alerts = 0;
            self.next = 0;
            self.noreply_since = 0;
            self.noreply_sig.clear();
            self.last_sig = f.sig.clone();
        }
        if f.op != self.hot_turn {
            self.hot_turn = f.op.clone();
            self.hot_seen.clear();
        }
        if let Some(hot) = f
            .turn
            .lines()
            .filter_map(|l| last_match(&self.hot, l))
            .next_back()
        {
            if self.hot_seen.insert(hot.clone()) {
                out.push(format!(
                    "HOT: {}",
                    hot.trim_start().chars().take(200).collect::<String>()
                ));
            }
        }
        if f.state == "idle" {
            self.idle += 1;
        } else {
            self.idle = 0;
            self.alerts = 0;
            self.next = 0;
        }
        if f.nothing && f.state == "idle" {
            if self.noreply_sig != f.sig {
                self.noreply_since = now;
                self.noreply_sig = f.sig.clone();
            }
            if now.saturating_sub(self.noreply_since) >= self.noreply {
                f.nothing = false;
                f.bound=format!("no reply since your last input for {}s; either it never arrived or the turn boundary is wrong",now.saturating_sub(self.noreply_since));
            }
        }
        if self.idle >= 2 && !f.nothing && f.sig != self.ack && now >= self.next {
            let q = f
                .turn
                .lines()
                .rev()
                .find(|l| l.trim_end().ends_with('?'))
                .unwrap_or("")
                .trim_start();
            let a = f
                .turn
                .lines()
                .rev()
                .find(|l| self.ask.last(l).is_some())
                .unwrap_or("")
                .trim_start();
            let why = if !q.is_empty() {
                "waiting on a DECISION from you"
            } else if !a.is_empty() {
                "idle, and its last turn reads like a request"
            } else {
                "idle with a completed, unacknowledged turn"
            };
            self.alerts += 1;
            self.next = now + [120, 300, 600][(self.alerts - 1).min(2)];
            out.push(">>>>>>>>>>  PANE RESPONSE MAY BE NEEDED  <<<<<<<<<<".into());
            out.push(format!(
                "is {why}. Review the pane and reply if appropriate. [alert #{}]",
                self.alerts
            ));
            if !q.is_empty() {
                out.push(format!(
                    "question: {}",
                    q.chars().take(200).collect::<String>()
                ));
            }
            if !a.is_empty() && a != q {
                out.push(format!(
                    "trigger: {}",
                    a.chars().take(200).collect::<String>()
                ));
            }
            let rows: Vec<_> = f.turn.lines().filter(|l| !l.trim().is_empty()).collect();
            let last = rows[rows.len().saturating_sub(2)..]
                .iter()
                .map(|s| s.trim_start().chars().take(160).collect::<String>())
                .collect::<Vec<_>>()
                .join("|");
            out.push(format!(
                "last: {}",
                if last.is_empty() {
                    "(turn text could not be extracted; treat as an unread wait)"
                } else {
                    &last
                }
            ));
            if !f.bound.is_empty() {
                out.push(format!("WARNING: {}", f.bound));
            }
            if forced {
                out.push(format!("WARNING: this idle was INFERRED; the status row claimed work but had not moved in {}s",self.static_run*self.poll));
            }
        }
        if now.saturating_sub(self.last_hb) >= self.heartbeat {
            out.push(format!(
                "HEALTH: coverage=valid ui=codex state={} last_valid={}s ago",
                f.state,
                now - self.last_valid
            ));
            self.last_hb = now;
        }
        (out, None)
    }
}
fn parse_height(row: &str, pane: &str, server: &str, process: &str) -> Result<usize> {
    let parts: Vec<_> = row.split(':').collect();
    if parts.len() != 4
        || !parts[0]
            .strip_prefix('%')
            .is_some_and(|s| !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()))
        || parts[1..]
            .iter()
            .any(|s| s.is_empty() || !s.bytes().all(|b| b.is_ascii_digit()))
    {
        return Err("invalid pane geometry".into());
    }
    if parts[0] != pane || parts[2] != server || parts[3] != process {
        return Err("target server or pane process identity changed".into());
    }
    parts[1].parse().map_err(|_| "invalid pane geometry".into())
}
fn read_sample(
    height: &mut impl FnMut() -> Result<usize>,
    capture: &mut impl FnMut() -> Result<String>,
    captured: impl FnOnce(),
) -> Result<(usize, usize, String)> {
    let before = height()?;
    let text = capture()?;
    captured();
    let after = height()?;
    Ok((before, after, text))
}
fn preflight(
    height: &mut impl FnMut() -> Result<usize>,
    capture: &mut impl FnMut() -> Result<String>,
    mut pause: impl FnMut(),
) -> Result<(usize, Frame)> {
    height()?;
    for attempt in 0..3 {
        let (before, after, text) = read_sample(height, capture, || {})?;
        if before == after {
            return Ok((before, extract(&text, before)));
        }
        if attempt < 2 {
            pause();
        }
    }
    Err("pane geometry will not hold still".into())
}
struct Geometry {
    height: usize,
    failures: usize,
    reseed: bool,
}
impl Geometry {
    fn new(height: usize) -> Self {
        Self {
            height,
            failures: 0,
            reseed: false,
        }
    }
    fn observe(
        &mut self,
        monitor: &mut Monitor,
        height: &mut impl FnMut() -> Result<usize>,
        capture: &mut impl FnMut() -> Result<String>,
        now: u64,
    ) -> (Vec<String>, Option<i32>) {
        let (before, after, text) = match read_sample(height, capture, || self.failures = 0) {
            Ok(sample) => sample,
            Err(e) => {
                self.failures += 1;
                monitor.reset_geometry();
                let code = if e.contains("identity changed") {
                    Some(2)
                } else if e.contains("timed out") || self.failures >= 5 {
                    Some(3)
                } else {
                    None
                };
                return (if code.is_some() { vec![e] } else { vec![] }, code);
            }
        };
        let mut rows = vec![];
        if before != after {
            rows.push(format!("NOTICE: pane resized during the capture ({before}r -> {after}r); discarding this observation"));
            self.height = after;
            monitor.reset_geometry();
            self.reseed |= !monitor.ack.is_empty();
            return (rows, None);
        }
        if before != self.height {
            rows.push(format!(
                "NOTICE: pane resized {}r -> {before}r; state unreliable for one cycle",
                self.height
            ));
            self.height = before;
            monitor.reset_geometry();
            self.reseed |= !monitor.ack.is_empty();
        }
        let frame = extract(&text, before);
        if self.reseed && !frame.sig.is_empty() {
            monitor.ack = frame.sig.clone();
            self.reseed = false;
        }
        let (out, code) = monitor.step(frame, now);
        rows.extend(out);
        (rows, code)
    }
}
struct Lock {
    path: PathBuf,
    pid: String,
    start: String,
}
impl Drop for Lock {
    fn drop(&mut self) {
        if fs::read_to_string(self.path.join("pid")).ok().as_deref() == Some(&self.pid)
            && fs::read_to_string(self.path.join("start")).ok().as_deref() == Some(&self.start)
        {
            let _ = fs::remove_file(self.path.join("pid"));
            let _ = fs::remove_file(self.path.join("start"));
            let _ = fs::remove_dir(&self.path);
        }
    }
}
fn lock(socket: &Path, server: &str, pane: &str, replace: bool) -> Result<Lock> {
    let root = PathBuf::from(setting("TMPDIR", "/tmp")).join("pane-watch-locks");
    private_dir(&root)?;
    if root.join(&pane[1..]).is_dir() {
        return Err("a legacy watcher lock exists; stop that watcher before rearming".into());
    }
    let path = root.join(format!(
        "{:x}-{}",
        Sha256::digest(format!("{}:{server}", socket.display()).as_bytes()),
        &pane[1..]
    ));
    if fs::create_dir(&path).is_err() {
        if !replace {
            return Err(format!(
                "another watcher already holds {pane} (lock: {}). Use --replace to take over.",
                path.display()
            ));
        }
        let owner =
            fs::read_to_string(path.join("pid")).map_err(|_| "lock has no valid owner PID")?;
        let owner = owner
            .trim()
            .parse::<u32>()
            .map_err(|_| "lock has no valid owner PID")?;
        if let Some(process) = crate::identity::kernel_process(owner) {
            let start = fs::read_to_string(path.join("start")).unwrap_or_default();
            let args = process_args(owner).ok_or("cannot verify the live watcher")?;
            let role = args.iter().any(|a| {
                a.ends_with("/pane-watch.sh")
                    || Path::new(a).file_name().is_some_and(|n| n == "pane-watch")
            }) || args.windows(2).any(|a| a == ["--surface", "pane-watch"]);
            if !role
                || start.trim() != process_start(owner)
                || crate::identity::kernel_process(owner) != Some(process)
            {
                return Err("live lock owner cannot be verified as this watcher".into());
            }
            println!("NOTICE: requesting a safe handoff from watcher PID {owner} for {pane}");
            if unsafe { libc::kill(owner as i32, libc::SIGTERM) } != 0 {
                return Err("cannot stop existing watcher".into());
            }
            let deadline = Instant::now() + Duration::from_secs(5);
            while path.is_dir() && Instant::now() < deadline {
                std::thread::sleep(Duration::from_millis(100));
            }
            if path.is_dir() {
                return Err(
                    "existing watcher did not release its lock; no replacement was started".into(),
                );
            }
        } else {
            for name in ["pid", "start"] {
                let _ = fs::remove_file(path.join(name));
            }
            fs::remove_dir(&path)
                .map_err(|_| "stale lock contains unexpected files; inspect it before replacing")?;
        }
        fs::create_dir(&path).map_err(|e| e.to_string())?;
    }
    let pid = format!("{}\n", std::process::id());
    let start = format!("{}\n", process_start(std::process::id()));
    let guard = Lock { path, pid, start };
    write(&guard.path.join("pid"), &guard.pid)?;
    write(&guard.path.join("start"), &guard.start)?;
    Ok(guard)
}
fn run(args: &[String]) -> std::result::Result<i32, (i32, String)> {
    let mut target = String::new();
    let mut ui = String::new();
    let mut hotfile = String::new();
    let (mut ack, mut replace) = (false, false);
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--pane" | "--ui" | "--hot-file" => {
                let value = args
                    .get(i + 1)
                    .filter(|v| !v.is_empty() && !v.starts_with("--"))
                    .ok_or((64, USAGE.into()))?
                    .clone();
                match args[i].as_str() {
                    "--pane" => target = value,
                    "--ui" => ui = value,
                    _ => hotfile = value,
                }
                i += 2;
            }
            "--ack-current" => {
                ack = true;
                i += 1;
            }
            "--replace" => {
                replace = true;
                i += 1;
            }
            _ => return Err((64, USAGE.into())),
        }
    }
    if target.is_empty() || ui.is_empty() {
        return Err((64, USAGE.into()));
    }
    if ui != "codex" {
        return Err((1, format!("unsupported --ui '{ui}'. Supported: codex")));
    }
    let poll = integer("PW_POLL", 3, u64::MAX / 1000, true).map_err(|e| (64, e))?;
    let noreply = integer("PW_NOREPLY", 60, u64::MAX, true).map_err(|e| (64, e))?;
    let heartbeat = integer("PW_HEARTBEAT", 1800, u64::MAX, true).map_err(|e| (64, e))?;
    let seconds = integer("PW_TMUX_TIMEOUT", 2, 10, false).map_err(|e| (64, e))?;
    let hot = if hotfile.is_empty() {
        vec![Pattern::new(HOT).unwrap()]
    } else {
        let raw = fs::read_to_string(&hotfile).map_err(|e| (1, e.to_string()))?;
        hot_patterns(&raw).map_err(|e| (1, e))?
    };
    let socket = socket();
    let q = |args: &[&str]| query(&socket, args, seconds).map_err(|e| (1, e));
    let pane = q(&["display-message", "-p", "-t", &target, "#{pane_id}"])?;
    if !pane.starts_with('%')
        || pane[1..].is_empty()
        || !pane[1..].bytes().all(|b| b.is_ascii_digit())
    {
        return Err((1, "target does not resolve to a pane".into()));
    }
    let candidates = q(&["list-panes", "-t", &target, "-F", "#{pane_id}"])?;
    if !candidates.lines().any(|s| s == pane)
        || q(&["list-panes", "-a", "-F", "#{pane_id}"])?
            .lines()
            .filter(|s| *s == pane)
            .count()
            != 1
    {
        return Err((1, "target did not resolve uniquely".into()));
    }
    if pane == env("TMUX_PANE") {
        return Err((1, format!("refusing to watch my own pane ({pane})")));
    }
    let info=q(&["display-message","-p","-t",&pane,"#{pane_id} #{pane_dead} #{pane_current_command} #{session_name} #{window_name} #{pane_current_path}"])?;
    let fields: Vec<_> = info.splitn(6, ' ').collect();
    if fields.len() != 6 || fields[0] != pane || fields[1] != "0" {
        return Err((1, "pane identity changed or pane is dead".into()));
    }
    let identity = q(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{pane_id}:#{pid}:#{pane_pid}",
    ])?;
    let ids: Vec<_> = identity.split(':').collect();
    if ids.len() != 3
        || ids[0] != pane
        || ids[1..]
            .iter()
            .any(|s| s.is_empty() || !s.bytes().all(|b| b.is_ascii_digit()))
    {
        return Err((1, "cannot identify target process".into()));
    }
    let socket_check = q(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{pane_id}:#{socket_path}",
    ])?;
    let socket_check = socket_check
        .strip_prefix(&format!("{pane}:"))
        .ok_or((1, "cannot identify tmux socket".into()))?;
    let socket = PathBuf::from(socket_check);
    if !socket.is_absolute() {
        return Err((1, "cannot identify tmux socket".into()));
    }
    let _guard = lock(&socket, ids[1], &pane, replace).map_err(|e| (1, e))?;
    let mut height = || -> Result<usize> {
        let row = query(
            &socket,
            &[
                "display-message",
                "-p",
                "-t",
                &pane,
                "#{pane_id}:#{pane_height}:#{pid}:#{pane_pid}",
            ],
            seconds,
        )?;
        parse_height(&row, &pane, ids[1], ids[2])
    };
    let mut capture = || {
        let o = tmux(
            &socket,
            &["capture-pane", "-p", "-t", &pane, "-S", "-400"],
            seconds,
        )?;
        if o.code == 0 {
            Ok(o.text())
        } else {
            Err(if o.code == 124 {
                "tmux request timed out".into()
            } else {
                String::from_utf8_lossy(&o.err).into_owned()
            })
        }
    };
    let (initial_height, first) = preflight(&mut height, &mut capture, || {
        std::thread::sleep(Duration::from_secs(1));
    })
    .map_err(|e| (1, e))?;
    if first.state == "unknown" {
        return Err((
            1,
            format!("the 'codex' grammar does not recognise pane {pane} ({info})"),
        ));
    }
    println!(
        "ARMED codex on {pane} ({}:{}, {}, {})",
        fields[3], fields[4], fields[2], fields[5]
    );
    println!(
        "      live={initial_height}r state={} model={} hot={} startup-ack={}",
        first.state,
        first.model,
        if hotfile.is_empty() {
            "built-in"
        } else {
            &hotfile
        },
        u8::from(ack)
    );
    let mut monitor = Monitor::new(
        &first,
        ack,
        poll,
        noreply,
        heartbeat,
        hot,
        (epoch_ms() / 1000) as u64,
    );
    let mut geometry = Geometry::new(initial_height);
    SIGNAL.store(0, Ordering::Relaxed);
    unsafe {
        libc::signal(libc::SIGINT, interrupted as *const () as libc::sighandler_t);
        libc::signal(
            libc::SIGTERM,
            interrupted as *const () as libc::sighandler_t,
        );
    }
    loop {
        let until = Instant::now() + Duration::from_secs(poll);
        while Instant::now() < until && SIGNAL.load(Ordering::Relaxed) == 0 {
            std::thread::sleep(
                until
                    .saturating_duration_since(Instant::now())
                    .min(Duration::from_millis(50)),
            );
        }
        let signal = SIGNAL.load(Ordering::Relaxed);
        if signal != 0 {
            return Ok(128 + signal);
        }
        let (rows, code) = geometry.observe(
            &mut monitor,
            &mut height,
            &mut capture,
            (epoch_ms() / 1000) as u64,
        );
        for row in &rows {
            println!("{row}");
        }
        if let Some(code) = code {
            coverage(
                &pane,
                rows.last()
                    .map(String::as_str)
                    .unwrap_or("unknown observation"),
            );
            return Ok(code);
        }
    }
}

#[cfg(test)]
#[path = "watch_parity_tests.rs"]
mod parity_tests;
fn coverage(pane: &str, reason: &str) {
    println!(">>>>>>>>>>  WATCH COVERAGE LOST  <<<<<<<<<<\n{reason}\nPane {pane} is NO LONGER BEING WATCHED.\nNothing will alert you until this is re-armed.");
}
pub(crate) fn entry(args: &[String]) -> i32 {
    match run(args) {
        Ok(c) => c,
        Err((c, e)) => {
            eprintln!("REFUSE: {e}");
            c
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn replay(name: &str, ack: bool) -> Vec<String> {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tools/pane-watch/tests/fx")
            .join(name);
        let max = fs::read_dir(&root)
            .unwrap()
            .filter_map(|e| e.ok())
            .filter_map(|e| {
                e.file_name()
                    .to_string_lossy()
                    .split('.')
                    .next()?
                    .parse::<usize>()
                    .ok()
            })
            .max()
            .unwrap();
        let first = extract(&fixture(name, 1), 59);
        assert_ne!(first.state, "unknown", "{name} never armed");
        let mut m = Monitor::new(
            &first,
            ack,
            0,
            60,
            1800,
            vec![Pattern::new(HOT).unwrap()],
            0,
        );
        let mut rows = Vec::new();
        for n in 2..max + 12 {
            let (out, code) = m.step(extract(&fixture(name, n.min(max)), 59), 0);
            rows.extend(out);
            if code.is_some() {
                rows.push("WATCH COVERAGE LOST".into());
                break;
            }
        }
        rows
    }
    #[test]
    fn complete_fixture_alarm_matrix() {
        for name in [
            "startup_wait",
            "phase_race",
            "stale_queued",
            "working_text",
            "unmatched_decision",
            "content_busy_static",
            "composer_request_erased",
            "completed_idle",
            "real_geometry",
            "anchor_decoy",
        ] {
            let rows = replay(name, false);
            assert!(
                rows.iter()
                    .any(|s| s.contains("PANE RESPONSE MAY BE NEEDED")),
                "{name}: {rows:?}"
            );
        }
        for (name, n) in [
            ("dedup_repeat", 2),
            ("fast_backoff", 2),
            ("empty_turn", 0),
            ("unknown_gap", 0),
        ] {
            let rows = replay(name, false);
            assert_eq!(
                rows.iter()
                    .filter(|s| s.contains("PANE RESPONSE MAY BE NEEDED"))
                    .count(),
                n,
                "{name}: {rows:?}"
            );
        }
        for name in ["stale_deep_restart", "padding_stale", "service_modal"] {
            let rows = replay(name, false);
            assert!(
                !rows
                    .iter()
                    .any(|s| s.contains("PANE RESPONSE MAY BE NEEDED")),
                "{name}: {rows:?}"
            );
        }
        assert!(!replay("user_input_false_fire", false)
            .iter()
            .any(|s| s.contains("my approval")));
        for name in ["ack_spent_observed", "ack_unknown", "ack_filter"] {
            let rows = replay(name, true);
            assert!(
                rows.iter()
                    .any(|s| s.contains("PANE RESPONSE MAY BE NEEDED")),
                "{name}: {rows:?}"
            );
        }
        for (name, n) in [("hot_same_new_turn", 2), ("hot_dash", 1)] {
            let rows = replay(name, false);
            assert_eq!(
                rows.iter().filter(|s| s.starts_with("HOT:")).count(),
                n,
                "{name}: {rows:?}"
            );
        }
        for name in ["process_gone", "stale_deep_restart"] {
            assert!(
                replay(name, false)
                    .iter()
                    .any(|s| s == "WATCH COVERAGE LOST"),
                "{name}"
            );
        }
        assert!(replay("real_geometry", false)
            .iter()
            .any(|s| s.contains("PANE RESPONSE MAY")));
    }
    pub(super) fn fixture(name: &str, n: usize) -> String {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tools/pane-watch/tests/fx")
            .join(name);
        fs::read_to_string(root.join(format!("{n}.full")))
            .or_else(|_| fs::read_to_string(root.join(format!("{n}.vis"))))
            .unwrap()
    }
    #[test]
    fn frame_structures() {
        for (name, state) in [
            ("real_geometry", "idle"),
            ("service_modal", "modal"),
            ("ground_busy", "busy"),
            ("ground_queue", "queued"),
        ] {
            let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../tools/pane-watch/tests/fx")
                .join(name);
            if root.exists() {
                let f = extract(&fixture(name, 1), 59);
                assert_eq!(f.state, state, "{name}");
            }
        }
    }
    #[test]
    fn modal_requires_structure() {
        for name in [
            "modal_no_anchor_content",
            "modal_two_on_one_row",
            "modal_two_prose_rows",
        ] {
            assert_ne!(extract(&fixture(name, 1), 59).state, "modal", "{name}");
        }
    }
    #[test]
    fn preserved_padding() {
        let raw = format!(
            "› hi\nanswer\n› Ask Codex to do anything\n\nFast off · model\n{}",
            "\n".repeat(60)
        );
        assert_eq!(extract(&raw, 59).state, "unknown");
    }
    #[test]
    fn activity_spends_ack() {
        let idle = extract(
            "› request\nanswer\n› Ask Codex to do anything\n\nFast off · model\n",
            59,
        );
        let mut m = Monitor::new(
            &idle,
            true,
            3,
            60,
            1800,
            vec![Pattern::new(HOT).unwrap()],
            0,
        );
        assert!(!m
            .step(idle.clone(), 3)
            .0
            .iter()
            .any(|s| s.contains("RESPONSE MAY")));
        let mut busy = idle.clone();
        busy.state = "busy";
        busy.win = "busy".into();
        m.step(busy, 6);
        m.step(idle.clone(), 9);
        assert!(m
            .step(idle, 12)
            .0
            .iter()
            .any(|s| s.contains("RESPONSE MAY")));
    }
}
