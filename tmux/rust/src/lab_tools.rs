use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::fs::{DirBuilderExt, FileTypeExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::process::{CommandExt, ExitStatusExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub(crate) mod freeze;
type Result<T> = std::result::Result<T, String>;
pub(crate) const TMUX: &str = "/opt/homebrew/Cellar/tmux/3.7c/bin/tmux";

pub(crate) fn env(key: &str) -> String {
    std::env::var(key).unwrap_or_default()
}
pub(crate) fn setting(key: &str, default: &str) -> String {
    let v = env(key);
    if v.trim().is_empty() {
        default.into()
    } else {
        v.trim().into()
    }
}
pub(crate) fn epoch_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}
pub(crate) fn stamp() -> String {
    let seconds = (epoch_ms() / 1000) as libc::time_t;
    let mut value: libc::tm = unsafe { std::mem::zeroed() };
    unsafe {
        libc::gmtime_r(&seconds, &mut value);
    }
    format!(
        "{:04}{:02}{:02}T{:02}{:02}{:02}Z",
        value.tm_year + 1900,
        value.tm_mon + 1,
        value.tm_mday,
        value.tm_hour,
        value.tm_min,
        value.tm_sec
    )
}
pub(crate) fn home() -> PathBuf {
    PathBuf::from(env("HOME"))
}
#[cfg(test)]
pub(crate) fn fresh() -> Result<String> {
    let mut b = [0u8; 16];
    File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut b))
        .map_err(|e| e.to_string())?;
    Ok(b.iter().map(|v| format!("{v:02x}")).collect())
}
pub(crate) fn private_dir(path: &Path) -> Result<()> {
    fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .map_err(|e| e.to_string())?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o700)).map_err(|e| e.to_string())
}
pub(crate) fn write(path: &Path, bytes: impl AsRef<[u8]>) -> Result<()> {
    let mut file = OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
        .map_err(|e| e.to_string())?;
    file.set_permissions(fs::Permissions::from_mode(0o600))
        .map_err(|e| e.to_string())?;
    file.write_all(bytes.as_ref()).map_err(|e| e.to_string())
}
pub(crate) fn is_socket(path: &Path) -> bool {
    fs::metadata(path).is_ok_and(|m| m.file_type().is_socket())
}
pub(crate) struct Output {
    pub code: i32,
    pub out: Vec<u8>,
    pub err: Vec<u8>,
}
impl Output {
    pub fn text(&self) -> String {
        String::from_utf8_lossy(&self.out).into_owned()
    }
}
pub(crate) fn bounded_status(
    command: &mut Command,
    seconds: u64,
    preserve_signal: bool,
) -> Result<Output> {
    command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0);
    let mut child = command.spawn().map_err(|e| e.to_string())?;
    let child_identity = crate::identity::kernel_process(child.id());
    let mut pipes: Vec<File> = vec![
        File::from(OwnedFd::from(child.stdout.take().unwrap())),
        File::from(OwnedFd::from(child.stderr.take().unwrap())),
    ];
    for pipe in &pipes {
        let flags = unsafe { libc::fcntl(pipe.as_raw_fd(), libc::F_GETFL) };
        if flags < 0
            || unsafe { libc::fcntl(pipe.as_raw_fd(), libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0
        {
            return Err("cannot bound command output".into());
        }
    }
    let mut deadline = Instant::now() + Duration::from_secs(seconds);
    let mut timeout_stage = 0;
    let mut bytes = [Vec::new(), Vec::new()];
    let mut eof = [false; 2];
    loop {
        for (i, pipe) in pipes.iter_mut().enumerate() {
            let mut buf = [0; 16384];
            for _ in 0..16 {
                match pipe.read(&mut buf) {
                    Ok(0) => {
                        eof[i] = true;
                        break;
                    }
                    Ok(n) => bytes[i].extend_from_slice(&buf[..n]),
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                    Err(e) => return Err(e.to_string()),
                }
            }
        }
        let status = child.try_wait().map_err(|e| e.to_string())?;
        if let Some(status) = status {
            if eof.iter().all(|v| *v) {
                return Ok(Output {
                    code: if preserve_signal && timeout_stage == 2 {
                        137
                    } else if timeout_stage > 0 {
                        124
                    } else if preserve_signal {
                        status
                            .code()
                            .unwrap_or_else(|| 128 + status.signal().unwrap_or(0))
                    } else {
                        status.code().unwrap_or(1)
                    },
                    out: std::mem::take(&mut bytes[0]),
                    err: std::mem::take(&mut bytes[1]),
                });
            }
        }
        if Instant::now() >= deadline {
            if timeout_stage < 2
                && child_identity.is_some_and(|p| {
                    crate::identity::kernel_process(child.id())
                        .is_some_and(|live| live.same(p) && live.parent == std::process::id())
                })
            {
                unsafe {
                    libc::kill(
                        -(child.id() as i32),
                        if timeout_stage == 0 {
                            libc::SIGTERM
                        } else {
                            libc::SIGKILL
                        },
                    );
                }
                timeout_stage += 1;
                deadline = Instant::now() + Duration::from_secs(1);
                continue;
            }
            let _ = child.try_wait();
            return Ok(Output {
                code: if preserve_signal && timeout_stage == 2 {
                    137
                } else {
                    124
                },
                out: std::mem::take(&mut bytes[0]),
                err: std::mem::take(&mut bytes[1]),
            });
        }
        std::thread::sleep(Duration::from_millis(2));
    }
}
