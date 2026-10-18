use super::*;

const CONFIG: &str = r##"
session = "agent-session"
title = "Lane board"
[[lanes]]
name = "build"
window = "codex"
job = "Build the tool"
result = "RESULT.md"
end = "#abc"
started = 1000
"##;

#[test]
fn toml_requires_the_lane_fields_and_resolves_relative_paths() {
    let board = parse(CONFIG, Path::new("/evidence")).unwrap();
    assert_eq!(board.session, "agent-session");
    assert_eq!(board.lanes[0].result, Path::new("/evidence/RESULT.md"));
    assert_eq!(board.lanes[0].started, Some(1000));
    assert!(parse(&CONFIG.replace("name = \"build\"", ""), Path::new(".")).is_err());
    assert!(parse(
        &CONFIG.replace("started = 1000", "started = -1"),
        Path::new(".")
    )
    .is_err());
    assert!(parse(
        &CONFIG.replace("title = \"Lane board\"", "title = \"\""),
        Path::new(".")
    )
    .is_err());
    assert!(parse(&CONFIG.replace("job =", "typo ="), Path::new(".")).is_err());
    assert!(parse("session = 's'\ntitle = 't'\nlanes = []", Path::new(".")).is_err());
}

#[test]
fn state_separates_completion_activity_missing_and_failed_captures() {
    let running = Ok(Some("• Working (4s · esc to interrupt)".into()));
    let idle = Ok(Some("• Worked for 5m 11s\n› ".into()));
    assert_eq!(state(false, &running), "RUNNING");
    assert_eq!(state(false, &idle), "IDLE");
    assert_eq!(state(false, &Ok(Some("❯".into()))), "IDLE");
    assert_eq!(state(false, &Ok(None)), "MISSING");
    assert_eq!(state(false, &Err("timeout".into())), "ERROR");
    for pane in [running, idle, Ok(None), Err("timeout".into())] {
        assert_eq!(state(true, &pane), "DONE");
    }
    assert_eq!(
        activity("Working (old)\nWorked for 2s"),
        ("Worked for 2s", false)
    );
    assert_eq!(
        activity("Working (old · esc to interrupt)\nWorked for 2s"),
        ("Worked for 2s", false)
    );
    assert_eq!(activity("✻ Thinking… (esc to interrupt)"), ("", true));
}

#[test]
fn exact_window_lookup_does_not_accept_prefixes_or_other_sessions() {
    let rows = "agent-session\tcodex-extra\t%1\nother\tcodex\t%2\nagent-session\tcodex\t%3\nagent-session\tcodex\t%4\n";
    let windows = windows(rows, "agent-session");
    assert_eq!(windows["codex"], ["%3", "%4"]);
    assert_eq!(windows["codex-extra"], ["%1"]);
    assert!(!windows.contains_key("code"));
}

#[test]
fn result_needs_an_exact_end_line_and_preserves_missing_files() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("target")
        .join(format!("lanes-test-{}", std::process::id()));
    fs::create_dir(&root).unwrap();
    let lane = parse(CONFIG, &root).unwrap().lanes.remove(0);
    assert_eq!(result(&lane).unwrap(), (false, None));
    let text = "quoted END #abc\nEND #abcd\nEND #abc extra\n";
    fs::write(&lane.result, text).unwrap();
    assert_eq!(result(&lane).unwrap(), (false, Some(text.len() as u64)));
    let text = format!("{text}END #abc\r\n");
    fs::write(&lane.result, &text).unwrap();
    assert_eq!(result(&lane).unwrap(), (true, Some(text.len() as u64)));
    fs::remove_file(&lane.result).unwrap();
    fs::remove_dir(&root).unwrap();
}

#[test]
fn elapsed_and_cells_preserve_unknown_times_and_terminal_columns() {
    assert_eq!(elapsed(None, 100), "-");
    assert_eq!(elapsed(Some(101), 100), "-");
    assert_eq!(elapsed(Some(0), 65), "1m05s");
    assert_eq!(elapsed(Some(0), 3665), "1h01m");
    assert_eq!(cell("界a\nb", 3), "界a");
    assert_eq!(cell("界", 3), "界 ");
}
