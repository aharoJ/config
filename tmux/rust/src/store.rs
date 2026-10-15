#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum State {
    PendingNoInput,
    InputIntent,
    Pasted,
    WaitingForFocusRelease,
    SubmitIntent,
    Submitted,
    TerminalNoInput,
    InputUnknown,
}

impl State {
    pub(crate) fn references_archive(self) -> bool {
        matches!(
            self,
            Self::PendingNoInput
                | Self::InputIntent
                | Self::Pasted
                | Self::WaitingForFocusRelease
                | Self::SubmitIntent
                | Self::InputUnknown
        )
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Peer {
    pub socket_device: u64,
    pub socket_inode: u64,
    pub server_generation: u64,
    pub session: u64,
    pub window: u64,
    pub pane: u64,
    pub pane_generation: u64,
}
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub enum Source {
    Tool,
    Known {
        identity: String,
        generation: u64,
        label: String,
    },
}

use crate::identity;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::ffi::CString;
use std::fs::File;
use std::io::{Read, Write};
use std::os::fd::AsRawFd;

use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub enum Error {
    Io(std::io::Error),
    Invalid,
    UnsafePath,
    Busy,
    Corrupt,
    Missing,
    Collision,
    Replay,
    CodeReserved,
    Pruned,
    Unresolved(String),
    CommitUncertain,
    Transition,
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(e) => write!(f, "{e}"),
            Self::Unresolved(id) => write!(f, "unresolved archive {id}"),
            e => write!(f, "{e:?}"),
        }
    }
}
impl From<std::io::Error> for Error {
    fn from(value: std::io::Error) -> Self {
        Self::Io(value)
    }
}

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Code {
    pub value: String,
    pub generated: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Attribution {
    pub source: Source,
    pub label: String,
    pub codes: Vec<Code>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Content {
    bytes: u64,
    sha256: String,
}

impl Content {
    fn of(bytes: &[u8]) -> Self {
        Self {
            bytes: bytes.len() as u64,
            sha256: format!("{:x}", Sha256::digest(bytes)),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
enum ArchiveState {
    Publishing,
    Stored,
    Pruning,
    Pruned,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Archive {
    id: String,
    original: Content,
    wire: Content,
    attribution: Attribution,
    state: ArchiveState,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Capacity {
    pub width: u64,
    pub height: u64,
    pub cursor_x: u64,
    pub cursor_y: u64,
    pub pointer: String,
    pub cells: Option<u64>,
    pub byte_limit: Option<u64>,
    pub cell_limit: Option<u64>,
}

impl Capacity {
    pub fn permits(&self) -> bool {
        self.width > 0
            && self.height > 0
            && self.cursor_x < self.width
            && self.cursor_y < self.height
            && !self.pointer.is_empty()
            && !self.pointer.chars().any(char::is_control)
            && self
                .byte_limit
                .is_some_and(|n| self.pointer.len() as u64 <= n)
            && self
                .cells
                .zip(self.cell_limit)
                .is_some_and(|(n, max)| n <= max)
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Budgets {
    pub stop_ms: u64,
    pub drain_ms: u64,
    pub reap_ms: u64,
    pub decision_ms: u64,
}

impl Budgets {
    fn valid(&self) -> bool {
        [self.stop_ms, self.drain_ms, self.reap_ms, self.decision_ms]
            .into_iter()
            .all(|n| n > 0 && n <= i64::MAX as u64)
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Ownership {
    pub owner_pid: u32,
    pub owner_generation: u64,
    pub child: Option<(u32, u64)>,
    pub socket_path: String,
    pub socket_device: u64,
    pub socket_inode: u64,
    pub server_generation: u64,
    pub lease_owner: u32,
    pub lease_nonce: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SubmissionBoundary {
    pub epoch: u64,
    pub watermark: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub enum NoEffectProof {
    NeverLaunched {
        evidence: String,
    },
    Rejected {
        evidence: String,
        producers_closed: bool,
        stopped: bool,
        reaped: bool,
        before_effect: bool,
    },
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Evidence {
    pub capacity: Option<Capacity>,
    pub budgets: Option<Budgets>,
    pub ownership: Option<Ownership>,
    pub composer_proof: Option<String>,
    pub no_effect_proof: Option<NoEffectProof>,
    pub paste_proof: Option<String>,
    pub boundary: Option<SubmissionBoundary>,
    pub submission_proof: Option<String>,
    pub diagnostics: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Transition {
    pub sequence: u64,
    pub predecessor: Option<u64>,
    pub state: State,
    pub evidence: Evidence,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Attempt {
    pub id: String,
    pub archive: String,
    pub request: String,
    pub peer: Peer,
    pub attribution: Attribution,
    pub history: Vec<Transition>,
}

impl Attempt {
    pub fn state(&self) -> State {
        self.history.last().expect("validated history").state
    }

    pub fn sequence(&self) -> u64 {
        self.history.last().expect("validated history").sequence
    }

    pub fn recovered_state(&self) -> State {
        match self.state() {
            State::InputIntent
            | State::Pasted
            | State::WaitingForFocusRelease
            | State::SubmitIntent => State::InputUnknown,
            state => state,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Ledger {
    schema: String,
    version: u64,
    revision: u64,
    archives: Vec<Archive>,
    attempts: Vec<Attempt>,
}

impl Default for Ledger {
    fn default() -> Self {
        Self {
            schema: "angelstar-store".into(),
            version: 1,
            revision: 0,
            archives: Vec::new(),
            attempts: Vec::new(),
        }
    }
}

pub struct Published {
    id: String,
    instance: u64,
}

pub struct AttemptHandle {
    id: String,
    instance: u64,
    sequence: u64,
}

pub struct Acceptance<'a> {
    pub id: &'a str,
    pub request: &'a str,
    pub peer: Peer,
}

struct Lock(File);

impl Drop for Lock {
    fn drop(&mut self) {
        unsafe {
            libc::flock(self.0.as_raw_fd(), libc::LOCK_UN);
        }
    }
}

pub struct Store {
    path: PathBuf,
    root: File,
    ledger: Ledger,
    instance: u64,
    poisoned: bool,
}

static INSTANCE: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

pub fn valid_id(id: &str) -> bool {
    id.len() == 32
        && id
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
fn attribution(a: &Attribution) -> bool {
    !a.label.is_empty()
        && !a.label.chars().any(char::is_control)
        && match &a.source {
            Source::Tool => a.label == "relay",
            Source::Known {
                identity,
                generation,
                label,
            } => !identity.is_empty() && *generation > 0 && label == &a.label,
        }
        && !a.codes.is_empty()
        && a.codes.iter().enumerate().all(|(i, c)| {
            !c.value.is_empty()
                && c.value
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
                && !a.codes[..i].iter().any(|x| x.value == c.value)
        })
}
fn attributed_wire(wire: &[u8], attribution: &Attribution) -> bool {
    std::str::from_utf8(wire).is_ok_and(|s| {
        s.starts_with(&format!("{}: ", attribution.label))
            && attribution.codes.iter().all(|c| {
                s.match_indices(&format!("#{}", c.value)).any(|(i, _)| {
                    s.as_bytes()
                        .get(i + 1 + c.value.len())
                        .is_none_or(|b| !b.is_ascii_alphanumeric() && !b"_-".contains(b))
                })
            })
    })
}
fn text(p: &Option<String>) -> bool {
    p.as_ref().is_some_and(|p| !p.is_empty())
}
fn same_owner(a: &Ownership, b: &Ownership) -> bool {
    let mut a = a.clone();
    let mut b = b.clone();
    a.child = None;
    b.child = None;
    a == b
}
fn allowed(from: State, to: State) -> bool {
    use State::*;
    match from {
        PendingNoInput => matches!(to, InputIntent | TerminalNoInput),
        InputIntent => matches!(to, InputIntent | Pasted | TerminalNoInput | InputUnknown),
        Pasted => matches!(to, WaitingForFocusRelease | SubmitIntent | InputUnknown),
        WaitingForFocusRelease => matches!(to, SubmitIntent | InputUnknown),
        SubmitIntent => matches!(
            to,
            SubmitIntent | WaitingForFocusRelease | Submitted | InputUnknown
        ),
        _ => false,
    }
}
fn transition_valid(a: &Attempt, i: usize) -> bool {
    let t = &a.history[i];
    let e = &t.evidence;
    if t.sequence != i as u64 || t.predecessor != i.checked_sub(1).map(|n| n as u64) {
        return false;
    }
    if i == 0 {
        return t.state == State::PendingNoInput && e == &Evidence::default();
    }
    let old = &a.history[i - 1];
    if old.state == t.state
        && matches!(
            t.state,
            State::PendingNoInput | State::InputUnknown | State::TerminalNoInput | State::Submitted
        )
        && !e.diagnostics.is_empty()
    {
        return e.diagnostics.iter().all(|s| !s.is_empty())
            && *e
                == Evidence {
                    diagnostics: e.diagnostics.clone(),
                    ..Default::default()
                };
    }
    if !allowed(old.state, t.state) {
        return false;
    }
    match t.state {
        State::InputIntent => {
            e.capacity.as_ref().is_some_and(Capacity::permits)
                && e.budgets.as_ref().is_some_and(Budgets::valid)
                && text(&e.composer_proof)
                && e.ownership.as_ref().is_some_and(|o| {
                    o.owner_pid > 0
                        && o.owner_generation > 0
                        && Path::new(&o.socket_path).is_absolute()
                        && o.lease_owner > 0
                        && !o.lease_nonce.is_empty()
                        && (o.socket_device, o.socket_inode, o.server_generation)
                            == (
                                a.peer.socket_device,
                                a.peer.socket_inode,
                                a.peer.server_generation,
                            )
                        && if old.state == State::PendingNoInput {
                            o.child.is_none()
                        } else {
                            o.child.is_some_and(|(p, g)| p > 0 && g > 0)
                                && old
                                    .evidence
                                    .ownership
                                    .as_ref()
                                    .is_some_and(|v| v.child.is_none() && same_owner(v, o))
                                && e.capacity == old.evidence.capacity
                                && e.budgets == old.evidence.budgets
                                && e.composer_proof == old.evidence.composer_proof
                        }
                })
        }
        State::Pasted => {
            text(&e.paste_proof)
                && e.ownership.as_ref().is_some_and(|o| {
                    o.child.is_some_and(|(p, g)| p > 0 && g > 0)
                        && old
                            .evidence
                            .ownership
                            .as_ref()
                            .is_some_and(|v| v.child == o.child && same_owner(v, o))
                })
        }
        State::SubmitIntent => {
            text(&e.composer_proof)
                && e.boundary.as_ref().is_some_and(|b| b.epoch > 0)
                && (old.state != State::SubmitIntent
                    || (e.boundary == old.evidence.boundary
                        && e.composer_proof == old.evidence.composer_proof
                        && e.ownership.as_ref().is_some_and(|o| {
                            o.child.is_some_and(|(p, g)| p > 0 && g > 0)
                                && a.history[..i]
                                    .iter()
                                    .rev()
                                    .find_map(|t| t.evidence.ownership.as_ref())
                                    .is_some_and(|v| same_owner(v, o))
                        })))
        }
        State::TerminalNoInput => {
            old.state == State::PendingNoInput
                || match &e.no_effect_proof {
                    Some(NoEffectProof::NeverLaunched { evidence }) => {
                        !evidence.is_empty()
                            && a.history[..i].iter().all(|t| {
                                t.evidence
                                    .ownership
                                    .as_ref()
                                    .is_none_or(|o| o.child.is_none())
                            })
                    }
                    Some(NoEffectProof::Rejected {
                        evidence,
                        producers_closed,
                        stopped,
                        reaped,
                        before_effect,
                    }) => {
                        !evidence.is_empty()
                            && *producers_closed
                            && *stopped
                            && *reaped
                            && *before_effect
                            && old
                                .evidence
                                .ownership
                                .as_ref()
                                .is_some_and(|o| o.child.is_some())
                    }
                    None => false,
                }
        }
        State::Submitted => text(&e.submission_proof),
        State::WaitingForFocusRelease | State::InputUnknown => true,
        State::PendingNoInput => false,
    }
}
impl Ledger {
    fn validate(&self) -> bool {
        if self.schema != "angelstar-store" || self.version != 1 {
            return false;
        }
        for (i, a) in self.archives.iter().enumerate() {
            if !valid_id(&a.id)
                || !attribution(&a.attribution)
                || a.original.bytes == 0
                || a.wire.bytes == 0
                || self.archives[..i].iter().any(|x| x.id == a.id)
                || [&a.original.sha256, &a.wire.sha256].iter().any(|s| {
                    s.len() != 64
                        || !s
                            .bytes()
                            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
                })
            {
                return false;
            }
        }
        for (i, a) in self.attempts.iter().enumerate() {
            let Some(archive) = self.archives.iter().find(|x| x.id == a.archive) else {
                return false;
            };
            if !valid_id(&a.id)
                || a.request.is_empty()
                || a.peer.socket_inode == 0
                || a.peer.server_generation == 0
                || a.peer.pane_generation == 0
                || a.attribution != archive.attribution
                || a.history.is_empty()
                || self.attempts[..i]
                    .iter()
                    .any(|x| x.id == a.id || x.request == a.request || x.archive == a.archive)
                || (0..a.history.len()).any(|n| !transition_valid(a, n))
                || archive.state == ArchiveState::Publishing
                || (matches!(archive.state, ArchiveState::Pruning | ArchiveState::Pruned)
                    && a.state().references_archive())
                || a.history
                    .iter()
                    .filter(|t| t.state == State::InputIntent)
                    .any(|t| {
                        t.evidence
                            .capacity
                            .as_ref()
                            .is_none_or(|c| Content::of(c.pointer.as_bytes()) != archive.wire)
                    })
            {
                return false;
            }
            if a.attribution.codes.iter().filter(|c| c.generated).any(|c| {
                self.attempts[..i]
                    .iter()
                    .any(|x| x.attribution.codes.iter().any(|v| v.value == c.value))
            }) {
                return false;
            }
        }
        true
    }
}
fn unsafe_path(_e: String) -> Error {
    Error::UnsafePath
}
impl Store {
    pub fn open(path: &Path) -> Result<Self> {
        let desk = PathBuf::from(std::env::var_os("HOME").ok_or(Error::UnsafePath)?).join("desk");
        if !path.starts_with(&desk) || path == desk {
            return Err(Error::UnsafePath);
        }
        if !path.exists() {
            let parent =
                identity::open_dir(path.parent().ok_or(Error::UnsafePath)?).map_err(unsafe_path)?;
            if parent.metadata()?.uid() != unsafe { libc::geteuid() } {
                return Err(Error::UnsafePath);
            }
            let name = CString::new(
                path.file_name()
                    .ok_or(Error::UnsafePath)?
                    .as_encoded_bytes(),
            )
            .map_err(|_| Error::UnsafePath)?;
            if unsafe { libc::mkdirat(parent.as_raw_fd(), name.as_ptr(), 0o700) } != 0 {
                return Err(std::io::Error::last_os_error().into());
            }
        }
        let root = identity::open_dir(path).map_err(unsafe_path)?;
        identity::private(&root, true).map_err(unsafe_path)?;
        let mut store = Self {
            path: path.into(),
            root,
            ledger: Ledger::default(),
            instance: INSTANCE.fetch_add(1, std::sync::atomic::Ordering::Relaxed),
            poisoned: false,
        };
        let _lock = store.root_lock()?;
        let entries = identity::names(&store.root).map_err(unsafe_path)?;
        if entries.is_empty() {
            store.commit("initialize")?;
        } else {
            store.reload()?;
        }
        Ok(store)
    }
    fn check_root(&self) -> Result<()> {
        if self.poisoned {
            return Err(Error::CommitUncertain);
        }
        let named = identity::open_dir(&self.path).map_err(unsafe_path)?;
        identity::private(&named, true).map_err(unsafe_path)?;
        identity::private(&self.root, true).map_err(unsafe_path)?;
        let a = named.metadata()?;
        let b = self.root.metadata()?;
        if (a.dev(), a.ino()) != (b.dev(), b.ino()) {
            return Err(Error::UnsafePath);
        }
        Ok(())
    }
    fn root_lock(&self) -> Result<Lock> {
        self.check_root()?;
        let file = identity::open_dir(&self.path).map_err(unsafe_path)?;
        if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
            return Err(Error::Busy);
        }
        Ok(Lock(file))
    }
    fn lock(&mut self) -> Result<Lock> {
        let lock = self.root_lock()?;
        self.reload()?;
        Ok(lock)
    }
    fn file(&self, name: &str) -> Result<Vec<u8>> {
        let mut file =
            identity::open_at(&self.root, name, libc::O_RDONLY).map_err(|_| Error::Corrupt)?;
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        Ok(bytes)
    }
    fn reload(&mut self) -> Result<()> {
        self.ledger =
            serde_json::from_slice(&self.file("ledger.json")?).map_err(|_| Error::Corrupt)?;
        if !self.ledger.validate() {
            return Err(Error::Corrupt);
        }
        for name in identity::names(&self.root).map_err(unsafe_path)? {
            self.file(&name)?;
            if name == "ledger.json" || name.ends_with(".pending") {
                continue;
            }
            let (id, kind) = name.split_once('.').ok_or(Error::Corrupt)?;
            let archive = self
                .ledger
                .archives
                .iter()
                .find(|a| a.id == id)
                .ok_or(Error::Corrupt)?;
            if !matches!(kind, "original" | "wire") || archive.state == ArchiveState::Pruned {
                return Err(Error::Corrupt);
            }
        }
        for archive in self
            .ledger
            .archives
            .iter()
            .filter(|a| a.state == ArchiveState::Stored)
        {
            self.content(archive, false)?;
            self.content(archive, true)?;
        }
        self.check_root()
    }
    fn content(&self, a: &Archive, wire: bool) -> Result<Vec<u8>> {
        let bytes = self.file(&format!(
            "{}.{}",
            a.id,
            if wire { "wire" } else { "original" }
        ))?;
        if Content::of(&bytes)
            != if wire {
                a.wire.clone()
            } else {
                a.original.clone()
            }
            || (wire && !attributed_wire(&bytes, &a.attribution))
        {
            return Err(Error::Corrupt);
        }
        Ok(bytes)
    }
    fn write(&mut self, name: &str, bytes: &[u8], exclusive: bool, phase: &str) -> Result<()> {
        let result = (|| {
            self.check_root()?;
            crate::runtime::checkpoint(&format!("{phase}:before-create"));
            let tmp = format!(
                ".{name}.{}.{}.{}.pending",
                std::process::id(),
                self.instance,
                self.ledger.revision
            );
            let mut file = identity::open_at(
                &self.root,
                &tmp,
                libc::O_WRONLY | libc::O_CREAT | libc::O_EXCL,
            )
            .map_err(|_| Error::Corrupt)?;
            crate::runtime::checkpoint(&format!("{phase}:after-create"));
            file.write_all(bytes)?;
            crate::runtime::checkpoint(&format!("{phase}:before-file-sync"));
            file.sync_all()?;
            crate::runtime::checkpoint(&format!("{phase}:after-file-sync"));
            self.check_root()?;
            let tmp = CString::new(tmp).unwrap();
            let name_c = CString::new(name).map_err(|_| Error::Invalid)?;
            crate::runtime::checkpoint(&format!("{phase}:before-rename"));
            if unsafe {
                libc::renameatx_np(
                    self.root.as_raw_fd(),
                    tmp.as_ptr(),
                    self.root.as_raw_fd(),
                    name_c.as_ptr(),
                    if exclusive { libc::RENAME_EXCL } else { 0 },
                )
            } != 0
            {
                return Err(std::io::Error::last_os_error().into());
            }
            crate::runtime::checkpoint(&format!("{phase}:after-rename"));
            crate::runtime::checkpoint(&format!("{phase}:before-directory-sync"));
            self.root.sync_all()?;
            crate::runtime::checkpoint(&format!("{phase}:after-directory-sync"));
            crate::runtime::checkpoint(&format!("{phase}:before-verify"));
            if self.file(name)? != bytes {
                return Err(Error::Corrupt);
            }
            self.check_root()?;
            crate::runtime::checkpoint(&format!("{phase}:after-verify"));
            Ok(())
        })();
        if result.is_err() {
            self.poisoned = true;
            return Err(Error::CommitUncertain);
        }
        result
    }
    fn commit(&mut self, phase: &str) -> Result<()> {
        if !self.ledger.validate() {
            return Err(Error::Corrupt);
        }
        self.ledger.revision = self.ledger.revision.checked_add(1).ok_or(Error::Corrupt)?;
        self.write(
            "ledger.json",
            &serde_json::to_vec(&self.ledger).map_err(|_| Error::Corrupt)?,
            phase == "initialize",
            phase,
        )
    }
    pub fn publish(
        &mut self,
        id: &str,
        original: &[u8],
        wire: &[u8],
        attribution: Attribution,
    ) -> Result<Published> {
        let _lock = self.lock()?;
        if !valid_id(id)
            || original.is_empty()
            || std::str::from_utf8(original).is_err()
            || !self::attribution(&attribution)
            || !attributed_wire(wire, &attribution)
        {
            return Err(Error::Invalid);
        }
        if self.ledger.archives.iter().any(|a| a.id == id) {
            return Err(Error::Collision);
        }
        let digest = Content::of(original);
        if let Some(a) = self.ledger.archives.iter().find(|a| {
            a.original == digest
                && (a.state == ArchiveState::Publishing
                    || self.ledger.attempts.iter().any(|t| {
                        t.archive == a.id
                            && matches!(
                                t.state(),
                                State::InputIntent
                                    | State::Pasted
                                    | State::WaitingForFocusRelease
                                    | State::SubmitIntent
                                    | State::InputUnknown
                            )
                    }))
        }) {
            return Err(Error::Unresolved(a.id.clone()));
        }
        self.ledger.archives.push(Archive {
            id: id.into(),
            original: digest,
            wire: Content::of(wire),
            attribution,
            state: ArchiveState::Publishing,
        });
        self.commit("archive-intent")?;
        self.write(&format!("{id}.original"), original, true, "original")?;
        self.write(&format!("{id}.wire"), wire, true, "wire")?;
        self.resolve_publication(id)?;
        Ok(Published {
            id: id.into(),
            instance: self.instance,
        })
    }
    fn resolve_publication(&mut self, id: &str) -> Result<()> {
        let i = self
            .ledger
            .archives
            .iter()
            .position(|a| a.id == id)
            .ok_or(Error::Missing)?;
        if self.ledger.archives[i].state != ArchiveState::Publishing {
            return Err(Error::Transition);
        }
        self.content(&self.ledger.archives[i], false)?;
        self.content(&self.ledger.archives[i], true)?;
        self.ledger.archives[i].state = ArchiveState::Stored;
        self.commit("archive-resolved")
    }
    pub fn read(&mut self, id: &str, wire: bool) -> Result<Vec<u8>> {
        let _lock = self.lock()?;
        if !valid_id(id) {
            return Err(Error::Invalid);
        }
        let a = self
            .ledger
            .archives
            .iter()
            .find(|a| a.id == id)
            .ok_or(Error::Missing)?;
        match a.state {
            ArchiveState::Stored => self.content(a, wire),
            ArchiveState::Pruned => Err(Error::Pruned),
            _ => Err(Error::Unresolved(id.into())),
        }
    }
    pub fn accept(&mut self, p: Published, s: Acceptance<'_>) -> Result<AttemptHandle> {
        let _lock = self.lock()?;
        if p.instance != self.instance
            || !valid_id(s.id)
            || s.request.is_empty()
            || s.peer.socket_inode == 0
            || s.peer.server_generation == 0
            || s.peer.pane_generation == 0
        {
            return Err(Error::Invalid);
        }
        if self
            .ledger
            .attempts
            .iter()
            .any(|a| a.id == s.id || a.request == s.request || a.archive == p.id)
        {
            return Err(Error::Replay);
        }
        let archive = self
            .ledger
            .archives
            .iter()
            .find(|a| a.id == p.id)
            .ok_or(Error::Missing)?;
        if archive.state != ArchiveState::Stored {
            return Err(Error::Unresolved(p.id));
        }
        self.content(archive, false)?;
        self.content(archive, true)?;
        let attribution = archive.attribution.clone();
        if attribution.codes.iter().filter(|c| c.generated).any(|c| {
            self.ledger
                .attempts
                .iter()
                .any(|a| a.attribution.codes.iter().any(|v| v.value == c.value))
        }) {
            return Err(Error::CodeReserved);
        }
        self.ledger.attempts.push(Attempt {
            id: s.id.into(),
            archive: p.id,
            request: s.request.into(),
            peer: s.peer,
            attribution,
            history: vec![Transition {
                sequence: 0,
                predecessor: None,
                state: State::PendingNoInput,
                evidence: Evidence::default(),
            }],
        });
        self.commit("acceptance")?;
        Ok(AttemptHandle {
            id: s.id.into(),
            instance: self.instance,
            sequence: 0,
        })
    }
    pub fn attempt(&mut self, id: &str) -> Result<Attempt> {
        let _lock = self.lock()?;
        if !valid_id(id) {
            return Err(Error::Invalid);
        }
        self.ledger
            .attempts
            .iter()
            .find(|a| a.id == id)
            .cloned()
            .ok_or(Error::Missing)
    }
    pub fn target_blocked(&mut self, id: &str) -> Result<bool> {
        let _lock = self.lock()?;
        let own = self
            .ledger
            .attempts
            .iter()
            .find(|a| a.id == id)
            .ok_or(Error::Missing)?;
        Ok(self.ledger.attempts.iter().any(|a| {
            a.id != id
                && a.peer == own.peer
                && matches!(
                    a.state(),
                    State::InputIntent
                        | State::Pasted
                        | State::WaitingForFocusRelease
                        | State::SubmitIntent
                        | State::InputUnknown
                )
        }))
    }
    pub fn transition(
        &mut self,
        handle: &mut AttemptHandle,
        state: State,
        evidence: Evidence,
    ) -> Result<()> {
        let _lock = self.lock()?;
        if handle.instance != self.instance {
            return Err(Error::Replay);
        }
        let i = self
            .ledger
            .attempts
            .iter()
            .position(|a| a.id == handle.id)
            .ok_or(Error::Missing)?;
        let mut a = self.ledger.attempts[i].clone();
        if a.sequence() != handle.sequence {
            return Err(Error::Transition);
        }
        let sequence = handle.sequence.checked_add(1).ok_or(Error::Transition)?;
        a.history.push(Transition {
            sequence,
            predecessor: Some(handle.sequence),
            state,
            evidence,
        });
        if !transition_valid(&a, a.history.len() - 1) {
            return Err(Error::Transition);
        }
        self.ledger.attempts[i] = a;
        self.commit("transition")?;
        handle.sequence = sequence;
        Ok(())
    }
    pub fn record_restart(&mut self, id: &str) -> Result<Attempt> {
        let _lock = self.lock()?;
        let i = self
            .ledger
            .attempts
            .iter()
            .position(|a| a.id == id)
            .ok_or(Error::Missing)?;
        let a = &mut self.ledger.attempts[i];
        if a.recovered_state() != a.state() {
            let p = a.sequence();
            a.history.push(Transition {
                sequence: p.checked_add(1).ok_or(Error::Transition)?,
                predecessor: Some(p),
                state: State::InputUnknown,
                evidence: Evidence {
                    diagnostics: vec!["restarted without actual owner; no replay".into()],
                    ..Default::default()
                },
            });
            self.commit("restart")?;
        }
        Ok(self.ledger.attempts[i].clone())
    }
    pub fn diagnostics(&mut self, id: &str, messages: Vec<String>) -> Result<()> {
        if messages.is_empty() || messages.iter().any(|s| s.is_empty()) {
            return Err(Error::Invalid);
        }
        let a = self.attempt(id)?;
        let mut handle = AttemptHandle {
            id: id.into(),
            instance: self.instance,
            sequence: a.sequence(),
        };
        self.transition(
            &mut handle,
            a.state(),
            Evidence {
                diagnostics: messages,
                ..Default::default()
            },
        )
    }
}
#[cfg(test)]
#[path = "../tests/support/store.rs"]
mod tests;
