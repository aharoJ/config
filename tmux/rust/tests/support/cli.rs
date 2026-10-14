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
    assert!(parse("codex-send-to", &args(&["w"]), &env).is_err());
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
    let mut evidence = store::Evidence {
        capacity: Some(store::Capacity {
            width: 80,
            height: 24,
            cursor_x: 2,
            cursor_y: 0,
            pointer: "relay: #explicit original".into(),
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
    evidence.capacity.as_mut().unwrap().cells = Some("relay: #explicit original".len() as u64);
    store
        .transition(&mut handle, State::InputIntent, evidence.clone())
        .unwrap();
    evidence.ownership.as_mut().unwrap().child = Some((3, 4));
    store
        .transition(&mut handle, State::InputIntent, evidence.clone())
        .unwrap();
    evidence.paste_proof = Some("exact".into());
    store
        .transition(&mut handle, State::Pasted, evidence)
        .unwrap();
    store
        .transition(
            &mut handle,
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
            &mut handle,
            State::Submitted,
            store::Evidence {
                submission_proof: Some("guarded Enter".into()),
                ..Default::default()
            },
        )
        .unwrap();
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
