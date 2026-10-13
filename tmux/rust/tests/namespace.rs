#![cfg(target_os = "macos")]

use angelstar_runtime::target::{kernel_process, Error, Namespace};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::UnixListener;
use std::path::PathBuf;

struct Fixture {
    root: PathBuf,
    executable: PathBuf,
    socket: PathBuf,
    _listener: UnixListener,
}

impl Fixture {
    fn new() -> Self {
        static SERIAL: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
            .join("desk/tmp")
            .join(format!(
                "test-k05-namespace-{}-{}",
                std::process::id(),
                SERIAL.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            ));
        std::fs::create_dir(&root).unwrap();
        std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700)).unwrap();
        let executable = root.join("explicit-client");
        std::fs::write(&executable, "fixture executable, never executed").unwrap();
        std::fs::set_permissions(&executable, std::fs::Permissions::from_mode(0o700)).unwrap();
        let socket = root.join("server");
        let listener = UnixListener::bind(&socket).unwrap();
        Self {
            root,
            executable,
            socket,
            _listener: listener,
        }
    }
    fn connect(&self) -> Result<Namespace, Error> {
        Namespace::connect(
            &self.executable,
            &self.socket,
            kernel_process(std::process::id()).unwrap(),
        )
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        for path in [
            &self.socket,
            &self.executable,
            &self.root.join("prior-server"),
            &self.root.join("prior-client"),
            &self.root.join("snapshot"),
            &self.root.join("descendant"),
            &self.root.join("socket-alias"),
        ] {
            if let Err(error) = std::fs::remove_file(path) {
                assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
            }
        }
        std::fs::remove_dir(&self.root).unwrap();
    }
}

#[test]
fn explicit_namespace_binds_observed_peer_kernel_generation() {
    let fixture = Fixture::new();
    let namespace = fixture.connect().unwrap();
    assert_eq!(
        namespace.server(),
        kernel_process(std::process::id()).unwrap()
    );
    namespace.revalidate().unwrap();
}

#[test]
fn wrong_server_generation_is_not_an_admitted_namespace() {
    let fixture = Fixture::new();
    let mut expected = kernel_process(std::process::id()).unwrap();
    expected.start_microseconds = (expected.start_microseconds + 1) % 1_000_000;
    assert!(matches!(
        Namespace::connect(&fixture.executable, &fixture.socket, expected),
        Err(Error::Changed)
    ));
}

#[test]
fn socket_replacement_does_not_rebind_an_existing_namespace() {
    let fixture = Fixture::new();
    let namespace = fixture.connect().unwrap();
    std::fs::rename(&fixture.socket, fixture.root.join("prior-server")).unwrap();
    let _replacement = UnixListener::bind(&fixture.socket).unwrap();
    assert!(matches!(namespace.revalidate(), Err(Error::Changed)));
}

#[test]
fn executable_replacement_does_not_rebind_an_existing_namespace() {
    let fixture = Fixture::new();
    let namespace = fixture.connect().unwrap();
    std::fs::rename(&fixture.executable, fixture.root.join("prior-client")).unwrap();
    std::fs::write(&fixture.executable, "replacement").unwrap();
    std::fs::set_permissions(&fixture.executable, std::fs::Permissions::from_mode(0o700)).unwrap();
    assert!(matches!(namespace.revalidate(), Err(Error::Changed)));
}

#[test]
fn nonprivate_parent_or_noncanonical_executable_is_not_admitted() {
    let fixture = Fixture::new();
    std::fs::set_permissions(&fixture.root, std::fs::Permissions::from_mode(0o755)).unwrap();
    assert!(matches!(fixture.connect(), Err(Error::InvalidNamespace)));
    std::fs::set_permissions(&fixture.root, std::fs::Permissions::from_mode(0o700)).unwrap();
    let alias = fixture.root.join("prior-client");
    std::os::unix::fs::symlink(&fixture.executable, &alias).unwrap();
    assert!(matches!(
        Namespace::connect(
            &alias,
            &fixture.socket,
            kernel_process(std::process::id()).unwrap()
        ),
        Err(Error::InvalidNamespace)
    ));
}

#[test]
fn in_place_executable_change_is_not_an_unchanged_binding() {
    let fixture = Fixture::new();
    let namespace = fixture.connect().unwrap();
    std::fs::write(&fixture.executable, "different executable contents").unwrap();
    assert!(matches!(namespace.revalidate(), Err(Error::Changed)));
}

#[test]
fn extended_acl_parent_is_not_private_namespace_authority() {
    let fixture = Fixture::new();
    assert!(std::process::Command::new("/bin/chmod")
        .args(["+a", "everyone allow list,search"])
        .arg(&fixture.root)
        .status()
        .unwrap()
        .success());
    let result = fixture.connect();
    assert!(std::process::Command::new("/bin/chmod")
        .arg("-N")
        .arg(&fixture.root)
        .status()
        .unwrap()
        .success());
    assert!(matches!(result, Err(Error::InvalidNamespace)));
}

