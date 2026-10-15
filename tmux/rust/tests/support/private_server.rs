use crate::identity::{self, Namespace};
use sha2::{Digest, Sha256};
use std::io::Write;
use std::os::fd::AsRawFd;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::{
    path::{Path, PathBuf},
    process::Command,
};
fn write_private(path: &Path, value: &serde_json::Value) {
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
        .unwrap();
    serde_json::to_writer(&mut file, value).unwrap();
    file.sync_all().unwrap();
}
pub fn supervised(selection: &str) -> bool {
    if std::env::var_os("KS01_RUN_CAP").is_some() {
        return false;
    }
    let root = identity::account_home()
        .unwrap()
        .join("desk/tmp")
        .join(format!("s7x-{}", &crate::runtime::fresh_id().unwrap()[..8]));
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&root)
        .unwrap();
    let owner = identity::kernel_process(std::process::id()).unwrap();
    let lease = serde_json::json!({"root":root,"nonce":format!("{}{}",crate::runtime::fresh_id().unwrap(),crate::runtime::fresh_id().unwrap()),"key":format!("{}{}",crate::runtime::fresh_id().unwrap(),crate::runtime::fresh_id().unwrap()),"owner":owner.pid,"owner_generation":[owner.start_seconds,owner.start_microseconds]});
    let mut body = lease.clone();
    body.as_object_mut().unwrap().remove("key");
    write_private(
        &root.join("lease.json"),
        &identity::signed(body, lease["key"].as_str().unwrap()).unwrap(),
    );
    let mut command = Command::new(std::env::current_exe().unwrap());
    for (key, _) in std::env::vars_os() {
        if key.to_string_lossy().starts_with("ANGELSTAR_") {
            command.env_remove(key);
        }
    }
    let out = command
        .env("KS01_RUN_CAP", lease.to_string())
        .args(["--ignored", "--exact", selection, "--nocapture"])
        .output()
        .unwrap();
    assert!(out.status.success(), "private supervisor: {out:?}");
    println!("{}", String::from_utf8_lossy(&out.stdout));
    eprint!("{}", String::from_utf8_lossy(&out.stderr));
    true
}
pub struct Server {
    pub root: PathBuf,
    pub socket: PathBuf,
}
impl Server {
    pub fn new() -> Self {
        let lease = identity::fixture_lease().unwrap();
        let records = Path::new(lease["root"].as_str().unwrap());
        let root = records.join(format!("k50-{}", &crate::runtime::fresh_id().unwrap()[..8]));
        std::fs::DirBuilder::new()
            .mode(0o700)
            .create(&root)
            .unwrap();
        let server = Self {
            socket: root.join("server"),
            root,
        };
        assert!(!server.socket.exists());
        let marker = format!(
            "{}{}",
            crate::runtime::fresh_id().unwrap(),
            crate::runtime::fresh_id().unwrap()
        );
        let record = records.join(format!(
            "{:x}.json",
            Sha256::digest(server.socket.as_os_str().as_encoded_bytes())
        ));
        let claim = serde_json::json!({"state":"claimed","path":server.socket,"marker":marker,"nonce":lease["nonce"],"owner":lease["owner"],"owner_generation":lease["owner_generation"]});
        write_private(
            &record,
            &identity::signed(claim, lease["key"].as_str().unwrap()).unwrap(),
        );
        let out = Command::new("/opt/homebrew/bin/tmux")
            .env_remove("TMUX")
            .env_remove("TMUX_PANE")
            .args(["-f", "/dev/null", "-S"])
            .arg(&server.socket)
            .args([
                "new-session",
                "-d",
                "-s",
                "private-k50",
                "-n",
                "hold",
                "--",
                "/bin/sleep",
                "120",
                ";",
                "set-option",
                "-g",
                "@ks01_socket_nonce",
                &marker,
            ])
            .output()
            .unwrap();
        assert!(out.status.success(), "{out:?}");
        let socket = std::fs::symlink_metadata(&server.socket).unwrap();
        let connection = std::os::unix::net::UnixStream::connect(&server.socket).unwrap();
        let mut pid = 0i32;
        let mut size = 4;
        assert_eq!(
            unsafe {
                libc::getsockopt(
                    connection.as_raw_fd(),
                    0,
                    2,
                    (&mut pid as *mut i32).cast(),
                    &mut size,
                )
            },
            0
        );
        assert!(pid > 0);
        let process = identity::kernel_process(pid as u32).unwrap();
        let out = Command::new("/opt/homebrew/bin/tmux")
            .args(["-N", "-S"])
            .arg(&server.socket)
            .args([
                "display-message",
                "-p",
                "#{pid}|#{start_time}|#{@ks01_socket_nonce}|#{socket_path}",
            ])
            .output()
            .unwrap();
        assert!(out.status.success());
        let text = String::from_utf8(out.stdout).unwrap();
        let values: Vec<_> = text.trim().split('|').collect();
        assert_eq!(values.len(), 4);
        assert_eq!(values[0], pid.to_string());
        assert_eq!(values[2], marker);
        assert_eq!(values[3], server.socket.to_str().unwrap());
        let start: u64 = values[1].parse().unwrap();
        let body = serde_json::json!({"path":server.socket,"device":socket.dev(),"inode":socket.ino(),"pid":pid,"generation":[process.start_seconds,process.start_microseconds],"server_start":start,"marker":marker,"nonce":lease["nonce"],"owner":lease["owner"],"owner_generation":lease["owner_generation"]});
        let pending = record.with_extension("pending");
        write_private(
            &pending,
            &identity::signed(body, lease["key"].as_str().unwrap()).unwrap(),
        );
        std::fs::rename(pending, record).unwrap();
        identity::delivery_attest(&server.socket).unwrap();
        server.command(&["set-option", "-g", "status", "off"]);
        println!(
            "signed fixture root before server {}",
            server.root.display()
        );
        server
    }
    pub fn fixtures(&self, names: &[&str]) {
        for name in names {
            let executable = std::env::current_exe().unwrap();
            self.command(&[
                "new-window",
                "-d",
                "-t",
                "private-k50",
                "-n",
                name,
                "-e",
                &format!("ANGELSTAR_FIXTURE_ROOT={}", self.root.display()),
                "-e",
                &format!("ANGELSTAR_FIXTURE_NAME={name}"),
                "--",
                executable.to_str().unwrap(),
                "--ignored",
                "--exact",
                "test_server::fixture",
                "--nocapture",
            ]);
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
            while !self.root.join(format!("{name}.json")).exists() {
                assert!(std::time::Instant::now() < deadline);
                std::thread::sleep(std::time::Duration::from_millis(5));
            }
            let pid: u32 = self
                .command(&["display-message", "-p", "-t", name, "#{pane_pid}"])
                .trim()
                .parse()
                .unwrap();
            assert_eq!(
                identity::process_path(pid).unwrap(),
                std::fs::canonicalize(&executable).unwrap()
            );
            println!(
                "direct fixture {name}: pane PID {pid}, image {}",
                executable.display()
            );
        }
    }
    pub fn command(&self, args: &[&str]) -> String {
        identity::delivery_attest(&self.socket).unwrap();
        let out = Command::new("/opt/homebrew/bin/tmux")
            .args(["-N", "-S"])
            .arg(&self.socket)
            .args(args)
            .output()
            .unwrap();
        assert!(out.status.success(), "private command {args:?}: {out:?}");
        String::from_utf8(out.stdout).unwrap()
    }
    pub fn namespace(&self) -> Namespace {
        identity::connect_signed(&self.socket).unwrap()
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        let record = identity::delivery_attest(&self.socket).unwrap();
        let pid = record["pid"].as_u64().unwrap() as u32;
        let before = identity::kernel_process(pid).unwrap();
        let m = std::fs::symlink_metadata(&self.socket).unwrap();
        let observed = self.command(&[
            "display-message",
            "-p",
            "#{pid}|#{start_time}|#{@ks01_socket_nonce}|#{socket_path}",
        ]);
        assert_eq!(
            observed.trim(),
            format!(
                "{pid}|{}|{}|{}",
                record["server_start"],
                record["marker"].as_str().unwrap(),
                self.socket.display()
            )
        );
        assert_eq!(identity::delivery_attest(&self.socket).unwrap(), record);
        let out = Command::new("/opt/homebrew/bin/tmux")
            .args(["-N", "-S"])
            .arg(&self.socket)
            .arg("kill-server")
            .output()
            .unwrap();
        assert!(
            out.status.success() && out.stdout.is_empty(),
            "private cleanup: {out:?}"
        );
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(2);
        while !identity::process_retired(before).unwrap() {
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(std::time::Duration::from_millis(5));
        }
        if self.socket.exists() {
            let after = std::fs::symlink_metadata(&self.socket).unwrap();
            assert_eq!((m.dev(), m.ino()), (after.dev(), after.ino()));
            assert!(std::os::unix::net::UnixStream::connect(&self.socket).is_err());
            std::fs::remove_file(&self.socket).unwrap();
        }
    }
}
#[test]
#[ignore = "private line editor process only"]
fn fixture() {
    let root = PathBuf::from(std::env::var_os("ANGELSTAR_FIXTURE_ROOT").unwrap());
    let name = std::env::var("ANGELSTAR_FIXTURE_NAME").unwrap();
    identity::delivery_attest(&root.join("server")).unwrap();
    let path = root.join(format!("{name}.json"));
    let control = root.join(format!("{name}.control"));
    let mut journal = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(root.join(format!("{name}.tsv")))
        .unwrap();
    let process = identity::kernel_process(std::process::id()).unwrap();
    let mut saved = unsafe { std::mem::zeroed::<libc::termios>() };
    assert_eq!(unsafe { libc::tcgetattr(0, &mut saved) }, 0);
    let mut raw = saved;
    unsafe { libc::cfmakeraw(&mut raw) };
    assert_eq!(unsafe { libc::tcsetattr(0, libc::TCSANOW, &raw) }, 0);
    let mut draft = Vec::new();
    let mut last = Vec::new();
    let mut events = 0u64;
    let mut submissions = 0u64;
    let mut busy = false;
    let mut changed = true;
    loop {
        let desired = std::fs::read_to_string(&control).unwrap_or_else(|_| "ready".into());
        assert!(["ready", "busy"].contains(&desired.trim()));
        let next = desired.trim() == "busy";
        if next != busy {
            busy = next;
            changed = true;
        }
        if changed {
            let hex = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
            journal
                .write_all(
                    format!("{events}\t{submissions}\t{}\t{}\n", hex(&draft), hex(&last))
                        .as_bytes(),
                )
                .unwrap();
            let body = serde_json::json!({"schema":"private-runtime-line-editor-v2","pid":process.pid,"generation":[process.start_seconds,process.start_microseconds],"draft":hex(&draft),"last":hex(&last),"events":events,"submissions":submissions,"busy":busy});
            let pending = path.with_extension("pending");
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&pending)
                .unwrap();
            file.write_all(&serde_json::to_vec(&body).unwrap()).unwrap();
            std::fs::rename(pending, &path).unwrap();
            let mut rendered = b"\r\x1b[2Kfixture> ".to_vec();
            rendered.extend_from_slice(&draft);
            std::io::stdout().write_all(&rendered).unwrap();
            std::io::stdout().flush().unwrap();
            changed = false;
        }
        let mut descriptor = libc::pollfd {
            fd: 0,
            events: libc::POLLIN,
            revents: 0,
        };
        let count = unsafe { libc::poll(&mut descriptor, 1, 20) };
        assert!(count >= 0);
        if count == 0 {
            continue;
        }
        let mut byte = [0];
        if unsafe { libc::read(0, byte.as_mut_ptr().cast(), 1) } <= 0 {
            break;
        }
        events += 1;
        match byte[0] {
            b'\r' | b'\n' => {
                last = std::mem::take(&mut draft);
                submissions += 1;
            }
            127 => {
                draft.pop();
            }
            32..=126 => draft.push(byte[0]),
            _ => panic!("unsupported fixture input"),
        };
        changed = true;
    }
    assert_eq!(unsafe { libc::tcsetattr(0, libc::TCSANOW, &saved) }, 0);
}

