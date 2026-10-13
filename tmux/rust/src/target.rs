use std::collections::{HashMap, HashSet};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct SessionId(pub u64);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct WindowId(pub u64);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
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
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Error {
    MissingSession,
    AmbiguousSession,
    MissingWindow,
    AmbiguousWindow,
    MissingPane,
    AmbiguousPane,
    Changed,
    InvalidCapture,
    CaptureFailed,
    InvalidNamespace,
}

#[cfg(target_os = "macos")]
#[derive(Debug)]
pub struct Namespace {
    executable: std::path::PathBuf,
    socket: std::path::PathBuf,
    executable_file: std::fs::File,
    executable_stamp: FileStamp,
    directory: std::fs::File,
    connection: std::os::unix::net::UnixStream,
    socket_identity: (u64, u64),
    server: ProcessIdentity,
}

#[cfg(target_os = "macos")]
#[derive(Debug, PartialEq, Eq)]
struct FileStamp {
    device: u64,
    inode: u64,
    size: u64,
    modified: (i64, i64),
    changed: (i64, i64),
    mode: u32,
    owner: u32,
}

#[cfg(target_os = "macos")]
impl From<&std::fs::Metadata> for FileStamp {
    fn from(value: &std::fs::Metadata) -> Self {
        use std::os::unix::fs::MetadataExt;
        Self {
            device: value.dev(),
            inode: value.ino(),
            size: value.len(),
            modified: (value.mtime(), value.mtime_nsec()),
            changed: (value.ctime(), value.ctime_nsec()),
            mode: value.mode(),
            owner: value.uid(),
        }
    }
}

#[cfg(target_os = "macos")]
fn peer_pid(connection: &std::os::unix::net::UnixStream) -> Result<u32, Error> {
    use std::os::fd::AsRawFd;
    unsafe extern "C" {
        fn getsockopt(
            fd: i32,
            level: i32,
            option: i32,
            value: *mut std::ffi::c_void,
            size: *mut u32,
        ) -> i32;
    }
    let mut pid = 0i32;
    let mut size = std::mem::size_of::<i32>() as u32;
    let result = unsafe {
        getsockopt(
            connection.as_raw_fd(),
            0,
            2,
            (&mut pid as *mut i32).cast(),
            &mut size,
        )
    };
    if result != 0 || size != std::mem::size_of::<i32>() as u32 || pid <= 0 {
        return Err(Error::InvalidNamespace);
    }
    Ok(pid as u32)
}

#[cfg(target_os = "macos")]
impl Namespace {
    pub fn connect(
        executable: &std::path::Path,
        socket: &std::path::Path,
        expected: ProcessIdentity,
    ) -> Result<Self, Error> {
        use std::os::unix::fs::{FileTypeExt, MetadataExt, OpenOptionsExt};
        unsafe extern "C" {
            fn geteuid() -> u32;
        }
        let uid = unsafe { geteuid() };
        let parent = socket.parent().ok_or(Error::InvalidNamespace)?;
        for path in [executable, socket, parent] {
            if !path.is_absolute() || std::fs::canonicalize(path).ok().as_deref() != Some(path) {
                return Err(Error::InvalidNamespace);
            }
        }
        let open = |path| {
            std::fs::OpenOptions::new()
                .read(true)
                .custom_flags(0x01000100)
                .open(path)
                .map_err(|_| Error::InvalidNamespace)
        };
        let executable_file = open(executable)?;
        let metadata = executable_file
            .metadata()
            .map_err(|_| Error::InvalidNamespace)?;
        if !metadata.is_file()
            || metadata.mode() & 0o6022 != 0
            || metadata.mode() & 0o111 == 0
            || ![0, uid].contains(&metadata.uid())
        {
            return Err(Error::InvalidNamespace);
        }
        let executable_stamp = FileStamp::from(&metadata);
        let directory = open(parent)?;
        let metadata = directory.metadata().map_err(|_| Error::InvalidNamespace)?;
        if !metadata.is_dir()
            || metadata.uid() != uid
            || metadata.mode() & 0o777 != 0o700
            || !crate::delivery::has_no_acl(&directory).map_err(|_| Error::InvalidNamespace)?
            || !crate::delivery::has_no_acl(&executable_file)
                .map_err(|_| Error::InvalidNamespace)?
        {
            return Err(Error::InvalidNamespace);
        }
        let metadata = std::fs::symlink_metadata(socket).map_err(|_| Error::InvalidNamespace)?;
        if !metadata.file_type().is_socket() || metadata.uid() != uid {
            return Err(Error::InvalidNamespace);
        }
        let socket_identity = (metadata.dev(), metadata.ino());
        let connection =
            std::os::unix::net::UnixStream::connect(socket).map_err(|_| Error::InvalidNamespace)?;
        if peer_pid(&connection)? != expected.pid || kernel_process(expected.pid) != Some(expected)
        {
            return Err(Error::Changed);
        }
        let namespace = Self {
            executable: executable.to_owned(),
            socket: socket.to_owned(),
            executable_file,
            executable_stamp,
            directory,
            connection,
            socket_identity,
            server: expected,
        };
        namespace.revalidate()?;
        Ok(namespace)
    }

