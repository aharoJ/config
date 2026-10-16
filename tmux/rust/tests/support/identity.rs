use super::*;
use std::io::Read;
use std::os::unix::fs::DirBuilderExt;
#[test]
#[ignore = "read-only owned live Agy process/TTY admission; never launches a client"]
fn live_native_agy_binding() {
    let pane = std::env::var("ANGELSTAR_BIND_PANE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let expected: u32 = std::env::var("ANGELSTAR_BIND_NATIVE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let client = Client::bind(pane).unwrap();
    assert_eq!(client.process.pid, expected);
    assert_eq!(client.glyph, '>');
    client.current().unwrap();
    assert!(Client::bind(std::process::id()).is_err());
}
#[test]
#[ignore = "read-only explicitly authorized live Codex descendant identity; never launches a client"]
fn live_codex_descendant_binding() {
    let pane: u32 = std::env::var("ANGELSTAR_BIND_PANE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let expected: u32 = std::env::var("ANGELSTAR_BIND_NATIVE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let client = Client::bind(pane).unwrap();
    assert_eq!(client.process.pid, expected);
    assert_ne!(
        client.process.parent, pane,
        "fixture must cover nested wrappers"
    );
    assert_eq!(client.glyph, '›');
    client.current().unwrap();
}

#[test]
fn bound_client_checks_identity_without_rebinding_image() {
    let process = kernel_process(std::process::id()).unwrap();
    let path = process_path(process.pid).unwrap();
    let file = File::open(&path).unwrap();
    // Stand in for an already hash-proven binding. This test image is not a
    // vendor profile, so calling bind again would fail rather than succeed.
    let mut client = Client {
        stamp: stamp(&file.metadata().unwrap()),
        file,
        path,
        process,
        pane: process,
        glyph: '›',
    };
    client.current().unwrap();
    client.stamp.0 ^= 1;
    assert!(client.current().is_err());
}

#[test]
fn private_paths() {
    let root = PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk/tmp")
        .join(format!(
            "k50-private-{}",
            crate::runtime::fresh_id().unwrap()
        ));
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&root)
        .unwrap();
    let dir = open_dir(&root).unwrap();
    private(&dir, true).unwrap();
    let file = open_at(
        &dir,
        "record",
        libc::O_WRONLY | libc::O_CREAT | libc::O_EXCL,
    )
    .unwrap();
    private(&file, false).unwrap();
    std::os::unix::fs::symlink(&root, root.join("alias")).unwrap();
    assert!(open_dir(&root.join("alias")).is_err());
    assert!(open_at(&dir, "../record", libc::O_RDONLY).is_err());
    std::fs::set_permissions(
        root.join("record"),
        std::os::unix::fs::PermissionsExt::from_mode(0o644),
    )
    .unwrap();
    assert!(open_at(&dir, "record", libc::O_RDONLY).is_err());
    assert!(private(&File::open("/").unwrap(), true).is_err());
    let mut bytes: Vec<_> = root.as_os_str().as_bytes().to_vec();
    bytes.extend_from_slice(b"/../tmp");
    assert!(open_dir(Path::new(std::ffi::OsStr::from_bytes(&bytes))).is_err());
    let me = kernel_process(std::process::id()).unwrap();
    assert_eq!(kernel_ancestry(me.pid).unwrap()[0], me);
    assert!(me.generation().unwrap() > 0);
}
#[test]
fn routing_source() {
    let snapshot =
        Snapshot::parse(b"$0\t@1\t%2\t42\t0\t3:a:b3:w,#\n$1\t@2\t%3\t43\t0\t1:x1:y\n").unwrap();
    let target = resolve(&snapshot, "a:b", "w,#", None).unwrap();
    assert_eq!(target.selector(), "%2");
    assert_eq!(split_route("a:b:w,#").unwrap(), ("a:b", "w,#"));
    for route in ["", ":x", "x:", "x"] {
        assert!(split_route(route).is_err());
    }
    assert!(resolve(&snapshot, "a", "w,#", None).is_err());
    assert!(resolve(&snapshot, "a:b", "w,#", Some(PaneId(3))).is_err());
    let mut duplicate = snapshot.clone();
    duplicate.targets.push(target.clone());
    assert!(resolve(&duplicate, "a:b", "w,#", None).is_err());
    let parents = HashMap::from([(99, 42)]);
    assert_eq!(source_candidate(&snapshot, 99, &parents), Some(target));
    assert!(source_candidate(&duplicate, 99, &parents).is_none());
    for raw in [
        b"$0\t@1\t%2\t0\t0\t9:short".as_slice(),
        b"$0\t@1\t%2\t42\t2\t1:x1:y\n",
        b"$0\t@1\t%2\t42\t0\t1:x1:y",
    ] {
        assert!(Snapshot::parse(raw).is_err());
    }
}

#[test]
fn account_home_does_not_follow_environment() {
    let account = account_home().unwrap();
    let mut command = std::process::Command::new(std::env::current_exe().unwrap());
    let output = command
        .args([
            "--exact",
            "identity::tests::account_home_child",
            "--nocapture",
        ])
        .env("HOME", account.join("desk/tmp/nonaccount-home"))
        .env("ANGELSTAR_EXPECTED_ACCOUNT_HOME", &account)
        .output()
        .unwrap();
    assert!(output.status.success(), "{output:?}");
}
#[test]
fn account_home_child() {
    if let Some(expected) = std::env::var_os("ANGELSTAR_EXPECTED_ACCOUNT_HOME") {
        assert_eq!(account_home().unwrap(), PathBuf::from(expected));
        assert_ne!(
            account_home().unwrap(),
            PathBuf::from(std::env::var_os("HOME").unwrap())
        );
    }
}
#[test]
#[ignore = "authorized read-only running native identity profile"]
fn running_native_binding() {
    let pane = std::env::var("ANGELSTAR_BIND_PANE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let expected = std::env::var("ANGELSTAR_BIND_NATIVE_PID")
        .unwrap()
        .parse::<u32>()
        .unwrap();
    let client = Client::bind(pane).unwrap();
    assert_eq!(client.process.pid, expected);
    assert_eq!(client.glyph, '❯');
    client.current().unwrap();
}

#[test]
fn process_retirement_requires_reaping() {
    let mut child = std::process::Command::new(std::env::current_exe().unwrap())
        .args(["--exact", "identity::tests::account_home_child"])
        .stdout(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let process = kernel_process(child.id()).unwrap();
    let mut bytes = Vec::new();
    child
        .stdout
        .take()
        .unwrap()
        .read_to_end(&mut bytes)
        .unwrap();
    assert!(!process_retired(process).unwrap());
    assert!(child.wait().unwrap().success());
    assert!(process_retired(process).unwrap());
}

#[test]
fn caller_context_prefers_ancestry_then_exact_tmux_pane() {
    let snapshot =
        Snapshot::parse(b"$0\t@1\t%2\t42\t0\t3:a:b3:w,#\n$1\t@2\t%3\t43\t0\t1:x1:y\n").unwrap();
    let parents = HashMap::from([(99, 42)]);
    assert_eq!(
        source_context(&snapshot, 99, &parents, Some("%3")),
        Some(snapshot.targets[0].clone())
    );
    assert_eq!(
        source_context(&snapshot, 77, &HashMap::new(), Some("%3")),
        Some(snapshot.targets[1].clone())
    );
    for pane in [None, Some("3"), Some("%99"), Some("")] {
        assert!(source_context(&snapshot, 77, &HashMap::new(), pane).is_none());
    }
    let mut ambiguous = snapshot.clone();
    ambiguous.targets.push(snapshot.targets[1].clone());
    assert!(source_context(&ambiguous, 77, &HashMap::new(), Some("%3")).is_none());
    let mut dead = snapshot;
    dead.targets[1].pane.dead = true;
    assert!(source_context(&dead, 77, &HashMap::new(), Some("%3")).is_none());
}
