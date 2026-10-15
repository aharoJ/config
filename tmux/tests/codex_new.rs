use super::*;
use crate::composer::{self, Composer};
use sha2::{Digest, Sha256};
use std::path::PathBuf;

fn fixture(name: &str) -> String {
    std::fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures")
            .join(name),
    )
    .unwrap()
}
const FOOTER: &str = "Fast off · GPT-6-Astra low · ~/.config";

fn variants(raw: &str) -> Vec<String> {
    let sgr = re(r"\x1b\[[0-9;]*m");
    let duplicate = sgr
        .replace_all(raw, |c: &regex::Captures<'_>| format!("{}{}", &c[0], &c[0]))
        .into_owned();
    let split = sgr
        .replace_all(raw, |c: &regex::Captures<'_>| {
            c[0][2..c[0].len() - 1]
                .split(';')
                .map(|p| format!("\x1b[{p}m"))
                .collect::<String>()
        })
        .into_owned();
    let mut result = vec![
        raw.to_owned(),
        duplicate,
        format!("\x1b[0m\x1b[0m{raw}\x1b[0m\x1b[0m"),
    ];
    if !raw.contains("38;") && !raw.contains("48;") {
        result.push(split);
    }
    result
}

fn expect(mode: &str, raw: &str, expected: &str, accepted: bool) {
    for variant in variants(raw) {
        assert_eq!(
            check(mode, &variant, expected).is_some(),
            accepted,
            "{mode}, {expected}, {variant:?}"
        );
    }
}

#[test]
fn picker_captures_and_hostile_mutations() {
    for (mode, name, footer) in [
        ("menu", "codex-new-menu.ansi", FOOTER),
        ("models", "codex-new-models.ansi", FOOTER),
        ("efforts", "codex-new-efforts.ansi", FOOTER),
        (
            "advanced",
            "codex-new-advanced.ansi",
            "Fast off · GPT-6-Astra ultra · ~/.config",
        ),
        (
            "model-slash",
            "codex-new-model-slash.ansi",
            "Fast off · GPT-6.1-Sol low · ~/.config",
        ),
        ("models", "codex-1601-models.ansi", FOOTER),
        (
            "efforts",
            "codex-1601-efforts.ansi",
            "Fast off · GPT-6.1-Sol low · ~/.config",
        ),
    ] {
        let raw = fixture(name);
        expect(mode, &raw, footer, true);
        for mutated in [
            format!("{raw}unknown overlay\n"),
            raw.replacen("1.", "9.", 1),
            raw.replace("\x1b[1;7m", "\x1b[1m"),
            raw.replace("enter", "space"),
            format!("{raw}{raw}"),
            raw.replacen("› ", "  ", 1),
        ] {
            if mutated != raw {
                expect(mode, &mutated, footer, false);
            }
        }
    }
    let menu = fixture("codex-new-menu.ansi");
    for raw in [
        menu.replace("Current checkout", "Other checkout"),
        menu.replace("New worktree", "New directory"),
        menu.replace("current working directory", "another working directory"),
    ] {
        expect("menu", &raw, FOOTER, false);
    }
    expect(
        "models",
        &fixture("codex-new-models.ansi").replace("Latest workhorse model", "Unknown model"),
        FOOTER,
        false,
    );
    expect(
        "models",
        &fixture("codex-1601-models.ansi").replace("GPT-5.6-Luna", "Unknown-model"),
        FOOTER,
        false,
    );
    expect(
        "models",
        &fixture("codex-1601-models.ansi").replace("  7. GPT-5.6-Luna", "  8. GPT-5.6-Luna"),
        FOOTER,
        false,
    );
    expect(
        "efforts",
        &fixture("codex-1601-efforts.ansi")
            .replace("(default) (current)", "(default) (current) (current)"),
        "Fast off · GPT-6.1-Sol low · ~/.config",
        false,
    );
    expect(
        "efforts",
        &fixture("codex-new-efforts.ansi").replace("GPT-6-Astra", "GPT-6.1-Sol"),
        FOOTER,
        false,
    );
    expect(
        "advanced",
        &fixture("codex-new-advanced.ansi")
            .replace("⚠ Consumes usage limits faster", "Unknown warning"),
        "Fast off · GPT-6-Astra ultra · ~/.config",
        false,
    );
}

