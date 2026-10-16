use super::*;
use std::io::Read;
use std::os::unix::fs::DirBuilderExt;
#[test]
#[ignore = "read-only kernel/process admission proof for an explicitly selected live native client"]
fn live_running_client_binding() {
    let pane = std::env::var("ANGELSTAR_BIND_PANE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let expected: u32 = std::env::var("ANGELSTAR_BIND_NATIVE_PID")
        .unwrap()
        .parse()
        .unwrap();
    let glyph = std::env::var("ANGELSTAR_BIND_GLYPH")
        .unwrap()
        .chars()
        .next()
        .unwrap();
    let client = Client::bind(pane).unwrap();
    assert_eq!(client.process.pid, expected);
    assert_eq!(client.glyph, glyph);
    client.current().unwrap();
    println!(
        "running client PID{} executable={} proof={}",
        expected,
        client.path.display(),
        client.proof().unwrap()
    );
}
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
#[ignore = "owned native PTY regression child only"]
fn running_image_child() {
    assert_eq!(std::env::var("ANGELSTAR_RUNNING_IMAGE_CHILD").unwrap(), "1");
    std::fs::write(
        std::env::var_os("ANGELSTAR_RUNNING_IMAGE_READY").unwrap(),
        b"ready",
    )
    .unwrap();
    std::thread::sleep(std::time::Duration::from_secs(120));
}

#[test]
fn running_client_survives_replaced_and_deleted_executable() {
    use std::os::unix::process::CommandExt;
    struct Seat {
        child: std::process::Child,
        _terminal: File,
    }
    impl Drop for Seat {
        fn drop(&mut self) {
            if self.child.try_wait().unwrap().is_none() {
                self.child.kill().unwrap();
            }
            self.child.wait().unwrap();
        }
    }
    fn seat(path: &Path, arg0: Option<&Path>) -> Seat {
        let (mut master, mut slave) = (-1, -1);
        assert_eq!(
            unsafe {
                libc::openpty(
                    &mut master,
                    &mut slave,
                    std::ptr::null_mut(),
                    std::ptr::null_mut(),
                    std::ptr::null_mut(),
                )
            },
            0
        );
        let terminal = unsafe { File::from_raw_fd(master) };
        let slave = unsafe { File::from_raw_fd(slave) };
        assert_eq!(
            unsafe { libc::fcntl(master, libc::F_SETFD, libc::FD_CLOEXEC) },
            0
        );
        let fd = slave.as_raw_fd();
        let ready = path.with_extension("ready");
        let mut command = Command::new(path);
        command
            .args([
                "--ignored",
                "--exact",
                "identity::tests::running_image_child",
                "--nocapture",
            ])
            .env("ANGELSTAR_RUNNING_IMAGE_CHILD", "1")
            .env("ANGELSTAR_RUNNING_IMAGE_READY", &ready)
            .stdin(slave.try_clone().unwrap())
            .stdout(slave.try_clone().unwrap())
            .stderr(slave.try_clone().unwrap());
        if let Some(arg0) = arg0 {
            command.arg0(arg0);
        }
        unsafe {
            command.pre_exec(move || {
                if libc::setsid() < 0
                    || libc::ioctl(fd, libc::TIOCSCTTY.into(), 0) < 0
                    || libc::tcsetpgrp(fd, libc::getpid()) < 0
                {
                    return Err(std::io::Error::last_os_error());
                }
                Ok(())
            });
        }
        let child = command.spawn().unwrap();
        let mut seat = Seat {
            child,
            _terminal: terminal,
        };
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
        while !ready.is_file() {
            assert!(
                seat.child.try_wait().unwrap().is_none(),
                "owned PTY child exited before ready"
            );
            assert!(
                std::time::Instant::now() < deadline,
                "owned PTY child did not enter its test body"
            );
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
        seat
    }
    let root = account_home().unwrap().join("desk/tmp").join(format!(
        "running-image-{}",
        crate::runtime::fresh_id().unwrap()
    ));
    let image = root.join("node_modules/@openai/codex/vendor/aarch64-apple-darwin/bin/codex");
    std::fs::create_dir_all(image.parent().unwrap()).unwrap();
    std::fs::copy(std::env::current_exe().unwrap(), &image).unwrap();
    let running = seat(&image, None);
    let pid = running.child.id();
    let mut client = Client::bind(pid).unwrap();
    assert_eq!(client.glyph, '›');
    let proof = client.proof().unwrap();
    let retired = root.join("retired-image");
    std::fs::rename(&image, &retired).unwrap();
    std::fs::copy("/bin/sleep", &image).unwrap();
    client.current().unwrap();
    assert_eq!(client.proof().unwrap(), proof);
    assert_eq!(Client::bind(pid).unwrap().process, client.process);
    std::fs::remove_file(&retired).unwrap();
    std::fs::remove_file(&image).unwrap();
    assert!(process_path(pid).is_err());
    client.current().unwrap();
    assert_eq!(Client::bind(pid).unwrap().process, client.process);
    assert_eq!(Client::bind_codex(pid).unwrap().process, client.process);
    client.process.start_microseconds ^= 1;
    assert!(client.current().is_err());
    let other = root.join("not-a-client");
    std::fs::copy(std::env::current_exe().unwrap(), &other).unwrap();
    let non_client = seat(&other, Some(&image));
    assert!(Client::bind(non_client.child.id()).is_err());
    drop(non_client);
    drop(running);
    assert!(Command::new("/usr/bin/trash")
        .arg(root)
        .status()
        .unwrap()
        .success());
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
