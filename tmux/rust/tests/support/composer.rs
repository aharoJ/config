use super::*;
#[test]
fn captured_fresh_and_background_codex_acceptance() {
    for (capture, y, width, wire) in [
        (include_str!("../fixtures/codex-fresh-accepted.ansi"), 12, 149, "s15x-haiku-final (config-tt:s15x-haiku-final): #s15xfresh16 Reply ACK_S15X_FRESH16 only; no tools."),
        (include_str!("../fixtures/codex-background-accepted.ansi"), 47, 183, "s15x-haiku-final (config-tt:s15x-haiku-final): #s15xbgprobe16 Reply ACK_S15X_BG16 only; no tools."),
    ] {
        assert_eq!(classify(capture, '›', 2, y, width), Composer::EmptyCandidate);
        assert_eq!(receipt('›', capture, 2, y, width, wire).submitted, 1);
        for changed in [capture.replace(wire, &format!("{wire} suffix")), capture.replace("\x1b[1;2m› ", "\x1b[2m› ")] {
            assert_ne!(changed, capture);
            assert_eq!(receipt('›', &changed, 2, y, width, wire).submitted, 0);
        }
        assert_eq!(receipt('›', capture, 2, y, width, "unrelated").submitted, 0);
        assert!(ready('›', capture, 2, y, width));
        assert!(!ready('›', capture, 3, y, width));
        assert!(!ready('›', "", 0, 0, width));
    }
}
#[test]
fn codex_queue_uses_the_observed_background_ghost() {
    let old = include_str!("../fixtures/codex-busy-queued.ansi");
    let capture = old.replace("\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m", "\x1b[1m›\x1b[0m\x1b[48;2;57;57;71m \x1b[2mAsk Codex to do anything\x1b[0m\x1b[48;2;57;57;71m");
    let wire = "sol (config-tt:sol): #s11k9stable Reply ACK_S11K9_STABLE only; no tools.";
    assert_ne!(capture, old);
    assert_eq!(
        receipt('›', &capture, 2, 19, 180, wire),
        Receipt {
            submitted: 0,
            queued: 1,
            queue_prompt: true
        }
    );
    assert!(
        !receipt(
            '›',
            &capture.replace("57;57;71", "57;57;72"),
            2,
            19,
            180,
            wire
        )
        .queue_prompt
    );
}
#[test]
fn captured_claude_generating_queue_without_spinner_row() {
    let capture = include_str!("../fixtures/claude-generating-queued.ansi");
    let wire = "sol (config-tt:sol): #s15xgenreal16 Reply ACK_S15X_GEN_REAL16 only after your current answer; no tools.";
    assert_eq!(
        receipt('❯', capture, 2, 45, 183, wire),
        Receipt {
            submitted: 0,
            queued: 1,
            queue_prompt: true
        }
    );
    for changed in [
        capture.replace(wire, &format!("{wire} suffix")),
        capture.replace("ctrl+x ctrl+s to send now", "ctrl+x ctrl+s unknown"),
        capture.replace("messages", "drafts"),
        capture.replace("48;5;237", "48;5;238"),
    ] {
        assert_ne!(changed, capture);
        let receipt = receipt('❯', &changed, 2, 45, 183, wire);
        assert!(!receipt.queue_prompt || receipt.queued == 0);
    }
    assert!(!receipt('❯', capture, 3, 45, 183, wire).queue_prompt);
    assert_eq!(receipt('❯', capture, 2, 45, 183, "unrelated").queued, 0);
}
#[test]
fn captured_long_lived_codex_acceptance() {
    let composer = include_str!("../fixtures/codex-sol-live-composer.ansi");
    let accepted = include_str!("../fixtures/codex-sol-accepted-line.ansi");
    let wire = "claude (config-tt:claude): #pre1 #pre3 #pre2 read and execute; do not forward: ~/desk/tmp/relay-rust-store/f68bb1c3afe553ca45b404b1c29854a3.original";
    assert!(composer.contains("1 warning"));
    assert_eq!(
        classify(composer, '›', 2, 47, 183),
        Composer::EmptyCandidate
    );
    let combined = format!("{accepted}{composer}");
    assert_eq!(receipt('›', &combined, 2, 48, 183, wire).submitted, 1);
    assert_eq!(
        receipt('›', accepted, wire.len() + 2, 0, 183, wire).submitted,
        0
    );
    for changed in [
        combined.replace("48;2;66;66;79", "48;2;66;66;80"),
        combined.replace(wire, &format!("{wire} suffix")),
        combined.replace(wire, &format!("prefix {wire}")),
        combined.replace("\x1b[1;2m› ", "\x1b[2m› "),
    ] {
        assert_eq!(receipt('›', &changed, 2, 48, 183, wire).submitted, 0);
    }
    assert_eq!(
        receipt('›', &combined, 2, 48, 183, "unrelated").submitted,
        0
    );
}
#[test]
fn captured_claude_busy_queue_with_status_and_tip() {
    let capture = include_str!("../fixtures/claude-busy-queued-with-tip.ansi");
    let wire = "sol (config-tt:sol): #rf-p6 -- full: ~/desk/tmp/relay-rust-store/d1cc2d94966b184255b27c7813766208.original";
    assert_eq!(
        receipt('❯', capture, 2, 28, 149, wire),
        Receipt {
            submitted: 0,
            queued: 1,
            queue_prompt: true
        }
    );
    for changed in [
        capture.replace(wire, &format!("{wire} suffix")),
        capture.replace("ctrl+x ctrl+s to send now", "unknown queue hint"),
        capture.replace("Press up to edit queued messages", "unknown prompt"),
        capture.replace("48;5;237", "48;5;238"),
        capture.replace(&"─".repeat(149), &"─".repeat(148)),
    ] {
        assert_ne!(changed, capture);
        let observed = receipt('❯', &changed, 2, 28, 149, wire);
        assert!(!observed.queue_prompt || observed.queued == 0);
    }
    assert!(!receipt('❯', capture, 3, 28, 149, wire).queue_prompt);
    assert_eq!(receipt('❯', capture, 2, 28, 149, "unrelated").queued, 0);
    assert_eq!(receipt('›', capture, 2, 28, 149, wire).queued, 0);
    assert_eq!(receipt('❯', capture, 2, 27, 149, wire).queued, 0);
}
#[test]
fn captured_claude_busy_queue_word_styles() {
    let capture = include_str!("../fixtures/claude-busy-queued-word-styles.ansi");
    let wire = "sol (config-tt:sol): #s12r11rust Reply ACK_S12R11_RUST only; no tools.";
    assert_eq!(
        receipt('❯', capture, 2, 25, 180, wire),
        Receipt {
            submitted: 0,
            queued: 1,
            queue_prompt: true
        }
    );
    assert!(!receipt('❯', capture, 3, 25, 180, wire).queue_prompt);
    assert_eq!(receipt('❯', capture, 2, 25, 180, "unrelated").queued, 0);
    assert!(
        !receipt(
            '❯',
            &capture.replace("\x1b[2mqueued", "queued"),
            2,
            25,
            180,
            wire
        )
        .queue_prompt
    );
    assert!(
        !receipt(
            '❯',
            &capture.replace("messages", "drafts"),
            2,
            25,
            180,
            wire
        )
        .queue_prompt
    );
}
#[test]
fn captured_codex_busy_accepted_history() {
    let capture = include_str!("../fixtures/codex-busy-accepted.ansi");
    let wire = "sol (config-tt:sol): #s11k10rust Reply ACK_S11K10_RUST only; no tools.";
    assert_eq!(classify(capture, '›', 2, 24, 180), Composer::EmptyCandidate);
    assert_eq!(receipt('›', capture, 2, 24, 180, wire).submitted, 1);
    assert_eq!(receipt('›', capture, 2, 24, 180, "unrelated").submitted, 0);
    assert_eq!(receipt('❯', capture, 2, 24, 180, wire).submitted, 0);
    let row = capture
        .lines()
        .position(|row| row == format!("\x1b[1;2m› \x1b[0m{wire}"))
        .unwrap();
    assert_eq!(
        receipt('›', capture, wire.len() + 2, row, 180, wire).submitted,
        0
    );
    for changed in [
        capture.replace("\x1b[1;2m› ", "\x1b[2m› "),
        capture.replace(wire, &format!("prefix {wire}")),
        capture.replace(wire, &format!("{wire} suffix")),
    ] {
        assert_eq!(receipt('›', &changed, 2, 24, 180, wire).submitted, 0);
    }
}
#[test]
fn captured_busy_queue_receipts() {
    let claude = include_str!("../fixtures/claude-busy-queued.ansi");
    let codex = include_str!("../fixtures/codex-busy-queued.ansi");
    for (glyph, capture, y, wire, hint, ghost) in [
        (
            '❯',
            claude,
            20,
            "sol (config-tt:sol): #s11r9stable Reply ACK_S11R9_STABLE only; no tools.",
            "ctrl+x ctrl+s to send now",
            "Press up to edit queued messages",
        ),
        (
            '›',
            codex,
            19,
            "sol (config-tt:sol): #s11k9stable Reply ACK_S11K9_STABLE only; no tools.",
            "Messages to be submitted after next tool call",
            "Ask Codex to do anything",
        ),
    ] {
        let observed = receipt(glyph, capture, 2, y, 180, wire);
        assert_eq!(
            observed,
            Receipt {
                submitted: 0,
                queued: 1,
                queue_prompt: true
            }
        );
        assert_eq!(receipt(glyph, capture, 2, y, 180, "unrelated").queued, 0);
        assert_eq!(
            receipt(
                glyph,
                &capture.replace(hint, "unknown layout"),
                2,
                y,
                180,
                wire
            )
            .queued,
            0
        );
        assert!(
            !receipt(
                glyph,
                &capture.replace(ghost, "unknown prompt"),
                2,
                y,
                180,
                wire
            )
            .queue_prompt
        );
        assert!(!receipt(glyph, capture, 3, y, 180, wire).queue_prompt);
        assert_eq!(receipt(glyph, capture, 2, y + 1, 180, wire).queued, 0);
        let staged = capture.replace(ghost, wire);
        let before = receipt(glyph, &staged, wire.len() + 2, y, 180, wire);
        assert_eq!(before.queued, observed.queued);
        assert!(!before.queue_prompt);
        let accepted = match glyph {
            '❯' => format!("\x1b[38;5;246m\x1b[48;5;237m❯ \x1b[38;5;231m{wire}\x1b[39m\n"),
            _ => format!("\x1b[1m›\x1b[0m {wire}\n"),
        };
        assert_eq!(
            receipt(glyph, &accepted, wire.len() + 2, 0, 180, wire).submitted,
            0
        );
        assert_eq!(
            receipt(glyph, &(accepted + capture), 2, y + 1, 180, wire).submitted,
            1
        );
    }
}
#[test]
fn codex_162_current_composer() {
    let capture = include_str!("../../../tests/fixtures/codex-162-empty-composer.ansi");
    assert_eq!(classify(capture, '›', 2, 0, 215), Composer::EmptyCandidate);
    assert_eq!(screen('›', capture, 2, 0, 215, "relay: #x"), Screen::Empty);
}
#[test]
fn startup_ghost_without_footer_cannot_authorize_paste() {
    let capture = "\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m\n\n\n";
    assert_eq!(classify(capture, '›', 2, 0, 180), Composer::EmptyCandidate);
    assert!(!ready('›', capture, 2, 0, 180));
}

