use angelstar_runtime::target::*;

#[test]
#[ignore = "read-only check against an explicitly available tmux server"]
#[cfg(any())]
fn live_metadata_is_coherent() {
    let snapshot = Snapshot::capture().unwrap();
    assert!(!snapshot.sessions.is_empty());
    for (session_id, windows) in &snapshot.windows {
        assert!(snapshot.sessions.contains_key(session_id));
        for window in windows {
            assert!(!snapshot.panes[&window.id].is_empty());
        }
    }
}

#[test]
#[ignore = "requires the owned test-k1-framing-会🦀 window"]
#[cfg(any())]
fn live_unicode_name_uses_byte_lengths() {
    let snapshot = Snapshot::capture().unwrap();
    let target = resolve(
        &snapshot,
        "config(tmux-to-rust)",
        "test-k1-framing-会🦀",
        None,
    )
    .unwrap();
    assert_eq!(target.window.name, "test-k1-framing-会🦀");
}

#[test]
#[ignore = "requires an explicit empty/failure tmux executable on PATH"]
fn capture_command_outcome_is_not_inferred_from_empty_bytes() {
    assert!(matches!(Snapshot::capture(), Err(Error::InvalidNamespace)));
}

#[cfg(unix)]
#[test]
#[ignore = "isolated subprocess PATH fixtures; no live tmux command"]
fn isolated_capture_checks_argv_status_and_signal() {
    use std::os::unix::fs::PermissionsExt;
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::path::PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
        .join("desk/tmp")
        .join(format!(
            "keeper1-command-boundary-{}-{stamp}",
            std::process::id()
        ));
    std::fs::create_dir(&root).unwrap();
    eprintln!("owned-fixture-root {}", root.display());
    let fixture = "#!/bin/sh\nprintf '%s\\000' \"$@\" > \"$ANGELSTAR_CAPTURE_ARGV\"\ncase \"$ANGELSTAR_CAPTURE_FIXTURE\" in\nvalid) printf '$1\\t@2\\t%%3\\t123\\t0\\t1:s1:w\\n';;\nnonzero) printf '$1\\t@2\\t%%3\\t123\\t0\\t1:s1:w\\n'; exit 1;;\nsignal) /bin/kill -TERM $$; exit 99;;\nmalformed) printf 'not metadata\\n';;\nesac\n";
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        for (mode, outcome) in [
            ("valid", "valid"),
            ("nonzero", "failure"),
            ("signal", "failure"),
            ("malformed", "malformed"),
        ] {
            let directory = root.join(mode);
            std::fs::create_dir(&directory).unwrap();
            let executable = directory.join("tmux");
            let argv = directory.join("argv");
            std::fs::write(&executable, fixture).unwrap();
            std::fs::set_permissions(&executable, std::fs::Permissions::from_mode(0o700)).unwrap();
            if std::env::var("ANGELSTAR_FIXTURE_FAULT").as_deref() == Ok("panic") {
                panic!("injected fixture body failure");
            }
            let output = std::process::Command::new(std::env::current_exe().unwrap())
                .args([
                    "--ignored",
                    "--exact",
                    "capture_command_outcome_is_not_inferred_from_empty_bytes",
                ])
                .env("PATH", &directory)
                .env("ANGELSTAR_CAPTURE_FIXTURE", mode)
                .env("ANGELSTAR_CAPTURE_OUTCOME", outcome)
                .env("ANGELSTAR_CAPTURE_ARGV", &argv)
                .output()
                .unwrap();
            assert!(output.status.success(), "{mode}: {output:?}");
            assert!(
                !argv.exists(),
                "ambient capture reached fixture backend: {mode}"
            );
            std::fs::remove_file(argv).unwrap();
            std::fs::remove_file(executable).unwrap();
            std::fs::remove_dir(directory).unwrap();
        }
    }));
    let mut cleanup_errors = Vec::new();
    for mode in ["valid", "nonzero", "signal", "malformed"] {
        let directory = root.join(mode);
        for removal in [
            std::fs::remove_file(directory.join("argv")),
            std::fs::remove_file(directory.join("tmux")),
            std::fs::remove_dir(&directory),
        ] {
            if let Err(error) = removal {
                if error.kind() != std::io::ErrorKind::NotFound {
                    cleanup_errors.push(format!("{}: {error}", directory.display()));
                }
            }
        }
    }
    if let Err(error) = std::fs::remove_dir(&root) {
        if error.kind() != std::io::ErrorKind::NotFound {
            cleanup_errors.push(format!("{}: {error}", root.display()));
        }
    }
    if !cleanup_errors.is_empty() {
        eprintln!("cleanup errors: {cleanup_errors:?}");
    }
    if let Err(panic) = result {
        std::panic::resume_unwind(panic);
    }
    assert!(cleanup_errors.is_empty(), "{cleanup_errors:?}");
}