    pub fn revalidate(&self) -> Result<(), Error> {
        use std::os::unix::fs::MetadataExt;
        let validate = || -> Result<(), Error> {
            for path in [&self.executable, &self.socket] {
                if std::fs::canonicalize(path).ok().as_ref() != Some(path) {
                    return Err(Error::Changed);
                }
            }
            let executable =
                std::fs::symlink_metadata(&self.executable).map_err(|_| Error::Changed)?;
            let held = self
                .executable_file
                .metadata()
                .map_err(|_| Error::Changed)?;
            if FileStamp::from(&executable) != self.executable_stamp
                || FileStamp::from(&held) != self.executable_stamp
            {
                return Err(Error::Changed);
            }
            let parent = std::fs::symlink_metadata(self.socket.parent().unwrap())
                .map_err(|_| Error::Changed)?;
            let pinned = self.directory.metadata().map_err(|_| Error::Changed)?;
            if (parent.dev(), parent.ino()) != (pinned.dev(), pinned.ino())
                || pinned.mode() & 0o777 != 0o700
                || !crate::delivery::has_no_acl(&self.directory).map_err(|_| Error::Changed)?
                || !crate::delivery::has_no_acl(&self.executable_file)
                    .map_err(|_| Error::Changed)?
            {
                return Err(Error::Changed);
            }
            let socket = std::fs::symlink_metadata(&self.socket).map_err(|_| Error::Changed)?;
            if (socket.dev(), socket.ino()) != self.socket_identity
                || peer_pid(&self.connection)? != self.server.pid
                || kernel_process(self.server.pid) != Some(self.server)
            {
                return Err(Error::Changed);
            }
            Ok(())
        };
        validate().map_err(|_| Error::Changed)
    }

    pub fn server(&self) -> ProcessIdentity {
        self.server
    }

    pub fn is_protected_socket(&self) -> bool {
        unsafe extern "C" {
            fn geteuid() -> u32;
        }
        cleanup_socket_protected(&self.socket, std::env::var_os("TMUX").as_deref(), unsafe {
            geteuid()
        })
    }

    pub fn verify_peer_image(&self) -> Result<(), Error> {
        use std::os::unix::ffi::OsStrExt;
        #[link(name = "proc")]
        unsafe extern "C" {
            fn proc_pidpath(pid: i32, buffer: *mut std::ffi::c_void, size: u32) -> i32;
        }
        self.revalidate()?;
        let pid = i32::try_from(self.server.pid).map_err(|_| Error::InvalidNamespace)?;
        let mut path = [0u8; 4096];
        let count = unsafe { proc_pidpath(pid, path.as_mut_ptr().cast(), path.len() as u32) };
        if count <= 0 || count as usize >= path.len() {
            return Err(Error::InvalidNamespace);
        }
        let end = path
            .iter()
            .position(|byte| *byte == 0)
            .ok_or(Error::InvalidNamespace)?;
        let image = std::path::Path::new(std::ffi::OsStr::from_bytes(&path[..end]));
        if std::fs::canonicalize(image).ok().as_ref() != Some(&self.executable) {
            return Err(Error::InvalidNamespace);
        }
        self.revalidate()
    }

