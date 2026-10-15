use crate::{
    panel_dispatch::{self, Args},
    panel_io::*,
    panel_trust,
};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::fs;
use std::os::unix::{
    fs::{MetadataExt, PermissionsExt},
    process::CommandExt,
};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

fn executable(name: &str) -> Result<PathBuf> {
    let path = if name.contains('/') {
        PathBuf::from(name)
    } else {
        std::env::split_paths(&std::env::var_os("PATH").unwrap_or_default())
            .map(|dir| dir.join(name))
            .find(|path| {
                fs::metadata(path).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
            })
            .ok_or_else(|| format!("seat CLI not found: {name}"))?
    };
    check(
        fs::metadata(&path).is_ok_and(|m| m.is_file() && m.mode() & 0o111 != 0),
        "seat CLI not executable",
    )?;
    if path.is_absolute() {
        Ok(path)
    } else {
        Ok(io(std::env::current_dir())?.join(path))
    }
}
pub(crate) fn profile(seat: &Value, home: &Path) -> Result<Value> {
    let directory = Path::new(s(seat, "directory")?);
    let kind = s(seat, "transport")?;
    let mut env = BTreeMap::<String, String>::new();
    let scratch = directory.join("scratch");
    env.insert("TMPDIR".into(), scratch.to_string_lossy().into());
    let mut args: Vec<String> = Vec::new();
    let (program, trust) = match kind {
        "astra" => {
            env.insert(
                "CODEX_HOME".into(),
                home.join(".local/state/codex-panel-home")
                    .to_string_lossy()
                    .into(),
            );
            args.extend(["--no-daemon","--strict-config","-m",s(seat,"model")?,"-c",&format!("model_reasoning_effort={}",s(seat,"effort")?),"-a","never","-c","default_permissions=\"panel-seat\"","-c","permissions.panel-seat.filesystem={\":root\"=\"deny\",\":minimal\"=\"read\",\":slash_tmp\"=\"deny\",\":workspace_roots\"=\"write\"}","-c","permissions.panel-seat.network.enabled=false"].map(str::to_owned));
            ("codex".to_owned(), "codex")
        }
        "fable" | "deepseek" => {
            let temp = Path::new("/private/tmp")
                .join(format!("panel-{}", io(fs::metadata(directory))?.ino()))
                .to_string_lossy()
                .into_owned();
            env.insert("TMPDIR".into(), temp.clone());
            env.insert("CLAUDE_CODE_TMPDIR".into(), temp);
            env.insert(
                "CLAUDE_ENV_FILE".into(),
                directory.join("panel-env.sh").to_string_lossy().into(),
            );
            args.extend(
                ["--model", s(seat, "model")?, "--effort", s(seat, "effort")?].map(str::to_owned),
            );
            if kind == "fable" {
                args.extend(
                    [
                        "--tools",
                        "Read,Glob,Grep,Write,Edit,Bash",
                        "--safe-mode",
                        "--disable-slash-commands",
                        "--setting-sources",
                        "",
                        "--settings",
                    ]
                    .map(str::to_owned),
                );
            } else {
                env.insert("PANEL_SEAT_CONFINED".into(), "1".into());
                args.extend(
                    [
                        "--bare",
                        "--disable-slash-commands",
                        "--setting-sources",
                        "",
                        "--settings",
                    ]
                    .map(str::to_owned),
                );
            }
            args.push(
                directory
                    .join("panel-settings.json")
                    .to_string_lossy()
                    .into(),
            );
            args.extend(["--permission-mode", "dontAsk"].map(str::to_owned));
            if kind == "deepseek" {
                args.extend(["--tools", "Read,Glob,Grep,Write,Edit,Bash"].map(str::to_owned));
            }
            (
                if kind == "fable" {
                    "claude".into()
                } else {
                    home.join(".local/cc-pinned-2.1.153/node_modules/.bin/claude")
                        .to_string_lossy()
                        .into()
                },
                if kind == "fable" {
                    "claude"
                } else {
                    "deepseek"
                },
            )
        }
        "gemini" => {
            args.extend(
                [
                    "--dangerously-skip-permissions",
                    "--model",
                    s(seat, "model")?,
                    "--effort",
                    s(seat, "effort")?,
                    "--sandbox",
                ]
                .map(str::to_owned),
            );
            ("agy".into(), "agy")
        }
        _ => return Err("unsupported seat kind".into()),
    };
    Ok(json!({"command":program,"args":args,"env":env,"trust":trust}))
}
pub(crate) fn start(args: &Args, record: &Value, seat: &Value) -> Result<String> {
    let home = home()?;
    let profile = profile(seat, &home)?;
    panel_trust::prepare(s(&profile, "trust")?, s(seat, "directory")?)?;
    let program = executable(s(&profile, "command")?)?;
    let batch = Path::new(s(record, "batch")?);
    let id = s(seat, "seat_id")?;
    let release = batch.join(format!("{id}-exec-release.json"));
    let plan = fresh(
        &batch.join(format!("{id}-exec-plan.json")),
        &json!({"prepared_ref":{"path":panel_dispatch::arg(args,"prepared")?,"sha256":panel_dispatch::arg(args,"sha256")?},"seat_id":id,"profile":profile,"program":program,"home":home,"release":release,"source_sha256":reference(&panel_dispatch::source()?)?["sha256"]}),
    )?;
    let request = read(&record["request_ref"])?;
    let source = panel_dispatch::source()?;
    let mut argv = vec![
        "new-window".to_owned(),
        "-d".into(),
        "-t".into(),
        format!("={}:", s(&request, "session")?),
        "-P".into(),
        "-F".into(),
        "#{pane_id}".into(),
        "-c".into(),
        s(seat, "directory")?.into(),
        "-n".into(),
        s(seat, "window")?.into(),
    ];
    for (key, value) in profile["env"].as_object().unwrap() {
        argv.extend(["-e".into(), format!("{key}={}", value.as_str().unwrap())]);
    }
    argv.extend([
        source.to_string_lossy().into(),
        "--panel-seat-exec".into(),
        s(&plan, "path")?.into(),
        s(&plan, "sha256")?.into(),
    ]);
    let pane = panel_dispatch::tmux(&argv.iter().map(String::as_str).collect::<Vec<_>>())?;
    let mut own_args = args.clone();
    own_args.insert("seat-id".into(), id.into());
    own_args.insert("pane".into(), pane.clone());
    let owned = panel_dispatch::own(&own_args)?;
    fresh(&release, &json!({"plan_ref":plan,"owned_ref":owned}))?;
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        let observed = panel_dispatch::exact_pane(s(&request, "session")?, s(seat, "window")?)?;
        let pid: u32 = s(&observed, "pid")?
            .parse()
            .map_err(|_| "invalid pane PID")?;
        let mut buffer = vec![0u8; 4096];
        let count =
            unsafe { proc_pidpath(pid as i32, buffer.as_mut_ptr().cast(), buffer.len() as u32) };
        if count > 0 {
            let end = buffer
                .iter()
                .position(|b| *b == 0)
                .unwrap_or(count as usize);
            let path = Path::new(std::str::from_utf8(&buffer[..end]).map_err(|e| e.to_string())?);
            if io(fs::canonicalize(path))? != source {
                break;
            }
        }
        check(
            Instant::now() < deadline,
            "CLI readiness deadline exhausted",
        )?;
        std::thread::sleep(Duration::from_millis(20));
    }
    Ok(format!("native seat {id} -> {}", program.display()))
}
unsafe extern "C" {
    fn proc_pidpath(pid: i32, buffer: *mut libc::c_void, size: u32) -> i32;
}
fn exec(args: &[String]) -> Result<()> {
    check(args.len() == 2, "seat exec requires plan path/hash")?;
    let plan_ref = json!({"path":args[0],"sha256":args[1]});
    let plan = read(&plan_ref)?;
    check(
        plan["source_sha256"] == reference(&panel_dispatch::source()?)?["sha256"],
        "seat exec source drift",
    )?;
    let prepared = read(&plan["prepared_ref"])?;
    let seat = a(&prepared, "seats")?
        .iter()
        .find(|s| s["seat_id"] == plan["seat_id"])
        .ok_or("seat exec identity absent")?;
    let profile = profile(seat, Path::new(s(&plan, "home")?))?;
    check(profile == plan["profile"], "seat exec profile drift")?;
    let program = Path::new(s(&plan, "program")?);
    check(
        program.is_absolute()
            && program.file_name().and_then(|n| n.to_str())
                == Some(if seat["transport"] == "astra" {
                    "codex"
                } else if seat["transport"] == "gemini" {
                    "agy"
                } else {
                    "claude"
                }),
        "seat exec program kind conflict",
    )?;
    let release = Path::new(s(&plan, "release")?);
    check(
        release
            == Path::new(s(&prepared, "batch")?)
                .join(format!("{}-exec-release.json", s(seat, "seat_id")?)),
        "seat exec release path conflict",
    )?;
    let deadline = Instant::now() + Duration::from_secs(30);
    while !release.exists() {
        check(
            Instant::now() < deadline,
            "seat ownership registration did not complete",
        )?;
        std::thread::sleep(Duration::from_millis(10));
    }
    let proof = decode(&path_bytes(release)?)?;
    check(proof["plan_ref"] == plan_ref, "seat release plan conflict")?;
    let owned = read(&proof["owned_ref"])?;
    check(
        a(&owned, "seats")?.iter().any(|s| {
            s["seat_id"] == seat["seat_id"]
                && s["pane"]["pane_id"] == std::env::var("TMUX_PANE").unwrap_or_default()
        }),
        "seat exec lacks own pane registration",
    )?;
    let mut command = Command::new(program);
    command
        .args(a(&profile, "args")?.iter().map(|v| v.as_str().unwrap()))
        .current_dir(s(seat, "directory")?);
    for (key, value) in profile["env"].as_object().unwrap() {
        command.env(key, value.as_str().unwrap());
    }
    if seat["transport"] == "deepseek" {
        let key = io(fs::read_to_string(
            Path::new(s(&plan, "home")?).join("desk/.secret/deepseek/api-key"),
        ))?;
        let model = "deepseek-flash";
        for key in [
            "ANTHROPIC_DEFAULT_OPUS_MODEL",
            "ANTHROPIC_DEFAULT_SONNET_MODEL",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL",
            "CLAUDE_CODE_SUBAGENT_MODEL",
        ] {
            command.env(key, model);
        }
        command
            .env("ANTHROPIC_BASE_URL", "https://api.deepseek.com/anthropic")
            .env("ANTHROPIC_AUTH_TOKEN", key.trim())
            .env("ANTHROPIC_API_KEY", key.trim())
            .env("ANTHROPIC_MODEL", format!("{model}[1m]"))
            .env("CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1")
            .env("CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK", "1");
    }
    let cap = std::env::var("AGENT_NPROC_CAP")
        .ok()
        .and_then(|s| s.parse::<u32>().ok())
        .filter(|n| *n > 0 && *n <= i32::MAX as u32)
        .unwrap_or(2000) as libc::rlim_t;
    let mut limit = libc::rlimit {
        rlim_cur: 0,
        rlim_max: 0,
    };
    if unsafe { libc::getrlimit(libc::RLIMIT_NPROC, &mut limit) } == 0 {
        let mut soft = limit;
        soft.rlim_cur = cap;
        if unsafe { libc::setrlimit(libc::RLIMIT_NPROC, &soft) } == 0 {
            limit = soft;
        }
        limit.rlim_max = cap;
        let _ = unsafe { libc::setrlimit(libc::RLIMIT_NPROC, &limit) };
    }
    Err(command.exec().to_string())
}
pub fn main_entry(args: &[String]) -> i32 {
    match exec(args) {
        Ok(()) => 0,
        Err(e) => {
            eprintln!("panel seat exec: {e}");
            1
        }
    }
}

#[cfg(test)]
#[path = "../tests/support/panel_launch.rs"]
mod tests;
