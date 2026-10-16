use super::super::*;
use serde_json::{json, Value};
use std::cell::RefCell;
use std::os::unix::net::UnixListener;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Fault {
    Recover,
    Timeout,
    Exit,
    Socket,
}

struct State {
    fault: Fault,
    target: crate::identity::ProcessIdentity,
    socket: PathBuf,
    listener: Option<UnixListener>,
    children: Vec<Value>,
}

thread_local! { static STATE: RefCell<Option<State>> = const { RefCell::new(None) }; }

pub(in crate::lab_tools::rescue) struct Trace {
    path: PathBuf,
    value: Option<Value>,
    began: Option<Instant>,
}

impl Trace {
    pub(in crate::lab_tools::rescue) fn new(c: &Config, e: &Evidence, p: &Proof<'_>) -> Self {
        let value = STATE.with(|s| s.borrow().as_ref().map(|_| json!({
            "entry_epoch_ms": epoch_ms(), "pid": c.pid, "socket": c.socket,
            "expected": {"socket_identity": p.socket_id, "process_start": p.start,
                "executable": p.exe, "sha256": p.sha, "uuid": p.uuid},
            "observed": {"socket_identity": socket_identity(&c.socket), "process_start": lab::process_start(c.pid),
                "executable": lab::path(c.pid).and_then(|p| fs::canonicalize(p).ok()), "sha256": digest(p.exe).ok()},
            "invoked": false, "detached": false, "bound_seconds": super::SECONDS,
        })));
        let trace = Self {
            path: e.root.join("emergency-detach.json"),
            value,
            began: None,
        };
        trace.save();
        trace
    }
    fn save(&self) {
        if let Some(value) = &self.value {
            write(&self.path, serde_json::to_vec_pretty(value).unwrap()).unwrap();
        }
    }
    pub(in crate::lab_tools::rescue) fn owner(&mut self, output: &Result<Output>) {
        if let (Some(value), Ok(output)) = (&mut self.value, output) {
            value["observed"]["owners"] = json!(owners(&output.text()));
            value["owner_exit"] = json!(output.code);
        }
    }
    pub(in crate::lab_tools::rescue) fn uuid(&mut self, output: &Result<Output>) {
        if let (Some(value), Ok(output)) = (&mut self.value, output) {
            value["observed"]["uuid_output"] = json!(output.text());
            value["uuid_exit"] = json!(output.code);
        }
    }
    pub(in crate::lab_tools::rescue) fn begin(&mut self, commands: &[String], seconds: u64) {
        if let Some(value) = &mut self.value {
            value["identity"] = json!("PASS");
            value["commands"] = json!(commands);
            value["argv"] = json!([
                "/usr/bin/lldb",
                "--no-lldbinit",
                "-b",
                "-s",
                self.path
                    .parent()
                    .unwrap()
                    .join("emergency-detach-command-file.txt")
            ]);
            value["invocation_start_epoch_ms"] = json!(epoch_ms());
            value["invoked"] = json!(true);
            value["bound_seconds"] = json!(seconds);
            self.began = Some(Instant::now());
        }
        self.save();
    }
    pub(in crate::lab_tools::rescue) fn finished(&mut self, output: &Result<Output>, pid: u32) {
        if let Some(value) = &mut self.value {
            value["invocation_end_epoch_ms"] = json!(epoch_ms());
            value["elapsed_ms"] = json!(self.began.unwrap().elapsed().as_millis());
            match output {
                Ok(output) => {
                    value["exit"] = json!(output.code);
                    value["detached"] = json!(
                        output.code == 0
                            && output.text().contains(&format!("Process {pid} detached"))
                    );
                }
                Err(error) => value["error"] = json!(error),
            }
        }
    }
}
impl Drop for Trace {
    fn drop(&mut self) {
        if let Some(value) = &mut self.value {
            value["end_epoch_ms"] = json!(epoch_ms());
        }
        self.save();
    }
}

pub(in crate::lab_tools::rescue) fn lifecycle(pid: u32, event: &str) {
    STATE.with(|state| {
        if let Some(state) = state.borrow_mut().as_mut() {
            if let Some(child) = state.children.iter_mut().rev().find(|v| v["pid"] == pid) {
                child["events"].as_array_mut().unwrap().push(json!({"event": event,
                    "epoch_ms": epoch_ms(), "image": lab::path(pid), "argv": lab::process_args(pid)}));
            }
        }
    });
}

