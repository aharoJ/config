use super::*;
use std::cell::{Cell, RefCell};

fn screen(operator: &str, answer: &str, model: &str) -> String {
    format!("› {operator}\n{answer}\n› Ask Codex to do anything\n\nFast off · {model}\n")
}
fn monitor(text: &str, ack: bool, patterns: &str) -> Monitor {
    Monitor::new(
        &extract(text, 59),
        ack,
        3,
        60,
        1800,
        hot_patterns(patterns).unwrap(),
        0,
    )
}
fn observe(
    g: &mut Geometry,
    m: &mut Monitor,
    before: usize,
    after: usize,
    text: &str,
    now: u64,
) -> (Vec<String>, Option<i32>) {
    let mut heights = [before, after].into_iter();
    g.observe(
        m,
        &mut || Ok(heights.next().unwrap()),
        &mut || Ok(text.into()),
        now,
    )
}
fn alarm(rows: &[String]) -> bool {
    rows.iter()
        .any(|s| s.contains("PANE RESPONSE MAY BE NEEDED"))
}

#[test]
fn startup_retries_races_without_poisoning_the_baseline() {
    let stale = screen("old", "FAILED stale", "stale");
    let valid = screen("new", "done", "baseline");
    let mut heights = [59, 59, 10, 10, 10].into_iter();
    let mut captures = [stale, valid.clone()].into_iter();
    let mut pauses = 0;
    let (height, frame) = preflight(
        &mut || Ok(heights.next().unwrap()),
        &mut || Ok(captures.next().unwrap()),
        || pauses += 1,
    )
    .unwrap();
    assert_eq!((height, pauses), (10, 1));
    assert_eq!(frame.model, "Fast off, baseline");
    assert_eq!(frame.op, "› new");
    let mut m = Monitor::new(&frame, true, 3, 60, 1800, hot_patterns(HOT).unwrap(), 0);
    let mut g = Geometry::new(height);
    for now in [3, 6, 9] {
        let (rows, code) = observe(&mut g, &mut m, height, height, &valid, now);
        assert_eq!(code, None);
        assert!(rows.is_empty(), "{rows:?}");
    }
}

#[test]
fn startup_churn_stops_after_three_captures_and_two_pauses() {
    let mut heights = [59, 59, 10, 10, 59, 59, 10].into_iter();
    let captures = Cell::new(0);
    let mut pauses = 0;
    let result = preflight(
        &mut || Ok(heights.next().unwrap()),
        &mut || {
            captures.set(captures.get() + 1);
            Ok(screen("request", "done", "fixture"))
        },
        || pauses += 1,
    );
    assert_eq!(result.unwrap_err(), "pane geometry will not hold still");
    assert_eq!((captures.get(), pauses), (3, 2));
    assert_eq!(heights.next(), None);
}

#[test]
fn startup_request_failures_refuse_before_monitoring() {
    for failure in 0..4 {
        let calls = RefCell::new(Vec::new());
        let next = || -> Result<()> {
            let mut calls = calls.borrow_mut();
            let index = calls.len();
            calls.push(index);
            if index == failure {
                Err("request failed".into())
            } else {
                Ok(())
            }
        };
        let result = preflight(
            &mut || {
                next()?;
                Ok(59)
            },
            &mut || {
                next()?;
                Ok(screen("a", "done", "model"))
            },
            || panic!("no retry after request failure"),
        );
        assert_eq!(result.unwrap_err(), "request failed");
        assert_eq!(calls.borrow().len(), failure + 1);
    }
}

#[test]
fn torn_capture_discards_model_hot_turn_and_coverage_side_effects() {
    let valid = screen("a", "done", "baseline");
    let poison = screen("b", "FAILED poisoned?", "wrong");
    let mut m = monitor(&valid, true, HOT);
    let mut g = Geometry::new(59);
    m.idle = 1;
    m.static_run = 2;
    m.unknowns = 2;
    let sig = m.last_sig.clone();
    let (rows, code) = observe(&mut g, &mut m, 59, 10, &poison, 3);
    assert_eq!(code, None);
    assert_eq!(rows.len(), 1);
    assert!(rows[0].contains("discarding this observation"));
    assert_eq!(m.base_model, "Fast off, baseline");
    assert_eq!(m.last_sig, sig);
    assert_eq!(m.ack, sig);
    assert_eq!(m.unknowns, 2);
    assert!(m.hot_seen.is_empty());
    assert_eq!((m.idle, m.static_run), (0, 0));
    assert!(m.prev_win.is_empty());
    assert!(g.reseed);
    assert_eq!(g.height, 10);
    assert!(observe(&mut g, &mut m, 10, 10, &valid, 6).0.is_empty());
}

