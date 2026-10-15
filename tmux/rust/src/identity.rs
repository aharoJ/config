use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString};
use std::fs::File;
use std::io::Read;
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};
use std::process::Command;

pub type Result<T> = std::result::Result<T, String>;
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SessionId(pub u64);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct WindowId(pub u64);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PaneId(pub u64);
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Window {
    pub id: WindowId,
    pub name: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pane {
    pub id: PaneId,
    pub pid: u32,
    pub dead: bool,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Target {
    pub session_id: SessionId,
    pub session_name: String,
    pub window: Window,
    pub pane: Pane,
}
impl Target {
    pub fn selector(&self) -> String {
        format!("%{}", self.pane.id.0)
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProcessIdentity {
    pub pid: u32,
    pub parent: u32,
    pub start_seconds: u64,
    pub start_microseconds: u64,
}
impl ProcessIdentity {
    pub fn generation(self) -> Result<u64> {
        self.start_seconds
            .checked_mul(1_000_000)
            .and_then(|n| n.checked_add(self.start_microseconds))
            .ok_or("generation overflow".into())
    }
    pub fn same(self, other: Self) -> bool {
        (self.pid, self.start_seconds, self.start_microseconds)
            == (other.pid, other.start_seconds, other.start_microseconds)
    }
}
#[repr(C)]
struct BsdInfo {
    head: [u32; 12],
    command: [u8; 16],
    name: [u8; 32],
    tail: [u32; 6],
    seconds: u64,
    micros: u64,
}
unsafe extern "C" {
    fn proc_pidinfo(pid: i32, flavor: i32, arg: u64, buffer: *mut libc::c_void, size: i32) -> i32;
    fn proc_pidpath(pid: i32, buffer: *mut libc::c_void, size: u32) -> i32;
    fn proc_listchildpids(pid: i32, buffer: *mut libc::c_void, size: i32) -> i32;
}
pub fn kernel_process(pid: u32) -> Option<ProcessIdentity> {
    let mut info: BsdInfo = unsafe { std::mem::zeroed() };
    let count = unsafe {
        proc_pidinfo(
            i32::try_from(pid).ok()?,
            3,
            0,
            (&mut info as *mut BsdInfo).cast(),
            std::mem::size_of::<BsdInfo>() as i32,
        )
    };
    if count != 136
        || info.head[3] != pid
        || info.head[1] == 5
        || info.seconds == 0
        || info.micros >= 1_000_000
    {
        return None;
    }
    Some(ProcessIdentity {
        pid,
        parent: info.head[4],
        start_seconds: info.seconds,
        start_microseconds: info.micros,
    })
}
pub fn kernel_ancestry(mut pid: u32) -> Result<Vec<ProcessIdentity>> {
    let mut chain = Vec::new();
    for _ in 0..64 {
        if chain.iter().any(|p: &ProcessIdentity| p.pid == pid) {
            return Err("cyclic ancestry".into());
        }
        let process = kernel_process(pid).ok_or("missing ancestry")?;
        chain.push(process);
        if process.parent == 1 && chain.iter().all(|p| kernel_process(p.pid) == Some(*p)) {
            return Ok(chain);
        }
        pid = process.parent;
    }
    Err("long ancestry".into())
}
fn process_path(pid: u32) -> Result<PathBuf> {
    let mut path = [0u8; 4096];
    let count = unsafe { proc_pidpath(pid as i32, path.as_mut_ptr().cast(), path.len() as u32) };
    if count <= 0 || count as usize >= path.len() {
        return Err("process image unavailable".into());
    }
    let end = path
        .iter()
        .position(|b| *b == 0)
        .ok_or("invalid process image")?;
    std::fs::canonicalize(Path::new(std::ffi::OsStr::from_bytes(&path[..end])))
        .map_err(|e| e.to_string())
}
pub fn no_acl(file: &File) -> Result<()> {
    unsafe extern "C" {
        fn acl_get_fd_np(fd: i32, kind: i32) -> *mut libc::c_void;
        fn acl_get_entry(acl: *mut libc::c_void, kind: i32, entry: *mut *mut libc::c_void) -> i32;
        fn acl_free(ptr: *mut libc::c_void) -> i32;
    }
    unsafe {
        *libc::__error() = 0;
        let acl = acl_get_fd_np(file.as_raw_fd(), 0x100);
        if acl.is_null() {
            return if *libc::__error() == libc::ENOENT {
                Ok(())
            } else {
                Err("ACL unavailable".into())
            };
        }
        let mut entry = std::ptr::null_mut();
        *libc::__error() = 0;
        let found = acl_get_entry(acl, 0, &mut entry);
        let error = *libc::__error();
        acl_free(acl);
        if found == -1 && error == libc::EINVAL {
            Ok(())
        } else {
            Err("extended ACL".into())
        }
    }
}
pub fn private(file: &File, directory: bool) -> Result<()> {
    let m = file.metadata().map_err(|e| e.to_string())?;
    if m.uid() != unsafe { libc::geteuid() }
        || m.mode() & 0o7777 != if directory { 0o700 } else { 0o600 }
        || if directory {
            !m.is_dir()
        } else {
            !m.is_file() || m.nlink() != 1
        }
    {
        return Err("nonprivate object".into());
    }
    no_acl(file)
}
pub fn open_dir(path: &Path) -> Result<File> {
    if !path.is_absolute() {
        return Err("absolute path required".into());
    }
    let mut current = File::open("/").map_err(|e| e.to_string())?;
    for component in path.components().skip(1) {
        let Component::Normal(name) = component else {
            return Err("noncanonical component".into());
        };
        let name = CString::new(name.as_bytes()).map_err(|e| e.to_string())?;
        let fd = unsafe {
            libc::openat(
                current.as_raw_fd(),
                name.as_ptr(),
                libc::O_RDONLY | libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC,
            )
        };
        if fd < 0 {
            return Err(std::io::Error::last_os_error().to_string());
        }
        current = unsafe { File::from_raw_fd(fd) };
    }
    if std::fs::canonicalize(path).map_err(|e| e.to_string())? != path {
        return Err("noncanonical path".into());
    }
    Ok(current)
}
pub fn open_at(root: &File, name: &str, flags: i32) -> Result<File> {
    if name.is_empty() || name.contains('/') || matches!(name, "." | "..") {
        return Err("invalid relative name".into());
    }
    let name = CString::new(name).map_err(|e| e.to_string())?;
    let fd = unsafe {
        libc::openat(
            root.as_raw_fd(),
            name.as_ptr(),
            flags | libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC,
            0o600,
        )
    };
    if fd < 0 {
        return Err(std::io::Error::last_os_error().to_string());
    }
    let file = unsafe { File::from_raw_fd(fd) };
    private(&file, false)?;
    Ok(file)
}
pub fn names(root: &File) -> Result<Vec<String>> {
    let copy = root.try_clone().map_err(|e| e.to_string())?;
    let fd = unsafe { libc::dup(copy.as_raw_fd()) };
    if fd < 0 {
        return Err("directory enumeration failed".into());
    }
    unsafe {
        libc::lseek(fd, 0, libc::SEEK_SET);
    }
    let dir = unsafe { libc::fdopendir(fd) };
    if dir.is_null() {
        unsafe {
            libc::close(fd);
        }
        return Err("directory enumeration failed".into());
    }
    let mut names = Vec::new();
    loop {
        unsafe {
            *libc::__error() = 0;
        }
        let entry = unsafe { libc::readdir(dir) };
        if entry.is_null() {
            let error = unsafe { *libc::__error() };
            unsafe {
                libc::closedir(dir);
            }
            if error != 0 {
                return Err("directory enumeration failed".into());
            }
            return Ok(names);
        }
        let bytes = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) }.to_bytes();
        if bytes != b"." && bytes != b".." {
            names.push(
                std::str::from_utf8(bytes)
                    .map_err(|e| e.to_string())?
                    .into(),
            );
        }
    }
}
fn stamp(m: &std::fs::Metadata) -> (u64, u64, u64, i64, i64, i64, i64) {
    (
        m.dev(),
        m.ino(),
        m.len(),
        m.mtime(),
        m.mtime_nsec(),
        m.ctime(),
        m.ctime_nsec(),
    )
}
pub struct Namespace {
    socket: PathBuf,
    root: File,
    executable: PathBuf,
    image: File,
    image_stamp: (u64, u64, u64, i64, i64, i64, i64),
    socket_identity: (u64, u64),
    server: ProcessIdentity,
}
impl Namespace {
    pub fn connect(executable: &Path, socket: &Path, expected: ProcessIdentity) -> Result<Self> {
        use std::os::unix::fs::FileTypeExt;
        let root = open_dir(socket.parent().ok_or("missing socket parent")?)?;
        private(&root, true)?;
        let m = std::fs::symlink_metadata(socket).map_err(|e| e.to_string())?;
        if !m.file_type().is_socket()
            || m.uid() != unsafe { libc::geteuid() }
            || std::fs::canonicalize(socket).map_err(|e| e.to_string())? != socket
        {
            return Err("unsafe socket".into());
        }
        let image = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(executable)
            .map_err(|e| e.to_string())?;
        let im = image.metadata().map_err(|e| e.to_string())?;
        if !im.is_file()
            || im.mode() & 0o6022 != 0
            || im.mode() & 0o111 == 0
            || ![0, unsafe { libc::geteuid() }].contains(&im.uid())
        {
            return Err("unsafe server image".into());
        }
        no_acl(&image)?;
        let ns = Self {
            socket: socket.into(),
            root,
            executable: executable.into(),
            image,
            image_stamp: stamp(&im),
            socket_identity: (m.dev(), m.ino()),
            server: expected,
        };
        ns.verify()?;
        Ok(ns)
    }
    pub fn socket(&self) -> &Path {
        &self.socket
    }
    pub fn directory(&self) -> &File {
        &self.root
    }
    pub fn server(&self) -> ProcessIdentity {
        self.server
    }
    pub fn verify(&self) -> Result<()> {
        let named = open_dir(self.socket.parent().ok_or("missing socket parent")?)?;
        private(&named, true)?;
        private(&self.root, true)?;
        let held = self.root.metadata().map_err(|e| e.to_string())?;
        let now = named.metadata().map_err(|e| e.to_string())?;
        let socket = std::fs::symlink_metadata(&self.socket).map_err(|e| e.to_string())?;
        use std::os::unix::fs::FileTypeExt;
        if !socket.file_type().is_socket()
            || socket.uid() != unsafe { libc::geteuid() }
            || std::fs::canonicalize(&self.socket).map_err(|e| e.to_string())? != self.socket
        {
            return Err("socket identity changed".into());
        }
        if (held.dev(), held.ino()) != (now.dev(), now.ino())
            || (socket.dev(), socket.ino()) != self.socket_identity
            || kernel_process(self.server.pid) != Some(self.server)
            || process_path(self.server.pid)? != self.executable
            || stamp(&self.image.metadata().map_err(|e| e.to_string())?) != self.image_stamp
            || stamp(&std::fs::symlink_metadata(&self.executable).map_err(|e| e.to_string())?)
                != self.image_stamp
        {
            return Err("namespace changed".into());
        }
        let connection =
            std::os::unix::net::UnixStream::connect(&self.socket).map_err(|e| e.to_string())?;
        let mut pid = 0i32;
        let mut size = std::mem::size_of::<i32>() as libc::socklen_t;
        if unsafe {
            libc::getsockopt(
                connection.as_raw_fd(),
                0,
                2,
                (&mut pid as *mut i32).cast(),
                &mut size,
            )
        } != 0
            || pid <= 0
            || size != std::mem::size_of::<i32>() as libc::socklen_t
            || pid as u32 != self.server.pid
        {
            return Err("wrong server peer".into());
        }
        Ok(())
    }
    pub fn command(&self, args: &[&str]) -> Result<String> {
        self.verify()?;
        let mut command = Command::new("/usr/bin/python3");
        command
            .arg(delivery_helper())
            .args(["run", "tmux", "-S"])
            .arg(&self.socket)
            .args(args);
        let bytes = crate::runtime::capture(&mut command)?;
        self.verify()?;
        String::from_utf8(bytes).map_err(|e| e.to_string())
    }
    pub fn capture(&self) -> Result<Snapshot> {
        Snapshot::parse(
            self.command(&["list-panes", "-a", "-F", CAPTURE_FORMAT])?
                .as_bytes(),
        )
    }
}
use std::os::unix::fs::OpenOptionsExt;
#[cfg(test)]
pub fn helper() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../tests/cleanup_guard.py")
}
pub fn delivery_helper() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../tests/delivery_guard.py")
}
pub fn connect_delivery(socket: &Path) -> Result<Namespace> {
    let mut command = Command::new("/usr/bin/python3");
    command.arg(delivery_helper()).arg("attest").arg(socket);
    let raw = crate::runtime::capture(&mut command)?;
    let record: serde_json::Value = serde_json::from_slice(&raw).map_err(|e| e.to_string())?;
    let pid = u32::try_from(record["pid"].as_u64().ok_or("missing server pid")?)
        .map_err(|e| e.to_string())?;
    let server = kernel_process(pid).ok_or("missing server")?;
    if record["generation"] != serde_json::json!([server.start_seconds, server.start_microseconds])
    {
        return Err("server generation changed".into());
    }
    Namespace::connect(
        &std::fs::canonicalize("/opt/homebrew/bin/tmux").map_err(|e| e.to_string())?,
        socket,
        server,
    )
}
#[cfg(test)]
pub fn connect_signed(socket: &Path) -> Result<Namespace> {
    if socket
        == Path::new(&format!("/private/tmp/tmux-{}/default", unsafe {
            libc::geteuid()
        }))
    {
        return Err("fixture socket required".into());
    }
    connect_delivery(socket)
}
#[derive(Clone, Debug)]
pub struct Snapshot {
    pub targets: Vec<Target>,
}
pub const CAPTURE_FORMAT: &str="#{session_id}\t#{window_id}\t#{pane_id}\t#{pane_pid}\t#{pane_dead}\t#{n:session_name}:#{session_name}#{n:window_name}:#{window_name}";
impl Snapshot {
    pub fn parse(mut bytes: &[u8]) -> Result<Self> {
        fn field<'a>(bytes: &mut &'a [u8], delimiter: u8) -> Result<&'a [u8]> {
            let n = bytes
                .iter()
                .position(|b| *b == delimiter)
                .ok_or("truncated capture")?;
            let result = &bytes[..n];
            *bytes = &bytes[n + 1..];
            Ok(result)
        }
        fn number(bytes: &[u8]) -> Result<u64> {
            if bytes.is_empty() || !bytes.iter().all(u8::is_ascii_digit) {
                return Err("invalid number".into());
            }
            std::str::from_utf8(bytes)
                .map_err(|e| e.to_string())?
                .parse()
                .map_err(|e: std::num::ParseIntError| e.to_string())
        }
        fn name(bytes: &mut &[u8]) -> Result<String> {
            let n = usize::try_from(number(field(bytes, b':')?)?).map_err(|e| e.to_string())?;
            if n > bytes.len() {
                return Err("truncated name".into());
            }
            let text = std::str::from_utf8(&bytes[..n])
                .map_err(|e| e.to_string())?
                .to_owned();
            *bytes = &bytes[n..];
            Ok(text)
        }
        let mut targets = Vec::new();
        while !bytes.is_empty() {
            let mut id = |prefix| {
                let f = field(&mut bytes, b'\t')?;
                if f.first() != Some(&prefix) {
                    return Err("invalid id".into());
                }
                number(&f[1..])
            };
            let session = SessionId(id(b'$')?);
            let window = WindowId(id(b'@')?);
            let pane = PaneId(id(b'%')?);
            let pid =
                u32::try_from(number(field(&mut bytes, b'\t')?)?).map_err(|e| e.to_string())?;
            let dead = match field(&mut bytes, b'\t')? {
                b"0" => false,
                b"1" => true,
                _ => return Err("invalid dead flag".into()),
            };
            let session_name = name(&mut bytes)?;
            let window_name = name(&mut bytes)?;
            if bytes.first() != Some(&b'\n') {
                return Err("invalid capture boundary".into());
            }
            bytes = &bytes[1..];
            targets.push(Target {
                session_id: session,
                session_name,
                window: Window {
                    id: window,
                    name: window_name,
                },
                pane: Pane {
                    id: pane,
                    pid,
                    dead,
                },
            });
        }
        Ok(Self { targets })
    }
}
pub fn split_route(route: &str) -> Result<(&str, &str)> {
    let (s, w) = route.rsplit_once(':').ok_or("missing route")?;
    if s.is_empty() || w.is_empty() {
        return Err("empty route".into());
    }
    Ok((s, w))
}
pub fn resolve(
    snapshot: &Snapshot,
    session: &str,
    window: &str,
    pane: Option<PaneId>,
) -> Result<Target> {
    let sessions: HashSet<_> = snapshot
        .targets
        .iter()
        .filter(|t| t.session_name == session)
        .map(|t| t.session_id)
        .collect();
    if sessions.len() != 1 {
        return Err("missing or ambiguous session".into());
    }
    let windows: HashSet<_> = snapshot
        .targets
        .iter()
        .filter(|t| t.session_name == session && t.window.name == window)
        .map(|t| t.window.id)
        .collect();
    if windows.len() != 1 {
        return Err("missing or ambiguous window".into());
    }
    let mut targets = snapshot.targets.iter().filter(|t| {
        t.session_name == session
            && t.window.name == window
            && !t.pane.dead
            && pane.is_none_or(|p| t.pane.id == p)
    });
    let first = targets.next().ok_or("missing pane")?;
    if targets.next().is_some() {
        return Err("ambiguous pane".into());
    }
    Ok(first.clone())
}
pub fn source_candidate(
    snapshot: &Snapshot,
    mut pid: u32,
    parents: &HashMap<u32, u32>,
) -> Option<Target> {
    let mut visited = HashSet::new();
    for _ in 0..64 {
        if !visited.insert(pid) {
            return None;
        }
        let mut targets = snapshot
            .targets
            .iter()
            .filter(|t| !t.pane.dead && t.pane.pid == pid);
        if let Some(first) = targets.next() {
            return if targets.next().is_none() {
                Some(first.clone())
            } else {
                None
            };
        }
        pid = *parents.get(&pid)?;
    }
    None
}
pub struct Client {
    file: File,
    path: PathBuf,
    stamp: (u64, u64, u64, i64, i64, i64, i64),
    process: ProcessIdentity,
    pane: ProcessIdentity,
    pub glyph: char,
}
impl Client {
    pub fn bind(pane: u32) -> Result<Self> {
        let pane_identity = kernel_process(pane).ok_or("missing pane owner")?;
        let mut queue = vec![(pane, 0)];
        let mut seen = HashSet::new();
        let mut matches = Vec::new();
        while let Some((pid, depth)) = queue.pop() {
            if !seen.insert(pid) || seen.len() > 64 || depth > 8 {
                return Err("ambiguous ancestry".into());
            }
            if let (Some(process), Ok(path)) = (kernel_process(pid), process_path(pid)) {
                if let Ok(file) = std::fs::OpenOptions::new()
                    .read(true)
                    .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
                    .open(&path)
                {
                    let m = file.metadata().map_err(|e| e.to_string())?;
                    let profile = match m.len() {
                        247931696 => Some((
                            '❯',
                            "ba5ab7b8c195fa03ab8d5bf3915c76153b576a2c40e79a5c46e265e7ed9744b3",
                        )),
                        246642624 => Some((
                            '›',
                            "74c6a6d263f40d65f99c27a815275f5b4ed0bcc2baecc396b4cf3255498bdfc0",
                        )),
                        _ => None,
                    };
                    if let Some((glyph, hash)) = profile {
                        if m.is_file()
                            && m.mode() & 0o6022 == 0
                            && m.mode() & 0o111 != 0
                            && [0, unsafe { libc::geteuid() }].contains(&m.uid())
                            && no_acl(&file).is_ok()
                        {
                            let mut bytes = std::io::BufReader::new(
                                file.try_clone().map_err(|e| e.to_string())?,
                            );
                            let mut digest = Sha256::new();
                            let mut buffer = [0u8; 65536];
                            loop {
                                let n = bytes.read(&mut buffer).map_err(|e| e.to_string())?;
                                if n == 0 {
                                    break;
                                }
                                digest.update(&buffer[..n]);
                            }
                            if format!("{:x}", digest.finalize()) == hash {
                                matches.push(Self {
                                    file,
                                    path,
                                    stamp: stamp(&m),
                                    process,
                                    pane: pane_identity,
                                    glyph,
                                });
                            }
                        }
                    }
                }
            }
            let mut children = [0i32; 64];
            let count = unsafe {
                proc_listchildpids(
                    pid as i32,
                    children.as_mut_ptr().cast(),
                    std::mem::size_of_val(&children) as i32,
                )
            };
            if count < 0 || count as usize >= children.len() {
                return Err("child enumeration unavailable".into());
            }
            queue.extend(
                children[..count as usize]
                    .iter()
                    .filter(|p| **p > 0)
                    .map(|p| (*p as u32, depth + 1)),
            );
        }
        if matches.is_empty() {
            return Err("unsupported client".into());
        }
        if matches.len() != 1 {
            return Err(format!(
                "ambiguous client: {} matching processes",
                matches.len()
            ));
        }
        let client = matches.pop().unwrap();
        client.verify()?;
        Ok(client)
    }
    pub fn current(&self) -> Result<()> {
        self.verify()
    }
    pub fn verify(&self) -> Result<()> {
        if !kernel_ancestry(self.process.pid)?.contains(&self.pane) {
            return Err("client ancestry changed".into());
        }
        if kernel_process(self.pane.pid) != Some(self.pane)
            || kernel_process(self.process.pid) != Some(self.process)
            || process_path(self.process.pid)? != self.path
            || stamp(&self.file.metadata().map_err(|e| e.to_string())?) != self.stamp
            || stamp(&std::fs::symlink_metadata(&self.path).map_err(|e| e.to_string())?)
                != self.stamp
        {
            return Err("client changed".into());
        }
        Ok(())
    }
}
#[cfg(test)]
#[path = "../tests/support/identity.rs"]
mod tests;
