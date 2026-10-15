use super::*;
const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../tests/fixtures");
fn fixture(name: &str) -> String {
    std::fs::read_to_string(format!("{FIXTURES}/{name}")).unwrap()
}
#[test]
fn seven_and_eight_model_pickers_preserve_order_labels_and_highlights() {
    let expected = "Fast off · GPT-6.1-Sol low · ~/model-lab/fixture";
    for name in [
        "codex-model-1601-terra-derived.ansi",
        "codex-new-colored-models.ansi",
    ] {
        let capture = fixture(name);
        assert_eq!(picker(&capture, "models", expected), Some((5, 0)), "{name}");
        for bad in [
            capture.replace("GPT-5.6-Luna", "Unknown-model"),
            capture.replace("  7. GPT-5.6-Luna", "  8. GPT-5.6-Luna"),
            capture.replace("Older balanced model", "Unknown description"),
            capture.replace(" select · ", " unverified · "),
            capture.replace("Select Model and Effort", "Unexpected picker"),
            capture.replace("\x1b[1m\x1b[38;2;0;0;46m\x1b[48;2;99;168;248m›", "›"),
            capture.replace("\x1b[1;7m›", "›"),
        ] {
            if bad != capture {
                assert!(picker(&bad, "models", expected).is_none(), "{name}");
            }
        }
    }
}
#[test]
fn fresh_reset_allows_only_known_structure_and_retains_strict_transition() {
    let expected="Fast off · GPT-5.6-Terra max · ~/model-lab/live-reset-restore-terra/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    let capture = fixture("codex-new-live-config-main-after.ansi");
    let expected = footer(&capture).unwrap_or(expected.into());
    for screen in [
        capture.clone(),
        capture.replace("v0.160.0", "v0.160.1"),
        capture.replace("v0.160.0", "v0.161.0"),
        capture
            .lines()
            .filter(|r| !r.contains("conversational potential"))
            .collect::<Vec<_>>()
            .join("\n"),
    ] {
        assert!(check("settling-reset", &screen, &expected));
        for line in [
            "  Unexpected status text",
            "  ⚠ Unknown warning",
            "  Select Model and Effort",
            "  Where should the new conversation run?",
            "› 1. Unknown choice",
            "  Tip: Unknown command",
            "  Unknown greeting",
        ] {
            let bad = screen.replace("\n\x1b[1m›", &format!("\n{line}\n\x1b[1m›"));
            assert_ne!(screen, bad);
            assert!(!check("settling-reset", &bad, &expected), "{line}");
        }
        for bad in [
            screen.replace("excellent conversational potential", "unknown greeting"),
            screen.replace("desktop app", "unknown action"),
            screen.replace("Context 0%", "Context 1%"),
            screen.replace("YOLO mode", "Unknown mode"),
            screen.replace(">_ OpenAI", "\x1b]8;;https://example.test\x07>_ OpenAI"),
        ] {
            if bad != screen {
                assert!(!check("settling-reset", &bad, &expected));
            }
        }
    }
    let native = fixture("codex-161-native-reset.ansi");
    let footer = footer(&native).unwrap();
    assert!(check("settling-reset", &native, &footer));
    assert!(!check("direct-reset", &native, &footer));
}
#[test]
fn supported_arguments_session_only_confirmation_and_complete_screen_fingerprint() {
    for (model, _) in MODELS {
        for effort in LEVELS {
            assert_eq!(
                valid(&model.to_lowercase(), effort),
                !model.ends_with("Luna") || *effort != "ultra"
            );
        }
    }
    assert!(!valid("gpt-6.1-sol", "default"));
    assert!(!valid("unknown", "low"));
    let expected = "Fast off · GPT-6.1-Sol low · ~/model-lab/fixture";
    let changed=format!("• Model changed to gpt-6.1-sol low for this session only\n  {expected} · Context 12% used\n");
    assert!(check("changed", &changed, expected));
    assert!(!check(
        "changed",
        &changed.replace(" for this session only", ""),
        expected
    ));
    assert!(!check(
        "changed",
        &changed.replace("Sol low", "Sol high"),
        expected
    ));
    assert_eq!(digest("screen\n\n"), digest("screen"));
    assert_ne!(digest("screen"), digest("screen\nwarning"));
    let fresh = fixture("codex-161-native-reset.ansi");
    let rows = rows(&fresh);
    let y = rows
        .iter()
        .position(|s| s == "› Ask Codex to do anything")
        .unwrap();
    assert_eq!(crate::model_payload::input(&fresh, '›', 2, y, 200), 0);
    assert_eq!(
        crate::model_payload::input(
            &fresh.replace("\x1b[2mAsk Codex to do anything\x1b[0m", "owned draft"),
            '›',
            13,
            y,
            200
        ),
        1
    );
    assert_eq!(
        crate::model_payload::input(&fresh.replace("\n\n  Fast", "\n \n  Fast"), '›', 2, y, 200),
        1
    );
}
#[test]
fn effort_and_advanced_navigation_accepts_session_controls() {
    for (model, _) in MODELS {
        for effort in LEVELS {
            if !valid(&model.to_lowercase(), effort) {
                continue;
            }
            let expected = format!("Fast off · {model} {effort} · ~/fixture");
            for kind in ["efforts", "advanced"] {
                let luna = model.ends_with("Luna");
                let choices = if kind == "efforts" {
                    EFFORTS
                } else if luna {
                    &ADVANCED[..1]
                } else {
                    ADVANCED
                };
                if kind == "advanced" && !matches!(*effort, "max" | "ultra") {
                    continue;
                }
                for selected in 0..choices.len() {
                    let mut screen = if kind == "efforts" {
                        format!("  Select Reasoning Level for {model}\n")
                    } else {
                        "  Advanced Reasoning\n  ⚠ Consumes usage limits faster\n".into()
                    };
                    for (i, (label, description)) in choices.iter().enumerate() {
                        let description = if luna && *label == "More reasoning…" {
                            "Max consumes usage limits faster"
                        } else {
                            description
                        };
                        screen += &format!(
                            "{}{}. {label}  {description}\x1b[0m\n",
                            if selected == i { "\x1b[1;7m› " } else { "  " },
                            i + 1
                        );
                    }
                    screen += if kind == "efforts" && selected == 4 {
                        "  enter select · esc back\n"
                    } else {
                        "  enter apply · s session · esc back\n"
                    };
                    let wanted = if kind == "advanced" {
                        usize::from(*effort == "ultra")
                    } else {
                        LEVELS.iter().position(|s| s == effort).unwrap().min(4)
                    };
                    assert_eq!(
                        picker(&screen, kind, &expected),
                        Some((selected, wanted)),
                        "{model} {effort} {kind}"
                    );
                    assert!(picker(&screen.replace("\x1b[1;7m", ""), kind, &expected).is_none());
                }
            }
        }
    }
}
#[test]
fn late_row_replacements_invalidate_reset_and_fingerprint() {
    let original = fixture("codex-161-native-reset.ansi");
    let expected = footer(&original).unwrap();
    let mut lines: Vec<_> = original.lines().map(str::to_owned).collect();
    for replacement in [
        "  ⚠ Unknown warning",
        "  Unexpected status text",
        "  Select Model and Effort",
        "  Where should the new conversation run?",
    ] {
        lines[4] = replacement.into();
        let changed = lines.join("\n");
        assert!(!check("settling-reset", &changed, &expected));
        assert_ne!(digest(&original), digest(&changed));
    }
    assert_eq!(
        crate::model_payload::input(&original.replace('›', "»"), '»', 2, 7, 200),
        1
    );
}
#[test]
fn payload_controls_unicode_and_live_guard_return_codes() {
    use crate::model_payload as payload;
    for control in ["a\u{200b}b", "a\u{2028}b", "a\0b", "a\x1bb"] {
        assert!(!payload::printable(control));
    }
    assert!(payload::printable("hello 界 e\u{301}"));
    assert_eq!(payload::cells("界e\u{301}"), Some(3));
    assert_eq!(payload::cells("x\u{fe0f}"), None);
    assert_eq!(payload::input("no prompt\n", '›', 2, 0, 200), 2);
    assert_eq!(
        payload::input("› owned draft\n\n  footer\n", '›', 2, 0, 200),
        1
    );
    assert!(payload::busy(
        "• Working (1m 4s · esc to interrupt)\n\n› \n",
        '›',
        2
    ));
    let nested = payload::nested(
        "%1",
        "#{==:1,1}",
        "send-keys -t %1 Enter",
        "display-message -p nope",
    );
    assert!(nested.starts_with("'if-shell' '-F' '-t' '%1'"));
}
