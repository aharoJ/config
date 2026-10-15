use serde::de::{self, Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::ffi::CString;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Component, Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

pub type Result<T> = std::result::Result<T, String>;
pub const MAX_BYTES: u64 = 64 * 1024 * 1024;
pub fn check(ok: bool, message: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(message.into())
    }
}
pub fn io<T>(result: std::io::Result<T>) -> Result<T> {
    result.map_err(|e| e.to_string())
}
pub fn s<'a>(v: &'a Value, key: &str) -> Result<&'a str> {
    v.get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("missing/string field: {key}"))
}
pub fn a<'a>(v: &'a Value, key: &str) -> Result<&'a Vec<Value>> {
    v.get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| format!("missing/array field: {key}"))
}
pub fn closed(v: &Value, keys: &[&str]) -> bool {
    v.as_object()
        .is_some_and(|m| m.len() == keys.len() && keys.iter().all(|k| m.contains_key(*k)))
}
pub fn subset(v: &Value, expected: &Value) -> bool {
    expected
        .as_object()
        .is_some_and(|m| m.iter().all(|(k, x)| v.get(k) == Some(x)))
}
pub fn fields(v: &Value, keys: &[&str]) -> Value {
    Value::Object(keys.iter().map(|k| ((*k).into(), v[*k].clone())).collect())
}
pub fn merge(mut v: Value, extra: Value) -> Value {
    if let (Some(v), Some(extra)) = (v.as_object_mut(), extra.as_object()) {
        v.extend(extra.clone());
    }
    v
}
pub fn external(key: &str) -> &'static Value {
    static DATA: std::sync::OnceLock<Value> = std::sync::OnceLock::new();
    &DATA.get_or_init(|| serde_json::from_str(include_str!("../panel_external.json")).unwrap())[key]
}
pub fn ext(key: &str) -> &'static str {
    external(key).as_str().unwrap()
}
pub fn home() -> Result<PathBuf> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .map(Ok)
        .unwrap_or_else(crate::identity::account_home)
}
pub fn now() -> String {
    chrono::DateTime::<chrono::Utc>::from(std::time::SystemTime::now())
        .to_rfc3339_opts(chrono::SecondsFormat::Secs, false)
}
pub fn instant(value: &str) -> Result<chrono::DateTime<chrono::FixedOffset>> {
    chrono::DateTime::parse_from_rfc3339(value).map_err(|e| e.to_string())
}
pub fn hash(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
pub fn quote(value: &str) -> String {
    if !value.is_empty()
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_@%+=:,./-".contains(&b))
    {
        value.into()
    } else {
        format!("'{}'", value.replace('\'', "'\"'\"'"))
    }
}

struct Strict(Value);
impl<'de> Deserialize<'de> for Strict {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> std::result::Result<Self, D::Error> {
        struct V;
        impl<'de> Visitor<'de> for V {
            type Value = Strict;
            fn expecting(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
                f.write_str("strict JSON")
            }
            fn visit_bool<E: de::Error>(self, v: bool) -> std::result::Result<Strict, E> {
                Ok(Strict(v.into()))
            }
            fn visit_i64<E: de::Error>(self, v: i64) -> std::result::Result<Strict, E> {
                Ok(Strict(v.into()))
            }
            fn visit_u64<E: de::Error>(self, v: u64) -> std::result::Result<Strict, E> {
                Ok(Strict(v.into()))
            }
            fn visit_f64<E: de::Error>(self, v: f64) -> std::result::Result<Strict, E> {
                serde_json::Number::from_f64(v)
                    .map(|v| Strict(Value::Number(v)))
                    .ok_or_else(|| E::custom("nonfinite JSON"))
            }
            fn visit_str<E: de::Error>(self, v: &str) -> std::result::Result<Strict, E> {
                Ok(Strict(v.into()))
            }
            fn visit_string<E: de::Error>(self, v: String) -> std::result::Result<Strict, E> {
                Ok(Strict(v.into()))
            }
            fn visit_unit<E: de::Error>(self) -> std::result::Result<Strict, E> {
                Ok(Strict(Value::Null))
            }
            fn visit_seq<A: SeqAccess<'de>>(
                self,
                mut a: A,
            ) -> std::result::Result<Strict, A::Error> {
                let mut v = Vec::new();
                while let Some(x) = a.next_element::<Strict>()? {
                    v.push(x.0);
                }
                Ok(Strict(v.into()))
            }
            fn visit_map<A: MapAccess<'de>>(
                self,
                mut a: A,
            ) -> std::result::Result<Strict, A::Error> {
                let mut v = Map::new();
                while let Some(k) = a.next_key::<String>()? {
                    if v.contains_key(&k) {
                        return Err(de::Error::custom(format!("duplicate JSON key: {k}")));
                    }
                    v.insert(k, a.next_value::<Strict>()?.0);
                }
                Ok(Strict(v.into()))
            }
        }
        deserializer.deserialize_any(V)
    }
}
pub fn decode(bytes: &[u8]) -> Result<Value> {
    let mut depth = 0u32;
    let mut quoted = false;
    let mut escaped = false;
    for c in bytes {
        if quoted {
            if escaped {
                escaped = false;
            } else if *c == b'\\' {
                escaped = true;
            } else if *c == b'"' {
                quoted = false;
            }
        } else if *c == b'"' {
            quoted = true;
        } else if b"[{".contains(c) {
            depth += 1;
            check(depth <= 32, "JSON depth exceeds limit")?;
        } else if b"]}".contains(c) {
            depth = depth.saturating_sub(1);
        }
    }
    serde_json::from_slice::<Strict>(bytes)
        .map(|v| v.0)
        .map_err(|e| e.to_string())
}
fn stamp(m: &fs::Metadata) -> (u64, u64, u64, i64, i64, i64, i64) {
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
fn named(parent: &File, name: &str) -> Result<fs::Metadata> {
    let name = CString::new(name).map_err(|e| e.to_string())?;
    let fd = unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            libc::O_RDONLY | libc::O_SYMLINK | libc::O_CLOEXEC | libc::O_NONBLOCK,
        )
    };
    if fd < 0 {
        return Err(std::io::Error::last_os_error().to_string());
    }
    io(unsafe { File::from_raw_fd(fd) }.metadata())
}
fn open_at(parent: &File, name: &str, directory: bool) -> Result<File> {
    let name = CString::new(name).map_err(|e| e.to_string())?;
    let flags = libc::O_RDONLY
        | libc::O_NOFOLLOW
        | libc::O_CLOEXEC
        | if directory { libc::O_DIRECTORY } else { 0 };
    let fd = unsafe { libc::openat(parent.as_raw_fd(), name.as_ptr(), flags) };
    if fd < 0 {
        Err(std::io::Error::last_os_error().to_string())
    } else {
        Ok(unsafe { File::from_raw_fd(fd) })
    }
}
pub fn path_bytes(path: &Path) -> Result<Vec<u8>> {
    check(
        path.is_absolute() && !path.components().any(|c| matches!(c, Component::ParentDir)),
        "absolute canonical path required",
    )?;
    let parts: Vec<_> = path
        .components()
        .filter_map(|c| {
            if let Component::Normal(n) = c {
                n.to_str()
            } else {
                None
            }
        })
        .collect();
    check(!parts.is_empty(), "regular bounded evidence required")?;
    let mut directories = vec![io(File::open("/"))?];
    let mut rails = Vec::new();
    for name in &parts[..parts.len() - 1] {
        let parent = directories.last().unwrap();
        let before = named(parent, name)?;
        check(before.is_dir(), "symlinked/non-directory evidence ancestor")?;
        let child = open_at(parent, name, true)?;
        let held = io(child.metadata())?;
        check(
            (before.dev(), before.ino()) == (held.dev(), held.ino()),
            "evidence ancestor replaced",
        )?;
        rails.push(((*name).to_owned(), held.dev(), held.ino()));
        directories.push(child);
    }
    let parent = directories.last().unwrap();
    let name = parts.last().unwrap();
    let before = named(parent, name)?;
    check(
        before.is_file() && before.len() <= MAX_BYTES,
        "regular bounded evidence required",
    )?;
    let mut file = open_at(parent, name, false)?;
    let held = io(file.metadata())?;
    let mut bytes = Vec::new();
    io((&mut file).take(MAX_BYTES + 1).read_to_end(&mut bytes))?;
    let after = io(file.metadata())?;
    check(
        stamp(&before) == stamp(&held)
            && stamp(&held) == stamp(&after)
            && stamp(&after) == stamp(&named(parent, name)?),
        "evidence changed while read",
    )?;
    for (index, (name, dev, ino)) in rails.iter().enumerate() {
        let named = named(&directories[index], name)?;
        let held = io(directories[index + 1].metadata())?;
        check(
            named.is_dir()
                && (named.dev(), named.ino()) == (*dev, *ino)
                && (held.dev(), held.ino()) == (*dev, *ino),
            "evidence ancestor changed",
        )?;
    }
    check(bytes.len() as u64 <= MAX_BYTES, "evidence byte limit")?;
    Ok(bytes)
}
pub fn reference(path: &Path) -> Result<Value> {
    Ok(json!({"path":path,"sha256":hash(&path_bytes(path)?)}))
}
pub fn read_bytes(reference: &Value) -> Result<Vec<u8>> {
    check(
        closed(reference, &["path", "sha256"]),
        "closed evidence reference required",
    )?;
    let digest = s(reference, "sha256")?;
    check(
        digest.len() == 64
            && digest
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)),
        "SHA256 required",
    )?;
    let bytes = path_bytes(Path::new(s(reference, "path")?))?;
    check(hash(&bytes) == digest, "evidence hash mismatch")?;
    Ok(bytes)
}
pub fn read(reference: &Value) -> Result<Value> {
    let bytes = read_bytes(reference)?;
    check(bytes.len() <= 256 * 1024, "JSON proof byte limit")?;
    decode(&bytes)
}
pub fn fresh_bytes(path: &Path, bytes: &[u8]) -> Result<Value> {
    check(
        path.is_absolute()
            && path
                .ancestors()
                .skip(1)
                .all(|p| !fs::symlink_metadata(p).is_ok_and(|m| m.file_type().is_symlink())),
        "real absolute output path required",
    )?;
    let mut file = io(OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path))?;
    io(file.write_all(bytes))?;
    io(file.flush())?;
    io(file.sync_all())?;
    io(fs::set_permissions(path, fs::Permissions::from_mode(0o444)))?;
    reference(path)
}
pub fn fresh(path: &Path, value: &Value) -> Result<Value> {
    let mut bytes = serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?;
    bytes.push(b'\n');
    fresh_bytes(path, &bytes)
}
pub fn run(command: &mut Command, input: Option<&[u8]>, seconds: u64) -> Result<String> {
    command
        .stdin(if input.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    let mut child = io(command.spawn())?;
    let stdout = child.stdout.take().ok_or("stdout missing")?;
    let stderr = child.stderr.take().ok_or("stderr missing")?;
    let capture = |mut pipe: Box<dyn Read + Send>| {
        std::thread::spawn(move || {
            let mut b = Vec::new();
            pipe.read_to_end(&mut b).map(|_| b)
        })
    };
    let out = capture(Box::new(stdout));
    let err = capture(Box::new(stderr));
    if let Some(bytes) = input {
        let mut stdin = child.stdin.take().ok_or("stdin missing")?;
        if let Err(error) = stdin.write_all(bytes) {
            drop(stdin);
            let _ = child.kill();
            let _ = child.wait();
            let _ = out.join();
            let _ = err.join();
            return Err(error.to_string());
        }
    }
    let deadline = Instant::now() + Duration::from_secs(seconds);
    let status = loop {
        if let Some(status) = io(child.try_wait())? {
            break status;
        }
        if seconds > 0 && Instant::now() >= deadline {
            let _ = child.kill();
            let _ = child.wait();
            let _ = out.join();
            let _ = err.join();
            return Err("command timeout".into());
        }
        std::thread::sleep(Duration::from_millis(10));
    };
    let stdout = io(out.join().map_err(|_| "stdout reader failed")?)?;
    let stderr = io(err.join().map_err(|_| "stderr reader failed")?)?;
    check(
        status.success(),
        &format!(
            "command refused: {command:?}: {}",
            String::from_utf8_lossy(&stderr).trim()
        ),
    )?;
    String::from_utf8(stdout)
        .map(|v| v.trim().to_owned())
        .map_err(|e| e.to_string())
}
pub fn protocol(root: &str, mode: &str, value: &Value) -> Result<Value> {
    let path = Path::new(root);
    check(
        path.is_absolute() && !io(fs::symlink_metadata(path))?.file_type().is_symlink(),
        "explicit real protocol checkout required",
    )?;
    let code = format!("{}{}", ext("protocol_import"), ext(mode));
    let mut command = Command::new(ext("runtime"));
    command.args(["-B", "-c", &code, root]);
    decode(
        run(
            &mut command,
            Some(&serde_json::to_vec(value).map_err(|e| e.to_string())?),
            0,
        )?
        .as_bytes(),
    )
}
