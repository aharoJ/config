use super::*;
use crate::panel_schema::list;
#[test]
fn trimmed_live_capture_misaligns_actual_tmux_cursor_row() {
    let raw = include_str!("../fixtures/panel-codex-idle.ansi");
    let meta = include_str!("../fixtures/panel-codex-idle.meta").trim();
    let fields = meta.split('|').collect::<Vec<_>>();
    let x = fields[0].parse().unwrap();
    let y = fields[1].parse().unwrap();
    let width = fields[2].parse().unwrap();
    assert_eq!(
        crate::composer::screen('›', raw, x, y, width, ""),
        crate::composer::Screen::Empty
    );
    assert_ne!(
        crate::composer::screen('›', raw.trim(), x, y, width, ""),
        crate::composer::Screen::Empty
    );
    println!("F11 actual tmux metadata {meta}: raw empty=true, stripped empty=false");
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
