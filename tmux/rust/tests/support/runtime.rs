use super::*;
use std::os::unix::fs::OpenOptionsExt;
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
    let mut command = Command::new("/bin/sleep");
    command.arg("5").stdin(Stdio::null());
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
    let mut command = Command::new("/usr/bin/python3");
    command
        .arg(
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../tests/fixtures/private-attached-client.py"),
        )
        .arg(identity::helper())
        .arg(&server.socket)
        .arg("private-k50")
        .arg(&ready)
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
    for scene in ["ready", "busy", "copy", "draft", "edited-stage"] {
        let target = format!("target-{scene}");
        let decoy = format!("decoy-{scene}");
        server.fixtures(&[&target, &decoy]);
        let ns = server.namespace();
        let mut client = if matches!(scene, "draft" | "edited-stage") {
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
        let prepared =
            Prepared::new(&ns, "private-k50", &target, None, "#core staged-message").unwrap();
        let wire = prepared.wire.clone();
        let mut store = Store::open(&server.root.join(format!("archive-{scene}"))).unwrap();
        let mut runtime = Runtime::accept(
            &ns,
            prepared,
            &mut store,
            b"#core staged-message",
            Budgets {
                stop_ms: 30,
                drain_ms: 30,
                reap_ms: 30,
                decision_ms: 90,
            },
        )
        .unwrap();
        runtime.fixture = Some(server.root.join(format!("{target}.json")));
        let state = runtime.tick().unwrap();
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