pub(in crate::lab_tools::rescue) fn spawned(pid: u32, command: &Command) {
    STATE.with(|state| {
        if let Some(state) = state.borrow_mut().as_mut() {
            state.children.push(json!({"pid": pid, "identity": crate::identity::kernel_process(pid),
                "program": command.get_program().to_string_lossy(),
                "argv": command.get_args().map(|s| s.to_string_lossy().into_owned()).collect::<Vec<_>>(),
                "spawn_epoch_ms": epoch_ms(), "image_at_spawn": lab::path(pid), "events": []}));
        }
    });
}

pub(in crate::lab_tools::rescue) fn fail_primary(
    d: &mut debugger::Debugger,
    root: &Path,
) -> Result<()> {
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        let Some(state) = state.as_mut() else {
            return Ok(());
        };
        let primary = d.crash_for_fixture()?;
        write(
            &root.join("fixture-primary-fault.json"),
            serde_json::to_vec_pretty(&primary).unwrap(),
        )?;
        match state.fault {
            Fault::Exit => {
                signal_owned(state.target, libc::SIGTERM);
                assert!(retire(state.target, Duration::from_secs(3)));
            }
            Fault::Socket => {
                fs::rename(&state.socket, state.socket.with_extension("original"))
                    .map_err(|e| e.to_string())?;
                state.listener =
                    Some(UnixListener::bind(&state.socket).map_err(|e| e.to_string())?);
            }
            _ => (),
        }
        Err("injected-primary-debugger-death-after-confirmed-write".into())
    })
}

pub(in crate::lab_tools::rescue) fn emergency_commands(mut commands: Vec<String>) -> Vec<String> {
    STATE.with(|state| {
        if state
            .borrow()
            .as_ref()
            .is_some_and(|s| s.fault == Fault::Timeout)
        {
            commands.insert(1, "process continue".into());
        }
    });
    commands
}

fn signal_owned(identity: crate::identity::ProcessIdentity, signal: i32) {
    if crate::identity::kernel_process(identity.pid).is_some_and(|p| p.same(identity)) {
        unsafe {
            libc::kill(identity.pid as i32, signal);
        }
    }
}

fn retire(identity: crate::identity::ProcessIdentity, budget: Duration) -> bool {
    let until = Instant::now() + budget;
    while crate::identity::kernel_process(identity.pid).is_some_and(|p| p.same(identity)) {
        if Instant::now() >= until {
            return false;
        }
        std::thread::sleep(Duration::from_millis(5));
    }
    true
}

struct Owner {
    root: PathBuf,
    server: crate::identity::ProcessIdentity,
    hold: crate::identity::ProcessIdentity,
}

impl Drop for Owner {
    fn drop(&mut self) {
        for identity in [self.server, self.hold] {
            signal_owned(identity, libc::SIGTERM);
            if !retire(identity, Duration::from_secs(2)) {
                signal_owned(identity, libc::SIGKILL);
                assert!(retire(identity, Duration::from_secs(2)));
            }
        }
        write(
            &self.root.join("cleanup.json"),
            serde_json::to_vec_pretty(&json!({
                "server": self.server, "hold": self.hold, "server_retired": true,
                "hold_retired": true, "epoch_ms": epoch_ms(), "manual_debugger_recovery": false,
            }))
            .unwrap(),
        )
        .unwrap();
    }
}

struct Environment(Vec<(String, Option<std::ffi::OsString>)>);
impl Environment {
    fn apply(values: &[(&str, Option<String>)]) -> Self {
        let mut saved = Vec::new();
        for (key, value) in values {
            saved.push((key.to_string(), std::env::var_os(key)));
            if let Some(value) = value {
                std::env::set_var(key, value);
            } else {
                std::env::remove_var(key);
            }
        }
        Self(saved)
    }
}
impl Drop for Environment {
    fn drop(&mut self) {
        for (key, value) in &self.0 {
            if let Some(value) = value {
                std::env::set_var(key, value);
            } else {
                std::env::remove_var(key);
            }
        }
    }
}

struct Confirmation(i32);
impl Confirmation {
    fn typed(pid: u32) -> Self {
        let mut pipe = [0; 2];
        assert_eq!(unsafe { libc::pipe(pipe.as_mut_ptr()) }, 0);
        let saved = unsafe { libc::dup(0) };
        assert!(saved >= 0);
        let line = format!("{pid}\n");
        assert_eq!(
            unsafe { libc::write(pipe[1], line.as_ptr().cast(), line.len()) },
            line.len() as isize
        );
        unsafe {
            libc::close(pipe[1]);
            assert_eq!(libc::dup2(pipe[0], 0), 0);
            libc::close(pipe[0]);
        }
        Self(saved)
    }
}
impl Drop for Confirmation {
    fn drop(&mut self) {
        unsafe {
            libc::dup2(self.0, 0);
            libc::close(self.0);
        }
    }
}

