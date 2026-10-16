use super::*;
use std::os::unix::fs::OpenOptionsExt;
#[test]
fn agy_generation_accepts_only_a_fresh_own_receipt() {
    let capture = include_str!("../fixtures/legacy/rt2-agy-busy-generating.ansi");
    let y = capture
        .lines()
        .position(|row| row == "\x1b[94m>\x1b[39m")
        .unwrap();
    let wire = "RT2-workflow-14 probe: reply \"ack\" and take no action";
    let mut view = View {
        receipt: composer::receipt('>', capture, 2, y, 215, wire),
        bytes: Vec::new(),
        busy: true,
        copy: false,
        width: 215,
        height: 45,
        x: 2,
        y: y as u64,
    };
    assert!(view.accepted(Default::default(), (215, 45), false));
    assert!(!view.accepted(view.receipt, (215, 45), true));
    assert!(!view.accepted(Default::default(), (214, 45), true));
    view.copy = true;
    assert!(!view.accepted(Default::default(), (215, 45), true));
}
#[test]
fn captured_lab_unknown_requires_retired_producers_and_distinct_request() {
    let attempt: store::Attempt =
        serde_json::from_str(include_str!("../fixtures/lab-unsettled-attempt.json")).unwrap();
    assert_eq!(attempt.state(), State::InputUnknown);
    assert_eq!(attempt.id, "f91f272f2c10195960ae8d35074175f3");
    assert!(prior_blocker(&attempt, false, |_, _| false).is_none());
    assert!(prior_blocker(&attempt, true, |_, _| false)
        .unwrap()
        .contains("no replay"));
    for ownership in attempt
        .history
        .iter()
        .filter_map(|t| t.evidence.ownership.as_ref())
    {
        let mut identities = vec![(ownership.owner_pid, ownership.owner_generation)];
        identities.extend(ownership.child);
        for active in identities {
            assert!(
                prior_blocker(&attempt, false, |pid, generation| (pid, generation)
                    == active)
                .unwrap()
                .contains("still live")
            );
        }
    }
    let mut unproved = attempt.clone();
    for transition in &mut unproved.history {
        transition.evidence.ownership = None;
    }
    assert!(prior_blocker(&unproved, false, |_, _| false)
        .unwrap()
        .contains("retirement unproved"));
}
#[test]
#[ignore = "private lab target with a retired unknown owner and a cleared mark"]
fn lab_cleared_mark_after_retired_unknown() {
    if crate::test_server::supervised("runtime::tests::lab_cleared_mark_after_retired_unknown") {
        return;
    }
    let server = crate::test_server::Server::new();
    server.fixtures(&["lab", "lab-decoy"]);
    let ns = server.namespace();
    let mut store = Store::open(&server.root.join("lab-archive")).unwrap();
    let budgets = Budgets {
        stop_ms: 30,
        drain_ms: 30,
        reap_ms: 30,
        decision_ms: 90,
    };
    let prepared = Prepared::new(&ns, "private-k50", "lab", None, "#prior old request").unwrap();
    let mut old = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        b"#prior old request",
        budgets.clone(),
    )
    .unwrap();
    old.fixture = Some(server.root.join("lab.json"));
    let mut child = OwnedChild::spawn(Command::new("/bin/sleep").arg("0.1")).unwrap();
    let owner = child.identity.unwrap();
    while !child.poll().unwrap() {
        std::thread::sleep(Duration::from_millis(5));
    }
    let lease = identity::delivery_attest(ns.socket()).unwrap();
    let evidence = Evidence {
        capacity: Some(store::Capacity {
            width: 80,
            height: 24,
            cursor_x: 2,
            cursor_y: 0,
            pointer: old.prepared.wire.clone(),
            cells: Some(old.prepared.wire.len() as u64),
            byte_limit: Some(77),
            cell_limit: Some(77),
        }),
        budgets: Some(budgets.clone()),
        composer_proof: Some("captured empty composer".into()),
        ownership: Some(Ownership {
            owner_pid: owner.pid,
            owner_generation: owner.generation().unwrap(),
            child: None,
            socket_path: server.socket.to_string_lossy().into(),
            socket_device: old.peer.socket_device,
            socket_inode: old.peer.socket_inode,
            server_generation: old.peer.server_generation,
            lease_owner: lease["owner"].as_u64().unwrap() as u32,
            lease_nonce: lease["nonce"].as_str().unwrap().into(),
        }),
        ..Default::default()
    };
    old.commit(State::InputIntent, evidence).unwrap();
    old.unknown("failure cleanup: composer already empty; no removal input")
        .unwrap();
    let prior = old.id.clone();
    old.close().unwrap();
    drop(old);
    let prepared = Prepared::new(&ns, "private-k50", "lab", None, "#new distinct request").unwrap();
    let mut runtime =
        Runtime::accept(&ns, prepared, &mut store, b"#new distinct request", budgets).unwrap();
    runtime.fixture = Some(server.root.join("lab.json"));
    let deadline = Instant::now() + Duration::from_secs(5);
    while runtime.tick().unwrap() == State::PendingNoInput {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    runtime.close().unwrap();
    let observed = runtime.state;
    drop(runtime);
    assert_eq!(
        observed,
        State::Submitted,
        "retired unknown with cleared mark blocked a distinct request; evidence {}",
        server.root.display()
    );
    assert_eq!(store.attempt(&prior).unwrap().state(), State::InputUnknown);
    assert_eq!(fixture_state(&server, "lab")["submissions"], 1);
    assert_eq!(fixture_state(&server, "lab-decoy")["events"], 0);
    let prepared = Prepared::new(&ns, "private-k50", "lab", None, "#prior old request").unwrap();
    let replay = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        b"#prior old request",
        Budgets {
            stop_ms: 30,
            drain_ms: 30,
            reap_ms: 30,
            decision_ms: 90,
        },
    );
    assert!(replay.err().unwrap().contains("Unresolved"));
    assert_eq!(fixture_state(&server, "lab")["submissions"], 1);
    let peer = store.attempt(&prior).unwrap().peer;
    let mark = server.root.join(format!(
        "target-{}-{}-{}",
        peer.server_generation, peer.pane, peer.pane_generation
    ));
    std::fs::write(&mark, &prior).unwrap();
    let mut out = Vec::new();
    let mut err = Vec::new();
    let environment = std::collections::HashMap::from([
        (
            "ANGELSTAR_RELAY_STORE".into(),
            server.root.join("lab-archive").to_string_lossy().into(),
        ),
        (
            "ANGELSTAR_RELAY_SOCKET".into(),
            server.socket.to_string_lossy().into(),
        ),
    ]);
    assert_eq!(
        crate::cli::execute(
            crate::cli::Operation::Send {
                client: Some('›'),
                session: "private-k50".into(),
                window: "lab".into(),
                pane: None,
                message: Some("#blocked marked request".into())
            },
            &environment,
            &mut &b""[..],
            &mut out,
            &mut err
        ),
        1
    );
    let stderr = String::from_utf8(err).unwrap();
    assert!(stderr.contains("prior target effect unresolved"));
    let stdout = String::from_utf8(out).unwrap();
    let record = stdout.split("; record ").nth(1).unwrap().trim();
    let record: store::ReaderRecord =
        serde_json::from_slice(&std::fs::read(record).unwrap()).unwrap();
    assert!(stderr.contains(record.reason.as_deref().unwrap()));
    assert_eq!(record.state, "error");
    assert_eq!(std::fs::read_to_string(mark).unwrap(), prior);
    assert_eq!(fixture_state(&server, "lab")["submissions"], 1);
    println!("lab regression evidence {}", server.root.display());
}
#[test]
fn delivery_guard_accepts_literal_message_formats() {
    assert!(
        identity::validate_delivery(&["send-keys", "-t", "%7", "-N", "27", "BSpace"], true).is_ok()
    );
    for arguments in [
        ["send-keys", "-t", "%7", "-N", "0", "BSpace"],
        ["send-keys", "-t", "%7", "-N", "65536", "BSpace"],
        ["send-keys", "-t", "%7", "-N", "-1", "BSpace"],
        ["send-keys", "-t", "%7", "-N", "27", "C-u"],
    ] {
        assert!(identity::validate_delivery(&arguments, true).is_err());
    }
    assert!(
        identity::validate_delivery(&["send-keys", "-t", "%7", "-N", "27", "BSpace"], false)
            .is_err()
    );
    for payload in [
        "relay: #literal plain data",
        "relay: #literal explain #(literal)",
        "relay: #literal explain #{E:literal}",
        "relay: #literal explain #{T:literal}",
    ] {
        assert!(identity::validate_delivery(
            &[
                "set-buffer",
                "-b",
                "relay-0123456789abcdef0123456789abcdef",
                "--",
                payload
            ],
            false
        )
        .is_ok());
    }
    for args in [
        vec!["kill-server"],
        vec!["display-message", "-p", "#(unsafe)"],
        vec![
            "set-buffer",
            "-b",
            "relay-0123456789abcdef0123456789abcdef",
            "--",
            "bad\nline",
        ],
        vec![
            "if-shell",
            "-F",
            "-t",
            "%7",
            "1",
            "send-keys -t %7 Enter ; kill-server",
            "display-message -p refused",
        ],
    ] {
        assert!(identity::validate_delivery(&args, false).is_err());
    }
}
#[test]
fn observed_c16_uses_the_live_legacy_overflow_frame() {
    let label = "s15x-haiku-final (config-tt:s15x-haiku-final)";
    let codes = "#s15xhandoff";
    let path = identity::account_home()
        .unwrap()
        .join("desk/tmp/relay-rust-store/568aedc4474443452f6ad87924cddf42.original");
    let original = format!(
        "{label}: {codes} read and execute; do not forward: ~/desk/tmp/relay-rust-store/568aedc4474443452f6ad87924cddf42.original"
    );
    assert_eq!(original.len(), 163);
    let legacy = format!(
        "{label}: {codes} -- full: ~/desk/tmp/relay-rust-store/568aedc4474443452f6ad87924cddf42.original"
    );
    for width in [149, 183] {
        let capacity = store::Capacity {
            width,
            height: 45,
            cursor_x: 2,
            cursor_y: 42,
            pointer: legacy.clone(),
            cells: Some(legacy.len() as u64),
            byte_limit: Some(width - 3),
            cell_limit: Some(width - 3),
        };
        assert!(capacity.permits());
    }
    assert_eq!(overflow_pointer(label, codes, &path), legacy);
}
#[test]
fn envelope_capacity() {
    assert_eq!(normalize("  λ\n\t#x\u{1c} y  ").unwrap(), "λ #x y");
    for text in ["", " \n\t", "bad\u{1b}", "bad\0"] {
        assert!(normalize(text).is_err());
    }
    let mut capacity = store::Capacity {
        width: 20,
        height: 4,
        cursor_x: 2,
        cursor_y: 0,
        pointer: "relay: #x".into(),
        cells: Some(9),
        byte_limit: Some(9),
        cell_limit: Some(9),
    };
    assert!(capacity.permits());
    capacity.byte_limit = Some(8);
    assert!(!capacity.permits());
    capacity.byte_limit = Some(9);
    capacity.cells = None;
    assert!(!capacity.permits());
}
#[test]
fn captured_transition_needs_acceptance_or_exact_removal() {
    let wire = "sol (config-tt:sol): #rf-r1-p6 -- full: ~/desk/tmp/relay-rust-store/ddb758b0a3d63f5fe4f437d5395865d5.original";
    let capture = include_str!("../fixtures/claude-transition-staged.ansi");
    let observe = |capture: &str, x, y| {
        let (bytes, busy) = match composer::screen('❯', capture, x, y, 149, wire) {
            composer::Screen::Staged(bytes) => (bytes, false),
            composer::Screen::Empty => (Vec::new(), false),
            composer::Screen::Hold => (Vec::new(), true),
        };
        View {
            receipt: composer::receipt('❯', capture, x, y, 149, wire),
            bytes,
            busy,
            copy: false,
            x: x as u64,
            y: y as u64,
            width: 149,
            height: 45,
        }
    };
    let staged = observe(capture, 111, 29);
    assert_eq!(staged.bytes, wire.as_bytes());
    assert!(!staged.accepted(Default::default(), (149, 45), true));
    let cleared = observe(&capture.replace(wire, ""), 2, 29);
    assert!(!cleared.busy);
    assert!(cleared.accepted(Default::default(), (149, 45), true));
    assert!(!cleared.accepted(Default::default(), (149, 45), false));
    let changed = observe(&capture.replace(wire, &format!("{wire}!")), 112, 29);
    assert!(!changed.accepted(Default::default(), (149, 45), true));
    let queued = include_str!("../fixtures/claude-busy-queued-with-tip.ansi");
    let old_wire = "sol (config-tt:sol): #rf-p6 -- full: ~/desk/tmp/relay-rust-store/d1cc2d94966b184255b27c7813766208.original";
    let receipt = composer::receipt('❯', queued, 2, 28, 149, old_wire);
    let view = View {
        receipt,
        bytes: Vec::new(),
        busy: false,
        copy: false,
        x: 2,
        y: 28,
        width: 149,
        height: 45,
    };
    assert!(view.accepted(Default::default(), (149, 45), false));
    assert!(!view.accepted(receipt, (149, 45), false));
}
#[test]
#[ignore = "owned private guard transition, exactly-once submission and residue-free refusal"]
fn transition_guard_and_owned_refusal() {
    if crate::test_server::supervised("runtime::tests::transition_guard_and_owned_refusal") {
        return;
    }
    let server = crate::test_server::Server::new();
    server.fixtures(&["target", "remove", "decoy"]);
    let ns = server.namespace();
    let message = "#transition staged-message";
    let prepared = Prepared::new(&ns, "private-k50", "target", None, message).unwrap();
    let mut store = Store::open(&server.root.join("archive-transition")).unwrap();
    let budgets = Budgets {
        stop_ms: 30,
        drain_ms: 30,
        reap_ms: 30,
        decision_ms: 90,
    };
    let mut runtime = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        message.as_bytes(),
        budgets.clone(),
    )
    .unwrap();
    runtime.fixture = Some(server.root.join("target.json"));
    let mut inject = true;
    runtime.before_enter = Some(Box::new(|| {
        if inject {
            server.command(&["copy-mode", "-t", "private-k50:target"]);
            inject = false;
        }
        Ok(())
    }));
    assert_eq!(runtime.tick().unwrap(), State::WaitingForFocusRelease);
    assert_eq!(fixture_state(&server, "target")["submissions"], 0);
    assert!(!runtime.enter_pending);
    assert_eq!(runtime.tick().unwrap(), State::WaitingForFocusRelease);
    server.command(&["send-keys", "-t", "private-k50:target", "-X", "cancel"]);
    assert_eq!(runtime.tick().unwrap(), State::Submitted);
    let deadline = Instant::now() + Duration::from_secs(2);
    while fixture_state(&server, "target")["submissions"] != 1 {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    assert_eq!(runtime.tick().unwrap(), State::Submitted);
    assert_eq!(fixture_state(&server, "target")["submissions"], 1);
    runtime.close().unwrap();
    drop(runtime);
    let client = attached(&server, "remove");
    let message = "#remove staged-message";
    let prepared = Prepared::new(&ns, "private-k50", "remove", None, message).unwrap();
    let mut store = Store::open(&server.root.join("archive-remove")).unwrap();
    let mut runtime =
        Runtime::accept(&ns, prepared, &mut store, message.as_bytes(), budgets).unwrap();
    runtime.fixture = Some(server.root.join("remove.json"));
    assert_eq!(runtime.tick().unwrap(), State::WaitingForFocusRelease);
    runtime.close().unwrap();
    assert_eq!(runtime.state, State::Refused);
    assert_eq!(crate::cli::outcome(runtime.state), 1);
    assert_eq!(store::reader_state(runtime.state), "refused");
    assert_eq!(fixture_state(&server, "remove")["draft"], "");
    assert_eq!(fixture_state(&server, "remove")["submissions"], 0);
    assert_eq!(fixture_state(&server, "decoy")["events"], 0);
    drop(runtime);
    detach(client);
}
#[test]
fn owned_cleanup() {
    for n in [0, u64::MAX] {
        assert!(validate_budgets(&Budgets {
            stop_ms: n,
            drain_ms: 1,
            reap_ms: 1,
            decision_ms: 1
        })
        .is_err());
    }
    let budgets = Budgets {
        stop_ms: 20,
        drain_ms: 20,
        reap_ms: 20,
        decision_ms: 60,
    };
    validate_budgets(&budgets).unwrap();
    let mut command = Command::new("/bin/cat");
    command.stdin(Stdio::piped());
    let mut child = OwnedChild::spawn(&mut command).unwrap();
    let expected = child.identity.unwrap();
    let mut wrong = expected;
    wrong.start_microseconds = wrong.start_microseconds.wrapping_add(1);
    child.identity = Some(wrong);
    assert!(child.poll().is_err());
    child.identity = Some(expected);
    let start = Instant::now();
    let notes = child.cleanup(&budgets);
    assert!(child.status.is_some(), "{notes:?}");
    assert!(start.elapsed() < Duration::from_millis(500));
}
pub(super) fn fixture_view(
    ns: &Namespace,
    prepared: &Prepared,
    path: &std::path::Path,
) -> Result<View> {
    if path.parent() != ns.socket().parent() {
        return Err("fixture outside namespace".into());
    }
    let file = identity::open_at(
        ns.directory(),
        path.file_name().unwrap().to_str().unwrap(),
        libc::O_RDONLY,
    )?;
    let value: serde_json::Value = serde_json::from_reader(file).map_err(|e| e.to_string())?;
    let process =
        identity::kernel_process(prepared.target.pane.pid).ok_or("fixture peer absent")?;
    if value["schema"] != "private-runtime-line-editor-v2"
        || value["pid"].as_u64() != Some(process.pid as u64)
        || value["generation"]
            != serde_json::json!([process.start_seconds, process.start_microseconds])
    {
        return Err("fixture peer changed".into());
    }
    let hex = value["draft"].as_str().ok_or("missing draft")?;
    if hex.len() % 2 != 0 {
        return Err("invalid hex".into());
    }
    let bytes = (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16))
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    let pane = prepared.target.selector();
    let metadata = ns.command(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{pane_width}|#{pane_height}|#{cursor_x}|#{cursor_y}|#{pane_in_mode}",
    ])?;
    let v: Vec<u64> = metadata
        .trim()
        .split('|')
        .map(str::parse)
        .collect::<std::result::Result<_, _>>()
        .map_err(|e: std::num::ParseIntError| e.to_string())?;
    if v.len() != 5 || v[0] <= 10 || v[1] == 0 || v[2] >= v[0] || v[3] >= v[1] {
        return Err("unknown fixture geometry".into());
    }
    Ok(View {
        receipt: Default::default(),
        bytes,
        busy: value["busy"].as_bool().ok_or("busy missing")?,
        copy: v[4] != 0,
        width: v[0],
        height: v[1],
        x: v[2],
        y: v[3],
    })
}
fn fixture_state(server: &crate::test_server::Server, name: &str) -> serde_json::Value {
    serde_json::from_slice(&std::fs::read(server.root.join(format!("{name}.json"))).unwrap())
        .unwrap()
}
fn attached(server: &crate::test_server::Server, target: &str) -> OwnedChild {
    server.command(&["select-window", "-t", &format!("private-k50:{target}")]);
    let ready = server.root.join(format!("{target}.attached.ready"));
    let mut command = Command::new(std::env::current_exe().unwrap());
    command
        .args([
            "--ignored",
            "--exact",
            "runtime::tests::attached_worker",
            "--nocapture",
        ])
        .env("ANGELSTAR_ATTACHED_SOCKET", &server.socket)
        .env("ANGELSTAR_ATTACHED_READY", &ready)
        .stdin(Stdio::piped())
        .env("TERM", "xterm-256color");
    let mut child = OwnedChild::spawn(&mut command).unwrap();
    let deadline = Instant::now() + Duration::from_secs(3);
    while !ready.exists() {
        assert!(!child.poll().unwrap());
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    while !server
        .command(&["list-clients", "-F", "#{client_session}"])
        .lines()
        .any(|s| s == "private-k50")
    {
        assert!(!child.poll().unwrap());
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    child
}
fn human(
    child: &mut OwnedChild,
    server: &crate::test_server::Server,
    target: &str,
    bytes: &[u8],
    expected: &[u8],
) {
    let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
    writeln!(child.child.stdin.as_mut().unwrap(), "{hex}").unwrap();
    let expected: String = expected.iter().map(|b| format!("{b:02x}")).collect();
    let deadline = Instant::now() + Duration::from_secs(3);
    while fixture_state(server, target)["draft"] != expected {
        assert!(!child.poll().unwrap());
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
}
fn detach(mut child: OwnedChild) {
    writeln!(child.child.stdin.as_mut().unwrap(), "quit").unwrap();
    child.child.stdin.take();
    let deadline = Instant::now() + Duration::from_secs(3);
    while !child.poll().unwrap() {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    assert!(child.status.unwrap().success());
}
#[test]
#[ignore = "explicit signed leased private delivery fixture only"]
fn private_delivery() {
    if crate::test_server::supervised("runtime::tests::private_delivery") {
        return;
    }
    let server = crate::test_server::Server::new();
    for scene in [
        "bind-error",
        "ready",
        "busy",
        "copy",
        "draft",
        "edited-stage",
        "abandoned-stage",
        "trailing-semi",
        "escaped-semi",
    ] {
        let target = format!("target-{scene}");
        let decoy = format!("decoy-{scene}");
        server.fixtures(&[&target, &decoy]);
        let ns = server.namespace();
        let mut client = if matches!(scene, "draft" | "edited-stage" | "abandoned-stage") {
            Some(attached(&server, &target))
        } else {
            None
        };
        if scene == "draft" {
            human(
                client.as_mut().unwrap(),
                &server,
                &target,
                b"human",
                b"human",
            );
        }
        if scene == "busy" {
            std::fs::write(server.root.join(format!("{target}.control")), b"busy").unwrap();
            let deadline = Instant::now() + Duration::from_secs(2);
            while fixture_state(&server, &target)["busy"] != true {
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(5));
            }
        }
        if scene == "copy" {
            server.command(&["copy-mode", "-t", &format!("private-k50:{target}")]);
        }
        let message = match scene {
            "trailing-semi" => "#core staged-message;",
            "escaped-semi" => "#core staged-message\\;",
            _ => "#core staged-message",
        };
        let prepared = Prepared::new(&ns, "private-k50", &target, None, message).unwrap();
        let wire = prepared.wire.clone();
        let mut store = Store::open(&server.root.join(format!("archive-{scene}"))).unwrap();
        let mut runtime = Runtime::accept(
            &ns,
            prepared,
            &mut store,
            message.as_bytes(),
            Budgets {
                stop_ms: 30,
                drain_ms: 30,
                reap_ms: 30,
                decision_ms: 90,
            },
        )
        .unwrap();
        if scene == "bind-error" {
            // The real fixture process is not a supported native image. Preserve
            // that actual binding failure rather than replacing it with a
            // generic renderer message or permitting any input.
            let deadline = Instant::now() + Duration::from_secs(4);
            while runtime.tick().unwrap() == State::PendingNoInput {
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(10));
            }
            assert_eq!(runtime.state, State::TerminalNoInput);
            assert_eq!(
                runtime
                    .store
                    .attempt(&runtime.id)
                    .unwrap()
                    .history
                    .last()
                    .unwrap()
                    .evidence
                    .diagnostics,
                vec!["initial-view: client-bind: unsupported client"]
            );
            assert_eq!(fixture_state(&server, &target)["events"], 0);
            assert_eq!(fixture_state(&server, &decoy)["events"], 0);
            runtime.close().unwrap();
            continue;
        }
        runtime.fixture = Some(server.root.join(format!("{target}.json")));
        let state = runtime.tick().unwrap();
        if scene == "abandoned-stage" {
            assert_eq!(state, State::WaitingForFocusRelease);
            assert_eq!(fixture_state(&server, &target)["submissions"], 0);
            runtime.close().unwrap();
            let observed = fixture_state(&server, &target);
            assert_eq!(observed["draft"], "");
            assert_eq!(observed["events"], wire.len() * 2);
            assert_eq!(observed["submissions"], 0);
            assert_eq!(fixture_state(&server, &decoy)["events"], 0);
            assert!(runtime.store.attempt(&runtime.id).unwrap().history.iter().any(|step| step.evidence.diagnostics.iter().any(|note| note == "failure cleanup: exact own staged bytes removed; empty native composer proven")));
            detach(client.take().unwrap());
            continue;
        }
        if matches!(scene, "busy" | "copy" | "draft") {
            assert_eq!(state, State::PendingNoInput);
            assert_eq!(fixture_state(&server, &target)["submissions"], 0);
            if scene == "busy" {
                std::fs::write(server.root.join(format!("{target}.control")), b"ready").unwrap();
            } else if scene == "copy" {
                server.command(&[
                    "send-keys",
                    "-t",
                    &format!("private-k50:{target}"),
                    "-X",
                    "cancel",
                ]);
            } else {
                human(client.as_mut().unwrap(), &server, &target, &[127; 5], b"");
                detach(client.take().unwrap());
            }
        } else if scene == "edited-stage" {
            assert_eq!(state, State::WaitingForFocusRelease);
            assert!(runtime
                .store
                .attempt(&runtime.id)
                .unwrap()
                .history
                .last()
                .unwrap()
                .evidence
                .diagnostics
                .iter()
                .any(|message| message == "submit-focused-guard"));
            assert_eq!(fixture_state(&server, &target)["submissions"], 0);
            let edited = format!("{wire}!");
            human(
                client.as_mut().unwrap(),
                &server,
                &target,
                b"!",
                edited.as_bytes(),
            );
            assert_eq!(runtime.tick().unwrap(), State::InputUnknown);
            assert_eq!(fixture_state(&server, &target)["submissions"], 0);
            detach(client.take().unwrap());
        }
        if scene != "edited-stage" {
            let deadline = Instant::now() + Duration::from_secs(3);
            while runtime.state != State::Submitted {
                runtime.tick().unwrap();
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(5));
            }
            let deadline = Instant::now() + Duration::from_secs(2);
            while fixture_state(&server, &target)["submissions"] != 1 {
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(5));
            }
            let state = fixture_state(&server, &target);
            assert_eq!(state["submissions"], 1);
            let hex: String = wire.as_bytes().iter().map(|b| format!("{b:02x}")).collect();
            assert_eq!(state["last"], hex);
            runtime.tick().unwrap();
            assert_eq!(fixture_state(&server, &target)["submissions"], 1);
        }
        runtime.close().unwrap();
        drop(runtime);
        assert_eq!(fixture_state(&server, &decoy)["events"], 0);
        if scene == "edited-stage" {
            for n in 0..2 {
                let prepared =
                    Prepared::new(&ns, "private-k50", &target, None, "#next no-replay").unwrap();
                let mut other = Store::open(&server.root.join(format!("other-{n}"))).unwrap();
                let mut runtime = Runtime::accept(
                    &ns,
                    prepared,
                    &mut other,
                    b"#next no-replay",
                    Budgets {
                        stop_ms: 30,
                        drain_ms: 30,
                        reap_ms: 30,
                        decision_ms: 90,
                    },
                )
                .unwrap();
                runtime.fixture = Some(server.root.join(format!("{target}.json")));
                assert_eq!(runtime.tick().unwrap(), State::TerminalNoInput);
                runtime.close().unwrap();
                assert_eq!(fixture_state(&server, &target)["submissions"], 0);
            }
        }
        println!("private core {scene} evidence {}", server.root.display());
    }
}
#[test]
#[ignore = "explicit signed leased private effect-boundary fixture only"]
fn effect_faults() {
    if let Some(root) = std::env::var_os("ANGELSTAR_CORE_WORKER_ROOT") {
        let root = std::path::PathBuf::from(root);
        let target = std::env::var("ANGELSTAR_CORE_WORKER_TARGET").unwrap();
        let ns = identity::connect_signed(&root.join("server")).unwrap();
        let prepared =
            Prepared::new(&ns, "private-k50", &target, None, "#core crash-message").unwrap();
        let mut store = Store::open(&root.join(format!("archive-{target}"))).unwrap();
        let mut runtime = Runtime::accept(
            &ns,
            prepared,
            &mut store,
            b"#core crash-message",
            Budgets {
                stop_ms: 30,
                drain_ms: 30,
                reap_ms: 30,
                decision_ms: 90,
            },
        )
        .unwrap();
        runtime.fixture = Some(root.join(format!("{target}.json")));
        let ids = root.join(format!("{target}.ids.json"));
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(ids)
            .unwrap();
        serde_json::to_writer(&mut file, &runtime.ids()).unwrap();
        file.sync_all().unwrap();
        runtime.tick().unwrap();
        panic!("required crash checkpoint was not reached");
    }
    if crate::test_server::supervised("runtime::tests::effect_faults") {
        return;
    }
    let server = crate::test_server::Server::new();
    for (index, point) in [
        "InputIntent:before-commit",
        "InputIntent:after-commit",
        "paste-launch:after",
        "paste-dispatch:before",
        "paste-observation",
        "after-postcheck",
        "enter-dispatch:before",
        "Submitted:before-commit",
        "Submitted:after-commit",
    ]
    .into_iter()
    .enumerate()
    {
        let target = format!("crash-target-{index}");
        let decoy = format!("crash-decoy-{index}");
        server.fixtures(&[&target, &decoy]);
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args([
                "--ignored",
                "--exact",
                "runtime::tests::effect_faults",
                "--nocapture",
            ])
            .env("ANGELSTAR_CORE_WORKER_ROOT", &server.root)
            .env("ANGELSTAR_CORE_WORKER_TARGET", &target)
            .env("ANGELSTAR_CORE_CRASH", point)
            .stdin(Stdio::null());
        let mut child = OwnedChild::spawn(&mut command).unwrap();
        let deadline = Instant::now() + Duration::from_secs(15);
        while !child.poll().unwrap() {
            assert!(Instant::now() < deadline);
            std::thread::sleep(Duration::from_millis(5));
        }
        assert_eq!(child.status.unwrap().code(), Some(86));
        let (attempt, archive): (String, String) = serde_json::from_slice(
            &std::fs::read(server.root.join(format!("{target}.ids.json"))).unwrap(),
        )
        .unwrap();
        let mut store = Store::open(&server.root.join(format!("archive-{target}"))).unwrap();
        let state = store.record_restart(&attempt).unwrap().state();
        assert_eq!(
            state,
            if point == "InputIntent:before-commit" {
                State::PendingNoInput
            } else if point == "Submitted:after-commit" {
                State::Submitted
            } else {
                State::InputUnknown
            }
        );
        assert_eq!(store.read(&archive, false).unwrap(), b"#core crash-message");
        if point.starts_with("Submitted:") {
            let deadline = Instant::now() + Duration::from_secs(2);
            while fixture_state(&server, &target)["submissions"] != 1 {
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(5));
            }
        }
        let observed = fixture_state(&server, &target);
        assert!(observed["submissions"].as_u64().unwrap() <= 1);
        assert_eq!(fixture_state(&server, &decoy)["events"], 0);
        println!("effect boundary {point} evidence {}", server.root.display());
    }
}
#[test]
#[ignore = "signed leased private reproduced activity-fence case; fixture timing only"]
fn activity_gate() {
    if crate::test_server::supervised("runtime::tests::activity_gate") {
        return;
    }
    let server = crate::test_server::Server::new();
    server.fixtures(&["target", "decoy"]);
    let ns = server.namespace();
    let mut client = attached(&server, "target");
    server.command(&["select-window", "-t", "private-k50:hold"]);
    let deadline = Instant::now() + Duration::from_secs(2);
    loop {
        let activity: u64 = server
            .command(&["list-clients", "-F", "#{client_activity}"])
            .trim()
            .parse()
            .unwrap();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        if activity < now {
            break;
        }
        assert!(
            Instant::now() < deadline,
            "prior client activity did not precede paste epoch"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    let prepared = Prepared::new(
        &ns,
        "private-k50",
        "target",
        None,
        "#activity staged-message",
    )
    .unwrap();
    let wire = prepared.wire.clone();
    let edited = format!("{wire}x");
    let mut store = Store::open(&server.root.join("archive")).unwrap();
    let mut runtime = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        b"#activity staged-message",
        Budgets {
            stop_ms: 30,
            drain_ms: 30,
            reap_ms: 30,
            decision_ms: 90,
        },
    )
    .unwrap();
    runtime.fixture = Some(server.root.join("target.json"));
    runtime.before_enter = Some(Box::new(|| {
        server.command(&["select-window", "-t", "private-k50:target"]);
        human(&mut client, &server, "target", b"x", edited.as_bytes());
        server.command(&["select-window", "-t", "private-k50:hold"]);
        Ok(())
    }));
    let state = runtime.tick().unwrap();
    let result = String::from_utf8(
        runtime.producers.last().unwrap().child.readers[0]
            .bytes
            .clone(),
    )
    .unwrap();
    assert_eq!(result.trim(), "activity");
    assert_eq!(state, State::WaitingForFocusRelease);
    assert!(runtime
        .store
        .attempt(&runtime.id)
        .unwrap()
        .history
        .last()
        .unwrap()
        .evidence
        .diagnostics
        .iter()
        .any(|message| message == "submit-activity-guard"));
    assert_eq!(fixture_state(&server, "target")["submissions"], 0);
    assert_eq!(runtime.tick().unwrap(), State::InputUnknown);
    assert_eq!(runtime.tick().unwrap(), State::InputUnknown);
    let attempt = runtime.ids().0.to_string();
    runtime.close().unwrap();
    drop(runtime);
    detach(client);
    assert_eq!(
        store.attempt(&attempt).unwrap().state(),
        State::InputUnknown
    );
    let target = fixture_state(&server, "target");
    assert_eq!(target["events"], wire.len() as u64 + 1);
    let hex: String = edited
        .as_bytes()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect();
    assert_eq!(target["draft"], hex);
    assert_eq!(target["submissions"], 0);
    assert_eq!(fixture_state(&server, "decoy")["events"], 0);
    println!("activity refusal evidence {}", server.root.display());
}

#[test]
#[ignore = "signed leased private activity-elsewhere then quiet fixture"]
fn activity_elsewhere_then_quiet() {
    if crate::test_server::supervised("runtime::tests::activity_elsewhere_then_quiet") {
        return;
    }
    let server = crate::test_server::Server::new();
    server.fixtures(&["target", "decoy"]);
    let ns = server.namespace();
    let mut client = attached(&server, "decoy");
    let prepared =
        Prepared::new(&ns, "private-k50", "target", None, "#quiet staged-message").unwrap();
    let wire = prepared.wire.clone();
    let mut store = Store::open(&server.root.join("archive")).unwrap();
    let mut runtime = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        b"#quiet staged-message",
        Budgets {
            stop_ms: 30,
            drain_ms: 30,
            reap_ms: 30,
            decision_ms: 90,
        },
    )
    .unwrap();
    runtime.fixture = Some(server.root.join("target.json"));
    let mut inject_once = true;
    runtime.before_enter = Some(Box::new(|| {
        if inject_once {
            // Real attached-client input elsewhere, after the exact target check.
            human(&mut client, &server, "decoy", b"x", b"x");
            inject_once = false;
        }
        Ok(())
    }));
    assert_eq!(runtime.tick().unwrap(), State::WaitingForFocusRelease);
    assert!(runtime
        .store
        .attempt(&runtime.id)
        .unwrap()
        .history
        .last()
        .unwrap()
        .evidence
        .diagnostics
        .iter()
        .any(|d| d == "submit-activity-guard"));
    assert_eq!(fixture_state(&server, "target")["submissions"], 0);
    let deadline = Instant::now() + Duration::from_secs(8);
    loop {
        match runtime.tick().unwrap() {
            State::Submitted => break,
            State::WaitingForFocusRelease => {
                assert!(
                    Instant::now() < deadline,
                    "quiet activity boundary never advanced"
                );
                std::thread::sleep(Duration::from_millis(10));
            }
            state => panic!("unexpected quiet-loop state: {state:?}"),
        }
    }
    for _ in 0..3 {
        assert_eq!(runtime.tick().unwrap(), State::Submitted);
    }
    while fixture_state(&server, "target")["submissions"] != 1 {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(5));
    }
    assert_eq!(
        fixture_state(&server, "target")["events"],
        wire.len() as u64 + 1
    );
    assert_eq!(fixture_state(&server, "decoy")["events"], 1);
    assert_eq!(fixture_state(&server, "decoy")["submissions"], 0);
    let attempt = runtime.ids().0.to_string();
    runtime.close().unwrap();
    drop(runtime);
    detach(client);
    assert_eq!(store.attempt(&attempt).unwrap().state(), State::Submitted);
    assert_eq!(fixture_state(&server, "target")["submissions"], 1);
    println!(
        "activity elsewhere then quiet evidence {}",
        server.root.display()
    );
}

