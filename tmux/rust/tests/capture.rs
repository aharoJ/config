use angelstar_runtime::target::*;

fn row(
    session: u64,
    window: u64,
    pane: u64,
    pid: &str,
    dead: &str,
    session_name: &str,
    window_name: &str,
) -> String {
    format!(
        "${session}\t@{window}\t%{pane}\t{pid}\t{dead}\t{}:{session_name}{}:{window_name}\n",
        session_name.len(),
        window_name.len()
    )
}
#[test]
fn capture_resolves_exact_ids() {
    let bytes = row(2, 8, 10, "123", "0", "config::tmux-to-rust", "codex");
    let s = Snapshot::parse(bytes.as_bytes()).unwrap();
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "codex", None)
            .unwrap()
            .selector(),
        "%10"
    );
}
#[test]
fn unicode_newlines_and_delimiters_are_name_data() {
    let a = "会:#{x}\n\t'";
    let b = "win:🦀\n5:x";
    let bytes = row(2, 8, 10, "123", "0", a, b);
    let s = Snapshot::parse(bytes.as_bytes()).unwrap();
    assert_eq!(resolve(&s, a, b, None).unwrap().selector(), "%10");
}
#[test]
fn linked_window_rows_do_not_duplicate_panes() {
    let bytes = row(2, 8, 10, "123", "0", "a", "w") + &row(3, 8, 10, "123", "0", "b", "w");
    let s = Snapshot::parse(bytes.as_bytes()).unwrap();
    assert_eq!(resolve(&s, "b", "w", None).unwrap().selector(), "%10");
}
#[test]
fn truncated_name_is_invalid() {
    let bytes = row(2, 8, 10, "123", "0", "a", "w");
    assert!(matches!(
        Snapshot::parse(&bytes.as_bytes()[..bytes.len() - 2]),
        Err(Error::InvalidCapture)
    ));
}
#[test]
fn boolean_pid_is_not_numeric() {
    assert!(matches!(
        Snapshot::parse(row(2, 8, 10, "true", "0", "a", "w").as_bytes()),
        Err(Error::InvalidCapture)
    ));
}
#[test]
fn unknown_dead_flag_is_invalid() {
    assert!(matches!(
        Snapshot::parse(row(2, 8, 10, "123", "2", "a", "w").as_bytes()),
        Err(Error::InvalidCapture)
    ));
}
#[test]
fn conflicting_session_names_are_invalid() {
    let bytes = row(2, 8, 10, "123", "0", "a", "w") + &row(2, 9, 11, "124", "0", "other", "v");
    assert!(matches!(
        Snapshot::parse(bytes.as_bytes()),
        Err(Error::InvalidCapture)
    ));
}
#[test]
fn conflicting_pane_generations_are_invalid() {
    let bytes = row(2, 8, 10, "123", "0", "a", "w") + &row(2, 8, 10, "999", "0", "a", "w");
    assert!(matches!(
        Snapshot::parse(bytes.as_bytes()),
        Err(Error::InvalidCapture)
    ));
}
#[test]
fn many_windows_remain_exact() {
    let mut bytes = String::new();
    for id in 1..=1000 {
        bytes.push_str(&row(2, id, id, "123", "0", "a", &format!("w{id}")));
    }
    let snapshot = Snapshot::parse(bytes.as_bytes()).unwrap();
    assert_eq!(snapshot.windows[&SessionId(2)].len(), 1000);
    assert_eq!(
        resolve(&snapshot, "a", "w1000", None).unwrap().pane.id,
        PaneId(1000)
    );
}
#[test]
fn malformed_bytes_do_not_panic() {
    let mut state = 0x12345678u32;
    for length in 0..128 {
        let bytes: Vec<u8> = (0..length)
            .map(|_| {
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                state as u8
            })
            .collect();
        let _ = Snapshot::parse(&bytes);
    }
}

#[test]
fn nonempty_prefixes_of_unicode_frame_are_invalid() {
    let bytes = row(2, 8, 10, "123", "0", "会\t:\n🦀", "w\n:\t");
    for end in 1..bytes.len() {
        let result = std::panic::catch_unwind(|| Snapshot::parse(&bytes.as_bytes()[..end]));
        assert!(matches!(result, Ok(Err(Error::InvalidCapture))), "{end}");
    }
}

#[test]
fn empty_snapshot_cannot_resolve() {
    let snapshot = Snapshot::parse(b"").unwrap();
    assert_eq!(
        resolve(&snapshot, "s", "w", None),
        Err(Error::MissingSession)
    );
}

