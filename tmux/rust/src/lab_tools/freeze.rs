use super::*;

struct Capture {
    root: PathBuf,
    timing: String,
}
impl Capture {
    fn record(&mut self, label: &str, start: u128, out: Output) -> Result<i32> {
        let end = epoch_ms();
        write(&self.root.join(format!("{label}.stdout.txt")), out.out)?;
        write(&self.root.join(format!("{label}.stderr.txt")), out.err)?;
        self.status(label, start, end, out.code)?;
        Ok(out.code)
    }
    fn status(&mut self, label: &str, start: u128, end: u128, code: i32) -> Result<()> {
        write(
            &self.root.join(format!("{label}.status.txt")),
            format!("{code}\n"),
        )?;
        self.timing.push_str(&format!(
            "{label}\t{start}\t{end}\t{}\t{code}\n",
            end as i128 - start as i128,
        ));
        write(&self.root.join("timing.tsv"), &self.timing)
    }
    fn unavailable(&mut self, label: &str, message: &str) -> Result<()> {
        write(
            &self.root.join(format!("{label}.stdout.txt")),
            format!("{message}\n"),
        )?;
        let marked = epoch_ms();
        self.status(label, marked, marked, 127)
    }
    fn request(&mut self, socket: &Path, label: &str, args: &[&str]) -> Result<String> {
        let start = epoch_ms();
        let out = bounded_status(
            Command::new(TMUX)
                .arg("-N")
                .arg("-S")
                .arg(socket)
                .args(args)
                .env_remove("TMUX")
                .env_remove("TMUX_PANE"),
            2,
            true,
        )?;
        let text = out.text();
        if matches!(self.record(label, start, out)?, 124 | 137 | 143) {
            return Err(format!(
                "tmux request timed out; capture stopped. Evidence: {}",
                self.root.display()
            ));
        }
        Ok(text)
    }
    fn os(&mut self, label: &str, seconds: u64, exe: &str, args: &[&str]) -> Result<String> {
        let start = epoch_ms();
        let out = bounded_status(
            Command::new(exe)
                .args(args)
                .env_remove("TMUX")
                .env_remove("TMUX_PANE"),
            seconds,
            true,
        )
        .unwrap_or_else(|e| Output {
            code: 127,
            out: Vec::new(),
            err: e.into_bytes(),
        });
        let text = out.text();
        self.record(label, start, out)?;
        Ok(text)
    }
}
fn executable(path: &Path) -> bool {
    fs::metadata(path).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
}
fn lsof_pid(text: &str) -> &str {
    text.lines()
        .find_map(|line| {
            let mut fields = line.split_whitespace();
            (fields.next() == Some("tmux"))
                .then(|| fields.next().filter(|pid| decimal(pid)))
                .flatten()
        })
        .unwrap_or("")
}
fn decimal(text: &str) -> bool {
    !text.is_empty() && text.bytes().all(|b| b.is_ascii_digit())
}
fn run() -> std::result::Result<(), (i32, String)> {
    let requested = PathBuf::from(setting("TMUX_FREEZE_CAPTURE_TMUX_BIN", TMUX));
    if !executable(&requested) || !executable(Path::new(TMUX)) {
        return Err((64, "tmux executable is unavailable.".into()));
    }
    if fs::canonicalize(&requested).ok() != fs::canonicalize(TMUX).ok() {
        return Err((
            64,
            "tmux executable must resolve to the pinned binary.".into(),
        ));
    }
    let socket = PathBuf::from(setting(
        "TMUX_FREEZE_CAPTURE_SOCKET",
        "/private/tmp/tmux-501/default",
    ));
    if !is_socket(&socket) {
        return Err((
            1,
            format!("expected tmux socket is absent: {}", socket.display()),
        ));
    }
    let utc = stamp();
    let root = PathBuf::from(setting(
        "TMUX_FREEZE_CAPTURE_OUTPUT_ROOT",
        &home().join("desk/incidents/tmux").to_string_lossy(),
    ))
    .join(format!(
        "tmux-freeze-capture-{}-{}",
        utc,
        std::process::id()
    ));
    private_dir(&root).map_err(|_| {
        (
            73,
            format!("cannot create evidence directory: {}", root.display()),
        )
    })?;
    let work = || -> Result<()> {
        write(&root.join("manifest.txt"),format!("utc={utc}\nsocket={}\ntmux={TMUX}\ntimeout=native\ntmux_timeout_seconds=2\nlsof_timeout_seconds=7\nreadonly=true\n",socket.display()))?;
        let mut c = Capture {
            root: root.clone(),
            timing: "label\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus\n".into(),
        };
        write(&root.join("timing.tsv"), &c.timing)?;
        let lsof = if executable(Path::new("/usr/sbin/lsof")) {
            c.os(
                "socket-lsof",
                7,
                "/usr/sbin/lsof",
                &["-n", "-a", "-U", &socket.to_string_lossy()],
            )?
        } else {
            c.unavailable("socket-lsof", "lsof unavailable")?;
            String::new()
        };
        let pid = lsof_pid(&lsof);
        write(&root.join("server-pid.txt"), format!("{pid}\n"))?;
        if !pid.is_empty() {
            c.os(
                "server-ps",
                2,
                "/bin/ps",
                &[
                    "-p",
                    pid,
                    "-o",
                    "pid=,ppid=,state=,etime=,pcpu=,pmem=,command=",
                ],
            )?;
            if executable(Path::new("/usr/bin/sample")) {
                c.os(
                    "server-sample",
                    7,
                    "/usr/bin/sample",
                    &[pid, "5", "1", "-mayDie"],
                )?;
            } else {
                c.unavailable("server-sample", "sample unavailable")?;
            }
        } else {
            for label in ["server-ps", "server-sample"] {
                c.unavailable(label, "server PID unavailable from lsof")?;
            }
        }
        for (label,args) in [
            ("sessions",vec!["list-sessions","-F","#{session_id}|#{session_name}|#{session_created}"]),
            ("panes",vec!["list-panes","-a","-F","#{pane_id}|#{session_name}|#{window_name}|#{pane_pid}|#{pane_in_mode}|#{pane_current_command}|#{history_size}|#{pane_width}x#{pane_height}"]),
            ("clients",vec!["list-clients","-F","#{client_tty}|#{client_session}|#{client_width}x#{client_height}|#{client_control_mode}"]),
            ("server-options",vec!["show-options","-s"]),
            ("server-message",vec!["display-message","-p","#{version}|#{socket_path}"]),
        ]{
            c.request(&socket, label, &args)?;
        }
        if pid.is_empty() {
            let text = c.request(&socket, "server-pid", &["display-message", "-p", "#{pid}"])?;
            let pid = text.lines().find(|line| decimal(line)).unwrap_or("");
            write(&root.join("server-pid.txt"), format!("{pid}\n"))?;
        }
        Ok(())
    };
    work().map_err(|e| (1, e))?;
    println!("Read-only capture complete: {}", root.display());
    println!("No keys, config reload, process control, or register writes were performed.");
    Ok(())
}
pub(crate) fn entry(_: &[String]) -> i32 {
    match run() {
        Ok(()) => 0,
        Err((c, e)) => {
            eprintln!("STOP: {e}");
            c
        }
    }
}

#[cfg(test)]
#[path = "../../tests/support/freeze.rs"]
mod tests;
