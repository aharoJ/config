use super::*;
use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::unix::fs::{symlink, MetadataExt};
use std::sync::atomic::{AtomicI32, Ordering};
static SIGNAL: AtomicI32 = AtomicI32::new(0);
extern "C" fn interrupted(n: i32) {
    SIGNAL.store(n, Ordering::Relaxed);
}
unsafe extern "C" {
    fn responsibility_get_pid_responsible_for_pid(pid: i32) -> i32;
    fn responsibility_spawnattrs_setdisclaim(
        attr: *mut libc::posix_spawnattr_t,
        disclaim: bool,
    ) -> i32;
    fn proc_listallpids(buffer: *mut libc::c_void, size: i32) -> i32;
    fn proc_pidinfo(pid: i32, flavor: i32, arg: u64, buffer: *mut libc::c_void, size: i32) -> i32;
    fn proc_pidpath(pid: i32, buffer: *mut libc::c_void, size: u32) -> i32;
}
pub(super) fn responsible(pid: u32) -> i32 {
    unsafe { responsibility_get_pid_responsible_for_pid(pid as i32) }
}
#[repr(C)]
struct Unique {
    uuid: [u8; 16],
    unique: u64,
    parent: u64,
    version: i32,
    parent_version: i32,
    reserved: [u64; 2],
}
fn unique(pid: u32) -> Option<u64> {
    let mut v: Unique = unsafe { std::mem::zeroed() };
    let size = std::mem::size_of_val(&v) as i32;
    if unsafe { proc_pidinfo(pid as i32, 17, 0, (&mut v as *mut Unique).cast(), size) } == size {
        Some(v.unique)
    } else {
        None
    }
}
fn uid(pid: u32) -> Option<u32> {
    let mut info = [0u32; 34];
    let n = unsafe { proc_pidinfo(pid as i32, 3, 0, info.as_mut_ptr().cast(), 136) };
    if n == 136 && info[3] == pid && info[1] != 5 {
        Some(info[5])
    } else {
        None
    }
}
pub(super) fn path(pid: u32) -> Option<String> {
    let mut b = [0u8; 4096];
    if unsafe { proc_pidpath(pid as i32, b.as_mut_ptr().cast(), b.len() as u32) } <= 0 {
        return None;
    }
    Some(
        unsafe { CStr::from_ptr(b.as_ptr().cast()) }
            .to_string_lossy()
            .into_owned(),
    )
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
fn records() -> Vec<PathBuf> {
    let root = home().join("desk/lab/tmux-lab-ledger");
    let mut paths = fs::read_dir(root)
        .into_iter()
        .flatten()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().starts_with("run-"))
        .map(|e| e.path().join("record.json"))
        .filter(|p| fs::symlink_metadata(p).is_ok())
        .collect::<Vec<_>>();
    paths.sort();
    paths
}
fn save(path: &Path, record: &Value) -> Result<()> {
    let pending = path.with_extension("json.pending");
    write(
        &pending,
        serde_json::to_vec(record).map_err(|e| e.to_string())?,
    )?;
    fs::rename(pending, path).map_err(|e| e.to_string())
}
fn responsibility_scope(run_args: &[String]) -> Result<()> {
    let pid = std::process::id();
    let inherited = responsible(pid);
    for path in records() {
        if let Ok(r) = fs::read(path)
            .map_err(|e| e.to_string())
            .and_then(|b| serde_json::from_slice::<Value>(&b).map_err(|e| e.to_string()))
        {
            if r["owner_pid"].as_i64() == Some(inherited as i64)
                && inherited != pid as i32
                && r["owner_start"].as_str() == Some(&process_start(inherited as u32))
            {
                return Err("nested lab owners are refused; use the current private server".into());
            }
        }
    }
    if env("TMUX_LAB_RESPONSIBLE_PID") == pid.to_string() && inherited == pid as i32 {
        return Ok(());
    }
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let mut args = vec![
        exe.to_string_lossy().into_owned(),
        "--surface".into(),
        "tmux-lab".into(),
        "run".into(),
    ];
    args.extend_from_slice(run_args);
    let args = args
        .into_iter()
        .map(CString::new)
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    let argv = args
        .iter()
        .map(|s| s.as_ptr() as *mut i8)
        .chain(std::iter::once(std::ptr::null_mut()))
        .collect::<Vec<_>>();
    let mut values = std::env::vars()
        .filter(|(k, _)| k != "TMUX_LAB_RESPONSIBLE_PID")
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>();
    values.push(format!("TMUX_LAB_RESPONSIBLE_PID={pid}"));
    let values = values
        .into_iter()
        .map(CString::new)
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    let envp = values
        .iter()
        .map(|s| s.as_ptr() as *mut i8)
        .chain(std::iter::once(std::ptr::null_mut()))
        .collect::<Vec<_>>();
    let mut attr = unsafe { std::mem::zeroed() };
    if unsafe { libc::posix_spawnattr_init(&mut attr) } != 0 {
        return Err("cannot initialize responsibility scope".into());
    }
    let mut result = unsafe { responsibility_spawnattrs_setdisclaim(&mut attr, true) };
    if result == 0 {
        result = unsafe { libc::posix_spawnattr_setflags(&mut attr, 0x0040) };
    }
    if result == 0 {
        let mut child = 0;
        result = unsafe {
            libc::posix_spawn(
                &mut child,
                args[0].as_ptr(),
                std::ptr::null(),
                &attr,
                argv.as_ptr(),
                envp.as_ptr(),
            )
        };
    }
    unsafe { libc::posix_spawnattr_destroy(&mut attr) };
    Err(format!(
        "responsibility re-exec failed: {}",
        std::io::Error::from_raw_os_error(result)
    ))
}
fn processes(owner: u32) -> Result<Vec<Value>> {
    let count = unsafe { proc_listallpids(std::ptr::null_mut(), 0) };
    if count <= 0 {
        return Err("process enumeration unavailable".into());
    }
    let mut pids = vec![0i32; count as usize + 128];
    let n = unsafe { proc_listallpids(pids.as_mut_ptr().cast(), (pids.len() * 4) as i32) };
    if n <= 0 || n as usize >= pids.len() {
        return Err("process enumeration unavailable".into());
    }
    let mut rows = Vec::new();
    for p in &pids[..n as usize] {
        let pid = *p as u32;
        if pid == std::process::id() || uid(pid) != Some(unsafe { libc::geteuid() }) {
            continue;
        }
        let attribution = responsible(pid);
        let Some(process) = crate::identity::kernel_process(pid) else {
            continue;
        };
        if attribution <= 0 {
            return Err(format!("process attribution unavailable: pid={pid}"));
        }
        if attribution != owner as i32 {
            continue;
        }
        rows.push(json!({"pid":pid,"uid":uid(pid).ok_or("process UID unavailable")?,"birth":[process.start_seconds,process.start_microseconds],"unique_id":unique(pid).ok_or("process identity unavailable")?,"start":process_start(pid),"command":process_args(pid).map(|a|a.join(" ")).unwrap_or_else(||path(pid).unwrap_or_default())}));
    }
    Ok(rows)
}
fn pane_descendants(name: &str) -> Result<Vec<Value>> {
    let panes = named(name, &["list-panes", "-a", "-F", "#{pane_pid}|#{pane_tty}"])?;
    if panes.code != 0 {
        return Err("cannot enumerate owned pane processes".into());
    }
    let mut selected = std::collections::HashSet::new();
    for line in panes.text().lines() {
        let (pid, _) = line
            .split_once('|')
            .ok_or("invalid pane process identity")?;
        selected.insert(
            pid.parse::<u32>()
                .map_err(|_| "invalid pane process identity")?,
        );
    }
    let table = bounded(
        Command::new("/bin/ps").args(["-axo", "pid=,ppid=,tty=,lstart="]),
        2,
    )?;
    if table.code != 0 {
        return Err("process table unavailable".into());
    }
    let mut rows = Vec::new();
    for line in table.text().lines() {
        let a: Vec<_> = line.split_whitespace().collect();
        if a.len() >= 8 {
            if let (Ok(pid), Ok(parent)) = (a[0].parse::<u32>(), a[1].parse::<u32>()) {
                rows.push((pid, parent, a[2].to_owned(), a[3..].join(" ")));
            }
        }
    }
    loop {
        let n = selected.len();
        for (pid, parent, _, _) in &rows {
            if selected.contains(parent) {
                selected.insert(*pid);
            }
        }
        if n == selected.len() {
            break;
        }
    }
    rows.sort_by_key(|r| r.0);
    Ok(rows
        .into_iter()
        .filter(|r| selected.contains(&r.0))
        .map(|(pid, ppid, tty, start)| json!({"pid":pid,"ppid":ppid,"tty":tty,"start":start}))
        .collect())
}
fn named(name: &str, args: &[&str]) -> Result<Output> {
    bounded(
        Command::new(TMUX)
            .args(["-L", name, "-f", "/dev/null"])
            .args(args)
            .env_remove("TMUX")
            .env_remove("TMUX_PANE")
            .env_remove("TMUX_TMPDIR")
            .env_remove("NO_COLOR"),
        5,
    )
}
fn server(name: &str) -> Result<(u32, PathBuf)> {
    let out = named(
        name,
        &[
            "display-message",
            "-p",
            "-t",
            &format!("=lab-owner-{}", name.rsplit('-').next().unwrap_or("")),
            "#{pid}|#{socket_path}",
        ],
    )?;
    if out.code != 0 {
        return Err("cannot identify private server".into());
    }
    let s = out.text();
    let (pid, path) = s
        .trim()
        .split_once('|')
        .ok_or("invalid private server identity")?;
    Ok((
        pid.parse().map_err(|_| "invalid private server PID")?,
        PathBuf::from(path),
    ))
}
fn verify(r: &Value) -> bool {
    let Some(name) = r["socket"].as_str() else {
        return false;
    };
    let Some(path) = r["socket_path"].as_str() else {
        return false;
    };
    if !fs::metadata(path)
        .is_ok_and(|m| m.file_type().is_socket() && Some(m.ino()) == r["socket_inode"].as_u64())
    {
        return false;
    }
    server(name).is_ok_and(|(pid, p)| {
        Some(pid as u64) == r["server_pid"].as_u64()
            && fs::canonicalize(p).ok() == fs::canonicalize(path).ok()
            && crate::identity::kernel_process(pid).is_some()
    })
}
fn proxy(args: &[String]) -> Result<i32> {
    let r: Value =
        serde_json::from_slice(&fs::read(env("TMUX_LAB_RECORD")).map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
    let name = env("TMUX_LAB_SOCKET");
    let suffix = name
        .strip_prefix("ccmsg-lab-private-")
        .ok_or("invalid private socket")?;
    if suffix.is_empty()
        || !suffix.bytes().all(|b| b.is_ascii_digit())
        || r["socket"] != name
        || r["token"] != env("TMUX_LAB_TOKEN")
        || r["owner_pid"].as_u64() != env("TMUX_LAB_OWNER_PID").parse::<u64>().ok()
        || r["owner_start"].as_str()
            != Some(&process_start(
                r["owner_pid"].as_u64().ok_or("owner missing")? as u32,
            ))
        || r["state"] != "running"
    {
        return Err("lab ownership refused".into());
    }
    validate_proxy(args, &name)?;
    if !verify(&r) {
        return Err("private server identity changed".into());
    }
    let start = if args.get(2).map(String::as_str) == Some("-f") {
        4
    } else {
        2
    };
    let out = named(
        &name,
        &args[start..].iter().map(String::as_str).collect::<Vec<_>>(),
    )?;
    std::io::stdout()
        .write_all(&out.out)
        .map_err(|e| e.to_string())?;
    std::io::stderr()
        .write_all(&out.err)
        .map_err(|e| e.to_string())?;
    Ok(out.code)
}
fn validate_proxy(args: &[String], name: &str) -> Result<()> {
    if args.len() < 3 || args[0] != "-L" || args[1] != name {
        return Err("explicit private label required".into());
    }
    let start = if args[2] == "-f" {
        if args.get(3).map(String::as_str) != Some("/dev/null") {
            return Err("private config required".into());
        }
        4
    } else {
        2
    };
    let rest = args
        .get(start..)
        .filter(|s| !s.is_empty())
        .ok_or("missing command")?;
    if rest[0].starts_with('-')
        || [
            "attach",
            "attach-session",
            "detach-client",
            "switch-client",
            "refresh-client",
            "lock-client",
            "kill-server",
            "start-server",
            "new-client",
        ]
        .contains(&rest[0].as_str())
        || rest[1..]
            .iter()
            .any(|s| ["-L", "-S", "-f"].contains(&s.as_str()))
    {
        return Err("private command refused".into());
    }
    if rest[0] == "new-session" {
        let i = rest
            .iter()
            .position(|s| s == "-s")
            .ok_or("detached lab session required")?;
        let name = rest.get(i + 1).ok_or("lab name missing")?;
        if !rest.iter().any(|s| s == "-d")
            || !name.starts_with("lab-")
            || name.len() == 4
            || !name[4..]
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
        {
            return Err("detached lab session required".into());
        }
    }
    if rest[0] == "new-window" && !rest.iter().any(|s| s == "-d") {
        return Err("detached window required".into());
    }
    Ok(())
}
fn run(args: &[String]) -> Result<i32> {
    if args.len() < 2 || args[0] != "--" {
        return Err("usage: tmux-lab run -- command [args...]".into());
    }
    responsibility_scope(args)?;
    let pid = std::process::id();
    let name = format!("ccmsg-lab-private-{pid}");
    let socket = PathBuf::from(format!("/private/tmp/tmux-{}/{name}", unsafe {
        libc::geteuid()
    }));
    if fs::symlink_metadata(&socket).is_ok() {
        return Err(format!(
            "private socket already exists: {}",
            socket.display()
        ));
    }
    let start = process_start(pid);
    if start.is_empty() {
        return Err("cannot attest owner start time".into());
    }
    let root = home().join("desk/lab/tmux-lab-ledger");
    private_dir(&root)?;
    let run_dir = root.join(format!("run-{pid}-{}", &fresh()?[..12]));
    private_dir(&run_dir)?;
    let record_path = run_dir.join("record.json");
    let wrapper = run_dir.join("tmux");
    symlink(
        std::env::current_exe().map_err(|e| e.to_string())?,
        &wrapper,
    )
    .map_err(|e| e.to_string())?;
    let token = fresh()?;
    let mut r = json!({"socket":name,"owner_pid":pid,"owner_start":start,"server_pid":null,"socket_path":socket,"socket_inode":null,"state":"preparing","command":&args[1..],"token":token,"created":epoch_ms()as f64/1000.0,"uid":unsafe{libc::geteuid()},"owner_unique_id":unique(pid).ok_or("cannot attest owner kernel identity")?});
    save(&record_path, &r)?;
    SIGNAL.store(0, Ordering::Relaxed);
    unsafe {
        for n in [libc::SIGINT, libc::SIGTERM, libc::SIGHUP] {
            libc::signal(n, interrupted as *const () as libc::sighandler_t);
        }
    }
    let operation = (|| -> Result<i32> {
        let exe = std::env::current_exe().map_err(|e| e.to_string())?;
        let created = named(
            &name,
            &[
                "new-session",
                "-d",
                "-s",
                &format!("lab-owner-{pid}"),
                "-n",
                "hold",
                "--",
                &exe.to_string_lossy(),
                "--surface",
                "tmux-lab",
                "hold",
            ],
        )?;
        if created.code != 0 {
            return Err(format!(
                "private server creation failed: {}",
                String::from_utf8_lossy(&created.err)
            ));
        }
        let (server_pid, actual) = server(&name)?;
        if fs::canonicalize(&actual).ok() != fs::canonicalize(&socket).ok() {
            return Err("private socket path differs from expected path".into());
        }
        r["server_pid"] = json!(server_pid);
        r["socket_path"] = json!(actual);
        r["socket_inode"] = json!(fs::metadata(&actual).map_err(|e| e.to_string())?.ino());
        if responsible(server_pid) != pid as i32 {
            return Err("private server did not inherit responsibility scope".into());
        }
        r["state"] = json!("running");
        save(&record_path, &r)?;
        let signal = SIGNAL.load(Ordering::Relaxed);
        if signal != 0 {
            return Ok(128 + signal);
        }
        let mut command = Command::new(&args[1]);
        command
            .args(&args[2..])
            .env_remove("TMUX_PANE")
            .env_remove("TMUX_TMPDIR")
            .env("TMUX_LAB_SOCKET", &name)
            .env("TMUX_LAB_OWNER_PID", pid.to_string())
            .env("TMUX_LAB_OWNER_START", &start)
            .env("TMUX_LAB_RECORD", &record_path)
            .env("TMUX_LAB_TOKEN", &token)
            .env("TMUX_LAB_TMUX", &wrapper)
            .env("TMUX_BIN", &wrapper)
            .env("TMUX", format!("{},{server_pid},0", actual.display()))
            .env("PATH", format!("{}:{}", run_dir.display(), env("PATH")));
        unsafe {
            command.pre_exec(|| {
                if libc::setsid() < 0 {
                    Err(std::io::Error::last_os_error())
                } else {
                    Ok(())
                }
            });
        }
        let mut child = command.spawn().map_err(|e| e.to_string())?;
        loop {
            if let Some(status) = child.try_wait().map_err(|e| e.to_string())? {
                use std::os::unix::process::ExitStatusExt;
                return Ok(status
                    .code()
                    .unwrap_or_else(|| 128 + status.signal().unwrap_or(1)));
            }
            let signal = SIGNAL.load(Ordering::Relaxed);
            if signal != 0 {
                let identity = crate::identity::kernel_process(child.id());
                if identity.is_some_and(|p| p.parent == pid) {
                    unsafe {
                        libc::kill(-(child.id() as i32), libc::SIGTERM);
                    }
                }
                let deadline = Instant::now() + Duration::from_secs(3);
                while Instant::now() < deadline
                    && child.try_wait().map_err(|e| e.to_string())?.is_none()
                {
                    std::thread::sleep(Duration::from_millis(20));
                }
                if identity.is_some_and(|p| {
                    crate::identity::kernel_process(child.id())
                        .is_some_and(|live| live.same(p) && live.parent == pid)
                }) {
                    unsafe {
                        libc::kill(-(child.id() as i32), libc::SIGKILL);
                    }
                }
                let _ = child.wait();
                return Ok(128 + signal);
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    })();
    let mut errors = Vec::new();
    let (code, ledger_code) = match operation {
        Ok(c) => (c, c),
        Err(e) => {
            eprintln!("tmux-lab: {e}");
            (97, 1)
        }
    };
    if r["server_pid"].is_null() && is_socket(&socket) {
        if let Ok((server_pid, actual)) = server(&name) {
            if responsible(server_pid) == pid as i32
                && fs::canonicalize(&actual).ok() == fs::canonicalize(&socket).ok()
                && path(server_pid)
                    .is_some_and(|p| fs::canonicalize(p).ok() == fs::canonicalize(TMUX).ok())
            {
                if let Ok(info) = fs::metadata(&actual) {
                    r["server_pid"] = json!(server_pid);
                    r["socket_path"] = json!(actual);
                    r["socket_inode"] = json!(info.ino());
                }
            }
        }
    }
    let verified = verify(&r);
    if verified {
        match named(&name, &["list-clients", "-F", "#{client_pid}"]) {
            Ok(out) if out.code == 0 => {
                if !out.text().trim().is_empty() {
                    eprintln!("tmux-lab: warning: an external client attached to the owned server");
                }
            }
            _ => errors.push("client census unavailable".into()),
        }
        r["pane_descendants_before"] = json!(match pane_descendants(&name) {
            Ok(rows) => rows,
            Err(error) => {
                errors.push(format!("pane census: {error}"));
                Vec::new()
            }
        });
        r["kill_exit"] = json!(0);
        match named(&name, &["list-panes", "-a", "-F", "#{pane_id}"]) {
            Ok(out) if out.code == 0 => {
                for pane in out.text().lines().rev() {
                    if pane
                        .strip_prefix('%')
                        .is_some_and(|s| !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()))
                    {
                        let same = fs::metadata(&socket)
                            .is_ok_and(|m| Some(m.ino()) == r["socket_inode"].as_u64())
                            && r["server_pid"]
                                .as_u64()
                                .and_then(|p| crate::identity::kernel_process(p as u32))
                                .is_some();
                        if !same
                            || !named(&name, &["kill-pane", "-t", pane]).is_ok_and(|o| o.code == 0)
                        {
                            r["kill_exit"] = Value::Null;
                            errors.push("private pane cleanup unconfirmed".into());
                        }
                    }
                }
            }
            _ => errors.push("private pane census unconfirmed".into()),
        }
        let end = Instant::now() + Duration::from_secs(3);
        while Instant::now() < end
            && r["server_pid"]
                .as_u64()
                .and_then(|p| crate::identity::kernel_process(p as u32))
                .is_some()
        {
            std::thread::sleep(Duration::from_millis(20));
        }
        r["state"] = json!(if r["server_pid"]
            .as_u64()
            .and_then(|p| crate::identity::kernel_process(p as u32))
            .is_none()
            && errors.is_empty()
        {
            "closed"
        } else {
            "cleanup-failed"
        });
    } else {
        r["state"] = json!(if r["server_pid"].is_null() && !socket.exists() {
            "creation-failed"
        } else {
            "identity-mismatch"
        });
    }
    let mut escalated = Vec::new();
    if verified {
        r["escape_candidates"] = json!(processes(pid).unwrap_or_default());
        for signal in [0, libc::SIGTERM, libc::SIGKILL] {
            if signal != 0 {
                if let Ok(rows) = processes(pid) {
                    for row in rows {
                        if signal_scoped(&r, &row, signal) {
                            escalated.push(row["pid"].as_u64().unwrap_or(0));
                        }
                    }
                }
            }
            let deadline = Instant::now() + Duration::from_secs(1);
            while Instant::now() < deadline {
                if processes(pid).is_ok_and(|a| a.is_empty()) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(100));
            }
            if processes(pid).is_ok_and(|a| a.is_empty()) {
                break;
            }
        }
        escalated.sort();
        escalated.dedup();
        r["escalated_pane_pids"] = json!(escalated);
        r["remaining_pane_pids"] = json!(processes(pid)
            .unwrap_or_default()
            .iter()
            .filter_map(|r| r["pid"].as_u64())
            .collect::<Vec<_>>());
    }
    match processes(pid) {
        Ok(escaped) => {
            if !escaped.is_empty() && r["state"] == "closed" {
                r["state"] = json!("closed-with-escapes");
            }
            for row in &escaped {
                eprintln!(
                    "tmux-lab: ESCAPED PROCESS pid={} command={}; inspect {}",
                    row["pid"],
                    row["command"],
                    record_path.display()
                );
            }
            r["escaped_processes"] = json!(escaped);
        }
        Err(e) => {
            errors.push(e);
            r["state"] = json!("cleanup-failed");
        }
    }
    r["exit_code"] = json!(ledger_code);
    r["cleanup_errors"] = json!(errors);
    r["finished"] = json!(epoch_ms() as f64 / 1000.0);
    save(&record_path, &r)?;
    if r["state"] != "closed" && r["state"] != "creation-failed" {
        eprintln!(
            "tmux-lab: cleanup unverified; inspect {}",
            record_path.display()
        );
    }
    Ok(code)
}
fn signal_scoped(record: &Value, row: &Value, signal: i32) -> bool {
    let Some(pid) = row["pid"].as_u64().and_then(|n| u32::try_from(n).ok()) else {
        return false;
    };
    let Some(owner) = record["owner_pid"]
        .as_u64()
        .and_then(|n| u32::try_from(n).ok())
    else {
        return false;
    };
    let Some(current) = crate::identity::kernel_process(pid) else {
        return false;
    };
    if unique(owner) != record["owner_unique_id"].as_u64()
        || unique(pid) != row["unique_id"].as_u64()
        || responsible(pid) != owner as i32
        || uid(pid).map(u64::from) != record["uid"].as_u64()
        || row["birth"] != json!([current.start_seconds, current.start_microseconds])
        || current.start_seconds < (record["created"].as_f64().unwrap_or(f64::MAX) as u64)
    {
        return false;
    }
    unsafe { libc::kill(pid as i32, signal) == 0 }
}
fn list() -> Result<i32> {
    let probe = bounded(Command::new("/usr/sbin/lsof").args(["-nU", "-Fpn"]), 5)?;
    let mut owners = std::collections::BTreeMap::<String, Vec<u32>>::new();
    let mut pid = 0;
    for line in probe.text().lines() {
        if let Some(p) = line.strip_prefix('p') {
            pid = p.parse().unwrap_or(0);
        } else if let Some(p) = line.strip_prefix("n/") {
            let p = format!("/{p}");
            if pid > 0
                && Path::new(&p).file_name().is_some_and(|n| {
                    let n = n.to_string_lossy();
                    n.starts_with("ccmsg-lab-private-") && n.len() > 18
                })
            {
                let p = fs::canonicalize(&p)
                    .unwrap_or(PathBuf::from(p))
                    .to_string_lossy()
                    .into_owned();
                let pids = owners.entry(p).or_default();
                if !pids.contains(&pid) {
                    pids.push(pid);
                    pids.sort();
                }
            }
        }
    }
    let mut registered = HashSet::new();
    for record in records() {
        match fs::read(&record)
            .ok()
            .and_then(|b| serde_json::from_slice::<Value>(&b).ok())
        {
            Some(mut r)
                if r.is_object()
                    && r["owner_pid"].is_u64()
                    && r["owner_start"].is_string()
                    && r["socket_path"].is_string()
                    && r["socket"].is_string()
                    && r["state"].is_string()
                    && r.get("server_pid").is_some()
                    && r.get("socket_inode").is_some() =>
            {
                let path = r["socket_path"].as_str().unwrap_or("").to_owned();
                let owner_live = r["owner_pid"]
                    .as_u64()
                    .is_some_and(|p| r["owner_start"].as_str() == Some(&process_start(p as u32)));
                let live = owners.get(&path);
                let server_live = live.is_some_and(|ps| {
                    if r["server_pid"].is_null() {
                        return !ps.is_empty();
                    }
                    r["server_pid"]
                        .as_u64()
                        .is_some_and(|p| ps.contains(&(p as u32)))
                        && fs::metadata(&path)
                            .is_ok_and(|m| r["socket_inode"].as_u64() == Some(m.ino()))
                });
                if server_live {
                    registered.insert(path.clone());
                }
                r.as_object_mut().unwrap().remove("token");
                let escapes = r["escaped_processes"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .filter(|row| {
                        row["pid"].as_u64().is_some_and(|p| {
                            row["unique_id"]
                                .as_u64()
                                .is_some_and(|id| unique(p as u32) == Some(id))
                        })
                    })
                    .cloned()
                    .collect::<Vec<_>>();
                println!(
                    "{}",
                    json!({"record":record,"state":r["state"],"owner_live":owner_live,"escaped_processes":escapes,"escape_inspection_unknown":!owner_live&&["running","preparing","identity-mismatch","cleanup-failed"].contains(&r["state"].as_str().unwrap_or("")),"escape_observation":if !escapes.is_empty(){"live"}else if r.get("escaped_processes").is_some_and(|v|v.as_array().is_some_and(|a|!a.is_empty())){"gone"}else{"none"},"server_live":server_live,"socket_observation":if ![0,1].contains(&probe.code){"unknown"}else if live.is_some_and(|p|!p.is_empty()){"live"}else if fs::symlink_metadata(&path).is_ok(){"stale"}else{"absent"},"stale":server_live&&!owner_live,"inspection_unknown":![0,1].contains(&probe.code),"socket":r["socket"],"server_pid":r["server_pid"]})
                );
            }
            _ => println!("{}", json!({"record":record,"state":"unreadable"})),
        }
    }
    let directory = PathBuf::from(format!("/private/tmp/tmux-{}", unsafe { libc::geteuid() }));
    for e in fs::read_dir(directory)
        .into_iter()
        .flatten()
        .filter_map(|e| e.ok())
    {
        if e.file_name()
            .to_string_lossy()
            .starts_with("ccmsg-lab-private-")
        {
            owners
                .entry(e.path().to_string_lossy().into_owned())
                .or_default();
        }
    }
    for (path, pids) in owners {
        if !registered.contains(&path) {
            println!(
                "{}",
                json!({"state":"unregistered","socket":Path::new(&path).file_name().unwrap_or_default().to_string_lossy(),"socket_path":path,"listener_pids":pids,"socket_observation":if ![0,1].contains(&probe.code){"unknown"}else if !pids.is_empty(){"live"}else if Path::new(&path).exists(){"stale"}else{"absent"},"inspection_unknown":![0,1].contains(&probe.code)})
            );
        }
    }
    Ok(0)
}
use std::collections::HashSet;
pub(crate) fn entry(args: &[String]) -> i32 {
    let result = match args.first().map(String::as_str) {
        Some("run") => run(&args[1..]),
        Some("tmux") => proxy(&args[1..]),
        Some("ls") if args.len() == 1 => list(),
        Some("hold") if args.len() == 1 => loop {
            std::thread::park_timeout(Duration::from_secs(3600));
        },
        _ => Err("usage: tmux-lab run -- command | tmux ... | ls".into()),
    };
    match result {
        Ok(c) => c,
        Err(e) => {
            eprintln!("tmux-lab: {e}");
            97
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn native_identity_layout() {
        let pid = std::process::id();
        assert_eq!(std::mem::size_of::<Unique>(), 56);
        assert!(unique(pid).is_some());
        assert_eq!(uid(pid), Some(unsafe { libc::geteuid() }));
        assert!(!process_args(pid).unwrap().is_empty());
    }
    #[test]
    fn proxy_rules() {
        let name = "ccmsg-lab-private-1";
        let args = |tail: &[&str]| {
            [vec!["-L", name], tail.to_vec()]
                .concat()
                .into_iter()
                .map(str::to_owned)
                .collect::<Vec<_>>()
        };
        for tail in [
            &["kill-server"][..],
            &["attach-session"],
            &["new-session", "-s", "lab-test"],
            &["new-session", "-d", "-s", "production"],
            &["new-window"],
            &["display-message", "-S", "other"],
        ] {
            assert!(validate_proxy(&args(tail), name).is_err(), "{tail:?}");
        }
        for tail in [
            &["list-panes", "-a"][..],
            &["new-session", "-d", "-s", "lab-test"],
            &["new-window", "-d"],
        ] {
            assert!(validate_proxy(&args(tail), name).is_ok(), "{tail:?}");
        }
    }
}
