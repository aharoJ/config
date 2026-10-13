use crate::target::Target;

#[derive(Debug, PartialEq, Eq)]
pub struct Envelope {
    pub label: String,
    pub message: String,
    pub codes: Vec<String>,
}

impl Envelope {
    pub fn render(&self) -> String {
        format!("{}: {}", self.label, self.message)
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum Error {
    EmptyMessage,
    InvalidGeneratedCode,
    Source(crate::target::Error),
    Target(crate::target::Error),
    InvalidStore,
    InvalidRecordId,
    Publication(std::io::ErrorKind),
    PublicationCommittedUncertain {
        path: std::path::PathBuf,
        cause: std::io::ErrorKind,
    },
}

#[derive(Debug)]
pub struct Prepared {
    target: Target,
    source: Option<Target>,
    envelope: Envelope,
    ancestry: Vec<crate::target::ProcessIdentity>,
    server: Option<crate::target::ProcessIdentity>,
}

impl Prepared {
    pub fn target(&self) -> &Target {
        &self.target
    }
    pub fn source(&self) -> Option<&Target> {
        self.source.as_ref()
    }
    pub fn envelope(&self) -> &Envelope {
        &self.envelope
    }
}

#[cfg(target_os = "macos")]
pub fn prepare(
    session: &str,
    window: &str,
    pane: Option<crate::target::PaneId>,
    message: &str,
    generated: &str,
) -> Result<Prepared, Error> {
    let snapshot = crate::target::Snapshot::capture().map_err(Error::Target)?;
    let target = crate::target::resolve(&snapshot, session, window, pane).map_err(Error::Target)?;
    let (source, ancestry) = crate::target::captured_source()
        .map_err(Error::Source)?
        .map_or_else(
            || (None, Vec::new()),
            |(target, chain)| (Some(target), chain),
        );
    let envelope = envelope(source.as_ref(), message, generated)?;
    crate::target::revalidate(
        &crate::target::Snapshot::capture().map_err(Error::Target)?,
        &target,
    )
    .map_err(Error::Target)?;
    Ok(Prepared {
        target,
        source,
        envelope,
        ancestry,
        server: None,
    })
}

#[cfg(target_os = "macos")]
pub fn prepare_in(
    namespace: &crate::target::Namespace,
    session: &str,
    window: &str,
    pane: Option<crate::target::PaneId>,
    message: &str,
    generated: &str,
) -> Result<Prepared, Error> {
    let snapshot = namespace.capture().map_err(Error::Target)?;
    let target = crate::target::resolve(&snapshot, session, window, pane).map_err(Error::Target)?;
    let ancestry = crate::target::kernel_ancestry(std::process::id())
        .ok_or(Error::Source(crate::target::Error::Changed))?;
    let parents = ancestry.iter().map(|row| (row.pid, row.parent)).collect();
    let source = crate::target::source_candidate(&snapshot, std::process::id(), &parents);
    let envelope = envelope(source.as_ref(), message, generated)?;
    let prepared = Prepared {
        target,
        source,
        envelope,
        ancestry,
        server: Some(namespace.server()),
    };
    prepared.revalidate_in(namespace)?;
    Ok(prepared)
}

#[cfg(target_os = "macos")]
impl Prepared {
    pub fn identity_condition(
        &self,
        namespace: &crate::target::Namespace,
    ) -> Result<String, Error> {
        self.revalidate_in(namespace)?;
        namespace.verify_peer_image().map_err(Error::Target)?;
        let literal = |value: &str| {
            value
                .chars()
                .map(|ch| match ch {
                    '#' => "##".to_owned(),
                    ',' => "#,".to_owned(),
                    '}' => "#}".to_owned(),
                    ch => ch.to_string(),
                })
                .collect::<String>()
        };
        let checks = [
            ("pid", namespace.server().pid.to_string()),
            ("session_id", format!("${}", self.target.session_id.0)),
            ("window_id", format!("@{}", self.target.window.id.0)),
            ("pane_id", self.target.selector()),
            ("pane_pid", self.target.pane.pid.to_string()),
            ("pane_dead", "0".to_owned()),
            ("pane_in_mode", "0".to_owned()),
            ("session_name", literal(&self.target.session_name)),
            ("window_name", literal(&self.target.window.name)),
        ];
        let expression = checks
            .into_iter()
            .map(|(key, value)| format!("#{{==:#{{{key}}},{value}}}"))
            .collect::<Vec<_>>()
            .join(",");
        Ok(format!("#{{&&:{expression}}}"))
    }

    pub fn revalidate_in(&self, namespace: &crate::target::Namespace) -> Result<(), Error> {
        if self.server != Some(namespace.server()) {
            return Err(Error::Target(crate::target::Error::Changed));
        }
        let snapshot = namespace.capture().map_err(Error::Target)?;
        crate::target::revalidate(&snapshot, &self.target).map_err(Error::Target)?;
        if self.ancestry.first().map(|row| row.pid) != Some(std::process::id())
            || !self
                .ancestry
                .iter()
                .all(|row| crate::target::kernel_process(row.pid) == Some(*row))
        {
            return Err(Error::Source(crate::target::Error::Changed));
        }
        let parents = self
            .ancestry
            .iter()
            .map(|row| (row.pid, row.parent))
            .collect();
        if crate::target::source_candidate(&snapshot, std::process::id(), &parents) != self.source {
            return Err(Error::Source(crate::target::Error::Changed));
        }
        Ok(())
    }
}

#[derive(Debug)]
pub struct Publication {
    pub path: std::path::PathBuf,
    pub pointer: String,
}

#[cfg(target_os = "macos")]
pub fn prepare_and_publish(
    session: &str,
    window: &str,
    pane: Option<crate::target::PaneId>,
    message: &str,
    directory: &std::path::Path,
) -> Result<(Prepared, Publication), Error> {
    use std::io::Read;
    let mut nonce = [0u8; 16];
    std::fs::File::open("/dev/urandom")
        .and_then(|mut file| file.read_exact(&mut nonce))
        .map_err(|error| Error::Publication(error.kind()))?;
    let id = nonce
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect::<String>();
    let prepared = prepare(session, window, pane, message, &id)?;
    let publication = prepared.publish(directory, &id)?;
    Ok((prepared, publication))
}

#[cfg(target_os = "macos")]
impl Prepared {
    pub fn publish(&self, directory: &std::path::Path, id: &str) -> Result<Publication, Error> {
        self.publish_with_check(directory, id, |_| Ok(()))
    }

    fn publish_with_check(
        &self,
        directory: &std::path::Path,
        id: &str,
        mut check: impl FnMut(&str) -> std::io::Result<()>,
    ) -> Result<Publication, Error> {
        use std::io::Write;
        use std::os::fd::{AsRawFd, FromRawFd};
        use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
        unsafe extern "C" {
            fn geteuid() -> u32;
            fn openat(fd: i32, name: *const std::ffi::c_char, flags: i32, ...) -> i32;
            fn renameatx_np(
                oldfd: i32,
                old: *const std::ffi::c_char,
                newfd: i32,
                new: *const std::ffi::c_char,
                flags: u32,
            ) -> i32;
            fn unlinkat(fd: i32, name: *const std::ffi::c_char, flags: i32) -> i32;
        }
        if id.len() != 32
            || !id
                .bytes()
                .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
        {
            return Err(Error::InvalidRecordId);
        }
        if !directory.is_absolute()
            || directory.to_str().is_none()
            || std::fs::canonicalize(directory).ok().as_deref() != Some(directory)
        {
            return Err(Error::InvalidStore);
        }
        let metadata = std::fs::symlink_metadata(directory).map_err(|_| Error::InvalidStore)?;
        if !metadata.is_dir()
            || metadata.mode() & 0o777 != 0o700
            || metadata.uid() != unsafe { geteuid() }
        {
            return Err(Error::InvalidStore);
        }
        let root = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(0x01000100)
            .open(directory)
            .map_err(|_| Error::InvalidStore)?;
        let pinned = root.metadata().map_err(|_| Error::InvalidStore)?;
        if (pinned.dev(), pinned.ino()) != (metadata.dev(), metadata.ino()) {
            return Err(Error::InvalidStore);
        }
        if !has_no_acl(&root).map_err(|_| Error::InvalidStore)? {
            return Err(Error::InvalidStore);
        }
        static SERIAL: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let pending = std::ffi::CString::new(format!(
            ".{id}.{}.{}.pending",
            std::process::id(),
            SERIAL.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ))
        .unwrap();
        let final_name = std::ffi::CString::new(format!("{id}.json")).unwrap();
        let fd = unsafe { openat(root.as_raw_fd(), pending.as_ptr(), 0x01000b01, 0o600u32) };
        if fd < 0 {
            return Err(Error::Publication(std::io::Error::last_os_error().kind()));
        }
        let file = unsafe { std::fs::File::from_raw_fd(fd) };
        struct Pending<'a> {
            root: &'a std::fs::File,
            name: &'a std::ffi::CString,
            file: std::fs::File,
            committed: bool,
        }
        impl Drop for Pending<'_> {
            fn drop(&mut self) {
                if self.committed {
                    return;
                }
                let cleanup_fd =
                    unsafe { openat(self.root.as_raw_fd(), self.name.as_ptr(), 0x01000100) };
                if cleanup_fd < 0 {
                    return;
                }
                let cleanup = unsafe { std::fs::File::from_raw_fd(cleanup_fd) };
                if let (Ok(current), Ok(owned)) = (cleanup.metadata(), self.file.metadata()) {
                    if (current.dev(), current.ino()) == (owned.dev(), owned.ino()) {
                        unsafe {
                            unlinkat(self.root.as_raw_fd(), self.name.as_ptr(), 0);
                        }
                    }
                }
            }
        }
        let mut pending_guard = Pending {
            root: &root,
            name: &pending,
            file,
            committed: false,
        };
        use std::os::unix::fs::PermissionsExt;
        check("permissions").map_err(|error| Error::Publication(error.kind()))?;
        pending_guard
            .file
            .set_permissions(std::fs::Permissions::from_mode(0o600))
            .map_err(|error| Error::Publication(error.kind()))?;
        if !has_no_acl(&pending_guard.file).map_err(|error| Error::Publication(error.kind()))? {
            return Err(Error::Publication(std::io::ErrorKind::PermissionDenied));
        }
        check("metadata").map_err(|error| Error::Publication(error.kind()))?;
        let owned = pending_guard
            .file
            .metadata()
            .map_err(|error| Error::Publication(error.kind()))?;
        let body = self.record(id);
        let result = (|| -> std::io::Result<()> {
            pending_guard.file.write_all(body.as_bytes())?;
            pending_guard.file.sync_all()?;
            if unsafe {
                renameatx_np(
                    root.as_raw_fd(),
                    pending.as_ptr(),
                    root.as_raw_fd(),
                    final_name.as_ptr(),
                    4,
                )
            } != 0
            {
                return Err(std::io::Error::last_os_error());
            }
            pending_guard.committed = true;
            check("directory-sync")?;
            root.sync_all()?;
            check("verification")?;
            let verified_fd = unsafe { openat(root.as_raw_fd(), final_name.as_ptr(), 0x01000100) };
            if verified_fd < 0 {
                return Err(std::io::Error::last_os_error());
            }
            let verified = unsafe { std::fs::File::from_raw_fd(verified_fd) };
            let current = verified.metadata()?;
            if !has_no_acl(&verified)? || !has_no_acl(&root)? {
                return Err(std::io::Error::from(std::io::ErrorKind::PermissionDenied));
            }
            if !current.is_file() || (current.dev(), current.ino()) != (owned.dev(), owned.ino()) {
                return Err(std::io::Error::from(std::io::ErrorKind::Interrupted));
            }
            check("root-recheck")?;
            let now = std::fs::symlink_metadata(directory)?;
            if (now.dev(), now.ino()) != (pinned.dev(), pinned.ino())
                || std::fs::canonicalize(directory)?.as_path() != directory
            {
                return Err(std::io::Error::from(std::io::ErrorKind::Interrupted));
            }
            Ok(())
        })();
        let path = directory.join(final_name.to_str().unwrap());
        result.map_err(|error| {
            if pending_guard.committed {
                Error::PublicationCommittedUncertain {
                    path: path.clone(),
                    cause: error.kind(),
                }
            } else {
                Error::Publication(error.kind())
            }
        })?;
        let codes = self
            .envelope
            .codes
            .iter()
            .map(|code| format!("#{code}"))
            .collect::<Vec<_>>()
            .join(" ");
        let pointer = format!(
            "{} {codes} -- full: {}",
            self.envelope.label,
            json_string(path.to_str().unwrap())
        );
        Ok(Publication { path, pointer })
    }

