#![cfg(target_os = "macos")]

use angelstar_runtime::{delivery, target};
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::Command;

struct Server {
    root: PathBuf,
    executable: PathBuf,
    socket: PathBuf,
    identity: target::ProcessIdentity,
    socket_identity: (u64, u64),
}

impl Server {
    fn cleanup_helper() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../tests/cleanup_guard.py")
    }
    fn command(&self, args: &[&str]) -> String {
        let output = Command::new(&self.executable)
            .arg("-N")
            .arg("-S")
            .arg(&self.socket)
            .args(args)
            .output()
            .unwrap();
        assert!(output.status.success(), "{args:?}: {output:?}");
        String::from_utf8(output.stdout).unwrap().trim().to_owned()
    }
    fn namespace(&self) -> target::Namespace {
        target::Namespace::connect(&self.executable, &self.socket, self.identity).unwrap()
    }
    fn condition(&self, pane: &str, condition: &str) -> String {
        self.command(&[
            "if-shell",
            "-F",
            "-t",
            pane,
            condition,
            "display-message -p 1",
            "display-message -p 0",
        ])
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        use std::os::unix::fs::MetadataExt;
        let namespace = self.namespace();
        assert!(
            !namespace.is_protected_socket(),
            "refusing protected socket cleanup"
        );
        let current = std::fs::symlink_metadata(&self.socket).unwrap();
        assert_eq!(
            (current.dev(), current.ino()),
            self.socket_identity,
            "refusing replaced socket cleanup"
        );
        namespace.verify_peer_image().unwrap();
        drop(namespace);
        let output = Command::new("/usr/bin/python3")
            .arg(Self::cleanup_helper())
            .args(["stop", "tmux", "-S"])
            .arg(&self.socket)
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "socket lease cleanup refused: {output:?}"
        );
        if let Err(error) = std::fs::remove_file(&self.socket) {
            assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
        }
        std::fs::remove_dir(&self.root).unwrap();
    }
}

#[test]
#[ignore = "owned private desk socket/server and test-k05 session only; no pane input"]
fn owned_server_guard_handles_literal_names_and_rejects_rename_respawn_and_copy_mode() {
    if std::env::var_os("KS01_RUN_CAP").is_none() {
        let output = Command::new("/usr/bin/python3")
            .arg(Server::cleanup_helper())
            .arg("supervise")
            .arg(std::env::current_exe().unwrap())
            .args([
                "--ignored",
                "--exact",
                "owned_server_guard_handles_literal_names_and_rejects_rename_respawn_and_copy_mode",
            ])
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "owned lease supervisor failed: {output:?}"
        );
        return;
    }
    let root = PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
        .join("desk/tmp")
        .join(format!("test-k05-action-{}", std::process::id()));
    std::fs::create_dir(&root).unwrap();
    std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700)).unwrap();
    let executable = std::fs::canonicalize("/opt/homebrew/bin/tmux").unwrap();
    let socket = root.join("server");
    let session = "test-k05-s_会 #{pid},} '";
    let window = "test-k05-w:🦀 #{pid},} '";
    let create_session = session.replace('#', "##");
    let create_window = window.replace('#', "##");
    let output = Command::new("/usr/bin/python3")
        .arg(Server::cleanup_helper())
        .arg("run")
        .arg(&executable)
        .arg("-f")
        .arg("/dev/null")
        .arg("-S")
        .arg(&socket)
        .args([
            "new-session",
            "-d",
            "-P",
            "-F",
            "#{pid}",
            "-s",
            &create_session,
            "-n",
            &create_window,
            "/bin/sleep 30",
        ])
        .output()
        .unwrap();
    assert!(output.status.success(), "{output:?}");
    let pid = String::from_utf8(output.stdout)
        .unwrap()
        .trim()
        .parse()
        .unwrap();
    use std::os::unix::fs::MetadataExt;
    let metadata = std::fs::symlink_metadata(&socket).unwrap();
    let server = Server {
        root,
        executable,
        socket,
        identity: target::kernel_process(pid).unwrap(),
        socket_identity: (metadata.dev(), metadata.ino()),
    };
    let namespace = server.namespace();
    eprintln!(
        "owned native names: {}",
        server.command(&["list-panes", "-a", "-F", "#{session_name}|#{window_name}"])
    );
    let prepared =
        delivery::prepare_in(&namespace, session, window, None, "#k05 guard", "unused").unwrap();
    let pane = prepared.target().selector();
    let condition = prepared.identity_condition(&namespace).unwrap();
    assert_eq!(server.condition(&pane, &condition), "1");
    server.command(&["copy-mode", "-t", &pane]);
    assert_eq!(server.condition(&pane, &condition), "0");
    server.command(&["send-keys", "-t", &pane, "-X", "cancel"]);
    server.command(&["rename-window", "-t", &pane, "test-k05-renamed"]);
    assert_eq!(server.condition(&pane, &condition), "0");
    server.command(&["rename-window", "-t", &pane, &create_window]);
    assert_eq!(server.condition(&pane, &condition), "1");
    server.command(&["respawn-pane", "-k", "-t", &pane, "/bin/sleep 30"]);
    assert_eq!(server.condition(&pane, &condition), "0");
}
