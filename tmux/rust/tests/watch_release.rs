use serde_json::{json, Value};
use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::{Child, Command};
use std::time::{Duration, Instant};

const TMUX: &str = "/opt/homebrew/Cellar/tmux/3.7c/bin/tmux";
fn q(args: &[&str]) -> String {
    let output = Command::new(TMUX).args(args).output().unwrap();
    assert!(
        output.status.success(),
        "{args:?}: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout)
        .unwrap()
        .trim_end_matches('\n')
        .into()
}
fn save(path: &Path, value: &Value) {
    fs::write(path, serde_json::to_vec_pretty(value).unwrap()).unwrap();
}
fn wait(mut predicate: impl FnMut() -> bool, seconds: u64, label: &str) {
    let deadline = Instant::now() + Duration::from_secs(seconds);
    while !predicate() {
        assert!(Instant::now() < deadline, "timed out: {label}");
        std::thread::sleep(Duration::from_millis(100));
    }
}
fn text(path: &Path) -> String {
    fs::read_to_string(path).unwrap_or_default()
}
fn capture(pane: &str, path: &Path) -> String {
    let text = q(&["capture-pane", "-p", "-t", pane, "-S", "-400"]);
    fs::write(path, &text).unwrap();
    text
}
fn tree(pid: u32) -> Vec<(u32, u32, String)> {
    let output = Command::new("/bin/ps")
        .args(["-axo", "pid=,ppid=,comm="])
        .output()
        .unwrap();
    assert!(output.status.success());
    let rows: Vec<_> = String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .filter_map(|line| {
            let mut parts = line.split_whitespace();
            Some((
                parts.next()?.parse::<u32>().ok()?,
                parts.next()?.parse::<u32>().ok()?,
                parts.collect::<Vec<_>>().join(" "),
            ))
        })
        .collect();
    let mut owned = vec![pid];
    loop {
        let before = owned.len();
        for (child, parent, _) in &rows {
            if owned.contains(parent) && !owned.contains(child) {
                owned.push(*child);
            }
        }
        if before == owned.len() {
            break;
        }
    }
    rows.into_iter()
        .filter(|(p, _, _)| owned.contains(p))
        .collect()
}
struct Smoke {
    root: PathBuf,
    window: String,
    pane: String,
    pane_pid: String,
    name: String,
    children: Vec<Child>,
    live: bool,
    passed: bool,
}
impl Smoke {
    fn owned(&self) -> bool {
        let output = Command::new(TMUX)
            .args([
                "display-message",
                "-p",
                "-t",
                &self.window,
                "#{pane_id}|#{pane_pid}|#{window_name}",
            ])
            .output()
            .unwrap();
        output.status.success()
            && String::from_utf8_lossy(&output.stdout).trim()
                == format!("{}|{}|{}", self.pane, self.pane_pid, self.name)
    }
    fn watcher(&mut self, executable: &str, hot: &Path, replace: bool, label: &str) -> PathBuf {
        let log = self.root.join(format!("{label}.stdout"));
        let mut command = Command::new(executable);
        command.args([
            "--pane",
            &self.pane,
            "--ui",
            "codex",
            "--hot-file",
            hot.to_str().unwrap(),
            "--ack-current",
        ]);
        if replace {
            command.arg("--replace");
        }
        let child = command
            .env("PW_POLL", "1")
            .env("PW_HEARTBEAT", "1")
            .stdout(File::create(&log).unwrap())
            .stderr(File::create(self.root.join(format!("{label}.stderr"))).unwrap())
            .spawn()
            .unwrap();
        save(
            &self.root.join(format!("{label}.json")),
            &json!({"pid":child.id(),"program":executable,"pane":self.pane,"replace":replace,"env":{"PW_POLL":"1","PW_HEARTBEAT":"1"}}),
        );
        self.children.push(child);
        wait(|| text(&log).contains("ARMED codex"), 12, "watcher arm");
        log
    }
    fn exit(&mut self, index: usize) -> i32 {
        let mut code = None;
        wait(
            || {
                code = self.children[index]
                    .try_wait()
                    .unwrap()
                    .map(|s| s.code().unwrap_or(-1));
                code.is_some()
            },
            12,
            "watcher exit",
        );
        code.unwrap()
    }
}
impl Drop for Smoke {
    fn drop(&mut self) {
        if !self.passed && self.live {
            let status = Command::new("/bin/ln")
                .arg("-sfn")
                .arg(
                    PathBuf::from(std::env::var_os("HOME").unwrap())
                        .join(".scripts/tmux/pane-watch/pane-watch.sh"),
                )
                .arg(PathBuf::from(std::env::var_os("HOME").unwrap()).join(".local/bin/pane-watch"))
                .status();
            let _ = fs::write(self.root.join("rollback.txt"), format!("{status:?}\n"));
        }
        for child in &mut self.children {
            if child.try_wait().ok().flatten().is_none() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
        if !self.window.is_empty() && self.owned() {
            let _ = Command::new(TMUX)
                .args(["kill-window", "-t", &self.window])
                .output();
        }
    }
}
#[test]
#[ignore]
fn release_watch_smoke() {
    let root = PathBuf::from(std::env::var("PANE_WATCH_SMOKE_ROOT").unwrap());
    let executable = std::env::var("PANE_WATCH_SMOKE_BIN").unwrap();
    let phase = std::env::var("PANE_WATCH_SMOKE_PHASE").unwrap();
    assert!(["private", "live"].contains(&phase.as_str()));
    fs::create_dir(&root).unwrap();
    let owner = fs::read_to_string(
        PathBuf::from(std::env::var_os("HOME").unwrap()).join("desk/tmp/relay/realtab.lock/owner"),
    )
    .unwrap();
    assert!(owner.contains("seat=config-tt:lab-watch") && owner.contains("release/pane-watch"));
    let name = format!("release-watch-{phase}-{}", std::process::id());
    assert!(
        !q(&["list-windows", "-t", "=config-tt", "-F", "#{window_name}"])
            .lines()
            .any(|n| n == name)
    );
    let focus = q(&[
        "list-clients",
        "-F",
        "#{client_name}|#{session_name}|#{window_id}",
    ]);
    let command = "codex -m gpt-6.1-sol -c model_reasoning_effort=xhigh -c service_tier=default";
    let created = q(&[
        "new-window",
        "-d",
        "-P",
        "-F",
        "#{window_id}|#{pane_id}|#{pane_pid}",
        "-t",
        "=config-tt:",
        "-n",
        &name,
        "-c",
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .ancestors()
            .nth(2)
            .unwrap()
            .to_str()
            .unwrap(),
        "--",
        "/opt/homebrew/bin/fish",
        "-C",
        command,
    ]);
    let parts: Vec<_> = created.split('|').collect();
    assert_eq!(parts.len(), 3);
    let mut smoke = Smoke {
        root: root.clone(),
        window: parts[0].into(),
        pane: parts[1].into(),
        pane_pid: parts[2].into(),
        name,
        children: vec![],
        live: phase == "live",
        passed: false,
    };
    save(
        &root.join("launch.json"),
        &json!({"phase":phase,"window":smoke.window,"pane":smoke.pane,"pane_pid":smoke.pane_pid,"program":"/opt/homebrew/bin/fish","argv":["-C",command],"focus_before":focus}),
    );
    q(&[
        "set-window-option",
        "-t",
        &smoke.window,
        "window-size",
        "manual",
    ]);
    q(&[
        "resize-window",
        "-t",
        &smoke.window,
        "-x",
        "149",
        "-y",
        "45",
    ]);
    wait(
        || {
            let s = capture(&smoke.pane, &root.join("startup.txt"));
            s.contains("Fast off") && s.contains("Ask Codex to do anything") && s.contains("xhigh")
        },
        120,
        "fresh Codex Fast off xhigh",
    );
    let processes = tree(smoke.pane_pid.parse().unwrap());
    assert!(
        processes.iter().any(|(_, _, p)| p.ends_with("/codex")),
        "native Codex absent: {processes:?}"
    );
    save(&root.join("owned-processes.json"), &json!(processes));
    let hot = root.join("custom.hot");
    fs::write(&hot, "PW_RELEASE_OMEGA\nPW_RELEASE_ALPHA\n").unwrap();
    let first = smoke.watcher(&executable, &hot, false, "first");
    for turn in [1, 2] {
        let wire = format!("#release-watch-{phase}-{turn} Reply exactly PW_RELEASE_ALPHA PW_RELEASE_OMEGA without tools.");
        q(&["send-keys", "-t", &smoke.pane, "-l", "--", &wire]);
        q(&["send-keys", "-t", &smoke.pane, "Enter"]);
        wait(
            || {
                capture(&smoke.pane, &root.join(format!("turn-{turn}.txt")))
                    .lines()
                    .any(|line| {
                        line.trim()
                            .strip_prefix('•')
                            .is_some_and(|s| s.trim() == "PW_RELEASE_ALPHA PW_RELEASE_OMEGA")
                    })
                    && text(&first)
                        .lines()
                        .filter(|l| *l == "HOT: PW_RELEASE_OMEGA")
                        .count()
                        == turn
            },
            90,
            "real HOT turn",
        );
        wait(
            || {
                text(&first)
                    .lines()
                    .filter(|l| l.contains("PANE RESPONSE MAY BE NEEDED"))
                    .count()
                    == turn
            },
            12,
            "idle alert per turn",
        );
        fs::write(root.join(format!("turn-{turn}.wire")), wire).unwrap();
    }
    assert_eq!(
        text(&first)
            .lines()
            .filter(|l| *l == "HOT: PW_RELEASE_OMEGA")
            .count(),
        2
    );
    let replacement = smoke.watcher(&executable, &hot, true, "replacement");
    assert_eq!(smoke.exit(0), 143);
    q(&["resize-window", "-t", &smoke.window, "-y", "35"]);
    wait(|| text(&replacement).contains("45r -> 35r"), 12, "shrink");
    capture(&smoke.pane, &root.join("height-35.txt"));
    q(&["resize-window", "-t", &smoke.window, "-y", "45"]);
    wait(|| text(&replacement).contains("35r -> 45r"), 12, "grow");
    capture(&smoke.pane, &root.join("height-45.txt"));
    wait(
        || {
            text(&replacement)
                .lines()
                .filter(|s| s.starts_with("HEALTH:"))
                .count()
                >= 4
        },
        12,
        "stable resize observation",
    );
    let resized = text(&replacement);
    assert!(
        !resized.contains("PANE RESPONSE MAY BE NEEDED")
            && !resized.contains("MODEL/CONFIG CHANGED"),
        "{resized}"
    );
    let socket = q(&["display-message", "-p", "-t", &smoke.pane, "#{socket_path}"]);
    let server = q(&["display-message", "-p", "-t", &smoke.pane, "#{pid}"]);
    use sha2::{Digest, Sha256};
    let key = format!(
        "{:x}-{}",
        Sha256::digest(format!("{socket}:{server}").as_bytes()),
        &smoke.pane[1..]
    );
    let lock = PathBuf::from(std::env::var("TMPDIR").unwrap_or_else(|_| "/tmp".into()))
        .join("pane-watch-locks")
        .join(key);
    assert!(lock.is_dir());
    assert!(smoke.owned());
    q(&["kill-window", "-t", &smoke.window]);
    smoke.window.clear();
    assert_eq!(smoke.exit(1), 3);
    assert!(!lock.exists());
    wait(
        || tree(smoke.pane_pid.parse().unwrap()).is_empty(),
        12,
        "owned native process exit",
    );
    let after = q(&[
        "list-clients",
        "-F",
        "#{client_name}|#{session_name}|#{window_id}",
    ]);
    assert_eq!(after, focus, "client focus changed");
    save(
        &root.join("result.json"),
        &json!({"status":"PASS","phase":phase,"two_real_hot_turns":true,"hot":"PW_RELEASE_OMEGA","resize":[45,35,45],"replaced_exit":143,"target_exit":3,"watcher_lock_absent":true,"owned_pane_process_absent":true,"focus_unchanged":true,"executable":executable}),
    );
    smoke.passed = true;
}