    fn record(&self, id: &str) -> String {
        fn target(value: &Target) -> String {
            format!("{{\"session_id\":\"{}\",\"window_id\":\"{}\",\"pane_id\":\"{}\",\"pane_pid\":{},\"session\":{},\"window\":{}}}", value.session_id.0, value.window.id.0, value.pane.id.0, value.pane.pid, json_string(&value.session_name), json_string(&value.window.name))
        }
        let source = self
            .source
            .as_ref()
            .map_or_else(|| "null".to_owned(), target);
        let codes = self
            .envelope
            .codes
            .iter()
            .map(|code| json_string(code))
            .collect::<Vec<_>>()
            .join(",");
        let generations = self.ancestry.iter().map(|row| format!("{{\"pid\":{},\"parent\":{},\"start_seconds\":\"{}\",\"start_microseconds\":\"{}\"}}", row.pid, row.parent, row.start_seconds, row.start_microseconds)).collect::<Vec<_>>().join(",");
        format!("{{\"schema\":\"angelstar-message\",\"version\":1,\"state\":\"archived-no-input\",\"id\":{},\"target\":{},\"source\":{source},\"source_generations\":[{generations}],\"label\":{},\"message\":{},\"codes\":[{codes}],\"full_message\":{}}}\n", json_string(id), target(&self.target), json_string(&self.envelope.label), json_string(&self.envelope.message), json_string(&self.envelope.render()))
    }
}