thread_local! {
    static HARNESS_FIXTURE: std::cell::RefCell<Option<std::path::PathBuf>> = const { std::cell::RefCell::new(None) };
}

pub(super) fn cli_fixture() -> Option<std::path::PathBuf> {
    HARNESS_FIXTURE.with(|value| value.borrow().clone())
}

#[test]
#[ignore = "stdin-only actual CLI adapter for signed private controller dry run"]
fn harness_cli_probe() {
    use std::io::Read;
    let socket = std::path::PathBuf::from(std::env::var_os("ANGELSTAR_RELAY_SOCKET").unwrap());
    let ns = identity::connect_signed(&socket).expect("signed private socket required");
    let mut input = String::new();
    std::io::stdin()
        .take(1024 * 1024)
        .read_to_string(&mut input)
        .unwrap();
    let request: serde_json::Value = serde_json::from_str(&input).unwrap();
    let fixture = std::path::PathBuf::from(request["fixture"].as_str().unwrap());
    assert_eq!(fixture.parent(), ns.socket().parent());
    HARNESS_FIXTURE.with(|value| *value.borrow_mut() = Some(fixture));
    let args: Vec<String> = request["args"]
        .as_array()
        .unwrap()
        .iter()
        .map(|arg| arg.as_str().unwrap().to_owned())
        .collect();
    // Actual public parser, runtime, store, budgets, producer and exit mapping.
    // Only the already-existing test view is supplied by the private client.
    std::process::exit(crate::cli::main_entry("cc-msg", &args));
}