fn runtime() -> PathBuf {
    let exe = std::env::current_exe().unwrap();
    let beside = exe.parent().unwrap().join("angelstar-runtime");
    if beside.is_file() {
        beside
    } else {
        exe.parent()
            .unwrap()
            .parent()
            .unwrap()
            .join("angelstar-runtime")
    }
}

fn create(root: &Path) -> Owner {
    private_dir(root).unwrap();
    let socket = root.join("server");
    let created = bounded(
        Command::new(TMUX)
            .args(["-f", "/dev/null", "-S"])
            .arg(&socket)
            .args([
                "new-session",
                "-d",
                "-s",
                "lab-rescue-emergency",
                "-n",
                "hold",
                "--",
                &runtime().to_string_lossy(),
                "--surface",
                "tmux-lab",
                "hold",
            ])
            .env_remove("TMUX")
            .env_remove("TMUX_PANE"),
        5,
    )
    .unwrap();
    assert_eq!(created.code, 0, "{}", String::from_utf8_lossy(&created.err));
    let peer = std::os::unix::net::UnixStream::connect(&socket).unwrap();
    let (mut pid, mut size) = (0i32, 4);
    assert_eq!(
        unsafe {
            libc::getsockopt(
                peer.as_raw_fd(),
                0,
                2,
                (&mut pid as *mut i32).cast(),
                &mut size,
            )
        },
        0
    );
    let server = crate::identity::kernel_process(pid as u32).unwrap();
    assert_eq!(lab::path(server.pid).unwrap(), TMUX);
    let hold_pid = query(&socket, &["display-message", "-p", "#{pane_pid}"], 2)
        .unwrap()
        .parse()
        .unwrap();
    let hold = crate::identity::kernel_process(hold_pid).unwrap();
    assert_eq!(hold.parent, server.pid);
    write(&root.join("lease.json"), serde_json::to_vec_pretty(&json!({"socket": socket,
        "socket_identity": socket_identity(&socket), "server": server, "hold": hold,
        "owner": crate::identity::kernel_process(std::process::id()), "nonce": fresh().unwrap(),
        "created_epoch_ms": epoch_ms(), "runtime": runtime(), "runtime_sha256": digest(&runtime()).unwrap(),
        "fixture": std::env::current_exe().unwrap(), "fixture_sha256": digest(&std::env::current_exe().unwrap()).unwrap(),
    })).unwrap()).unwrap();
    let owner = Owner {
        root: root.into(),
        server,
        hold,
    };
    assert_eq!(tmux(&socket, &["copy-mode"], 2).unwrap().code, 0);
    let _ = bounded(
        Command::new(TMUX)
            .args(["-N", "-S"])
            .arg(&socket)
            .args(["send-keys", "-X", "-N", "4294967295", "cursor-down"])
            .env_remove("TMUX")
            .env_remove("TMUX_PANE"),
        1,
    )
    .unwrap();
    owner
}

fn latest(root: &Path) -> PathBuf {
    let mut dirs = fs::read_dir(root)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().starts_with("rescue-"))
        .map(|e| e.path())
        .collect::<Vec<_>>();
    dirs.sort();
    dirs.pop().unwrap()
}

