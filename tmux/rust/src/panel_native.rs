use crate::panel_io::*;
use regex::Regex;
use serde_json::{json, Map, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Component, Path, PathBuf};

pub fn resolve(path: &Path) -> Result<PathBuf> {
    if let Ok(real) = std::fs::canonicalize(path) {
        return Ok(real);
    }
    let absolute = if path.is_absolute() {
        path.to_owned()
    } else {
        io(std::env::current_dir())?.join(path)
    };
    let mut result = PathBuf::new();
    for part in absolute.components() {
        match part {
            Component::ParentDir => {
                result.pop();
            }
            Component::CurDir => (),
            other => result.push(other.as_os_str()),
        }
    }
    let mut base = result.clone();
    let mut tail = Vec::new();
    while !base.exists() {
        tail.push(base.file_name().ok_or("unresolvable path")?.to_owned());
        check(base.pop(), "unresolvable path")?;
    }
    let mut real = io(std::fs::canonicalize(base))?;
    for name in tail.into_iter().rev() {
        real.push(name);
    }
    Ok(real)
}
fn re(pattern: &str) -> Regex {
    Regex::new(pattern).unwrap()
}
fn text_blocks(value: &Value, types: &[&str]) -> Result<String> {
    if let Some(s) = value.as_str() {
        return Ok(s.into());
    }
    let parts = value.as_array().ok_or("unsupported text envelope")?;
    parts
        .iter()
        .map(|v| {
            check(types.contains(&s(v, "type")?), "unsupported text envelope")?;
            Ok(s(v, "text")?.to_owned())
        })
        .collect::<Result<Vec<_>>>()
        .map(|v| v.join("\n"))
}
fn loaded(value: &Value) -> bool {
    match value {
        Value::Object(m) => {
            if m.get("agents_md").is_some_and(truth) {
                return true;
            }
            if let Some(Value::Object(attachment)) = m.get("attachment") {
                let kind = attachment
                    .get("type")
                    .or_else(|| attachment.get("kind"))
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_lowercase();
                if kind != "prompt_snapshot"
                    && (kind == "skill_listing"
                        || kind.contains("memory")
                        || kind.contains("automem"))
                {
                    return true;
                }
            }
            m.values().any(loaded)
        }
        Value::Array(a) => a.iter().any(loaded),
        _ => false,
    }
}
fn truth(v: &Value) -> bool {
    match v {
        Value::Null => false,
        Value::Bool(b) => *b,
        Value::String(s) => !s.is_empty(),
        Value::Array(a) => !a.is_empty(),
        Value::Object(m) => !m.is_empty(),
        Value::Number(n) => n.as_f64() != Some(0.0),
    }
}
pub fn wrapped(value: &Value) -> Option<Value> {
    let value = value.as_str()?;
    let first = re(
        r"^\s*const ([A-Za-z_]\w*) = await tools\.exec_command\((\{[^\n]+\})\);\s*text\(([A-Za-z_]\w*)\);\s*$",
    );
    let second = re(r"^\s*text\(await tools\.exec_command\((\{[^\n]+\})\)\);?\s*$");
    let raw = if let Some(c) = first.captures(value) {
        if c[1] != c[3] {
            return None;
        }
        c[2].to_owned()
    } else {
        second.captures(value)?.get(1)?.as_str().to_owned()
    };
    let normalized =
        re(r"\b(cmd|max_output_tokens|yield_time_ms|workdir)\s*:").replace_all(&raw, "\"$1\":");
    let argument = decode(normalized.as_bytes()).ok()?;
    let m = argument.as_object()?;
    (m.keys()
        .all(|k| ["cmd", "max_output_tokens", "yield_time_ms", "workdir"].contains(&k.as_str()))
        && argument["cmd"].is_string())
    .then_some(argument)
}
pub fn codex_result(value: &Value) -> Result<(String, bool)> {
    let blocks = if value.is_array() {
        value.as_array().unwrap().clone()
    } else {
        vec![json!({"type":"input_text","text":value})]
    };
    check(
        blocks
            .iter()
            .all(|b| b["type"] == "input_text" && b["text"].is_string()),
        "unsupported Codex output envelope",
    )?;
    let text = blocks
        .iter()
        .map(|b| b["text"].as_str().unwrap())
        .collect::<Vec<_>>()
        .join("\n");
    let candidates: Vec<_> = blocks
        .iter()
        .filter_map(|b| decode(b["text"].as_str().unwrap().as_bytes()).ok())
        .filter(|v| v["exit_code"].as_i64().is_some() && v["output"].is_string())
        .collect();
    if candidates.len() > 1 {
        return Ok((text, true));
    }
    if candidates.len() == 1 {
        return Ok((
            s(&candidates[0], "output")?.into(),
            candidates[0]["exit_code"] != 0,
        ));
    }
    let exits: Vec<_> = re(r"(?m)^Process exited with code (-?[0-9]+)\s*$")
        .captures_iter(&text)
        .map(|c| c[1].to_owned())
        .collect();
    let failed = exits.len() != 1 || exits[0] != "0";
    Ok((text, failed))
}
pub fn inspect(data: &[u8], fmt: &str, seat: &Value) -> Result<Value> {
    check(data.ends_with(b"\n"), "incomplete LF native record")?;
    let raw = &data[..data.len() - 1];
    let rows = raw
        .split(|b| *b == b'\n')
        .map(decode)
        .collect::<Result<Vec<_>>>()?;
    check(
        !rows.is_empty() && rows.len() <= 100000,
        "empty/oversized native session",
    )?;
    let (mut sessions, mut models, mut efforts, mut cwds) = (
        BTreeSet::new(),
        BTreeSet::new(),
        BTreeSet::new(),
        BTreeSet::new(),
    );
    let (mut starts, mut timestamps, mut finals, mut gaps) =
        (Vec::new(), Vec::new(), Vec::new(), Vec::<String>::new());
    let (mut calls, mut results) = (
        BTreeMap::<String, Value>::new(),
        BTreeMap::<String, Value>::new(),
    );
    let mut call_order = Vec::new();
    for (index, row) in rows.iter().enumerate() {
        let line = index + 1;
        check(
            !loaded(row),
            "unapproved native instructions/memory attachment",
        )?;
        let payload = &row["payload"];
        let message = &row["message"];
        if let Some(timestamp) = row["timestamp"]
            .as_str()
            .filter(|s| !s.is_empty())
            .or_else(|| payload["timestamp"].as_str())
        {
            timestamps.push(instant(timestamp)?);
        }
        let session = if row["type"] == "session_meta" {
            payload.get("id").or_else(|| payload.get("session_id"))
        } else {
            row.get("sessionId")
        };
        if let Some(id) = session.filter(|v| truth(v)) {
            sessions.insert(
                id.as_str()
                    .ok_or("invalid native session identity")?
                    .to_owned(),
            );
        }
        let cwd = row["cwd"]
            .as_str()
            .filter(|s| !s.is_empty())
            .or_else(|| payload["cwd"].as_str());
        if let Some(cwd) = cwd.filter(|s| !s.is_empty()) {
            cwds.insert(cwd.to_owned());
        }
        if row["type"] == "turn_context" {
            if let Some(model) = payload["model"].as_str().filter(|s| !s.is_empty()) {
                models.insert(model.to_owned());
            }
            if let Some(effort) = payload["effort"].as_str().filter(|s| !s.is_empty()) {
                efforts.insert(effort.to_owned());
            }
        }
        if let Some(model) = message["model"].as_str().filter(|s| !s.is_empty()) {
            models.insert(model.to_owned());
        }
        if row["type"] == "user" && message["role"] == "user" {
            if let Some(text) = message["content"].as_str() {
                starts.push((line, text.trim().to_owned()));
            } else if let Some(parts) = message["content"].as_array() {
                check(
                    !parts.is_empty()
                        && parts.iter().all(|p| {
                            p.is_object()
                                && [Some("text"), Some("tool_result")].contains(&p["type"].as_str())
                        }),
                    "unknown/non-text external native user input",
                )?;
                let texts: Vec<_> = parts
                    .iter()
                    .filter(|p| p["type"] == "text")
                    .cloned()
                    .collect();
                if !texts.is_empty() {
                    starts.push((
                        line,
                        text_blocks(&texts.into(), &["text"])?.trim().to_owned(),
                    ));
                }
                for part in parts.iter().filter(|p| p["type"] == "tool_result") {
                    let id = part["tool_use_id"].as_str().unwrap_or("null").to_owned();
                    check(!results.contains_key(&id), "duplicate native result ID")?;
                    let (output, error) = match text_blocks(
                        part.get("content").unwrap_or(&Value::String(String::new())),
                        &["text"],
                    ) {
                        Ok(text) => (
                            text,
                            part.get("is_error").cloned().unwrap_or(Value::Bool(false)),
                        ),
                        Err(_) => {
                            gaps.push(format!("unsupported native result envelope {id}"));
                            (String::new(), Value::Null)
                        }
                    };
                    results.insert(id, json!({"line":line,"output":output,"error":error}));
                }
            } else {
                return Err("malformed external native user input".into());
            }
        }
        if row["type"] == "response_item" && payload["role"] == "user" {
            let value = text_blocks(
                payload.get("content").unwrap_or(&json!([])),
                &["input_text"],
            )?;
            if !starts.is_empty()
                || !re(r"(?s)^<environment_context>.*?</environment_context>$")
                    .is_match(value.trim())
            {
                starts.push((line, value.trim().to_owned()));
            }
        }
        if let Some(parts) = message["content"].as_array() {
            for part in parts.iter().filter(|p| p["type"] == "tool_use") {
                let id = s(part, "id")?;
                check(
                    !id.is_empty() && !calls.contains_key(id),
                    "duplicate/missing native call ID",
                )?;
                call_order.push(id.to_owned());
                calls.insert(id.into(),json!({"line":line,"name":part["name"],"args":part["input"],"cwd":cwd.unwrap_or(s(seat,"directory")?)}));
            }
        }
        if row["type"] == "response_item"
            && [Some("function_call"), Some("custom_tool_call")].contains(&payload["type"].as_str())
        {
            let id = s(payload, "call_id")?;
            check(
                !id.is_empty() && !calls.contains_key(id),
                "duplicate/missing native call ID",
            )?;
            call_order.push(id.to_owned());
            let mut argument = payload
                .get("arguments")
                .or_else(|| payload.get("input"))
                .cloned()
                .unwrap_or(Value::Null);
            if let Some(raw) = argument.as_str() {
                if let Ok(parsed) = decode(raw.as_bytes()) {
                    argument = parsed;
                }
            }
            let original = payload["name"].clone();
            let wrapper = if [Some("exec"), Some("functions.exec")].contains(&original.as_str()) {
                wrapped(&argument)
            } else {
                None
            };
            calls.insert(id.into(),json!({"line":line,"name":if wrapper.is_some(){Value::String("exec_command".into())}else{original.clone()},"args":wrapper.unwrap_or(argument),"original_name":original,"cwd":cwd.unwrap_or(s(seat,"directory")?)}));
        }
        if row["type"] == "response_item"
            && [
                Some("function_call_output"),
                Some("custom_tool_call_output"),
            ]
            .contains(&payload["type"].as_str())
        {
            let id = payload["call_id"].as_str().unwrap_or("null").to_owned();
            check(!results.contains_key(&id), "duplicate native result ID")?;
            let (output, error) = match codex_result(
                payload
                    .get("output")
                    .unwrap_or(&Value::String(String::new())),
            ) {
                Ok((text, failed)) => (
                    text,
                    Value::Bool(payload.get("is_error").is_some_and(truth) || failed),
                ),
                Err(_) => {
                    gaps.push(format!("unsupported native result envelope {id}"));
                    (String::new(), Value::Null)
                }
            };
            results.insert(id, json!({"line":line,"output":output,"error":error}));
        }
        if fmt == "claude-jsonl"
            && row["type"] == "assistant"
            && message["role"] == "assistant"
            && message["stop_reason"] == "end_turn"
            && message["content"]
                .as_array()
                .is_some_and(|a| !a.is_empty() && a.iter().all(|p| p["type"] == "text"))
        {
            finals.push((line, text_blocks(&message["content"], &["text"])?));
        }
        if fmt == "codex-jsonl"
            && row["type"] == "response_item"
            && payload["type"] == "message"
            && payload["role"] == "assistant"
            && (payload["channel"] == "final" || payload["phase"] == "final_answer")
        {
            finals.push((line, text_blocks(&payload["content"], &["output_text"])?));
        }
        if fmt == "agy-jsonl" {
            if row["source"] == "USER_EXPLICIT" && row["type"] == "USER_INPUT" {
                let value = row["content"].as_str().unwrap_or("");
                let pattern = re(
                    r"(?s)^<USER_REQUEST>\n(.*?)\n</USER_REQUEST>(?:\n<ADDITIONAL_METADATA>\n.*?\n</ADDITIONAL_METADATA>)?(?:\n<USER_SETTINGS_CHANGE>\n.*?\n</USER_SETTINGS_CHANGE>)?\s*$",
                );
                let text = pattern
                    .captures(value)
                    .map(|c| c[1].to_owned())
                    .unwrap_or_else(|| value.into());
                starts.push((line, text.trim().into()));
            }
            if row["source"] == "MODEL"
                && row["type"] == "PLANNER_RESPONSE"
                && row["status"] == "DONE"
                && !row.get("tool_calls").is_some_and(truth)
            {
                finals.push((line, s(row, "content")?.into()));
            }
            gaps.push("Agy effective identity and action linkage are unqualified".into());
        }
    }
    check(
        sessions.len() == 1,
        "native session identity missing or mixed",
    )?;
    let folder = Path::new(s(seat, "directory")?);
    check(
        !cwds.is_empty()
            && cwds
                .iter()
                .all(|cwd| resolve(Path::new(cwd)).is_ok_and(|p| p.starts_with(folder))),
        "native cwd missing or outside seat",
    )?;
    check(
        starts.len() == 1 && starts[0].1 == s(&seat["delivery"], "native_start")?,
        "external native input differs from one exact Start",
    )?;
    let start_line = starts[0].0 as u64;
    check(
        calls
            .values()
            .all(|c| c["line"].as_u64().is_some_and(|l| l > start_line)),
        "native actions precede Start",
    )?;
    if let Some(prepared) = seat["prepared_at"].as_str().filter(|s| !s.is_empty()) {
        let prepared = instant(prepared)?;
        check(
            !timestamps.is_empty() && timestamps.iter().all(|t| *t >= prepared),
            "native session predates fresh preparation or lacks timestamps",
        )?;
    }
    check(
        finals.len() == 1 && !finals[0].1.trim().is_empty(),
        "one unambiguous completed native final required",
    )?;
    let (final_line, final_text) = finals.pop().unwrap();
    check(
        final_line as u64 > start_line,
        "native final precedes Start",
    )?;
    check(
        calls
            .values()
            .all(|c| c["line"].as_u64().is_some_and(|l| l <= final_line as u64)),
        "selected final precedes later tool calls",
    )?;
    check(
        results.iter().all(|(id, r)| {
            calls
                .get(id)
                .is_some_and(|c| c["line"].as_u64() < r["line"].as_u64())
        }),
        "orphan/out-of-order tool result",
    )?;
    check(
        models.is_empty() || (models.len() == 1 && models.contains(s(seat, "model")?)),
        "requested/effective native model mismatch",
    )?;
    if models.is_empty() {
        gaps.push(
            "effective model unavailable; no identity/family claim from requested label".into(),
        );
    }
    check(
        efforts.is_empty() || (efforts.len() == 1 && efforts.contains(s(seat, "effort")?)),
        "native effort mismatch",
    )?;
    let mut reads = Map::new();
    let mut actions = Vec::new();
    let numbering = re(r"(?m)^[ \t]*\d+(?:→|\t)");
    for id in call_order {
        let call = calls.remove(&id).ok_or("native call disappeared")?;
        let argument = &call["args"];
        let result = results.get(&id);
        actions.push(merge(call.clone(), json!({"id":id,"result":result})));
        let name = call["name"].as_str().unwrap_or("");
        let mut target = if name == "Read" {
            argument["file_path"].as_str().map(str::to_owned)
        } else {
            None
        };
        let command = argument
            .get("command")
            .or_else(|| argument.get("cmd"))
            .and_then(Value::as_str);
        if ["Bash", "exec_command", "functions.exec_command"].contains(&name) {
            if let Some(command) =
                command.filter(|c| re(r"^(?:/bin/)?cat (?:PROMPT\.md|intake\.md)$").is_match(c))
            {
                target = command.split_once(' ').map(|(_, p)| p.into());
            }
        }
        if let (Some(target), Some(result)) = (target, result) {
            if result["error"] == false
                && result["line"]
                    .as_u64()
                    .is_some_and(|l| l < final_line as u64)
            {
                let base = argument
                    .get("workdir")
                    .or_else(|| argument.get("cwd"))
                    .and_then(Value::as_str)
                    .unwrap_or(s(&call, "cwd")?);
                let path = Path::new(&target);
                let path = resolve(&if path.is_absolute() {
                    path.to_owned()
                } else {
                    Path::new(base).join(path)
                })?;
                for (input, reference) in seat["inputs"].as_object().ok_or("missing inputs")? {
                    let mut expected =
                        String::from_utf8(read_bytes(reference)?).map_err(|e| e.to_string())?;
                    let mut coverage = "complete literal output";
                    if input == "intake.md" && name == "Read" && argument.get("limit").is_some() {
                        let offset = argument.get("offset").and_then(Value::as_u64).unwrap_or(
                            if argument.get("offset").is_none() {
                                1
                            } else {
                                0
                            },
                        );
                        let limit = argument["limit"].as_u64().unwrap_or(0);
                        check(offset > 0 && limit > 0, "invalid native read range")?;
                        expected = expected
                            .split('\n')
                            .skip((offset - 1) as usize)
                            .take(limit as usize)
                            .collect::<Vec<_>>()
                            .join("\n");
                        coverage = "explicit partial native read; no whole-file claim";
                    }
                    let output = s(result, "output")?;
                    let wanted = expected.trim_end_matches('\n');
                    if path == Path::new(s(reference, "path")?)
                        && !expected.trim().is_empty()
                        && (output.contains(wanted)
                            || numbering.replace_all(output, "").contains(wanted))
                    {
                        reads.insert(input.clone(),json!({"call_id":id,"call_line":call["line"],"result_line":result["line"],"coverage":coverage}));
                        if coverage.starts_with("explicit partial") {
                            gaps.push("only a bound partial intake read is proven; account limitations require review".into());
                        }
                    }
                }
            }
        }
        if result.is_none()
            || !argument.is_object()
            || !["Read", "Bash", "exec_command", "functions.exec_command"].contains(&name)
        {
            gaps.push(format!("unsupported/pending action {id}"));
        }
    }
    check(
        reads.len() == 2 && reads.contains_key("PROMPT.md") && reads.contains_key("intake.md"),
        "complete matched native prompt/intake reads missing",
    )?;
    let verdicts: Vec<_> = re(r"(?m)^Verdict: (PASS_WITH_MONITORING|PASS|FAIL)\s*$")
        .captures_iter(&final_text)
        .map(|c| c[1].to_owned())
        .collect();
    if verdicts.len() != 1 {
        gaps.push("native verdict grammar requires independently bound interpretation".into());
    }
    gaps.sort();
    gaps.dedup();
    Ok(
        json!({"session_id":sessions.first(),"model":models.first(),"effort":efforts.first(),"final_line":final_line,"final_text":final_text,"raw_verdict":if verdicts.len()==1{verdicts.first()}else{None},"reads":reads,"actions":actions,"limitations":gaps,"absence_qualified":false}),
    )
}

#[cfg(test)]
#[path = "../tests/support/panel_native.rs"]
mod tests;
