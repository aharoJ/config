pub(super) fn fresh(now_ms: u128, deadline: u64) -> bool {
    now_ms <= u128::from(deadline) * 1000
}

pub(super) fn confirmed(answer: &str, pid: u32) -> bool {
    answer == pid.to_string()
}

pub(super) fn stopped_at_breakpoint(thread: &str, id: u64) -> bool {
    let Some(line) = thread.lines().find(|line| line.starts_with("thread #")) else {
        return false;
    };
    let Some((_, reason)) = line.rsplit_once(", stop reason = ") else {
        return false;
    };
    let Some(location) = reason.strip_prefix("breakpoint ") else {
        return false;
    };
    let Some((breakpoint, location)) = location
        .split_whitespace()
        .next()
        .and_then(|s| s.split_once('.'))
    else {
        return false;
    };
    breakpoint.parse::<u64>().ok() == Some(id) && location.parse::<u64>().is_ok_and(|n| n > 0)
}

pub(super) fn runtime_pc(text: &str, function: &str, offset: &str) -> Option<String> {
    text.lines().find_map(|line| {
        let (head, rest) = line.split_once("[0x")?;
        if !head.contains(function) || !head.ends_with(char::is_whitespace) {
            return None;
        }
        let before_offset = head.trim_end().strip_suffix(offset)?;
        if !before_offset.ends_with(char::is_whitespace) {
            return None;
        }
        let (address, _) = rest.split_once(']')?;
        if address.is_empty() || !address.bytes().all(|b| b.is_ascii_hexdigit()) {
            return None;
        }
        u64::from_str_radix(address, 16).ok()?;
        Some(format!("0x{address}"))
    })
}

#[cfg(test)]
mod tests {
    use super::super::*;
    use super::{confirmed, fresh, runtime_pc, stopped_at_breakpoint};

    struct OwnedProcess(std::process::Child);

    impl Drop for OwnedProcess {
        fn drop(&mut self) {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }

    #[test]
    fn owned_stale_pid_cannot_enter_emergency_attach() {
        let root = home()
            .join("desk/tmp/relay/port/rescue-check")
            .join(format!("stale-{}", crate::lab_tools::fresh().unwrap()));
        private_dir(&root).unwrap();
        let socket = root.join("server");
        let _listener = std::os::unix::net::UnixListener::bind(&socket).unwrap();
        let exe = std::env::current_exe().unwrap();
        let mut child = OwnedProcess(
            Command::new(&exe)
                .args(["--ignored", "--exact", "lab_tools::debugger::tests::parked"])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .unwrap(),
        );
        let pid = child.0.id();
        let start = lab::process_start(pid);
        assert!(!start.is_empty());
        let identity = socket_identity(&socket);
        let sha = digest(&exe).unwrap();
        let c = Config {
            production: false,
            action: "rescue",
            socket,
            pid,
            count: Some(1),
            root: root.clone(),
            exe: exe.clone(),
            sha: sha.clone(),
            uuid: String::new(),
            function: String::new(),
            frame: String::new(),
            offset: String::new(),
            bytes: String::new(),
            seconds: 2,
            age: 300,
        };
        let mut e = Evidence {
            root: root.clone(),
            timing: String::new(),
            gates: String::new(),
        };
        let mut proof = Proof {
            exe: &exe,
            sha: &sha,
            uuid: "unused",
            socket_id: &identity,
            start: &start,
            pc: 0,
            bound: 1,
            deadline: 0,
        };
        proof.socket_id = "replaced-socket";
        assert!(!emergency_detach(&c, &mut e, &proof));
        proof.socket_id = &identity;
        proof.start = "reused-pid";
        assert!(!emergency_detach(&c, &mut e, &proof));
        proof.start = &start;
        proof.sha = "changed-build";
        assert!(!emergency_detach(&c, &mut e, &proof));
        proof.sha = &sha;
        child.0.kill().unwrap();
        child.0.wait().unwrap();
        assert!(crate::identity::kernel_process(pid).is_none());
        assert!(!emergency_detach(&c, &mut e, &proof));
        assert!(e.timing.is_empty());
        assert!(!root.join("emergency-detach-command-file.txt").exists());
        println!(
            "stale owned PID and changed identities refused before any command; evidence={}",
            root.display()
        );
    }

