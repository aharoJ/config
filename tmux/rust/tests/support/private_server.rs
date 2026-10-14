use crate::identity::{self, Namespace};
use std::os::unix::fs::DirBuilderExt;
use std::{path::PathBuf, process::Command};
pub fn supervised(selection: &str) -> bool {
    if std::env::var_os("KS01_RUN_CAP").is_some() {
        return false;
    }
    let mut command = Command::new("/usr/bin/python3");
    for (key, _) in std::env::vars_os() {
        if key.to_string_lossy().starts_with("ANGELSTAR_") {
            command.env_remove(key);
        }
    }
    let out = command
        .arg(identity::helper())
        .arg("supervise")
        .arg(std::env::current_exe().unwrap())
        .args(["--ignored", "--exact", selection, "--nocapture"])
        .output()
        .unwrap();
    assert!(out.status.success(), "private supervisor: {out:?}");
    println!("{}", String::from_utf8_lossy(&out.stdout));
    true
}
pub struct Server {
    pub root: PathBuf,
    pub socket: PathBuf,
}
impl Server {
    pub fn new() -> Self {
        let records = Command::new("/usr/bin/python3")
            .arg(identity::helper())
            .arg("records")
            .output()
            .unwrap();
        assert!(records.status.success());
        let root = PathBuf::from(String::from_utf8(records.stdout).unwrap().trim())
            .join(format!("k50-{}", crate::runtime::fresh_id().unwrap()));
        std::fs::DirBuilder::new()
            .mode(0o700)
            .create(&root)
            .unwrap();
        let server = Self {
            socket: root.join("server"),
            root,
        };
        println!(
            "signed fixture root before server {}",
            server.root.display()
        );
        server.command(&[
            "new-session",
            "-d",
            "-s",
            "private-k50",
            "-n",
            "hold",
            "/bin/sleep 120",
        ]);
        server.command(&["set-option", "-g", "status", "off"]);
        server
    }
    pub fn fixtures(&self, names: &[&str]) {
        let fixture = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/private-runtime-line-editor.py");
        for name in names {
            let pane = self.command(&[
                "new-window",
                "-d",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                "private-k50",
                "-n",
                name,
                "/bin/sleep 120",
            ]);
            let command = format!(
                "exec /usr/bin/python3 {} {} {} {} {}",
                crate::runtime::quote(fixture.to_str().unwrap()),
                crate::runtime::quote(self.root.join(format!("{name}.tsv")).to_str().unwrap()),
                crate::runtime::quote(self.root.join(format!("{name}.json")).to_str().unwrap()),
                crate::runtime::quote(self.root.join(format!("{name}.control")).to_str().unwrap()),
                crate::runtime::quote(identity::helper().to_str().unwrap())
            );
            self.command(&["respawn-pane", "-k", "-t", pane.trim(), &command]);
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
            while !self.root.join(format!("{name}.json")).exists() {
                assert!(std::time::Instant::now() < deadline);
                std::thread::sleep(std::time::Duration::from_millis(5));
            }
        }
    }
    pub fn command(&self, args: &[&str]) -> String {
        let out = Command::new("/usr/bin/python3")
            .arg(identity::helper())
            .args(["run", "tmux", "-S"])
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
        let out = Command::new("/usr/bin/python3")
            .arg(identity::helper())
            .args(["stop", "tmux", "-S"])
            .arg(&self.socket)
            .output()
            .unwrap();
        assert!(out.status.success(), "private cleanup: {out:?}");
    }
}