    pub fn capture(&self) -> Result<Snapshot, Error> {
        self.revalidate()?;
        let mut command = std::process::Command::new(&self.executable);
        command
            .arg("-N")
            .arg("-S")
            .arg(&self.socket)
            .args([
                "display-message",
                "-p",
                "#{pid}",
                ";",
                "list-panes",
                "-a",
                "-F",
                CAPTURE_FORMAT,
            ])
            .env_remove("TMUX")
            .env_remove("TMUX_PANE");
        let output = bounded_capture(&mut command, self.server.pid)?;
        self.revalidate()?;
        let end = output
            .iter()
            .position(|byte| *byte == b'\n')
            .ok_or(Error::InvalidCapture)?;
        if number(&output[..end])? != u64::from(self.server.pid) {
            return Err(Error::Changed);
        }
        Snapshot::parse(&output[end + 1..])
    }
}

#[cfg(target_os = "macos")]
pub fn cleanup_socket_protected(
    socket: &std::path::Path,
    context: Option<&std::ffi::OsStr>,
    uid: u32,
) -> bool {
    use std::os::unix::fs::MetadataExt;
    let mut paths = vec![std::path::PathBuf::from(format!(
        "/private/tmp/tmux-{uid}/default"
    ))];
    if let Some(context) = context {
        let Some(context) = context.to_str() else {
            return true;
        };
        let fields = context.rsplitn(3, ',').collect::<Vec<_>>();
        if fields.len() != 3
            || fields[2].is_empty()
            || !fields[1].bytes().all(|byte| byte.is_ascii_digit())
            || fields[1].is_empty()
            || !fields[0].bytes().all(|byte| byte.is_ascii_digit())
            || fields[0].is_empty()
        {
            return true;
        }
        paths.push(fields[2].into());
    }
    let identity = std::fs::metadata(socket)
        .ok()
        .map(|meta| (meta.dev(), meta.ino()));
    let canonical = std::fs::canonicalize(socket).unwrap_or_else(|_| socket.to_owned());
    paths.into_iter().any(|path| {
        path == socket
            || std::fs::canonicalize(&path).ok().as_ref() == Some(&canonical)
            || identity.is_some_and(|expected| {
                std::fs::metadata(path).is_ok_and(|meta| (meta.dev(), meta.ino()) == expected)
            })
    })
}

#[cfg(target_os = "macos")]
fn bounded_capture(
    command: &mut std::process::Command,
    protected_server: u32,
) -> Result<Vec<u8>, Error> {
    use std::io::Read;
    use std::os::fd::AsRawFd;
    use std::os::unix::process::CommandExt;
    #[repr(C)]
    struct SignalInfo {
        signal: i32,
        error: i32,
        code: i32,
        pid: i32,
        uid: u32,
        status: i32,
        address: *mut std::ffi::c_void,
        value: u64,
        band: i64,
        reserved: [u64; 7],
    }
    unsafe extern "C" {
        fn fcntl(fd: i32, operation: i32, ...) -> i32;
        fn waitid(kind: i32, id: u32, info: *mut SignalInfo, options: i32) -> i32;
    }
    struct Child {
        process: std::process::Child,
        cleaned: bool,
        protected_server: u32,
    }
    impl Child {
        fn cleanup(&mut self) -> Result<(), Error> {
            if self.cleaned {
                return Ok(());
            }
            if self.process.id() == 0
                || self.process.id() > i32::MAX as u32
                || self.process.id() == self.protected_server
            {
                self.cleaned = true;
                return Err(Error::CaptureFailed);
            }
            let _ = self.process.kill();
            let start = std::time::Instant::now();
            let gone = loop {
                match group_has_running(self.process.id()) {
                    Ok(false) => break true,
                    Err(_) => break false,
                    Ok(true) if start.elapsed() >= std::time::Duration::from_millis(500) => {
                        break false
                    }
                    Ok(true) => std::thread::sleep(std::time::Duration::from_millis(5)),
                }
            };
            let waited = self.process.wait();
            self.cleaned = true;
            if !gone {
                return Err(Error::CaptureFailed);
            }
            waited.map(|_| ()).map_err(|_| Error::CaptureFailed)
        }
    }
    impl Drop for Child {
        fn drop(&mut self) {
            let _ = self.cleanup();
        }
    }
    let mut child = Child {
        process: command
            .process_group(0)
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::null())
            .spawn()
            .map_err(|_| Error::CaptureFailed)?,
        cleaned: false,
        protected_server,
    };
    let mut stdout = child.process.stdout.take().ok_or(Error::CaptureFailed)?;
    let flags = unsafe { fcntl(stdout.as_raw_fd(), 3) };
    if flags < 0 || unsafe { fcntl(stdout.as_raw_fd(), 4, flags | 4) } < 0 {
        return Err(Error::CaptureFailed);
    }
    let start = std::time::Instant::now();
    let mut bytes = Vec::new();
    let mut eof = false;
    loop {
        if start.elapsed() >= std::time::Duration::from_secs(2) {
            return Err(Error::CaptureFailed);
        }
        let mut buffer = [0u8; 8192];
        match stdout.read(&mut buffer) {
            Ok(0) => eof = true,
            Ok(count) => {
                if bytes.len() + count > 8 * 1024 * 1024 {
                    return Err(Error::CaptureFailed);
                }
                bytes.extend_from_slice(&buffer[..count]);
                continue;
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => (),
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => continue,
            Err(_) => return Err(Error::CaptureFailed),
        }
        let mut info = unsafe { std::mem::zeroed::<SignalInfo>() };
        if unsafe { waitid(1, child.process.id(), &mut info, 0x25) } != 0 {
            if std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            return Err(Error::CaptureFailed);
        }
        if info.pid != 0 {
            let valid =
                info.pid == child.process.id() as i32 && info.code == 1 && info.status == 0 && eof;
            child.cleanup()?;
            return if valid {
                Ok(bytes)
            } else {
                Err(Error::CaptureFailed)
            };
        }
        std::thread::sleep(std::time::Duration::from_millis(5));
    }
}

