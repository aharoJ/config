use crate::{panel_io::*, panel_native};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, DirBuilder};
use std::os::unix::fs::{DirBuilderExt, MetadataExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

pub(crate) const START: &str = "#panel-start Read PROMPT.md in this folder and follow it exactly.";
pub(crate) type Args = BTreeMap<String, String>;
pub(crate) fn arg<'a>(args: &'a Args, key: &str) -> Result<&'a str> {
    args.get(key)
        .map(String::as_str)
        .ok_or_else(|| format!("missing option --{key}"))
}
pub(crate) fn authority(args: &Args, key: &str, digest: &str) -> Result<Value> {
    Ok(json!({"path":arg(args,key)?,"sha256":arg(args,digest)?}))
}
pub(crate) fn context(v: &Value) -> Value {
    fields(v, &["topic", "cycle_type", "cycle", "round"])
}
pub(crate) fn source() -> Result<PathBuf> {
    io(std::env::current_exe()).and_then(|p| io(fs::canonicalize(p)))
}
pub(crate) fn tools() -> Result<PathBuf> {
    source()?
        .parent()
        .map(Path::to_owned)
        .ok_or("tool directory missing".into())
}
pub(crate) fn adapter() -> Result<Value> {
    Ok(
        json!({"id":"config-panel-dispatch","version":"1","source_sha256":reference(&source()?)?["sha256"]}),
    )
}
fn executable_hash(path: &Path) -> Result<Value> {
    Ok(reference(&io(fs::canonicalize(path))?)?["sha256"].clone())
}
pub(crate) fn format(kind: &str) -> Result<&'static str> {
    match kind {
        "astra" => Ok("codex-jsonl"),
        "fable" | "deepseek" => Ok("claude-jsonl"),
        "gemini" => Ok("agy-jsonl"),
        _ => Err("unsupported transport".into()),
    }
}
fn safe(value: &str, dot: bool) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b) || (dot && b == b'.'))
}
fn slot(request: &Value) -> Result<PathBuf> {
    let scope = merge(
        context(request),
        json!({"project_root":panel_native::resolve(Path::new(s(request,"project_root")?))?}),
    );
    let text = serde_json::to_string(&scope).map_err(|e| e.to_string())?;
    let mut pretty = String::new();
    let mut quoted = false;
    let mut escaped = false;
    for ch in text.chars() {
        if ch as u32 >= 0x7f {
            for unit in ch.encode_utf16(&mut [0; 2]).iter() {
                pretty.push_str(&format!("\\u{unit:04x}"));
            }
        } else {
            pretty.push(ch);
        }
        if quoted {
            if escaped {
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                quoted = false;
            }
        } else if ch == '"' {
            quoted = true;
        } else if ch == ':' || ch == ',' {
            pretty.push(' ');
        }
    }
    Ok(home()?
        .join(".local/state/panel-dispatch/initial-launches")
        .join(format!("{}.json", hash(pretty.as_bytes()))))
}
fn first_attempt(request: &Value, reference: &Value) -> Result<()> {
    let proof = read(&request["first_attempt_ref"])?;
    check(
        proof["context"] == context(request)
            && proof["project_root"] == request["project_root"]
            && proof["roster"] == request["roster"],
        "initial attempt authority binding mismatch",
    )?;
    check(
        proof["independent"] == true
            && proof["authorized"] == true
            && proof["prior_attempts"] == json!([]),
        "v1 requires independently authorized first attempts; replacements unsupported",
    )?;
    let root = Path::new(s(request, "project_root")?);
    check(
        !Path::new(s(&request["first_attempt_ref"], "path")?).starts_with(root),
        "first attempt authority must be external",
    )?;
    let ledger = root
        .join("reviews")
        .join(s(request, "topic")?)
        .join("state")
        .join(s(request, "cycle_type")?)
        .join(format!("resolve-r{}.json", request["round"]));
    check(
        !ledger.exists(),
        "existing round ledger makes first-attempt authority ambiguous",
    )?;
    let claim = slot(request)?;
    if claim.exists() {
        check(
            decode(&path_bytes(&claim)?)?["request_ref"] == *reference,
            "round already claimed by another current attempt; replacement unsupported",
        )?;
    }
    Ok(())
}
fn claim_launch(request: &Value, reference: &Value) -> Result<Value> {
    first_attempt(request, reference)?;
    let slot = slot(request)?;
    let parent = slot.parent().ok_or("claim parent missing")?;
    io(DirBuilder::new().recursive(true).mode(0o700).create(parent))?;
    let m = io(fs::metadata(parent))?;
    check(
        io(fs::canonicalize(parent))? == parent
            && m.uid() == unsafe { libc::getuid() }
            && m.mode() & 0o7777 == 0o700,
        "unsafe initial-launch claim directory",
    )?;
    let result = fresh(
        &slot,
        &json!({"request_ref":reference,"context":context(request),"project_root":request["project_root"],"first_attempt_ref":request["first_attempt_ref"],"created_at":now(),"scope":"one initial launch only; never admission or supersession authority"}),
    )?;
    io(io(fs::File::open(parent))?.sync_all())?;
    Ok(result)
}
pub(crate) fn request_check(reference: &Value) -> Result<Value> {
    let value = read(reference)?;
    check(
        closed(
            &value,
            &[
                "version",
                "project_root",
                "protocol_root",
                "topic",
                "cycle_type",
                "cycle",
                "round",
                "session",
                "packet",
                "roster",
                "redispatch_policy_ref",
                "launcher_ref",
                "first_attempt_ref",
                "deadline_seconds",
                "authorized",
                "authorized_at",
            ],
        ) && value["version"] == "1"
            && value["authorized"] == true,
        "closed authorized v1 launch request required",
    )?;
    let topic = s(&value, "topic")?;
    check(
        !topic.is_empty() && topic.as_bytes()[0].is_ascii_lowercase()
            || topic.as_bytes().first().is_some_and(u8::is_ascii_digit),
        "invalid topic",
    )?;
    check(
        topic
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-'),
        "invalid topic",
    )?;
    check(
        [Some("research"), Some("implementation")].contains(&value["cycle_type"].as_str())
            && !s(&value, "cycle")?.trim().is_empty(),
        "invalid cycle",
    )?;
    check(
        value["round"].as_u64().is_some_and(|n| n > 0),
        "invalid round",
    )?;
    check(
        safe(s(&value, "session")?, false),
        "exact named session required",
    )?;
    check(
        value["deadline_seconds"]
            .as_u64()
            .is_some_and(|n| (1..=3600).contains(&n)),
        "bounded deadline required",
    )?;
    let root = Path::new(s(&value, "project_root")?);
    check(
        root.is_absolute() && root.is_dir(),
        "reviewed project root required",
    )?;
    check(
        !Path::new(s(reference, "path")?).starts_with(root),
        "launch authority must be external",
    )?;
    protocol(s(&value, "protocol_root")?, "protocol_load", &Value::Null)?;
    let packet = &value["packet"];
    check(
        closed(
            packet,
            &[
                "canonical_input",
                "delivered_input",
                "manifest",
                "prompt",
                "projection_review",
            ],
        ),
        "closed packet required",
    )?;
    let canonical = read_bytes(&packet["canonical_input"])?;
    let manifest = read(&packet["manifest"])?;
    let stem = if value["cycle_type"] == "implementation" {
        "audit"
    } else {
        "research"
    };
    let expected = root
        .join("reviews")
        .join(topic)
        .join("intakes")
        .join(format!("{stem}-r{}", value["round"]));
    let expected = expected.to_str().ok_or("non-UTF8 intake path")?;
    check(
        s(&packet["canonical_input"], "path")? == format!("{expected}.md")
            && s(&packet["manifest"], "path")? == format!("{expected}.manifest.json"),
        "wrong canonical intake location",
    )?;
    check(
        [
            ".commit-marker.json",
            ".commit-marker.json.tmp",
            ".md.tmp",
            ".manifest.json.tmp",
        ]
        .iter()
        .all(|suffix| !Path::new(&format!("{expected}{suffix}")).exists()),
        "pending canonical publication",
    )?;
    check(
        manifest["status"] == "PASS"
            && manifest["sha256"] == format!("sha256:{}", s(&packet["canonical_input"], "sha256")?)
            && manifest["bytes"].as_u64() == Some(canonical.len() as u64)
            && manifest["output"] == packet["canonical_input"]["path"],
        "compiler manifest mismatch",
    )?;
    read_bytes(&packet["delivered_input"])?;
    read_bytes(&packet["prompt"])?;
    let projection = read(&packet["projection_review"])?;
    check(
        projection["context"] == context(&value)
            && ["canonical_input", "delivered_input", "prompt"]
                .iter()
                .all(|k| projection[*k] == packet[*k]),
        "projection/prompt identity mismatch",
    )?;
    check(
        projection["exclusion_pass"] == true
            && projection["fidelity_pass"] == true
            && projection["independent"] == true
            && projection["unknown_fields"] == json!([]),
        "unresolved independent projection check",
    )?;
    let launcher = read(&value["launcher_ref"])?;
    check(
        launcher["context"] == context(&value)
            && launcher["adapter"] == adapter()?
            && launcher["authorized"] == true,
        "launcher identity/authority mismatch",
    )?;
    check(
        launcher["tai_sha256"] == adapter()?["source_sha256"]
            && launcher["trust_sha256"] == executable_hash(&tools()?.join("panel-seat-trust"))?,
        "launcher source drift",
    )?;
    check(
        executable_hash(&home()?.join(".config/tmux/tools/panel-seat-trust"))?
            == launcher["trust_sha256"],
        "installed trust helper differs from bound launcher",
    )?;
    let policy = read(&value["redispatch_policy_ref"])?;
    check(
        policy["context"] == context(&value)
            && policy["authorized"] == true
            && policy["max_redispatches"].as_u64() == Some(0)
            && policy["exhaustion"] == "non-response",
        "v1 requires an explicit zero automatic-redispatch budget; exhaustion is non-response",
    )?;
    check(
        a(&policy, "technical_causes")?
            .iter()
            .all(|c| c.as_str().is_some_and(|s| !s.is_empty())),
        "technical causes required",
    )?;
    let authorized = instant(s(&value, "authorized_at")?)?;
    check(
        instant(s(&policy, "authorized_at")?)? <= authorized && authorized <= instant(&now())?,
        "prospective authority timing mismatch",
    )?;
    let roster = a(&value, "roster")?;
    check(
        (1..=64).contains(&roster.len()),
        "bounded operator roster required",
    )?;
    let mut ids = BTreeSet::new();
    let mut windows = BTreeSet::new();
    for seat in roster {
        check(
            closed(
                seat,
                &[
                    "seat_id",
                    "attempt_id",
                    "transport",
                    "window",
                    "model",
                    "effort",
                    "accepted_limitations",
                ],
            ),
            "closed roster row required",
        )?;
        check(
            ["seat_id", "attempt_id", "model", "effort"]
                .iter()
                .all(|k| seat[*k].as_str().is_some_and(|s| safe(s, true))),
            "invalid seat identity/profile",
        )?;
        check(
            ids.insert(s(seat, "seat_id")?) && windows.insert(s(seat, "window")?),
            "duplicate seat or exact window",
        )?;
        format(s(seat, "transport")?)?;
        let limits = a(seat, "accepted_limitations")?;
        check(
            safe(s(seat, "window")?, false),
            "exact safe window name required",
        )?;
        if seat["transport"] == "gemini" {
            check(
                limits.contains(&json!("outside-writes-not-confined")),
                "Agy limitation not accepted",
            )?;
        }
    }
    first_attempt(&value, reference)?;
    read(reference)?;
    Ok(value)
}
fn ancestors(folder: &Path) -> Result<()> {
    check(
        folder.is_absolute()
            && io(fs::canonicalize(folder))? == folder
            && !io(fs::symlink_metadata(folder))?.file_type().is_symlink(),
        "physical seat required",
    )?;
    for parent in folder.ancestors() {
        check(
            [
                ".git",
                "AGENTS.md",
                "CLAUDE.md",
                ".claude",
                ".codex",
                ".gemini",
            ]
            .iter()
            .all(|name| !parent.join(name).exists()),
            &format!("ambient context in {}", parent.display()),
        )?;
    }
    let slug: String = folder
        .to_string_lossy()
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' {
                c
            } else {
                '-'
            }
        })
        .collect();
    let projects = home()?.join(".claude/projects");
    check(
        !projects.join(&slug).exists()
            && !projects
                .join(slug.replacen("-private-tmp-", "-tmp-", 1))
                .exists(),
        "existing Claude project/context for fresh seat",
    )
}
fn seat_directory(request: &Value, seat: &Value) -> Result<PathBuf> {
    let mut root = PathBuf::from("/private/tmp");
    root.push(format!(
        "review-protocol-{}-audit-r{}-agentic-{}-{}-{}-cli",
        s(request, "topic")?,
        request["round"],
        s(seat, "attempt_id")?,
        s(seat, "transport")?,
        crate::runtime::fresh_id()?
    ));
    io(DirBuilder::new().mode(0o700).create(&root))?;
    Ok(root)
}
pub(crate) fn prepare(args: &Args) -> Result<Value> {
    let authority = authority(args, "request", "sha256")?;
    let request = request_check(&authority)?;
    let batch = Path::new(arg(args, "batch")?);
    check(
        batch.is_absolute() && !batch.exists() && !batch.starts_with(s(&request, "project_root")?),
        "fresh external batch required",
    )?;
    io(DirBuilder::new().mode(0o700).create(batch))?;
    let mut rows = Vec::new();
    for seat in a(&request, "roster")? {
        let folder = seat_directory(&request, seat)?;
        ancestors(&folder)?;
        let mut inputs = serde_json::Map::new();
        for (name, key) in [("PROMPT.md", "prompt"), ("intake.md", "delivered_input")] {
            inputs.insert(
                name.into(),
                fresh_bytes(&folder.join(name), &read_bytes(&request["packet"][key])?)?,
            );
        }
        rows.push(merge(
            seat.clone(),
            json!({"directory":folder,"inputs":inputs,"prepared_at":now()}),
        ));
    }
    fresh(
        &batch.join("prepared.json"),
        &json!({"phase":"prepared","context":context(&request),"request_ref":authority,"adapter":adapter()?,"batch":batch,"seats":rows,"created_at":now()}),
    )
}
fn prepared_check(record: &Value, runtime: bool) -> Result<Value> {
    let request = request_check(&record["request_ref"])?;
    check(
        record["adapter"] == adapter()? && record["context"] == context(&request),
        "prepared source/context drift",
    )?;
    let seats = a(record, "seats")?;
    let wanted = a(&request, "roster")?;
    check(
        seats.len() == wanted.len(),
        "prepared roster length mismatch",
    )?;
    for (seat, wanted) in seats.iter().zip(wanted) {
        check(
            subset(seat, wanted),
            "prepared roster order/profile changed",
        )?;
        let folder = Path::new(s(seat, "directory")?);
        let info = io(fs::symlink_metadata(folder))?;
        check(
            info.is_dir()
                && info.uid() == unsafe { libc::getuid() }
                && info.mode() & 0o777 == 0o700,
            "seat ownership/mode drift",
        )?;
        let mut allowed = vec!["PROMPT.md", "intake.md"];
        if runtime {
            allowed.extend([
                "scratch",
                "panel-settings.json",
                "panel-env.sh",
                "panel-temp.json",
                "unleash-repo-schema-v1-codeium-language-server.json",
            ]);
        }
        let names = io(fs::read_dir(folder))?
            .map(|e| io(e).map(|e| e.file_name().to_string_lossy().into_owned()))
            .collect::<Result<BTreeSet<_>>>()?;
        check(
            names.iter().all(|n| allowed.contains(&n.as_str()))
                && names.contains("PROMPT.md")
                && names.contains("intake.md"),
            "unexpected prepared/runtime files",
        )?;
        for (name, reference) in seat["inputs"].as_object().ok_or("seat inputs missing")? {
            let path = folder.join(name);
            check(
                Path::new(s(reference, "path")?) == path
                    && io(fs::metadata(&path))?.mode() & 0o222 == 0,
                "frozen input path/mode drift",
            )?;
            read_bytes(reference)?;
        }
        check(
            seat["inputs"]["PROMPT.md"]["sha256"] == request["packet"]["prompt"]["sha256"]
                && seat["inputs"]["intake.md"]["sha256"]
                    == request["packet"]["delivered_input"]["sha256"],
            "delivered copy binding mismatch",
        )?;
    }
    Ok(request)
}
pub(crate) fn tmux(args: &[&str]) -> Result<String> {
    let mut command = Command::new("/opt/homebrew/bin/tmux");
    if let Ok(socket) = std::env::var("TMUX_LAB_SOCKET") {
        if !socket.is_empty() {
            command.args(["-L", &socket, "-f", "/dev/null"]);
        }
    }
    command.args(args);
    run(&mut command, None, 30)
}
pub(crate) fn panes(session: &str) -> Result<Vec<Value>> {
    let rows=tmux(&["list-panes","-a","-F","#{session_name}\t#{window_name}\t#{window_id}\t#{pane_id}\t#{pane_pid}\t#{pane_current_command}\t#{pane_current_path}"])?;
    rows.lines().filter(|row|row.split('\t').next()==Some(session)).map(|row|{let p:Vec<_>=row.split('\t').collect();check(p.len()==7,"invalid pane row")?;Ok(json!({"session":p[0],"window":p[1],"window_id":p[2],"pane_id":p[3],"pid":p[4],"command":p[5],"cwd":p[6]}))}).collect()
}
pub(crate) fn exact_pane(session: &str, window: &str) -> Result<Value> {
    let mut found: Vec<_> = panes(session)?
        .into_iter()
        .filter(|p| p["window"] == window)
        .collect();
    check(found.len() == 1, "target is not one unique pane")?;
    Ok(found.pop().unwrap())
}
#[repr(C)]
struct Unique {
    uuid: [u8; 16],
    id: u64,
    parent: u64,
    version: i32,
    parent_version: i32,
    reserved: [u64; 2],
}
#[repr(C)]
struct Bsd {
    head: [u32; 12],
    command: [u8; 16],
    name: [u8; 32],
    tail: [u32; 6],
    seconds: u64,
    micros: u64,
}
unsafe extern "C" {
    fn proc_pidinfo(pid: i32, flavor: i32, arg: u64, buffer: *mut libc::c_void, size: i32) -> i32;
}
pub(crate) fn process_identity(pid: u32) -> Result<Value> {
    let mut bsd: Bsd = unsafe { std::mem::zeroed() };
    let size = std::mem::size_of::<Bsd>() as i32;
    check(
        unsafe { proc_pidinfo(pid as i32, 3, 0, (&mut bsd as *mut Bsd).cast(), size) } == size
            && bsd.head[1] != 5
            && bsd.head[5] == unsafe { libc::getuid() },
        "owned pane process identity unavailable",
    )?;
    let mut unique: Unique = unsafe { std::mem::zeroed() };
    let size = std::mem::size_of::<Unique>() as i32;
    check(
        unsafe { proc_pidinfo(pid as i32, 17, 0, (&mut unique as *mut Unique).cast(), size) }
            == size,
        "kernel unique process identity unavailable",
    )?;
    Ok(json!({"pid":pid,"unique_id":unique.id,"uid":bsd.head[5],"birth":[bsd.seconds,bsd.micros]}))
}
pub(crate) fn custody(pid: u32) -> Result<Vec<Value>> {
    let rows = run(
        Command::new("/bin/ps").args(["-axo", "pid=,ppid="]),
        None,
        30,
    )?;
    let mut graph = BTreeMap::<u32, Vec<u32>>::new();
    for row in rows.lines() {
        let p: Vec<_> = row.split_whitespace().collect();
        check(p.len() == 2, "invalid process row")?;
        graph
            .entry(p[1].parse().map_err(|_| "invalid parent PID")?)
            .or_default()
            .push(p[0].parse().map_err(|_| "invalid PID")?);
    }
    let mut queue = vec![pid];
    let mut found = Vec::new();
    while let Some(pid) = queue.pop() {
        let Ok(identity) = process_identity(pid) else {
            continue;
        };
        found.push(identity);
        queue.extend(graph.get(&pid).into_iter().flatten());
    }
    check(
        found.first().is_some_and(|p| p["pid"] == pid),
        "pane process custody unavailable",
    )?;
    Ok(found)
}
pub(crate) fn remaining(custody: &[Value]) -> Vec<Value> {
    custody
        .iter()
        .filter(|held| {
            held["pid"]
                .as_u64()
                .and_then(|pid| process_identity(pid as u32).ok())
                .as_ref()
                == Some(held)
        })
        .cloned()
        .collect()
}
pub(crate) fn own(args: &Args) -> Result<Value> {
    let preparation = authority(args, "prepared", "sha256")?;
    let record = read(&preparation)?;
    let request = read(&record["request_ref"])?;
    let matches: Vec<_> = a(&record, "seats")?
        .iter()
        .filter(|seat| seat["seat_id"] == arg(args, "seat-id").unwrap_or(""))
        .collect();
    check(
        matches.len() == 1 && record["adapter"] == adapter()?,
        "spawn ownership source/seat conflict",
    )?;
    let seat = matches[0];
    let batch = Path::new(s(&record, "batch")?);
    let id = s(seat, "seat_id")?;
    let intent = batch.join(format!("{id}-spawn-intent.json"));
    if !intent.exists() {
        fresh(
            &intent,
            &json!({"prepared_ref":preparation,"seat_id":id,"pane_id":arg(args,"pane")?,"observed_at":now()}),
        )?;
    }
    let pane = exact_pane(s(&request, "session")?, s(seat, "window")?)?;
    check(
        pane["pane_id"] == arg(args, "pane")?
            && panel_native::resolve(Path::new(s(&pane, "cwd")?))?
                == Path::new(s(seat, "directory")?),
        "spawn ownership exact pane/cwd conflict",
    )?;
    let spawn = batch.join(format!("{id}-spawn.json"));
    if spawn.exists() {
        let original = decode(&path_bytes(&spawn)?)?;
        check(
            fields(&original["pane"], &["window_id", "pane_id", "pid"])
                == fields(&pane, &["window_id", "pane_id", "pid"]),
            "spawn recovery target changed",
        )?;
    } else {
        fresh(
            &spawn,
            &merge(seat.clone(), json!({"pane":pane,"observed_at":now()})),
        )?;
    }
    let deadline = Instant::now() + Duration::from_secs(3);
    let identity = loop {
        match process_identity(s(&pane, "pid")?.parse().map_err(|_| "invalid pane PID")?) {
            Ok(v) => break v,
            Err(_) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(100)),
            Err(_) => {
                return Err(
                    "spawn recorded but kernel custody unavailable; retain seat and do not resend"
                        .into(),
                )
            }
        }
    };
    let temp = Path::new(s(seat, "directory")?).join("panel-temp.json");
    let owned = merge(
        seat.clone(),
        json!({"pane":pane,"pane_process":identity,"process_observer_ref":reference(&source()?)?,"temp":if temp.exists(){decode(&path_bytes(&temp)?)?}else{Value::Null},"launched_at":now()}),
    );
    let path = batch.join(format!("{id}-owned-prestart.json"));
    if !path.exists() {
        fresh(&path, &owned)?;
    }
    let mut rows = Vec::new();
    for seat in a(&record, "seats")? {
        let path = batch.join(format!("{}-owned-prestart.json", s(seat, "seat_id")?));
        if !path.exists() {
            break;
        }
        rows.push(decode(&path_bytes(&path)?)?);
    }
    let path = batch.join(format!("owned-prestart-{}.json", rows.len()));
    if path.exists() {
        reference(&path)
    } else {
        fresh(
            &path,
            &merge(
                fields(&record, &["context", "request_ref", "adapter", "batch"]),
                json!({"phase":"owned-launch","prepared_ref":preparation,"seats":rows,"created_at":now()}),
            ),
        )
    }
}
pub(crate) fn relay_start(request: &Value, seat: &Value) -> Result<Value> {
    let kind = s(seat, "transport")?;
    let name = match kind {
        "fable" | "deepseek" => "cc-msg",
        "astra" => "codex-send-to",
        "gemini" => "agy-send-to",
        _ => return Err("unsupported transport".into()),
    };
    let mut command = Command::new(name);
    if ["fable", "deepseek"].contains(&kind) {
        command
            .env("CC_MSG_SESSION", s(request, "session")?)
            .env("CC_MSG_WINDOW", s(seat, "window")?);
    } else {
        command.env(
            if kind == "astra" {
                "CODEX_SEND_SESSION"
            } else {
                "AGY_SEND_SESSION"
            },
            s(request, "session")?,
        );
        command.arg(s(seat, "window")?);
    }
    command.arg(START);
    let output = run(&mut command, None, 15)?;
    let path = output
        .split_once("; record ")
        .map(|(_, p)| p.lines().next().unwrap_or(""))
        .filter(|p| p.starts_with('/'))
        .ok_or("relay did not return a durable record")?;
    let deadline = Instant::now()
        + Duration::from_secs(
            request["deadline_seconds"]
                .as_u64()
                .ok_or("deadline missing")?,
        );
    let mut value = Value::Null;
    while Instant::now() < deadline {
        value = decode(&path_bytes(Path::new(path))?)?;
        if [Some("delivered"), Some("error")].contains(&value["state"].as_str()) {
            break;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    check(
        value["state"] == "delivered",
        "relay outcome unknown/refused; do not resend",
    )?;
    let native = format!("{}: {START}", s(&value, "label")?);
    check(
        value["payload"] == native,
        "Start was archived/changed; no canonical or pointer fallback",
    )?;
    check(
        value["target"]["session_name"] == request["session"]
            && value["target"]["window_name"] == seat["window"]
            && value["message"] == START
            && value["target"]["pane_id"] == seat["pane"]["pane_id"]
            && value["target"]["pane_pid"] == seat["pane"]["pid"],
        "relay target/input conflict",
    )?;
    let current = exact_pane(s(request, "session")?, s(seat, "window")?)?;
    check(
        fields(&current, &["pane_id", "window_id", "pid"])
            == fields(&seat["pane"], &["pane_id", "window_id", "pid"]),
        "relay target changed during delivery",
    )?;
    Ok(json!({"reference":reference(Path::new(path))?,"native_start":native}))
}
fn launch_prestart(args: &Args) -> Result<Value> {
    let preparation = authority(args, "prepared", "sha256")?;
    let record = read(&preparation)?;
    let request = prepared_check(&record, false)?;
    let batch = Path::new(s(&record, "batch")?);
    check(
        !batch.join("launch-started.json").exists(),
        "launch already attempted; no blind resend",
    )?;
    let existing = panes(s(&request, "session")?)?;
    check(
        !existing.iter().any(|p| {
            a(&record, "seats")
                .unwrap()
                .iter()
                .any(|seat| p["window"] == seat["window"])
        }),
        "target windows already exist",
    )?;
    claim_launch(&request, &record["request_ref"])?;
    fresh(
        &batch.join("launch-started.json"),
        &json!({"prepared_ref":preparation,"created_at":now()}),
    )?;
    let mut launches = Vec::new();
    for seat in a(&record, "seats")? {
        fresh(
            &batch.join(format!("trust-pending-{}.json", launches.len() + 1)),
            &merge(
                fields(&record, &["context", "request_ref", "adapter", "batch"]),
                json!({"phase":"trust-pending","prepared_ref":preparation,"seats":a(&record,"seats")?[..launches.len()+1],"created_at":now()}),
            ),
        )?;
        let output = crate::panel_launch::start(args, &record, seat)?;
        let pane = exact_pane(s(&request, "session")?, s(seat, "window")?)?;
        check(
            panel_native::resolve(Path::new(s(&pane, "cwd")?))? == Path::new(s(seat, "directory")?),
            "launched cwd mismatch",
        )?;
        tmux(&[
            "resize-window",
            "-t",
            s(&pane, "window_id")?,
            "-x",
            "215",
            "-y",
            "50",
        ])?;
        let capture = tmux(&["capture-pane", "-p", "-e", "-t", s(&pane, "pane_id")?])?;
        let screen = fresh_bytes(
            &batch.join(format!("{}-prestart.ansi", s(seat, "seat_id")?)),
            capture.as_bytes(),
        )?;
        let mut files = serde_json::Map::new();
        for entry in io(fs::read_dir(s(seat, "directory")?))? {
            let path = io(entry)?.path();
            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .ok_or("runtime filename not UTF-8")?;
            if path.is_file() && seat["inputs"].get(name).is_none() {
                files.insert(path.to_string_lossy().into_owned(), reference(&path)?);
            }
        }
        let temp = Path::new(s(seat, "directory")?).join("panel-temp.json");
        let launched = merge(
            seat.clone(),
            json!({"pane":pane,"pane_process":process_identity(s(&pane,"pid")?.parse().map_err(|_|"invalid pane PID")?)?,"process_observer_ref":reference(&source()?)?,"launch_stdout":output,"launched_at":now(),"prestart_ref":screen,"runtime_files":files,"temp":if temp.exists(){decode(&path_bytes(&temp)?)?}else{Value::Null}}),
        );
        fresh(
            &batch.join(format!("{}-launched.json", s(seat, "seat_id")?)),
            &launched,
        )?;
        launches.push(launched);
        fresh(
            &batch.join(format!("owned-{}.json", launches.len())),
            &merge(
                fields(&record, &["context", "request_ref", "adapter", "batch"]),
                json!({"phase":"owned-launch","prepared_ref":preparation,"seats":launches,"created_at":now()}),
            ),
        )?;
    }
    prepared_check(&record, true)?;
    fresh(
        &batch.join("starts-entered.json"),
        &json!({"prepared_ref":preparation,"created_at":now()}),
    )?;
    for seat in &mut launches {
        let current = exact_pane(s(&request, "session")?, s(seat, "window")?)?;
        check(
            fields(&current, &["window_id", "pane_id", "pid", "cwd"])
                == fields(&seat["pane"], &["window_id", "pane_id", "pid", "cwd"]),
            "pre-start target identity drift",
        )?;
        seat["delivery"] = relay_start(&request, seat)?;
        fresh(
            &batch.join(format!("{}-start.json", s(seat, "seat_id")?)),
            &seat["delivery"],
        )?;
    }
    fresh(
        &batch.join("launched.json"),
        &merge(
            fields(&record, &["context", "request_ref", "adapter", "batch"]),
            json!({"phase":"launched","prepared_ref":preparation,"seats":launches,"created_at":now()}),
        ),
    )
}
fn recover(record: &Value, preparation: &Value, error: &str) -> Result<()> {
    let batch = Path::new(s(record, "batch")?);
    for seat in a(record, "seats")? {
        let id = s(seat, "seat_id")?;
        let intent = batch.join(format!("{id}-spawn-intent.json"));
        if intent.exists() && !batch.join(format!("{id}-owned-prestart.json")).exists() {
            let value = decode(&path_bytes(&intent)?)?;
            check(
                value["prepared_ref"] == *preparation,
                "spawn intent preparation conflict",
            )?;
            let args = Args::from([
                ("prepared".into(), s(preparation, "path")?.into()),
                ("sha256".into(), s(preparation, "sha256")?.into()),
                ("seat-id".into(), id.into()),
                ("pane".into(), s(&value, "pane_id")?.into()),
            ]);
            own(&args)?;
        }
    }
    let mut pending = io(fs::read_dir(batch))?
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().into_owned();
            let n = name
                .strip_prefix("trust-pending-")?
                .strip_suffix(".json")?
                .parse::<u64>()
                .ok()?;
            Some((n, e.path()))
        })
        .collect::<Vec<_>>();
    pending.sort_by_key(|(n, _)| *n);
    let Some((_, path)) = pending.last() else {
        return Ok(());
    };
    let pending_ref = reference(path)?;
    let proof = read(&pending_ref)?;
    check(
        proof["prepared_ref"] == *preparation,
        "trust recovery preparation conflict",
    )?;
    let mut rows = Vec::new();
    for seat in a(&proof, "seats")? {
        let path = batch.join(format!("{}-owned-prestart.json", s(seat, "seat_id")?));
        rows.push(if path.exists() {
            decode(&path_bytes(&path)?)?
        } else {
            merge(seat.clone(), json!({"pane":null,"pane_process":null}))
        });
    }
    let launch_ref = fresh(
        &batch.join("prestart-recovery.json"),
        &merge(
            fields(record, &["context", "request_ref", "adapter", "batch"]),
            json!({"phase":"prestart-recovery","prepared_ref":preparation,"seats":rows,"trust_pending_ref":pending_ref,"created_at":now()}),
        ),
    )?;
    let index = fresh(
        &batch.join("prestart-failure-index.json"),
        &json!({"context":record["context"],"launch_ref":launch_ref,"seats":rows.iter().map(|seat|merge(fields(seat,&["seat_id","attempt_id"]),json!({"native_ref":null,"non_observation":true,"cause":format!("pre-Start launch failure; native transcript not observed: {error}")}))).collect::<Vec<_>>()}),
    )?;
    let args = Args::from([
        ("launched".into(), s(&launch_ref, "path")?.into()),
        ("sha256".into(), s(&launch_ref, "sha256")?.into()),
        ("native-index".into(), s(&index, "path")?.into()),
        ("native-sha256".into(), s(&index, "sha256")?.into()),
        (
            "output".into(),
            batch
                .join("prestart-failure-retained.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    let retained = retain(&args)?;
    let args = Args::from([
        ("launched".into(), s(&launch_ref, "path")?.into()),
        ("sha256".into(), s(&launch_ref, "sha256")?.into()),
        ("collected".into(), s(&retained, "path")?.into()),
        ("collected-sha256".into(), s(&retained, "sha256")?.into()),
        (
            "output".into(),
            batch
                .join("prestart-failure-cleanup.json")
                .to_string_lossy()
                .into_owned(),
        ),
    ]);
    crate::panel_cleanup::cleanup(&args)?;
    Ok(())
}
fn launch(args: &Args) -> Result<Value> {
    let prep = authority(args, "prepared", "sha256")?;
    let record = read(&prep)?;
    match launch_prestart(args) {
        Ok(v) => Ok(v),
        Err(error) => {
            if let Some(batch) = record["batch"].as_str() {
                if !Path::new(batch).join("starts-entered.json").exists() {
                    recover(&record, &prep, &error)?;
                }
            }
            Err(error)
        }
    }
}
pub(crate) fn retain(args: &Args) -> Result<Value> {
    let launch_ref = authority(args, "launched", "sha256")?;
    let launch = read(&launch_ref)?;
    let index_ref = authority(args, "native-index", "native-sha256")?;
    let index = read(&index_ref)?;
    check(
        index["launch_ref"] == launch_ref && index["context"] == launch["context"],
        "retained native index authority conflict",
    )?;
    let seats = a(&launch, "seats")?;
    let supplied = a(&index, "seats")?;
    check(
        seats.len() == supplied.len(),
        "retained roster length mismatch",
    )?;
    let mut outputs = Vec::new();
    for (seat, supplied) in seats.iter().zip(supplied) {
        check(
            fields(supplied, &["seat_id", "attempt_id"])
                == fields(seat, &["seat_id", "attempt_id"]),
            "retained seat order/identity mismatch",
        )?;
        let native = supplied.get("native_ref").filter(|v| !v.is_null());
        check(
            native.is_some() || supplied["non_observation"] == true,
            "missing native requires explicit non-observation",
        )?;
        let snapshot = if let Some(native) = native {
            fresh_bytes(
                &Path::new(s(&launch, "batch")?)
                    .join(format!("{}-unadmitted-native.jsonl", s(seat, "seat_id")?)),
                &read_bytes(native)?,
            )?
        } else {
            Value::Null
        };
        check(
            !s(supplied, "cause")?.trim().is_empty(),
            "non-response cause required",
        )?;
        outputs.push(merge(fields(seat,&["seat_id","attempt_id"]),json!({"native_session_ref":snapshot,"final_ref":null,"admitted":false,"responding":false,"raw_verdict":null,"pass_floor_eligible":false,"cause":supplied["cause"],"findings":"retained native bytes require lead reproduction/classification; no vote credit"})));
    }
    read(&index_ref)?;
    fresh(
        Path::new(arg(args, "output")?),
        &merge(
            fields(
                &launch,
                &["context", "adapter", "batch", "request_ref", "prepared_ref"],
            ),
            json!({"phase":"unadmitted-retention","launch_ref":launch_ref,"native_index_ref":index_ref,"seats":outputs,"created_at":now()}),
        ),
    )
}
fn wait(args: &Args) -> Result<Value> {
    let launch_ref = authority(args, "launched", "sha256")?;
    let launch = read(&launch_ref)?;
    let request = request_check(&launch["request_ref"])?;
    let locations_ref = authority(args, "locations", "locations-sha256")?;
    let locations = read(&locations_ref)?;
    check(
        closed(&locations, &["context", "launch_ref", "seats"])
            && locations["context"] == launch["context"]
            && locations["launch_ref"] == launch_ref,
        "native locations authority conflict",
    )?;
    let seats = a(&launch, "seats")?;
    let locations = a(&locations, "seats")?;
    check(
        seats.len() == locations.len(),
        "native locations roster mismatch",
    )?;
    for (seat, location) in seats.iter().zip(locations) {
        check(
            closed(location, &["seat_id", "attempt_id", "native_path"])
                && fields(location, &["seat_id", "attempt_id"])
                    == fields(seat, &["seat_id", "attempt_id"]),
            "native location identity mismatch",
        )?;
        check(
            Path::new(s(location, "native_path")?).is_absolute(),
            "absolute current native location required",
        )?;
    }
    let deadline =
        Instant::now() + Duration::from_secs(request["deadline_seconds"].as_u64().unwrap());
    let mut pending: Vec<usize> = (0..seats.len()).collect();
    let mut last = BTreeMap::new();
    let mut observations: Vec<_> = seats
        .iter()
        .map(|seat| {
            merge(
                fields(seat, &["seat_id", "attempt_id"]),
                json!({"candidate":false,"cause":"deadline exhausted before native observation"}),
            )
        })
        .collect();
    while !pending.is_empty() && Instant::now() < deadline {
        let mut remaining = Vec::new();
        for index in pending {
            let seat = &seats[index];
            let inspected = (|| {
                let bytes = path_bytes(Path::new(s(&locations[index], "native_path")?))?;
                last.insert(index, bytes.clone());
                panel_native::inspect(&bytes, format(s(seat, "transport")?)?, seat)
            })();
            observations[index] = merge(
                fields(seat, &["seat_id", "attempt_id"]),
                match inspected {
                    Ok(diagnostics) => merge(
                        fields(&diagnostics, &["model", "effort", "session_id"]),
                        json!({"candidate":true,"cause":"native binding/read/final checks passed"}),
                    ),
                    Err(error) => {
                        remaining.push(index);
                        json!({"candidate":false,"cause":error})
                    }
                },
            );
        }
        pending = remaining;
        if !pending.is_empty() {
            std::thread::sleep(Duration::from_millis(250));
        }
    }
    for (index, observation) in observations.iter_mut().enumerate() {
        observation["native_session_ref"] = if let Some(bytes) = last.get(&index) {
            fresh_bytes(
                &Path::new(s(&launch, "batch")?).join(format!(
                    "{}-observed-native.jsonl",
                    s(&seats[index], "seat_id")?
                )),
                bytes,
            )?
        } else {
            Value::Null
        };
        let candidate = observation["candidate"] == true;
        observation["exhausted"] = json!(!candidate);
        observation["accounting"] = json!(if candidate {
            "candidate only; no vote until independent admission"
        } else {
            "non-response; retain evidence and existing C71 authority requirements"
        });
    }
    read(&locations_ref)?;
    request_check(&launch["request_ref"])?;
    fresh(
        Path::new(arg(args, "output")?),
        &json!({"phase":"observed","launch_ref":launch_ref,"locations_ref":locations_ref,"context":launch["context"],"seats":observations,"created_at":now(),"automatic_redispatches":0}),
    )
}
fn verify(args: &Args) -> Result<Value> {
    let dispatch_ref = authority(args, "dispatch", "sha256")?;
    let dispatch = read(&dispatch_ref)?;
    check(
        dispatch["adapter"] == adapter()?,
        "dispatch adapter is not this version/source",
    )?;
    let ledger_ref = authority(args, "ledger", "ledger-sha256")?;
    let ledger = read(&ledger_ref)?;
    let sources = protocol(
        arg(args, "protocol-root")?,
        "protocol_verify",
        &json!({"dispatch":dispatch,"authority":dispatch_ref,"ledger":ledger,"project_root":arg(args,"project-root")?}),
    )?;
    fresh(
        Path::new(arg(args, "output")?),
        &json!({"status":"PASS","adapter":adapter()?,"dispatch_ref":dispatch_ref,"ledger_ref":ledger_ref,"pass_sources":sources,"qualification_mode":dispatch["activation"]["mode"],"created_at":now()}),
    )
}
fn collect(args: &Args) -> Result<Value> {
    crate::panel_collect::collect(args)
}
const HELP:&str="usage: panel-dispatch <prepare|launch|own|wait|collect|retain|verify|cleanup> [options]\n       panel-dispatch codex-path\nEvery phase requires --sha256 and its explicit path/hash authority options.\n";
fn parse(args: &[String]) -> Result<Option<(String, Args)>> {
    if args == ["--help"] || args == ["-h"] {
        return Ok(None);
    }
    let phase = args.first().ok_or("phase is required")?;
    let required: &[&str] = match phase.as_str() {
        "prepare" => &["request", "batch"],
        "launch" => &["prepared"],
        "own" => &["prepared", "seat-id", "pane"],
        "wait" => &["launched", "locations", "locations-sha256", "output"],
        "collect" => &["launched", "native-index", "native-sha256"],
        "retain" => &["launched", "native-index", "native-sha256", "output"],
        "verify" => &[
            "protocol-root",
            "project-root",
            "dispatch",
            "ledger",
            "ledger-sha256",
            "output",
        ],
        "cleanup" => &["launched", "collected", "collected-sha256", "output"],
        _ => return Err("invalid phase".into()),
    };
    if args[1..].iter().any(|a| a == "--help" || a == "-h") {
        return Ok(None);
    }
    let mut values = Args::new();
    let mut index = 1;
    let keys: Vec<_> = required
        .iter()
        .copied()
        .chain(std::iter::once("sha256"))
        .collect();
    while index < args.len() {
        let raw = args[index]
            .strip_prefix("--")
            .ok_or("unrecognized argument")?;
        let (name, value) = raw
            .split_once('=')
            .map(|(k, v)| (k, Some(v)))
            .unwrap_or((raw, None));
        let matches: Vec<_> = keys.iter().filter(|k| k.starts_with(name)).collect();
        let key = if keys.contains(&name) {
            name
        } else {
            check(matches.len() == 1, "unrecognized or ambiguous option")?;
            matches[0]
        };
        let value = if let Some(v) = value {
            v.to_owned()
        } else {
            index += 1;
            let v = args.get(index).ok_or("option requires a value")?;
            check(!v.starts_with("--"), "option requires a value")?;
            v.clone()
        };
        values.insert(key.to_owned(), value);
        index += 1;
    }
    check(
        keys.iter().all(|k| values.contains_key(*k)),
        "required option missing",
    )?;
    Ok(Some((phase.clone(), values)))
}
pub fn main_entry(args: &[String]) -> i32 {
    if args == ["codex-path"] {
        return match crate::panel_launch::executable("codex") {
            Ok(path) => {
                println!("{}", path.display());
                0
            }
            Err(error) => {
                eprintln!("panel-dispatch: {error}");
                1
            }
        };
    }
    let (phase, args) = match parse(args) {
        Ok(Some(v)) => v,
        Ok(None) => {
            print!("{HELP}");
            return 0;
        }
        Err(error) => {
            eprintln!("{HELP}panel-dispatch: {error}");
            return 2;
        }
    };
    let result = match phase.as_str() {
        "prepare" => prepare(&args),
        "launch" => launch(&args),
        "own" => own(&args),
        "wait" => wait(&args),
        "collect" => collect(&args),
        "retain" => retain(&args),
        "verify" => verify(&args),
        "cleanup" => crate::panel_cleanup::cleanup(&args),
        _ => unreachable!(),
    };
    match result {
        Ok(value) => {
            println!("{value}");
            0
        }
        Err(error) => {
            eprintln!("STOP: {error}");
            1
        }
    }
}

#[cfg(test)]
#[path = "../tests/support/panel_dispatch.rs"]
mod tests;