#[test]
fn color_and_highlight_proofs() {
    for (mode, name, footer) in [
        ("menu", "codex-new-menu.ansi", FOOTER),
        ("models", "codex-new-models.ansi", FOOTER),
        (
            "efforts",
            "codex-new-efforts.ansi",
            "Fast off · GPT-6-Astra high · ~/.config",
        ),
        (
            "advanced",
            "codex-new-advanced.ansi",
            "Fast off · GPT-6-Astra max · ~/.config",
        ),
        (
            "model-slash",
            "codex-new-model-slash.ansi",
            "Fast off · GPT-6.1-Sol low · ~/.config",
        ),
    ] {
        let raw = fixture(name);
        let color = "\x1b[1m\x1b[38;2;0;0;46m\x1b[48;2;99;168;248m";
        expect(mode, &raw.replace("\x1b[1;7m", color), footer, true);
        for bad in [
            color.replace("\x1b[1m", ""),
            color.replace("48;2;99;168;248", "49"),
            color.replace("248", "256"),
            format!("{color}\x1b[0m"),
            format!("{color}\x1b[22m"),
        ] {
            expect(mode, &raw.replace("\x1b[1;7m", &bad), footer, false);
        }
    }
    for mode in ["models", "efforts", "advanced"] {
        expect(
            mode,
            &fixture(&format!("codex-new-colored-{mode}.ansi")),
            "Fast off · GPT-5.6-Terra max · ~/.config",
            true,
        );
    }
}

#[test]
fn restoration_navigation_and_controls() {
    for (mode, file, footer, wanted) in [
        ("navigate-models", "codex-new-models.ansi", FOOTER, "0:1"),
        (
            "navigate-efforts",
            "codex-new-efforts.ansi",
            "Fast off · GPT-6-Astra xhigh · ~/.config",
            "1:3",
        ),
        (
            "navigate-efforts",
            "codex-new-effort-more.ansi",
            FOOTER,
            "4:0",
        ),
        (
            "navigate-advanced",
            "codex-new-advanced.ansi",
            "Fast off · GPT-6-Astra ultra · ~/.config",
            "0:1",
        ),
    ] {
        assert_eq!(check(mode, &fixture(file), footer).as_deref(), Some(wanted));
    }
    let efforts = fixture("codex-new-efforts.ansi");
    for effort in ["low", "medium", "high", "xhigh", "max", "ultra"] {
        expect(
            "efforts",
            &efforts,
            &format!("Fast off · GPT-6-Astra {effort} · ~/.config"),
            true,
        );
    }
    let more = fixture("codex-new-effort-more.ansi");
    expect(
        "efforts",
        &more,
        "Fast off · GPT-6-Astra ultra · ~/.config",
        true,
    );
    expect(
        "efforts",
        &more.replace(" select · ", " default · s session · "),
        FOOTER,
        false,
    );
    expect(
        "efforts",
        &efforts
            .replace(" default · ", " select · ")
            .replace("\x1b[0;1ms\x1b[0;2m session · ", ""),
        FOOTER,
        false,
    );
    let current = fixture("codex-new-advanced-current.ansi");
    for (word, accepted) in [("default", true), ("apply", true), ("run", false)] {
        expect(
            "advanced",
            &current.replace(" default · ", &format!(" {word} · ")),
            "Fast off · GPT-6-Astra max · ~/.config",
            accepted,
        );
    }
    for footer in [
        "Fast off · Unknown-model low · ~/.config",
        "Fast off · GPT-6-Astra unknown · ~/.config",
    ] {
        expect("supported-footer", "", footer, false);
    }
    expect("supported-footer", "", FOOTER, true);
}

#[test]
fn slash_footer_and_reset_continuity() {
    let slash = format!("\x1b[1;7m› /new  \x1b[0;7mstart a new chat during a conversation\x1b[0m\n\n› /new\n\n  {FOOTER} · Context 43% used\n");
    expect("slash", &slash, FOOTER, true);
    for raw in [
        slash.replace("› /new\n", "› /new draft\n"),
        slash.replace("/new  ", "/model  "),
        slash.replace("\x1b[1;7m", "\x1b[1m"),
        format!("{slash}unknown overlay\n"),
        slash.replace("GPT-6-Astra", "GPT-6-Sol"),
    ] {
        expect("slash", &raw, FOOTER, false);
    }
    let fresh =
        format!("› Ask Codex to do anything\n\n  {FOOTER} · Context 0% used · ← for agents\n");
    expect("fresh", &fresh, FOOTER, true);
    for raw in [
        fresh.replace("0%", "1%"),
        fresh.replace("~/.config", "~/elsewhere"),
        fresh.replace(" low", " high"),
        fresh.replace("Context 0% used", "Context 0% used arbitrary"),
    ] {
        expect("fresh", &raw, FOOTER, false);
    }
    let reset = fresh.replace("GPT-6-Astra low", "GPT-6.1-Sol low");
    expect("reset", &reset, FOOTER, true);
    expect("fresh", &reset, FOOTER, false);
    for raw in [
        reset.replace("~/.config", "~/elsewhere"),
        reset.replace("Fast off", "Fast on"),
        format!("{}  ⚠ unknown warning\n", reset.trim_end()),
    ] {
        expect("reset", &raw, FOOTER, false);
    }
    expect(
        "reset",
        &format!("{}  ⚠ 1 warning · f2 to view\n", reset.trim_end()),
        FOOTER,
        true,
    );
}

