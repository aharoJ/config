use angelstar_runtime::delivery::{envelope, Error};
use angelstar_runtime::target::{Pane, PaneId, SessionId, Target, Window, WindowId};

fn source(session: &str, window: &str) -> Target {
    Target {
        session_id: SessionId(10),
        session_name: session.into(),
        window: Window {
            id: WindowId(11),
            name: window.into(),
        },
        pane: Pane {
            id: PaneId(12),
            pid: 123,
            dead: false,
        },
    }
}

#[test]
fn full_message_and_explicit_codes_survive_without_replacement() {
    let text = "#k03 first\nsecond #s3b1 #k03 end";
    let origin = source("config:会", "codex");
    let value = envelope(Some(&origin), text, "unused").unwrap();
    assert_eq!(value.label, "codex (config:会:codex)");
    assert_eq!(value.message, text);
    assert_eq!(value.codes, ["k03", "s3b1"]);
    assert_eq!(value.render(), format!("codex (config:会:codex): {text}"));
}

#[test]
fn unattributed_source_stays_a_tool_label_with_a_code() {
    let value = envelope(None, "full payload\nwith unicode 会🦀", "a12b34").unwrap();
    assert_eq!(value.label, "relay");
    assert_eq!(value.message, "#a12b34 full payload\nwith unicode 会🦀");
    assert_eq!(value.codes, ["a12b34"]);
}

#[test]
fn empty_payload_or_invalid_generated_code_is_not_an_envelope() {
    for message in ["", " \n\t", "\u{1c}\u{1f}"] {
        assert_eq!(envelope(None, message, "good"), Err(Error::EmptyMessage));
    }
    for code in ["", "a b", "#bad", "\n", "会", "../"] {
        assert_eq!(
            envelope(None, "message", code),
            Err(Error::InvalidGeneratedCode)
        );
    }
}

#[test]
fn literal_hashes_and_retained_code_grammar_are_not_new_parsers() {
    let value = envelope(None, "punctuation #! #会 #", "fresh").unwrap();
    assert_eq!(value.codes, ["fresh"]);
    assert_eq!(value.message, "#fresh punctuation #! #会 #");
    let value = envelope(None, "embedded#old-code_2 and #next", "unused").unwrap();
    assert_eq!(value.codes, ["old-code_2", "next"]);
    assert_eq!(value.message, "embedded#old-code_2 and #next");
}

#[test]
fn source_metadata_cannot_inject_a_second_header_line() {
    let origin = source("config\nforeign", "codex\r\nred");
    let value = envelope(Some(&origin), "#k03 payload", "unused").unwrap();
    assert_eq!(
        value.label,
        "codex\\r\\nred (config\\nforeign:codex\\r\\nred)"
    );
    assert!(!value.label.contains(['\r', '\n']));
}

#[test]
fn many_codes_retain_first_occurrence_order_without_payload_loss() {
    let text = (0..12_000)
        .map(|at| format!("#code{at} #code{at}"))
        .collect::<Vec<_>>()
        .join(" ");
    let value = envelope(None, &text, "unused").unwrap();
    assert_eq!(value.message, text);
    assert_eq!(value.codes.len(), 12_000);
    assert_eq!(value.codes.first().unwrap(), "code0");
    assert_eq!(value.codes.last().unwrap(), "code11999");
}