    #[test]
    fn delayed_breakpoint_stop_is_confirmed_before_final_checks() {
        let mut replies = std::collections::VecDeque::from([
            ("process status", "Process 123 is running.\n"),
            ("process status", "Process 123 is running.\n"),
            ("process status", "Process 123 stopped\n"),
            (
                "thread info",
                "thread #1: tid = 0x12, stop reason = breakpoint 7.1\n",
            ),
        ]);
        await_breakpoint(Instant::now() + Duration::from_secs(1), 123, 7, |command| {
            let (expected, reply) = replies.pop_front().expect("unexpected debugger command");
            assert_eq!(command, expected);
            Ok(reply.into())
        })
        .unwrap();
        assert!(replies.is_empty());
    }

    #[test]
    fn breakpoint_wait_rejects_wrong_process_or_stop_reason() {
        for (status, thread, error) in [
            (
                "Process 124 stopped",
                "",
                "pid-mismatch-or-process-not-stopped",
            ),
            (
                "Process 123 stopped",
                "thread #1: tid = 0x12, stop reason = breakpoint 8.1",
                "breakpoint-mismatch-or-unexpected-stop-reason",
            ),
            (
                "Process 123 stopped",
                "thread #1: tid = 0x12, stop reason = signal SIGSTOP",
                "breakpoint-mismatch-or-unexpected-stop-reason",
            ),
        ] {
            let result =
                await_breakpoint(Instant::now() + Duration::from_secs(1), 123, 7, |command| {
                    Ok(if command == "process status" {
                        status
                    } else {
                        thread
                    }
                    .into())
                });
            assert_eq!(result.unwrap_err(), error);
        }
    }

    #[test]
    fn breakpoint_wait_keeps_deadline_and_command_failure() {
        assert_eq!(
            await_breakpoint(Instant::now(), 123, 7, |_| panic!("deadline was extended"))
                .unwrap_err(),
            "debugger transaction timed out"
        );
        let mut calls = 0;
        let result = await_breakpoint(Instant::now() + Duration::from_secs(1), 123, 7, |_| {
            calls += 1;
            if calls == 1 {
                Ok("Process 123 is running.".into())
            } else {
                Err("debugger transaction interrupted".into())
            }
        });
        assert_eq!(result.unwrap_err(), "debugger transaction interrupted");
        assert_eq!(calls, 2);
    }

    #[test]
    fn breakpoint_reason_cannot_come_from_a_thread_name() {
        assert!(stopped_at_breakpoint(
            "thread #1: tid = 0x12, stop reason = breakpoint 1.1",
            1
        ));
        for thread in [
            "thread #1: tid = 0x12, name = 'stop reason = breakpoint 1.1', stop reason = signal SIGSTOP",
            "thread #1: tid = 0x12, stop reason = breakpoint 10.1",
            "thread #1: tid = 0x12, stop reason = signal SIGSTOP",
            "thread #1: tid = 0x12, stop reason = breakpoint 1.invalid",
        ] {
            assert!(!stopped_at_breakpoint(thread, 1), "{thread}");
        }
    }

    #[test]
    fn typed_pid_requires_the_exact_line() {
        assert!(confirmed("123", 123));
        for answer in [" 123", "123 ", "123\r", "\t123", "0123", "+123", ""] {
            assert!(!confirmed(answer, 123), "{answer:?}");
        }
    }

    #[test]
    fn final_deadline_has_no_extra_fractional_second() {
        assert!(fresh(109_999, 110));
        assert!(fresh(110_000, 110));
        assert!(!fresh(110_001, 110));
        assert!(!fresh(110_999, 110));
        assert!(!fresh(111_000, 110));
    }

    #[test]
    fn sampled_offset_must_be_a_complete_token() {
        let function = "window_copy_cmd_cursor_down";
        let sample = format!("  {function} (in tmux) + 36 [0x100010000]");
        assert_eq!(
            runtime_pc(&sample, function, "+ 36"),
            Some("0x100010000".into())
        );
        for changed in [
            sample.replace("+ 36", "+ 360"),
            sample.replace("+ 36", "+ 36extra"),
            sample.replace("[0x100010000]", "[0xnothex]"),
        ] {
            assert_eq!(runtime_pc(&changed, function, "+ 36"), None, "{changed}");
        }
    }
}