#[test]
fn revalidate_rejects_same_name_recreation() {
    let snapshot = Snapshot::parse(row(2, 8, 10, "123", "0", "s", "w").as_bytes()).unwrap();
    let target = resolve(&snapshot, "s", "w", None).unwrap();
    for bytes in [
        row(3, 8, 10, "123", "0", "s", "w"),
        row(2, 9, 10, "123", "0", "s", "w"),
        row(2, 8, 10, "124", "0", "s", "w"),
        row(2, 8, 10, "123", "1", "s", "w"),
    ] {
        let current = Snapshot::parse(bytes.as_bytes()).unwrap();
        assert!(revalidate(&current, &target).is_err());
    }
}

#[test]
fn linked_window_two_panes_requires_id() {
    let bytes = row(2, 8, 10, "123", "0", "a", "w")
        + &row(2, 8, 11, "124", "0", "a", "w")
        + &row(3, 8, 10, "123", "0", "b", "w")
        + &row(3, 8, 11, "124", "0", "b", "w");
    let snapshot = Snapshot::parse(bytes.as_bytes()).unwrap();
    for session in ["a", "b"] {
        assert_eq!(
            resolve(&snapshot, session, "w", None),
            Err(Error::AmbiguousPane)
        );
        for pane in [10, 11] {
            assert_eq!(
                resolve(&snapshot, session, "w", Some(PaneId(pane)))
                    .unwrap()
                    .selector(),
                format!("%{pane}")
            );
        }
    }
    let conflict = bytes + &row(3, 9, 10, "123", "0", "b", "other");
    assert!(matches!(
        Snapshot::parse(conflict.as_bytes()),
        Err(Error::InvalidCapture)
    ));
}

#[test]
fn identical_rows_and_row_order_are_stable() {
    let a = row(2, 8, 10, "123", "0", "a", "w");
    let b = row(3, 8, 10, "123", "0", "b", "w");
    let c = row(2, 9, 11, "124", "0", "a", "v");
    let expected = resolve(
        &Snapshot::parse(format!("{a}{b}{c}").as_bytes()).unwrap(),
        "a",
        "w",
        None,
    )
    .unwrap();
    for bytes in [format!("{c}{b}{a}"), format!("{b}{a}{a}{c}{b}")] {
        assert_eq!(
            resolve(&Snapshot::parse(bytes.as_bytes()).unwrap(), "a", "w", None).unwrap(),
            expected
        );
    }
    for changed in [
        row(2, 8, 10, "124", "0", "a", "w"),
        row(2, 8, 10, "123", "1", "a", "w"),
    ] {
        assert!(matches!(
            Snapshot::parse(format!("{a}{changed}").as_bytes()),
            Err(Error::InvalidCapture)
        ));
    }
}

#[test]
fn numeric_boundaries_are_framed() {
    let valid = row(u64::MAX, u64::MAX, u64::MAX, "4294967295", "0", "s", "w");
    let snapshot = Snapshot::parse(valid.as_bytes()).unwrap();
    assert_eq!(
        resolve(&snapshot, "s", "w", None).unwrap().pane.id,
        PaneId(u64::MAX)
    );
    for bytes in [
        valid.replacen("$18446744073709551615", "$18446744073709551616", 1),
        valid.replacen("@18446744073709551615", "@18446744073709551616", 1),
        valid.replacen("%18446744073709551615", "%18446744073709551616", 1),
        row(2, 8, 10, "4294967296", "0", "s", "w"),
        row(2, 8, 10, "0", "0", "s", "w"),
        row(2, 8, 10, "1x", "0", "s", "w"),
    ] {
        assert!(matches!(
            Snapshot::parse(bytes.as_bytes()),
            Err(Error::InvalidCapture)
        ));
    }
}

#[test]
fn large_linked_snapshot_remains_exact() {
    let mut bytes = String::new();
    for window in 1..=5000 {
        for (session, name) in [(2, "a"), (3, "b")] {
            for offset in 0..3 {
                bytes.push_str(&row(
                    session,
                    window,
                    window * 3 + offset,
                    "123",
                    "0",
                    name,
                    &format!("w{window}"),
                ));
            }
        }
    }
    let snapshot = Snapshot::parse(bytes.as_bytes()).unwrap();
    assert_eq!(snapshot.windows[&SessionId(2)].len(), 5000);
    assert_eq!(snapshot.windows[&SessionId(3)].len(), 5000);
    assert_eq!(snapshot.panes.values().map(Vec::len).sum::<usize>(), 15000);
    assert_eq!(
        resolve(&snapshot, "b", "w5000", Some(PaneId(15002)))
            .unwrap()
            .selector(),
        "%15002"
    );
}