#[test]
fn stable_resize_resets_idle_and_static_motion_before_processing() {
    let valid = screen("a", "answer", "model");
    let mut m = monitor(&valid, false, HOT);
    let mut g = Geometry::new(59);
    assert!(!alarm(&observe(&mut g, &mut m, 59, 59, &valid, 3).0));
    let rows = observe(&mut g, &mut m, 10, 10, &valid, 6).0;
    assert!(!alarm(&rows));
    assert!(rows[0].contains("59r -> 10r"));
    assert_eq!((m.idle, m.static_run), (1, 0));
    assert!(alarm(&observe(&mut g, &mut m, 10, 10, &valid, 9).0));
    let busy = screen("a", "Working (1s · esc to interrupt)", "model");
    let mut m = monitor(&busy, false, HOT);
    let mut g = Geometry::new(59);
    observe(&mut g, &mut m, 59, 59, &busy, 3);
    observe(&mut g, &mut m, 59, 59, &busy, 6);
    let rows = observe(&mut g, &mut m, 10, 10, &busy, 9).0;
    assert!(!rows.iter().any(|s| s.contains("disbelieving")));
    assert_eq!(m.static_run, 0);
}

#[test]
fn resize_ack_reseeds_after_unknown_and_modal_then_activity_spends_it() {
    let valid = screen("a", "done", "model");
    let cropped = "done\n› Ask Codex to do anything\n\nFast off · model\n";
    let mut m = monitor(&valid, true, HOT);
    let original = m.ack.clone();
    let mut g = Geometry::new(59);
    observe(&mut g, &mut m, 59, 10, "invalid", 3);
    observe(&mut g, &mut m, 10, 10, "invalid", 6);
    assert!(g.reseed);
    assert_eq!(m.ack, original);
    let modal =
        "No action is required\n  › 1. Retry with a faster model\n2. Dismiss and keep waiting\n";
    observe(&mut g, &mut m, 10, 10, modal, 9);
    assert!(g.reseed);
    for now in [12, 15, 18] {
        assert!(!alarm(&observe(&mut g, &mut m, 10, 10, cropped, now).0));
    }
    assert!(!g.reseed);
    assert_ne!(m.ack, original);
    assert_eq!(m.ack, extract(cropped, 10).sig);
    let busy = screen("b", "Working (1s · esc to interrupt)", "model");
    observe(&mut g, &mut m, 10, 10, &busy, 21);
    assert!(m.ack.is_empty());
    observe(&mut g, &mut m, 10, 10, &valid, 24);
    assert!(alarm(&observe(&mut g, &mut m, 10, 10, &valid, 27).0));
}

#[test]
fn legacy_dynamic_resize_ack_fixture_runs_through_the_capture_pipeline() {
    let count = Cell::new(0usize);
    let mut height = || Ok(if count.get() >= 4 { 57 } else { 59 });
    let mut capture = || {
        count.set(count.get() + 1);
        Ok(super::tests::fixture("resize_ack", count.get().min(8)))
    };
    let (h, first) = preflight(&mut height, &mut capture, || panic!("stable startup")).unwrap();
    assert_eq!(first.state, "idle");
    let mut m = Monitor::new(&first, true, 0, 60, 1800, hot_patterns(HOT).unwrap(), 0);
    let mut g = Geometry::new(h);
    let mut rows = vec![];
    for _ in 0..16 {
        let (out, code) = g.observe(&mut m, &mut height, &mut capture, 0);
        rows.extend(out);
        assert_eq!(code, None);
    }
    assert!(count.get() > 8);
    assert!(rows.iter().any(|s| s.contains("59r -> 57r")));
    assert!(!alarm(&rows), "{rows:?}");
    assert!(!m.ack.is_empty());
}