fn fresh() -> (String, String) {
    let footer = "Fast off · GPT-6.1-Sol low · ~/demo/lab/nongit".to_owned();
    (format!("  >_ OpenAI Codex (v0.160.0)\n     ~/demo/lab/nongit\n  \x1b[38;2;99;168;248mHello.\x1b[39m\n  \x1b[1mTip:\x1b[0m Use /title.\n\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m\n\n  {footer} · Context 0% used\n"), footer)
}

fn destination(raw: &str, footer: &str, x: usize, y: usize) -> bool {
    check("menu", raw, footer).is_some()
        || (check("direct-reset", raw, footer).is_some()
            && composer::classify(raw, '›', x, y, 215) == Composer::EmptyCandidate
            && check("busy", raw, "").is_none())
}

#[test]
fn fresh_destination_and_retained_transcript_refusals() {
    let (fresh, footer) = fresh();
    assert!(destination(&fixture("codex-new-menu.ansi"), &footer, 2, 4));
    for version in ["0.160.0", "0.160.1", "0.161.0"] {
        assert!(destination(
            &fresh.replace("0.160.0", version),
            &footer,
            2,
            4
        ));
    }
    assert!(destination(
        &fresh.replace(" used", " used · Main [default]"),
        &footer,
        2,
        4
    ));
    assert!(destination(
        &fresh.replace("GPT-6.1-Sol low", "GPT-6-Astra high"),
        &footer,
        2,
        4
    ));
    assert!(destination(
        &fresh.replace(
            "\n\x1b[1m›",
            "\n• Model changed to gpt-6.1-sol low for this session only\n\x1b[1m›"
        ),
        &footer,
        2,
        5
    ));
    for raw in [
        "unrecognized overlay\n".into(),
        format!("Previous conversation remains loaded: BANANA.\n{fresh}"),
        fresh.replace("v0.160.0", "invalid"),
        fresh.replace(
            "\n\x1b[1m›",
            "\n• Model changed to gpt-6-astra high for this session only\n\x1b[1m›",
        ),
        fresh.replace("Context 0%", "Context 1%"),
        fresh.replace("Context 0%", "Context 100%"),
        fresh.replace("nongit", "other-cwd"),
        fresh.replace("Fast off", "Fast on"),
        format!("{fresh}{fresh}"),
        fresh.replace("Context 0% used", "Context 0% used unknown"),
        fresh.replace(" used\n", " used · Main [other]\n"),
        fresh.replace(" · Context 0% used", ""),
        fresh.replace("\x1b[2mAsk Codex to do anything\x1b[0m", "unsent draft"),
        fresh.replace("\x1b[2mAsk Codex to do anything\x1b[0m", "/new"),
        fresh.replace("\n\n  Fast", "\n  unsent continuation\n\n  Fast"),
        format!("{fresh}unknown overlay\n"),
        fresh.replace("Fast off", "\x1b[8mFast off\x1b[0m"),
        fresh.replace("\x1b[2mAsk", "\x1b[22mAsk"),
    ] {
        for raw in variants(&raw) {
            assert!(!destination(&raw, &footer, 2, 4), "{raw:?}");
        }
    }
    assert!(!destination(
        &format!("• Working (1s • esc to interrupt)\n\n{fresh}"),
        &footer,
        2,
        6
    ));
    assert!(!destination(&fresh, &footer, 2, 1));
    let startup = fixture("codex-new-live-startup-residue.ansi");
    let y = rows(&startup)
        .iter()
        .position(|row| row.contains("Ask Codex to do anything"))
        .unwrap();
    assert!(destination(
        &startup,
        "Fast off · GPT-6.1-Sol low · ~/demo/lab/codex-new-chat-smoke",
        2,
        y
    ));
    for file in [
        "codex-new-blind-retained-direct.ansi",
        "codex-new-blind-retained-menu.ansi",
    ] {
        let raw = fixture(file);
        let footer = check("footer", &raw, "").unwrap();
        assert!(check("direct-reset", &raw, &footer).is_none());
    }
}

