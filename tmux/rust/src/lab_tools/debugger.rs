use super::*;
use std::os::unix::net::UnixStream;
use std::process::{Child, ChildStdin};
use std::sync::atomic::{AtomicI32, Ordering};
static INTERRUPT: AtomicI32 = AtomicI32::new(0);
extern "C" fn interrupt(n: i32) {
    INTERRUPT.store(n, Ordering::Relaxed);
}
pub(super) fn install_interrupts() {
    INTERRUPT.store(0, Ordering::Relaxed);
    unsafe {
        for n in [libc::SIGINT, libc::SIGTERM] {
            libc::signal(n, interrupt as *const () as libc::sighandler_t);
        }
    }
}
pub(super) fn interruption() -> i32 {
    INTERRUPT.load(Ordering::Relaxed)
}

pub(super) struct Debugger {
    child: Child,
    input: Option<ChildStdin>,
    output: UnixStream,
    buffer: String,
    sequence: u64,
    deadline: Instant,
    identity: Option<crate::identity::ProcessIdentity>,
    attached: bool,
    log: PathBuf,
    transcript: String,
}

#[cfg(test)]
#[path = "debugger_check.rs"]
mod debugger_check;
impl Debugger {
    pub(super) fn new(log: PathBuf, seconds: u64) -> Result<Self> {
        let (output, writer) = UnixStream::pair().map_err(|e| e.to_string())?;
        output.set_nonblocking(true).map_err(|e| e.to_string())?;
        let err = writer.try_clone().map_err(|e| e.to_string())?;
        let mut child = Command::new("/usr/bin/lldb")
            .args(["--no-lldbinit", "--no-use-colors"])
            .env_remove("TMUX")
            .env_remove("TMUX_PANE")
            .stdin(Stdio::piped())
            .stdout(Stdio::from(OwnedFd::from(writer)))
            .stderr(Stdio::from(OwnedFd::from(err)))
            .process_group(0)
            .spawn()
            .map_err(|e| e.to_string())?;
        let identity = crate::identity::kernel_process(child.id());
        let input = child.stdin.take();
        let mut d = Self {
            child,
            input,
            output,
            buffer: String::new(),
            sequence: 0,
            deadline: Instant::now() + Duration::from_secs(seconds),
            identity,
            attached: false,
            log,
            transcript: String::new(),
        };
        d.command("settings set auto-confirm true")?;
        Ok(d)
    }
    pub(super) fn deadline(&self) -> Instant {
        self.deadline
    }
    pub(super) fn command(&mut self, command: &str) -> Result<String> {
        if command.contains(['\r', '\n']) {
            return Err("invalid debugger command".into());
        }
        self.sequence += 1;
        let marker = format!("__p4x_done_{}", self.sequence);
        let sentinel = format!("(lldb) {marker}\n");
        self.input
            .as_mut()
            .ok_or("debugger input closed")?
            .write_all(format!("command alias {marker} version\n{command}\n{marker}\n").as_bytes())
            .map_err(|e| e.to_string())?;
        loop {
            if interruption() != 0 && command != "process detach" {
                return Err("debugger transaction interrupted".into());
            }
            let mut bytes = [0; 16384];
            match self.output.read(&mut bytes) {
                Ok(0) => return Err("debugger output closed".into()),
                Ok(n) => self.buffer.push_str(&String::from_utf8_lossy(&bytes[..n])),
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => (),
                Err(e) => return Err(e.to_string()),
            }
            if let Some(at) = self.buffer.find(&sentinel) {
                let response = self.buffer[..at].to_owned();
                self.buffer.drain(..at + sentinel.len());
                self.transcript.push_str(&response);
                self.transcript.push_str(&sentinel);
                write(&self.log, &self.transcript)?;
                if response.lines().any(|l| l.starts_with("error:")) {
                    return Err(response);
                }
                return Ok(response);
            }
            if self.child.try_wait().map_err(|e| e.to_string())?.is_some() {
                return Err(format!("debugger exited: {}", self.buffer));
            }
            if Instant::now() >= self.deadline {
                return Err("debugger transaction timed out".into());
            }
            std::thread::sleep(Duration::from_millis(2));
        }
    }
    pub(super) fn attach(&mut self, pid: u32) -> Result<String> {
        self.attached = true;
        self.command(&format!("process attach -p {pid}"))
    }
    pub(super) fn detach(&mut self) -> Result<()> {
        self.deadline = Instant::now() + Duration::from_secs(5);
        let out = self.command("process detach")?;
        let detached = |s: &str| {
            s.lines()
                .any(|line| line.starts_with("Process ") && line.ends_with(" detached"))
        };
        if !detached(&out) {
            loop {
                if detached(&self.buffer) {
                    self.transcript.push_str(&self.buffer);
                    self.buffer.clear();
                    write(&self.log, &self.transcript)?;
                    break;
                }
                let mut bytes = [0; 4096];
                match self.output.read(&mut bytes) {
                    Ok(0) => return Err("debugger output closed before detach confirmation".into()),
                    Ok(n) => self.buffer.push_str(&String::from_utf8_lossy(&bytes[..n])),
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => (),
                    Err(e) => return Err(e.to_string()),
                }
                if Instant::now() >= self.deadline {
                    return Err("debugger detach unconfirmed".into());
                }
                std::thread::sleep(Duration::from_millis(2));
            }
        }
        self.attached = false;
        Ok(())
    }
    fn signal(&self, signal: i32) {
        if self.identity.is_some_and(|p| {
            crate::identity::kernel_process(self.child.id())
                .is_some_and(|now| now.same(p) && now.parent == std::process::id())
        }) {
            unsafe {
                libc::kill(self.child.id() as i32, signal);
            }
        }
    }
    #[cfg(test)]
    pub(super) fn crash_for_fixture(&mut self) -> Result<serde_json::Value> {
        let identity = self.identity.ok_or("missing owned debugger identity")?;
        if !crate::identity::kernel_process(self.child.id())
            .is_some_and(|now| now.same(identity) && now.parent == std::process::id())
        {
            return Err("owned debugger identity changed".into());
        }
        let mut record = serde_json::json!({"identity": identity, "image": lab::path(identity.pid),
            "argv": lab::process_args(identity.pid), "attached": self.attached,
            "fault_epoch_ms": epoch_ms()});
        self.signal(libc::SIGKILL);
        self.child.wait().map_err(|e| e.to_string())?;
        record["reaped_epoch_ms"] = serde_json::json!(epoch_ms());
        Ok(record)
    }
}
impl Drop for Debugger {
    fn drop(&mut self) {
        self.deadline = Instant::now() + Duration::from_secs(3);
        if self.attached {
            self.signal(libc::SIGINT);
            let _ = self.detach();
        }
        if let Some(mut input) = self.input.take() {
            let _ = input.write_all(b"quit\n");
        }
        let until = Instant::now() + Duration::from_secs(1);
        while Instant::now() < until {
            if self.child.try_wait().ok().flatten().is_some() {
                return;
            }
            std::thread::sleep(Duration::from_millis(5));
        }
        self.signal(libc::SIGTERM);
        let until = Instant::now() + Duration::from_secs(1);
        while Instant::now() < until {
            if self.child.try_wait().ok().flatten().is_some() {
                return;
            }
            std::thread::sleep(Duration::from_millis(5));
        }
        self.signal(libc::SIGKILL);
        let _ = self.child.wait();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    #[ignore]
    fn parked() {
        loop {
            std::thread::park_timeout(Duration::from_secs(60));
        }
    }
    #[test]
    #[ignore]
    fn owned_debugger() {
        let mut child = Command::new(std::env::current_exe().unwrap())
            .args(["--ignored", "--exact", "lab_tools::debugger::tests::parked"])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .spawn()
            .unwrap();
        let pid = child.id();
        let run = (|| -> Result<()> {
            let mut d =
                Debugger::new(home().join("desk/tmp/relay/port/l2/debugger-smoke.txt"), 12)?;
            d.attach(pid)?;
            let status = d.command("process status")?;
            assert!(status.contains(&format!("Process {pid} stopped")));
            d.detach()
        })();
        let _ = child.kill();
        let _ = child.wait();
        run.unwrap();
    }
}