#[test]
fn raw_physical_rows_bound_the_visible_region() {
    let stale = screen("old", "FAILED stale", "stale");
    let shell = format!("{stale}{}", "shell\n".repeat(10));
    assert_eq!(extract(&shell, 10).state, "unknown");
    assert_eq!(extract(&shell, 59).state, "idle");
    for blank in ["\n", " \n", "\t\n"] {
        let raw = format!("{stale}{}", blank.repeat(10));
        assert_eq!(extract(&raw, 10).state, "unknown");
    }
    let wrapped = "› request\nanswer\n› Ask Codex to do\nanything\n\nFast off · model\n";
    assert_eq!(extract(wrapped, 10).state, "unknown");
    assert_eq!(extract(&screen("a", "done", "model"), 0).state, "unknown");
}

#[test]
fn malformed_geometry_is_a_request_failure_and_changed_identity_loses_coverage() {
    assert_eq!(
        parse_height("%13:59:999:100", "%13", "999", "100").unwrap(),
        59
    );
    for row in [
        "",
        "%13:bad:999:100",
        "%13:59::100",
        "x:59:999:100",
        "%13:59:999:100:extra",
        "%13:-1:999:100",
    ] {
        assert_eq!(
            parse_height(row, "%13", "999", "100").unwrap_err(),
            "invalid pane geometry",
            "{row}"
        );
    }
    for row in ["%99:59:999:100", "%13:59:998:100", "%13:59:999:101"] {
        let valid = screen("a", "done", "model");
        let mut m = monitor(&valid, true, HOT);
        let mut g = Geometry::new(59);
        let (_, code) = g.observe(
            &mut m,
            &mut || parse_height(row, "%13", "999", "100"),
            &mut || panic!("identity changed before capture"),
            3,
        );
        assert_eq!(code, Some(2), "{row}");
    }
}

#[test]
fn failed_geometry_and_capture_requests_obey_the_live_failure_counter() {
    let valid = screen("a", "done", "model");
    for before in [true, false] {
        let mut m = monitor(&valid, false, HOT);
        let mut g = Geometry::new(59);
        m.idle = 1;
        m.static_run = 2;
        for attempt in 1..=5 {
            let (_, code) = if before {
                g.observe(
                    &mut m,
                    &mut || Err("request failed".into()),
                    &mut || panic!("failed before capture"),
                    3,
                )
            } else {
                g.observe(
                    &mut m,
                    &mut || Ok(59),
                    &mut || Err("request failed".into()),
                    3,
                )
            };
            assert_eq!(code, if attempt == 5 { Some(3) } else { None });
            assert_eq!((m.idle, m.static_run), (0, 0));
        }
    }
    let mut m = monitor(&valid, true, HOT);
    let mut g = Geometry::new(59);
    for _ in 0..8 {
        let mut calls = 0;
        let (_, code) = g.observe(
            &mut m,
            &mut || {
                calls += 1;
                if calls == 1 {
                    Ok(59)
                } else {
                    Err("post-capture failure".into())
                }
            },
            &mut || Ok(valid.clone()),
            3,
        );
        assert_eq!(code, None);
        assert_eq!(g.failures, 1);
    }
    observe(&mut g, &mut m, 59, 59, &valid, 6);
    assert_eq!(g.failures, 0);
    for after in [false, true] {
        let mut calls = 0;
        let (_, code) = g.observe(
            &mut m,
            &mut || {
                calls += 1;
                if after && calls == 1 {
                    Ok(59)
                } else {
                    Err("tmux request timed out".into())
                }
            },
            &mut || Ok(valid.clone()),
            9,
        );
        assert_eq!(code, Some(3));
    }
    let (_, code) = g.observe(
        &mut m,
        &mut || Ok(59),
        &mut || Err("tmux request timed out".into()),
        12,
    );
    assert_eq!(code, Some(3));
}

