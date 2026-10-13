#![cfg(all(target_os = "macos", any()))]

use angelstar_runtime::target::captured_source;
use std::process::Command;

#[test]
#[ignore = "owned test-k3 windows and private archive only; no app input"]
#[cfg(any())]
fn owned_kernel_source_ignores_a_spoofed_ambient_pane() {
    if let Ok(expected) = std::env::var("ANGELSTAR_KERNEL_SOURCE_WINDOW") {
        let (source, ancestry) = captured_source().unwrap().unwrap();
        assert_eq!(source.window.name, expected);
        assert_eq!(ancestry[0].pid, std::process::id());
        assert!(ancestry.iter().any(|row| row.pid == source.pane.pid));
        assert_ne!(source.selector(), std::env::var("TMUX_PANE").unwrap());
        let destination = std::env::var("ANGELSTAR_DELIVERY_TARGET_WINDOW").unwrap();
        let text = "#k04 full payload\nsecond line 会🦀 #extra";
        let executable = std::fs::canonicalize("/opt/homebrew/bin/tmux").unwrap();
        let socket = std::path::Path::new("/private/tmp/tmux-501/default");
        let output = Command::new(&executable)
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
        let namespace = angelstar_runtime::target::Namespace::connect(
            &executable,
            socket,
            angelstar_runtime::target::kernel_process(pid).unwrap(),
        )
        .unwrap();
        namespace.verify_peer_image().unwrap();
        let bound = angelstar_runtime::delivery::prepare_in(
            &namespace,
            "config(tmux-to-rust)",
            &destination,
            None,
            text,
            "unused",
        )
        .unwrap();
        assert_eq!(bound.source(), Some(&source));
        bound.revalidate_in(&namespace).unwrap();
        assert!(bound
            .identity_condition(&namespace)
            .unwrap()
            .contains("#{pane_pid}"));
        let prepared = angelstar_runtime::delivery::prepare(
            "config(tmux-to-rust)",
            &destination,
            None,
            text,
            "unused",
        )
        .unwrap();
        assert_eq!(prepared.source(), Some(&source));
        assert_eq!(prepared.target().window.name, destination);
        assert_eq!(
            prepared.target().selector(),
            std::env::var("TMUX_PANE").unwrap()
        );
        assert_ne!(prepared.target().pane.id, source.pane.id);
        assert_eq!(prepared.envelope().message, text);
        assert_eq!(prepared.envelope().codes, ["k04", "extra"]);
        assert_eq!(
            prepared.envelope().label,
            format!(
                "{} ({}:{})",
                source.window.name, source.session_name, source.window.name
            )
        );
        let store = std::path::PathBuf::from(std::env::var("ANGELSTAR_DELIVERY_STORE").unwrap());
        let (published, record) = angelstar_runtime::delivery::prepare_and_publish(
            "config(tmux-to-rust)",
            &destination,
            None,
            text,
            &store,
        )
        .unwrap();
        assert_eq!(published.source(), Some(&source));
        let full = Command::new("jq")
            .args(["-j", ".full_message"])
            .arg(&record.path)
            .output()
            .unwrap();
        assert!(full.status.success());
        assert_eq!(full.stdout, published.envelope().render().as_bytes());
        let kernel = Command::new("jq").args(["-e", "--argjson", "pid", &std::process::id().to_string(), ".source_generations[0].pid == $pid and .state == \"archived-no-input\" and .source != null"]).arg(&record.path).status().unwrap();
        assert!(kernel.success());
        assert!(record.pointer.contains("#k04 #extra -- full:"));
        eprintln!(
            "kernel-source-proof {} {}",
            source.window.name,
            source.selector()
        );
        return;
    }
    fn tmux(args: &[&str]) -> String {
        let output = Command::new("tmux").args(args).output().unwrap();
        assert!(output.status.success(), "{args:?}: {output:?}");
        String::from_utf8(output.stdout).unwrap().trim().to_owned()
    }
    let prefix = format!("test-k3-kernel-{}", std::process::id());
    let decoy_name = format!("{prefix}-decoy");
    let source_name = format!("{prefix}-source");
    let store = std::path::PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
        .join("desk/tmp")
        .join(format!(
            "{prefix}-publication-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
    std::fs::create_dir(&store).unwrap();
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(&store, std::fs::Permissions::from_mode(0o700)).unwrap();
    let mut owned = Vec::new();
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let created = tmux(&[
            "new-window",
            "-d",
            "-P",
            "-F",
            "#{window_id}:#{pane_id}",
            "-t",
            "=config(tmux-to-rust):",
            "-n",
            &decoy_name,
            "/bin/sleep 30",
        ]);
        let (decoy, pane) = created.split_once(':').unwrap();
        owned.push((decoy.to_owned(), decoy_name.clone()));
        let exe = std::env::current_exe().unwrap();
        let exe = exe.to_str().unwrap();
        assert!(!exe.contains('\''));
        let startup = format!("/bin/sh -c \"/bin/sleep 2; exec /usr/bin/env ANGELSTAR_KERNEL_SOURCE_WINDOW={source_name} ANGELSTAR_DELIVERY_TARGET_WINDOW={decoy_name} ANGELSTAR_DELIVERY_STORE={} TMUX_PANE={pane} '{exe}' --ignored --exact owned_kernel_source_ignores_a_spoofed_ambient_pane --nocapture\"", store.display());
        let window = tmux(&[
            "new-window",
            "-d",
            "-P",
            "-F",
            "#{window_id}",
            "-t",
            "=config(tmux-to-rust):",
            "-n",
            &source_name,
            &startup,
        ]);
        owned.push((window.clone(), source_name.clone()));
        assert_eq!(
            tmux(&["display-message", "-p", "-t", &window, "#{window_name}"]),
            source_name
        );
        tmux(&[
            "set-window-option",
            "-t",
            &window,
            "automatic-rename",
            "off",
        ]);
        tmux(&["set-window-option", "-t", &window, "remain-on-exit", "on"]);
        let mut exited = false;
        for _ in 0..80 {
            if tmux(&["display-message", "-p", "-t", &window, "#{pane_dead}"]) == "1" {
                exited = true;
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        assert!(exited, "owned kernel proof did not exit");
        let capture = tmux(&["capture-pane", "-p", "-t", &window]);
        assert_eq!(
            tmux(&[
                "display-message",
                "-p",
                "-t",
                &window,
                "#{pane_dead_status}"
            ]),
            "0",
            "{capture}"
        );
        assert!(
            capture.contains(&format!("kernel-source-proof {source_name} %")),
            "{capture}"
        );
    }));
    let mut cleanup_error = None;
    for (window, expected) in owned {
        let cleanup = std::panic::catch_unwind(|| {
            assert_eq!(
                tmux(&["display-message", "-p", "-t", &window, "#{window_name}"]),
                expected
            );
            tmux(&["kill-window", "-t", &window]);
        });
        if cleanup_error.is_none() {
            cleanup_error = cleanup.err();
        }
    }
    let store_cleanup = std::panic::catch_unwind(|| {
        for entry in std::fs::read_dir(&store).unwrap() {
            let entry = entry.unwrap();
            let name = entry.file_name().into_string().unwrap();
            assert!(entry.file_type().unwrap().is_file());
            assert!(name
                .strip_suffix(".json")
                .is_some_and(|id| id.len() == 32 && id.bytes().all(|b| b.is_ascii_hexdigit())));
            std::fs::remove_file(entry.path()).unwrap();
        }
        std::fs::remove_dir(&store).unwrap();
    });
    if cleanup_error.is_none() {
        cleanup_error = store_cleanup.err();
    }
    if let Err(error) = result {
        std::panic::resume_unwind(error);
    }
    if let Some(error) = cleanup_error {
        std::panic::resume_unwind(error);
    }
}