#[cfg(target_os = "macos")]
pub(crate) fn has_no_acl(file: &std::fs::File) -> std::io::Result<bool> {
    use std::os::fd::AsRawFd;
    unsafe extern "C" {
        fn acl_get_fd_np(fd: i32, kind: i32) -> *mut std::ffi::c_void;
        fn acl_get_entry(
            acl: *mut std::ffi::c_void,
            entry_id: i32,
            entry: *mut *mut std::ffi::c_void,
        ) -> i32;
        fn acl_free(value: *mut std::ffi::c_void) -> i32;
    }
    let acl = unsafe { acl_get_fd_np(file.as_raw_fd(), 0x100) };
    if acl.is_null() {
        let error = std::io::Error::last_os_error();
        if error.raw_os_error() == Some(2) {
            return Ok(true);
        }
        return Err(error);
    }
    let mut entry = std::ptr::null_mut();
    let result = unsafe { acl_get_entry(acl, 0, &mut entry) };
    let error = std::io::Error::last_os_error();
    unsafe {
        acl_free(acl);
    }
    match result {
        0 => Ok(false),
        -1 if error.raw_os_error() == Some(22) => Ok(true),
        _ => Err(error),
    }
}

#[cfg(target_os = "macos")]
fn json_string(value: &str) -> String {
    let mut encoded = String::from("\"");
    for ch in value.chars() {
        match ch {
            '"' => encoded.push_str("\\\""),
            '\\' => encoded.push_str("\\\\"),
            '\n' => encoded.push_str("\\n"),
            '\r' => encoded.push_str("\\r"),
            '\t' => encoded.push_str("\\t"),
            ch if ch <= '\u{1f}' => encoded.push_str(&format!("\\u{:04x}", ch as u32)),
            ch => encoded.push(ch),
        }
    }
    encoded.push('"');
    encoded
}

