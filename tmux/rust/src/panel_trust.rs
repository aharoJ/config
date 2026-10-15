use serde_json::{Map, Value};
use std::fs::{self, DirBuilder, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{symlink, DirBuilderExt, MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

type Result<T> = std::result::Result<T, String>;
const USAGE: &str = "usage: panel-seat-trust <claude|deepseek|codex|agy> <seat-folder>";
const CODEX_CONFIG: &str = r#"model = "gpt-5.6-terra"
model_reasoning_effort = "max"
approval_policy = "never"
sandbox_mode = "danger-full-access"
check_for_update_on_startup = false

[skills]
include_instructions = false

[features]
plugins = false
remote_plugin = false
apps = false
skill_search = false
tool_suggest = false
memories = false

[notice]
hide_rate_limit_model_nudge = true

[tui]
alternate_screen = "never"
status_line = ["fast-mode", "model-with-reasoning", "current-dir", "context-used"]
screen_reader_detection_done = true

[tui.keymap.editor]
insert_newline = ["shift-enter", "alt-enter"]
"#;

fn io<T>(result: std::io::Result<T>) -> Result<T> {
    result.map_err(|e| e.to_string())
}

fn seat_name(path: &str) -> bool {
    let Some(body) = path
        .strip_prefix("/private/tmp/review-protocol-")
        .and_then(|s| s.strip_suffix("-cli"))
    else {
        return false;
    };
    let token = |s: &str| {
        !s.is_empty()
            && s.bytes()
                .all(|c| c.is_ascii_alphanumeric() || b"._-".contains(&c))
    };
    body.match_indices("-audit-r").any(|(offset, marker)| {
        let rest = &body[offset + marker.len()..];
        let Some((round, agent)) = rest.split_once("-agentic-") else {
            return false;
        };
        token(&body[..offset])
            && !round.is_empty()
            && round.bytes().all(|c| c.is_ascii_digit())
            && token(agent)
    })
}

fn seat_paths(raw: &str) -> Result<[String; 2]> {
    if !Path::new(raw).is_absolute() {
        return Err("seat path must be absolute".into());
    }
    let real = io(fs::canonicalize(raw))?;
    let real = real.to_str().ok_or("seat path is not UTF-8")?;
    if !seat_name(real) {
        return Err(format!("{real} is not an agentic audit seat folder"));
    }
    let info = io(fs::symlink_metadata(real))?;
    if !info.is_dir() {
        return Err(format!("{real} is not a real directory"));
    }
    if info.uid() != unsafe { libc::getuid() } || info.mode() & 0o077 != 0 {
        return Err(format!("{real} must be owned by you with mode 0700"));
    }
    Ok([
        real.into(),
        format!("/tmp{}", &real["/private/tmp".len()..]),
    ])
}

fn write_atomic(path: &Path, text: &str, mode: u32) -> Result<()> {
    let name = path
        .file_name()
        .ok_or("config filename missing")?
        .to_string_lossy();
    let tmp = path.with_file_name(format!(".{name}.panel-seat-trust.{}", std::process::id()));
    let mut file = io(OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(mode)
        .open(&tmp))?;
    io(file.write_all(text.as_bytes()))?;
    io(file.flush())?;
    io(file.sync_all())?;
    io(fs::rename(tmp, path))
}

struct DirLock(PathBuf);

impl DirLock {
    fn acquire(config: &Path) -> Result<Self> {
        let mut path = config.as_os_str().to_owned();
        path.push(".lock");
        let path = PathBuf::from(path);
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match fs::create_dir(&path) {
                Ok(()) => return Ok(Self(path)),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                    if Instant::now() > deadline {
                        return Err(format!("{} stayed locked for 5s", path.display()));
                    }
                    std::thread::sleep(Duration::from_millis(50));
                }
                Err(e) => return Err(e.to_string()),
            }
        }
    }
}

impl Drop for DirLock {
    fn drop(&mut self) {
        let _ = fs::remove_dir(&self.0);
    }
}

