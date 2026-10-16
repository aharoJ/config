use angelstar_runtime::model_guard::visible;
use serde_json::{json, Value};
use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

const TMUX: &str = "/opt/homebrew/Cellar/tmux/3.7c/bin/tmux";

fn query(args: &[&str]) -> String {
    let output = Command::new(TMUX).args(args).output().unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout)
        .unwrap()
        .trim_end_matches('\n')
        .into()
}

fn capture(pane: &str) -> String {
    query(&["capture-pane", "-p", "-e", "-t", pane, "-S", "-500"])
}

fn wait_screen(pane: &str, root: &Path, name: &str, predicate: impl Fn(&str) -> bool) -> String {
    let deadline = Instant::now() + Duration::from_secs(45);
    loop {
        let text = capture(pane);
        fs::write(root.join(format!("{name}.ansi")), &text).unwrap();
        if predicate(&visible(&text)) {
            return text;
        }
        assert!(
            Instant::now() < deadline,
            "missing screen {name}; no replay"
        );
        std::thread::sleep(Duration::from_millis(25));
    }
}

fn send(alias: &Path, root: &Path, name: &str, window: &str, message: &str) -> Child {
    Command::new(alias)
        .args([window, message])
        .env("AGY_SEND_SESSION", "config-tt")
        .env_remove("AGY_SEND_PANE")
        .env_remove("ANGELSTAR_RELAY_SOCKET")
        .env_remove("ANGELSTAR_RELAY_STORE")
        .stdin(Stdio::null())
        .stdout(File::create(root.join(format!("{name}.stdout"))).unwrap())
        .stderr(File::create(root.join(format!("{name}.stderr"))).unwrap())
        .spawn()
        .unwrap()
}

fn finish(child: &mut Child, root: &Path, name: &str) -> Value {
    let deadline = Instant::now() + Duration::from_secs(45);
    let code = loop {
        if let Some(status) = child.try_wait().unwrap() {
            break status.code();
        }
        assert!(Instant::now() < deadline, "{name}: deadline; no replay");
        std::thread::sleep(Duration::from_millis(20));
    };
    let stderr = fs::read_to_string(root.join(format!("{name}.stderr"))).unwrap();
    fs::write(root.join(format!("{name}.exit")), format!("{code:?}\n")).unwrap();
    assert_eq!(code, Some(0), "{name}: {stderr}");
    completed(root, name)
}

fn completed(root: &Path, name: &str) -> Value {
    assert_eq!(
        fs::read_to_string(root.join(format!("{name}.exit"))).unwrap(),
        "Some(0)\n"
    );
    let stdout = fs::read_to_string(root.join(format!("{name}.stdout"))).unwrap();
    let path = stdout
        .lines()
        .find_map(|line| line.split_once("; record ").map(|(_, path)| path))
        .unwrap();
    let result: Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
    assert_eq!(result["state"], "delivered");
    fs::write(
        root.join(format!("{name}.record.json")),
        serde_json::to_vec_pretty(&result).unwrap(),
    )
    .unwrap();
    result
}

#[test]
#[ignore = "owned native Agy seat and private candidate alias"]
fn private_idle_and_generating_ack() {
    let root = PathBuf::from(std::env::var_os("AGY_RELEASE_EVIDENCE").unwrap());
    let alias = PathBuf::from(std::env::var_os("AGY_RELEASE_ALIAS").unwrap());
    let window = std::env::var("AGY_RELEASE_WINDOW").unwrap();
    let live = std::env::var("AGY_RELEASE_LIVE").is_ok_and(|value| value == "1");
    assert_eq!(alias.file_name().unwrap(), "agy-send-to");
    if live {
        assert_eq!(
            alias,
            PathBuf::from(std::env::var_os("HOME").unwrap()).join(".local/bin/agy-send-to")
        );
    } else {
        assert!(alias.starts_with(&root));
    }
    let caller = std::env::var("TMUX_PANE").unwrap();
    let session = query(&["display-message", "-p", "-t", &caller, "#{session_name}"]);
    assert_eq!(session, "config-tt");
    let target = format!("=config-tt:={window}");
    let pane = query(&["list-panes", "-t", &target, "-F", "#{pane_id}"]);
    assert!(pane.starts_with('%') && !pane.contains('\n'));
    let metadata = query(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{pane_id}|#{pane_pid}|#{pane_current_command}|#{pane_width}|#{pane_height}",
    ]);
    fs::write(root.join("target.txt"), &metadata).unwrap();
    wait_screen(&pane, &root, "idle-before", |text| {
        text.contains("? for shortcuts") && !text.contains("esc to cancel")
    });
    let help = Command::new(&alias).arg("--help").output().unwrap();
    assert!(help.status.success());
    let missing = Command::new(&alias)
        .args(["agy-absent-release", "#agy missing route"])
        .env("AGY_SEND_SESSION", "config-tt")
        .output()
        .unwrap();
    fs::write(root.join("missing.stderr"), &missing.stderr).unwrap();
    assert_eq!(missing.status.code(), Some(1));
    let resume = std::env::var("AGY_RELEASE_RESUME_IDLE_ACK").ok();
    let idle_ack = resume
        .clone()
        .unwrap_or_else(|| format!("AGY_IDLE_{}", std::process::id()));
    let idle_message = format!("#agyidle Reply {idle_ack} only; no tools.");
    let idle_result = if resume.is_some() {
        completed(&root, "idle")
    } else {
        let mut idle = send(&alias, &root, "idle", &window, &idle_message);
        finish(&mut idle, &root, "idle")
    };
    assert_eq!(idle_result["message"], idle_message);
    assert_eq!(idle_result["target"]["pane_id"], pane);
    wait_screen(&pane, &root, "idle-ack", |text| {
        text.lines().any(|line| line.trim() == idle_ack)
            && text.contains("? for shortcuts")
            && !text.contains("esc to cancel")
    });
    let mut generating = send(
        &alias,
        &root,
        "generator",
        &window,
        "#agygen Print 120 numbered lines, one number per line. No tools.",
    );
    wait_screen(&pane, &root, "generating-before-send", |text| {
        text.contains("esc to cancel")
    });
    let busy_ack = format!("AGY_BUSY_{}", std::process::id());
    let mut busy = send(
        &alias,
        &root,
        "busy",
        &window,
        &format!("#agybusy Reply {busy_ack} only; no tools."),
    );
    let generator_result = finish(&mut generating, &root, "generator");
    let busy_result = finish(&mut busy, &root, "busy");
    wait_screen(&pane, &root, "busy-ack", |text| {
        text.lines().any(|line| line.trim() == busy_ack)
            && text.contains("? for shortcuts")
            && !text.contains("esc to cancel")
    });
    let after = query(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{pane_id}|#{pane_pid}|#{pane_current_command}|#{pane_width}|#{pane_height}",
    ]);
    assert_eq!(metadata, after);
    fs::write(root.join("RESULT.json"), serde_json::to_vec_pretty(&json!({"status":"PASS","caller":caller,"target":metadata,"route":{"AGY_SEND_SESSION":"config-tt","window":window},"idle_ack":idle_ack,"busy_ack":busy_ack,"idle":idle_result,"generator":generator_result,"busy":busy_result,"public_links_changed":live})).unwrap()).unwrap();
}
