use super::*;

#[test]
fn owner_requires_exact_process_name_and_decimal_pid() {
    assert_eq!(
        lsof_pid("COMMAND PID USER\ntmux x owner\ntmux 123 owner\ntmux 456 owner\n"),
        "123"
    );
    for text in ["", "tmux", "tmux: 123", "other 123", "tmux +123", "tmux -1"] {
        assert_eq!(lsof_pid(text), "", "{text}");
    }
    assert!(decimal("123"));
    for text in ["", "123 ", " 123", "+123", "1\n2"] {
        assert!(!decimal(text));
    }
}

#[test]
fn unavailable_probe_and_binary_output_preserve_evidence_shape() {
    let root = home()
        .join("desk/tmp/relay/lead-plan/release/freeze/private")
        .join(format!("unit-{}", fresh().unwrap()));
    private_dir(&root).unwrap();
    let mut capture = Capture {
        root: root.clone(),
        timing: "label\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus\n".into(),
    };
    capture
        .unavailable("server-ps", "server PID unavailable from lsof")
        .unwrap();
    assert!(!root.join("server-ps.stderr.txt").exists());
    assert_eq!(
        fs::read_to_string(root.join("server-ps.stdout.txt")).unwrap(),
        "server PID unavailable from lsof\n"
    );
    assert_eq!(
        fs::read_to_string(root.join("server-ps.status.txt")).unwrap(),
        "127\n"
    );
    assert_eq!(
        capture
            .record(
                "sessions",
                epoch_ms(),
                Output {
                    code: 124,
                    out: vec![0, 255],
                    err: b"timed out\n".to_vec()
                }
            )
            .unwrap(),
        124
    );
    assert_eq!(
        fs::read(root.join("sessions.stdout.txt")).unwrap(),
        [0, 255]
    );
    assert_eq!(
        fs::read(root.join("sessions.stderr.txt")).unwrap(),
        b"timed out\n"
    );
    let timing = fs::read_to_string(root.join("timing.tsv")).unwrap();
    let rows: Vec<Vec<&str>> = timing
        .lines()
        .skip(1)
        .map(|line| line.split('\t').collect())
        .collect();
    assert_eq!(rows.len(), 2);
    assert!(rows.iter().all(|row| row.len() == 5));
    assert_eq!(rows[0][1], rows[0][2]);
    assert_eq!(&rows[0][3..], ["0", "127"]);
    assert_eq!(rows[1][4], "124");
    assert_eq!(
        fs::metadata(&root).unwrap().permissions().mode() & 0o777,
        0o700
    );
    for file in fs::read_dir(&root).unwrap() {
        assert_eq!(
            file.unwrap().metadata().unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}

#[test]
#[ignore]
fn owned_unresponsive_socket_records_timeout_status() {
    let root = home()
        .join("desk/tmp/relay/lead-plan/release/freeze/private")
        .join(format!("killed-query-{}", fresh().unwrap()));
    private_dir(&root).unwrap();
    let socket = root.join("server");
    let _listener = std::os::unix::net::UnixListener::bind(&socket).unwrap();
    let mut capture = Capture {
        root: root.clone(),
        timing: "label\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus\n".into(),
    };
    let start = Instant::now();
    assert!(capture
        .request(&socket, "sessions", &["list-sessions"])
        .unwrap_err()
        .contains("capture stopped"));
    assert_eq!(
        fs::read_to_string(root.join("sessions.status.txt")).unwrap(),
        "124\n"
    );
    assert!(start.elapsed() < Duration::from_secs(4));
    println!("owned unresponsive socket evidence: {}", root.display());
}

#[test]
#[ignore]
fn timeout_child() {
    unsafe {
        libc::signal(libc::SIGTERM, libc::SIG_IGN);
    }
    loop {
        std::thread::park_timeout(Duration::from_secs(60));
    }
}

#[test]
#[ignore]
fn owned_term_resistant_child_records_kill_status() {
    let output = bounded_status(
        Command::new(std::env::current_exe().unwrap()).args([
            "--ignored",
            "--exact",
            "lab_tools::freeze::tests::timeout_child",
            "--nocapture",
        ]),
        1,
        true,
    )
    .unwrap();
    assert_eq!(output.code, 137);
}
