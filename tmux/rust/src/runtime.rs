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
    command.stdin(Stdio::null());
    let mut child = OwnedChild::spawn(command)?;
    let deadline = Instant::now() + Duration::from_secs(2);
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

const BRIDGE:&str="import runpy,sys,subprocess\ng=runpy.run_path(sys.argv[1])\ng['attest'](sys.argv[2])\nif sys.stdin.readline()!='go\\n':sys.exit(90)\nr=g['run_tmux'](['tmux','-S',sys.argv[2],*sys.argv[3:]],capture_output=True,stdin=subprocess.DEVNULL,timeout=2)\nsys.stdout.buffer.write(r.stdout);sys.stderr.buffer.write(r.stderr);sys.exit(r.returncode)\n";
struct Producer {
    child: OwnedChild,
    input: Option<ChildStdin>,
}
impl Producer {
    fn spawn(ns: &Namespace, args: &[&str]) -> Result<Self> {
        ns.verify()?;
        let mut command = Command::new("/usr/bin/python3");
        command
            .args(["-c", BRIDGE])
            .arg(identity::delivery_helper())
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
pub struct Prepared {
    target: Target,
    source: Option<Target>,
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
        let target = identity::resolve(&snapshot, session, window, pane)?;
        let ancestry = identity::kernel_ancestry(std::process::id())?;
        let parents = ancestry.iter().map(|p| (p.pid, p.parent)).collect();
        let source = identity::source_candidate(&snapshot, std::process::id(), &parents);
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
        if codes.is_empty() {
            let value = format!("r{}", &fresh_id()?[..12]);
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
            target,
            source,
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
        if identity::source_candidate(&snapshot, std::process::id(), &parents) != self.source {
            return Err("source changed".into());
        }
        Ok(())
    }
}
struct View {
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
    #[cfg(test)]
    fixture: Option<std::path::PathBuf>,
    #[cfg(test)]
    before_enter: Option<Box<dyn FnMut() -> Result<()> + 'a>>,
}
impl<'a> Runtime<'a> {
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
        let id = fresh_id()?;
        if !prepared.wire.is_ascii() || prepared.wire.len() as u64 > v[0] - 10 {
            let codes = prepared
                .attribution
                .codes
                .iter()
                .map(|c| format!("#{}", c.value))
                .collect::<Vec<_>>()
                .join(" ");
            prepared.wire = format!("{}: {codes} -- full: {archive}", prepared.attribution.label);
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
            composer::Screen::Empty => (Vec::new(), false),
            composer::Screen::Staged(bytes) => (bytes, false),
            composer::Screen::Hold => (Vec::new(), true),
        };
        Ok(View {
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
            && self.geometry == Some((view.width, view.height, view.y))
    }
    pub fn tick(&mut self) -> Result<State> {
        match self.state {
            State::PendingNoInput => self.paste(),
            State::Pasted | State::WaitingForFocusRelease => self.enter(),
            state => Ok(state),
        }
    }
    fn paste(&mut self) -> Result<State> {
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
            Err(error) => return self.no_input(&format!("initial-view: {error}")),
        };
        if before.busy || before.copy || !before.bytes.is_empty() {
            return Ok(self.state);
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
        self.ns
            .command(&["set-buffer", "-b", &buffer, "--", &wire])?;
        checkpoint("final-paste-check");
        let ready = match self.view() {
            Ok(v) => v,
            Err(error) => return self.no_input(&format!("final-view: {error}")),
        };
        if (ready.width, ready.height, ready.y) != (before.width, before.height, before.y) {
            return self.no_input("geometry changed before paste");
        }
        if ready.busy || ready.copy || !ready.bytes.is_empty() {
            return Ok(self.state);
        }
        let mut attest = Command::new("/usr/bin/python3");
        attest
            .arg(identity::delivery_helper())
            .arg("attest")
            .arg(self.ns.socket());
        let lease: serde_json::Value =
            serde_json::from_slice(&capture(&mut attest)?).map_err(|e| e.to_string())?;
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
        if self.geometry != Some((v.width, v.height, v.y)) {
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
            let final_view = self.view()?;
            if !self.staged(&final_view) {
                self.unknown("input change before Enter release")?;
                return Err("staged input changed".into());
            }
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
        // A new boundary for this exact-byte check, not the original paste.
        // CLI ticks wait briefly and share one overall deadline. Same-second
        // activity conservatively holds until a later quiet check can pass.
        let second = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_secs();
        let before = match self.view() {
            Ok(v) => v,
            Err(error) => return self.unknown(&format!("staged-view: {error}")),
        };
        if !self.staged(&before) {
            return self.unknown("staged bytes or geometry changed");
        }
        let condition = self.condition()?;
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
        let action = format!(
            "if-shell -F -t {pane} {} {} 'display-message -p activity'",
            quote(&no_activity_condition(second)),
            quote(&guarded)
        );
        let result = self.effect(&no_focus_condition(&pane), &action, true)?;
        match result.trim() {
            "focused" | "activity" => self.commit(
                State::WaitingForFocusRelease,
                Evidence {
                    diagnostics: vec![format!("submit-{}-guard", result.trim())],
                    ..Default::default()
                },
            ),
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
        let producers_closed = self.producers.iter().all(|p| {
            p.child.status.is_some()
                && !p.child.reader_fault
                && p.child.readers.iter().all(|r| r.eof)
        });
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
        restart.map(|_| ()).map_err(|e| format!("restart: {e:?}"))
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
