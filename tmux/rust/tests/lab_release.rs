use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn alias() -> PathBuf {
    PathBuf::from(std::env::var_os("LAB_RELEASE_ALIAS").unwrap())
}
fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap())
}
fn evidence() -> PathBuf {
    PathBuf::from(std::env::var_os("LAB_RELEASE_EVIDENCE").unwrap())
}
#[test]
#[ignore]
fn precheck() {
    let root = home().join("desk/lab/tmux-to-rust-artifacts/relay-stable-backup-2026-10-15");
    let mut rows = Vec::new();
    for (manifest, expected) in [("SHA256SUMS", 12), ("LIVE-SHA256SUMS", 7)] {
        let text = fs::read_to_string(root.join(manifest)).unwrap();
        let mut count = 0;
        for line in text.lines().filter(|line| !line.is_empty()) {
            let (hash, name) = line.split_once(char::is_whitespace).unwrap();
            let name = name.trim_start().trim_start_matches('*');
            let path = root.join(name);
            let actual = format!("{:x}", Sha256::digest(fs::read(&path).unwrap()));
            assert_eq!(actual, hash, "{}", path.display());
            rows.push(json!({"manifest":manifest,"path":path,"sha256":actual}));
            count += 1;
        }
        assert_eq!(count, expected);
    }
    let binary = fs::canonicalize(alias()).unwrap();
    let hash = format!("{:x}", Sha256::digest(fs::read(&binary).unwrap()));
    assert_eq!(hash, std::env::var("LAB_RELEASE_SHA").unwrap());
    fs::write(
        evidence().join("precheck.json"),
        serde_json::to_vec_pretty(
            &json!({"status":"PASS","binary":binary,"sha256":hash,"rows":rows}),
        )
        .unwrap(),
    )
    .unwrap();
}
#[test]
#[ignore]
fn census_probe() {
    assert!(std::env::var("TMUX_PANE").is_err());
    let name = std::env::var("TMUX_LAB_SOCKET").unwrap();
    let output = Command::new(alias()).arg("ls").output().unwrap();
    assert!(output.status.success());
    let row = String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .find(|row| row["socket"] == name && row["state"] == "running")
        .unwrap();
    let keys = [
        "record",
        "state",
        "owner_live",
        "escaped_processes",
        "escape_inspection_unknown",
        "escape_observation",
        "server_live",
        "socket_observation",
        "stale",
        "inspection_unknown",
        "socket",
        "server_pid",
    ];
    assert_eq!(row.as_object().unwrap().len(), keys.len());
    assert!(keys.iter().all(|key| row.get(key).is_some()));
    assert_eq!(row["server_live"], true);
    assert_eq!(row["owner_live"], true);
    let mut proxy = Vec::new();
    for (args, expected) in [
        (vec!["-L", name.as_str(), "list-panes", "-a"], 0),
        (vec!["-L", "default", "list-panes"], 97),
        (vec!["-L", name.as_str(), "kill-server"], 97),
    ] {
        let out = Command::new("tmux").args(&args).output().unwrap();
        assert_eq!(out.status.code(), Some(expected));
        proxy.push(json!({"argv":args,"exit":expected}));
    }
    fs::write(
        evidence().join("census.json"),
        serde_json::to_vec_pretty(&json!({"row":row,"proxy":proxy})).unwrap(),
    )
    .unwrap();
}
fn record(pid: u32) -> (PathBuf, Value) {
    fs::read_dir(home().join("desk/lab/tmux-lab-ledger"))
        .unwrap()
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            entry
                .file_name()
                .to_string_lossy()
                .starts_with(&format!("run-{pid}-"))
        })
        .filter_map(|entry| {
            let path = entry.path().join("record.json");
            let row: Value = serde_json::from_slice(&fs::read(&path).ok()?).ok()?;
            Some((path, row))
        })
        .max_by(|a, b| {
            a.1["created"]
                .as_f64()
                .partial_cmp(&b.1["created"].as_f64())
                .unwrap()
        })
        .unwrap()
}
#[test]
#[ignore]
fn smoke() {
    let mut rows = Vec::new();
    for (name, command, expected) in [
        ("true", vec!["/usr/bin/true".to_string()], 0),
        ("false", vec!["/usr/bin/false".to_string()], 1),
        (
            "missing",
            vec!["/lab-release-no-such-executable".to_string()],
            97,
        ),
        (
            "census",
            vec![
                std::env::current_exe()
                    .unwrap()
                    .to_string_lossy()
                    .into_owned(),
                "--ignored".into(),
                "--exact".into(),
                "census_probe".into(),
                "--nocapture".into(),
            ],
            0,
        ),
    ] {
        let child = Command::new(alias())
            .args(["run", "--"])
            .args(&command)
            .spawn()
            .unwrap();
        let pid = child.id();
        let status = child.wait_with_output().unwrap().status;
        assert_eq!(status.code(), Some(expected), "{name}");
        let (path, row) = record(pid);
        assert_eq!(row["state"], "closed");
        assert_eq!(row["exit_code"], if expected == 97 { 1 } else { expected });
        assert_eq!(row["kill_exit"], 0);
        assert_eq!(row["cleanup_errors"], json!([]));
        assert_eq!(row["remaining_pane_pids"], json!([]));
        assert_eq!(row["escaped_processes"], json!([]));
        assert!(std::os::unix::net::UnixStream::connect(Path::new(
            row["socket_path"].as_str().unwrap()
        ))
        .is_err());
        rows.push(
            json!({"case":name,"command":command,"exit":expected,"record_path":path,"record":row}),
        );
    }
    fs::write(evidence().join("smoke.json"),serde_json::to_vec_pretty(&json!({"status":"PASS","alias":alias(),"binary":fs::canonicalize(alias()).unwrap(),"rows":rows})).unwrap()).unwrap();
}
