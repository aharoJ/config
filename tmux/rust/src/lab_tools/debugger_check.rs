use super::*;

struct OwnedChild(Child, crate::identity::ProcessIdentity);

impl OwnedChild {
    fn new() -> Self {
        let child = Command::new(std::env::current_exe().unwrap())
            .args(["--ignored", "--exact", "lab_tools::debugger::tests::parked"])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        let identity = crate::identity::kernel_process(child.id()).unwrap();
        Self(child, identity)
    }
}

impl Drop for OwnedChild {
    fn drop(&mut self) {
        if crate::identity::kernel_process(self.0.id()).is_some_and(|p| p.same(self.1)) {
            let _ = self.0.kill();
        }
        let _ = self.0.wait();
    }
}

fn root() -> PathBuf {
    let root = home()
        .join("desk/tmp/relay/port/rescue-check")
        .join(format!("debugger-{}", fresh().unwrap()));
    private_dir(&root).unwrap();
    root
}

#[test]
#[ignore]
fn owned_debugger_failure_and_retirement() {
    let root = root();
    let child = OwnedChild::new();
    let identity = crate::identity::kernel_process(child.0.id()).unwrap();
    let mut debugger = Debugger::new(root.join("command-failure.txt"), 12).unwrap();
    debugger.attach(child.0.id()).unwrap();
    let error = debugger
        .command("p4r_invalid_debugger_command")
        .unwrap_err();
    assert!(error.contains("error:"), "{error}");
    debugger.detach().unwrap();
    assert!(crate::identity::kernel_process(child.0.id())
        .unwrap()
        .same(identity));
    drop(debugger);
    drop(child);

    let mut child = OwnedChild::new();
    let retired = crate::identity::kernel_process(child.0.id()).unwrap();
    let mut debugger = Debugger::new(root.join("target-exit.txt"), 12).unwrap();
    debugger.attach(child.0.id()).unwrap();
    child.0.kill().unwrap();
    let _ = debugger.command("process continue");
    let _ = child.0.wait();
    let until = Instant::now() + Duration::from_secs(2);
    let status = loop {
        let status = debugger.command("process status").unwrap();
        if !status.contains(&format!("Process {} stopped", child.0.id())) {
            break status;
        }
        assert!(
            Instant::now() < until,
            "target exit was not reported: {status}"
        );
        std::thread::sleep(Duration::from_millis(10));
    };
    assert!(
        !status.contains(&format!("Process {} stopped", child.0.id())),
        "{status}"
    );
    assert!(crate::identity::kernel_process(retired.pid).is_none());
    assert!(debugger.detach().is_err());
    drop(debugger);
    drop(child);
    println!(
        "owned command failure detached; target exit refused; evidence={}",
        root.display()
    );
}

#[test]
#[ignore]
fn owned_debugger_death_and_recovery() {
    let root = root();
    let child = OwnedChild::new();
    let target = crate::identity::kernel_process(child.0.id()).unwrap();
    let mut debugger = Debugger::new(root.join("debugger-death.txt"), 12).unwrap();
    debugger.attach(child.0.id()).unwrap();
    let saved = debugger.identity.unwrap();
    let mut replacement = saved;
    replacement.start_microseconds = (replacement.start_microseconds + 1) % 1_000_000;
    debugger.identity = Some(replacement);
    debugger.signal(libc::SIGTERM);
    std::thread::sleep(Duration::from_millis(20));
    assert!(debugger.child.try_wait().unwrap().is_none());
    debugger.identity = Some(saved);
    debugger.child.kill().unwrap();
    debugger.child.wait().unwrap();
    assert!(debugger.command("process status").is_err());
    drop(debugger);
    assert!(crate::identity::kernel_process(child.0.id())
        .unwrap()
        .same(target));
    let mut recovery = Debugger::new(root.join("emergency-detach.txt"), 12).unwrap();
    recovery.attach(child.0.id()).unwrap();
    recovery.detach().unwrap();
    drop(recovery);
    drop(child);
    println!(
        "owned debugger died; generation mismatch blocked signal; recovery detached; evidence={}",
        root.display()
    );
}