#[test]
fn composer_rules() {
    let empty = "❯\u{a0}\n────────────────────\n";
    assert_eq!(classify(empty, '❯', 2, 0, 20), Composer::EmptyCandidate);
    assert_eq!(screen('❯', empty, 2, 0, 20, "relay: #x"), Screen::Empty);
    for (text, x) in [
        ("❯\u{a0}human-draft\n────────────────────\n", 13),
        ("❯\u{a0} \n────────────────────\n", 3),
        ("❯\u{a0}draft\nunknown\n", 7),
    ] {
        assert_ne!(classify(text, '❯', x, 0, 20), Composer::EmptyCandidate);
    }
    let staged = "❯\u{a0}relay: #x\n────────────────────\n";
    assert_eq!(
        screen('❯', staged, 11, 0, 20, "relay: #x"),
        Screen::Staged(b"relay: #x".to_vec())
    );
    for x in [0, 2, 10, 12] {
        assert_eq!(screen('❯', staged, x, 0, 20, "relay: #x"), Screen::Hold);
    }
    assert_eq!(screen('❯', staged, 11, 0, 20, "relay: #y"), Screen::Hold);
    assert_eq!(
        screen('❯', "unrecognized", 0, 0, 20, "relay: #x"),
        Screen::Hold
    );
    assert!(row("\x1b[8mhidden").is_err());
    assert!(row("\x1b[badm").is_err());
    let codex = "› relay: #x\n\n  model · context\n";
    assert_eq!(
        screen('›', codex, 11, 0, 40, "relay: #x"),
        Screen::Staged(b"relay: #x".to_vec())
    );
}
#[test]
fn historical_corpus() {
    use sha2::{Digest, Sha256};
    let root = std::path::PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk")
        .join("audits/relay/rustify/review/keeper2-slice/corpus");
    let bytes = std::fs::read(root.join("manifest.json")).unwrap();
    assert_eq!(
        format!("{:x}", Sha256::digest(&bytes)),
        "4ea87002e5202a5f4d11b82264b3ffa1ccee5f97b6d0c8dd16d93981236c8bdc"
    );
    let manifest: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    let cases = manifest["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 52);
    for case in cases {
        let capture = match case["capture_file"].as_str() {
            Some(p) => {
                let raw = std::fs::read(root.join(p)).unwrap();
                assert_eq!(
                    format!("{:x}", Sha256::digest(&raw)),
                    case["capture_sha256"].as_str().unwrap()
                );
                String::from_utf8(raw).unwrap()
            }
            None => case["capture"].as_str().unwrap().to_owned(),
        };
        let glyph = case["glyph"]
            .as_str()
            .unwrap_or("›")
            .chars()
            .next()
            .unwrap();
        let x = case["cursor_x"].as_u64().unwrap() as usize;
        let y = case["cursor_y"].as_u64().unwrap() as usize;
        let width = case["pane_width"].as_u64().unwrap_or(167) as usize;
        let expected = case["input_exit"].as_i64().unwrap() == 0
            || case["name"] == "sol-startup-without-footer";
        assert_eq!(
            classify(&capture, glyph, x, y, width) == Composer::EmptyCandidate,
            expected,
            "{}",
            case["name"]
        );
    }
}

// Read-only harness adapter. The production classifier above is not changed.
fn snapshot_result(request: &serde_json::Value) -> serde_json::Value {
    let capture = request["capture"].as_str().unwrap();
    let glyph = request["glyph"].as_str().unwrap().chars().next().unwrap();
    let x = request["x"].as_u64().unwrap() as usize;
    let y = request["y"].as_u64().unwrap() as usize;
    let width = request["width"].as_u64().unwrap() as usize;
    let expected = request["expected"].as_str().unwrap();
    let classified = classify(capture, glyph, x, y, width);
    let observed = screen(glyph, capture, x, y, width, expected);
    let accepted = if expected.is_empty() {
        observed == Screen::Empty
    } else {
        observed == Screen::Staged(expected.as_bytes().to_vec())
    };
    let observed_name = match observed {
        Screen::Empty => "Empty",
        Screen::Staged(_) => "StagedExact",
        Screen::Hold => "Hold",
    };
    let reason = format!(
        "expected={}; composer::screen={observed_name}; composer::classify={classified:?}",
        if expected.is_empty() {
            "empty"
        } else {
            "exact-draft"
        }
    );
    // No capture character is structural by assumption. Mask every non-space
    // character, including prompt/box glyphs and terminal control sequences.
    // Known glyph and geometry metadata are separate from the capture.
    fn sanitized(raw: &str) -> String {
        raw.chars()
            .map(|ch| if ch.is_whitespace() { ch } else { 'x' })
            .collect()
    }
    let rows: Vec<_> = capture.split_inclusive('\n').collect();
    let first = y.saturating_sub(1).min(rows.len());
    let last = y.saturating_add(4).min(rows.len());
    let fixture = serde_json::json!({
        "capture": rows[first..last].iter().map(|row| sanitized(row)).collect::<String>(),
        "glyph": glyph.to_string(), "cursor_x": x, "cursor_y": y.saturating_sub(first),
        "pane_width": width, "original_cursor_y": y, "original_row_count": rows.len(),
        "first_retained_row": first, "all_visible_text_masked": true,
        "reason": reason,
    });
    serde_json::json!({"accepted": accepted, "reason": reason, "fixture": fixture})
}

#[test]
#[ignore = "stdin-only read-only native snapshot harness probe"]
fn native_snapshot_probe() {
    use std::io::Read;
    let mut input = String::new();
    std::io::stdin()
        .take(4 * 1024 * 1024)
        .read_to_string(&mut input)
        .unwrap();
    let request: serde_json::Value = serde_json::from_str(&input).unwrap();
    println!("K65_SNAPSHOT {}", snapshot_result(&request));
}

#[test]
fn snapshot_adapter_reuses_classifier_and_redacts_refusal() {
    let empty = "❯\u{a0}\n────────────────────\n";
    let mut request =
        serde_json::json!({"capture": empty,"glyph":"❯","x":2,"y":0,"width":20,"expected":""});
    assert_eq!(snapshot_result(&request)["accepted"], true);
    request["capture"] = "❯\u{a0}private123\n────────────────────\n".into();
    request["x"] = 12.into();
    request["expected"] = "private123".into();
    assert_eq!(snapshot_result(&request)["accepted"], true);
    request["expected"] = "different!".into();
    let refused = snapshot_result(&request);
    assert_eq!(refused["accepted"], false);
    assert_eq!(
        refused["reason"],
        "expected=exact-draft; composer::screen=Hold; composer::classify=Draft"
    );
    let fixture = refused["fixture"].to_string();
    assert!(!fixture.contains("private123"));
    assert!(fixture.contains("xxxxxxxxxx"));
    request["capture"] = "❯\u{a0}\u{1b}[8mprivate123\n────────────────────\n".into();
    let refused = snapshot_result(&request);
    assert!(!refused["fixture"].to_string().contains("private123"));
    assert!(refused["fixture"]["capture"]
        .as_str()
        .unwrap()
        .chars()
        .all(|ch| ch == 'x' || ch.is_whitespace()));
}

#[test]
fn snapshot_fixture_masks_prompt_and_box_glyphs_in_body_positions() {
    for glyph in ['❯', '›', '─', '━', '│'] {
        let request = serde_json::json!({
            "capture": format!("❯\u{a0}{glyph}secret\n────────────────────\n"),
            "glyph": "❯", "x": 9, "y": 0, "width": 20, "expected": "different",
        });
        let refused = snapshot_result(&request);
        assert_eq!(refused["accepted"], false);
        assert_eq!(refused["fixture"]["all_visible_text_masked"], true);
        let capture = refused["fixture"]["capture"].as_str().unwrap();
        assert!(capture.chars().all(|ch| ch == 'x' || ch.is_whitespace()));
        assert!(capture.starts_with("x\u{a0}xxxxxxx\n"));
        assert_eq!(refused["fixture"]["glyph"], "❯");
    }
}

#[test]
fn codex_162_background_staged_prompt() {
    let wire = "relay: #s7x probe";
    let capture =
        format!("\x1b[1m›\x1b[0m\x1b[48;2;57;57;71m {wire}\n\n\x1b[49m  native-session\n");
    assert_eq!(
        screen('›', &capture, wire.len() + 2, 0, 100, wire),
        Screen::Staged(wire.as_bytes().to_vec())
    );
    assert_eq!(
        screen('›', &capture, wire.len() + 1, 0, 100, wire),
        Screen::Hold
    );
    assert_eq!(
        screen('›', &capture, wire.len() + 2, 0, 100, "other"),
        Screen::Hold
    );
    assert_eq!(
        screen(
            '›',
            &capture.replace("57;57;71", "1;2;3"),
            wire.len() + 2,
            0,
            100,
            wire
        ),
        Screen::Hold
    );
}