fn case(fault: Fault) {
    let root = home()
        .join("desk/tmp/relay/lead-next/rescue-emergency/native")
        .join(format!("{fault:?}-{}", &fresh().unwrap()[..12]));
    let owner = create(&root);
    let socket = root.join("server");
    let _environment = Environment::apply(&[
        ("TMUX_LOOP_RESCUE_LAB", Some("1".into())),
        (
            "TMUX_LOOP_RESCUE_LAB_ROOT",
            Some(root.to_string_lossy().into_owned()),
        ),
        (
            "TMUX_LOOP_RESCUE_SOCKET",
            Some(socket.to_string_lossy().into_owned()),
        ),
        ("TMUX_LOOP_RESCUE_PID", Some(owner.server.pid.to_string())),
        (
            "TMUX_LOOP_RESCUE_EVIDENCE_ROOT",
            Some(root.to_string_lossy().into_owned()),
        ),
        ("TMUX_LOOP_RESCUE_COUNT", None),
        ("TMUX_LOOP_RESCUE_OBSERVATION", None),
        ("TMUX_LOOP_RESCUE_OBSERVATION_NONCE", None),
        ("TMUX_LOOP_RESCUE_LAB_WRITE_EXCEPTION", None),
    ]);
    assert_eq!(entry(&["--observe".into()]), 0, "{}", root.display());
    let observation = latest(&root).join("observation.tsv");
    let values = record(&observation).unwrap();
    let _observed = Environment::apply(&[
        (
            "TMUX_LOOP_RESCUE_COUNT",
            Some(values["observed_count"].clone()),
        ),
        (
            "TMUX_LOOP_RESCUE_OBSERVATION",
            Some(observation.to_string_lossy().into_owned()),
        ),
        (
            "TMUX_LOOP_RESCUE_OBSERVATION_NONCE",
            Some(values["nonce"].clone()),
        ),
    ]);
    STATE.with(|s| {
        *s.borrow_mut() = Some(State {
            fault,
            target: owner.server,
            socket: socket.clone(),
            listener: None,
            children: Vec::new(),
        })
    });
    let typed = Confirmation::typed(owner.server.pid);
    let code = entry(&[]);
    drop(typed);
    let state = STATE.with(|s| s.borrow_mut().take().unwrap());
    let result_root = latest(&root);
    let trace: Value =
        serde_json::from_slice(&fs::read(result_root.join("emergency-detach.json")).unwrap())
            .unwrap();
    let result = fs::read_to_string(result_root.join("result.txt")).unwrap();
    let primary: Value =
        serde_json::from_slice(&fs::read(result_root.join("fixture-primary-fault.json")).unwrap())
            .unwrap();
    assert_eq!(code, 1);
    assert!(
        result.contains("rescue=WRITE_UNCERTAIN\nwrite=ATTEMPTED"),
        "{result}"
    );
    assert_eq!(primary["attached"], true);
    let primary_pid = primary["identity"]["pid"].as_u64().unwrap() as i32;
    let mut status = 0;
    assert_eq!(
        unsafe { libc::waitpid(primary_pid, &mut status, libc::WNOHANG) },
        -1
    );
    assert_eq!(
        std::io::Error::last_os_error().raw_os_error(),
        Some(libc::ECHILD)
    );
    let mut emergency_children = state
        .children
        .iter()
        .filter(|r| r["program"] == "/usr/bin/lldb")
        .cloned()
        .collect::<Vec<_>>();
    for child in &mut emergency_children {
        let pid = child["pid"].as_u64().unwrap() as i32;
        let reaped = unsafe { libc::waitpid(pid, &mut status, libc::WNOHANG) } == -1
            && std::io::Error::last_os_error().raw_os_error() == Some(libc::ECHILD);
        child["reaped_by_runtime"] = json!(reaped);
        let events = child["events"].as_array().unwrap();
        if let (Some(term), Some(reaped)) = (
            events.iter().find(|v| v["event"] == "TERM-deadline"),
            events.iter().find(|v| v["event"] == "reaped"),
        ) {
            let term = term["epoch_ms"].as_u64().unwrap();
            let reaped = reaped["epoch_ms"].as_u64().unwrap();
            child["deadline_from_spawn_ms"] =
                json!(term - child["spawn_epoch_ms"].as_u64().unwrap());
            child["cleanup_after_term_ms"] = json!(reaped - term);
        }
        assert!(reaped, "{child}");
    }
    write(
        &root.join("fixture-result.json"),
        serde_json::to_vec_pretty(&json!({"fault": format!("{fault:?}"),
            "code": code, "trace": trace, "result": result, "primary": primary,
            "emergency_children": emergency_children, "root": result_root, "manual_recovery": false,
        }))
        .unwrap(),
    )
    .unwrap();
    println!(
        "native automatic fallback {fault:?}: evidence={}",
        root.display()
    );
    drop(state);
    drop(owner);
    match fault {
        Fault::Recover => {
            assert_eq!(trace["identity"], "PASS");
            assert_eq!(trace["detached"], true);
            assert_eq!(emergency_children.len(), 1);
            assert!(result.contains("server_responsiveness=RECOVERED"));
        }
        Fault::Timeout => {
            assert_eq!(trace["exit"], 124);
            assert_eq!(trace["detached"], false);
            assert_eq!(emergency_children.len(), 1);
            assert!(
                trace["elapsed_ms"].as_u64().unwrap() < 7_000,
                "legacy five-second bound exceeded: {trace}"
            );
            assert_eq!(trace["bound_seconds"], 5);
            assert!(result.contains("debugger=UNCONFIRMED"));
        }
        _ => {
            assert_eq!(trace["invoked"], false);
            assert!(emergency_children.is_empty());
        }
    }
}

#[test]
#[ignore]
fn automatic_fallback() {
    case(Fault::Recover);
}
#[test]
#[ignore]
fn automatic_timeout() {
    case(Fault::Timeout);
}
#[test]
#[ignore]
fn exited_target() {
    case(Fault::Exit);
}
#[test]
#[ignore]
fn changed_socket() {
    case(Fault::Socket);
}
