use super::*;
use crate::panel_schema::list;
#[test]
fn real_native_composer_readiness_refuses_drafts_modes_and_wrong_geometry() {
    let capture = include_str!("../fixtures/panel-codex-idle.ansi");
    let y = capture
        .lines()
        .position(|line| {
            crate::composer::row(line).is_ok_and(|r| r.text.trim_start().starts_with('›'))
        })
        .unwrap();
    let meta = format!("2|{y}|215|50|0|0|%1");
    assert!(empty(&meta, capture, '›'));
    assert!(!empty(&format!("2|{y}|215|50|0|1|%1"), capture, '›'));
    assert!(!empty("2|49|215|50|0|0|%1", capture, '›'));
    let draft = capture
        .lines()
        .enumerate()
        .map(|(i, line)| {
            if i == y {
                "› actual draft\n".to_owned()
            } else {
                format!("{line}\n")
            }
        })
        .collect::<String>();
    assert!(!empty(&meta, &draft, '›'));
}
#[test]
fn codex_seat_preserves_policy_and_native_config_arguments() {
    let seat = json!({"transport":"astra","directory":"/fixtures/seat","model":"gpt-6-sol","effort":"low"});
    let p = profile(&seat, Path::new("/fixtures/operator")).unwrap();
    assert_eq!(p["command"], "codex");
    assert_eq!(
        p["env"]["CODEX_HOME"],
        "/fixtures/operator/.local/state/codex-panel-home"
    );
    assert_eq!(p["env"]["TMPDIR"], "/fixtures/seat/scratch");
    assert_eq!(p["args"],json!(["--no-daemon","--strict-config","-m","gpt-6-sol","-c","model_reasoning_effort=low","-a","never","-c","default_permissions=\"panel-seat\"","-c","permissions.panel-seat.filesystem={\":root\"=\"deny\",\":minimal\"=\"read\",\":slash_tmp\"=\"deny\",\":workspace_roots\"=\"write\"}","-c","permissions.panel-seat.network.enabled=false"]));
}
#[test]
fn agy_seat_preserves_model_effort_and_sandbox() {
    let p = profile(
        &json!({"transport":"gemini","directory":"/fixtures/seat","model":"gemini","effort":"low"}),
        Path::new("/fixtures/operator"),
    )
    .unwrap();
    assert_eq!(p["command"], "agy");
    assert_eq!(p["trust"], "agy");
    assert_eq!(
        p["args"],
        json!([
            "--dangerously-skip-permissions",
            "--model",
            "gemini",
            "--effort",
            "low",
            "--sandbox"
        ])
    );
}
#[test]
fn provider_seats_preserve_sandbox_and_distinct_launchers() {
    let root = home().unwrap().join("desk/tmp").join(format!(
        "p3x-launch-{}",
        crate::runtime::fresh_id().unwrap()
    ));
    fs::create_dir(&root).unwrap();
    for kind in ["fable", "deepseek"] {
        let seat =
            json!({"transport":kind,"directory":root,"model":"fixture-model","effort":"low"});
        let p = profile(&seat, Path::new("/fixtures/operator")).unwrap();
        assert_eq!(p["env"]["TMPDIR"], p["env"]["CLAUDE_CODE_TMPDIR"]);
        assert!(p["env"]["TMPDIR"]
            .as_str()
            .unwrap()
            .starts_with("/private/tmp/panel-"));
        assert_eq!(p["args"][0], "--model");
        assert!(list(&p["args"]).contains(&json!("dontAsk")));
        if kind == "fable" {
            assert_eq!(p["command"], "claude");
            assert!(list(&p["args"]).contains(&json!("--safe-mode")));
        } else {
            assert!(p["command"]
                .as_str()
                .unwrap()
                .ends_with("/.local/cc-pinned-2.1.153/node_modules/.bin/claude"));
            assert!(list(&p["args"]).contains(&json!("--bare")));
            assert_eq!(p["env"]["PANEL_SEAT_CONFINED"], "1");
        }
    }
    fs::remove_dir(root).unwrap();
}
