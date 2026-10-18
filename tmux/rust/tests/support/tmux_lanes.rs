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
    let missing = result(&lane).unwrap();
    assert!(!missing.done);
    assert_eq!(missing.size, None);
    let text = "quoted END #abc\nEND #abcd\nEND #abc extra\n";
    fs::write(&lane.result, text).unwrap();
    let incomplete = result(&lane).unwrap();
    assert!(!incomplete.done);
    assert_eq!(incomplete.size, Some(text.len() as u64));
    let text = format!("{text}END #abc\r\n");
    fs::write(&lane.result, &text).unwrap();
    let complete = result(&lane).unwrap();
    assert!(complete.done);
    assert_eq!(complete.size, Some(text.len() as u64));
    assert_eq!(
        complete.modified,
        Some(
            fs::metadata(&lane.result)
                .unwrap()
                .modified()
                .unwrap()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs()
        )
    );
    fs::remove_file(&lane.result).unwrap();
    fs::remove_dir(&root).unwrap();
}

#[test]
fn reload_keeps_the_last_valid_board_and_recovers_with_an_added_lane() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("target")
        .join(format!("lanes-reload-{}", std::process::id()));
    fs::create_dir(&root).unwrap();
    let path = root.join("lanes.toml");
    fs::write(&path, CONFIG).unwrap();
    let mut board = load(&path).unwrap();
    let with_footer = CONFIG.replace(
        "title = \"Lane board\"",
        "title = \"Reloaded board\"\nfooter = [\"Next: inspect\", \"Records: ./results\"]",
    );
    fs::write(&path, &with_footer).unwrap();
    assert_eq!(reload(&path, &mut board), None);
    assert_eq!(board.title, "Reloaded board");
    assert_eq!(board.footer, ["Next: inspect", "Records: ./results"]);
    fs::write(&path, "session = [").unwrap();
    let warning = reload(&path, &mut board).unwrap();
    assert_eq!(board.title, "Reloaded board");
    assert_eq!(board.lanes.len(), 1);
    assert!(render(&board, &[], 60, Some(warning), 1000)
        .contains("WARNING: config error; showing last valid board"));
    fs::remove_file(&path).unwrap();
    assert!(reload(&path, &mut board).is_some());
    let fixed = format!("{with_footer}\n[[lanes]]\nname = 'new'\nwindow = 'worker'\njob = 'New task'\nresult = 'new.md'\nend = '#new'\n");
    fs::write(&path, fixed).unwrap();
    assert_eq!(reload(&path, &mut board), None);
    assert_eq!(board.lanes.len(), 2);
    assert_eq!(board.lanes[1].result, root.join("new.md"));
    assert!(!render(&board, &[], 60, None, 1000).contains("WARNING"));
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn completed_rows_hide_the_pane_and_freeze_elapsed_at_the_result_write() {
    let board = parse(CONFIG, Path::new(".")).unwrap();
    let lane = &board.lanes[0];
    let row = |now, done, modified| {
        lane_row(
            lane,
            Ok(Some("Working (10m · esc to interrupt)".into())),
            Ok(ResultFile {
                done,
                size: Some(42),
                modified,
            }),
            now,
        )
    };
    assert_eq!(row(1010, false, Some(1005))[3], "0m10s");
    let done = row(1010, true, Some(1005));
    assert_eq!(done[1], "DONE");
    assert_eq!(done[3], "0m05s");
    assert_eq!(done[5], "result complete");
    assert_eq!(done, row(2000, true, Some(1005)));
    assert_eq!(row(1010, true, None)[3], "-");
    assert_eq!(row(1010, true, Some(999))[3], "-");
    assert_eq!(row(1010, true, Some(1011))[3], "-");
}

#[test]
fn footer_clock_and_layout_fit_wide_narrow_and_very_small_windows() {
    use unicode_width::UnicodeWidthStr;
    let text = CONFIG.replace(
        "title = \"Lane board\"",
        "title = \"Lane board\"\nfooter = [\"Next: inspect\", \"Records: ./results\"]",
    );
    let board = parse(&text, Path::new(".")).unwrap();
    let row = lane_row(
        &board.lanes[0],
        Ok(Some("Working (old)".into())),
        Ok(ResultFile {
            done: true,
            size: Some(42),
            modified: Some(1005),
        }),
        2000,
    );
    for width in [20, 39, 60, 72, 80, 120] {
        let frame = render(&board, std::slice::from_ref(&row), width, None, 2000);
        let text = frame.strip_prefix("\x1b[H\x1b[2J").unwrap();
        let unwrapped = text.replace('\n', "");
        assert!(
            text.lines().all(|line| line.width() <= width),
            "{width}: {text}"
        );
        for value in [
            "updated ",
            "DONE",
            "0m05s",
            "42",
            "result complete",
            "Next: inspect",
            "Records: ./results",
        ] {
            assert!(
                unwrapped.contains(value),
                "{width}: missing {value}: {text}"
            );
        }
        assert!(!text.contains("Working"));
        if width == 60 {
            assert!(text.lines().any(|line| line.contains("build")
                && line.contains("DONE")
                && line.contains("0m05s")
                && line.contains("42")));
            assert!(text.contains("  JOB: Build the tool"));
        }
    }
    let mut long_job = row;
    long_job[2] = "Build a long running task".into();
    let wide = render(&board, std::slice::from_ref(&long_job), 120, None, 2000);
    let narrow_job = render(&board, std::slice::from_ref(&long_job), 72, None, 2000);
    assert!(wide.contains(&long_job[2]));
    assert!(!narrow_job.contains(&long_job[2]));
    assert!(narrow_job.contains("result complete"));
    assert!(parse(
        &text.replace("Next: inspect", "Next:\\ninspect"),
        Path::new(".")
    )
    .is_err());
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
