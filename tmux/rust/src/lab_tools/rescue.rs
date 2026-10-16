use super::*;
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::os::unix::fs::MetadataExt;

mod emergency;
mod rescue_check;
use emergency::detach as emergency_detach;

#[cfg(test)]
pub(super) fn record_spawn_for_fixture(pid: u32, command: &Command) {
    emergency::fixture::spawned(pid, command);
}

#[cfg(test)]
pub(super) fn record_lifecycle_for_fixture(pid: u32, event: &str) {
    emergency::fixture::lifecycle(pid, event);
}

const SHA: &str = "1d101560ca3d4fb6f86bb53e6d9946e7b98444343d1fdab4a2a6e72980e232a5";
const UUID: &str = "060659F0-3277-3658-8E15-BECF60DB7114";
#[derive(Debug)]
struct Config {
    production: bool,
    action: &'static str,
    socket: PathBuf,
    pid: u32,
    count: Option<u32>,
    root: PathBuf,
    exe: PathBuf,
    sha: String,
    uuid: String,
    function: String,
    frame: String,
    offset: String,
    bytes: String,
    seconds: u64,
    age: u64,
}
fn config(args: &[String]) -> Result<Config> {
    let (mut production, mut action) = (false, "rescue");
    for arg in args {
        match arg.as_str() {
            "--production" => production = true,
            "--verify" | "--verify-only" | "--observe" => {
                if action != "rescue" {
                    return Err("choose only one of --verify or --observe".into());
                }
                action = if arg == "--observe" {
                    "observe"
                } else {
                    "verify"
                };
            }
            _ => return Err("usage: tmux-loop-rescue [--production] [--verify|--observe]".into()),
        }
    }
    let required = |key: &str| {
        let s = env(key);
        if s.is_empty() {
            Err(format!("{key} is required"))
        } else {
            Ok(s)
        }
    };
    let mut socket = PathBuf::from(required("TMUX_LOOP_RESCUE_SOCKET")?);
    let pid = required("TMUX_LOOP_RESCUE_PID")?
        .parse::<u32>()
        .map_err(|_| "PID must be numeric")?;
    let count = env("TMUX_LOOP_RESCUE_COUNT");
    let count = if action == "observe" {
        if !count.is_empty() {
            return Err("--observe does not accept TMUX_LOOP_RESCUE_COUNT".into());
        }
        None
    } else {
        Some(
            count
                .parse::<u32>()
                .ok()
                .filter(|n| *n > 0)
                .ok_or("TMUX_LOOP_RESCUE_COUNT must be a positive u_int")?,
        )
    };
    let lab_root = if production {
        if !env("TMUX_LOOP_RESCUE_LAB_WRITE_EXCEPTION").is_empty() {
            return Err("lab write-exception override is forbidden in production mode".into());
        }
        if env("TMUX_LOOP_RESCUE_PRODUCTION_ACK") != "I-ACK-PRODUCTION-ATTACH" {
            return Err("production requires an explicit attachment acknowledgement".into());
        }
        for (keys, message) in [
            (
                &["EXE", "SHA256", "UUID"][..],
                "production identity overrides are forbidden",
            ),
            (
                &["FRAME", "FUNCTION", "PC_OFFSET", "INSTRUCTION_BYTES"][..],
                "production loop overrides are forbidden",
            ),
        ] {
            if keys
                .iter()
                .any(|k| !env(&format!("TMUX_LOOP_RESCUE_EXPECTED_{k}")).is_empty())
            {
                return Err(message.into());
            }
        }
        if !env("TMUX_LOOP_RESCUE_OBSERVATION_MAX_AGE_SECONDS").is_empty() {
            return Err("production observation-age overrides are forbidden".into());
        }
        required("TMUX_LOOP_RESCUE_EVIDENCE_ROOT")?;
        if socket != Path::new("/private/tmp/tmux-501/default") {
            return Err("production socket must be /private/tmp/tmux-501/default".into());
        }
        PathBuf::new()
    } else {
        if env("TMUX_LOOP_RESCUE_LAB") != "1" {
            return Err("set TMUX_LOOP_RESCUE_LAB=1 for an explicit lab rehearsal".into());
        }
        let root = fs::canonicalize(required("TMUX_LOOP_RESCUE_LAB_ROOT")?)
            .map_err(|_| "cannot resolve declared lab root")?;
        socket = fs::canonicalize(socket).map_err(|_| "cannot resolve lab socket")?;
        if socket == Path::new("/private/tmp/tmux-501/default") {
            return Err("production socket is forbidden in lab mode".into());
        }
        if !socket.starts_with(&root) || socket == root {
            return Err("socket is outside declared lab root".into());
        }
        root
    };
    if !["", "1"].contains(&env("TMUX_LOOP_RESCUE_LAB_WRITE_EXCEPTION").as_str()) {
        return Err("lab write-exception override must be 1".into());
    }
    if !is_socket(&socket) {
        return Err("tmux socket is absent".into());
    }
    let function = setting(
        "TMUX_LOOP_RESCUE_EXPECTED_FUNCTION",
        "window_copy_cmd_cursor_down",
    );
    if function.is_empty()
        || !function
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_')
    {
        return Err("expected function name is invalid".into());
    }
    let bytes = setting("TMUX_LOOP_RESCUE_EXPECTED_INSTRUCTION_BYTES", "94 06 00 71");
    let hex = bytes.replace(' ', "");
    if hex.len() != 8 || !hex.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("expected instruction bytes are invalid".into());
    }
    Ok(Config {
        production,
        action,
        socket,
        pid,
        count,
        root: PathBuf::from(setting(
            "TMUX_LOOP_RESCUE_EVIDENCE_ROOT",
            &lab_root.to_string_lossy(),
        )),
        exe: PathBuf::from(setting("TMUX_LOOP_RESCUE_EXPECTED_EXE", TMUX)),
        sha: setting("TMUX_LOOP_RESCUE_EXPECTED_SHA256", SHA),
        uuid: setting("TMUX_LOOP_RESCUE_EXPECTED_UUID", UUID),
        function,
        frame: setting("TMUX_LOOP_RESCUE_EXPECTED_FRAME", "window_copy_command"),
        offset: setting("TMUX_LOOP_RESCUE_EXPECTED_PC_OFFSET", "+ 36"),
        bytes,
        seconds: integer("TMUX_LOOP_RESCUE_TMUX_TIMEOUT_SECONDS", 2, 10, false)?,
        age: integer(
            "TMUX_LOOP_RESCUE_OBSERVATION_MAX_AGE_SECONDS",
            300,
            300,
            false,
        )?,
    })
}
struct Evidence {
    root: PathBuf,
    timing: String,
    gates: String,
}
impl Evidence {
    fn step(&mut self, label: &str, exe: &str, args: &[&str], seconds: u64) -> Result<Output> {
        let start = epoch_ms();
        let out = bounded(
            Command::new(exe)
                .args(args)
                .env_remove("TMUX")
                .env_remove("TMUX_PANE"),
            seconds,
        )?;
        let end = epoch_ms();
        write(&self.root.join(format!("{label}.stdout.txt")), &out.out)?;
        write(&self.root.join(format!("{label}.stderr.txt")), &out.err)?;
        self.timing.push_str(&format!(
            "{label}\t{start}\t{end}\t{}\t{}\n",
            end - start,
            out.code
        ));
        write(&self.root.join("timing.tsv"), &self.timing)?;
        Ok(out)
    }
    fn gate(&mut self, name: &str, result: bool) -> Result<()> {
        self.gates.push_str(&format!(
            "{name}\t{}\n",
            if result { "PASS" } else { "FAIL" }
        ));
        write(&self.root.join("gates.tsv"), &self.gates)
    }
    fn debugger(&mut self, label: &str, commands: &[String], seconds: u64) -> Result<Output> {
        let path = self.root.join(format!("{label}-command-file.txt"));
        write(&path, format!("{}\n", commands.join("\n")))?;
        self.step(
            label,
            "/usr/bin/lldb",
            &["--no-lldbinit", "-b", "-s", &path.to_string_lossy()],
            seconds,
        )
    }
}
fn digest(path: &Path) -> Result<String> {
    let mut f = File::open(path).map_err(|e| e.to_string())?;
    let mut sha = Sha256::new();
    let mut b = [0u8; 65536];
    loop {
        let n = f.read(&mut b).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        sha.update(&b[..n]);
    }
    Ok(format!("{:x}", sha.finalize()))
}
fn socket_identity(path: &Path) -> String {
    fs::metadata(path)
        .map(|m| format!("{}:{}", m.dev(), m.ino()))
        .unwrap_or_default()
}
fn owners(text: &str) -> Vec<u32> {
    let mut p = text
        .lines()
        .filter_map(|line| {
            let mut a = line.split_whitespace();
            if a.next() == Some("tmux") {
                a.next()?.parse().ok()
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    p.sort();
    p.dedup();
    p
}
fn record(path: &Path) -> Result<BTreeMap<String, String>> {
    if fs::symlink_metadata(path)
        .map_err(|e| e.to_string())?
        .file_type()
        .is_symlink()
    {
        return Err("observation is a symlink".into());
    }
    let mut r = BTreeMap::new();
    for line in fs::read_to_string(path).map_err(|e| e.to_string())?.lines() {
        let (k, v) = line.split_once('=').ok_or("invalid observation")?;
        if r.insert(k.into(), v.into()).is_some() {
            return Err("duplicate observation field".into());
        }
    }
    Ok(r)
}
fn valid_observation(r: &BTreeMap<String, String>, c: &Config, now: u64, nonce: &str) -> bool {
    let s = |k: &str| r.get(k).map(String::as_str).unwrap_or("");
    let number = |k: &str| {
        if !s(k).is_empty() && s(k).bytes().all(|b| b.is_ascii_digit()) {
            s(k).parse::<u64>().ok()
        } else {
            None
        }
    };
    !s("nonce").is_empty()
        && s("nonce")
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
        && s("nonce") == nonce
        && number("created_epoch").is_some_and(|v| v <= now)
        && number("max_age_seconds").is_some_and(|a| {
            a >= 1
                && a <= c.age
                && number("created_epoch").is_some_and(|v| now <= v.saturating_add(a))
        })
        && s("socket") == c.socket.to_string_lossy()
        && number("pid") == Some(c.pid as u64)
        && number("observed_count").is_some_and(|n| n >= 1 && n <= u32::MAX as u64)
}
fn hex_value(text: &str, prefix: &str) -> Option<u64> {
    text.lines().find_map(|l| {
        l.split_once(prefix)
            .and_then(|(_, s)| s.split_once("0x"))
            .and_then(|(_, s)| {
                let s = s
                    .chars()
                    .take_while(|c| c.is_ascii_hexdigit())
                    .collect::<String>();
                u64::from_str_radix(&s, 16).ok()
            })
    })
}
fn function_frames(text: &str, function: &str) -> Vec<usize> {
    text.lines()
        .filter(|l| {
            l.contains(&format!("`{function} ")) || l.trim_end().ends_with(&format!("`{function}"))
        })
        .filter_map(|l| {
            l.split_once("frame #")
                .and_then(|(_, s)| s.split_once(':'))
                .and_then(|(n, _)| n.parse().ok())
        })
        .collect()
}
fn preflight(c: &Config, root: &Path) -> Result<(u32, String)> {
    let mut d = debugger::Debugger::new(root.join("lldb-preflight.txt"), 12)?;
    let result = (|| -> Result<(u32, String)> {
        d.attach(c.pid)?;
        let stack = d.command("thread backtrace")?;
        let frames = function_frames(&stack, &c.function);
        if frames.len() != 1 {
            return Err("loop frame count is not one".into());
        }
        let frame = d.command(&format!("frame select {}", frames[0]))?;
        if !frame.contains(&format!("`{}", c.function)) {
            return Err("loop frame changed".into());
        }
        let disassembly = d.command(&format!("disassemble -n {}", c.function))?;
        let registers = d.command("register read x20")?;
        let count = hex_value(&registers, "x20 = ")
            .filter(|n| *n >= 1 && *n <= u32::MAX as u64)
            .ok_or("loop counter is not a positive u_int")?;
        Ok((count as u32, disassembly))
    })();
    let detached = d.detach();
    match (result, detached) {
        (Ok(v), Ok(())) => Ok(v),
        (Err(e), _) => Err(e),
        (_, Err(e)) => Err(e),
    }
}
fn frame_matches(text: &str, function: &str, pc: u64) -> bool {
    text.lines().any(|l| {
        l.contains("frame #0:")
            && hex_value(l, "frame #0:") == Some(pc)
            && l.split_once('`')
                .is_some_and(|(_, s)| s.split([' ', '\t', '(']).next() == Some(function))
    })
}
fn instruction(text: &str, pc: u64) -> Option<Vec<u8>> {
    text.lines().find_map(|line| {
        let (address, bytes) = line.trim().split_once(':')?;
        if u64::from_str_radix(address.strip_prefix("0x")?, 16).ok() != Some(pc) {
            return None;
        }
        bytes
            .split_whitespace()
            .map(|s| u8::from_str_radix(s.strip_prefix("0x")?, 16).ok())
            .collect::<Option<Vec<_>>>()
    })
}
struct Transaction {
    write: bool,
    detached: bool,
    result: Result<u32>,
}
fn confirmation() -> Result<String> {
    let mut value = Vec::new();
    loop {
        if debugger::interruption() != 0 {
            return Err("recovery confirmation interrupted".into());
        }
        let mut fd = libc::pollfd {
            fd: 0,
            events: libc::POLLIN,
            revents: 0,
        };
        let n = unsafe { libc::poll(&mut fd, 1, 100) };
        if n < 0 {
            if std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            return Err("cannot read PID confirmation".into());
        }
        if n == 0 {
            continue;
        }
        let mut byte = 0u8;
        let n = unsafe { libc::read(0, (&mut byte as *mut u8).cast(), 1) };
        if n == 0 {
            return Ok(String::new());
        }
        if n < 0 {
            continue;
        }
        if byte == b'\n' {
            return String::from_utf8(value).map_err(|e| e.to_string());
        }
        value.push(byte);
    }
}
struct Proof<'a> {
    exe: &'a Path,
    sha: &'a str,
    uuid: &'a str,
    socket_id: &'a str,
    start: &'a str,
    pc: u64,
    bound: u32,
    deadline: u64,
}
fn await_breakpoint(
    deadline: Instant,
    pid: u32,
    id: u64,
    mut command: impl FnMut(&str) -> Result<String>,
) -> Result<()> {
    loop {
        if Instant::now() >= deadline {
            return Err("debugger transaction timed out".into());
        }
        let status = command("process status")?;
        if Instant::now() >= deadline {
            return Err("debugger transaction timed out".into());
        }
        if status
            .lines()
            .any(|l| l == format!("Process {pid} stopped"))
        {
            let thread = command("thread info")?;
            if Instant::now() >= deadline {
                return Err("debugger transaction timed out".into());
            }
            return if rescue_check::stopped_at_breakpoint(&thread, id) {
                Ok(())
            } else {
                Err("breakpoint-mismatch-or-unexpected-stop-reason".into())
            };
        }
        if !status
            .lines()
            .any(|l| l == format!("Process {pid} is running."))
        {
            return Err("pid-mismatch-or-process-not-stopped".into());
        }
        std::thread::sleep(Duration::from_millis(2));
    }
}
fn final_transaction(c: &Config, e: &mut Evidence, p: Proof<'_>) -> Transaction {
    let Proof {
        exe,
        sha,
        uuid,
        socket_id,
        start,
        pc,
        bound,
        deadline,
    } = p;
    let mut attempted = false;
    let mut d = match debugger::Debugger::new(e.root.join("lldb-rescue.txt"), 20) {
        Ok(d) => d,
        Err(error) => {
            return Transaction {
                write: false,
                detached: true,
                result: Err(error),
            }
        }
    };
    let result = (|| -> Result<u32> {
        d.attach(c.pid)?;
        let breakpoint = d.command(&format!("breakpoint set --address 0x{pc:x}"))?;
        let id = breakpoint
            .lines()
            .find_map(|line| {
                line.strip_prefix("Breakpoint ")
                    .and_then(|s| s.split_once(':'))
                    .and_then(|(n, _)| n.parse::<u64>().ok())
            })
            .filter(|n| *n > 0)
            .ok_or("breakpoint creation was not confirmed")?;
        d.command("process continue")?;
        if !rescue_check::fresh(epoch_ms(), deadline) {
            return Err("observation-expired".into());
        }
        await_breakpoint(d.deadline(), c.pid, id, |command| d.command(command))?;
        let status = d.command("process status")?;
        if !status
            .lines()
            .any(|l| l == format!("Process {} stopped", c.pid))
        {
            return Err("pid-mismatch-or-process-not-stopped".into());
        }
        let thread = d.command("thread info")?;
        if !rescue_check::stopped_at_breakpoint(&thread, id) {
            return Err("breakpoint-mismatch-or-unexpected-stop-reason".into());
        }
        let frame = d.command("frame info")?;
        if !frame_matches(&frame, &c.function, pc) {
            return Err("frame-or-instruction-address-mismatch".into());
        }
        let images = d.command("image list -u -f")?;
        if !images.lines().any(|line| {
            line.trim_start().starts_with("[  0]")
                && line.contains(uuid)
                && line
                    .trim_end()
                    .ends_with(&exe.to_string_lossy().into_owned())
        }) {
            return Err("executable-path-or-uuid-mismatch".into());
        }
        if lab::path(c.pid)
            .and_then(|p| fs::canonicalize(p).ok())
            .as_deref()
            != Some(exe)
            || digest(exe).ok().as_deref() != Some(sha)
        {
            return Err("executable-sha256-mismatch".into());
        }
        if socket_identity(&c.socket) != socket_id || lab::process_start(c.pid) != start {
            return Err("socket-or-process-instance-mismatch".into());
        }
        let owner = e.step(
            "final-socket-lsof",
            "/usr/sbin/lsof",
            &["-n", "-a", "-U", &c.socket.to_string_lossy()],
            2,
        )?;
        if owner.code != 0 || owners(&owner.text()) != [c.pid] {
            return Err("socket-owner-mismatch".into());
        }
        let bytes = d.command(&format!(
            "memory read --format x --size 1 --count 4 0x{pc:x}"
        ))?;
        let expected = c
            .bytes
            .split_whitespace()
            .map(|s| u8::from_str_radix(s, 16).ok())
            .collect::<Option<Vec<_>>>()
            .ok_or("invalid instruction bytes")?;
        if instruction(&bytes, pc).as_deref() != Some(expected.as_slice()) {
            return Err("instruction-bytes-mismatch".into());
        }
        let registers = d.command("register read w20")?;
        let count = hex_value(&registers, "w20 = ")
            .filter(|n| *n >= 1 && *n <= bound as u64)
            .ok_or("counter-outside-fresh-bound")?;
        if !rescue_check::fresh(epoch_ms(), deadline) || debugger::interruption() != 0 {
            return Err("observation-expired-or-interrupted".into());
        }
        attempted = true;
        write(
            &e.root.join("lldb-final-checks.txt"),
            "TMUX_LOOP_WRITE=ATTEMPTED\n",
        )?;
        if env("TMUX_LOOP_RESCUE_LAB_WRITE_EXCEPTION") == "1" {
            return Err("register-write-exception:injected".into());
        }
        d.command("register write w20 1")?;
        if hex_value(&d.command("register read w20")?, "w20 = ") != Some(1) {
            return Err("register-write-failed".into());
        }
        #[cfg(test)]
        emergency::fixture::fail_primary(&mut d, &e.root)?;
        Ok(count as u32)
    })();
    let detached = d.detach().is_ok();
    write(
        &e.root.join("lldb-final-checks.txt"),
        format!(
            "TMUX_LOOP_WRITE={}\nTMUX_LOOP_FINAL={}\n",
            if attempted { "ATTEMPTED" } else { "SKIPPED" },
            match &result {
                Ok(_) => "PASS".into(),
                Err(error) => format!(
                    "{}:{error}",
                    if attempted { "UNCERTAIN" } else { "REFUSED" }
                ),
            }
        ),
    )
    .ok();
    Transaction {
        write: attempted,
        detached,
        result,
    }
}
fn run(c: Config) -> Result<i32> {
    let root = c
        .root
        .join(format!("rescue-{}-{}", stamp(), std::process::id()));
    private_dir(&root)?;
    write(&root.join("manifest.txt"), format!("mode={}\naction={}\nsocket={}\npid={}\ncount_claimed={}\nexpected_exe={}\nexpected_sha256={}\nexpected_uuid={}\n", if c.production {"production"} else {"lab"}, c.action, c.socket.display(), c.pid, c.count.map(|n|n.to_string()).unwrap_or_default(), c.exe.display(), c.sha, c.uuid))?;
    let mut e = Evidence {
        root: root.clone(),
        timing: "step\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus\n".into(),
        gates: "gate\tresult\n".into(),
    };
    let observation = record(Path::new(&env("TMUX_LOOP_RESCUE_OBSERVATION"))).ok();
    let socket_id = socket_identity(&c.socket);
    let start = lab::process_start(c.pid);
    let actual = lab::path(c.pid)
        .and_then(|p| fs::canonicalize(p).ok())
        .unwrap_or_default();
    let sha = digest(&actual).unwrap_or_default();
    let lsof = e.step(
        "socket-lsof",
        "/usr/sbin/lsof",
        &["-n", "-a", "-U", &c.socket.to_string_lossy()],
        2,
    )?;
    let uuid = if actual.is_file() {
        let out = e.step(
            "executable-uuid",
            "/usr/bin/dwarfdump",
            &["--uuid", &actual.to_string_lossy()],
            2,
        )?;
        out.text()
            .lines()
            .find_map(|l| {
                l.split_once("UUID:")
                    .and_then(|(_, s)| s.split_whitespace().next())
                    .map(str::to_owned)
            })
            .unwrap_or_default()
    } else {
        String::new()
    };
    let gate1 = lsof.code == 0
        && owners(&lsof.text()) == [c.pid]
        && !start.is_empty()
        && !socket_id.is_empty()
        && fs::canonicalize(&c.exe).ok().as_ref() == Some(&actual)
        && sha == c.sha
        && uuid == c.uuid;
    write(&root.join("gate1-identity.txt"), format!("owner_pids={:?}\nprocess_start={start}\nsocket_identity={socket_id}\nactual_exe={}\nactual_sha256={sha}\nactual_uuid={uuid}\n", owners(&lsof.text()), actual.display()))?;
    e.gate("gate1", gate1)?;
    let observation_pass = observation.as_ref().is_some_and(|r| {
        valid_observation(
            r,
            &c,
            (epoch_ms() / 1000) as u64,
            &env("TMUX_LOOP_RESCUE_OBSERVATION_NONCE"),
        ) && gate1
            && r.get("socket_identity") == Some(&socket_id)
            && r.get("process_start") == Some(&start)
            && r.get("executable") == Some(&actual.to_string_lossy().into_owned())
            && r.get("sha256") == Some(&sha)
            && r.get("uuid") == Some(&uuid)
    });
    let observation_gate = if env("TMUX_LOOP_RESCUE_OBSERVATION").is_empty() {
        "NOT_SUPPLIED"
    } else if observation_pass {
        "PASS"
    } else {
        "FAIL"
    };
    let sample = e.step(
        "gate2-sample",
        "/usr/bin/sample",
        &[&c.pid.to_string(), "1", "1", "-mayDie"],
        7,
    )?;
    let sample_text = format!("{}{}", sample.text(), String::from_utf8_lossy(&sample.err));
    write(&root.join("gate2-sample.txt"), &sample_text)?;
    let gate2 = sample.code == 0
        && sample_text.contains(&c.frame)
        && sample_text.contains(&c.function)
        && sample_text.contains("window_copy_cursor_down");
    e.gate("gate2", gate2)?;
    let (mut gate3, mut observed_count, mut detached) = (false, None, true);
    let mut runtime_pc = String::new();
    if gate1 && gate2 {
        runtime_pc =
            rescue_check::runtime_pc(&sample_text, &c.function, &c.offset).unwrap_or_default();
        let disassembly = e.step(
            "decrement-disassembly",
            "/Library/Developer/CommandLineTools/usr/bin/llvm-objdump",
            &["-d", "--macho", "--arch=arm64", &actual.to_string_lossy()],
            7,
        )?;
        match preflight(&c, &root) {
            Ok((count, text)) => {
                detached = true;
                observed_count = Some(count);
                let asm = disassembly.text();
                gate3 = disassembly.code == 0
                    && !runtime_pc.is_empty()
                    && asm.contains(&format!("_{}:", c.function))
                    && asm.lines().any(|line| {
                        line.contains(&c.bytes)
                            && line.contains("subs")
                            && line.contains("w20, w20, #0x1")
                    })
                    && text
                        .lines()
                        .any(|line| line.contains("subs") && line.contains("w20, w20, #0x1"));
            }
            Err(error) => {
                detached = false;
                write(&root.join("lldb-preflight.error.txt"), error)?;
            }
        }
    }
    write(
        &root.join("gate3-runtime.txt"),
        format!(
            "runtime_pc={runtime_pc}\nobserved_count={}\n",
            observed_count.map(|n| n.to_string()).unwrap_or_default()
        ),
    )?;
    e.gate("gate3", gate3)?;
    let pane = e.step(
        "pane-state",
        TMUX,
        &[
            "-N",
            "-S",
            &c.socket.to_string_lossy(),
            "list-panes",
            "-a",
            "-F",
            "#{pane_id}|#{pane_in_mode}|#{pane_current_command}",
        ],
        c.seconds,
    )?;
    let pane_match = if pane.code == 0 {
        pane.text().lines().any(|l| {
            let a: Vec<_> = l.split('|').collect();
            a.len() == 3
                && a[1] == "1"
                && (env("TMUX_LOOP_RESCUE_PANE").is_empty() || a[0] == env("TMUX_LOOP_RESCUE_PANE"))
        })
    } else {
        matches!(pane.code, 124 | 137 | 143) && gate2
    };
    let bound = if c.action == "observe" {
        observed_count
    } else if observation_pass {
        observation
            .as_ref()
            .and_then(|r| r.get("observed_count"))
            .and_then(|s| s.parse::<u32>().ok())
    } else {
        c.count
    };
    let gate4 = gate2 && pane_match && observed_count.zip(bound).is_some_and(|(n, b)| n <= b);
    e.gate("gate4", gate4)?;
    eprintln!(
        "GATE1={}\nGATE2={}\nGATE3={}\nGATE4={}\nOBSERVATION={observation_gate}",
        if gate1 { "PASS" } else { "FAIL" },
        if gate2 { "PASS" } else { "FAIL" },
        if gate3 { "PASS" } else { "FAIL" },
        if gate4 { "PASS" } else { "FAIL" }
    );
    let pass = gate1
        && gate2
        && gate3
        && gate4
        && detached
        && (c.action != "rescue" || observation_gate != "FAIL");
    if c.action == "observe" && pass {
        let nonce = format!("{}-{}", stamp(), std::process::id());
        let path = root.join("observation.tsv");
        write(&path,format!("version=1\nnonce={nonce}\ncreated_epoch={}\nmax_age_seconds={}\nsocket={}\nsocket_identity={socket_id}\npid={}\nprocess_start={start}\nexecutable={}\nsha256={sha}\nuuid={uuid}\nruntime_pc={runtime_pc}\nfunction={}\ninstruction_bytes={}\nobserved_count={}\n",epoch_ms()/1000,c.age,c.socket.display(),c.pid,actual.display(),c.function,c.bytes.replace(' ',""),observed_count.unwrap()))?;
        write(
            &root.join("result.txt"),
            format!(
                "observe=PASS\nwrite=SKIPPED\ndebugger=DETACHED\nobservation={}\n",
                path.display()
            ),
        )?;
        println!("OBSERVE: PASS; evidence={}; observation={}; nonce={nonce}; server_pid={}; socket_identity={socket_id}; executable={}; sha256={sha}; uuid={uuid}; observed_count={}",root.display(),path.display(),c.pid,actual.display(),observed_count.unwrap());
        return Ok(0);
    }
    if c.action == "verify" && pass {
        write(
            &root.join("result.txt"),
            "verify=PASS\nwrite=SKIPPED\ndebugger=DETACHED\n",
        )?;
        println!(
            "VERIFY: PASS; no debugger write was attempted. Evidence: {}",
            root.display()
        );
        return Ok(0);
    }
    if !pass {
        if !detached {
            let p = Proof {
                exe: &actual,
                sha: &sha,
                uuid: &uuid,
                socket_id: &socket_id,
                start: &start,
                pc: 0,
                bound: 0,
                deadline: 0,
            };
            detached = emergency_detach(&c, &mut e, &p);
        }
        write(
            &root.join("result.txt"),
            format!(
                "{}=REFUSED\nwrite=SKIPPED\ndebugger={}\nreason=one or more gates failed\n",
                c.action,
                if detached { "DETACHED" } else { "UNCONFIRMED" }
            ),
        )?;
        eprintln!(
            "{}: REFUSED; no debugger write was attempted. Evidence: {}",
            c.action.to_uppercase(),
            root.display()
        );
        return Ok(1);
    }
    eprint!(
        "Type the server PID {} to attempt the verified recovery: ",
        c.pid
    );
    let answer = confirmation()?;
    if !rescue_check::confirmed(&answer, c.pid) {
        e.gate("gate5", false)?;
        write(&root.join("result.txt"), "rescue=DECLINED\nwrite=SKIPPED\n")?;
        return Err(
            "server PID confirmation did not match; no debugger write was attempted".into(),
        );
    }
    e.gate("gate5", true)?;
    let final_bound = observed_count.unwrap().min(bound.unwrap());
    let deadline = observation
        .as_ref()
        .and_then(|r| {
            r.get("created_epoch")?
                .parse::<u64>()
                .ok()?
                .checked_add(r.get("max_age_seconds")?.parse::<u64>().ok()?)
        })
        .unwrap_or((epoch_ms() / 1000) as u64 + c.age);
    let pc = u64::from_str_radix(
        runtime_pc.strip_prefix("0x").ok_or("runtime PC missing")?,
        16,
    )
    .map_err(|_| "runtime PC invalid")?;
    let p = Proof {
        exe: &actual,
        sha: &sha,
        uuid: &uuid,
        socket_id: &socket_id,
        start: &start,
        pc,
        bound: final_bound,
        deadline,
    };
    let mut transaction = final_transaction(&c, &mut e, p);
    if !transaction.detached {
        let p = Proof {
            exe: &actual,
            sha: &sha,
            uuid: &uuid,
            socket_id: &socket_id,
            start: &start,
            pc,
            bound: final_bound,
            deadline,
        };
        transaction.detached = emergency_detach(&c, &mut e, &p);
    }
    let response = if transaction.write && transaction.detached {
        e.step(
            "post-rescue-response",
            TMUX,
            &[
                "-N",
                "-S",
                &c.socket.to_string_lossy(),
                "display-message",
                "-p",
                "#{pid}",
            ],
            c.seconds,
        )?
        .code
            == 0
    } else {
        false
    };
    let outcome = if transaction.result.is_ok() && transaction.detached {
        "WRITE_ATTEMPTED"
    } else if transaction.write {
        "WRITE_UNCERTAIN"
    } else {
        "REFUSED"
    };
    let reason = transaction
        .result
        .as_ref()
        .err()
        .map(String::as_str)
        .unwrap_or("");
    write(
        &root.join("result.txt"),
        format!(
            "rescue={outcome}\nwrite={}\ndebugger={}\nserver_responsiveness={}\nreason={reason}\n",
            if transaction.write {
                "ATTEMPTED"
            } else {
                "SKIPPED"
            },
            if transaction.detached {
                "DETACHED"
            } else {
                "UNCONFIRMED"
            },
            if response {
                "RECOVERED"
            } else {
                "NOT_CONFIRMED"
            }
        ),
    )?;
    println!(
        "RESCUE: {outcome}; debugger={}; server responsiveness={}; reason={reason}; Evidence: {}",
        if transaction.detached {
            "DETACHED"
        } else {
            "UNCONFIRMED"
        },
        if response {
            "RECOVERED"
        } else {
            "NOT_CONFIRMED"
        },
        root.display()
    );
    Ok(
        if transaction.result.is_ok() && transaction.detached && response {
            0
        } else {
            1
        },
    )
}
pub(crate) fn entry(args: &[String]) -> i32 {
    debugger::install_interrupts();
    let code = match config(args).and_then(run) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("REFUSED: {e}");
            1
        }
    };
    let signal = debugger::interruption();
    if signal != 0 {
        130
    } else {
        code
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn observation_freshness_and_identity() {
        let c = Config {
            production: false,
            action: "rescue",
            socket: PathBuf::from("/desk/lab/server"),
            pid: 10,
            count: Some(20),
            root: PathBuf::new(),
            exe: PathBuf::new(),
            sha: String::new(),
            uuid: String::new(),
            function: String::new(),
            frame: String::new(),
            offset: String::new(),
            bytes: String::new(),
            seconds: 2,
            age: 300,
        };
        let r = BTreeMap::from([
            ("nonce".into(), "nonce".into()),
            ("created_epoch".into(), "100".into()),
            ("max_age_seconds".into(), "10".into()),
            ("socket".into(), "/desk/lab/server".into()),
            ("pid".into(), "10".into()),
            ("observed_count".into(), "20".into()),
        ]);
        assert!(valid_observation(&r, &c, 100, "nonce"));
        assert!(valid_observation(&r, &c, 110, "nonce"));
        assert!(!valid_observation(&r, &c, 99, "nonce"));
        assert!(!valid_observation(&r, &c, 111, "nonce"));
        assert!(!valid_observation(&r, &c, 100, "wrong"));
        for (key, value) in [
            ("created_epoch", "+100"),
            ("max_age_seconds", "0"),
            ("max_age_seconds", "301"),
            ("pid", "11"),
            ("socket", "/other/socket"),
            ("observed_count", "0"),
            ("observed_count", "4294967296"),
        ] {
            let mut changed = r.clone();
            changed.insert(key.into(), value.into());
            assert!(
                !valid_observation(&changed, &c, 100, "nonce"),
                "{key}={value}"
            );
        }
    }
    struct OwnedServer {
        socket: PathBuf,
        process: crate::identity::ProcessIdentity,
        pane: String,
    }
    impl Drop for OwnedServer {
        fn drop(&mut self) {
            if crate::identity::kernel_process(self.process.pid) != Some(self.process) {
                return;
            }
            let _ = tmux(&self.socket, &["kill-pane", "-t", &self.pane], 1);
            for signal in [libc::SIGTERM, libc::SIGKILL] {
                if crate::identity::kernel_process(self.process.pid) == Some(self.process) {
                    unsafe {
                        libc::kill(self.process.pid as i32, signal);
                    }
                }
                let end = Instant::now() + Duration::from_secs(1);
                while Instant::now() < end
                    && crate::identity::kernel_process(self.process.pid).is_some()
                {
                    std::thread::sleep(Duration::from_millis(10));
                }
            }
        }
    }
    #[test]
    #[ignore]
    fn owned_rescue() {
        owned_rescue_case(false);
    }
    #[test]
    #[ignore]
    fn owned_rescue_injected() {
        owned_rescue_case(true);
    }
    fn owned_rescue_case(inject: bool) {
        assert!(!env("TMUX_PANE").is_empty());
        let root = home()
            .join("desk/tmp/relay/port/l2")
            .join(format!("rescue-native-{}", fresh().unwrap()));
        private_dir(&root).unwrap();
        let socket = root.join("server");
        let binary =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/angelstar-runtime");
        let started = (epoch_ms() / 1000) as u64;
        let created = bounded(
            Command::new(TMUX)
                .args(["-f", "/dev/null", "-S"])
                .arg(&socket)
                .args([
                    "new-session",
                    "-d",
                    "-s",
                    "lab-p4x-rescue",
                    "-n",
                    "hold",
                    "--",
                    &binary.to_string_lossy(),
                    "--surface",
                    "tmux-lab",
                    "hold",
                ])
                .env_remove("TMUX")
                .env_remove("TMUX_PANE"),
            5,
        )
        .unwrap();
        assert_eq!(created.code, 0, "{}", String::from_utf8_lossy(&created.err));
        let peer = std::os::unix::net::UnixStream::connect(&socket).unwrap();
        let mut pid = 0i32;
        let mut size = 4;
        assert_eq!(
            unsafe {
                libc::getsockopt(
                    peer.as_raw_fd(),
                    0,
                    2,
                    (&mut pid as *mut i32).cast(),
                    &mut size,
                )
            },
            0
        );
        let process = crate::identity::kernel_process(pid as u32).unwrap();
        assert!(process.start_seconds >= started);
        let pane = query(&socket, &["list-panes", "-F", "#{pane_id}"], 2).unwrap();
        let owner = OwnedServer {
            socket: socket.clone(),
            process,
            pane: pane.clone(),
        };
        assert_eq!(
            tmux(&socket, &["copy-mode", "-t", &pane], 2).unwrap().code,
            0
        );
        let mut trigger = Command::new(TMUX)
            .args(["-N", "-S"])
            .arg(&socket)
            .args([
                "send-keys",
                "-t",
                &pane,
                "-X",
                "-N",
                "4294967295",
                "cursor-down",
            ])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        std::thread::sleep(Duration::from_millis(100));
        if trigger.try_wait().unwrap().is_none() {
            trigger.kill().unwrap();
        }
        let _ = trigger.wait();
        let run = |action: &str, observation: Option<&Path>, nonce: &str, count: &str| {
            let mut command = Command::new(&binary);
            command.args(["--surface", "tmux-loop-rescue"]);
            if !action.is_empty() {
                command.arg(action);
            }
            if inject && action.is_empty() {
                command.env("TMUX_LOOP_RESCUE_LAB_WRITE_EXCEPTION", "1");
            }
            command
                .env("TMUX_LOOP_RESCUE_LAB", "1")
                .env("TMUX_LOOP_RESCUE_LAB_ROOT", &root)
                .env("TMUX_LOOP_RESCUE_SOCKET", &socket)
                .env("TMUX_LOOP_RESCUE_PID", pid.to_string())
                .env("TMUX_LOOP_RESCUE_EVIDENCE_ROOT", &root)
                .env_remove("TMUX_LOOP_RESCUE_COUNT")
                .env_remove("TMUX_LOOP_RESCUE_OBSERVATION")
                .env_remove("TMUX_LOOP_RESCUE_OBSERVATION_NONCE")
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped());
            if !count.is_empty() {
                command.env("TMUX_LOOP_RESCUE_COUNT", count);
            }
            if let Some(path) = observation {
                command
                    .env("TMUX_LOOP_RESCUE_OBSERVATION", path)
                    .env("TMUX_LOOP_RESCUE_OBSERVATION_NONCE", nonce);
            }
            let mut child = command.spawn().unwrap();
            if action.is_empty() {
                child
                    .stdin
                    .take()
                    .unwrap()
                    .write_all(format!("{pid}\n").as_bytes())
                    .unwrap();
            } else {
                child.stdin.take();
            }
            let out = child.wait_with_output().unwrap();
            let label = if action.is_empty() {
                "rescue"
            } else {
                "observe"
            };
            write(&root.join(format!("{label}.stdout")), &out.stdout).unwrap();
            write(&root.join(format!("{label}.stderr")), &out.stderr).unwrap();
            println!("{}", String::from_utf8_lossy(&out.stdout));
            eprintln!("{}", String::from_utf8_lossy(&out.stderr));
            assert!(
                out.status.code() == Some(if inject && action.is_empty() { 1 } else { 0 }),
                "{}: {}",
                root.display(),
                String::from_utf8_lossy(&out.stderr)
            );
            out
        };
        let observed = run("--observe", None, "", "");
        let text = String::from_utf8(observed.stdout).unwrap();
        let path = text
            .split("; observation=")
            .nth(1)
            .unwrap()
            .split(';')
            .next()
            .unwrap();
        let values = record(Path::new(path)).unwrap();
        let recovered = run(
            "",
            Some(Path::new(path)),
            &values["nonce"],
            &values["observed_count"],
        );
        if inject {
            assert!(String::from_utf8_lossy(&recovered.stdout).contains("WRITE_UNCERTAIN"));
            assert!(String::from_utf8_lossy(&recovered.stdout).contains("DETACHED"));
            drop(owner);
            return;
        }
        assert!(String::from_utf8_lossy(&recovered.stdout).contains("RECOVERED"));
        assert_eq!(
            query(&socket, &["display-message", "-p", "#{pid}"], 2).unwrap(),
            pid.to_string()
        );
        write(&home().join("desk/tmp/relay/port/l2/rescue-native-result.json"),serde_json::to_vec_pretty(&serde_json::json!({"status":"PASS","socket":socket,"pid":pid,"root":root,"observation":path,"recovered":true})).unwrap()).unwrap();
        drop(owner);
    }
    #[test]
    fn final_observation_parsers() {
        let frame = "frame #0: 0x0000000100010000 tmux`window_copy_cmd_cursor_down + 36";
        assert!(frame_matches(
            frame,
            "window_copy_cmd_cursor_down",
            0x100010000
        ));
        assert!(!frame_matches(
            frame,
            "window_copy_cmd_cursor_down",
            0x100010004
        ));
        assert!(!frame_matches(
            &frame.replace("#0", "#1"),
            "window_copy_cmd_cursor_down",
            0x100010000
        ));
        assert!(!frame_matches(
            frame,
            "window_copy_cmd_cursor_down_extra",
            0x100010000
        ));
        assert_eq!(
            instruction("0x100010000: 0x94 0x06 0x00 0x71", 0x100010000),
            Some(vec![0x94, 6, 0, 0x71])
        );
        assert_eq!(
            instruction("0x100010004: 0x94 0x06 0x00 0x71", 0x100010000),
            None
        );
    }
    #[test]
    fn parsing_observed_counter() {
        assert_eq!(hex_value(" x20 = 0x00000020\n", "x20 = "), Some(32));
        assert_eq!(hex_value(" x20 = unavailable", "x20 = "), None);
    }
    #[test]
    fn observation_rejects_duplicate_fields() {
        let path = home()
            .join("desk/tmp")
            .join(format!("p4x-observation-{}", fresh().unwrap()));
        write(&path, "nonce=n\nnonce=n\n").unwrap();
        assert!(record(&path).is_err());
        fs::remove_file(path).unwrap();
    }
}
