use crate::{
    composer,
    identity::{self, Namespace, Target},
    store::{
        self, Attribution, Budgets, Code, Evidence, NoEffectProof, Ownership, Peer, Source, State,
        Store,
    },
};
use identity::Result;
use std::fs::File;
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::fs::MetadataExt;
use std::process::{Child, ChildStdin, Command, ExitStatus, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub fn validate_budgets(b: &Budgets) -> Result<()> {
    let now = Instant::now();
    for ms in [b.stop_ms, b.drain_ms, b.reap_ms, b.decision_ms] {
        if ms == 0 || ms > i64::MAX as u64 || now.checked_add(Duration::from_millis(ms)).is_none() {
            return Err("invalid cleanup budgets".into());
        }
    }
    Ok(())
}
struct Reader {
    file: File,
    bytes: Vec<u8>,
    eof: bool,
}
impl Reader {
    fn new(file: File) -> Result<Self> {
        let flags = unsafe { libc::fcntl(file.as_raw_fd(), libc::F_GETFL) };
        if flags < 0
            || unsafe { libc::fcntl(file.as_raw_fd(), libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0
        {
            return Err("nonblocking output unavailable".into());
        }
        Ok(Self {
            file,
            bytes: Vec::new(),
            eof: false,
        })
    }
    fn poll(&mut self) -> Result<()> {
        if self.eof || self.bytes.len() >= 65536 {
            return Ok(());
        }
        let mut bytes = [0u8; 4096];
        let limit = bytes.len().min(65536 - self.bytes.len());
        match self.file.read(&mut bytes[..limit]) {
            Ok(0) => self.eof = true,
            Ok(n) => self.bytes.extend_from_slice(&bytes[..n]),
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => (),
            Err(e) => return Err(e.to_string()),
        }
        Ok(())
    }
}
struct OwnedChild {
    child: Child,
    owner: identity::ProcessIdentity,
    identity: Option<identity::ProcessIdentity>,
    readers: Vec<Reader>,
    status: Option<ExitStatus>,
    reader_fault: bool,
}
impl OwnedChild {
    fn spawn(command: &mut Command) -> Result<Self> {
        let owner = identity::kernel_process(std::process::id()).ok_or("owner unavailable")?;
        command.stdout(Stdio::piped()).stderr(Stdio::piped());
        let mut child = command.spawn().map_err(|e| e.to_string())?;
        let identity = identity::kernel_process(child.id());
        let mut readers = Vec::new();
        let mut reader_fault = false;
        if let Some(pipe) = child.stdout.take() {
            match Reader::new(File::from(OwnedFd::from(pipe))) {
                Ok(r) => readers.push(r),
                Err(_) => reader_fault = true,
            }
        }
        if let Some(pipe) = child.stderr.take() {
            match Reader::new(File::from(OwnedFd::from(pipe))) {
                Ok(r) => readers.push(r),
                Err(_) => reader_fault = true,
            }
        }
        Ok(Self {
            child,
            owner,
            identity,
            readers,
            status: None,
            reader_fault,
        })
    }
    fn owner_live(&self) -> bool {
        identity::kernel_process(std::process::id()).is_some_and(|p| p.same(self.owner))
    }
    fn poll(&mut self) -> Result<bool> {
        if !self.owner_live() {
            return Err("child owner changed".into());
        }
        if let Some(live) = identity::kernel_process(self.child.id()) {
            if self.identity.is_none_or(|expected| !live.same(expected))
                || live.parent != self.owner.pid
            {
                return Err("child generation changed".into());
            }
        }
        if self.status.is_none() {
            self.status = self.child.try_wait().map_err(|e| e.to_string())?;
        }
        for r in &mut self.readers {
            r.poll()?;
        }
        if self.reader_fault {
            return Err("output unreadable".into());
        }
        Ok(self.status.is_some() && self.readers.iter().all(|r| r.eof))
    }
    fn stop(&mut self) -> Result<()> {
        self.child.stdin.take();
        if self.status.is_some() {
            return Ok(());
        }
        // EOF cancels an undispatched producer. Never signal even an owned PID.
        Ok(())
    }
    fn cleanup(&mut self, b: &Budgets) -> Vec<String> {
        let start = Instant::now();
        let decision = start + Duration::from_millis(b.decision_ms);
        let mut notes = Vec::new();
        if self.stop().is_err() {
            notes.push("stop-unconfirmed".into());
        }
        for (ms, stage) in [
            (b.stop_ms, "stop-unconfirmed"),
            (b.drain_ms, "incomplete-output"),
            (b.reap_ms, "unreaped"),
        ] {
            let deadline = (Instant::now() + Duration::from_millis(ms)).min(decision);
            loop {
                let complete = self.poll().unwrap_or(false);
                let done = if stage == "incomplete-output" {
                    complete
                } else {
                    self.status.is_some()
                };
                if done {
                    break;
                }
                if Instant::now() >= deadline {
                    notes.push(stage.into());
                    break;
                }
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        if Instant::now() >= decision {
            notes.push("decision deadline reached".into());
        }
        notes
    }
}
pub fn capture(command: &mut Command) -> Result<Vec<u8>> {
    capture_for(command, Duration::from_secs(2))
}
pub(crate) fn capture_for(command: &mut Command, timeout: Duration) -> Result<Vec<u8>> {
    command.stdin(Stdio::null());
    let mut child = OwnedChild::spawn(command)?;
    let deadline = Instant::now() + timeout;
    let result = (|| {
        while Instant::now() < deadline {
            if child.poll()? {
                if !child.status.is_some_and(|s| s.success()) {
                    return Err("command refused".into());
                }
                return Ok(std::mem::take(&mut child.readers[0].bytes));
            }
            std::thread::sleep(Duration::from_millis(1));
        }
        Err("command outcome unproved".into())
    })();
    if result.is_err() {
        child.cleanup(&Budgets {
            stop_ms: 30,
            drain_ms: 30,
            reap_ms: 30,
            decision_ms: 90,
        });
    }
    result
}

pub fn producer_entry(args: &[String]) -> i32 {
    let result = (|| -> Result<()> {
        let socket = std::path::Path::new(args.first().ok_or("producer socket absent")?);
        let words: Vec<_> = args[1..].iter().map(String::as_str).collect();
        identity::validate_delivery(&words, false)?;
        let ns = identity::connect_delivery(socket)?;
        let mut release = [0; 3];
        std::io::stdin()
            .read_exact(&mut release)
            .map_err(|e| e.to_string())?;
        if release != *b"go\n" {
            return Err("producer release refused".into());
        }
        let output = ns.command(&words)?;
        std::io::stdout()
            .write_all(output.as_bytes())
            .map_err(|e| e.to_string())
    })();
    match result {
        Ok(()) => 0,
        Err(error) => {
            eprintln!("relay: {error}");
            1
        }
    }
}
struct Producer {
    child: OwnedChild,
    input: Option<ChildStdin>,
}
impl Producer {
    fn spawn(ns: &Namespace, args: &[&str]) -> Result<Self> {
        ns.verify()?;
        let executable = std::env::current_exe().map_err(|e| e.to_string())?;
        #[cfg(test)]
        let executable = executable
            .parent()
            .and_then(|p| p.parent())
            .ok_or("test executable parent")?
            .join("angelstar-runtime");
        let mut command = Command::new(executable);
        command
            .arg("--delivery-producer")
            .arg(ns.socket())
            .args(args)
            .stdin(Stdio::piped());
        let mut child = OwnedChild::spawn(&mut command)?;
        let input = child.child.stdin.take();
        Ok(Self { child, input })
    }
    fn execute(&mut self) -> Result<String> {
        self.input
            .take()
            .ok_or("producer input absent")?
            .write_all(b"go\n")
            .map_err(|e| e.to_string())?;
        let deadline = Instant::now() + Duration::from_secs(2);
        while Instant::now() < deadline {
            if self.child.poll()? {
                if !self.child.status.is_some_and(|s| s.success()) {
                    return Err("producer refused".into());
                }
                return String::from_utf8(self.child.readers[0].bytes.clone())
                    .map_err(|e| e.to_string());
            }
            std::thread::sleep(Duration::from_millis(1));
        }
        Err("producer outcome unproved".into())
    }
}
pub fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}
pub fn no_focus_condition(pane: &str) -> String {
    let sessions="#{S:#{?#{&&:#{session_attached},#{window_active},#{pane_active},#{==:#{pane_id},PANE}},1,0}}".replace("PANE",pane);
    let clients = "#{L:#{?#{m:*active-pane*,#{client_flags}},1,0}}";
    format!("#{{&&:#{{==:#{{m:*1*,{sessions}}},0}},#{{==:#{{m:*1*,{clients}}},0}}}}")
}
pub fn no_activity_condition(second: u64) -> String {
    let clients=format!("#{{L:#{{?#{{&&:#{{e|>:#{{client_activity}},0}},#{{e|<:#{{client_activity}},{second}}}}},0,1}}}}");
    format!("#{{==:#{{m:*1*,{clients}}},0}}")
}
pub fn fresh_id() -> Result<String> {
    let mut bytes = [0u8; 16];
    File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut bytes))
        .map_err(|e| e.to_string())?;
    Ok(bytes.iter().map(|b| format!("{b:02x}")).collect())
}
pub fn normalize(s: &str) -> Result<String> {
    if s.chars()
        .any(|c| c.is_control() && !c.is_whitespace() && !matches!(c, '\u{1c}'..='\u{1f}'))
    {
        return Err("control input".into());
    }
    let normalized = s
        .split(|c: char| c.is_whitespace() || matches!(c, '\u{1c}'..='\u{1f}'))
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join(" ");
    if normalized.is_empty() {
        return Err("empty message".into());
    }
    Ok(normalized)
}
fn overflow_pointer(label: &str, codes: &str, path: &std::path::Path) -> String {
    let compact = identity::account_home()
        .ok()
        .and_then(|home| path.strip_prefix(home).ok())
        .map(|suffix| format!("~/{}", suffix.display()))
        .unwrap_or_else(|| path.display().to_string());
    format!("{label}: {codes} read and execute; do not forward: {compact}")
}
pub struct Prepared {
    pub(crate) client: Option<char>,
    id: String,
    message: String,
    target: Target,
    source: Option<Target>,
    source_pane: Option<String>,
    ancestry: Vec<identity::ProcessIdentity>,
    attribution: Attribution,
    wire: String,
}
impl Prepared {
    pub fn new(
        ns: &Namespace,
        session: &str,
        window: &str,
        pane: Option<identity::PaneId>,
        message: &str,
    ) -> Result<Self> {
        let snapshot = ns.capture()?;
        let ancestry = identity::kernel_ancestry(std::process::id())?;
        let parents = ancestry.iter().map(|p| (p.pid, p.parent)).collect();
        let source_pane = std::env::var("TMUX_PANE").ok();
        let source = identity::source_context(
            &snapshot,
            std::process::id(),
            &parents,
            source_pane.as_deref(),
        );
        let session = if session.is_empty() {
            source
                .as_ref()
                .ok_or("caller session unavailable")?
                .session_name
                .as_str()
        } else {
            session
        };
        let target = identity::resolve(&snapshot, session, window, pane)?;
        for p in &ancestry {
            if snapshot
                .targets
                .iter()
                .filter(|t| !t.pane.dead && t.pane.pid == p.pid)
                .count()
                > 1
            {
                return Err("ambiguous source".into());
            }
        }

        if source.as_ref() == Some(&target) {
            return Err("self-send refused".into());
        }
        let label = source.as_ref().map_or("relay".into(), |s| {
            format!(
                "{} ({}:{})",
                s.window.name.escape_debug(),
                s.session_name.escape_debug(),
                s.window.name.escape_debug()
            )
        });
        let mut codes = Vec::new();
        let mut normalized = normalize(message)?;
        for (i, _) in normalized.match_indices('#') {
            let value: String = normalized[i + 1..]
                .chars()
                .take_while(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '-'))
                .collect();
            if !value.is_empty() && !codes.iter().any(|c: &Code| c.value == value) {
                codes.push(Code {
                    value,
                    generated: false,
                });
            }
        }
        let id = fresh_id()?;
        if codes.is_empty() {
            let value = id[..6].to_owned();
            normalized = format!("#{value} {normalized}");
            codes.push(Code {
                value,
                generated: true,
            });
        }
        let source_proof = match &source {
            None => Source::Tool,
            Some(s) => Source::Known {
                identity: format!("{}:{}:{}", s.session_id.0, s.window.id.0, s.pane.id.0),
                generation: identity::kernel_process(s.pane.pid)
                    .ok_or("source disappeared")?
                    .generation()?,
                label: label.clone(),
            },
        };
        let prepared = Self {
            client: None,
            id,
            message: normalized.clone(),
            target,
            source,
            source_pane,
            ancestry,
            attribution: Attribution {
                source: source_proof,
                label: label.clone(),
                codes,
            },
            wire: format!("{label}: {normalized}"),
        };
        prepared.verify(ns)?;
        Ok(prepared)
    }
    fn verify(&self, ns: &Namespace) -> Result<()> {
        ns.verify()?;
        let snapshot = ns.capture()?;
        if !snapshot.targets.contains(&self.target)
            || !self
                .ancestry
                .iter()
                .all(|p| identity::kernel_process(p.pid) == Some(*p))
        {
            return Err("target or source changed".into());
        }
        let parents = self.ancestry.iter().map(|p| (p.pid, p.parent)).collect();
        if identity::source_context(
            &snapshot,
            std::process::id(),
            &parents,
            self.source_pane.as_deref(),
        ) != self.source
        {
            return Err("source changed".into());
        }
        if let (Some(source), Source::Known { generation, .. }) =
            (&self.source, &self.attribution.source)
        {
            if identity::kernel_process(source.pane.pid).and_then(|p| p.generation().ok())
                != Some(*generation)
            {
                return Err("source generation changed".into());
            }
        }
        Ok(())
    }
}
struct View {
    receipt: composer::Receipt,
    bytes: Vec<u8>,
    busy: bool,
    copy: bool,
    width: u64,
    height: u64,
    x: u64,
    y: u64,
}
pub struct Runtime<'a> {
    ns: &'a Namespace,
    prepared: Prepared,
    store: &'a mut Store,
    handle: store::AttemptHandle,
    id: String,
    archive: String,
    state: State,
    peer: Peer,
    client: Result<identity::Client>,
    lock: Option<File>,
    marked: bool,
    producers: Vec<Producer>,
    evidence: Evidence,
    geometry: Option<(u64, u64, u64)>,
    closed: bool,
    receipt_before: Option<composer::Receipt>,
    ready_since: Option<(Instant, u64, u64, u64)>,
    binding_since: Instant,
    #[cfg(test)]
    fixture: Option<std::path::PathBuf>,
    #[cfg(test)]
    before_enter: Option<Box<dyn FnMut() -> Result<()> + 'a>>,
}
impl<'a> Runtime<'a> {
    pub fn reader_record(&mut self) -> Result<(State, std::path::PathBuf)> {
        let target = &self.prepared.target;
        self.store
            .reader_record(
                &self.id,
                store::ReaderTarget {
                    session_name: target.session_name.clone(),
                    window_name: target.window.name.clone(),
                    pane_id: target.selector(),
                    pane_pid: target.pane.pid.to_string(),
                },
                self.prepared.message.clone(),
            )
            .map_err(|e| format!("reader record: {e:?}"))
    }
    pub fn ids(&self) -> (&str, &str) {
        (&self.id, &self.archive)
    }
    pub fn accept(
        ns: &'a Namespace,
        mut prepared: Prepared,
        store: &'a mut Store,
        original: &[u8],
        budgets: Budgets,
    ) -> Result<Self> {
        validate_budgets(&budgets)?;
        prepared.verify(ns)?;
        let pane = prepared.target.selector();
        let metadata = ns.command(&[
            "display-message",
            "-p",
            "-t",
            &pane,
            "#{pane_width}|#{pane_height}|#{cursor_x}|#{cursor_y}",
        ])?;
        let v: Vec<u64> = metadata
            .trim()
            .split('|')
            .map(str::parse::<u64>)
            .collect::<std::result::Result<_, _>>()
            .map_err(|e| e.to_string())?;
        if v.len() != 4 || v[0] <= 10 || v[1] == 0 || v[2] >= v[0] || v[3] >= v[1] {
            return Err("unknown capacity".into());
        }
        let archive = fresh_id()?;
        let id = prepared.id.clone();
        if !prepared.wire.is_ascii() || prepared.wire.len() as u64 > v[0] - 3 {
            let codes = prepared
                .attribution
                .codes
                .iter()
                .map(|c| format!("#{}", c.value))
                .collect::<Vec<_>>()
                .join(" ");
            prepared.wire = overflow_pointer(
                &prepared.attribution.label,
                &codes,
                &store.original_path(&archive),
            );
        }
        let socket = std::fs::symlink_metadata(ns.socket()).map_err(|e| e.to_string())?;
        let process =
            identity::kernel_process(prepared.target.pane.pid).ok_or("target owner absent")?;
        let peer = Peer {
            socket_device: socket.dev(),
            socket_inode: socket.ino(),
            server_generation: ns.server().generation()?,
            session: prepared.target.session_id.0,
            window: prepared.target.window.id.0,
            pane: prepared.target.pane.id.0,
            pane_generation: process.generation()?,
        };
        let published = store
            .publish(
                &archive,
                original,
                prepared.wire.as_bytes(),
                prepared.attribution.clone(),
            )
            .map_err(|e| format!("publication {archive}: {e:?}"))?;
        let handle = store
            .accept(
                published,
                store::Acceptance {
                    id: &id,
                    request: &fresh_id()?,
                    peer,
                },
            )
            .map_err(|e| format!("acceptance {id}: {e:?}"))?;
        let client = identity::Client::bind(process.pid);
        Ok(Self {
            ns,
            prepared,
            store,
            handle,
            id,
            archive,
            state: State::PendingNoInput,
            peer,
            client,
            lock: None,
            marked: false,
            producers: Vec::new(),
            evidence: Evidence {
                budgets: Some(budgets),
                ..Default::default()
            },
            geometry: None,
            closed: false,
            receipt_before: None,
            ready_since: None,
            binding_since: Instant::now(),
            #[cfg(test)]
            fixture: tests::cli_fixture(),
            #[cfg(test)]
            before_enter: None,
        })
    }
    fn verify(&self) -> Result<()> {
        self.prepared.verify(self.ns)?;
        if identity::kernel_process(self.prepared.target.pane.pid)
            .ok_or("target owner missing")?
            .generation()?
            != self.peer.pane_generation
        {
            return Err("pane epoch changed".into());
        }
        Ok(())
    }
    fn commit(&mut self, state: State, e: Evidence) -> Result<State> {
        checkpoint(&format!("{state:?}:before-commit"));
        self.store
            .transition(&mut self.handle, state, e)
            .map_err(|e| format!("transition {}: {e:?}", self.id))?;
        self.state = state;
        checkpoint(&format!("{state:?}:after-commit"));
        Ok(state)
    }
    fn no_input(&mut self, reason: &str) -> Result<State> {
        self.commit(
            State::TerminalNoInput,
            Evidence {
                diagnostics: vec![reason.into()],
                ..Default::default()
            },
        )
    }
    fn unknown(&mut self, reason: &str) -> Result<State> {
        self.commit(
            State::InputUnknown,
            Evidence {
                diagnostics: vec![reason.into()],
                ..Default::default()
            },
        )
    }
    fn view(&self) -> Result<View> {
        self.verify()?;
        #[cfg(test)]
        if let Some(path) = &self.fixture {
            return tests::fixture_view(self.ns, &self.prepared, path);
        }
        let client = self
            .client
            .as_ref()
            .map_err(|e| format!("client-bind: {e}"))?;
        client.current()?;
        if self
            .prepared
            .client
            .is_some_and(|glyph| glyph != client.glyph)
        {
            return Err("target client does not match helper".into());
        }
        let pane = self.prepared.target.selector();
        let format="#{cursor_x}|#{cursor_y}|#{pane_width}|#{pane_height}|#{pane_dead}|#{pane_in_mode}|#{version}";
        let meta = self
            .ns
            .command(&["display-message", "-p", "-t", &pane, format])?;
        let v: Vec<&str> = meta.trim().split('|').collect();
        if v.len() != 7 || v[4] != "0" || v[6] != "3.7c" {
            return Err("unsupported renderer metadata".into());
        }
        let parse = |i: usize| v[i].parse::<u64>().map_err(|e| e.to_string());
        let x = parse(0)?;
        let y = parse(1)?;
        let width = parse(2)?;
        let height = parse(3)?;
        let copy = v[5] != "0";
        if width <= 10 || height == 0 || x >= width || y >= height {
            return Err("unknown geometry".into());
        }
        let capture = self
            .ns
            .command(&["capture-pane", "-p", "-e", "-t", &pane])?;
        if self
            .ns
            .command(&["display-message", "-p", "-t", &pane, format])?
            != meta
        {
            return Err("renderer changed during capture".into());
        }
        client.current()?;
        let (bytes, busy) = match composer::screen(
            client.glyph,
            &capture,
            x as usize,
            y as usize,
            width as usize,
            &self.prepared.wire,
        ) {
            composer::Screen::Empty => (
                Vec::new(),
                !composer::ready(
                    client.glyph,
                    &capture,
                    x as usize,
                    y as usize,
                    width as usize,
                ),
            ),
            composer::Screen::Staged(bytes) => (bytes, false),
            composer::Screen::Hold => (Vec::new(), true),
        };
        Ok(View {
            receipt: composer::receipt(
                client.glyph,
                &capture,
                x as usize,
                y as usize,
                width as usize,
                &self.prepared.wire,
            ),
            bytes,
            busy,
            copy,
            width,
            height,
            x,
            y,
        })
    }
    fn staged(&self, view: &View) -> bool {
        view.bytes == self.prepared.wire.as_bytes()
            && !view.busy
            && !view.copy
            && self.geometry.is_some_and(|(width, height, y)| {
                width == view.width && height == view.height && (self.receipt_mode() || y == view.y)
            })
    }
    fn receipt_mode(&self) -> bool {
        self.client.as_ref().is_ok_and(|client| {
            self.prepared
                .client
                .is_none_or(|glyph| glyph == client.glyph)
        })
    }
    fn wait_for_renderer(&mut self) -> Result<State> {
        if self.state == State::WaitingForFocusRelease {
            return Ok(self.state);
        }
        self.commit(
            State::WaitingForFocusRelease,
            Evidence {
                diagnostics: vec!["renderer changed before unreleased Enter; no new input".into()],
                ..Default::default()
            },
        )
    }
    pub fn tick(&mut self) -> Result<State> {
        match self.state {
            State::PendingNoInput => self.paste(),
            State::Pasted | State::WaitingForFocusRelease => self.enter(),
            state => Ok(state),
        }
    }
    fn paste(&mut self) -> Result<State> {
        if self.client.is_err() {
            self.client = identity::Client::bind(self.prepared.target.pane.pid);
        }
        if self.lock.is_none() {
            let name = format!(
                "target-{}-{}-{}",
                self.peer.server_generation, self.peer.pane, self.peer.pane_generation
            );
            let lock = identity::open_at(self.ns.directory(), &name, libc::O_RDWR | libc::O_CREAT)?;
            if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
                return Ok(self.state);
            }
            let unresolved = lock.metadata().map_err(|e| e.to_string())?.len() != 0;
            self.lock = Some(lock);
            if unresolved {
                return self.no_input("prior target effect unresolved; no replay");
            }
        }
        if self
            .store
            .target_blocked(&self.id)
            .map_err(|e| format!("target ledger: {e:?}"))?
        {
            return self.no_input("prior unsettled target; no replay");
        }
        let before = match self.view() {
            Ok(v) => v,
            Err(error)
                if error == "client-bind: unsupported client"
                    && self.binding_since.elapsed() < Duration::from_secs(3) =>
            {
                return Ok(self.state)
            }
            Err(error) if error == "renderer changed during capture" => return Ok(self.state),
            Err(error) => return self.no_input(&format!("initial-view: {error}")),
        };
        if before.busy || before.copy || !before.bytes.is_empty() {
            self.ready_since = None;
            return Ok(self.state);
        }
        if self.receipt_mode() {
            match self.ready_since {
                Some((since, width, height, y))
                    if (width, height, y) == (before.width, before.height, before.y) =>
                {
                    if since.elapsed() < Duration::from_millis(500) {
                        return Ok(self.state);
                    }
                }
                _ => {
                    self.ready_since =
                        Some((Instant::now(), before.width, before.height, before.y));
                    return Ok(self.state);
                }
            }
        }
        self.geometry = Some((before.width, before.height, before.y));
        let wire = self.prepared.wire.clone();
        if !wire.bytes().all(|b| (32..=126).contains(&b)) {
            return self.no_input("unknown payload cell width");
        }
        let capacity = store::Capacity {
            width: before.width,
            height: before.height,
            cursor_x: before.x,
            cursor_y: before.y,
            pointer: wire.clone(),
            cells: Some(wire.len() as u64),
            byte_limit: Some(before.width - before.x - 1),
            cell_limit: Some(before.width - before.x - 1),
        };
        if !capacity.permits() {
            return self.no_input("wire exceeds capacity");
        }
        let buffer = format!("relay-{}", self.id);
        let pane = self.prepared.target.selector();
        let data = wire
            .strip_suffix(';')
            .map_or_else(|| wire.clone(), |prefix| format!("{prefix}\\;"));
        self.ns
            .command(&["set-buffer", "-b", &buffer, "--", &data])?;
        checkpoint("final-paste-check");
        let ready = match self.view() {
            Ok(v) => v,
            Err(error) if error == "renderer changed during capture" => return Ok(self.state),
            Err(error) => return self.no_input(&format!("final-view: {error}")),
        };
        if (ready.width, ready.height, ready.y) != (before.width, before.height, before.y) {
            return self.no_input("geometry changed before paste");
        }
        if ready.busy || ready.copy || !ready.bytes.is_empty() {
            return Ok(self.state);
        }
        let lease = identity::delivery_attest(self.ns.socket())?;
        let owner = identity::kernel_process(std::process::id()).ok_or("owner missing")?;
        self.evidence.capacity = Some(capacity);
        self.evidence.composer_proof = Some("verified empty composer and exact geometry".into());
        self.evidence.ownership = Some(Ownership {
            owner_pid: owner.pid,
            owner_generation: owner.generation()?,
            child: None,
            socket_path: self.ns.socket().to_string_lossy().into(),
            socket_device: self.peer.socket_device,
            socket_inode: self.peer.socket_inode,
            server_generation: self.peer.server_generation,
            lease_owner: u32::try_from(lease["owner"].as_u64().ok_or("lease owner absent")?)
                .map_err(|e| e.to_string())?,
            lease_nonce: lease["nonce"].as_str().ok_or("lease nonce absent")?.into(),
        });
        self.commit(State::InputIntent, self.evidence.clone())?;
        let lock = self.lock.as_mut().ok_or("target lock absent")?;
        lock.write_all(self.id.as_bytes())
            .map_err(|e| e.to_string())?;
        lock.sync_all().map_err(|e| e.to_string())?;
        self.ns.directory().sync_all().map_err(|e| e.to_string())?;
        self.marked = true;
        checkpoint("paste-launch:before");
        let condition = self.condition()?;
        let action = format!("paste-buffer -b {buffer} -t {pane} ; display-message -p applied");
        let result = self.effect(&condition, &action, false)?;
        checkpoint("paste-observation");
        if result.trim() == "refused" {
            return self.commit(
                State::TerminalNoInput,
                Evidence {
                    no_effect_proof: Some(NoEffectProof::Rejected {
                        evidence:
                            "same-server before-effect refusal; producer reaped/output closed"
                                .into(),
                        producers_closed: true,
                        stopped: true,
                        reaped: true,
                        before_effect: true,
                    }),
                    ..Default::default()
                },
            );
        }
        if result.trim() != "applied" {
            return self.unknown("paste outcome unproved");
        }
        let deadline = Instant::now() + Duration::from_secs(2);
        loop {
            match self.view() {
                Ok(after)
                    if after.bytes == wire.as_bytes()
                        && (after.width, after.height, after.y)
                            == (before.width, before.height, before.y)
                        && !after.busy
                        && !after.copy =>
                {
                    break
                }
                Ok(after) if !after.bytes.is_empty() => {
                    return self.unknown("post-paste bytes changed; no Enter")
                }
                _ if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(5)),
                _ => return self.unknown("post-paste observation unproved"),
            }
        }
        self.geometry = Some((before.width, before.height, before.y));
        self.evidence.paste_proof = Some("exact own staged bytes and unchanged geometry".into());
        self.commit(State::Pasted, self.evidence.clone())?;
        checkpoint("after-postcheck");
        self.enter()
    }
    fn condition(&self) -> Result<String> {
        self.verify()?;
        let t = &self.prepared.target;
        let v = self.view()?;
        if self.geometry != Some((v.width, v.height, v.y))
            && !(self.receipt_mode() && self.staged(&v))
        {
            return Err("geometry changed before effect".into());
        }
        let literal = |s: &str| {
            s.chars()
                .map(|c| match c {
                    '#' => "##".into(),
                    ',' => "#,".into(),
                    '}' => "#}".into(),
                    c => c.to_string(),
                })
                .collect::<String>()
        };
        let checks = [
            ("pid", self.ns.server().pid.to_string()),
            ("session_id", format!("${}", t.session_id.0)),
            ("window_id", format!("@{}", t.window.id.0)),
            ("pane_id", t.selector()),
            ("pane_pid", t.pane.pid.to_string()),
            ("pane_dead", "0".into()),
            ("pane_in_mode", "0".into()),
            ("session_name", literal(&t.session_name)),
            ("window_name", literal(&t.window.name)),
            ("pane_width", v.width.to_string()),
            ("pane_height", v.height.to_string()),
            ("cursor_y", v.y.to_string()),
            ("cursor_x", v.x.to_string()),
        ];
        Ok(format!(
            "#{{&&:{}}}",
            checks
                .into_iter()
                .map(|(key, value)| format!("#{{==:#{{{key}}},{value}}}"))
                .collect::<Vec<_>>()
                .join(",")
        ))
    }
    fn effect(&mut self, condition: &str, action: &str, enter: bool) -> Result<String> {
        self.verify()?;
        let pane = self.prepared.target.selector();
        let args = [
            "if-shell",
            "-F",
            "-t",
            &pane,
            condition,
            action,
            if enter {
                "display-message -p focused"
            } else {
                "display-message -p refused"
            },
        ];
        let producer = match Producer::spawn(self.ns, &args) {
            Ok(p) => p,
            Err(_) => {
                self.unknown("producer launch unproved")?;
                return Err("producer unavailable".into());
            }
        };
        self.producers.push(producer);
        let i = self.producers.len() - 1;
        checkpoint(if enter {
            "enter-launch:after"
        } else {
            "paste-launch:after"
        });
        let child = self.producers[i]
            .child
            .identity
            .ok_or("producer attestation missing")?;
        let mut evidence = if enter {
            self.store
                .attempt(&self.id)
                .map_err(|e| format!("ledger: {e:?}"))?
                .history
                .last()
                .unwrap()
                .evidence
                .clone()
        } else {
            self.evidence.clone()
        };
        let mut ownership = self
            .evidence
            .ownership
            .clone()
            .ok_or("owner evidence missing")?;
        ownership.child = Some((child.pid, child.generation()?));
        evidence.ownership = Some(ownership.clone());
        if !enter {
            self.evidence.ownership = Some(ownership);
        }
        self.commit(
            if enter {
                State::SubmitIntent
            } else {
                State::InputIntent
            },
            evidence,
        )?;
        if enter {
            let final_view = match self.view() {
                Ok(view) => view,
                Err(error) if error == "renderer changed during capture" => {
                    self.producers[i].input.take();
                    return Ok("unstable".into());
                }
                Err(error) => return Err(error),
            };
            if !self.staged(&final_view) {
                self.unknown("input change before Enter release")?;
                return Err("staged input changed".into());
            }
            self.receipt_before = Some(final_view.receipt);
        } else {
            let ready = self.view()?;
            if ready.busy
                || ready.copy
                || !ready.bytes.is_empty()
                || self.geometry != Some((ready.width, ready.height, ready.y))
            {
                self.unknown("composer changed before paste release")?;
                return Err("composer changed".into());
            }
        }
        #[cfg(test)]
        if enter {
            if let Some(hook) = &mut self.before_enter {
                hook()?;
            }
        }
        checkpoint(if enter {
            "enter-dispatch:before"
        } else {
            "paste-dispatch:before"
        });
        match self.producers[i].execute() {
            Ok(result) => Ok(result),
            Err(_) => {
                self.unknown("dispatched effect unproved")?;
                Err("input outcome unproved".into())
            }
        }
    }
    fn enter(&mut self) -> Result<State> {
        let second = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_secs();
        let before = match self.view() {
            Ok(v) => v,
            Err(error) if self.receipt_mode() && error == "renderer changed during capture" => {
                return self.wait_for_renderer()
            }
            Err(error) => return self.unknown(&format!("staged-view: {error}")),
        };
        if !self.staged(&before) {
            return self.unknown("staged bytes or geometry changed");
        }
        let condition = match self.condition() {
            Ok(condition) => condition,
            Err(error) if self.receipt_mode() && error == "renderer changed during capture" => {
                return self.wait_for_renderer()
            }
            Err(error) => return Err(error),
        };
        self.commit(
            State::SubmitIntent,
            Evidence {
                composer_proof: Some("verified exact staged bytes before Enter".into()),
                boundary: Some(store::SubmissionBoundary {
                    epoch: self.peer.pane_generation,
                    watermark: 0,
                }),
                ..Default::default()
            },
        )?;
        let pane = self.prepared.target.selector();
        let enter = format!("send-keys -t {pane} Enter ; display-message -p applied");
        let guarded = format!(
            "if-shell -F -t {pane} {} {} 'display-message -p refused'",
            quote(&condition),
            quote(&enter)
        );
        let action = if self.receipt_mode() {
            guarded
        } else {
            format!(
                "if-shell -F -t {pane} {} {} 'display-message -p activity'",
                quote(&no_activity_condition(second)),
                quote(&guarded)
            )
        };
        let focus = if self.receipt_mode() {
            "1".into()
        } else {
            no_focus_condition(&pane)
        };
        let result = self.effect(&focus, &action, true)?;
        match result.trim() {
            "unstable" => self.wait_for_renderer(),
            "focused" | "activity" => self.commit(
                State::WaitingForFocusRelease,
                Evidence {
                    diagnostics: vec![format!("submit-{}-guard", result.trim())],
                    ..Default::default()
                },
            ),
            "applied" if self.receipt_mode() => {
                let prior = self
                    .receipt_before
                    .ok_or("pre-Enter receipt observation absent")?;
                let deadline = Instant::now() + Duration::from_secs(2);
                loop {
                    if let Ok(after) = self.view() {
                        if !after.copy
                            && after.width == before.width
                            && after.height == before.height
                            && ((after.receipt.queue_prompt && after.receipt.queued > prior.queued)
                                || (!after.busy
                                    && after.bytes.is_empty()
                                    && after.receipt.submitted > prior.submitted))
                        {
                            return self.commit(State::Submitted, Evidence { submission_proof: Some("bound native UI positively accepted exact own wire after guarded Enter".into()), diagnostics: vec!["native acceptance observed; application work completion unproved".into()], ..Default::default() });
                        }
                    }
                    if Instant::now() >= deadline {
                        return self.unknown("guarded Enter completed; native acceptance unproved");
                    }
                    std::thread::sleep(Duration::from_millis(5));
                }
            }
            "applied" => self.commit(
                State::Submitted,
                Evidence {
                    submission_proof: Some(
                        "bound same-server guarded Enter completed; application receipt unproved"
                            .into(),
                    ),
                    diagnostics: vec!["receipt-unproved".into()],
                    ..Default::default()
                },
            ),
            _ => self.unknown("Enter outcome unproved"),
        }
    }
    fn remove_staged(&mut self) -> Result<()> {
        let deadline = Instant::now() + Duration::from_secs(2);
        let before = loop {
            match self.view() {
                Ok(view) if !view.busy && !view.copy && view.bytes.is_empty() => {
                    self.store.diagnostics(&self.id, vec!["failure cleanup: composer already empty; no removal input".into()])
                        .map_err(|e| format!("removal observation: {e:?}"))?;
                    return Ok(());
                }
                Ok(view) if self.staged(&view) => break view,
                Err(error)
                    if error == "renderer changed during capture" && Instant::now() < deadline => {}
                _ => {
                    return Err(
                        "failure cleanup: exact own staged bytes unproved; no removal input".into(),
                    )
                }
            }
            std::thread::sleep(Duration::from_millis(5));
        };
        let pane = self.prepared.target.selector();
        let condition = self.condition()?;
        let action = format!(
            "send-keys -t {pane} -N {} BSpace ; display-message -p removed",
            self.prepared.wire.len()
        );
        let producer = Producer::spawn(
            self.ns,
            &[
                "if-shell",
                "-F",
                "-t",
                &pane,
                &condition,
                &action,
                "display-message -p refused",
            ],
        )?;
        self.producers.push(producer);
        let index = self.producers.len() - 1;
        let child = self.producers[index]
            .child
            .identity
            .ok_or("removal producer unattested")?;
        self.store
            .diagnostics(
                &self.id,
                vec![format!(
            "failure cleanup intent: exact own wire {} bytes; owned producer {}:{}; no replay",
            self.prepared.wire.len(), child.pid, child.generation()?
        )],
            )
            .map_err(|e| format!("removal intent: {e:?}"))?;
        checkpoint("removal-dispatch:before");
        let final_view = self.view()?;
        if !self.staged(&final_view)
            || (
                final_view.x,
                final_view.y,
                final_view.width,
                final_view.height,
            ) != (before.x, before.y, before.width, before.height)
        {
            self.producers[index].input.take();
            return Err(
                "failure cleanup: staged bytes changed before removal; no removal input".into(),
            );
        }
        if self.producers[index].execute()?.trim() != "removed" {
            return Err("failure cleanup: guarded removal refused".into());
        }
        let deadline = Instant::now() + Duration::from_secs(2);
        loop {
            if let Ok(after) = self.view() {
                if !after.busy
                    && !after.copy
                    && after.bytes.is_empty()
                    && (after.width, after.height) == (before.width, before.height)
                {
                    self.store.diagnostics(&self.id, vec!["failure cleanup: exact own staged bytes removed; empty native composer proven".into()])
                        .map_err(|e| format!("removal proof: {e:?}"))?;
                    return Ok(());
                }
            }
            if Instant::now() >= deadline {
                return Err("failure cleanup: removal outcome unproved".into());
            }
            std::thread::sleep(Duration::from_millis(5));
        }
    }
    pub fn close(&mut self) -> Result<()> {
        let start = Instant::now();
        if self.closed {
            return Ok(());
        }
        self.closed = true;
        let restart = self.store.record_restart(&self.id);
        if let Ok(a) = &restart {
            self.state = a.state();
        }
        let budgets = self
            .evidence
            .budgets
            .clone()
            .ok_or("cleanup budgets missing")?;
        let mut notes = Vec::new();
        let mut removal_error = None;
        for p in &mut self.producers {
            p.input.take();
        }
        for p in &mut self.producers {
            let mut clipped = budgets.clone();
            let remaining = budgets
                .decision_ms
                .saturating_sub(start.elapsed().as_millis() as u64);
            if remaining == 0 {
                notes.push("cleanup decision expired".into());
                break;
            }
            clipped.decision_ms = remaining;
            notes.extend(p.child.cleanup(&clipped));
        }
        let mut producers_closed = self.producers.iter().all(|p| {
            p.child.status.is_some()
                && !p.child.reader_fault
                && p.child.readers.iter().all(|r| r.eof)
        });
        if self.marked && producers_closed && self.state != State::Submitted {
            if let Err(error) = self.remove_staged() {
                notes.push(error.clone());
                removal_error = Some(error);
            }
            for producer in &mut self.producers {
                producer.input.take();
                notes.extend(producer.child.cleanup(&budgets));
            }
            producers_closed = self.producers.iter().all(|p| {
                p.child.status.is_some()
                    && !p.child.reader_fault
                    && p.child.readers.iter().all(|r| r.eof)
            });
        }
        if self.marked
            && producers_closed
            && matches!(self.state, State::Submitted | State::TerminalNoInput)
        {
            if let Some(lock) = &self.lock {
                lock.set_len(0)
                    .and_then(|_| lock.sync_all())
                    .map_err(|e| e.to_string())?;
            }
        }
        if producers_closed {
            self.lock.take();
        }
        if !notes.is_empty() {
            self.store
                .diagnostics(&self.id, notes)
                .map_err(|e| format!("cleanup warning: {e:?}"))?;
        }
        restart.map_err(|e| format!("restart: {e:?}"))?;
        if let Some(error) = removal_error {
            if self.state != State::InputUnknown {
                return Err(error);
            }
        }
        Ok(())
    }
}
impl Drop for Runtime<'_> {
    fn drop(&mut self) {
        let _ = self.close();
    }
}
pub(crate) fn checkpoint(name: &str) {
    #[cfg(test)]
    if std::env::var("ANGELSTAR_CORE_CRASH").ok().as_deref() == Some(name) {
        std::process::exit(86);
    }
    let _ = name;
}
#[cfg(test)]
#[path = "../tests/support/runtime.rs"]
mod tests;