fn object(value: &mut Value) -> Result<&mut Map<String, Value>> {
    value
        .as_object_mut()
        .ok_or("config entry must be an object".into())
}

fn defaults<'a>(parent: &'a mut Value, key: &str, default: Value) -> Result<&'a mut Value> {
    Ok(object(parent)?.entry(key).or_insert(default))
}

fn read_json(path: &Path) -> Result<Value> {
    serde_json::from_str(&io(fs::read_to_string(path))?).map_err(|e| e.to_string())
}

fn save_json(path: &Path, value: &Value) -> Result<()> {
    let mode = io(fs::metadata(path))?.permissions().mode() & 0o7777;
    write_atomic(
        path,
        &serde_json::to_string_pretty(value).map_err(|e| e.to_string())?,
        mode,
    )
}

fn trust_claude(home: &Path, paths: &[String; 2]) -> Result<()> {
    let config = home.join(".claude.json");
    let _lock = DirLock::acquire(&config)?;
    let mut data = read_json(&config)?;
    let projects = defaults(&mut data, "projects", Value::Object(Map::new()))?;
    let mut changed = false;
    for path in paths {
        let entry = defaults(projects, path, Value::Object(Map::new()))?;
        if entry.get("hasTrustDialogAccepted") != Some(&Value::Bool(true)) {
            object(entry)?.insert("hasTrustDialogAccepted".into(), Value::Bool(true));
            changed = true;
        }
    }
    if changed {
        save_json(&config, &data)?;
    }
    Ok(())
}

fn trust_deepseek(home: &Path, paths: &[String; 2]) -> Result<()> {
    trust_claude(home, paths)?;
    let key = io(fs::read_to_string(
        home.join("desk/.secret/deepseek/api-key"),
    ))?;
    let key = key.trim();
    if key.chars().count() < 20 {
        return Err("DeepSeek key is missing or too short".into());
    }
    let tail: String = key
        .chars()
        .rev()
        .take(20)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    let tail = Value::String(tail);
    let config = home.join(".claude.json");
    let _lock = DirLock::acquire(&config)?;
    let mut data = read_json(&config)?;
    let responses = defaults(
        &mut data,
        "customApiKeyResponses",
        Value::Object(Map::new()),
    )?;
    let approved = defaults(responses, "approved", Value::Array(Vec::new()))?
        .as_array_mut()
        .ok_or("approved keys must be an array")?;
    let missing = !approved.contains(&tail);
    if missing {
        approved.push(tail.clone());
    }
    let rejected = defaults(responses, "rejected", Value::Array(Vec::new()))?
        .as_array_mut()
        .ok_or("rejected keys must be an array")?;
    let rejected_before = rejected.len();
    rejected.retain(|entry| entry != &tail);
    if missing || rejected.len() != rejected_before {
        save_json(&config, &data)?;
    }
    Ok(())
}

fn trust_agy(home: &Path, paths: &[String; 2]) -> Result<()> {
    let config = home.join(".gemini/antigravity-cli/settings.json");
    let _lock = DirLock::acquire(&config)?;
    let mut data = read_json(&config)?;
    let trusted = defaults(&mut data, "trustedWorkspaces", Value::Array(Vec::new()))?
        .as_array_mut()
        .ok_or("trusted workspaces must be an array")?;
    let before = trusted.len();
    for path in paths {
        let path = Value::String(path.clone());
        if !trusted.contains(&path) {
            trusted.push(path);
        }
    }
    if trusted.len() != before {
        save_json(&config, &data)?;
    }
    Ok(())
}