#[test]
#[ignore = "creates and cleans only its own config(tmux-to-rust):test-* windows"]
#[cfg(any())]
fn owned_live_target_generations_and_ambiguity() {
    fn tmux(args: &[&str]) -> String {
        let output = std::process::Command::new("tmux")
            .args(args)
            .output()
            .unwrap();
        assert!(output.status.success(), "{args:?}: {output:?}");
        String::from_utf8(output.stdout).unwrap().trim().into()
    }
    let session = "config(tmux-to-rust)";
    let snapshot = Snapshot::capture().unwrap();
    let sessions = snapshot
        .sessions
        .iter()
        .filter(|(_, name)| name.as_str() == session)
        .map(|(id, _)| *id)
        .collect::<Vec<_>>();
    assert_eq!(sessions.len(), 1);
    let session_selector = format!("${}", sessions[0].0);
    let prefix = format!("test-k1-generation-{}", std::process::id());
    let original_name = format!("{prefix}:会 #{{pane_id}}");
    let renamed = format!("{prefix}-renamed");
    let decoy_name = format!("{prefix}-decoy");
    assert!(snapshot.windows[&sessions[0]].iter().all(|window| ![
        &original_name,
        &renamed,
        &decoy_name
    ]
    .contains(&&window.name)));
    let mut owned = Vec::new();
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        for name in [&original_name, &decoy_name] {
            let literal_name = name.replace('#', "##");
            owned.push(tmux(&[
                "new-window",
                "-d",
                "-P",
                "-F",
                "#{window_id}",
                "-t",
                &session_selector,
                "-n",
                &literal_name,
                "/bin/sleep 120",
            ]));
            eprintln!("owned-test-window {}", owned.last().unwrap());
            tmux(&["rename-window", "-t", owned.last().unwrap(), &literal_name]);
            tmux(&[
                "set-window-option",
                "-t",
                owned.last().unwrap(),
                "automatic-rename",
                "off",
            ]);
        }
        let before = Snapshot::capture().unwrap();
        let target = resolve(&before, session, &original_name, None).unwrap();
        assert_eq!(target.session_id, sessions[0]);
        assert_eq!(format!("@{}", target.window.id.0), owned[0]);
        tmux(&["rename-window", "-t", &owned[0], &renamed]);
        let after = Snapshot::capture().unwrap();
        assert_eq!(
            resolve(&after, session, &original_name, None),
            Err(Error::MissingWindow)
        );
        assert_eq!(revalidate(&after, &target), Err(Error::MissingWindow));
        let renamed_target = resolve(&after, session, &renamed, None).unwrap();
        tmux(&[
            "respawn-pane",
            "-k",
            "-t",
            &renamed_target.selector(),
            "/bin/sleep 120",
        ]);
        let after_respawn = Snapshot::capture().unwrap();
        assert_eq!(
            revalidate(&after_respawn, &renamed_target),
            Err(Error::Changed)
        );
        tmux(&["rename-window", "-t", &owned[1], &renamed]);
        let duplicate = Snapshot::capture().unwrap();
        assert_eq!(
            resolve(&duplicate, session, &renamed, None),
            Err(Error::AmbiguousWindow)
        );
        tmux(&["rename-window", "-t", &owned[1], &decoy_name]);
        let split = tmux(&[
            "split-window",
            "-d",
            "-P",
            "-F",
            "#{pane_id}",
            "-t",
            &renamed_target.selector(),
            "/bin/sleep 120",
        ]);
        let split_snapshot = Snapshot::capture().unwrap();
        assert_eq!(
            resolve(&split_snapshot, session, &renamed, None),
            Err(Error::AmbiguousPane)
        );
        let explicit = PaneId(split.strip_prefix('%').unwrap().parse().unwrap());
        assert_eq!(
            resolve(&split_snapshot, session, &renamed, Some(explicit))
                .unwrap()
                .pane
                .id,
            explicit
        );
        assert_eq!(
            resolve(&split_snapshot, session, &decoy_name, Some(explicit)),
            Err(Error::MissingPane)
        );
        if std::env::var("ANGELSTAR_LIVE_CLEANUP_FAULT").as_deref() == Ok("remove-first") {
            tmux(&["kill-window", "-t", &owned[0]]);
            panic!("injected live body failure");
        }
    }));
    let mut cleanup_error = None;
    for window in &owned {
        let cleanup = std::panic::catch_unwind(|| {
            let name = tmux(&["display-message", "-p", "-t", window, "#{window_name}"]);
            assert!([&original_name, &renamed, &decoy_name].contains(&&name));
            tmux(&["kill-window", "-t", window]);
        });
        if cleanup_error.is_none() {
            cleanup_error = cleanup.err();
        }
    }
    if let Err(panic) = result {
        std::panic::resume_unwind(panic);
    }
    if let Some(panic) = cleanup_error {
        std::panic::resume_unwind(panic);
    }
}