#[test]
fn bound_capture_ignores_ambient_routing_and_rejects_wrong_server_banner() {
    let fixture = Fixture::new();
    let pid = std::process::id();
    let script = format!("#!/bin/sh\n[ \"$1\" = -N ] && [ \"$2\" = -S ] && [ \"$3\" = '{}' ] || exit 9\n[ -z \"${{TMUX+x}}\" ] && [ -z \"${{TMUX_PANE+x}}\" ] || exit 8\nprintf '{pid}\\n$10\\t@11\\t%%12\\t123\\t0\\t1:s1:w\\n'\n", fixture.socket.display());
    std::fs::write(&fixture.executable, script).unwrap();
    let namespace = fixture.connect().unwrap();
    let snapshot = namespace.capture().unwrap();
    assert_eq!(
        angelstar_runtime::target::resolve(&snapshot, "s", "w", None)
            .unwrap()
            .pane
            .id
            .0,
        12
    );
    drop(namespace);
    std::fs::write(&fixture.executable, "#!/bin/sh\nprintf '1\\n'\n").unwrap();
    assert!(matches!(
        fixture.connect().unwrap().capture(),
        Err(Error::Changed)
    ));
}

#[test]
#[ignore = "explicit read-only native namespace proof; no pane mutations"]
#[cfg(any())]
fn native_bound_capture_matches_kernel_peer_and_existing_server() {
    let socket = std::path::Path::new("/private/tmp/tmux-501/default");
    let executable = std::fs::canonicalize("/opt/homebrew/bin/tmux").unwrap();
    let output = std::process::Command::new(&executable)
        .args(["-N", "-S"])
        .arg(socket)
        .args(["display-message", "-p", "#{pid}"])
        .output()
        .unwrap();
    assert!(output.status.success());
    let pid = String::from_utf8(output.stdout)
        .unwrap()
        .trim()
        .parse()
        .unwrap();
    let expected = kernel_process(pid).unwrap();
    let namespace = Namespace::connect(&executable, socket, expected).unwrap();
    assert!(namespace.is_protected_socket());
    namespace.verify_peer_image().unwrap();
    let snapshot = namespace.capture().unwrap();
    angelstar_runtime::target::resolve(&snapshot, "config(tmux-to-rust)", "codex", None).unwrap();
    assert_eq!(namespace.server(), expected);
    let unbound = angelstar_runtime::delivery::prepare(
        "config(tmux-to-rust)",
        "codex",
        None,
        "#k05 metadata only",
        "unused",
    )
    .unwrap();
    assert!(matches!(
        unbound.revalidate_in(&namespace),
        Err(angelstar_runtime::delivery::Error::Target(Error::Changed))
    ));
}

#[test]
fn stalled_capture_is_finitely_killed_and_reaped() {
    let fixture = Fixture::new();
    std::fs::write(&fixture.executable, "#!/bin/sh\nexec /bin/sleep 5\n").unwrap();
    let namespace = fixture.connect().unwrap();
    let start = std::time::Instant::now();
    let result = namespace.capture();
    assert!(matches!(result, Err(Error::CaptureFailed)));
    assert!(start.elapsed() < std::time::Duration::from_secs(3));
}

#[test]
fn nonzero_signal_and_oversized_capture_cannot_supply_a_snapshot() {
    let fixture = Fixture::new();
    for script in [
        format!("#!/bin/sh\nprintf '{}\\n'\nexit 7\n", std::process::id()),
        "#!/bin/sh\nkill -TERM $$\n".to_owned(),
        "#!/bin/sh\nexec /usr/bin/head -c 9000000 /dev/zero\n".to_owned(),
    ] {
        std::fs::write(&fixture.executable, script).unwrap();
        let result = fixture.connect().unwrap().capture();
        assert!(matches!(result, Err(Error::CaptureFailed)));
    }
}

#[test]
fn preparation_and_revalidation_use_the_bound_capture_not_ambient_tmux() {
    let fixture = Fixture::new();
    let script = format!(
        "#!/bin/sh\nprintf '{}\\n$10\\t@11\\t%%12\\t123\\t0\\t1:s1:w\\n'\n",
        std::process::id()
    );
    std::fs::write(&fixture.executable, script).unwrap();
    let namespace = fixture.connect().unwrap();
    let prepared = angelstar_runtime::delivery::prepare_in(
        &namespace,
        "s",
        "w",
        None,
        "#k05 exact 会🦀",
        "unused",
    )
    .unwrap();
    assert_eq!(prepared.target().pane.id.0, 12);
    assert!(prepared.source().is_none());
    assert_eq!(prepared.envelope().message, "#k05 exact 会🦀");
    prepared.revalidate_in(&namespace).unwrap();
    std::fs::write(&fixture.executable, "changed").unwrap();
    assert!(matches!(
        prepared.revalidate_in(&namespace),
        Err(angelstar_runtime::delivery::Error::Target(Error::Changed))
    ));
}