#[cfg(target_os = "macos")]
fn group_has_running(group: u32) -> Result<bool, Error> {
    #[link(name = "proc")]
    unsafe extern "C" {
        fn proc_listpids(kind: u32, info: u32, buffer: *mut std::ffi::c_void, size: i32) -> i32;
    }
    let mut pids = [0u32; 4096];
    let size = std::mem::size_of_val(&pids) as i32;
    let count = unsafe { proc_listpids(2, group, pids.as_mut_ptr().cast(), size) };
    if count < 0 || count >= size || count % 4 != 0 {
        return Err(Error::CaptureFailed);
    }
    for pid in pids[..count as usize / 4]
        .iter()
        .copied()
        .filter(|pid| *pid != 0 && *pid != group)
    {
        let (identity, status) = kernel_process_details(pid).ok_or(Error::CaptureFailed)?;
        if identity.group == group && status != 5 {
            return Ok(true);
        }
    }
    Ok(false)
}
#[derive(Default)]
pub struct Snapshot {
    pub sessions: HashMap<SessionId, String>,
    pub windows: HashMap<SessionId, Vec<Window>>,
    pub panes: HashMap<WindowId, Vec<Pane>>,
}
impl Snapshot {
    pub fn capture() -> Result<Self, Error> {
        Err(Error::InvalidNamespace)
    }
    pub fn parse(mut capture: &[u8]) -> Result<Self, Error> {
        let mut snapshot = Self::default();
        let mut window_names = HashMap::new();
        let mut links = HashSet::new();
        let mut pane_rows: HashMap<PaneId, (WindowId, Pane)> = HashMap::new();
        while !capture.is_empty() {
            let session_id = SessionId(id(field(&mut capture, b'\t')?, b'$')?);
            let window_id = WindowId(id(field(&mut capture, b'\t')?, b'@')?);
            let pane_id = PaneId(id(field(&mut capture, b'\t')?, b'%')?);
            let pid = u32::try_from(number(field(&mut capture, b'\t')?)?)
                .map_err(|_| Error::InvalidCapture)?;
            let dead = match field(&mut capture, b'\t')? {
                b"0" => false,
                b"1" => true,
                _ => return Err(Error::InvalidCapture),
            };
            if !dead && pid == 0 {
                return Err(Error::InvalidCapture);
            }
            let session_name = name(&mut capture)?;
            let window_name = name(&mut capture)?;
            if capture.first() != Some(&b'\n') {
                return Err(Error::InvalidCapture);
            }
            capture = &capture[1..];
            if snapshot
                .sessions
                .get(&session_id)
                .is_some_and(|value| value != &session_name)
            {
                return Err(Error::InvalidCapture);
            }
            snapshot.sessions.insert(session_id, session_name);
            match window_names.get(&window_id) {
                Some(previous) if previous != &window_name => return Err(Error::InvalidCapture),
                Some(_) => (),
                None => {
                    window_names.insert(window_id, window_name.clone());
                }
            }
            if links.insert((session_id, window_id)) {
                snapshot
                    .windows
                    .entry(session_id)
                    .or_default()
                    .push(Window {
                        id: window_id,
                        name: window_name,
                    });
            }
            let pane = Pane {
                id: pane_id,
                pid,
                dead,
            };
            match pane_rows.get(&pane_id) {
                Some((wid, previous)) if *wid != window_id || previous != &pane => {
                    return Err(Error::InvalidCapture)
                }
                Some(_) => (),
                None => {
                    pane_rows.insert(pane_id, (window_id, pane.clone()));
                    snapshot.panes.entry(window_id).or_default().push(pane);
                }
            }
        }
        Ok(snapshot)
    }
}
pub const CAPTURE_FORMAT: &str="#{session_id}\t#{window_id}\t#{pane_id}\t#{pane_pid}\t#{pane_dead}\t#{n:session_name}:#{session_name}#{n:window_name}:#{window_name}";
fn field<'a>(capture: &mut &'a [u8], separator: u8) -> Result<&'a [u8], Error> {
    let at = capture
        .iter()
        .position(|b| *b == separator)
        .ok_or(Error::InvalidCapture)?;
    let value = &capture[..at];
    *capture = &capture[at + 1..];
    Ok(value)
}
fn number(value: &[u8]) -> Result<u64, Error> {
    if value.is_empty() || !value.iter().all(u8::is_ascii_digit) {
        return Err(Error::InvalidCapture);
    }
    std::str::from_utf8(value)
        .map_err(|_| Error::InvalidCapture)?
        .parse()
        .map_err(|_| Error::InvalidCapture)
}
fn id(value: &[u8], prefix: u8) -> Result<u64, Error> {
    if value.first() != Some(&prefix) {
        return Err(Error::InvalidCapture);
    }
    number(&value[1..])
}
fn name(capture: &mut &[u8]) -> Result<String, Error> {
    let length =
        usize::try_from(number(field(capture, b':')?)?).map_err(|_| Error::InvalidCapture)?;
    let value = capture.get(..length).ok_or(Error::InvalidCapture)?;
    let result = std::str::from_utf8(value)
        .map_err(|_| Error::InvalidCapture)?
        .to_owned();
    *capture = &capture[length..];
    Ok(result)
}
pub fn split_route(route: &str) -> Result<(&str, &str), Error> {
    let (session, window) = route.rsplit_once(':').ok_or(Error::MissingWindow)?;
    if session.is_empty() {
        return Err(Error::MissingSession);
    }
    if window.is_empty() {
        return Err(Error::MissingWindow);
    }
    Ok((session, window))
}
fn unique<T>(rows: impl Iterator<Item = T>, missing: Error, ambiguous: Error) -> Result<T, Error> {
    let mut rows = rows;
    let first = rows.next().ok_or(missing)?;
    if rows.next().is_some() {
        return Err(ambiguous);
    }
    Ok(first)
}
pub fn resolve(
    snapshot: &Snapshot,
    session: &str,
    window: &str,
    pane: Option<PaneId>,
) -> Result<Target, Error> {
    let (&session_id, session_name) = unique(
        snapshot
            .sessions
            .iter()
            .filter(|(_, name)| name.as_str() == session),
        Error::MissingSession,
        Error::AmbiguousSession,
    )?;
    let windows = snapshot
        .windows
        .get(&session_id)
        .ok_or(Error::MissingWindow)?;
    let window = unique(
        windows.iter().filter(|w| w.name == window),
        Error::MissingWindow,
        Error::AmbiguousWindow,
    )?;
    let panes = snapshot.panes.get(&window.id).ok_or(Error::MissingPane)?;
    let pane = unique(
        panes
            .iter()
            .filter(|p| !p.dead && pane.is_none_or(|id| p.id == id)),
        Error::MissingPane,
        Error::AmbiguousPane,
    )?;
    Ok(Target {
        session_id,
        session_name: session_name.clone(),
        window: window.clone(),
        pane: pane.clone(),
    })
}
pub fn revalidate(snapshot: &Snapshot, expected: &Target) -> Result<(), Error> {
    let current = resolve(
        snapshot,
        &expected.session_name,
        &expected.window.name,
        Some(expected.pane.id),
    )?;
    if current != *expected {
        return Err(Error::Changed);
    }
    Ok(())
}

