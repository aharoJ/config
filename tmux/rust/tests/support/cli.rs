use super::*;
fn args(s: &[&str]) -> Vec<String> {
    s.iter().map(|s| s.to_string()).collect()
}
#[test]
fn grammar() {
    let mut env = Env::new();
    assert_eq!(parse("relay", &[], &env).unwrap(), Operation::Help);
    for surface in ["relay", "cc-msg", "codex-send", "codex-send-to"] {
        assert_eq!(
            parse(surface, &args(&["--help"]), &env).unwrap(),
            Operation::Help
        );
    }
    assert!(parse("cc-msg", &args(&["x"]), &env).is_err());
    env.insert("CC_MSG_SESSION".into(), "s:#".into());
    env.insert("CC_MSG_WINDOW".into(), "w,}".into());
    env.insert("CC_MSG_PANE".into(), "%12".into());
    assert_eq!(
        parse("cc-msg", &args(&["--", "--keys", "#x"]), &env).unwrap(),
        Operation::Send {
            client: Some('❯'),
            session: "s:#".into(),
            window: "w,}".into(),
            pane: Some(target::PaneId(12)),
            message: Some("--keys #x".into())
        }
    );
    assert!(parse("cc-msg", &args(&["--keys"]), &env).is_err());
    env.insert("CODEX_SEND_SESSION".into(), "s".into());
    assert!(
        matches!(parse("codex-send",&[],&env).unwrap(),Operation::Send{window,message:None,..} if window=="codex")
    );
    assert!(matches!(
        parse("codex-send-to", &args(&["w"]), &env).unwrap(),
        Operation::Send { message: None, .. }
    ));
    for op in ["prune", "recover"] {
        assert!(parse(
            "relay",
            &args(&[op, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]),
            &env
        )
        .is_err());
    }
    assert!(parse("relay", &args(&["status", "prefix"]), &env).is_err());
    assert!(parse(
        "relay",
        &args(&["read", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "bogus"]),
        &env
    )
    .is_err());
    let mut out = Vec::new();
    let mut err = Vec::new();
    assert_eq!(
        execute(
            Operation::Help,
            &Env::new(),
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        0
    );
    assert_eq!(
        execute(
            Operation::Send {
                client: None,
                session: "s".into(),
                window: "w".into(),
                pane: None,
                message: Some("\u{1b}bad".into())
            },
            &Env::new(),
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        1
    );
    assert!(String::from_utf8(err).unwrap().contains("control"));
}
#[test]
fn agy_route_uses_documented_context() {
    let env = Env::from([
        ("AGY_SEND_SESSION".into(), "session".into()),
        ("AGY_SEND_PANE".into(), "%42".into()),
    ]);
    assert_eq!(
        parse("agy-send-to", &args(&["seat", "#test", "message"]), &env).unwrap(),
        Operation::Send {
            client: Some('>'),
            session: "session".into(),
            window: "seat".into(),
            pane: Some(target::PaneId(42)),
            message: Some("#test message".into())
        }
    );
    assert!(
        matches!(parse("agy-send-to",&args(&["seat"]),&Env::new()).unwrap(),Operation::Send{client:Some('>'),session,message:None,..}if session.is_empty())
    );
    assert!(parse("agy-send-to", &[], &env).is_err());
}
#[test]
fn exits_announcements() {
    for (state, code) in [
        (State::PendingNoInput, 6),
        (State::InputIntent, 4),
        (State::Pasted, 4),
        (State::WaitingForFocusRelease, 4),
        (State::SubmitIntent, 4),
        (State::InputUnknown, 4),
        (State::TerminalNoInput, 1),
        (State::Submitted, 0),
    ] {
        assert_eq!(outcome(state), code);
    }
    for n in ["0", "-1", "true", "inf", "3600001"] {
        assert!(wait_ms(&Env::from([("ANGELSTAR_RELAY_WAIT_MS".into(), n.into())])).is_err());
    }
    assert_eq!(wait_ms(&Env::new()).unwrap(), 30000);
}
#[test]
fn every_non_success_state_has_a_durable_reason() {
    for state in [
        State::PendingNoInput,
        State::InputIntent,
        State::Pasted,
        State::WaitingForFocusRelease,
        State::SubmitIntent,
        State::InputUnknown,
        State::TerminalNoInput,
        State::Refused,
    ] {
        let attempt = store::Attempt {
            id: "a".repeat(32),
            archive: "b".repeat(32),
            request: "request".into(),
            peer: store::Peer {
                socket_device: 1,
                socket_inode: 2,
                server_generation: 3,
                session: 4,
                window: 5,
                pane: 6,
                pane_generation: 7,
            },
            attribution: store::Attribution {
                source: store::Source::Tool,
                label: "relay".into(),
                codes: vec![],
            },
            history: vec![store::Transition {
                sequence: 0,
                predecessor: None,
                state,
                evidence: store::Evidence::default(),
            }],
        };
        assert!(!attempt.reason().unwrap().is_empty(), "{state:?}");
    }
}
#[test]
fn read_status() {
    use std::os::unix::fs::DirBuilderExt;
    let path = PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk/tmp")
        .join(format!("k50-cli-{}", runtime::fresh_id().unwrap()));
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&path)
        .unwrap();
    let mut store = store::Store::open(&path).unwrap();
    let attr = store::Attribution {
        source: store::Source::Tool,
        label: "relay".into(),
        codes: vec![store::Code {
            value: "explicit".into(),
            generated: false,
        }],
    };
    let archive = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let attempt = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    let p = store
        .publish(
            archive,
            b" \n#explicit\t original",
            b"relay: #explicit original",
            attr,
        )
        .unwrap();
    let peer = store::Peer {
        socket_device: 1,
        socket_inode: 2,
        server_generation: 3,
        session: 4,
        window: 5,
        pane: 6,
        pane_generation: 7,
    };
    let mut handle = store
        .accept(
            p,
            store::Acceptance {
                id: attempt,
                request: "request",
                peer,
            },
        )
        .unwrap();
    let env = Env::from([(
        "ANGELSTAR_RELAY_STORE".into(),
        path.to_str().unwrap().into(),
    )]);
    let mut out = Vec::new();
    let mut err = Vec::new();
    assert_eq!(
        execute(
            Operation::Read(archive.into(), false),
            &env,
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        0
    );
    assert_eq!(out, b" \n#explicit\t original");
    out.clear();
    assert_eq!(
        execute(
            Operation::Status(attempt.into()),
            &env,
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        0
    );
    let value: serde_json::Value = serde_json::from_slice(&out).unwrap();
    assert_eq!(value["state"], "pending-no-input");
    assert_eq!(value["receipt"], "unproved");
    submit_fixture(&mut store, &mut handle, "relay: #explicit original");
    struct Broken;
    impl Write for Broken {
        fn write(&mut self, _: &[u8]) -> std::io::Result<usize> {
            Err(std::io::ErrorKind::BrokenPipe.into())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    assert_eq!(
        announcement(&mut store, attempt, &mut Broken, &mut err, false),
        0
    );
    assert_eq!(store.attempt(attempt).unwrap().state(), State::Submitted);
}

fn submit_fixture(store: &mut store::Store, handle: &mut store::AttemptHandle, wire: &str) {
    let mut evidence = store::Evidence {
        capacity: Some(store::Capacity {
            width: 80,
            height: 24,
            cursor_x: 2,
            cursor_y: 0,
            pointer: wire.into(),
            cells: Some(25),
            byte_limit: Some(77),
            cell_limit: Some(77),
        }),
        budgets: Some(store::Budgets {
            stop_ms: 10,
            drain_ms: 10,
            reap_ms: 10,
            decision_ms: 30,
        }),
        ownership: Some(store::Ownership {
            owner_pid: 1,
            owner_generation: 2,
            child: None,
            socket_path: "/private/test/socket".into(),
            socket_device: 1,
            socket_inode: 2,
            server_generation: 3,
            lease_owner: 1,
            lease_nonce: "nonce".into(),
        }),
        composer_proof: Some("empty".into()),
        ..Default::default()
    };
    evidence.capacity.as_mut().unwrap().cells = Some(wire.len() as u64);
    store
        .transition(handle, State::InputIntent, evidence.clone())
        .unwrap();
    evidence.ownership.as_mut().unwrap().child = Some((3, 4));
    store
        .transition(handle, State::InputIntent, evidence.clone())
        .unwrap();
    evidence.paste_proof = Some("exact".into());
    store.transition(handle, State::Pasted, evidence).unwrap();
    store
        .transition(
            handle,
            State::SubmitIntent,
            store::Evidence {
                composer_proof: Some("exact".into()),
                boundary: Some(store::SubmissionBoundary {
                    epoch: 7,
                    watermark: 0,
                }),
                ..Default::default()
            },
        )
        .unwrap();
    store
        .transition(
            handle,
            State::Submitted,
            store::Evidence {
                submission_proof: Some("guarded Enter".into()),
                ..Default::default()
            },
        )
        .unwrap();
}

#[test]
fn cc_route_first_word_refuses() {
    let env = Env::from([
        ("CC_MSG_SESSION".into(), "s".into()),
        ("CC_MSG_WINDOW".into(), "w".into()),
    ]);
    let snapshot = target::Snapshot::parse(b"$0\t@1\t%2\t42\t0\t7:session6:window\n").unwrap();
    for words in [
        args(&["session:window", "task"]),
        args(&["--", "session:window"]),
    ] {
        assert!(cc_positional_target(&words, &snapshot));
    }
    for words in [
        args(&["Explain", "session:window"]),
        args(&["Note: x"]),
        args(&["Note:", "x"]),
        args(&["a: b c"]),
        args(&["a:", "b", "c"]),
        args(&["https://example.test/a:b"]),
        args(&["15:18"]),
        args(&["not-live:target", "task"]),
        args(&["session:window task"]),
    ] {
        assert!(!cc_positional_target(&words, &snapshot), "{words:?}");
        for surface in ["cc-msg", "codex-send", "codex-send-to"] {
            let mut argv = words.clone();
            if surface == "codex-send-to" {
                argv.insert(0, "target".into());
            }
            assert!(
                matches!(parse(surface, &argv, &env).unwrap(), Operation::Send { message: Some(message), .. } if message == words.join(" "))
            );
        }
    }
}

fn reader_line(output: &str) -> Option<(&str, &str, &str)> {
    let line = output.strip_suffix('\n').unwrap_or(output);
    if line.contains(['\r', '\n']) {
        return None;
    }
    let (head, path) = line.strip_prefix("relay: ")?.split_once("; record ")?;
    let (id, state) = head.split_once(' ')?;
    if id.len() != 32
        || !id
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        || state.is_empty()
        || !state.bytes().all(|b| b.is_ascii_lowercase())
        || path.is_empty()
    {
        return None;
    }
    Some((id, state, path))
}

#[test]
fn unchanged_reader_parses() {
    use std::os::unix::fs::DirBuilderExt;
    let tasks = [
        ("Read TASK.md in this folder and execute it.", true),
        ("reply READY, read nothing", true),
        (
            "#panel-start Read PROMPT.md in this folder and follow it exactly.",
            false,
        ),
    ];
    for (task, generated) in tasks {
        let path = target::account_home()
            .unwrap()
            .join("desk/tmp")
            .join(format!("s9x-reader-{}", runtime::fresh_id().unwrap()));
        std::fs::DirBuilder::new()
            .mode(0o700)
            .create(&path)
            .unwrap();
        let id = runtime::fresh_id().unwrap();
        let message = if generated {
            format!("#{} {task}", &id[..6])
        } else {
            task.into()
        };
        let wire = format!("relay: {message}");
        let mut store = store::Store::open(&path).unwrap();
        let publication = store
            .publish(
                &runtime::fresh_id().unwrap(),
                task.as_bytes(),
                wire.as_bytes(),
                store::Attribution {
                    source: store::Source::Tool,
                    label: "relay".into(),
                    codes: vec![store::Code {
                        value: if generated {
                            id[..6].into()
                        } else {
                            "panel-start".into()
                        },
                        generated,
                    }],
                },
            )
            .unwrap();
        let mut handle = store
            .accept(
                publication,
                store::Acceptance {
                    id: &id,
                    request: &id,
                    peer: store::Peer {
                        socket_device: 1,
                        socket_inode: 2,
                        server_generation: 3,
                        session: 4,
                        window: 5,
                        pane: 6,
                        pane_generation: 7,
                    },
                },
            )
            .unwrap();
        submit_fixture(&mut store, &mut handle, &wire);
        let expected_target = store::ReaderTarget {
            session_name: "net".into(),
            window_name: "reader".into(),
            pane_id: "%6".into(),
            pane_pid: "123".into(),
        };
        let (state, record_path) = store
            .reader_record(&id, expected_target.clone(), message.clone())
            .unwrap();
        let mut output = Vec::new();
        write_reader_announcement(&mut output, &id, state, &record_path).unwrap();
        let output = String::from_utf8(output).unwrap();
        let (parsed_id, parsed_state, parsed_path) = reader_line(&output).unwrap();
        let record: store::ReaderRecord =
            serde_json::from_slice(&std::fs::read(parsed_path).unwrap()).unwrap();
        assert_eq!(parsed_id, id);
        assert_eq!(parsed_state, "delivered");
        assert_eq!(record.state, "delivered");
        assert_eq!(record.payload, wire);
        assert_eq!(
            record.payload,
            format!("{}: {}", record.label, record.message)
        );
        assert_eq!(record.id, parsed_id);
        assert_eq!(record.message, message);
        assert!(!record.operator && !record.literal);
        assert_eq!(record.target, expected_target);
        if generated {
            assert_eq!(record.message, format!("#{} {task}", &record.id[..6]));
            if task.starts_with("reply READY") {
                let neutral = record
                    .payload
                    .strip_suffix(" reply READY, read nothing")
                    .unwrap();
                let (label, code) = neutral.rsplit_once(": #").unwrap();
                assert!(!label.is_empty() && !label.contains(['\r', '\n']));
                assert_eq!(code, &parsed_id[..6]);
            }
        } else {
            let panel_path = output
                .split_once("; record ")
                .unwrap()
                .1
                .strip_suffix('\n')
                .unwrap();
            assert!(panel_path.starts_with('/'));
            assert_eq!(panel_path, parsed_path);
            assert_eq!(record.message, task);
        }
        drop(store);
        let mut reopened = store::Store::open(&path).unwrap();
        assert_eq!(reopened.attempt(&id).unwrap().state(), State::Submitted);
        let mut changed = record.clone();
        changed.payload.push('!');
        std::fs::write(&record_path, serde_json::to_vec(&changed).unwrap()).unwrap();
        assert!(reopened.attempt(&id).is_err());
        drop(reopened);
        std::fs::remove_dir_all(path).unwrap();
    }
    for line in [
        "relay: nope delivered; record /r\n",
        "relay: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa delivered; record /r\n\n",
        "relay: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa delivered; record /r\r\n",
    ] {
        assert!(reader_line(line).is_none());
    }
}

#[test]
fn codex_routing_uses_caller_session_when_unset() {
    let mut env = Env::new();
    for surface in ["codex-send", "codex-send-to"] {
        let argv = if surface == "codex-send" {
            args(&["--", "task"])
        } else {
            args(&["sol", "--", "task"])
        };
        assert!(
            matches!(parse(surface, &argv, &env).unwrap(), Operation::Send { session, .. } if session.is_empty())
        );
        env.insert("CODEX_SEND_SESSION".into(), "".into());
        assert!(
            matches!(parse(surface, &argv, &env).unwrap(), Operation::Send { session, .. } if session.is_empty())
        );
        env.insert("CODEX_SEND_SESSION".into(), "explicit".into());
        assert!(
            matches!(parse(surface, &argv, &env).unwrap(), Operation::Send { session, .. } if session == "explicit")
        );
        env.clear();
    }
    env.insert("CODEX_SEND_WINDOW".into(), "".into());
    env.insert("CODEX_SEND_PANE".into(), "".into());
    assert!(
        matches!(parse("codex-send", &args(&["task"]), &env).unwrap(), Operation::Send { window, pane: None, .. } if window == "codex")
    );
    env.insert("CODEX_SEND_WINDOW".into(), "other".into());
    assert!(
        matches!(parse("codex-send-to", &args(&["sol", "task"]), &env).unwrap(), Operation::Send { window, .. } if window == "sol")
    );
}

#[test]
fn default_store_uses_desk_tmp() {
    use std::os::unix::fs::{DirBuilderExt, PermissionsExt};
    let home = target::account_home()
        .unwrap()
        .join("desk/tmp")
        .join(format!("s10x-home-{}", runtime::fresh_id().unwrap()));
    for path in [&home, &home.join("desk"), &home.join("desk/tmp")] {
        std::fs::DirBuilder::new().mode(0o700).create(path).unwrap();
    }
    let mut out = Vec::new();
    let mut err = Vec::new();
    assert_eq!(
        execute(
            Operation::Status("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".into()),
            &Env::from([("HOME".into(), home.to_str().unwrap().into())]),
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        1
    );
    assert!(home.join("desk/tmp/relay-rust-store/ledger.json").is_file());
    assert_eq!(
        std::fs::metadata(home.join("desk/tmp/relay-rust-store"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o700
    );
    assert!(!home.join("desk/relay-rust-store").exists());
    std::fs::remove_dir_all(home).unwrap();
}