#[test]
#[ignore = "signed private attestation rejection cases"]
fn lease_rejections() {
    if supervised("test_server::lease_rejections") {
        return;
    }
    let server = Server::new();
    let lease = identity::fixture_lease().unwrap();
    let root = Path::new(lease["root"].as_str().unwrap());
    let path = root.join(format!(
        "{:x}.json",
        Sha256::digest(server.socket.as_os_str().as_encoded_bytes())
    ));
    let original = std::fs::read(&path).unwrap();
    let good = identity::read_private(&path).unwrap();
    for field in ["device", "inode", "generation", "owner", "nonce", "marker"] {
        let mut changed = good["body"].clone();
        changed[field] = serde_json::Value::Null;
        let changed = identity::signed(changed, lease["key"].as_str().unwrap()).unwrap();
        std::fs::write(&path, changed.to_string()).unwrap();
        assert!(
            identity::delivery_attest(&server.socket).is_err(),
            "{field}"
        );
        std::fs::write(&path, &original).unwrap();
    }
    let mut forged = good.clone();
    forged["mac"] = serde_json::json!("0".repeat(64));
    std::fs::write(&path, forged.to_string()).unwrap();
    assert!(identity::delivery_attest(&server.socket).is_err());
    std::fs::write(&path, &original).unwrap();
    let alias = server.root.join("alias");
    std::os::unix::fs::symlink(&server.socket, &alias).unwrap();
    assert!(identity::delivery_attest(&alias).is_err());
    identity::delivery_attest(&server.socket).unwrap();
}

#[test]
#[ignore = "explicit distinct signed-server retirement observations"]
fn retirement_observations() {
    if supervised("test_server::retirement_observations") {
        return;
    }
    for observation in 0..16 {
        let server = Server::new();
        println!(
            "retirement observation {observation} {}",
            server.socket.display()
        );
        drop(server);
    }
}