fn seed_codex_home(home: &Path) -> Result<PathBuf> {
    let panel_home = home.join(".local/state/codex-panel-home");
    io(DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&panel_home))?;
    io(fs::set_permissions(
        &panel_home,
        fs::Permissions::from_mode(0o700),
    ))?;
    let auth = panel_home.join("auth.json");
    let target = home.join(".codex/auth.json");
    if !fs::symlink_metadata(&auth).is_ok_and(|m| m.file_type().is_symlink()) {
        if auth.exists() {
            return Err(format!(
                "{} is a real file, not a link to {}; the shared login would diverge",
                auth.display(),
                target.display()
            ));
        }
        io(symlink(&target, &auth))?;
    } else if io(fs::read_link(&auth))? != target {
        return Err(format!(
            "{} does not link to {}",
            auth.display(),
            target.display()
        ));
    }
    if panel_home.join("AGENTS.md").exists() {
        return Err(format!(
            "{}/AGENTS.md exists; the panel home must carry no global instructions",
            panel_home.display()
        ));
    }
    let config = panel_home.join("config.toml");
    if !config.exists() {
        write_atomic(&config, CODEX_CONFIG, 0o600)?;
    }
    Ok(config)
}

fn trust_codex(home: &Path, paths: &[String; 2]) -> Result<()> {
    let config = seed_codex_home(home)?;
    let _lock = DirLock::acquire(&config)?;
    let text = io(fs::read_to_string(&config))?;
    let data: toml::Table = toml::from_str(&text).map_err(|e| e.to_string())?;
    for (table, key) in [
        ("skills", "include_instructions"),
        ("features", "plugins"),
        ("features", "remote_plugin"),
        ("features", "apps"),
        ("features", "skill_search"),
        ("features", "memories"),
    ] {
        if data
            .get(table)
            .and_then(|t| t.get(key))
            .and_then(toml::Value::as_bool)
            != Some(false)
        {
            return Err(format!(
                "{} must set [{table}] {key} = false",
                config.display()
            ));
        }
    }
    let projects = data
        .get("projects")
        .map(|p| p.as_table().ok_or("projects must be a table"))
        .transpose()?;
    let mut missing = Vec::new();
    for path in paths {
        let entry = projects.and_then(|p| p.get(path));
        if entry
            .and_then(|e| e.get("trust_level"))
            .and_then(toml::Value::as_str)
            != Some("trusted")
        {
            if entry.is_some() {
                return Err(format!(
                    "{} already has a non-trusted entry for {path}",
                    config.display()
                ));
            }
            missing.push(path);
        }
    }
    if !missing.is_empty() {
        let addition: String = missing
            .iter()
            .map(|path| format!("\n[projects.\"{path}\"]\ntrust_level = \"trusted\"\n"))
            .collect();
        let next = format!("{}\n{addition}", text.trim_end_matches('\n'));
        let _: toml::Table = toml::from_str(&next).map_err(|e| e.to_string())?;
        write_atomic(
            &config,
            &next,
            io(fs::metadata(&config))?.permissions().mode() & 0o7777,
        )?;
    }
    Ok(())
}

fn trust(kind: &str, home: &Path, paths: &[String; 2]) -> Result<()> {
    match kind {
        "claude" => trust_claude(home, paths),
        "deepseek" => trust_deepseek(home, paths),
        "codex" => trust_codex(home, paths),
        "agy" => trust_agy(home, paths),
        _ => Err("unsupported trust kind".into()),
    }
}

pub fn main_entry(args: &[String]) -> i32 {
    if args.len() != 2 || !["claude", "deepseek", "codex", "agy"].contains(&args[0].as_str()) {
        eprintln!("{USAGE}");
        return 2;
    }
    let result = (|| {
        let paths = seat_paths(&args[1])?;
        let home = std::env::var_os("HOME")
            .map(PathBuf::from)
            .map(Ok)
            .unwrap_or_else(crate::identity::account_home)?;
        trust(&args[0], &home, &paths)?;
        println!("panel-seat-trust: {} trusts {}", args[0], paths[0]);
        Ok::<_, String>(())
    })();
    match result {
        Ok(()) => 0,
        Err(message) => {
            eprintln!("panel-seat-trust: {message}; nothing was trusted");
            1
        }
    }
}

#[cfg(test)]
#[path = "../tests/support/panel_trust.rs"]
mod tests;
