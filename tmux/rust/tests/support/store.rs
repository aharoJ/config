use super::*;
use std::os::unix::fs::DirBuilderExt;
fn root() -> PathBuf {
    let path = PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk/tmp")
        .join(format!("k50-store-{}", crate::runtime::fresh_id().unwrap()));
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&path)
        .unwrap();
    path
}
fn peer() -> Peer {
    Peer {
        socket_device: 1,
        socket_inode: 2,
        server_generation: 3,
        session: 4,
        window: 5,
        pane: 6,
        pane_generation: 7,
    }
}
fn attribution() -> Attribution {
    Attribution {
        source: Source::Tool,
        label: "relay".into(),
        codes: vec![Code {
            value: "x".into(),
            generated: true,
        }],
    }
}
const ARCHIVE: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const ATTEMPT: &str = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
fn accepted(path: &Path) -> (Store, AttemptHandle) {
    let mut store = Store::open(path).unwrap();
    let p = store
        .publish(ARCHIVE, b"#x original", b"relay: #x", attribution())
        .unwrap();
    let h = store
        .accept(
            p,
            Acceptance {
                id: ATTEMPT,
                request: "request",
                peer: peer(),
            },
        )
        .unwrap();
    (store, h)
}
fn intent() -> Evidence {
    Evidence {
        capacity: Some(Capacity {
            width: 80,
            height: 24,
            cursor_x: 2,
            cursor_y: 0,
            pointer: "relay: #x".into(),
            cells: Some(9),
            byte_limit: Some(77),
            cell_limit: Some(77),
        }),
        budgets: Some(Budgets {
            stop_ms: 10,
            drain_ms: 10,
            reap_ms: 10,
            decision_ms: 30,
        }),
        ownership: Some(Ownership {
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
    }
}
#[test]
fn store_integrity() {
    let path = root();
    let mut store = Store::open(&path).unwrap();
    assert!(store.attempt(ATTEMPT).is_err());
    drop(store);
    let valid = std::fs::read(path.join("ledger.json")).unwrap();
    let value: serde_json::Value = serde_json::from_slice(&valid).unwrap();
    for field in ["schema", "version", "revision", "archives", "attempts"] {
        let mut bad = value.clone();
        bad.as_object_mut().unwrap().remove(field);
        std::fs::write(path.join("ledger.json"), serde_json::to_vec(&bad).unwrap()).unwrap();
        assert!(Store::open(&path).is_err());
    }
    for raw in [b"{\"schema\":\"angelstar-store\",\"version\":1,\"version\":1,\"revision\":1,\"archives\":[],\"attempts\":[]}".as_slice(),b"{}",b"{",b"{\"schema\":\"angelstar-store\",\"version\":99,\"revision\":1,\"archives\":[],\"attempts\":[]}"]{std::fs::write(path.join("ledger.json"),raw).unwrap();assert!(Store::open(&path).is_err());}
    std::fs::write(path.join("ledger.json"), valid).unwrap();
    std::fs::set_permissions(
        path.join("ledger.json"),
        std::os::unix::fs::PermissionsExt::from_mode(0o644),
    )
    .unwrap();
    assert!(Store::open(&path).is_err());
}
#[test]
fn publication() {
    let path = root();
    let (mut store, _) = accepted(&path);
    assert_eq!(store.read(ARCHIVE, false).unwrap(), b"#x original");
    assert_eq!(store.read(ARCHIVE, true).unwrap(), b"relay: #x");
    assert!(matches!(
        store.publish(ARCHIVE, b"#x other", b"relay: #x", attribution()),
        Err(Error::Collision)
    ));
    std::fs::write(path.join(format!("{ARCHIVE}.wire")), b"corrupt").unwrap();
    assert!(store.read(ARCHIVE, true).is_err());
    let uncertain = root();
    let mut store = Store::open(&uncertain).unwrap();
    store
        .publish(ARCHIVE, b"#x original", b"relay: #x", attribution())
        .unwrap();
    {
        let _lock = store.lock().unwrap();
        store.ledger.archives[0].state = ArchiveState::Publishing;
        store.commit("diagnostic-publication").unwrap();
    }
    assert!(matches!(store.read(ARCHIVE, false), Err(Error::Unresolved(id)) if id == ARCHIVE));
    assert!(
        matches!(store.publish("cccccccccccccccccccccccccccccccc", b"#x original", b"relay: #x", attribution()), Err(Error::Unresolved(id)) if id == ARCHIVE)
    );
    assert!(store.ledger.attempts.is_empty());
    {
        let _lock = store.lock().unwrap();
        store.resolve_publication(ARCHIVE).unwrap();
    }
    assert_eq!(store.read(ARCHIVE, true).unwrap(), b"relay: #x");
    assert!(store.ledger.attempts.is_empty());
    let other = root();
    std::fs::write(other.join("legacy"), b"legacy").unwrap();
    assert!(Store::open(&other).is_err());
}
#[test]
fn lineage_reservations() {
    let path = root();
    let (mut store, mut handle) = accepted(&path);
    let mut evidence = intent();
    store
        .transition(&mut handle, State::InputIntent, evidence.clone())
        .unwrap();
    assert!(store
        .transition(&mut handle, State::Submitted, Evidence::default())
        .is_err());
    evidence.ownership.as_mut().unwrap().child = Some((3, 4));
    store
        .transition(&mut handle, State::InputIntent, evidence.clone())
        .unwrap();
    evidence.paste_proof = Some("exact".into());
    store
        .transition(&mut handle, State::Pasted, evidence)
        .unwrap();
    store.record_restart(ATTEMPT).unwrap();
    assert!(matches!(
        store.publish(
            "cccccccccccccccccccccccccccccccc",
            b"#x original",
            b"relay: #x",
            attribution()
        ),
        Err(Error::Unresolved(_))
    ));
    let p = store
        .publish(
            "dddddddddddddddddddddddddddddddd",
            b"other #x",
            b"relay: other #x",
            attribution(),
        )
        .unwrap();
    assert!(matches!(
        store.accept(
            p,
            Acceptance {
                id: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                request: "other",
                peer: peer()
            }
        ),
        Err(Error::CodeReserved)
    ));
    assert!(store
        .transition(&mut handle, State::SubmitIntent, Evidence::default())
        .is_err());
}
#[test]
fn serialization() {
    let path = root();
    let (mut store, _) = accepted(&path);
    let lock = store.root_lock().unwrap();
    assert!(Store::open(&path).is_err());
    drop(lock);
    let foreign = root();
    let (_other, mut handle) = accepted(&foreign);
    assert!(store
        .transition(&mut handle, State::InputIntent, intent())
        .is_err());
}
#[test]
fn brief_contention_waits_without_replaying_a_transition() {
    let path = root();
    let (mut store, mut handle) = accepted(&path);
    let lock = store.root_lock().unwrap();
    let worker = std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(120));
        drop(lock);
    });
    let start = std::time::Instant::now();
    store
        .transition(&mut handle, State::InputIntent, intent())
        .unwrap();
    worker.join().unwrap();
    assert!(start.elapsed() >= std::time::Duration::from_millis(100));
    assert!(start.elapsed() < std::time::Duration::from_secs(1));
    assert_eq!(store.attempt(ATTEMPT).unwrap().history.len(), 2);
}
#[test]
fn durable_barriers() {
    let path = root();
    let (mut store, mut handle) = accepted(&path);
    let mut e = intent();
    store
        .transition(&mut handle, State::InputIntent, e.clone())
        .unwrap();
    assert!(store
        .transition(&mut handle, State::Pasted, Evidence::default())
        .is_err());
    assert!(store
        .transition(&mut handle, State::TerminalNoInput, Evidence::default())
        .is_err());
    e.ownership.as_mut().unwrap().child = Some((3, 4));
    store
        .transition(&mut handle, State::InputIntent, e.clone())
        .unwrap();
    for flag in 0..4 {
        let mut proofs = [true; 4];
        proofs[flag] = false;
        assert!(store
            .transition(
                &mut handle,
                State::TerminalNoInput,
                Evidence {
                    no_effect_proof: Some(NoEffectProof::Rejected {
                        evidence: "rejection".into(),
                        producers_closed: proofs[0],
                        stopped: proofs[1],
                        reaped: proofs[2],
                        before_effect: proofs[3]
                    }),
                    ..Default::default()
                }
            )
            .is_err());
    }
    assert!(store
        .transition(
            &mut handle,
            State::TerminalNoInput,
            Evidence {
                no_effect_proof: Some(NoEffectProof::NeverLaunched {
                    evidence: "false".into()
                }),
                ..Default::default()
            }
        )
        .is_err());
    e.paste_proof = Some("exact".into());
    store.transition(&mut handle, State::Pasted, e).unwrap();
    store
        .transition(
            &mut handle,
            State::SubmitIntent,
            Evidence {
                composer_proof: Some("exact".into()),
                boundary: Some(SubmissionBoundary {
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
            Evidence {
                submission_proof: Some("guarded Enter".into()),
                ..Default::default()
            },
        )
        .unwrap();
    assert_eq!(
        store.record_restart(ATTEMPT).unwrap().state(),
        State::Submitted
    );
    store.diagnostics(ATTEMPT, vec!["warning".into()]).unwrap();
    assert_eq!(store.attempt(ATTEMPT).unwrap().state(), State::Submitted);
    assert!(store
        .transition(&mut handle, State::PendingNoInput, Evidence::default())
        .is_err());
    {
        let _lock = store.lock().unwrap();
        store.ledger.archives[0].state = ArchiveState::Pruned;
        store.commit("diagnostic-old-pruned-record").unwrap();
    }
    let retained = root();
    for suffix in ["original", "wire"] {
        std::fs::rename(
            path.join(format!("{ARCHIVE}.{suffix}")),
            retained.join(format!("{ARCHIVE}.{suffix}")),
        )
        .unwrap();
    }
    assert!(matches!(store.read(ARCHIVE, false), Err(Error::Pruned)));
    assert_eq!(store.attempt(ATTEMPT).unwrap().state(), State::Submitted);
    let ledger: serde_json::Value =
        serde_json::from_slice(&std::fs::read(path.join("ledger.json")).unwrap()).unwrap();
    for mutation in ["predecessor", "response-observed", "receipt"] {
        let mut bad = ledger.clone();
        let history = bad["attempts"][0]["history"].as_array_mut().unwrap();
        match mutation {
            "predecessor" => history[1]["predecessor"] = serde_json::json!(99),
            "response-observed" => {
                history.last_mut().unwrap()["state"] = serde_json::json!("response-observed")
            }
            _ => history.last_mut().unwrap()["evidence"]["receipt"] = serde_json::Value::Null,
        }
        std::fs::write(path.join("ledger.json"), serde_json::to_vec(&bad).unwrap()).unwrap();
        assert!(Store::open(&path).is_err(), "{mutation}");
    }
}
#[test]
fn restart_no_replay() {
    for state in [
        State::InputIntent,
        State::Pasted,
        State::WaitingForFocusRelease,
        State::SubmitIntent,
    ] {
        let a = Attempt {
            id: ATTEMPT.into(),
            archive: ARCHIVE.into(),
            request: "r".into(),
            peer: peer(),
            attribution: attribution(),
            history: vec![Transition {
                sequence: 0,
                predecessor: None,
                state,
                evidence: Evidence::default(),
            }],
        };
        assert_eq!(a.recovered_state(), State::InputUnknown);
    }
    let path = root();
    let (mut store, mut handle) = accepted(&path);
    store
        .transition(&mut handle, State::InputIntent, intent())
        .unwrap();
    drop(store);
    let mut store = Store::open(&path).unwrap();
    assert_eq!(
        store.record_restart(ATTEMPT).unwrap().state(),
        State::InputUnknown
    );
    assert!(store
        .transition(&mut handle, State::InputIntent, intent())
        .is_err());
}

#[test]
fn persisted_attribution_matches_archived_wire() {
    for mutation in ["code", "label"] {
        let path = root();
        let (store, _) = accepted(&path);
        drop(store);
        let ledger_path = path.join("ledger.json");
        let mut ledger: serde_json::Value =
            serde_json::from_slice(&std::fs::read(&ledger_path).unwrap()).unwrap();
        for kind in ["archives", "attempts"] {
            let a = &mut ledger[kind][0]["attribution"];
            if mutation == "code" {
                a["codes"][0]["value"] = serde_json::json!("y");
            } else {
                a["label"] = serde_json::json!("other");
                a["source"] = serde_json::json!({
                    "Known": {"identity": "1:2:3", "generation": 1, "label": "other"}
                });
            }
        }
        std::fs::write(&ledger_path, serde_json::to_vec(&ledger).unwrap()).unwrap();
        assert!(
            matches!(Store::open(&path), Err(Error::Corrupt)),
            "{mutation}"
        );
    }
}