#[test]
#[ignore = "fault-injected subprocess; owns and cleans only child-created test windows"]
#[cfg(any())]
fn missing_first_window_does_not_abandon_second() {
    let child = std::process::Command::new(std::env::current_exe().unwrap())
        .args([
            "--ignored",
            "--exact",
            "owned_live_target_generations_and_ambiguity",
            "--nocapture",
        ])
        .env("ANGELSTAR_LIVE_CLEANUP_FAULT", "remove-first")
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let child_id = child.id();
    let output = child.wait_with_output().unwrap();
    let stderr = String::from_utf8(output.stderr).unwrap();
    let ids = stderr
        .lines()
        .filter_map(|line| line.strip_prefix("owned-test-window "))
        .map(|id| WindowId(id.strip_prefix('@').unwrap().parse().unwrap()))
        .collect::<Vec<_>>();
    assert_eq!(ids.len(), 2, "{stderr}");
    let snapshot = Snapshot::capture().unwrap();
    let prefix = format!("test-k1-generation-{child_id}");
    let leftovers = snapshot
        .windows
        .iter()
        .filter(|(id, _)| {
            snapshot.sessions.get(id).map(String::as_str) == Some("config(tmux-to-rust)")
        })
        .flat_map(|(_, windows)| windows)
        .filter(|window| ids.contains(&window.id))
        .collect::<Vec<_>>();
    for window in &leftovers {
        assert!([
            format!("{prefix}:会 #{{pane_id}}"),
            format!("{prefix}-renamed"),
            format!("{prefix}-decoy")
        ]
        .contains(&window.name));
        assert!(std::process::Command::new("tmux")
            .args(["kill-window", "-t", &format!("@{}", window.id.0)])
            .status()
            .unwrap()
            .success());
    }
    assert!(!output.status.success());
    assert!(stderr.contains("injected live body failure"), "{stderr}");
    assert!(
        leftovers.is_empty(),
        "child abandoned {} tracked owned window(s); parent recovered them",
        leftovers.len()
    );
}

#[test]
#[ignore = "owned live subprocess regression; reads non-owned window sizes/options without changing them"]
#[cfg(any())]
fn owned_live_fixtures_preserve_existing_window_geometry_and_options() {
    fn metadata() -> std::collections::BTreeMap<String, (String, String)> {
        let output = std::process::Command::new("tmux")
            .args([
                "list-windows",
                "-t",
                "config(tmux-to-rust)",
                "-F",
                "#{window_id}\t#{window_width}\t#{window_height}",
            ])
            .output()
            .unwrap();
        assert!(output.status.success());
        std::str::from_utf8(&output.stdout)
            .unwrap()
            .lines()
            .map(|line| {
                let (id, size) = line.split_once('\t').unwrap();
                let options = std::process::Command::new("tmux")
                    .args(["show-options", "-w", "-A", "-t", id])
                    .output()
                    .unwrap();
                assert!(options.status.success());
                (
                    id.to_owned(),
                    (size.to_owned(), String::from_utf8(options.stdout).unwrap()),
                )
            })
            .collect()
    }
    let before = metadata();
    for test in [
        "owned_live_target_generations_and_ambiguity",
        "missing_first_window_does_not_abandon_second",
        "fixture_panic_does_not_abandon_temporary_files",
        "isolated_capture_checks_argv_status_and_signal",
    ] {
        let child = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["--ignored", "--exact", test])
            .output()
            .unwrap();
        assert!(child.status.success(), "{test}: {child:?}");
        let after = metadata();
        for (id, original) in &before {
            assert_eq!(
                after.get(id),
                Some(original),
                "non-owned window changed: {id}"
            );
        }
        assert_eq!(after.len(), before.len(), "owned fixture window leaked");
    }
}

#[test]
#[ignore = "fault-injected subprocess; creates and cleans only its child fixture root"]
fn fixture_panic_does_not_abandon_temporary_files() {
    let child = std::process::Command::new(std::env::current_exe().unwrap())
        .args([
            "--ignored",
            "--exact",
            "isolated_capture_checks_argv_status_and_signal",
            "--nocapture",
        ])
        .env("ANGELSTAR_FIXTURE_FAULT", "panic")
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let child_id = child.id();
    let output = child.wait_with_output().unwrap();
    let stderr = String::from_utf8(output.stderr).unwrap();
    let roots = stderr
        .lines()
        .filter_map(|line| line.strip_prefix("owned-fixture-root "))
        .collect::<Vec<_>>();
    assert_eq!(roots.len(), 1, "{stderr}");
    let root = std::path::Path::new(roots[0]);
    assert_eq!(
        root.parent(),
        Some(
            std::path::PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
                .join("desk/tmp")
                .as_path()
        )
    );
    assert!(root
        .file_name()
        .unwrap()
        .to_str()
        .unwrap()
        .starts_with(&format!("keeper1-command-boundary-{child_id}-")));
    let abandoned = root.exists();
    if abandoned {
        for mode in ["valid", "nonzero", "signal", "malformed"] {
            let directory = root.join(mode);
            for file in ["argv", "tmux"] {
                let path = directory.join(file);
                if path.exists() {
                    std::fs::remove_file(path).unwrap();
                }
            }
            if directory.exists() {
                std::fs::remove_dir(directory).unwrap();
            }
        }
        std::fs::remove_dir(root).unwrap();
    }
    assert!(!output.status.success());
    assert!(stderr.contains("injected fixture body failure"), "{stderr}");
    assert!(
        !abandoned,
        "child abandoned its fixture root; parent recovered it"
    );
}