#[test]
fn byte_exact_real_capture_corpus() {
    for manifest in ["codex-new-cwd-live.json", "codex-new-reset-ansi.json"] {
        let data: serde_json::Value = serde_json::from_str(&fixture(manifest)).unwrap();
        for case in data["cases"].as_array().unwrap() {
            let raw = fixture(case["capture_file"].as_str().unwrap());
            assert_eq!(
                format!("{:x}", Sha256::digest(raw.as_bytes())),
                case["sha256"].as_str().unwrap()
            );
            let footer = case["footer"].as_str().unwrap();
            if let Some(meta) = case["meta_file"].as_str() {
                assert_eq!(
                    format!("{:x}", Sha256::digest(fixture(meta).as_bytes())),
                    case["meta_sha256"].as_str().unwrap()
                );
            }
            if case["stage"] == "before" {
                expect("footer", &raw, "", true);
            } else {
                for mode in ["reset", "fresh", "direct-reset"] {
                    expect(mode, &raw, footer, true);
                }
                assert!(destination(
                    &raw,
                    footer,
                    case["cursor_x"].as_u64().unwrap() as usize,
                    case["cursor_y"].as_u64().unwrap() as usize
                ));
            }
        }
    }
}

#[test]
fn busy_is_local_to_the_active_composer() {
    for (file, mode) in [
        ("codex-new-live-busy-slash.ansi", "busy"),
        ("codex-new-live-real-busy.ansi", "busy"),
        ("codex-new-live-real-busy-narrow.ansi", "busy"),
        ("codex-new-live-real-busy-draft.ansi", "busy"),
        ("codex-new-live-real-busy-slash.ansi", "busy-slash"),
    ] {
        expect(mode, &fixture(file), "", true);
    }
    for file in [
        "codex-new-live-transcript-quotes-busy.ansi",
        "codex-new-live-real-idle-quoted.ansi",
    ] {
        expect("busy", &fixture(file), "", false);
    }
    for (file, accepted) in [
        ("codex-new-live-80col-fresh.ansi", true),
        ("codex-new-live-80col-tail-fresh.ansi", true),
        ("codex-new-live-80col-used.ansi", false),
        ("codex-new-live-80col-tail-used.ansi", false),
    ] {
        let raw = fixture(file);
        let footer = check("footer", &raw, "").unwrap();
        expect("direct-reset", &raw, &footer, accepted);
    }
    expect(
        "footer",
        &fixture("codex-new-live-80col-truncated-used.ansi"),
        "",
        false,
    );
}

#[test]
fn atomic_screen_format_escapes_paths() {
    let raw = fixture("codex-new-menu.ansi");
    let output = check("tmux-rows", &raw, "/a#b,c}d").unwrap();
    assert!(output.contains("#{pane_current_path},/a##b#,c#}d}"));
    assert!(output.contains("#{C/r:^"));
    assert!(check("tmux-rows", &format!("{raw}{raw}"), "/x").is_none());
}

#[test]
fn current_checkout_menu_uses_the_live_source_contract() {
    let current = fixture("codex-new-live-1621-menu.ansi");
    expect("menu", &current, "", true);
    assert!(check("tmux-rows", &current, "/checkout").is_some());
    for mutation in [
        current.replace("Use current Git worktree", "Current checkout"),
        current.replace("Create new Git worktree", "New worktree"),
        current.replace("current working directory", "different working directory"),
        format!("{current}unknown overlay\n"),
    ] {
        expect("menu", &mutation, "", false);
    }
}

#[test]
fn both_guards_retain_the_shared_picker_and_native_reset_contract() {
    let footer = "Fast off · GPT-6.1-Sol low · ~/.config";
    let picker = fixture("codex-model-1601-terra-derived.ansi");
    assert_eq!(
        check("navigate-models", &picker, footer).as_deref(),
        Some("5:0")
    );
    assert_eq!(
        crate::model_guard::picker(&picker, "models", footer),
        Some((5, 0))
    );
    for capture in [
        picker.replace("GPT-5.6-Luna", "Unknown-model"),
        picker.replace("  7. GPT-5.6-Luna", "  8. GPT-5.6-Luna"),
        picker.replace("Older balanced model", "Unknown description"),
        picker.replace(" select · ", " unverified · "),
        picker.replace("Select Model and Effort", "Unexpected picker"),
    ] {
        assert!(check("models", &capture, footer).is_none());
        assert!(!crate::model_guard::check("models", &capture, footer));
    }
    let native = fixture("codex-161-native-reset.ansi");
    let footer = crate::model_guard::footer(&native).unwrap();
    assert!(crate::model_guard::check(
        "settling-reset",
        &native,
        &footer
    ));
    assert!(check("direct-reset", &native, &footer).is_some());
}
