use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs;
use std::os::unix::fs::{symlink, DirBuilderExt, MetadataExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

fn hash(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
fn reference(path: &Path) -> Value {
    json!({"path":path,"sha256":hash(&fs::read(path).unwrap())})
}
fn put(path: &Path, value: &Value) -> Value {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, serde_json::to_vec(value).unwrap()).unwrap();
    reference(path)
}
fn read(reference: &Value) -> Value {
    serde_json::from_slice(&fs::read(reference["path"].as_str().unwrap()).unwrap()).unwrap()
}
fn timestamp() -> String {
    chrono::DateTime::<chrono::Utc>::from(SystemTime::now())
        .to_rfc3339_opts(chrono::SecondsFormat::Secs, false)
}

struct Lane {
    root: PathBuf,
    home: PathBuf,
    bin: PathBuf,
    source: PathBuf,
    real_home: PathBuf,
    rows: Vec<Value>,
    seats: Vec<PathBuf>,
    path: String,
}
impl Lane {
    fn new() -> Self {
        let real_home = PathBuf::from(std::env::var_os("HOME").unwrap());
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = real_home
            .join("desk/tmp/relay/port/panel-evidence/corrected")
            .join(format!("plain-{nonce}"));
        fs::create_dir_all(&root).unwrap();
        let tools = root.join("stage/tmux/tools");
        fs::create_dir_all(&tools).unwrap();
        let source = tools.join("angelstar-runtime");
        fs::copy(env!("CARGO_BIN_EXE_angelstar-runtime"), &source).unwrap();
        let bin = root.join("bin");
        fs::create_dir(&bin).unwrap();
        for name in ["panel-seat-trust", "panel-dispatch"] {
            symlink(&source, tools.join(name)).unwrap();
            symlink(&source, bin.join(name)).unwrap();
        }
        let home = root.join("home");
        fs::create_dir(&home).unwrap();
        symlink(root.join("stage"), home.join(".config")).unwrap();
        fs::write(home.join(".claude.json"), "{\"untouched\":42}").unwrap();
        fs::create_dir_all(home.join(".gemini/antigravity-cli")).unwrap();
        fs::write(home.join(".gemini/antigravity-cli/settings.json"), "{}").unwrap();
        fs::create_dir_all(home.join("desk/.secret/deepseek")).unwrap();
        fs::write(
            home.join("desk/.secret/deepseek/api-key"),
            "fixture-01234567890123456789",
        )
        .unwrap();
        Self {
            root,
            home,
            bin,
            source,
            real_home,
            rows: Vec::new(),
            seats: Vec::new(),
            path: std::env::var("PATH").unwrap_or_default(),
        }
    }
    fn call(&mut self, surface: &str, args: &[String], expected: i32) -> Option<Value> {
        let started = Instant::now();
        let output = Command::new(surface)
            .args(args)
            .current_dir(&self.root)
            .env("HOME", &self.home)
            .env("PATH", format!("{}:{}", self.bin.display(), self.path))
            .output()
            .unwrap();
        self.rows.push(json!({"surface":surface,"argv":args,"expected_exit":expected,"actual_exit":output.status.code(),"stdout":String::from_utf8_lossy(&output.stdout),"stderr":String::from_utf8_lossy(&output.stderr),"elapsed_ms":started.elapsed().as_millis()}));
        fs::write(self.root.join("parity.json"),serde_json::to_vec_pretty(&json!({"candidate":self.source,"candidate_sha256":hash(&fs::read(&self.source).unwrap()),"home":self.home,"caller_env":std::env::vars().filter(|(key,_)|key=="TMUX" || key=="TMUX_PANE" || key.starts_with("CC_MSG_") || key.starts_with("CODEX_SEND_") || key.starts_with("AGY_SEND_")).collect::<std::collections::BTreeMap<_,_>>(),"rows":self.rows})).unwrap()).unwrap();
        assert_eq!(
            output.status.code(),
            Some(expected),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        if output.status.success() {
            serde_json::from_slice(&output.stdout).ok()
        } else {
            None
        }
    }
    fn dispatch(&mut self, phase: &str, values: &[(&str, String)], expected: i32) -> Option<Value> {
        let mut args = vec![phase.to_owned()];
        for (key, value) in values {
            args.extend([format!("--{key}"), value.clone()]);
        }
        self.call("panel-dispatch", &args, expected)
    }
    fn proof_args<'a>(reference: &Value, key: &'a str) -> Vec<(&'a str, String)> {
        vec![
            (key, reference["path"].as_str().unwrap().into()),
            ("sha256", reference["sha256"].as_str().unwrap().into()),
        ]
    }
    fn seat(&mut self, label: &str) -> PathBuf {
        let name = format!(
            "review-protocol-config-audit-r1-agentic-p3x-{}-{label}-cli",
            self.root.file_name().unwrap().to_string_lossy()
        );
        let folder = Path::new("/private/tmp").join(name);
        fs::DirBuilder::new().mode(0o700).create(&folder).unwrap();
        self.seats.push(folder.clone());
        folder
    }
    fn request(&self, round: u64, deadline: u64) -> Value {
        let base = self.root.join(format!("round-{round}"));
        let project = base.join("project");
        let identity = json!({"topic":"config-dispatch-fixture","cycle_type":"implementation","cycle":"owned-native-control","round":round});
        let intake = project.join(format!(
            "reviews/config-dispatch-fixture/intakes/audit-r{round}.md"
        ));
        fs::create_dir_all(intake.parent().unwrap()).unwrap();
        fs::write(&intake, "Owned input: alpha beta.\n").unwrap();
        let canonical = reference(&intake);
        let manifest = put(
            &intake.with_extension("manifest.json"),
            &json!({"status":"PASS","output":canonical["path"],"sha256":format!("sha256:{}",canonical["sha256"].as_str().unwrap()),"bytes":fs::metadata(&intake).unwrap().len()}),
        );
        let delivered = base.join("delivered.md");
        fs::copy(&intake, &delivered).unwrap();
        let delivered = reference(&delivered);
        let prompt = base.join("prompt.md");
        fs::write(&prompt,"Operator-authorized native dispatcher pilot. Preliminary prompt reads do not disqualify this pilot. Now read PROMPT.md and intake.md fully with two exec calls using these exact bodies: const r = await tools.exec_command({cmd:\"cat PROMPT.md\"}); text(r); and const r = await tools.exec_command({cmd:\"cat intake.md\"}); text(r); These authorized cat reads are not test execution; after these full-result reads, do not repeat them. No reads outside this seat, no test execution and no peer messages. Reply exactly with two lines:\nGrounded check: owned input contains alpha beta; no tests executed.\nVerdict: PASS\n").unwrap();
        let prompt = reference(&prompt);
        let projection = put(
            &base.join("projection.json"),
            &json!({"context":identity,"canonical_input":canonical,"delivered_input":delivered,"prompt":prompt,"exclusion_pass":true,"fidelity_pass":true,"independent":true,"unknown_fields":[],"test_fixture_only":true}),
        );
        let adapter = json!({"id":"config-panel-dispatch","version":"1","source_sha256":hash(&fs::read(&self.source).unwrap())});
        let launcher = put(
            &base.join("launcher.json"),
            &json!({"context":identity,"adapter":adapter,"authorized":true,"tai_sha256":hash(&fs::read(&self.source).unwrap()),"trust_sha256":hash(&fs::read(&self.source).unwrap()),"test_fixture_only":true}),
        );
        let policy = put(
            &base.join("policy.json"),
            &json!({"context":identity,"authorized":true,"authorized_at":timestamp(),"max_redispatches":0,"technical_causes":[],"exhaustion":"non-response","test_fixture_only":true}),
        );
        let roster = json!([{"seat_id":"a","attempt_id":"one","transport":"astra","window":format!("p3x-test-seat-{}-{round}",std::process::id()),"model":"gpt-6-sol","effort":"low","accepted_limitations":[]}]);
        let first = put(
            &base.join("first.json"),
            &json!({"context":identity,"project_root":project,"roster":roster,"authorized":true,"independent":true,"prior_attempts":[],"test_fixture_only":true}),
        );
        let mut request = json!({"version":"1","project_root":project,"protocol_root":fs::canonicalize(self.real_home.join(".skills/review-protocol")).unwrap(),"session":"config-tt","packet":{"canonical_input":canonical,"manifest":manifest,"delivered_input":delivered,"prompt":prompt,"projection_review":projection},"roster":roster,"redispatch_policy_ref":policy,"launcher_ref":launcher,"first_attempt_ref":first,"deadline_seconds":deadline,"authorized":true,"authorized_at":timestamp()});
        request
            .as_object_mut()
            .unwrap()
            .extend(identity.as_object().unwrap().clone());
        put(&base.join("request.json"), &request)
    }
    fn prepare(&mut self, request: &Value, label: &str) -> Value {
        let mut args = Self::proof_args(request, "request");
        args.push((
            "batch",
            self.root.join(label).to_string_lossy().into_owned(),
        ));
        let reference = self.dispatch("prepare", &args, 0).unwrap();
        for seat in read(&reference)["seats"].as_array().unwrap() {
            self.seats
                .push(PathBuf::from(seat["directory"].as_str().unwrap()));
        }
        reference
    }
}
impl Drop for Lane {
    fn drop(&mut self) {
        for folder in &self.seats {
            if let Ok(info) = fs::symlink_metadata(folder) {
                let temp = Path::new("/private/tmp").join(format!("panel-{}", info.ino()));
                if fs::read_to_string(temp.join(".panel-seat"))
                    .is_ok_and(|s| s == folder.to_string_lossy().to_string() + "\n")
                {
                    let _ = fs::remove_dir_all(temp);
                }
                let _ = fs::remove_dir_all(folder);
            }
        }
    }
}

fn assert_plain_pane() {
    let pane = std::env::var("TMUX_PANE").unwrap();
    let output = Command::new("/opt/homebrew/bin/tmux")
        .args([
            "display-message",
            "-p",
            "-t",
            &pane,
            "#{session_name}\t#{window_name}\t#{pane_id}",
        ])
        .output()
        .unwrap();
    assert!(output.status.success());
    let identity = String::from_utf8(output.stdout).unwrap();
    let fields: Vec<_> = identity.trim().split('\t').collect();
    assert_eq!(fields[0], "config-tt");
    assert!(fields[1].starts_with("p3x-test-"));
    assert_eq!(fields[2], pane);
}

#[test]
#[ignore = "owned plain-pane candidate check; creates and removes only its own seats"]
fn native_plain_pane_parity() {
    assert_plain_pane();
    let mut lane = Lane::new();
    let seat = lane.seat("trust");
    let physical = seat.to_string_lossy().into_owned();
    let logical = format!("/tmp{}", &physical["/private/tmp".len()..]);
    for kind in ["claude", "deepseek", "codex", "agy"] {
        lane.call("panel-seat-trust", &[kind.into(), physical.clone()], 0);
        let config = lane.home.join(match kind {
            "claude" | "deepseek" => ".claude.json",
            "agy" => ".gemini/antigravity-cli/settings.json",
            _ => ".local/state/codex-panel-home/config.toml",
        });
        let bytes = fs::read(&config).unwrap();
        let inode = fs::metadata(&config).unwrap().ino();
        lane.call("panel-seat-trust", &[kind.into(), logical.clone()], 0);
        assert_eq!(fs::read(&config).unwrap(), bytes);
        assert_eq!(fs::metadata(&config).unwrap().ino(), inode);
        assert!(seat.join("scratch").is_dir());
        if kind == "claude" || kind == "deepseek" {
            let settings: Value =
                serde_json::from_slice(&fs::read(seat.join("panel-settings.json")).unwrap())
                    .unwrap();
            assert_eq!(settings["sandbox"]["enabled"], true);
            assert_eq!(settings["sandbox"]["allowUnsandboxedCommands"], false);
            assert!(settings["permissions"]["allow"]
                .as_array()
                .unwrap()
                .contains(&json!("Bash")));
            assert!(seat.join("panel-env.sh").is_file());
        }
    }
    let marker = Path::new("/private/tmp")
        .join(format!("panel-{}", fs::metadata(&seat).unwrap().ino()))
        .join(".panel-seat");
    fs::write(&marker, "another seat\n").unwrap();
    lane.call("panel-seat-trust", &["claude".into(), physical.clone()], 1);
    fs::write(&marker, physical.clone() + "\n").unwrap();
    fs::remove_dir(seat.join("scratch")).unwrap();
    symlink(&lane.root, seat.join("scratch")).unwrap();
    lane.call("panel-seat-trust", &["codex".into(), physical.clone()], 1);
    fs::remove_file(seat.join("scratch")).unwrap();
    for (args, exit) in [
        (vec![], 2),
        (vec!["--help".into()], 2),
        (vec!["other".into(), physical.clone()], 2),
        (vec!["claude".into()], 2),
        (vec!["claude".into(), "relative".into()], 1),
    ] {
        lane.call("panel-seat-trust", &args, exit);
    }
    for phase in [
        "prepare", "launch", "own", "wait", "collect", "retain", "verify", "cleanup",
    ] {
        lane.call("panel-dispatch", &[phase.into()], 2);
    }
    lane.call("panel-dispatch", &["--help".into()], 0);
    let request_ref = lane.request(1, 1);
    let prep_ref = lane.prepare(&request_ref, "batch");
    let prepared = read(&prep_ref);
    let mut seat = prepared["seats"][0].clone();
    seat["delivery"] = json!({"native_start":"codex: #panel-start Read PROMPT.md in this folder and follow it exactly."});
    seat["pane"] = json!({"test_owned_fixture":true});
    seat["launched_at"] = json!(timestamp());
    let launch = put(
        &lane.root.join("launched.json"),
        &json!({"phase":"launched","context":prepared["context"],"request_ref":request_ref,"prepared_ref":prep_ref,"adapter":prepared["adapter"],"batch":prepared["batch"],"seats":[seat]}),
    );
    let folder = Path::new(seat["directory"].as_str().unwrap());
    let mut rows = vec![
        json!({"timestamp":timestamp(),"type":"session_meta","payload":{"id":"owned-control-session","cwd":folder}}),
        json!({"type":"turn_context","payload":{"model":"gpt-6-sol","effort":"low","cwd":folder}}),
        json!({"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":seat["delivery"]["native_start"]}]}}),
    ];
    for (id, name) in [("p", "PROMPT.md"), ("i", "intake.md")] {
        rows.push(json!({"type":"response_item","payload":{"type":"function_call","call_id":id,"name":"exec_command","arguments":json!({"cmd":format!("cat {name}")}).to_string()}}));
        rows.push(json!({"type":"response_item","payload":{"type":"function_call_output","call_id":id,"output":format!("Process exited with code 0\n{}",fs::read_to_string(folder.join(name)).unwrap())}}));
    }
    let final_text = "Grounded reasoning.\nVerdict: PASS\n";
    rows.push(json!({"type":"response_item","payload":{"type":"message","role":"assistant","channel":"final","content":[{"type":"output_text","text":final_text}]}}));
    let native = lane.root.join("observed-native.jsonl");
    fs::write(
        &native,
        rows.iter()
            .map(Value::to_string)
            .collect::<Vec<_>>()
            .join("\n")
            + "\n",
    )
    .unwrap();
    let native_ref = reference(&native);
    let locations = put(
        &lane.root.join("locations.json"),
        &json!({"context":prepared["context"],"launch_ref":launch,"seats":[{"seat_id":"a","attempt_id":"one","native_path":native}]}),
    );
    let mut args = Lane::proof_args(&launch, "launched");
    args.extend([
        ("locations", locations["path"].as_str().unwrap().into()),
        (
            "locations-sha256",
            locations["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root.join("wait.json").to_string_lossy().into_owned(),
        ),
    ]);
    let observed = lane.dispatch("wait", &args, 0).unwrap();
    assert_eq!(read(&observed)["seats"][0]["candidate"], true);
    let missing = put(
        &lane.root.join("missing-locations.json"),
        &json!({"context":prepared["context"],"launch_ref":launch,"seats":[{"seat_id":"a","attempt_id":"one","native_path":lane.root.join("absent-native.jsonl")}]}),
    );
    let mut args = Lane::proof_args(&launch, "launched");
    args.extend([
        ("locations", missing["path"].as_str().unwrap().into()),
        (
            "locations-sha256",
            missing["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("exhausted.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let exhausted = lane.dispatch("wait", &args, 0).unwrap();
    assert_eq!(read(&exhausted)["seats"][0]["exhausted"], true);
    assert_eq!(read(&exhausted)["automatic_redispatches"], 0);
    let boundary = put(
        &lane.root.join("boundary.json"),
        &json!({"context":prepared["context"],"seat_id":"a","attempt_id":"one","session_id":"owned-control-session","native_ref":native_ref,"descendants":[],"launch_ref":launch,"pane":seat["pane"],"session_binding_verified":true,"independent":true,"isolation_pass":true,"external_input_pass":true,"final_sha256":hash(final_text.as_bytes()),"raw_verdict":"PASS","test_fixture_only":true}),
    );
    let index = put(
        &lane.root.join("native-index.json"),
        &json!({"context":prepared["context"],"launch_ref":launch,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":native_ref,"format":"codex-jsonl","descendants":[],"boundary_review_ref":boundary,"account_ref":null}]}),
    );
    let mut args = Lane::proof_args(&launch, "launched");
    args.extend([
        ("native-index", index["path"].as_str().unwrap().into()),
        ("native-sha256", index["sha256"].as_str().unwrap().into()),
    ]);
    let collected = lane.dispatch("collect", &args, 0).unwrap();
    assert_eq!(read(&collected)["seats"][0]["raw_verdict"], "PASS");
    let retained_index = put(
        &lane.root.join("retain-index.json"),
        &json!({"context":prepared["context"],"launch_ref":launch,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":native_ref,"cause":"control evidence is unadmitted"}]}),
    );
    let mut args = Lane::proof_args(&launch, "launched");
    args.extend([
        (
            "native-index",
            retained_index["path"].as_str().unwrap().into(),
        ),
        (
            "native-sha256",
            retained_index["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("retained.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let retained = lane.dispatch("retain", &args, 0).unwrap();
    assert_eq!(read(&retained)["seats"][0]["pass_floor_eligible"], false);
    let recovery_ref = lane.prepare(&request_ref, "recovery-batch");
    let recovery = read(&recovery_ref);
    let recovery_seat = &recovery["seats"][0];
    lane.call(
        "panel-seat-trust",
        &[
            "codex".into(),
            recovery_seat["directory"].as_str().unwrap().into(),
        ],
        0,
    );
    let pending = put(
        &lane.root.join("pending.json"),
        &json!({"phase":"trust-pending","context":recovery["context"],"request_ref":request_ref,"prepared_ref":recovery_ref,"adapter":recovery["adapter"],"batch":recovery["batch"],"seats":recovery["seats"]}),
    );
    let mut recovery_seat = recovery_seat.clone();
    recovery_seat["pane"] = Value::Null;
    recovery_seat["pane_process"] = Value::Null;
    let owned = put(
        &lane.root.join("owned.json"),
        &json!({"phase":"prestart-recovery","context":recovery["context"],"request_ref":request_ref,"prepared_ref":recovery_ref,"adapter":recovery["adapter"],"batch":recovery["batch"],"seats":[recovery_seat],"trust_pending_ref":pending}),
    );
    let index = put(
        &lane.root.join("recovery-index.json"),
        &json!({"context":recovery["context"],"launch_ref":owned,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":null,"non_observation":true,"cause":"owned no-pane recovery control"}]}),
    );
    let mut args = Lane::proof_args(&owned, "launched");
    args.extend([
        ("native-index", index["path"].as_str().unwrap().into()),
        ("native-sha256", index["sha256"].as_str().unwrap().into()),
        (
            "output",
            lane.root
                .join("recovery-retained.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let retained = lane.dispatch("retain", &args, 0).unwrap();
    let mut args = Lane::proof_args(&owned, "launched");
    args.extend([
        ("collected", retained["path"].as_str().unwrap().into()),
        (
            "collected-sha256",
            retained["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("cleanup.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let cleaned = lane.dispatch("cleanup", &args, 0).unwrap();
    assert_eq!(read(&cleaned)["phase"], "cleaned");
    assert_eq!(read(&cleaned)["seats"][0]["pane_observed"], false);
    println!(
        "P3X_PLAIN_PASS {} rows; {}",
        lane.rows.len(),
        lane.root.display()
    );
}

#[test]
#[ignore = "owned interactive launcher failure check in the private plain-pane window"]
fn native_owned_launch_recovery() {
    assert_plain_pane();
    let mut lane = Lane::new();
    lane.path = "/usr/bin:/bin".into();
    let request = lane.request(2, 1);
    let prep_ref = lane.prepare(&request, "launch-batch");
    let prepared = read(&prep_ref);
    let args = Lane::proof_args(&prep_ref, "prepared");
    lane.dispatch("launch", &args, 1);
    let batch = Path::new(prepared["batch"].as_str().unwrap());
    let cleanup: Value =
        serde_json::from_slice(&fs::read(batch.join("prestart-failure-cleanup.json")).unwrap())
            .unwrap();
    assert_eq!(cleanup["phase"], "cleaned");
    assert!(!batch.join("starts-entered.json").exists());
    assert!(!batch.join("a-spawn.json").exists());
    assert!(batch.join("trust-pending-1.json").is_file());
    let output = Command::new("/opt/homebrew/bin/tmux")
        .args(["list-windows", "-t", "=config-tt", "-F", "#{window_name}"])
        .output()
        .unwrap();
    assert!(!String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .any(|window| window == read(&request)["roster"][0]["window"].as_str().unwrap()));
    println!("P3X_RECOVERY_PASS {}", lane.root.display());
}

struct OwnedWindow {
    pane: String,
    directory: PathBuf,
}
impl Drop for OwnedWindow {
    fn drop(&mut self) {
        let output = Command::new("/opt/homebrew/bin/tmux")
            .args([
                "display-message",
                "-p",
                "-t",
                &self.pane,
                "#{pane_id}\t#{pane_current_path}",
            ])
            .output()
            .unwrap();
        if output.status.success() {
            let identity = String::from_utf8(output.stdout).unwrap();
            if identity.trim() == format!("{}\t{}", self.pane, self.directory.display()) {
                let _ = Command::new("/opt/homebrew/bin/tmux")
                    .args(["kill-window", "-t", &self.pane])
                    .status();
            }
        }
    }
}

#[test]
#[ignore = "owned plain-pane process custody and preservation-before-cleanup check"]
fn native_owned_custody_cleanup() {
    assert_plain_pane();
    let mut lane = Lane::new();
    let request_ref = lane.request(3, 1);
    let request = read(&request_ref);
    let prep_ref = lane.prepare(&request_ref, "custody-batch");
    let prepared = read(&prep_ref);
    let seat = &prepared["seats"][0];
    let directory = PathBuf::from(seat["directory"].as_str().unwrap());
    lane.call(
        "panel-seat-trust",
        &["codex".into(), directory.to_string_lossy().into_owned()],
        0,
    );
    let output = Command::new("/opt/homebrew/bin/tmux")
        .args([
            "new-window",
            "-d",
            "-t",
            "=config-tt:",
            "-n",
            request["roster"][0]["window"].as_str().unwrap(),
            "-c",
            directory.to_str().unwrap(),
            "-P",
            "-F",
            "#{pane_id}",
        ])
        .output()
        .unwrap();
    assert!(output.status.success());
    let pane = String::from_utf8(output.stdout).unwrap().trim().to_owned();
    let guard = OwnedWindow {
        pane: pane.clone(),
        directory,
    };
    let mut args = Lane::proof_args(&prep_ref, "prepared");
    args.extend([("seat-id", "a".into()), ("pane", pane)]);
    let owned = lane.dispatch("own", &args, 0).unwrap();
    let receipt = read(&owned);
    assert_eq!(receipt["phase"], "owned-launch");
    assert!(receipt["seats"][0]["pane_process"]["unique_id"].is_u64());
    let index = put(
        &lane.root.join("custody-index.json"),
        &json!({"context":prepared["context"],"launch_ref":owned,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":null,"non_observation":true,"cause":"owned pre-Start custody control"}]}),
    );
    let mut args = Lane::proof_args(&owned, "launched");
    args.extend([
        ("native-index", index["path"].as_str().unwrap().into()),
        ("native-sha256", index["sha256"].as_str().unwrap().into()),
        (
            "output",
            lane.root
                .join("custody-retained.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let retained = lane.dispatch("retain", &args, 0).unwrap();
    let mut args = Lane::proof_args(&owned, "launched");
    args.extend([
        ("collected", retained["path"].as_str().unwrap().into()),
        (
            "collected-sha256",
            retained["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("custody-cleanup.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let cleanup = lane.dispatch("cleanup", &args, 0).unwrap();
    assert_eq!(read(&cleanup)["seats"][0]["pane_observed"], true);
    assert_eq!(
        read(&cleanup)["seats"][0]["captured_processes_closed"],
        true
    );
    drop(guard);
    println!("P3X_CUSTODY_PASS {}", lane.root.display());
}

struct LaunchGuard {
    route: String,
    directory: PathBuf,
    evidence: PathBuf,
}
impl Drop for LaunchGuard {
    fn drop(&mut self) {
        let output = Command::new("/opt/homebrew/bin/tmux")
            .args([
                "display-message",
                "-p",
                "-t",
                &self.route,
                "#{pane_id}\t#{pane_current_path}",
            ])
            .output()
            .unwrap();
        if output.status.success() {
            let text = String::from_utf8(output.stdout).unwrap();
            if let Some((pane, cwd)) = text.trim().split_once('\t') {
                if Path::new(cwd) == self.directory {
                    let capture = Command::new("/opt/homebrew/bin/tmux")
                        .args(["capture-pane", "-p", "-e", "-t", pane])
                        .output()
                        .unwrap();
                    let _ = fs::write(&self.evidence, capture.stdout);
                    let _ = Command::new("/opt/homebrew/bin/tmux")
                        .args(["kill-window", "-t", pane])
                        .status();
                }
            }
        }
    }
}

fn find_native(root: &Path, seat: &Path) -> Option<PathBuf> {
    for entry in fs::read_dir(root).ok()?.flatten() {
        let path = entry.path();
        if path.is_dir() {
            if let Some(found) = find_native(&path, seat) {
                return Some(found);
            }
        } else if path.extension().is_some_and(|e| e == "jsonl") {
            let text = fs::read_to_string(&path).ok()?;
            if text
                .lines()
                .next()
                .and_then(|line| serde_json::from_str::<Value>(line).ok())
                .is_some_and(|row| {
                    row["payload"]["cwd"]
                        .as_str()
                        .is_some_and(|cwd| Path::new(cwd) == seat)
                })
            {
                return Some(path);
            }
        }
    }
    None
}

#[test]
#[ignore = "explicit owned interactive Codex pilot; sends one sanctioned Start and closes only its fresh seat"]
fn native_interactive_start_collect_cleanup() {
    assert_plain_pane();
    let mut lane = Lane::new();
    symlink(lane.real_home.join(".codex"), lane.home.join(".codex")).unwrap();
    let request_ref = lane.request(4, 60);
    let request = read(&request_ref);
    let prep_ref = lane.prepare(&request_ref, "interactive-batch");
    let prepared = read(&prep_ref);
    let directory = PathBuf::from(prepared["seats"][0]["directory"].as_str().unwrap());
    let guard = LaunchGuard {
        route: format!(
            "=config-tt:={}",
            request["roster"][0]["window"].as_str().unwrap()
        ),
        directory: directory.clone(),
        evidence: lane.root.join("final-screen.ansi"),
    };
    let args = Lane::proof_args(&prep_ref, "prepared");
    let launched = lane.dispatch("launch", &args, 0).unwrap();
    let launch = read(&launched);
    let seat = &launch["seats"][0];
    assert_eq!(
        seat["delivery"]["native_start"]
            .as_str()
            .unwrap()
            .matches("#panel-start")
            .count(),
        1
    );
    let native_root = lane.home.join(".local/state/codex-panel-home/sessions");
    let deadline = Instant::now() + std::time::Duration::from_secs(60);
    let native = loop {
        if let Some(path) = find_native(&native_root, &directory) {
            break path;
        }
        assert!(
            Instant::now() < deadline,
            "native transcript did not appear"
        );
        std::thread::sleep(std::time::Duration::from_millis(250));
    };
    let locations = put(
        &lane.root.join("interactive-locations.json"),
        &json!({"context":launch["context"],"launch_ref":launched,"seats":[{"seat_id":"a","attempt_id":"one","native_path":native}]}),
    );
    let mut args = Lane::proof_args(&launched, "launched");
    args.extend([
        ("locations", locations["path"].as_str().unwrap().into()),
        (
            "locations-sha256",
            locations["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("interactive-wait.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let observed_ref = lane.dispatch("wait", &args, 0).unwrap();
    let observed = read(&observed_ref);
    assert_eq!(
        observed["seats"][0]["candidate"], true,
        "{}",
        observed["seats"][0]["cause"]
    );
    let native_ref = &observed["seats"][0]["native_session_ref"];
    let native_rows: Vec<Value> = fs::read_to_string(native_ref["path"].as_str().unwrap())
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let finals: Vec<_> = native_rows
        .iter()
        .filter_map(|row| {
            let p = &row["payload"];
            if row["type"] == "response_item"
                && p["type"] == "message"
                && p["role"] == "assistant"
                && (p["channel"] == "final" || p["phase"] == "final_answer")
            {
                Some(
                    p["content"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|c| c["text"].as_str().unwrap())
                        .collect::<Vec<_>>()
                        .join("\n"),
                )
            } else {
                None
            }
        })
        .collect();
    assert_eq!(finals.len(), 1);
    let final_text = &finals[0];
    let boundary = put(
        &lane.root.join("interactive-boundary.json"),
        &json!({"context":launch["context"],"seat_id":"a","attempt_id":"one","session_id":observed["seats"][0]["session_id"],"native_ref":native_ref,"descendants":[],"launch_ref":launched,"pane":seat["pane"],"session_binding_verified":true,"independent":true,"isolation_pass":true,"external_input_pass":true,"final_sha256":hash(final_text.as_bytes()),"raw_verdict":"PASS","test_fixture_only":true}),
    );
    let index = put(
        &lane.root.join("interactive-index.json"),
        &json!({"context":launch["context"],"launch_ref":launched,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":native_ref,"format":"codex-jsonl","descendants":[],"boundary_review_ref":boundary,"account_ref":null}]}),
    );
    let mut args = Lane::proof_args(&launched, "launched");
    args.extend([
        ("native-index", index["path"].as_str().unwrap().into()),
        ("native-sha256", index["sha256"].as_str().unwrap().into()),
    ]);
    let collected = lane.dispatch("collect", &args, 0).unwrap();
    let mut args = Lane::proof_args(&launched, "launched");
    args.extend([
        ("collected", collected["path"].as_str().unwrap().into()),
        (
            "collected-sha256",
            collected["sha256"].as_str().unwrap().into(),
        ),
        (
            "output",
            lane.root
                .join("interactive-cleanup.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let cleanup = lane.dispatch("cleanup", &args, 0).unwrap();
    assert_eq!(read(&cleanup)["phase"], "cleaned");
    drop(guard);
    println!("P3X_INTERACTIVE_PASS {}", lane.root.display());
}

#[test]
#[ignore = "owned no-pane provider temp retirement and marker refusal checks; launches no model"]
fn native_provider_temp_retirement() {
    assert_plain_pane();
    for (round, kind, trust_kind) in [
        (5, "fable", "claude"),
        (6, "deepseek", "deepseek"),
        (7, "gemini", "agy"),
    ] {
        let mut lane = Lane::new();
        let initial = lane.request(round, 1);
        let mut request = read(&initial);
        request["roster"][0]["transport"] = json!(kind);
        if kind == "gemini" {
            request["roster"][0]["accepted_limitations"] = json!(["outside-writes-not-confined"]);
        }
        let mut first = read(&request["first_attempt_ref"]);
        first["roster"] = request["roster"].clone();
        request["first_attempt_ref"] = put(&lane.root.join("provider-first.json"), &first);
        let request_ref = put(&lane.root.join("provider-request.json"), &request);
        let prep_ref = lane.prepare(&request_ref, "provider-batch");
        let prepared = read(&prep_ref);
        let mut seat = prepared["seats"][0].clone();
        let directory = PathBuf::from(seat["directory"].as_str().unwrap());
        lane.call(
            "panel-seat-trust",
            &[trust_kind.into(), directory.to_string_lossy().into_owned()],
            0,
        );
        let temp = Path::new("/private/tmp")
            .join(format!("panel-{}", fs::metadata(&directory).unwrap().ino()));
        if kind != "gemini" {
            assert!(temp.is_dir());
        }
        let pending = put(
            &lane.root.join("provider-pending.json"),
            &json!({"phase":"trust-pending","context":prepared["context"],"request_ref":request_ref,"prepared_ref":prep_ref,"adapter":prepared["adapter"],"batch":prepared["batch"],"seats":prepared["seats"]}),
        );
        seat["pane"] = Value::Null;
        seat["pane_process"] = Value::Null;
        let owned = put(
            &lane.root.join("provider-owned.json"),
            &json!({"phase":"prestart-recovery","context":prepared["context"],"request_ref":request_ref,"prepared_ref":prep_ref,"adapter":prepared["adapter"],"batch":prepared["batch"],"seats":[seat],"trust_pending_ref":pending}),
        );
        let index = put(
            &lane.root.join("provider-index.json"),
            &json!({"context":prepared["context"],"launch_ref":owned,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":null,"non_observation":true,"cause":"owned provider cleanup control"}]}),
        );
        let mut args = Lane::proof_args(&owned, "launched");
        args.extend([
            ("native-index", index["path"].as_str().unwrap().into()),
            ("native-sha256", index["sha256"].as_str().unwrap().into()),
            (
                "output",
                lane.root
                    .join("provider-retained.json")
                    .to_string_lossy()
                    .into_owned(),
            ),
        ]);
        let retained = lane.dispatch("retain", &args, 0).unwrap();
        let mut args = Lane::proof_args(&owned, "launched");
        args.extend([
            ("collected", retained["path"].as_str().unwrap().into()),
            (
                "collected-sha256",
                retained["sha256"].as_str().unwrap().into(),
            ),
            (
                "output",
                lane.root
                    .join("provider-cleanup.json")
                    .to_string_lossy()
                    .into_owned(),
            ),
        ]);
        if kind == "fable" {
            fs::write(temp.join(".panel-seat"), "another seat\n").unwrap();
            lane.dispatch("cleanup", &args, 1);
            assert!(temp.is_dir());
            assert!(!Path::new(prepared["batch"].as_str().unwrap())
                .join("a-cleanup-started.json")
                .exists());
            fs::write(
                temp.join(".panel-seat"),
                directory.to_string_lossy().to_string() + "\n",
            )
            .unwrap();
        }
        let cleaned = lane.dispatch("cleanup", &args, 0).unwrap();
        assert_eq!(read(&cleaned)["phase"], "cleaned");
        assert!(!temp.exists());
        let config = lane.home.join(if kind == "gemini" {
            ".gemini/antigravity-cli/settings.json"
        } else {
            ".claude.json"
        });
        let value: Value = serde_json::from_slice(&fs::read(config).unwrap()).unwrap();
        if kind == "gemini" {
            assert!(!value["trustedWorkspaces"]
                .as_array()
                .unwrap()
                .contains(&json!(directory)));
        } else {
            assert!(value["projects"].get(directory.to_str().unwrap()).is_none());
            assert_eq!(value["untouched"], 42);
        }
        println!("P3X_PROVIDER_PASS {kind} {}", lane.root.display());
    }
}

#[test]
#[ignore = "native protocol needs data artifacts and no owner executable modules"]
fn native_protocol_checkout_is_data_only() {
    assert_plain_pane();
    let mut lane = Lane::new();
    let reference = lane.request(8, 1);
    let mut request = read(&reference);
    let root = lane.root.join("data-only-protocol");
    fs::create_dir_all(root.join("reviews/schema")).unwrap();
    fs::copy(
        lane.real_home
            .join(".skills/review-protocol/reviews/schema/resolve-ledger.schema.json"),
        root.join("reviews/schema/resolve-ledger.schema.json"),
    )
    .unwrap();
    request["protocol_root"] = json!(root);
    let request = put(&lane.root.join("data-only-request.json"), &request);
    lane.prepare(&request, "data-only-batch");
    println!("P3X_IMPORT_ORIGIN_PASS {}", lane.root.display());
}