#[cfg(all(test, target_os = "macos"))]
#[path = "../tests/support/publication.rs"]
mod publication_tests;

pub fn envelope(
    source: Option<&Target>,
    message: &str,
    generated: &str,
) -> Result<Envelope, Error> {
    if message
        .chars()
        .all(|ch| ch.is_whitespace() || matches!(ch, '\u{1c}'..='\u{1f}'))
    {
        return Err(Error::EmptyMessage);
    }
    let code_byte = |b: u8| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-');
    let mut codes = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for (at, byte) in message.bytes().enumerate() {
        if byte != b'#' {
            continue;
        }
        let tail = &message[at + 1..];
        let count = tail.bytes().take_while(|b| code_byte(*b)).count();
        if count > 0 {
            let code = &tail[..count];
            if seen.insert(code) {
                codes.push(code.to_owned());
            }
        }
    }
    let message = if codes.is_empty() {
        if generated.is_empty() || !generated.bytes().all(code_byte) {
            return Err(Error::InvalidGeneratedCode);
        }
        codes.push(generated.to_owned());
        format!("#{generated} {message}")
    } else {
        message.to_owned()
    };
    let label = source.map_or_else(
        || "relay".to_owned(),
        |source| {
            let window = source.window.name.escape_debug();
            format!("{window} ({}:{window})", source.session_name.escape_debug())
        },
    );
    Ok(Envelope {
        label,
        message,
        codes,
    })
}