pub fn source_candidate(
    snapshot: &Snapshot,
    mut process: u32,
    parents: &HashMap<u32, u32>,
) -> Option<Target> {
    let mut sources: HashMap<u32, Option<Target>> = HashMap::new();
    for (session_id, windows) in &snapshot.windows {
        let session_name = snapshot.sessions.get(session_id)?;
        for window in windows {
            for pane in snapshot
                .panes
                .get(&window.id)?
                .iter()
                .filter(|pane| !pane.dead)
            {
                sources
                    .entry(pane.pid)
                    .and_modify(|candidate| *candidate = None)
                    .or_insert_with(|| {
                        Some(Target {
                            session_id: *session_id,
                            session_name: session_name.clone(),
                            window: window.clone(),
                            pane: pane.clone(),
                        })
                    });
            }
        }
    }
    let mut visited = HashSet::new();
    while process > 1 && visited.insert(process) {
        if let Some(candidate) = sources.get(&process) {
            return candidate.clone();
        }
        process = *parents.get(&process)?;
    }
    None
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ProcessIdentity {
    pub pid: u32,
    pub parent: u32,
    pub start_seconds: u64,
    pub start_microseconds: u64,
    pub group: u32,
    pub foreground_group: u32,
    pub tty: u32,
}

#[cfg(target_os = "macos")]
pub fn kernel_process(pid: u32) -> Option<ProcessIdentity> {
    kernel_process_details(pid).map(|(identity, _)| identity)
}

#[cfg(target_os = "macos")]
fn kernel_process_details(pid: u32) -> Option<(ProcessIdentity, u32)> {
    #[repr(C)]
    struct BsdInfo {
        flags: u32,
        status: u32,
        exit_status: u32,
        pid: u32,
        parent: u32,
        credentials_and_reserved: [u32; 7],
        command: [u8; 16],
        name: [u8; 32],
        file_count: u32,
        group: u32,
        job_count: u32,
        tty: u32,
        foreground_group: u32,
        nice: i32,
        start_seconds: u64,
        start_microseconds: u64,
    }
    #[link(name = "proc")]
    unsafe extern "C" {
        fn proc_pidinfo(
            pid: i32,
            flavor: i32,
            arg: u64,
            buffer: *mut std::ffi::c_void,
            size: i32,
        ) -> i32;
    }
    let native_pid = i32::try_from(pid).ok().filter(|pid| *pid > 0)?;
    let mut info = std::mem::MaybeUninit::<BsdInfo>::zeroed();
    let size = i32::try_from(std::mem::size_of::<BsdInfo>()).ok()?;
    let returned = unsafe { proc_pidinfo(native_pid, 3, 0, info.as_mut_ptr().cast(), size) };
    if returned != size {
        return None;
    }
    let info = unsafe { info.assume_init() };
    if info.pid != pid || info.start_seconds == 0 || info.start_microseconds >= 1_000_000 {
        return None;
    }
    Some((
        ProcessIdentity {
            pid,
            parent: info.parent,
            start_seconds: info.start_seconds,
            start_microseconds: info.start_microseconds,
            group: info.group,
            foreground_group: info.foreground_group,
            tty: info.tty,
        },
        info.status,
    ))
}

#[cfg(target_os = "macos")]
pub fn kernel_ancestry(mut process: u32) -> Option<Vec<ProcessIdentity>> {
    let mut chain = Vec::new();
    let mut visited = HashSet::new();
    while process > 1 && visited.insert(process) {
        let identity = kernel_process(process)?;
        process = identity.parent;
        chain.push(identity);
    }
    (process == 1
        && !chain.is_empty()
        && chain
            .iter()
            .all(|row| kernel_process(row.pid) == Some(*row)))
    .then_some(chain)
}

#[cfg(target_os = "macos")]
pub fn captured_source() -> Result<Option<(Target, Vec<ProcessIdentity>)>, Error> {
    let before = Snapshot::capture()?;
    let process = std::process::id();
    let Some(ancestry) = kernel_ancestry(process) else {
        return Ok(None);
    };
    let parents = ancestry.iter().map(|row| (row.pid, row.parent)).collect();
    let Some(source) = source_candidate(&before, process, &parents) else {
        return Ok(None);
    };
    let after = Snapshot::capture()?;
    revalidate(&after, &source)?;
    if source_candidate(&after, process, &parents).as_ref() != Some(&source) {
        return Err(Error::Changed);
    }
    if !ancestry
        .iter()
        .all(|row| kernel_process(row.pid) == Some(*row))
    {
        return Err(Error::Changed);
    }
    Ok(Some((source, ancestry)))
}
