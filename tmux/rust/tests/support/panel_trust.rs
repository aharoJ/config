use super::*;

struct Home(PathBuf);

impl Home {
    fn new() -> Self {
        let root = crate::identity::account_home()
            .unwrap()
            .join("desk/tmp")
            .join(format!(
                "panel-trust-{}",
                crate::runtime::fresh_id().unwrap()
            ));
        fs::create_dir(&root).unwrap();
        fs::create_dir_all(root.join(".gemini/antigravity-cli")).unwrap();
        fs::write(root.join(".gemini/antigravity-cli/settings.json"), "{}").unwrap();
        fs::write(root.join(".claude.json"), "{}").unwrap();
        Self(root)
    }
}

impl Drop for Home {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

fn paths() -> [String; 2] {
    [
        "/fixtures/panel-physical-seat".into(),
        "/fixtures/panel-logical-seat".into(),
    ]
}

#[test]
fn exact_seat_grammar() {
    for suffix in [
        "fixture-audit-r1-agentic-test-cli",
        "a._-audit-r000-agentic-._-cli",
        "a-audit-rx-audit-r2-agentic-b-cli",
    ] {
        let name = format!("/private/tmp/review-protocol-{suffix}");
        assert!(seat_name(&name), "{name}");
    }
    assert!(!seat_name("/fixtures/panel-physical-seat"));
    for suffix in [
        "-audit-r1-agentic-test-cli",
        "a-audit-r-agentic-test-cli",
        "a-audit-r1-agentic--cli",
        "a-audit-r1-agentic-test-cli/child",
        "a-audit-r1-agentic-test-cli\n",
        "a-audit-r1-agentic-tést-cli",
    ] {
        let name = format!("/private/tmp/review-protocol-{suffix}");
        assert!(!seat_name(&name), "{name}");
    }
}

#[test]
fn relative_and_unrelated_directories_refuse() {
    let home = Home::new();
    assert_eq!(
        seat_paths("relative").unwrap_err(),
        "seat path must be absolute"
    );
    assert!(seat_paths(home.0.to_str().unwrap())
        .unwrap_err()
        .contains("not an agentic audit seat"));
}

#[test]
fn claude_preserves_unrelated_state_and_file_mode() {
    let home = Home::new();
    let config = home.0.join(".claude.json");
    fs::write(
        &config,
        r#"{"projects":{"unrelated":{"hasTrustDialogAccepted":false}},"other":42}"#,
    )
    .unwrap();
    fs::set_permissions(&config, fs::Permissions::from_mode(0o640)).unwrap();
    trust_claude(&home.0, &paths()).unwrap();
    let value = read_json(&config).unwrap();
    assert_eq!(value["other"], 42);
    assert_eq!(
        value["projects"]["unrelated"]["hasTrustDialogAccepted"],
        false
    );
    for path in paths() {
        assert_eq!(value["projects"][path]["hasTrustDialogAccepted"], true);
    }
    assert_eq!(fs::metadata(&config).unwrap().mode() & 0o777, 0o640);
    assert!(!home.0.join(".claude.json.lock").exists());
}

#[test]
fn already_trusted_configs_are_not_rewritten() {
    let home = Home::new();
    for (kind, path) in [
        ("claude", home.0.join(".claude.json")),
        ("agy", home.0.join(".gemini/antigravity-cli/settings.json")),
        (
            "codex",
            home.0.join(".local/state/codex-panel-home/config.toml"),
        ),
    ] {
        trust(kind, &home.0, &paths()).unwrap();
        let before = fs::metadata(&path).unwrap().ino();
        let bytes = fs::read(&path).unwrap();
        trust(kind, &home.0, &paths()).unwrap();
        assert_eq!(fs::metadata(&path).unwrap().ino(), before, "{kind}");
        assert_eq!(fs::read(&path).unwrap(), bytes, "{kind}");
    }
}

#[test]
fn deepseek_approves_tail_and_removes_all_rejections() {
    let home = Home::new();
    fs::create_dir_all(home.0.join("desk/.secret/deepseek")).unwrap();
    fs::write(
        home.0.join("desk/.secret/deepseek/api-key"),
        "  fixture-01234567890123456789\n",
    )
    .unwrap();
    fs::write(home.0.join(".claude.json"), r#"{"customApiKeyResponses":{"approved":["other"],"rejected":["01234567890123456789","other","01234567890123456789"]}}"#).unwrap();
    trust_deepseek(&home.0, &paths()).unwrap();
    let value = read_json(&home.0.join(".claude.json")).unwrap();
    assert_eq!(
        value["customApiKeyResponses"]["approved"],
        serde_json::json!(["other", "01234567890123456789"])
    );
    assert_eq!(
        value["customApiKeyResponses"]["rejected"],
        serde_json::json!(["other"])
    );
    trust_deepseek(&home.0, &paths()).unwrap();
    assert_eq!(read_json(&home.0.join(".claude.json")).unwrap(), value);
}

#[test]
fn short_deepseek_key_keeps_the_original_partial_trust_order() {
    let home = Home::new();
    fs::create_dir_all(home.0.join("desk/.secret/deepseek")).unwrap();
    fs::write(home.0.join("desk/.secret/deepseek/api-key"), "short").unwrap();
    assert_eq!(
        trust_deepseek(&home.0, &paths()).unwrap_err(),
        "DeepSeek key is missing or too short"
    );
    assert_eq!(
        read_json(&home.0.join(".claude.json")).unwrap()["projects"][&paths()[0]]
            ["hasTrustDialogAccepted"],
        true
    );
}

#[test]
fn agy_extends_only_missing_workspaces() {
    let home = Home::new();
    let config = home.0.join(".gemini/antigravity-cli/settings.json");
    fs::write(
        &config,
        serde_json::json!({"trustedWorkspaces": ["other", paths()[0]], "theme":"dark"}).to_string(),
    )
    .unwrap();
    trust_agy(&home.0, &paths()).unwrap();
    let value = read_json(&config).unwrap();
    assert_eq!(
        value["trustedWorkspaces"],
        serde_json::json!(["other", paths()[0], paths()[1]])
    );
    assert_eq!(value["theme"], "dark");
}

#[test]
fn codex_seeds_the_original_clean_home() {
    let home = Home::new();
    trust_codex(&home.0, &paths()).unwrap();
    let panel = home.0.join(".local/state/codex-panel-home");
    assert_eq!(fs::metadata(&panel).unwrap().mode() & 0o777, 0o700);
    assert_eq!(
        fs::read_link(panel.join("auth.json")).unwrap(),
        home.0.join(".codex/auth.json")
    );
    assert_eq!(
        fs::metadata(panel.join("config.toml")).unwrap().mode() & 0o777,
        0o600
    );
    let text = fs::read_to_string(panel.join("config.toml")).unwrap();
    assert!(text.starts_with(CODEX_CONFIG));
    let config: toml::Table = toml::from_str(&text).unwrap();
    for path in paths() {
        assert_eq!(
            config["projects"][path]["trust_level"].as_str(),
            Some("trusted")
        );
    }
}

#[test]
fn codex_preserves_custom_config_and_requires_boolean_false() {
    let home = Home::new();
    let config = seed_codex_home(&home.0).unwrap();
    let custom = CODEX_CONFIG.replace("gpt-5.6-terra", "chosen-model");
    fs::write(&config, &custom).unwrap();
    trust_codex(&home.0, &paths()).unwrap();
    assert!(fs::read_to_string(&config).unwrap().starts_with(&custom));
    for entry in ["plugins = true", "plugins = 0", "plugins = \"false\""] {
        fs::write(&config, CODEX_CONFIG.replace("plugins = false", entry)).unwrap();
        assert!(trust_codex(&home.0, &paths())
            .unwrap_err()
            .contains("[features] plugins = false"));
    }
}

#[test]
fn codex_conflicting_entry_and_invalid_toml_are_not_rewritten() {
    let home = Home::new();
    let config = seed_codex_home(&home.0).unwrap();
    let conflict = format!(
        "{CODEX_CONFIG}\n[projects.\"{}\"]\ntrust_level = \"untrusted\"\n",
        paths()[0]
    );
    fs::write(&config, &conflict).unwrap();
    assert!(trust_codex(&home.0, &paths())
        .unwrap_err()
        .contains("already has a non-trusted entry"));
    assert_eq!(fs::read_to_string(&config).unwrap(), conflict);
    fs::write(&config, "[broken").unwrap();
    assert!(trust_codex(&home.0, &paths()).is_err());
    assert_eq!(fs::read_to_string(&config).unwrap(), "[broken");
    assert!(!config.with_file_name("config.toml.lock").exists());
}

#[test]
fn codex_refuses_real_auth_file_wrong_link_and_global_instructions() {
    let home = Home::new();
    let panel = home.0.join(".local/state/codex-panel-home");
    fs::create_dir_all(&panel).unwrap();
    let auth = panel.join("auth.json");
    fs::write(&auth, "shared-login-must-not-diverge").unwrap();
    assert!(seed_codex_home(&home.0).unwrap_err().contains("real file"));
    fs::remove_file(&auth).unwrap();
    symlink(home.0.join("other"), &auth).unwrap();
    assert!(seed_codex_home(&home.0)
        .unwrap_err()
        .contains("does not link"));
    fs::remove_file(&auth).unwrap();
    symlink(home.0.join(".codex/auth.json"), &auth).unwrap();
    fs::write(panel.join("AGENTS.md"), "ambient context").unwrap();
    assert!(seed_codex_home(&home.0)
        .unwrap_err()
        .contains("no global instructions"));
}

#[test]
fn malformed_json_and_structures_release_lock_without_rewriting() {
    let home = Home::new();
    let config = home.0.join(".claude.json");
    for text in [
        "{".to_owned(),
        "null".into(),
        r#"{"projects":[]}"#.into(),
        serde_json::json!({"projects":{&paths()[0]:null}}).to_string(),
    ] {
        fs::write(&config, &text).unwrap();
        assert!(trust_claude(&home.0, &paths()).is_err());
        assert_eq!(fs::read_to_string(&config).unwrap(), text);
        assert!(!home.0.join(".claude.json.lock").exists());
    }
}

#[test]
fn atomic_writer_refuses_a_collision_without_replacing_config() {
    let home = Home::new();
    let config = home.0.join("config");
    let temp = home
        .0
        .join(format!(".config.panel-seat-trust.{}", std::process::id()));
    fs::write(&config, "old").unwrap();
    fs::write(&temp, "occupied").unwrap();
    assert!(write_atomic(&config, "new", 0o600).is_err());
    assert_eq!(fs::read_to_string(config).unwrap(), "old");
    assert_eq!(fs::read_to_string(temp).unwrap(), "occupied");
}

#[test]
fn lock_serializes_then_releases_on_error_paths() {
    let home = Home::new();
    let config = home.0.join(".claude.json");
    let first = DirLock::acquire(&config).unwrap();
    let other = config.clone();
    let thread = std::thread::spawn(move || DirLock::acquire(&other).unwrap());
    std::thread::sleep(Duration::from_millis(60));
    assert!(!thread.is_finished());
    drop(first);
    drop(thread.join().unwrap());
    assert!(!home.0.join(".claude.json.lock").exists());
}
