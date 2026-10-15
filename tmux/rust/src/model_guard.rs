use regex::Regex;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

pub const MODELS: &[(&str, &str)] = &[
    (
        "GPT-6.1-Sol",
        "Latest workhorse model for coding and everyday work.",
    ),
    (
        "GPT-6-Astra",
        "Frontier intelligence for the most demanding work.",
    ),
    ("GPT-6-Sol", "Previous generation workhorse model."),
    ("GPT-6-Luna", "Fast and affordable model for easier tasks."),
    ("GPT-5.6-Sol", "Older generation workhorse model."),
    (
        "GPT-5.6-Terra",
        "Older balanced model for straightforward work.",
    ),
    ("GPT-5.6-Luna", "Older fast and efficient model."),
    ("GPT-5.5", "Legacy coding model."),
];
pub const EFFORTS: &[(&str, &str)] = &[
    ("Low", "Fast responses with lighter reasoning"),
    (
        "Medium",
        "Balances speed and reasoning depth for everyday tasks",
    ),
    ("High", "Greater reasoning depth for complex problems"),
    (
        "Extra high",
        "Extra high reasoning depth for complex problems",
    ),
    (
        "More reasoning…",
        "Max and Ultra consume usage limits faster",
    ),
];
pub const ADVANCED: &[(&str, &str)] = &[
    (
        "Max",
        "For difficult problems when quality matters more than speed · higher usage",
    ),
    (
        "Ultra",
        "For demanding work using multiple agents · highest usage",
    ),
];
pub const LEVELS: &[&str] = &["low", "medium", "high", "xhigh", "max", "ultra"];
pub fn re(pattern: &str) -> Regex {
    static CACHE: OnceLock<Mutex<HashMap<String, Regex>>> = OnceLock::new();
    CACHE
        .get_or_init(Mutex::default)
        .lock()
        .unwrap()
        .entry(pattern.into())
        .or_insert_with(|| Regex::new(pattern).unwrap())
        .clone()
}
pub fn visible(raw: &str) -> String {
    re(r"\x1b\[[0-?]*[ -/]*[@-~]")
        .replace_all(raw, "")
        .into_owned()
}
pub fn rows(capture: &str) -> Vec<String> {
    capture
        .lines()
        .map(|s| visible(s).trim_end().to_owned())
        .collect()
}
pub fn digest(capture: &str) -> String {
    format!(
        "{:x}",
        Sha256::digest(capture.trim_end_matches('\n').as_bytes())
    )
}
pub fn valid(model: &str, effort: &str) -> bool {
    MODELS.iter().any(|(m, _)| m.to_lowercase() == model)
        && LEVELS.contains(&effort)
        && !(model.ends_with("-luna") && effort == "ultra")
}
pub fn footer_parts(footer: &str) -> Option<(&str, &str, &str, &str)> {
    let fields: Vec<_> = footer.split(" · ").collect();
    if fields.len() != 3
        || !matches!(fields[0], "Fast on" | "Fast off")
        || !fields[2].starts_with(['~', '/'])
        || fields[2].contains('·')
    {
        return None;
    }
    let (model, effort) = fields[1].rsplit_once(' ')?;
    (MODELS.iter().any(|(m, _)| *m == model) && LEVELS.contains(&effort))
        .then_some((fields[0], model, effort, fields[2]))
}
pub fn footers(rows: &[String]) -> Vec<String> {
    let pattern = re(
        r"^  Fast (?:on|off) · [^·]+ · (?:~|/)[^·]+ · Context (?:100|[0-9]{1,2})% used(?: · Main \[default\])?(?: · ← for agents)?(?: {2,}⚠ [1-9][0-9]* warnings? · f2 to view)?$",
    );
    rows.iter()
        .filter(|s| pattern.is_match(s))
        .map(|s| s.trim().to_owned())
        .collect()
}
pub fn footer(capture: &str) -> Option<String> {
    let footers = footers(&rows(capture));
    (footers.len() == 1).then(|| footers[0].split(" · Context ").next().unwrap().into())
}
pub fn desired(capture: &str, model: &str, effort: &str) -> Option<String> {
    let (fast, _, _, cwd) = footer_parts(capture.trim())?;
    let model = MODELS.iter().find(|(m, _)| m.to_lowercase() == model)?.0;
    Some(format!("{fast} · {model} {effort} · {cwd}"))
}
pub fn highlighted(raw: &str) -> bool {
    let Some(end) = raw.find(['›', '»']) else {
        return false;
    };
    let mut prefix = &raw[..end];
    if prefix.is_empty() {
        return false;
    }
    let (mut bold, mut inverse, mut foreground, mut background) = (false, false, false, false);
    while !prefix.is_empty() {
        let Some(rest) = prefix.strip_prefix("\x1b[") else {
            return false;
        };
        let Some(end) = rest.find('m') else {
            return false;
        };
        let params = &rest[..end];
        if !params.bytes().all(|b| b.is_ascii_digit() || b == b';') {
            return false;
        }
        let values = if params.is_empty() {
            vec![0]
        } else {
            let Ok(values) = params
                .split(';')
                .map(str::parse::<u16>)
                .collect::<Result<Vec<_>, _>>()
            else {
                return false;
            };
            values
        };
        let mut i = 0;
        while i < values.len() {
            match values[i] {
                0 => {
                    bold = false;
                    inverse = false;
                    foreground = false;
                    background = false;
                }
                1 => bold = true,
                22 => bold = false,
                7 => inverse = true,
                27 => inverse = false,
                38 | 48 => {
                    let size = match values.get(i + 1) {
                        Some(2) => 3,
                        Some(5) => 1,
                        _ => return false,
                    };
                    let Some(colors) = values.get(i + 2..i + 2 + size) else {
                        return false;
                    };
                    if colors.iter().any(|v| *v > 255) {
                        return false;
                    }
                    if values[i] == 38 {
                        foreground = true;
                    } else {
                        background = true;
                    }
                    i += size + 1;
                }
                39 => foreground = false,
                49 => background = false,
                30..=37 | 90..=97 => foreground = true,
                40..=47 | 100..=107 => background = true,
                _ => return false,
            }
            i += 1;
        }
        prefix = &rest[end + 1..];
    }
    bold && (inverse || (foreground && background))
}
pub fn picker(capture: &str, kind: &str, expected: &str) -> Option<(usize, usize)> {
    let (_, model, effort, _) = footer_parts(expected)?;
    let luna = matches!(model, "GPT-6-Luna" | "GPT-5.6-Luna");
    let label = ["Low", "Medium", "High", "Extra high", "Max", "Ultra"]
        [LEVELS.iter().position(|s| *s == effort)?];
    let (title, mut choices, mut hint, desired, prelude) = match kind {
        "models" => (
            "  Select Model and Effort".into(),
            MODELS.to_vec(),
            "  enter select · esc back",
            model,
            vec![],
        ),
        "efforts" => (
            format!("  Select Reasoning Level for {model}"),
            EFFORTS.to_vec(),
            "  enter default · s session · esc back",
            if matches!(effort, "max" | "ultra") {
                "More reasoning…"
            } else {
                label
            },
            vec![],
        ),
        "advanced" => (
            "  Advanced Reasoning".into(),
            ADVANCED[..if luna { 1 } else { 2 }].to_vec(),
            "  enter default · s session · esc back",
            label,
            vec!["  ⚠ Consumes usage limits faster"],
        ),
        _ => return None,
    };
    if kind == "efforts" && luna {
        choices[4].1 = "Max consumes usage limits faster";
    }
    let rows = rows(capture);
    let raw: Vec<_> = capture.lines().collect();
    let starts: Vec<_> = rows
        .iter()
        .enumerate()
        .filter(|(_, s)| **s == title)
        .map(|(i, _)| i)
        .collect();
    if starts.len() != 1 {
        return None;
    }
    let tail: Vec<_> = rows
        .iter()
        .enumerate()
        .skip(starts[0])
        .filter(|(_, s)| !s.is_empty())
        .collect();
    if kind == "models" && tail.len() == MODELS.len() + 1 {
        choices.pop();
    }
    if tail.len() != choices.len() + prelude.len() + 2 {
        return None;
    }
    for (index, line) in prelude.iter().enumerate() {
        if tail[index + 1].1 != line {
            return None;
        }
    }
    let mut selected = None;
    let mut wanted = None;
    for (index, (label, desc)) in choices.iter().enumerate() {
        let (row_index, row) = tail[index + 1 + prelude.len()];
        let parsed = re(r"^(›| ) ([1-9][0-9]*)\. (.+?) {2,}(.+)$").captures(row)?;
        if parsed[2].parse::<usize>().ok()? != index + 1 || &parsed[4] != *desc {
            return None;
        }
        let actual =
            re(r" (?:\((?:current|default)\)|\(default\) \(current\))$").replace(&parsed[3], "");
        if actual != *label {
            return None;
        }
        if &parsed[1] == "›" {
            if selected.is_some() || !highlighted(raw[row_index]) {
                return None;
            }
            selected = Some(index);
        }
        if *label == desired {
            wanted = Some(index);
        }
    }
    let selected = selected?;
    if kind == "efforts" && choices[selected].0 == "More reasoning…" {
        hint = "  enter select · esc back";
    }
    let controls = tail.last()?.1.as_str();
    if controls != hint
        && !(hint == "  enter default · s session · esc back"
            && controls == "  enter apply · s session · esc back")
    {
        return None;
    }
    Some((selected, wanted?))
}
pub fn check(mode: &str, capture: &str, expected: &str) -> bool {
    let rows = rows(capture);
    let footers = footers(&rows);
    if matches!(mode, "models" | "efforts" | "advanced") {
        return picker(capture, mode, expected).is_some();
    }
    if mode == "supported-footer" {
        return footer_parts(expected).is_some();
    }
    if mode == "changed" {
        let Some((_, model, effort, _)) = footer_parts(expected) else {
            return false;
        };
        return rows.contains(&format!(
            "• Model changed to {} {effort} for this session only",
            model.to_lowercase()
        )) && footers.len() == 1
            && footers[0].starts_with(&format!("{expected} · Context "));
    }
    if mode == "settling-reset" {
        if footers.len() != 1 || !footers[0].contains(" · Context 0% used") {
            return false;
        }
        let current = footers[0].split(" · Context ").next().unwrap();
        let Some(previous) = footer_parts(expected) else {
            return false;
        };
        if current != expected || capture.lines().any(|s| crate::composer::row(s).is_err()) {
            return false;
        }
        let mut content: Vec<_> = rows
            .iter()
            .filter(|s| !s.is_empty())
            .map(String::as_str)
            .collect();
        if matches!(content.len(), 6 | 7) && content[2] == "  permissions: YOLO mode" {
            content.remove(2);
        }
        if content.len() == 5 {
            content.insert(2, "  Bring a question.");
        }
        if content.len() != 6 {
            return false;
        }
        let greeting = {
            [
                "  Bring a question.",
                "  Here for a quick fix or the extended edition?",
                "  This terminal has excellent conversational potential.",
            ]
            .contains(&content[2])
        };
        let tip = {
            ["  Tip: Use /title.", "  Tip: When worktree support is available, use /worktree to start or continue a conversation in a separate Git worktree.", "  Tip: Use the desktop app. Run codex app to open it. It installs automatically if needed."].contains(&content[3])
        };
        return re(r"^  >_ OpenAI Codex \(v[0-9]+\.[0-9]+\.[0-9]+\)$").is_match(content[0])
            && content[1] == format!("     {}", previous.3)
            && greeting
            && tip
            && content[4] == "› Ask Codex to do anything"
            && content[5].trim() == footers[0];
    }
    if mode == "model-slash" {
        let (command, description) = ("/model", "choose what model and reasoning effort to use");
        let starts: Vec<_> = rows
            .iter()
            .enumerate()
            .filter(|(_, s)| {
                ['›', '»']
                    .iter()
                    .any(|g| **s == format!("{g} {command}  {description}"))
            })
            .map(|(i, _)| i)
            .collect();
        if starts.len() != 1 || !highlighted(capture.lines().nth(starts[0]).unwrap()) {
            return false;
        }
        let tail: Vec<_> = rows[starts[0]..].iter().filter(|s| !s.is_empty()).collect();
        return tail.len() == 3
            && ['›', '»']
                .iter()
                .any(|g| *tail[1] == format!("{g} {command}"))
            && footers.len() == 1
            && tail[2].trim() == footers[0]
            && footers[0].split(" · Context ").next() == Some(expected);
    }
    false
}
pub fn escape_format(text: &str) -> String {
    text.replace('#', "##")
        .replace(',', "#,")
        .replace('}', "#}")
}
pub fn row_checks(rows: &[String], start: usize, end: usize) -> Option<String> {
    let checks: Vec<_> = (start..end)
        .filter(|i| !rows[*i].is_empty())
        .map(|i| {
            let pattern = rows[i]
                .chars()
                .flat_map(|c| {
                    if ".^$[]()|*+?{}\\".contains(c) {
                        vec!['\\', c]
                    } else {
                        vec![c]
                    }
                })
                .collect::<String>();
            format!("#{{==:#{{C/r:^{} *$}},{}}}", escape_format(&pattern), i + 1)
        })
        .collect();
    checks.into_iter().reduce(|a, b| format!("#{{&&:{a},{b}}}"))
}
pub fn tmux_rows(capture: &str, cwd: &str) -> Option<String> {
    let rows = rows(capture);
    let starts: Vec<_> = rows
        .iter()
        .enumerate()
        .filter(|(_, s)| {
            s.starts_with("› /new  ")
                || s.starts_with("› /model  ")
                || s.starts_with("» /model  ")
                || matches!(
                    s.as_str(),
                    "  Where should the new conversation run?"
                        | "  Select Model and Effort"
                        | "  Advanced Reasoning"
                )
                || s.starts_with("  Select Reasoning Level for ")
        })
        .map(|(i, _)| i)
        .collect();
    if starts.len() != 1 {
        return None;
    }
    Some(format!(
        "#{{&&:{},#{{==:#{{pane_current_path}},{}}}}}",
        row_checks(&rows, starts[0], rows.len())?,
        escape_format(cwd)
    ))
}
#[cfg(test)]
#[path = "../tests/support/model_guard.rs"]
mod tests;
