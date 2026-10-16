use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use std::ffi::CStr;
pub(crate) type Result<T> = std::result::Result<T, String>;
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
pub(crate) fn integer(key: &str, default: u64, max: u64, zero: bool) -> Result<u64> {
    let raw = std::env::var(key).unwrap_or_else(|_| default.to_string());
    if raw.is_empty()
        || !raw.bytes().all(|b| b.is_ascii_digit())
        || (raw.len() > 1 && raw.starts_with('0'))
    {
        return Err(format!("{key} must be a decimal integer"));
    }
    let n = raw.parse::<u64>().map_err(|_| format!("invalid {key}"))?;
    if n > max || (!zero && n == 0) {
        return Err(format!("{key} must be {}..{max}", if zero { 0 } else { 1 }));
    }
    Ok(n)
}
pub(crate) fn socket() -> PathBuf {
    env("TMUX")
        .rsplitn(3, ',')
        .last()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(format!("/private/tmp/tmux-{}/default", unsafe {
                libc::geteuid()
            }))
        })
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
pub(crate) fn bounded(command: &mut Command, seconds: u64) -> Result<Output> {
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
                    code: if timeout_stage > 0 {
                        124
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
                code: 124,
                out: std::mem::take(&mut bytes[0]),
                err: std::mem::take(&mut bytes[1]),
            });
        }
        std::thread::sleep(Duration::from_millis(2));
    }
}
pub(crate) fn tmux(socket: &Path, args: &[&str], seconds: u64) -> Result<Output> {
    bounded(
        Command::new(TMUX)
            .arg("-N")
            .arg("-S")
            .arg(socket)
            .args(args)
            .env_remove("TMUX")
            .env_remove("TMUX_PANE"),
        seconds,
    )
}
pub(crate) fn query(socket: &Path, args: &[&str], seconds: u64) -> Result<String> {
    let o = tmux(socket, args, seconds)?;
    if o.code == 0 {
        Ok(o.text().trim_end_matches('\n').into())
    } else {
        Err(if o.code == 124 {
            "tmux request timed out".into()
        } else {
            String::from_utf8_lossy(&o.err).into_owned()
        })
    }
}
pub(super) fn process_args(pid: u32) -> Option<Vec<String>> {
    let mut mib = [libc::CTL_KERN, 49, pid as i32];
    let mut size = 0;
    if unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            3,
            std::ptr::null_mut(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    } != 0
        || size < 5
    {
        return None;
    }
    let mut bytes = vec![0u8; size];
    if unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            3,
            bytes.as_mut_ptr().cast(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    } != 0
    {
        return None;
    }
    bytes.truncate(size);
    let argc = i32::from_ne_bytes(bytes[..4].try_into().ok()?);
    if !(1..=4096).contains(&argc) {
        return None;
    }
    let mut pos = 4 + bytes[4..].iter().position(|b| *b == 0)?;
    while bytes.get(pos) == Some(&0) {
        pos += 1;
    }
    let mut args = Vec::new();
    for _ in 0..argc {
        let end = pos + bytes.get(pos..)?.iter().position(|b| *b == 0)?;
        args.push(String::from_utf8(bytes[pos..end].to_vec()).ok()?);
        pos = end + 1;
    }
    Some(args)
}
pub(super) fn process_start(pid: u32) -> String {
    let Some(p) = crate::identity::kernel_process(pid) else {
        return String::new();
    };
    let seconds = p.start_seconds as libc::time_t;
    let mut tm = unsafe { std::mem::zeroed() };
    let mut bytes = [0u8; 64];
    unsafe {
        libc::localtime_r(&seconds, &mut tm);
        libc::strftime(
            bytes.as_mut_ptr().cast(),
            bytes.len(),
            c"%a %b %e %T %Y".as_ptr(),
            &tm,
        );
        CStr::from_ptr(bytes.as_ptr().cast())
            .to_string_lossy()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }
}
