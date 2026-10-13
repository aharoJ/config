use angelstar_runtime::composer::*;

#[test]
fn plain_text_is_not_dim() {
    assert_eq!(
        row("draft").unwrap(),
        Row {
            text: "draft".into(),
            visible_text_is_dim: false,
            has_dim_style: false,
            has_background_style: false
        }
    );
}

#[test]
fn prompt_markers_do_not_authorize_a_composer() {
    assert_eq!(marker("❯\u{a0}\n", '❯'), Ok(Marker::Empty));
    assert_eq!(marker("❯ \n", '❯'), Ok(Marker::Draft));
    assert_eq!(marker("› \x1b[2mhint\x1b[0m\n", '›'), Ok(Marker::Ghost));
    assert_eq!(marker("› draft\n", '›'), Ok(Marker::Draft));
    assert_eq!(
        marker("› \x1b[2mhint\x1b[22mdraft\n", '›'),
        Ok(Marker::Draft)
    );
    assert!(marker("history › \x1b[2mhint", '›').is_err());
    assert!(marker("› \x1b[2mhint\nwrapped", '›').is_err());
}
#[test]
fn dim_styling_is_distinct_from_normal_suffix() {
    assert!(row("\x1b[2mghost\x1b[0m").unwrap().visible_text_is_dim);
    assert!(
        !row("\x1b[2mghost\x1b[22mdraft")
            .unwrap()
            .visible_text_is_dim
    );
}

#[test]
fn claude_candidate_needs_current_cursor_and_closing_divider() {
    let screen = "history\n❯\u{a0}\n────────\nstatus\n";
    assert_eq!(classify(screen, '❯', 2, 1, 8), Composer::EmptyCandidate);
    assert_ne!(classify(screen, '❯', 3, 1, 8), Composer::EmptyCandidate);
    assert_ne!(classify(screen, '❯', 2, 0, 8), Composer::EmptyCandidate);
    assert_ne!(classify(screen, '❯', 2, 1, 9), Composer::EmptyCandidate);
    assert_ne!(
        classify("❯\u{a0}\n", '❯', 2, 0, 8),
        Composer::EmptyCandidate
    );
}

#[test]
fn divider_shaped_and_whitespace_continuations_are_drafts() {
    for continuation in [" ", "────────", "draft"] {
        let screen = format!("❯\u{a0}\n{continuation}\n────────\nstatus\n");
        assert_ne!(classify(&screen, '❯', 2, 0, 8), Composer::EmptyCandidate);
    }
}

#[test]
fn differently_sized_later_divider_is_not_a_safe_footer() {
    assert_ne!(
        classify("❯\u{a0}\n────────\n─────────\nstatus\n", '❯', 2, 0, 8),
        Composer::EmptyCandidate
    );
}

#[test]
fn codex_boundary_needs_zero_cell_separator_and_trusted_footer() {
    let prompt = "› \x1b[2mhint\x1b[0m\n";
    assert_eq!(
        classify(&format!("{prompt}\n  Fast dynamic footer\n"), '›', 2, 0, 80),
        Composer::EmptyCandidate
    );
    for tail in [
        " \n  Fast dynamic footer\n",
        "\n  \x1b[48;2;2;2;2mfooter\n",
        "\n  footer\ntext\n",
        "\n  \x1b[08mhidden\n",
    ] {
        assert_ne!(
            classify(&format!("{prompt}{tail}"), '›', 2, 0, 80),
            Composer::EmptyCandidate
        );
    }
}

#[test]
fn wrapped_dim_candidates_preserve_style_and_cursor_rows() {
    for (glyph, screen) in [
        ('❯', "❯ \x1b[2mapp ghost\n  continuation\x1b[0m\n────────\nstatus\n"),
        ('›', "› \x1b[2mapp ghost\n  continuation\x1b[0m\n\x1b[49m  Fast off · test · Context 0% used\n"),
    ] {
        assert_eq!(classify(screen, glyph, 2, 0, 8), Composer::EmptyCandidate);
        assert_eq!(classify(screen, glyph, 4, 1, 8), Composer::EmptyCandidate);
        assert_ne!(classify(&screen.replace("continuation", "\x1b[22mtyped"), glyph, 4, 1, 8), Composer::EmptyCandidate);
        assert_ne!(classify(&screen.replace("continuation", " "), glyph, 2, 0, 8), Composer::EmptyCandidate);
    }
}

#[test]
fn ghost_candidate_is_not_limited_to_empty_cursor_column() {
    assert_eq!(
        classify("› \x1b[2mghost\x1b[0m\n\n  footer\n", '›', 3, 0, 80),
        Composer::EmptyCandidate
    );
}

#[test]
fn malformed_styles_and_extreme_cursors_do_not_panic() {
    let alphabet = [
        "\x1b", "[", "m", ";", ":", "0", "8", "2", "❯", "›", "🦀", "\n", " ",
    ];
    let mut state = 0x87654321u32;
    for length in 0..256 {
        let mut capture = String::new();
        for _ in 0..length {
            state ^= state << 13;
            state ^= state >> 17;
            state ^= state << 5;
            capture.push_str(alphabet[state as usize % alphabet.len()]);
        }
        for (x, y) in [(0, 0), (2, 1), (usize::MAX, usize::MAX)] {
            assert!(std::panic::catch_unwind(|| classify(&capture, '❯', x, y, 8)).is_ok());
        }
        assert!(std::panic::catch_unwind(|| row(&capture)).is_ok());
    }
}

