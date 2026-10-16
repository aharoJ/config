use angelstar_runtime::model_guard::{ADVANCED, EFFORTS, MODELS};
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
fn tmux(args: &[&str]) -> String {
    let out = Command::new("/opt/homebrew/bin/tmux")
        .args(args)
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    String::from_utf8(out.stdout).unwrap()
}
fn wait(pane: &str, needle: &str) {
    let end = Instant::now() + Duration::from_secs(10);
    loop {
        if tmux(&["capture-pane", "-p", "-t", pane]).contains(needle) {
            return;
        }
        assert!(Instant::now() < end, "missing {needle}");
        std::thread::sleep(Duration::from_millis(20));
    }
}
fn call(root: &Path, args: &[&str], label: &str, expected: i32) {
    let out = Command::new("codex-model")
        .args(args)
        .stdin(Stdio::null())
        .output()
        .unwrap();
    fs::write(root.join(format!("{label}.stdout")), &out.stdout).unwrap();
    fs::write(root.join(format!("{label}.stderr")), &out.stderr).unwrap();
    let code = out.status.code().unwrap_or(-1);
    let mut f = OpenOptions::new()
        .create(true)
        .append(true)
        .open(root.join("results.tsv"))
        .unwrap();
    writeln!(
        f,
        "{label}\t{expected}\t{code}\t{}",
        if code == expected { "PASS" } else { "FAIL" }
    )
    .unwrap();
}
fn control(root: &Path, pane: &str, value: &str, needle: &str) {
    fs::write(root.join("control"), value).unwrap();
    let deadline = Instant::now() + Duration::from_secs(3);
    while fs::read_to_string(root.join("drawn")).ok().as_deref() != Some(value) {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(10));
    }
    wait(pane, needle);
}
fn controller(root: &Path, actor: &str, native: bool, wrapped: bool, documented: bool) {
    let pane = std::env::var("TMUX_PANE").unwrap();
    if documented {
        let ambient = std::env::var("TMUX").unwrap();
        let socket = ambient.rsplitn(3, ',').nth(2).unwrap();
        std::env::set_var("TMUX", format!("{socket},0,0"));
    }
    let window = tmux(&["display-message", "-p", "-t", &pane, "#{window_name}"])
        .trim()
        .to_owned();
    let path = format!(
        "{}:{}",
        root.join("bin").display(),
        std::env::var("PATH").unwrap()
    );
    std::env::set_var("PATH", path);
    fs::write(
        root.join("caller-env.txt"),
        format!(
            "TMUX={}\nTMUX_PANE={}\nPATH={}\n",
            std::env::var("TMUX").unwrap(),
            pane,
            std::env::var("PATH").unwrap()
        ),
    )
    .unwrap();
    call(root, &[], "arity", 1);
    call(
        root,
        &["config-tt", &window, "unsupported", "low"],
        "unsupported",
        1,
    );
    call(root, &["config-tt", &window], "plain-pane", 1);
    call(root, &["config-tt", "missing-p1x-seat"], "missing", 1);
    unsafe {
        libc::signal(libc::SIGTTOU, libc::SIG_IGN);
    }
    let mut command = Command::new(actor);
    if native {
        command.args([
            "--no-daemon",
            "--no-alt-screen",
            "-C",
            root.to_str().unwrap(),
            "-m",
            "gpt-5.6-terra",
            "-c",
            "model_reasoning_effort=\"max\"",
        ]);
    } else {
        command.args(["actor", root.to_str().unwrap()]);
    }
    if !wrapped {
        unsafe {
            command.pre_exec(|| {
                libc::setpgid(0, 0);
                libc::tcsetpgrp(0, libc::getpid());
                Ok(())
            });
        }
    }
    let mut child = command.spawn().unwrap();
    wait(
        &pane,
        if native {
            "GPT-5.6-Terra max"
        } else {
            "Ask Codex"
        },
    );
    std::thread::sleep(Duration::from_millis(100));
    fs::write(
        root.join("before.ansi"),
        tmux(&["capture-pane", "-p", "-e", "-t", &pane]),
    )
    .unwrap();
    call(
        root,
        &["config-tt", &window, "gpt-6.1-sol", "low"],
        "sol-low",
        0,
    );
    fs::write(
        root.join("after-sol.ansi"),
        tmux(&["capture-pane", "-p", "-e", "-t", &pane]),
    )
    .unwrap();
    if native {
        call(root, &["config-tt", &window], "defaults-terra-max", 0);
    }
    call(
        root,
        &["config-tt", &window, "gpt-6.1-sol", "ultra"],
        "sol-ultra",
        if native { 4 } else { 0 },
    );
    call(
        root,
        &["config-tt", &window],
        if native {
            "ultra-composer-refuses"
        } else {
            "defaults-terra-max"
        },
        if native { 5 } else { 0 },
    );
    tmux(&["copy-mode", "-t", &pane]);
    let before = fs::read(root.join("input.log")).unwrap_or_default();
    call(
        root,
        &["config-tt", &window, "gpt-6.1-sol", "low"],
        "copy-mode",
        2,
    );
    assert_eq!(before, fs::read(root.join("input.log")).unwrap_or_default());
    tmux(&["send-keys", "-t", &pane, "-X", "cancel"]);
    if native {
        tmux(&["send-keys", "-t", &pane, "-l", "owned draft"]);
        wait(&pane, "owned draft");
        call(
            root,
            &["config-tt", &window, "gpt-6.1-sol", "low"],
            "owned-draft",
            5,
        );
    } else {
        for (scenario, needle, expected) in [
            ("draft", "owned draft", 5),
            ("busy", "Working (", 5),
            ("settle", "Ask Codex", 0),
            ("stuck", "Ask Codex", 5),
            ("warning", "Unknown warning", 5),
            ("title", "Select Model and Effort", 5),
            ("checkout", "Where should", 5),
            ("status", "Unexpected status", 5),
            ("late-warning", "Ask Codex", 5),
        ] {
            control(root, &pane, scenario, needle);
            let before = fs::read(root.join("input.log")).unwrap_or_default();
            call(
                root,
                &["config-tt", &window, "gpt-6.1-sol", "low"],
                scenario,
                expected,
            );
            if expected != 0 {
                assert_eq!(
                    before,
                    fs::read(root.join("input.log")).unwrap_or_default(),
                    "input in {scenario}"
                );
            }
        }
        control(root, &pane, "ready", "Ask Codex");
        let exe = std::env::current_exe().unwrap();
        let out = tmux(&[
            "split-window",
            "-d",
            "-P",
            "-F",
            "#{pane_id}",
            "-t",
            &pane,
            "--",
            exe.to_str().unwrap(),
            "hold",
        ]);
        let extra = out.trim();
        call(root, &["config-tt", &window], "ambiguous-window", 1);
        tmux(&["kill-pane", "-t", extra]);
    }
    fs::write(
        root.join("after.ansi"),
        tmux(&["capture-pane", "-p", "-e", "-t", &pane]),
    )
    .unwrap();
    fs::write(root.join("done"), "done\n").unwrap();
    loop {
        if child.try_wait().unwrap().is_some() {
            break;
        }
        std::thread::sleep(Duration::from_secs(1));
    }
}
fn actor(root: &Path) {
    let mut old = unsafe { std::mem::zeroed::<libc::termios>() };
    unsafe {
        libc::tcgetattr(0, &mut old);
        let mut raw = old;
        libc::cfmakeraw(&mut raw);
        raw.c_cc[libc::VMIN] = 0;
        raw.c_cc[libc::VTIME] = 1;
        libc::tcsetattr(0, libc::TCSANOW, &raw);
    }
    let mut state = "fresh";
    let mut model = 5;
    let mut effort = "max".to_owned();
    let mut selected = 5;
    let mut command = String::new();
    let mut notice = String::new();
    let mut scenario = String::new();
    let mut started = Instant::now();
    let mut late = false;
    loop {
        let next = fs::read_to_string(root.join("control")).unwrap_or_else(|_| "ready".into());
        if next != scenario {
            scenario = next;
            state = "fresh";
            command.clear();
            notice.clear();
            started = Instant::now();
            late = false;
        }
        let elapsed = started.elapsed();
        let settling = matches!(
            scenario.as_str(),
            "stuck" | "warning" | "title" | "checkout" | "status"
        ) || (matches!(scenario.as_str(), "settle" | "late-warning")
            && elapsed < Duration::from_millis(180));
        if scenario == "late-warning" && elapsed >= Duration::from_millis(180) {
            late = true;
        }
        let mut rows = vec![
            "".to_owned(),
            "  >_ OpenAI Codex (v0.161.0)".into(),
            format!("     {}", root.display()),
            "  permissions: YOLO mode".into(),
            "".into(),
            "  Bring a question.".into(),
            "".into(),
            "  Tip: Use /title.".into(),
            "".into(),
        ];
        let mut cursor = (0, 0);
        if matches!(state, "fresh" | "slash") {
            if scenario == "warning" || late {
                rows.push("  ⚠ Unknown warning".into());
            }
            if scenario == "title" {
                rows.push("  Select Model and Effort".into());
            }
            if scenario == "checkout" {
                rows.push("  Where should the new conversation run?".into());
            }
            if scenario == "status" {
                rows.push("  Unexpected status text".into());
            }
            if !notice.is_empty() {
                rows.push(notice.clone());
                rows.push("".into());
            }
            if scenario == "busy" {
                rows.push("• Working (1s • esc to interrupt)".into());
                rows.push("".into());
            }
            if state == "slash" {
                rows.push(
                    "\x1b[1;7m› /model  choose what model and reasoning effort to use\x1b[0m"
                        .into(),
                );
                rows.push("".into());
                rows.push("› /model".into());
                cursor = (8, rows.len() - 1);
            } else {
                let draft = if scenario == "draft" {
                    "owned draft"
                } else {
                    "\x1b[2mAsk Codex to do anything\x1b[0m"
                };
                rows.push(format!("\x1b[1m›\x1b[0m {draft}"));
                cursor = (if scenario == "draft" { 13 } else { 2 }, rows.len() - 1);
            }
            rows.push("".into());
            rows.push(format!(
                "  Fast off · {} {effort} · {} · Context 0% used",
                MODELS[model].0,
                root.display()
            ));
        } else {
            let (title, choices, hint) = match state {
                "models" => (
                    "Select Model and Effort".into(),
                    MODELS,
                    "enter select · esc back",
                ),
                "efforts" => (
                    format!("Select Reasoning Level for {}", MODELS[model].0),
                    EFFORTS,
                    if selected == 4 {
                        "enter select · esc back"
                    } else {
                        "enter default · s session · esc back"
                    },
                ),
                _ => (
                    "Advanced Reasoning".into(),
                    ADVANCED,
                    "enter default · s session · esc back",
                ),
            };
            rows.push(format!("  {title}"));
            if state == "advanced" {
                rows.push("  ⚠ Consumes usage limits faster".into());
            }
            for (i, (label, description)) in choices.iter().enumerate() {
                rows.push(format!(
                    "{}{}. {label}  {description}\x1b[0m",
                    if selected == i { "\x1b[1;7m› " } else { "  " },
                    i + 1
                ));
            }
            rows.push(format!("  {hint}"));
        }
        if settling {
            cursor = (0, 0);
        }
        print!(
            "\x1b[?2004h\x1b[2J\x1b[H{}\x1b[{};{}H",
            rows.join("\r\n"),
            cursor.1 + 1,
            cursor.0 + 1
        );
        std::io::stdout().flush().unwrap();
        fs::write(root.join("drawn"), &scenario).unwrap();
        let mut bytes = [0u8; 4096];
        let count = std::io::stdin().read(&mut bytes).unwrap_or(0);
        if count == 0 {
            continue;
        }
        let bytes = &bytes[..count];
        let mut log = OpenOptions::new()
            .create(true)
            .append(true)
            .open(root.join("input.log"))
            .unwrap();
        writeln!(log, "{:02x?}", bytes).unwrap();
        let text = String::from_utf8_lossy(bytes)
            .replace("\x1b[200~", "")
            .replace("\x1b[201~", "");
        if text == "\x1b[A" {
            selected = selected.saturating_sub(1);
            continue;
        }
        if text == "\x1b[B" {
            selected += 1;
            continue;
        }
        for c in text.chars() {
            match (state, c) {
                ("slash", '\r') => {
                    state = "models";
                    selected = model;
                }
                ("models", '1'..='8') => {
                    model = c.to_digit(10).unwrap() as usize - 1;
                    state = "efforts";
                    selected = 0;
                }
                ("efforts", '5') => {
                    state = "advanced";
                    selected = 0;
                }
                ("efforts" | "advanced", 's') => {
                    effort = if state == "advanced" {
                        ["max", "ultra"][selected]
                    } else {
                        ["low", "medium", "high", "xhigh"][selected]
                    }
                    .into();
                    notice = format!(
                        "• Model changed to {} {effort} for this session only",
                        MODELS[model].0.to_lowercase()
                    );
                    state = "fresh";
                    command.clear();
                }
                ("fresh", _) => {
                    command.push(c);
                    if command == "/model" {
                        state = "slash";
                    }
                }
                _ => (),
            }
        }
    }
}
fn main() {
    let args: Vec<_> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("actor") => actor(Path::new(&args[2])),
        Some("controller") => controller(
            Path::new(&args[2]),
            &args[3],
            args.get(4).is_some_and(|s| s == "native"),
            args.get(5).is_some_and(|s| s == "wrapped"),
            args.get(6).is_some_and(|s| s == "documented"),
        ),
        _ => loop {
            std::thread::sleep(Duration::from_secs(1));
        },
    }
}
