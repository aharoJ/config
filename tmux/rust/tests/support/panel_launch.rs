use super::*;
use crate::panel_schema::list;
#[test]
fn codex_wrapper_resolves_only_to_the_native_vendor_image() {
    let root = home().unwrap().join("desk/tmp").join(format!(
        "panel-native-{}",
        crate::runtime::fresh_id().unwrap()
    ));
    let (package, target) = match std::env::consts::ARCH {
        "aarch64" => ("codex-darwin-arm64", "aarch64-apple-darwin"),
        "x86_64" => ("codex-darwin-x64", "x86_64-apple-darwin"),
        other => panic!("unsupported fixture architecture: {other}"),
    };
    for (index, layout) in [
        format!("node_modules/@openai/{package}/vendor/{target}/bin/codex"),
        format!("vendor/{target}/bin/codex"),
    ]
    .iter()
    .enumerate()
    {
        let install = root
            .join(index.to_string())
            .join("node_modules/@openai/codex");
        let wrapper = install.join("bin/codex.js");
        fs::create_dir_all(wrapper.parent().unwrap()).unwrap();
        fs::write(
            &wrapper,
            "#!/usr/bin/env node\nthrow new Error('wrapper must never execute');\n",
        )
        .unwrap();
        fs::set_permissions(&wrapper, fs::Permissions::from_mode(0o755)).unwrap();
        let entry = root.join(format!("codex-{index}"));
        std::os::unix::fs::symlink(&wrapper, &entry).unwrap();
        let native = install.join(layout);
        fs::create_dir_all(native.parent().unwrap()).unwrap();
        fs::hard_link(std::env::current_exe().unwrap(), &native).unwrap();
        assert_eq!(
            native_codex(&entry).unwrap(),
            fs::canonicalize(&native).unwrap()
        );
        assert_eq!(
            native_codex(&native).unwrap(),
            fs::canonicalize(&native).unwrap()
        );
        fs::rename(&native, native.with_file_name("native-saved")).unwrap();
        fs::write(
            &native,
            "#!/usr/bin/env node\nthrow new Error('not a native image');\n",
        )
        .unwrap();
        fs::set_permissions(&native, fs::Permissions::from_mode(0o755)).unwrap();
        assert!(native_codex(&entry)
            .unwrap_err()
            .contains("Mach-O executable required"));
        fs::rename(&native, native.with_file_name("script-saved")).unwrap();
        assert!(native_codex(&entry).unwrap_err().contains("not found"));
    }
    assert!(native_codex(&std::env::current_exe().unwrap())
        .unwrap_err()
        .contains("unrecognized Codex install path"));
    assert!(Command::new("/usr/bin/trash")
        .arg(root)
        .status()
        .unwrap()
        .success());
}
#[test]
#[ignore = "read-only installed Codex native resolution; launches no client"]
fn installed_codex_native_resolution() {
    let program = executable("codex").unwrap();
    assert!(crate::model_identity::native_codex_path(&program));
    assert_eq!(native_codex(&program).unwrap(), program);
    println!("native Codex program: {}", program.display());
}
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