#[test]
#[ignore = "private attached terminal worker only"]
fn attached_worker() {
    use std::os::unix::process::CommandExt;
    let socket = std::path::PathBuf::from(std::env::var_os("ANGELSTAR_ATTACHED_SOCKET").unwrap());
    let ready = std::path::PathBuf::from(std::env::var_os("ANGELSTAR_ATTACHED_READY").unwrap());
    identity::delivery_attest(&socket).unwrap();
    let mut master = -1;
    let mut slave = -1;
    let mut size = libc::winsize {
        ws_row: 24,
        ws_col: 80,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };
    assert_eq!(
        unsafe {
            libc::openpty(
                &mut master,
                &mut slave,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                &mut size,
            )
        },
        0
    );
    use std::os::fd::{AsRawFd, FromRawFd};
    let mut terminal = unsafe { File::from_raw_fd(master) };
    let slave = unsafe { File::from_raw_fd(slave) };
    let slave_fd = slave.as_raw_fd();
    let mut command = Command::new("/opt/homebrew/bin/tmux");
    command
        .args(["-N", "-S"])
        .arg(&socket)
        .args(["attach-session", "-t", "private-k50"])
        .stdin(slave.try_clone().unwrap())
        .stdout(slave.try_clone().unwrap())
        .stderr(slave.try_clone().unwrap());
    unsafe {
        command.pre_exec(move || {
            if libc::setsid() < 0 || libc::ioctl(slave_fd, libc::TIOCSCTTY.into(), 0) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    let mut child = command.spawn().unwrap();
    drop(command);
    drop(slave);
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(ready)
        .unwrap()
        .write_all(child.id().to_string().as_bytes())
        .unwrap();
    let mut line = Vec::new();
    loop {
        if child.try_wait().unwrap().is_some() {
            break;
        }
        let mut descriptors = [
            libc::pollfd {
                fd: master,
                events: libc::POLLIN,
                revents: 0,
            },
            libc::pollfd {
                fd: 0,
                events: libc::POLLIN,
                revents: 0,
            },
        ];
        assert!(unsafe { libc::poll(descriptors.as_mut_ptr(), 2, 100) } >= 0);
        if descriptors[0].revents != 0 {
            let mut bytes = [0; 65536];
            if terminal.read(&mut bytes).unwrap_or(0) == 0 {
                break;
            }
        }
        if descriptors[1].revents != 0 {
            let mut byte = [0];
            if unsafe { libc::read(0, byte.as_mut_ptr().cast(), 1) } <= 0 {
                break;
            }
            if byte[0] == b'\n' {
                if line == b"quit" {
                    terminal.write_all(b"\x02d").unwrap();
                    break;
                }
                let text = std::str::from_utf8(&line).unwrap();
                let bytes: Vec<u8> = (0..text.len())
                    .step_by(2)
                    .map(|n| u8::from_str_radix(&text[n..n + 2], 16).unwrap())
                    .collect();
                terminal.write_all(&bytes).unwrap();
                line.clear();
            } else {
                line.push(byte[0]);
            }
        }
    }
    drop(terminal);
    let deadline = Instant::now() + Duration::from_secs(2);
    while child.try_wait().unwrap().is_none() {
        assert!(
            Instant::now() < deadline,
            "owned attached client exit unresolved"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn overflow_receiver_instruction() {
    let path = identity::account_home()
        .unwrap()
        .join("desk/tmp/relay-rust-store/0123456789abcdef0123456789abcdef.original");
    let pointer = overflow_pointer("peer", "#abc123", &path);
    assert_eq!(pointer, "peer: #abc123 -- full: ~/desk/tmp/relay-rust-store/0123456789abcdef0123456789abcdef.original");
    assert!(pointer.ends_with("0123456789abcdef0123456789abcdef.original"));
}

#[test]
fn overflow_capacity_boundary_and_unknown_geometry_stay_closed() {
    let mut capacity = store::Capacity {
        width: 149,
        height: 45,
        cursor_x: 2,
        cursor_y: 42,
        pointer: "x".repeat(146),
        cells: Some(146),
        byte_limit: Some(146),
        cell_limit: Some(146),
    };
    assert!(capacity.permits());
    capacity.pointer.push('x');
    capacity.cells = Some(147);
    assert!(!capacity.permits());
    capacity.pointer.pop();
    capacity.cells = None;
    assert!(!capacity.permits());
    capacity.cells = Some(146);
    capacity.width = 0;
    assert!(!capacity.permits());
    capacity.width = 149;
    capacity.height = 0;
    assert!(!capacity.permits());
}

#[test]
#[ignore = "explicit signed leased private capacity and geometry fixture only"]
fn capacity_guards() {
    if crate::test_server::supervised("runtime::tests::capacity_guards") {
        return;
    }
    let server = crate::test_server::Server::new();
    server.fixtures(&["capacity-target", "capacity-decoy"]);
    let ns = server.namespace();
    server.command(&[
        "resize-window",
        "-t",
        "private-k50:capacity-target",
        "-x",
        "183",
        "-y",
        "45",
    ]);
    let message = format!("#capacity {}", "original message ".repeat(20));
    let prepared = Prepared::new(&ns, "private-k50", "capacity-target", None, &message).unwrap();
    let mut store = Store::open(&server.root.join("capacity-archive")).unwrap();
    let mut runtime = Runtime::accept(
        &ns,
        prepared,
        &mut store,
        message.as_bytes(),
        Budgets {
            stop_ms: 30,
            drain_ms: 30,
            reap_ms: 30,
            decision_ms: 90,
        },
    )
    .unwrap();
    runtime.fixture = Some(server.root.join("capacity-target.json"));
    assert_eq!(
        std::fs::read(runtime.store.original_path(&runtime.archive)).unwrap(),
        message.as_bytes()
    );
    assert!(runtime.prepared.wire.contains("#capacity -- full: "));
    let before = runtime.view().unwrap();
    runtime.geometry = Some((before.width, before.height, before.y));
    let condition = runtime.condition_for(&runtime.view().unwrap()).unwrap();
    server.command(&[
        "resize-window",
        "-t",
        "private-k50:capacity-target",
        "-x",
        "149",
        "-y",
        "45",
    ]);
    assert_eq!(
        runtime.condition_for(&runtime.view().unwrap()).unwrap_err(),
        "geometry changed before effect"
    );
    let pane = runtime.prepared.target.selector();
    assert_eq!(
        ns.command(&[
            "if-shell",
            "-F",
            "-t",
            &pane,
            &condition,
            &format!("send-keys -t {pane} Enter"),
            "display-message -p refused"
        ])
        .unwrap()
        .trim(),
        "refused"
    );
    assert_eq!(fixture_state(&server, "capacity-target")["events"], 0);
    assert_eq!(fixture_state(&server, "capacity-decoy")["events"], 0);
    runtime.close().unwrap();
    assert_eq!(runtime.state, State::PendingNoInput);
    assert_eq!(fixture_state(&server, "capacity-target")["events"], 0);
    assert_eq!(fixture_state(&server, "capacity-target")["submissions"], 0);
    assert_eq!(fixture_state(&server, "capacity-decoy")["events"], 0);
    println!(
        "capacity149/183 archive and atomic resize proof {}",
        server.root.display()
    );
}

#[test]
fn overflow_ordinary_width_capacity() {
    let path = identity::account_home()
        .unwrap()
        .join("desk/tmp/relay-rust-store/0123456789abcdef0123456789abcdef.original");
    let pointer = overflow_pointer("peer", "#abc123", &path);
    let mut capacity = store::Capacity {
        width: 120,
        height: 30,
        cursor_x: 2,
        cursor_y: 0,
        cells: Some(pointer.len() as u64),
        byte_limit: Some(117),
        cell_limit: Some(117),
        pointer,
    };
    assert!(capacity.permits(), "{}", capacity.pointer);
    capacity.pointer = overflow_pointer(&"long".repeat(30), "#abc123", &path);
    capacity.cells = Some(capacity.pointer.len() as u64);
    assert!(!capacity.permits());
}