#[test]
fn hot_pattern_files_preserve_extended_regexes_and_reject_bad_or_empty_input() {
    for raw in ["", " \n\t\n", "[", "ok\n(", "\0"] {
        assert!(hot_patterns(raw).is_err(), "{raw:?}");
    }
    let pats = hot_patterns("\n \n^ALERT [[:digit:]]+$\n- FAILED.*\n").unwrap();
    assert_eq!(pats.len(), 2);
    assert_eq!(last_match(&pats, "ALERT 123"), Some("ALERT 123".into()));
    assert_eq!(
        last_match(&pats, "- FAILED same"),
        Some("- FAILED same".into())
    );
    assert_eq!(last_match(&pats, "x ALERT 123"), None);
    let pats = hot_patterns("abc\r\n").unwrap();
    assert_eq!(last_match(&pats, "abc"), None);
    assert_eq!(last_match(&pats, "abc\r"), Some("abc\r".into()));
}

#[test]
fn custom_hot_uses_leftmost_longest_nonoverlapping_matches_across_patterns() {
    for (patterns, text, expected) in [
        ("omega\nalpha", "alpha omega", Some("omega")),
        ("alpha\nomega", "alpha omega", Some("omega")),
        ("abcd\nbc", "abcd", Some("abcd")),
        ("bc\nabcd", "abcd", Some("abcd")),
        ("a\nab", "ab", Some("ab")),
        ("ab\na", "ab", Some("ab")),
        ("^a", "aaa", Some("a")),
        ("^|$", "abc", None),
        ("a*", "baa", Some("aa")),
        ("x*\nomega", "alpha omega", Some("omega")),
        ("FAILED|REFUSE", "FAILED then REFUSE", Some("REFUSE")),
        (".", "é", Some("é")),
        ("[[:alpha:]]+", "résumé", Some("résumé")),
    ] {
        assert_eq!(
            last_match(&hot_patterns(patterns).unwrap(), text).as_deref(),
            expected,
            "{patterns:?}: {text}"
        );
    }
}

#[test]
fn custom_hot_uses_the_last_matching_row_and_deduplicates_per_operator_turn() {
    let initial = screen("a", "waiting", "model");
    let mut m = monitor(&initial, true, "omega\nalpha\n- FAILED.*");
    let mut hot = vec![];
    for (op, body) in [
        ("a", "alpha omega"),
        ("a", "alpha omega\n- FAILED repeated"),
        ("a", "alpha omega\n- FAILED repeated"),
        ("a", "alpha omega"),
        ("a", "quiet"),
        ("a", "- FAILED repeated"),
        ("b", "- FAILED repeated"),
    ] {
        let rows = m.step(extract(&screen(op, body, "model"), 59), 0).0;
        hot.extend(rows.into_iter().filter(|s| s.starts_with("HOT:")));
    }
    assert_eq!(
        hot,
        [
            "HOT: omega",
            "HOT: - FAILED repeated",
            "HOT: - FAILED repeated"
        ]
    );
}

#[test]
fn custom_hot_replaces_defaults_without_changing_ack_state_or_exit() {
    let initial = screen("a", "FAILED", "model");
    let mut with_hot = monitor(&initial, true, "omega");
    let mut without_hot = monitor(&initial, true, "NEVER_MATCH");
    let mut hot_count = 0;
    for text in [
        initial.clone(),
        screen("a", "omega", "model"),
        "unknown".into(),
        screen("b", "Working (1s)", "model"),
        screen("b", "done", "model"),
        screen("b", "done", "model"),
        "unknown".into(),
        "unknown".into(),
        "unknown".into(),
        "unknown".into(),
    ] {
        let (mut rows, code) = with_hot.step(extract(&text, 59), 3);
        hot_count += rows.iter().filter(|s| s.starts_with("HOT:")).count();
        rows.retain(|s| !s.starts_with("HOT:"));
        let expected = without_hot.step(extract(&text, 59), 3);
        assert_eq!((rows, code), expected);
        assert_eq!(with_hot.ack, without_hot.ack);
        assert_eq!(with_hot.unknowns, without_hot.unknowns);
    }
    assert_eq!(hot_count, 1);
}
