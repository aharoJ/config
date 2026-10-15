use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs;
use std::os::unix::fs::{symlink, DirBuilderExt, MetadataExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

fn record(
    rows: &mut Vec<Value>,
    label: &str,
    home: &Path,
    bin: &Path,
    args: &[String],
    expected: i32,
) {
    let path = format!(
        "{}:{}",
        bin.display(),
        std::env::var("PATH").unwrap_or_default()
    );
    let started = Instant::now();
    let output = Command::new("panel-seat-trust")
        .args(args)
        .env("PATH", path)
        .env("HOME", home)
        .output()
        .unwrap();
    let actual = output.status.code();
    rows.push(json!({"shape":label,"argv":args,"home":home,"expected_exit":expected,"actual_exit":actual,
        "stdout":String::from_utf8_lossy(&output.stdout),"stderr":String::from_utf8_lossy(&output.stderr),
        "elapsed_ms":started.elapsed().as_millis()}));
    assert_eq!(
        actual,
        Some(expected),
        "{label}: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

fn fixture(root: &Path, name: &str) -> PathBuf {
    let home = root.join(name);
    fs::create_dir_all(home.join(".gemini/antigravity-cli")).unwrap();
    fs::create_dir_all(home.join("desk/.secret/deepseek")).unwrap();
    fs::write(home.join(".claude.json"), "{\"untouched\":42}").unwrap();
    fs::write(home.join(".gemini/antigravity-cli/settings.json"), "{}").unwrap();
    fs::write(
        home.join("desk/.secret/deepseek/api-key"),
        "fixture-01234567890123456789",
    )
    .unwrap();
    home
}

#[test]
#[ignore = "run only from a plain pane in the lane's private config-tt test window"]
fn native_plain_pane_parity() {
    let pane = std::env::var("TMUX_PANE").expect("plain tmux pane required");
    let observed = Command::new("/opt/homebrew/bin/tmux")
        .args([
            "display-message",
            "-p",
            "-t",
            &pane,
            "#{session_name}\t#{window_name}\t#{pane_id}\t#{pane_current_command}",
        ])
        .output()
        .unwrap();
    assert!(observed.status.success());
    let observed = String::from_utf8(observed.stdout).unwrap();
    let fields: Vec<_> = observed.trim().split('\t').collect();
    assert_eq!(fields[0], "config-tt");
    assert!(fields[1].starts_with("p3x-test-"));
    assert_eq!(fields[2], pane);
    let home = PathBuf::from(std::env::var_os("HOME").unwrap());
    let evidence = home.join("desk/tmp/relay/port/panel-evidence");
    fs::create_dir_all(&evidence).unwrap();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = evidence.join(format!("plain-{nonce}"));
    fs::DirBuilder::new().mode(0o700).create(&root).unwrap();
    let bin = root.join("bin");
    let installed = evidence.join("installed-candidate");
    fs::create_dir(&bin).unwrap();
    fs::create_dir_all(&installed).unwrap();
    let candidate = installed.join("angelstar-runtime");
    fs::copy(env!("CARGO_BIN_EXE_angelstar-runtime"), &candidate).unwrap();
    symlink(&candidate, bin.join("panel-seat-trust")).unwrap();
    symlink(&candidate, bin.join("panel-dispatch")).unwrap();
    let seat = fs::read_dir("/private/tmp")
        .unwrap()
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .unwrap()
                .to_string_lossy()
                .starts_with("review-protocol-")
        })
        .filter(|path| {
            let name = path.file_name().unwrap().to_string_lossy();
            name.contains("-audit-r") && name.contains("-agentic-") && name.ends_with("-cli")
        })
        .find(|path| {
            fs::symlink_metadata(path).is_ok_and(|m| {
                m.is_dir() && m.uid() == unsafe { libc::getuid() } && m.mode() & 0o077 == 0
            })
        })
        .expect(
            "an existing private seat directory is required; smoke never creates or changes seats",
        );
    let seat = seat.to_str().unwrap().to_owned();
    let logical = format!("/tmp{}", &seat["/private/tmp".len()..]);
    let mut rows = Vec::new();
    for kind in ["claude", "deepseek", "codex", "agy"] {
        let fixture = fixture(&root, kind);
        let args = vec![kind.into(), seat.clone()];
        record(
            &mut rows,
            &format!("{kind} physical seat"),
            &fixture,
            &bin,
            &args,
            0,
        );
        let config = fixture.join(match kind {
            "claude" | "deepseek" => ".claude.json",
            "agy" => ".gemini/antigravity-cli/settings.json",
            _ => ".local/state/codex-panel-home/config.toml",
        });
        let bytes = fs::read(&config).unwrap();
        let inode = fs::metadata(&config).unwrap().ino();
        record(
            &mut rows,
            &format!("{kind} logical seat, already trusted"),
            &fixture,
            &bin,
            &[kind.into(), logical.clone()],
            0,
        );
        assert_eq!(fs::read(&config).unwrap(), bytes);
        assert_eq!(fs::metadata(&config).unwrap().ino(), inode);
        if kind == "codex" {
            assert_eq!(
                fs::read_link(config.parent().unwrap().join("auth.json")).unwrap(),
                fixture.join(".codex/auth.json")
            );
            let value: toml::Table = toml::from_str(std::str::from_utf8(&bytes).unwrap()).unwrap();
            assert_eq!(
                value["projects"][&seat]["trust_level"].as_str(),
                Some("trusted")
            );
            assert_eq!(
                value["projects"][&logical]["trust_level"].as_str(),
                Some("trusted")
            );
        } else {
            let value: Value = serde_json::from_slice(&bytes).unwrap();
            if kind == "agy" {
                assert_eq!(value["trustedWorkspaces"], json!([seat, logical]));
            } else {
                assert_eq!(value["untouched"], 42);
                assert_eq!(value["projects"][&seat]["hasTrustDialogAccepted"], true);
                assert_eq!(value["projects"][&logical]["hasTrustDialogAccepted"], true);
            }
        }
    }
    let generic = fixture(&root, "usage");
    for (name, args, exit) in [
        ("no argv", vec![], 2),
        ("help", vec!["--help".into()], 2),
        ("unknown kind", vec!["other".into(), seat.clone()], 2),
        ("missing seat", vec!["claude".into()], 2),
        (
            "extra argv",
            vec!["claude".into(), seat.clone(), "extra".into()],
            2,
        ),
        ("relative seat", vec!["claude".into(), "relative".into()], 1),
        (
            "unrelated seat",
            vec!["claude".into(), generic.to_str().unwrap().into()],
            1,
        ),
        (
            "absent seat",
            vec!["claude".into(), format!("{seat}-absent")],
            1,
        ),
    ] {
        record(&mut rows, name, &generic, &bin, &args, exit);
    }
    let malformed = fixture(&root, "malformed");
    fs::write(malformed.join(".claude.json"), "{").unwrap();
    record(
        &mut rows,
        "malformed config",
        &malformed,
        &bin,
        &["claude".into(), seat.clone()],
        1,
    );
    assert_eq!(
        fs::read_to_string(malformed.join(".claude.json")).unwrap(),
        "{"
    );
    assert!(!malformed.join(".claude.json.lock").exists());
    let short = fixture(&root, "short-key");
    fs::write(short.join("desk/.secret/deepseek/api-key"), "short").unwrap();
    record(
        &mut rows,
        "short key, trust committed first",
        &short,
        &bin,
        &["deepseek".into(), seat.clone()],
        1,
    );
    let partial: Value =
        serde_json::from_slice(&fs::read(short.join(".claude.json")).unwrap()).unwrap();
    assert_eq!(partial["projects"][&seat]["hasTrustDialogAccepted"], true);
    let locked = fixture(&root, "locked");
    fs::create_dir(locked.join(".claude.json.lock")).unwrap();
    record(
        &mut rows,
        "five second lock refusal",
        &locked,
        &bin,
        &["claude".into(), seat.clone()],
        1,
    );
    assert!(locked.join(".claude.json.lock").is_dir());
    let codex = fixture(&root, "codex-refusals");
    record(
        &mut rows,
        "codex seed before refusals",
        &codex,
        &bin,
        &["codex".into(), seat.clone()],
        0,
    );
    let panel = codex.join(".local/state/codex-panel-home");
    fs::write(panel.join("AGENTS.md"), "fixture only").unwrap();
    record(
        &mut rows,
        "global instructions refusal",
        &codex,
        &bin,
        &["codex".into(), seat.clone()],
        1,
    );
    fs::remove_file(panel.join("AGENTS.md")).unwrap();
    fs::remove_file(panel.join("auth.json")).unwrap();
    fs::write(panel.join("auth.json"), "fixture only").unwrap();
    record(
        &mut rows,
        "real auth file refusal",
        &codex,
        &bin,
        &["codex".into(), seat.clone()],
        1,
    );
    fs::remove_file(panel.join("auth.json")).unwrap();
    symlink(codex.join("wrong-auth"), panel.join("auth.json")).unwrap();
    record(
        &mut rows,
        "wrong auth link refusal",
        &codex,
        &bin,
        &["codex".into(), seat.clone()],
        1,
    );
    let mut dispatch = Vec::new();
    for (phase, expected) in [
        ("--help", 0),
        ("prepare", 2),
        ("launch", 2),
        ("own", 2),
        ("wait", 2),
        ("collect", 2),
        ("retain", 2),
        ("verify", 2),
        ("cleanup", 2),
    ] {
        let output = Command::new("panel-dispatch")
            .arg(phase)
            .env(
                "PATH",
                format!(
                    "{}:{}",
                    bin.display(),
                    std::env::var("PATH").unwrap_or_default()
                ),
            )
            .output()
            .unwrap();
        dispatch.push(json!({"argv":[phase], "expected_exit":expected, "actual_exit":output.status.code(),
            "stderr":String::from_utf8_lossy(&output.stderr), "status":"DIVERGENCE: surface absent from base and candidate"}));
    }
    let result = json!({"status":"PASS for baseline trust only","lane_verdict":"NO-GO","scope":"worktree a8ee75c trust helper; live isolation additions and dispatcher are unported",
        "caller":observed.trim(),"borrowed_seat_read_only":seat,"installed_candidate":candidate,
        "candidate_sha256":format!("{:x}",Sha256::digest(fs::read(&candidate).unwrap())),
        "caller_env": std::env::vars().filter(|(key,_)| key == "TMUX" || key == "TMUX_PANE" || key.starts_with("CC_MSG_") || key.starts_with("CODEX_SEND_") || key.starts_with("AGY_SEND_")).collect::<std::collections::BTreeMap<_,_>>(),
        "parity":rows,"dispatch_divergences":dispatch});
    let report = evidence.join("plain-parity.json");
    fs::write(&report, serde_json::to_vec_pretty(&result).unwrap()).unwrap();
    fs::remove_dir_all(&root).unwrap();
    println!(
        "{} shapes passed; evidence {}",
        result["parity"].as_array().unwrap().len(),
        report.display()
    );
}