#[test]
fn cursor_geometry_rejects_impossible_coordinates_but_allows_pending_wrap() {
    for (screen, y) in [
        ("› \x1b[2mghost\x1b[0m\n\n  footer\n", 0),
        ("› \x1b[2mghost\n  continuation\x1b[0m\n\x1b[49m  Fast off · test · Context 0% used\n", 1),
    ] {
        assert_eq!(classify(screen, '›', 8, y, 8), Composer::EmptyCandidate);
        for (x, width) in [(0, 0), (9, 8), (usize::MAX, 8)] {
            assert_eq!(classify(screen, '›', x, y, width), Composer::Unrecognized);
        }
    }
}

#[test]
fn zero_width_space_does_not_supply_visible_ghost_or_footer_evidence() {
    assert_eq!(marker("› \x1b[2m\u{200b}\x1b[0m\n", '›'), Ok(Marker::Draft));
    for screen in [
        "› \x1b[2m\u{200b}\x1b[0m\n\n  footer\n",
        "› \x1b[2mghost\x1b[0m\n\n  \u{200b}\n",
        "› \x1b[2mghost\x1b[0m\n\n  \u{200b}footer\n",
        "› \x1b[2mghost\n  \u{200b}\x1b[0m\n\x1b[49m  footer\n",
    ] {
        assert_ne!(classify(screen, '›', 2, 0, 80), Composer::EmptyCandidate);
    }
    assert_eq!(marker("› \x1b[2mghost\x1b[22m\u{200b}\n", '›'), Ok(Marker::Draft));
    assert_eq!(classify("› \x1b[2m会👩\u{200d}💻\x1b[0m\n\n  状態\n", '›', 2, 0, 80), Composer::EmptyCandidate);
}

#[test]
fn owned_native_codex_startup_draft_is_not_an_empty_candidate() {
    let draft = "WARNING: proceeding, even though we could not create PATH aliases: Operation not permitted (os error 1)\n\n  \x1b[38;2;99;168;248m>_ \x1b[1m\x1b[39mOpenAI Codex\x1b[0;2m (v0.162.1)\x1b[0m\n     \x1b[2m~/desk/tmp/keeper2-native\x1b[0m\n\n\n\x1b[1m›\x1b[0m keeper2-owned-draft 会🦀\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
    let cleared = "WARNING: proceeding, even though we could not create PATH aliases: Operation not permitted (os error 1)\n\n  \x1b[38;2;99;168;248m>_ \x1b[1m\x1b[39mOpenAI Codex\x1b[0;2m (v0.162.1)\x1b[0m\n     \x1b[2m~/desk/tmp/keeper2-native\x1b[0m\n\n\n\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
    assert_eq!(classify(draft, '›', 26, 6, 229), Composer::Draft);
    assert_eq!(classify(cleared, '›', 2, 6, 229), Composer::EmptyCandidate);
}

#[test]
fn codex_startup_placeholder_requires_dim_suffix_and_blank_tail() {
    let ghost = "› \x1b[2mAsk Codex to do anything\x1b[0m\n\n\n";
    assert_eq!(classify(ghost, '›', 2, 0, 80), Composer::EmptyCandidate);
    for screen in [
        "› Ask Codex to do anything\n\n",
        "› \x1b[2mAsk Codex\x1b[22m to do anything\n\n",
        "› \x1b[38;2;2;2;2mAsk Codex to do anything\x1b[0m\n\n",
        "› \x1b[2mAsk Codex to do anything\x1b[0m\n \n",
        "› \x1b[2mAsk Codex to do anything\x1b[0m\n  typed continuation\n",
        "› \x1b[2munknown hint\x1b[0m\n\n",
    ] {
        assert_ne!(classify(screen, '›', 2, 0, 80), Composer::EmptyCandidate);
    }
    assert_ne!(classify(ghost, '›', 2, 1, 80), Composer::EmptyCandidate);
}

#[test]
fn basic_bright_and_reverse_footer_backgrounds_are_not_trusted() {
    for style in ["41", "47", "101", "107", "7", "1;41", "2;101"] {
        let screen = format!("› \x1b[2mghost\x1b[0m\n\n\x1b[{style}m  footer\n");
        assert_ne!(
            classify(&screen, '›', 2, 0, 80),
            Composer::EmptyCandidate,
            "{style}"
        );
    }
    for style in ["39", "49", "27"] {
        let screen = format!("› \x1b[2mghost\x1b[0m\n\n\x1b[{style}m  footer\n");
        assert_eq!(
            classify(&screen, '›', 2, 0, 80),
            Composer::EmptyCandidate,
            "{style}"
        );
    }
}
#[test]
fn truecolor_two_is_not_dim() {
    assert!(!row("\x1b[48;2;2;2;2mdraft").unwrap().visible_text_is_dim);
    assert!(!row("\x1b[38:2::2:2:2mdraft").unwrap().visible_text_is_dim);
}
#[test]
fn conceal_and_controls_are_not_trusted() {
    for raw in [
        "\x1b[08mhidden\x1b[0m",
        "\x1b[2J",
        "\x1b]8;;url\x07text",
        "\x1b[",
        "\x1b[38;2;1mtext",
    ] {
        assert!(row(raw).is_err(), "{raw:?}");
    }
}