#[test]
fn selected_script_does_not_match_the_listener_kernel_process_image() {
    let fixture = Fixture::new();
    assert!(matches!(
        fixture.connect().unwrap().verify_peer_image(),
        Err(Error::InvalidNamespace)
    ));
}

#[test]
fn capture_refuses_uncontained_descendant_without_signaling_a_pidfile() {
    let fixture = Fixture::new();
    let pid_path = fixture.root.join("descendant");
    let script = format!(
        "#!/bin/sh\n/bin/sleep 0.8 >/dev/null 2>&1 &\nprintf '%s' \"$!\" > '{}'\nprintf '{}\\n'\n",
        pid_path.display(),
        std::process::id()
    );
    std::fs::write(&fixture.executable, script).unwrap();
    let result = fixture.connect().unwrap().capture();
    let pid = std::fs::read_to_string(pid_path).unwrap().parse().unwrap();
    for _ in 0..50 {
        if kernel_process(pid).is_none() {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }
    let remaining = kernel_process(pid);
    assert!(matches!(result, Err(Error::CaptureFailed)));
    assert!(
        remaining.is_none(),
        "owned descendant remained {remaining:?}"
    );
}

#[test]
fn cleanup_protection_refuses_context_aliases_and_malformed_values_without_signals() {
    use angelstar_runtime::target::cleanup_socket_protected as protected;
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;
    let fixture = Fixture::new();
    let context = format!("{},123,0", fixture.socket.display());
    assert!(protected(&fixture.socket, Some(OsStr::new(&context)), 501));
    let alias = fixture.root.join("socket-alias");
    std::os::unix::fs::symlink(&fixture.socket, &alias).unwrap();
    assert!(protected(&alias, Some(OsStr::new(&context)), 501));
    std::fs::remove_file(&alias).unwrap();
    std::fs::hard_link(&fixture.socket, &alias).unwrap();
    assert!(protected(&alias, Some(OsStr::new(&context)), 501));
    for value in [
        "",
        "invalid",
        "/tmp/anything,not-pid,0",
        "/tmp/anything,123,",
    ] {
        assert!(protected(&fixture.socket, Some(OsStr::new(value)), 501));
    }
    assert!(protected(
        &fixture.socket,
        Some(OsStr::from_bytes(b"/tmp/\xff,123,0")),
        501
    ));
    assert!(protected(
        std::path::Path::new("/private/tmp/tmux-501/default"),
        None,
        501
    ));
    assert!(protected(
        std::path::Path::new("/tmp/tmux-501/default"),
        None,
        501
    ));
    let mut signals = 0;
    if !protected(&fixture.socket, Some(OsStr::new(&context)), 501) {
        signals += 1;
    }
    assert_eq!(signals, 0);
    assert!(!protected(&fixture.socket, None, 501));
    assert!(protected(
        std::path::Path::new("/tmp/comma,socket"),
        Some(OsStr::new("/tmp/comma,socket,123,0")),
        501
    ));
}

#[test]
fn bound_preparation_refuses_changed_destination_and_source_ambiguity() {
    let fixture = Fixture::new();
    let pid = std::process::id();
    let path = fixture.root.join("snapshot");
    let initial = format!("{pid}\n$10\t@11\t%12\t{pid}\t0\t1:s1:w\n");
    std::fs::write(&path, &initial).unwrap();
    std::fs::write(
        &fixture.executable,
        format!("#!/bin/sh\nexec /bin/cat '{}'\n", path.display()),
    )
    .unwrap();
    let namespace = fixture.connect().unwrap();
    let prepared =
        angelstar_runtime::delivery::prepare_in(&namespace, "s", "w", None, "#k05 test", "unused")
            .unwrap();
    assert_eq!(prepared.source(), Some(prepared.target()));
    std::fs::write(&path, initial.replace(&format!("\t{pid}\t"), "\t123\t")).unwrap();
    assert!(matches!(
        prepared.revalidate_in(&namespace),
        Err(angelstar_runtime::delivery::Error::Target(Error::Changed))
    ));
    std::fs::write(
        &path,
        format!("{initial}$10\t@21\t%22\t{pid}\t0\t1:s5:decoy\n"),
    )
    .unwrap();
    assert!(matches!(
        prepared.revalidate_in(&namespace),
        Err(angelstar_runtime::delivery::Error::Source(Error::Changed))
    ));
}
