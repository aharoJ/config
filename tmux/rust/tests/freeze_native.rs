use serde_json::json;
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::os::unix::fs::{symlink, DirBuilderExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::time::{Duration, Instant};

const TMUX: &str = "/opt/homebrew/Cellar/tmux/3.7c/bin/tmux";

fn run(command: &mut Command, seconds: u64) -> Output {
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let deadline = Instant::now() + Duration::from_secs(seconds);
    while child.try_wait().unwrap().is_none() {
        if Instant::now() >= deadline {
            child.kill().unwrap();
            let output = child.wait_with_output().unwrap();
            panic!("command exceeded {seconds}s: {output:?}");
        }
        std::thread::sleep(Duration::from_millis(5));
    }
    child.wait_with_output().unwrap()
}

fn tmux(socket: Option<&Path>, args: &[&str]) -> Output {
    let mut command = Command::new(TMUX);
    command.arg("-N");
    if let Some(socket) = socket {
        command
            .arg("-S")
            .arg(socket)
            .env_remove("TMUX")
            .env_remove("TMUX_PANE");
    }
    run(command.args(args), 3)
}

struct Server {
    child: Child,
    socket: PathBuf,
    pane: String,
}

impl Server {
    fn signal(&mut self, signal: i32) {
        assert!(self.child.try_wait().unwrap().is_none());
        assert_eq!(unsafe { libc::kill(self.child.id() as i32, signal) }, 0);
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        if !matches!(self.child.try_wait(), Ok(None)) {
            return;
        }
        unsafe {
            libc::kill(self.child.id() as i32, libc::SIGCONT);
        }
        if !self.pane.is_empty() {
            let _ = tmux(Some(&self.socket), &["kill-pane", "-t", &self.pane]);
        }
        let deadline = Instant::now() + Duration::from_secs(1);
        while matches!(self.child.try_wait(), Ok(None)) && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        if matches!(self.child.try_wait(), Ok(None)) {
            let _ = self.child.kill();
        }
        let _ = self.child.wait();
    }
}

fn capture(root: &Path, socket: &Path, label: &str, expected: i32) -> (PathBuf, u128) {
    let path = format!(
        "{}:{}",
        root.join("bin").display(),
        std::env::var("PATH").unwrap()
    );
    let mut command = Command::new("tmux-freeze-capture.fish");
    command
        .env("PATH", path)
        .env("TMUX_FREEZE_CAPTURE_SOCKET", socket)
        .env("TMUX_FREEZE_CAPTURE_OUTPUT_ROOT", root.join(label))
        .env("TMUX_FREEZE_CAPTURE_TMUX_BIN", TMUX);
    for key in [
        "TIMEOUT_BIN",
        "LSOF_BIN",
        "SAMPLE_BIN",
        "TMUX_TIMEOUT_SECONDS",
        "LSOF_TIMEOUT_SECONDS",
        "SAMPLE_TIMEOUT_SECONDS",
    ] {
        command.env_remove(format!("TMUX_FREEZE_CAPTURE_{key}"));
    }
    let started = Instant::now();
    let out = run(&mut command, 20);
    let elapsed = started.elapsed().as_millis();
    fs::write(root.join(format!("{label}.stdout")), &out.stdout).unwrap();
    fs::write(root.join(format!("{label}.stderr")), &out.stderr).unwrap();
    assert_eq!(out.status.code(), Some(expected), "{label}: {out:?}");
    let evidence = fs::read_dir(root.join(label))
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    assert_eq!(fs::read_dir(root.join(label)).unwrap().count(), 1);
    assert_eq!(
        fs::metadata(&evidence).unwrap().permissions().mode() & 0o777,
        0o700
    );
    for file in fs::read_dir(&evidence).unwrap() {
        assert_eq!(
            file.unwrap().metadata().unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
    let manifest = fs::read_to_string(evidence.join("manifest.txt")).unwrap();
    let keys: Vec<_> = manifest
        .lines()
        .map(|line| line.split_once('=').unwrap().0)
        .collect();
    assert_eq!(
        keys,
        [
            "utc",
            "socket",
            "tmux",
            "timeout",
            "tmux_timeout_seconds",
            "lsof_timeout_seconds",
            "readonly"
        ]
    );
    assert!(manifest.contains("timeout=native\n"));
    assert!(manifest.contains("tmux_timeout_seconds=2\n"));
    assert!(manifest.contains("lsof_timeout_seconds=7\n"));
    assert!(manifest.ends_with("readonly=true\n"));
    let utc = manifest
        .lines()
        .next()
        .unwrap()
        .strip_prefix("utc=")
        .unwrap();
    assert!(evidence
        .file_name()
        .unwrap()
        .to_str()
        .unwrap()
        .starts_with(&format!("tmux-freeze-capture-{utc}-")));
    (evidence, elapsed)
}

fn timing(evidence: &Path) -> Vec<Vec<String>> {
    let text = fs::read_to_string(evidence.join("timing.tsv")).unwrap();
    assert_eq!(
        text.lines().next().unwrap(),
        "label\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus"
    );
    let rows: Vec<Vec<String>> = text
        .lines()
        .skip(1)
        .map(|line| line.split('\t').map(String::from).collect())
        .collect();
    for row in &rows {
        assert_eq!(row.len(), 5);
        let start: i128 = row[1].parse().unwrap();
        let end: i128 = row[2].parse().unwrap();
        assert_eq!(row[3], (end - start).to_string());
        assert_eq!(
            fs::read_to_string(evidence.join(format!("{}.status.txt", row[0]))).unwrap(),
            format!("{}\n", row[4])
        );
    }
    rows
}

#[test]
#[ignore]
fn hold() {
    loop {
        std::thread::park_timeout(Duration::from_secs(60));
    }
}

#[test]
#[ignore]
fn owned_freeze() {
    let context = "isolated owned private -S server";
    let root = PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk/tmp/relay/lead-plan/release/freeze/private");
    fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&root)
        .unwrap();
    let run_root = root.join(format!("run-{}", std::process::id()));
    fs::DirBuilder::new().mode(0o700).create(&run_root).unwrap();
    fs::create_dir(run_root.join("bin")).unwrap();
    let candidate = PathBuf::from(std::env::var_os("FREEZE_RELEASE_CANDIDATE").unwrap());
    let installed = PathBuf::from(std::env::var_os("HOME").unwrap()).join(".local/share/angelstar");
    assert!(candidate.starts_with(installed));
    assert_eq!(candidate.file_name().unwrap(), "angelstar-runtime");
    assert_eq!(
        fs::metadata(&candidate).unwrap().permissions().mode() & 0o777,
        0o500
    );
    let candidate_sha256 = format!("{:x}", Sha256::digest(fs::read(&candidate).unwrap()));
    assert_eq!(
        candidate_sha256,
        std::env::var("FREEZE_RELEASE_SHA256").unwrap()
    );
    symlink(&candidate, run_root.join("bin/tmux-freeze-capture.fish")).unwrap();
    let socket = run_root.join("server");
    let child = Command::new(TMUX)
        .args(["-D", "-f", "/dev/null", "-S"])
        .arg(&socket)
        .env_remove("TMUX")
        .env_remove("TMUX_PANE")
        .stdin(Stdio::null())
        .stdout(File::create(run_root.join("server.stdout")).unwrap())
        .stderr(File::create(run_root.join("server.stderr")).unwrap())
        .spawn()
        .unwrap();
    let mut server = Server {
        child,
        socket: socket.clone(),
        pane: String::new(),
    };
    let deadline = Instant::now() + Duration::from_secs(3);
    while !socket.exists() {
        assert!(server.child.try_wait().unwrap().is_none());
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    let binary = std::env::current_exe().unwrap();
    let created = tmux(
        Some(&socket),
        &[
            "new-session",
            "-d",
            "-P",
            "-F",
            "#{pane_id}",
            "-s",
            "p4f-owned",
            "-n",
            "hold",
            "--",
            binary.to_str().unwrap(),
            "--ignored",
            "--exact",
            "hold",
            "--nocapture",
        ],
    );
    assert!(created.status.success(), "{created:?}");
    server.pane = String::from_utf8(created.stdout).unwrap().trim().into();
    assert!(
        tmux(Some(&socket), &["set-option", "-s", "exit-empty", "on"])
            .status
            .success()
    );
    let identity = tmux(Some(&socket), &["display-message", "-p", "#{pid}"]);
    assert_eq!(
        String::from_utf8(identity.stdout).unwrap().trim(),
        server.child.id().to_string()
    );
    let (healthy, healthy_ms) = capture(&run_root, &socket, "healthy", 0);
    let rows = timing(&healthy);
    assert_eq!(
        rows.iter().map(|row| row[0].as_str()).collect::<Vec<_>>(),
        [
            "socket-lsof",
            "server-ps",
            "server-sample",
            "sessions",
            "panes",
            "clients",
            "server-options",
            "server-message"
        ]
    );
    assert!(rows.iter().all(|row| row[4] == "0"), "{rows:?}");
    assert_eq!(
        fs::read_to_string(healthy.join("server-pid.txt"))
            .unwrap()
            .trim(),
        server.child.id().to_string()
    );
    let fields = fs::read_to_string(healthy.join("panes.stdout.txt")).unwrap();
    assert_eq!(fields.trim().split('|').count(), 8);
    assert!(fields.contains("|p4f-owned|hold|"));
    server.signal(libc::SIGSTOP);
    let (stopped, stopped_ms) = capture(&run_root, &socket, "stopped", 1);
    let rows = timing(&stopped);
    assert_eq!(
        rows.iter().map(|row| row[0].as_str()).collect::<Vec<_>>(),
        ["socket-lsof", "server-ps", "server-sample", "sessions"]
    );
    assert_eq!(rows[3][4], "124");
    let timeout_code: i32 = rows[3][4].parse().unwrap();
    assert!((1900..4000).contains(&rows[3][3].parse::<u128>().unwrap()));
    assert_eq!(
        fs::read_to_string(stopped.join("server-pid.txt"))
            .unwrap()
            .trim(),
        server.child.id().to_string()
    );
    assert!(fs::read_to_string(stopped.join("server-ps.stdout.txt"))
        .unwrap()
        .split_whitespace()
        .nth(2)
        .unwrap()
        .starts_with('T'));
    for label in ["panes", "clients", "server-options", "server-message"] {
        for suffix in ["stdout", "stderr", "status"] {
            assert!(!stopped.join(format!("{label}.{suffix}.txt")).exists());
        }
    }
    assert!(fs::read_to_string(run_root.join("stopped.stderr"))
        .unwrap()
        .contains("tmux request timed out; capture stopped. Evidence:"));
    server.signal(libc::SIGCONT);
    assert!(tmux(Some(&socket), &["display-message", "-p", "#{pid}"])
        .status
        .success());
    let missing = run_root.join("missing");
    let path = format!(
        "{}:{}",
        run_root.join("bin").display(),
        std::env::var("PATH").unwrap()
    );
    let mut refusals = Vec::new();
    for (label, target, output, bin, expected) in [
        (
            "absent-socket",
            missing.as_path(),
            run_root.join("absent-output"),
            TMUX,
            1,
        ),
        (
            "absent-binary",
            socket.as_path(),
            run_root.join("binary-output"),
            missing.to_str().unwrap(),
            64,
        ),
        (
            "output-file",
            socket.as_path(),
            run_root.join("blocked-output"),
            TMUX,
            73,
        ),
    ] {
        if label == "output-file" {
            fs::write(&output, "occupied").unwrap();
        }
        let out = run(
            Command::new("tmux-freeze-capture.fish")
                .env("PATH", &path)
                .env("TMUX_FREEZE_CAPTURE_SOCKET", target)
                .env("TMUX_FREEZE_CAPTURE_OUTPUT_ROOT", &output)
                .env("TMUX_FREEZE_CAPTURE_TMUX_BIN", bin),
            3,
        );
        assert_eq!(out.status.code(), Some(expected), "{label}: {out:?}");
        refusals.push(json!({"case":label,"expected":expected,"actual":out.status.code(),"stderr":String::from_utf8_lossy(&out.stderr)}));
    }
    let pid = server.child.id();
    drop(server);
    assert!(std::os::unix::net::UnixStream::connect(&socket).is_err());
    fs::write(run_root.join("result.json"), serde_json::to_vec_pretty(&json!({"status":"PASS","context":context.trim(),"root":run_root,"candidate":candidate,"candidate_sha256":candidate_sha256,"socket":socket,"owned_server_pid":pid,"healthy":{"expected":0,"actual":0,"elapsed_ms":healthy_ms,"evidence":healthy},"stopped":{"expected":1,"actual":1,"elapsed_ms":stopped_ms,"evidence":stopped,"tmux_status":timeout_code,"later_requests":false},"refusals":refusals,"cleanup":"owned server reaped; owned pane ended"})).unwrap()).unwrap();
}
