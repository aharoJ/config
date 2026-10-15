use crate::{panel_dispatch::*, panel_io::*, panel_trust};
use serde_json::{json, Value};
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

pub(crate) fn retire_trust(home: &Path, kind: &str, paths: &[String; 2]) -> Result<()> {
    let config = home.join(match kind {
        "fable" | "deepseek" => ".claude.json",
        "gemini" => ".gemini/antigravity-cli/settings.json",
        _ => ".local/state/codex-panel-home/config.toml",
    });
    let _lock = panel_trust::DirLock::acquire(&config)?;
    let bytes = path_bytes(&config)?;
    if kind == "astra" {
        let mut text = String::from_utf8(bytes).map_err(|e| e.to_string())?;
        for path in paths {
            let pattern = format!(
                "(?m)^\\[projects\\.\"{}\"\\]\\ntrust_level = \"trusted\"\\n?",
                regex::escape(path)
            );
            text = regex::Regex::new(&pattern)
                .map_err(|e| e.to_string())?
                .replace_all(&text, "")
                .into_owned();
        }
        let _: toml::Table = toml::from_str(&text).map_err(|e| e.to_string())?;
        panel_trust::write_atomic(&config, &text, io(fs::metadata(&config))?.mode() & 0o7777)
    } else {
        let mut value = decode(&bytes)?;
        if kind == "gemini" {
            let trusted = value
                .get("trustedWorkspaces")
                .map(|v| v.as_array().ok_or("trusted workspaces must be an array"))
                .transpose()?
                .cloned()
                .unwrap_or_default();
            let workspaces = Value::Array(
                trusted
                    .into_iter()
                    .filter(|p| !paths.iter().any(|path| p == path))
                    .collect(),
            );
            value
                .as_object_mut()
                .ok_or("settings must be an object")?
                .insert("trustedWorkspaces".into(), workspaces);
        } else if let Some(projects) = value.get_mut("projects") {
            let projects = projects
                .as_object_mut()
                .ok_or("projects must be an object")?;
            for path in paths {
                projects.remove(path);
            }
        }
        panel_trust::save_json(&config, &value)
    }
}
fn preserved(
    launch: &Value,
    launch_ref: &Value,
    collection: &Value,
    collection_ref: &Value,
) -> Result<()> {
    let request = read(&launch["request_ref"])?;
    check(
        request["authorized"] == true && launch["context"] == context(&request),
        "cleanup launch authority conflict",
    )?;
    check(
        [Some("collected"), Some("unadmitted-retention")].contains(&collection["phase"].as_str()),
        "cleanup requires a typed preserved collection receipt",
    )?;
    let preparation = read(&launch["prepared_ref"])?;
    let launcher = read(&request["launcher_ref"])?;
    let batch = Path::new(s(launch, "batch")?);
    check(
        preparation["phase"] == "prepared"
            && Path::new(s(&launch["prepared_ref"], "path")?) == batch.join("prepared.json")
            && launcher["adapter"] == launch["adapter"]
            && launcher["context"] == launch["context"],
        "cleanup candidate source/preparation provenance conflict",
    )?;
    check(
        [
            Some("launched"),
            Some("owned-launch"),
            Some("prestart-recovery"),
        ]
        .contains(&launch["phase"].as_str())
            && fields(launch, &["adapter", "context", "request_ref", "batch"])
                == fields(
                    &preparation,
                    &["adapter", "context", "request_ref", "batch"],
                ),
        "cleanup launch/prepared chain conflict",
    )?;
    let seats = a(launch, "seats")?;
    let prepared = a(&preparation, "seats")?;
    if launch["phase"] == "prestart-recovery" {
        let pending = read(&launch["trust_pending_ref"])?;
        check(
            pending["phase"] == "trust-pending"
                && fields(
                    &pending,
                    &["context", "request_ref", "prepared_ref", "adapter", "batch"],
                ) == fields(
                    launch,
                    &["context", "request_ref", "prepared_ref", "adapter", "batch"],
                )
                && prepared
                    .get(..seats.len())
                    .is_some_and(|p| pending["seats"] == json!(p))
                && !batch.join("starts-entered.json").exists(),
            "cleanup trust-pending provenance conflict",
        )?;
    }
    check(
        !seats.is_empty()
            && seats.len() <= prepared.len()
            && seats
                .iter()
                .zip(prepared)
                .all(|(seat, prepared)| subset(seat, prepared)),
        "cleanup owned seats differ from prepared prefix",
    )?;
    check(
        fields(collection, &["context", "adapter"]) == fields(launch, &["context", "adapter"]),
        "cleanup collection context/source conflict",
    )?;
    if collection["phase"] == "unadmitted-retention" {
        check(
            closed(
                collection,
                &[
                    "phase",
                    "launch_ref",
                    "native_index_ref",
                    "context",
                    "adapter",
                    "batch",
                    "request_ref",
                    "prepared_ref",
                    "seats",
                    "created_at",
                ],
            ) && fields(collection, &["batch", "request_ref", "prepared_ref"])
                == fields(launch, &["batch", "request_ref", "prepared_ref"]),
            "cleanup retention chain conflict",
        )?;
    } else {
        check(
            closed(
                collection,
                &[
                    "phase",
                    "context",
                    "launch_ref",
                    "native_index_ref",
                    "adapter",
                    "seats",
                    "admission_authority",
                ],
            ) && Path::new(s(collection_ref, "path")?) == batch.join("collected.json")
                && launch["phase"] == "launched",
            "cleanup collection provenance conflict",
        )?;
    }
    let index = read(&collection["native_index_ref"])?;
    let indexed = a(&index, "seats")?;
    check(
        index["context"] == launch["context"]
            && index["launch_ref"] == *launch_ref
            && indexed.len() == seats.len(),
        "cleanup preservation index conflict",
    )?;
    check(
        collection["launch_ref"] == *launch_ref,
        "preserved collection binding required before cleanup",
    )?;
    let collected = a(collection, "seats")?;
    check(
        collected.len() == seats.len(),
        "cleanup retained roster incomplete",
    )?;
    check(
        collected
            .iter()
            .zip(seats)
            .all(|(s, t)| s["seat_id"] == t["seat_id"]),
        "cleanup retained roster order changed",
    )?;
    for ((seat, source), owned) in collected.iter().zip(indexed).zip(seats) {
        check(
            fields(seat, &["attempt_id", "seat_id"]) == fields(source, &["attempt_id", "seat_id"])
                && fields(source, &["attempt_id", "seat_id"])
                    == fields(owned, &["attempt_id", "seat_id"]),
            "cleanup preservation attempt conflict",
        )?;
        let id = s(seat, "seat_id")?;
        if collection["phase"] == "collected" {
            check(
                !seat["native_session_ref"].is_null() && !seat["final_ref"].is_null(),
                "cleanup admitted preservation missing",
            )?;
            check(
                Path::new(s(&seat["native_session_ref"], "path")?)
                    == batch.join(format!("{id}-native.jsonl"))
                    && Path::new(s(&seat["final_ref"], "path")?)
                        == batch.join(format!("{id}-final.md")),
                "cleanup preservation outside owned batch",
            )?;
            check(
                read_bytes(&seat["native_session_ref"])? == read_bytes(&source["native_ref"])?,
                "cleanup native snapshot provenance conflict",
            )?;
            let admission = read(&seat["admission_ref"])?;
            check(
                fields(
                    &admission,
                    &["native_session_ref", "final_ref", "session_id"],
                ) == fields(seat, &["native_session_ref", "final_ref", "session_id"]),
                "cleanup final/admission conflict",
            )?;
        } else {
            check(
                closed(
                    seat,
                    &[
                        "seat_id",
                        "attempt_id",
                        "native_session_ref",
                        "final_ref",
                        "admitted",
                        "responding",
                        "raw_verdict",
                        "pass_floor_eligible",
                        "cause",
                        "findings",
                    ],
                ) && seat["admitted"] == false
                    && seat["responding"] == false
                    && seat["pass_floor_eligible"] == false
                    && seat["raw_verdict"].is_null()
                    && seat["final_ref"].is_null()
                    && seat["cause"] == source["cause"]
                    && seat["cause"].as_str().is_some_and(|s| !s.trim().is_empty()),
                "cleanup non-observation/retention cause missing",
            )?;
            if !source["native_ref"].is_null() {
                check(
                    !seat["native_session_ref"].is_null()
                        && Path::new(s(&seat["native_session_ref"], "path")?)
                            == batch.join(format!("{id}-unadmitted-native.jsonl"))
                        && read_bytes(&seat["native_session_ref"])?
                            == read_bytes(&source["native_ref"])?,
                    "cleanup retained native provenance conflict",
                )?;
            } else {
                check(
                    seat["native_session_ref"].is_null() && source["non_observation"] == true,
                    "cleanup missing native requires explicit non-observation",
                )?;
            }
        }
        for key in ["native_session_ref", "final_ref"] {
            if !seat[key].is_null() {
                read_bytes(&seat[key])?;
            }
        }
    }
    Ok(())
}
fn wait_closed(captured: &[Value]) {
    let deadline = Instant::now() + Duration::from_secs(3);
    while !remaining(captured).is_empty() && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(100));
    }
}
pub(crate) fn cleanup(args: &Args) -> Result<Value> {
    let launch_ref = authority(args, "launched", "sha256")?;
    let launch = read(&launch_ref)?;
    let request = read(&launch["request_ref"])?;
    let collection_ref = authority(args, "collected", "collected-sha256")?;
    let collection = read(&collection_ref)?;
    preserved(&launch, &launch_ref, &collection, &collection_ref)?;
    let session = s(&request, "session")?;
    let mut targets = Vec::new();
    for seat in a(&launch, "seats")? {
        let (pane, captured) = if seat["pane"].is_null() {
            check(
                launch["phase"] == "prestart-recovery"
                    && !panes(session)?
                        .iter()
                        .any(|p| p["window"] == seat["window"]),
                "no-pane recovery found an unverified live target",
            )?;
            (Value::Null, Vec::new())
        } else {
            let pane = exact_pane(session, s(seat, "window")?)?;
            check(
                fields(&pane, &["window_id", "pane_id", "pid"])
                    == fields(&seat["pane"], &["window_id", "pane_id", "pid"]),
                "cleanup target is not original owned pane",
            )?;
            let pid = s(&pane, "pid")?.parse().map_err(|_| "invalid pane PID")?;
            check(
                process_identity(pid)? == seat["pane_process"],
                "cleanup pane process was replaced",
            )?;
            let captured = custody(pid)?;
            (pane, captured)
        };
        let folder = PathBuf::from(s(seat, "directory")?);
        let paths = panel_trust::seat_paths(s(seat, "directory")?)?;
        let info = io(fs::metadata(&folder))?;
        check(
            info.uid() == unsafe { libc::getuid() } && info.mode() & 0o7777 == 0o700,
            "cleanup prepared folder ownership/mode conflict",
        )?;
        let mut temp = seat["temp"].clone();
        if pane.is_null() {
            let path = folder.join("panel-temp.json");
            let candidate = Path::new("/private/tmp").join(format!("panel-{}", info.ino()));
            temp = if path.exists() {
                decode(&path_bytes(&path)?)?
            } else if candidate.exists() {
                json!({"seat":folder,"temp":candidate})
            } else {
                Value::Null
            };
        }
        if !temp.is_null() {
            let path = Path::new(s(&temp, "temp")?);
            check(
                temp["seat"] == s(seat, "directory")?
                    && path == Path::new("/private/tmp").join(format!("panel-{}", info.ino())),
                "cleanup temp identity conflict",
            )?;
            let info = io(fs::symlink_metadata(path))?;
            check(
                info.is_dir()
                    && info.uid() == unsafe { libc::getuid() }
                    && info.mode() & 0o777 == 0o700
                    && path_bytes(&path.join(".panel-seat"))?
                        == (s(seat, "directory")?.to_owned() + "\n").as_bytes(),
                "cleanup ownership marker mismatch",
            )?;
        }
        targets.push((seat.clone(), pane, folder, temp, captured, paths));
    }
    let batch = Path::new(s(&launch, "batch")?);
    let mut retired = Vec::new();
    for (seat, pane, folder, temp, captured, paths) in targets {
        if !pane.is_null() {
            let current = exact_pane(session, s(&seat, "window")?)?;
            check(
                fields(&current, &["window_id", "pane_id", "pid"])
                    == fields(&pane, &["window_id", "pane_id", "pid"]),
                "cleanup target changed after preflight",
            )?;
        } else {
            check(
                !panes(session)?
                    .iter()
                    .any(|p| p["window"] == seat["window"]),
                "no-pane target appeared after preflight",
            )?;
        }
        let id = s(&seat, "seat_id")?;
        fresh(
            &batch.join(format!("{id}-cleanup-started.json")),
            &json!({"launch_ref":launch_ref,"custody":captured,"created_at":now()}),
        )?;
        if !pane.is_null() {
            tmux(&["kill-window", "-t", s(&pane, "window_id")?])?;
            check(
                !panes(session)?
                    .iter()
                    .any(|p| p["window_id"] == pane["window_id"]),
                "window closure unverified",
            )?;
        }
        wait_closed(&captured);
        for held in remaining(&captured) {
            if remaining(std::slice::from_ref(&held)).contains(&held) {
                let pid = held["pid"].as_u64().ok_or("captured PID missing")?;
                if unsafe { libc::kill(pid as i32, libc::SIGTERM) } != 0 {
                    return Err(std::io::Error::last_os_error().to_string());
                }
            }
        }
        wait_closed(&captured);
        check(
            remaining(&captured).is_empty(),
            "owned process closure unverified; temp retained",
        )?;
        if !temp.is_null() {
            let path = Path::new(s(&temp, "temp")?);
            check(
                path_bytes(&path.join(".panel-seat"))?
                    == (s(&seat, "directory")?.to_owned() + "\n").as_bytes()
                    && !io(fs::symlink_metadata(path))?.file_type().is_symlink(),
                "cleanup temp changed after preflight",
            )?;
            run(Command::new("trash").arg(path), None, 30)?;
        }
        retire_trust(&home()?, s(&seat, "transport")?, &paths)?;
        let row = json!({"seat_id":seat["seat_id"],"directory":folder,"temp":temp,"trust_retired":true,"window_closed":true,"pane_observed":!pane.is_null(),"captured_processes_closed":true,"custody":captured,"process_scope":"observed pane descendants; no universal OS containment guarantee"});
        fresh(&batch.join(format!("{id}-cleanup-done.json")), &row)?;
        retired.push(row);
    }
    fresh(
        Path::new(arg(args, "output")?),
        &json!({"phase":"cleaned","launch_ref":launch_ref,"collected_ref":collection_ref,"seats":retired,"seat_evidence":"retained, not deleted","created_at":now()}),
    )
}

#[cfg(test)]
#[path = "../tests/support/panel_cleanup.rs"]
mod tests;
