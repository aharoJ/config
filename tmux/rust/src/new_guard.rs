use regex::Regex;
use std::collections::HashMap;
use std::io::Read;
use std::sync::{LazyLock, Mutex};

pub(crate) fn re(pattern: &str) -> Regex {
    static CACHE: LazyLock<Mutex<HashMap<String, Regex>>> = LazyLock::new(Default::default);
    let mut cache = CACHE.lock().unwrap();
    cache
        .entry(pattern.into())
        .or_insert_with(|| Regex::new(pattern).unwrap())
        .clone()
}

const MODELS: &[(&str, &str)] = &[
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
const EFFORTS: &[(&str, &str)] = &[
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
const ADVANCED: &[(&str, &str)] = &[
    (
        "Max",
        "For difficult problems when quality matters more than speed · higher usage",
    ),
    (
        "Ultra",
        "For demanding work using multiple agents · highest usage",
    ),
];

pub(crate) fn rows(capture: &str) -> Vec<String> {
    crate::model_guard::rows(capture)
}

fn highlighted(raw: &str) -> bool {
    let raw = crate::model_guard::normalize(raw, true);
    let Some((prefix, _)) = raw.split_once('›') else {
        return false;
    };
    if !re(r"^(?:\x1b\[[0-9;]*m)+$").is_match(prefix) {
        return false;
    }
    let (mut bold, mut inverse, mut foreground, mut background) = (false, false, false, false);
    for code in re(r"\x1b\[([0-9;]*)m").captures_iter(prefix) {
        let values: Option<Vec<u16>> = if code[1].is_empty() {
            Some(vec![0])
        } else {
            code[1].split(';').map(|v| v.parse().ok()).collect()
        };
        let Some(values) = values else { return false };
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
                    if i + 2 + size > values.len()
                        || values[i + 2..i + 2 + size].iter().any(|v| *v > 255)
                    {
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
    }
    bold && (inverse || (foreground && background))
}

pub(crate) fn footer_parts(footer: &str) -> Option<(String, String, String, String)> {
    let pattern =
        re(r"^(Fast (?:on|off)) · (.+) (low|medium|high|xhigh|max|ultra) · ((?:~|/)[^·]+)$");
    let parts = pattern.captures(footer)?;
    MODELS
        .iter()
        .any(|(model, _)| *model == &parts[2])
        .then(|| {
            (
                parts[1].into(),
                parts[2].into(),
                parts[3].into(),
                parts[4].into(),
            )
        })
}

pub(crate) fn profile(model: &str, effort: &str) -> Option<(String, String)> {
    let model = MODELS
        .iter()
        .find(|(label, _)| label.to_lowercase() == model)?
        .0;
    if !["low", "medium", "high", "xhigh", "max", "ultra"].contains(&effort)
        || (matches!(model, "GPT-6-Luna" | "GPT-5.6-Luna") && effort == "ultra")
    {
        return None;
    }
    Some((model.into(), effort.into()))
}

pub(crate) fn desired(footer: &str, profile: &Option<(String, String)>) -> Option<String> {
    let Some((model, effort)) = profile else {
        return Some(footer.into());
    };
    let (fast, _, _, cwd) = footer_parts(footer)?;
    Some(format!("{fast} · {model} {effort} · {cwd}"))
}

fn picker(rows: &[String], raw: &[&str], kind: &str, expected: &str) -> Option<(usize, usize)> {
    let (_, model, effort, _) = footer_parts(expected)?;
    let label = match effort.as_str() {
        "low" => "Low",
        "medium" => "Medium",
        "high" => "High",
        "xhigh" => "Extra high",
        "max" => "Max",
        "ultra" => "Ultra",
        _ => return None,
    };
    let (title, mut choices, mut hint, desired, prelude): (String, &[_], &str, &str, &[_]) =
        match kind {
            "models" => (
                "  Select Model and Effort".into(),
                MODELS,
                "  enter select · esc back",
                &model,
                &[],
            ),
            "efforts" => (
                format!("  Select Reasoning Level for {model}"),
                EFFORTS,
                "  enter default · s session · esc back",
                if matches!(effort.as_str(), "max" | "ultra") {
                    "More reasoning…"
                } else {
                    label
                },
                &[],
            ),
            "advanced" => (
                "  Advanced Reasoning".into(),
                ADVANCED,
                "  enter default · s session · esc back",
                label,
                &["  ⚠ Consumes usage limits faster"],
            ),
            _ => return None,
        };
    let starts: Vec<_> = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| **row == title)
        .map(|(i, _)| i)
        .collect();
    if starts.len() != 1 {
        return None;
    }
    let tail: Vec<_> = rows
        .iter()
        .enumerate()
        .skip(starts[0])
        .filter(|(_, row)| !row.is_empty())
        .collect();
    if kind == "models" && tail.len() == MODELS.len() + 1 {
        choices = &MODELS[..MODELS.len() - 1];
    }
    if tail.len() != choices.len() + prelude.len() + 2
        || tail[1..1 + prelude.len()]
            .iter()
            .map(|(_, row)| row.as_str())
            .ne(prelude.iter().copied())
    {
        return None;
    }
    let mut selected = None;
    for (index, ((i, row), (label, description))) in tail[1 + prelude.len()..tail.len() - 1]
        .iter()
        .zip(choices)
        .enumerate()
    {
        let option = re(r"^(›| ) ([1-9][0-9]*)\. (.+?) {2,}(.+)$");
        let option = option.captures(row)?;
        if option[2].parse::<usize>().ok()? != index + 1 || &option[4] != *description {
            return None;
        }
        let plain =
            re(r" (?:\((?:current|default)\)|\(default\) \(current\))$").replace(&option[3], "");
        if plain != *label {
            return None;
        }
        if &option[1] == "›" {
            if selected.is_some() || !highlighted(raw[*i]) {
                return None;
            }
            selected = Some(index);
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
    Some((
        selected,
        choices.iter().position(|(label, _)| *label == desired)?,
    ))
}

pub(crate) fn escape_format(s: &str) -> String {
    s.replace('#', "##").replace(',', "#,").replace('}', "#}")
}

pub(crate) fn row_checks(rows: &[String], start: usize) -> Option<String> {
    let checks: Vec<_> = rows
        .iter()
        .enumerate()
        .skip(start)
        .filter(|(_, row)| !row.is_empty())
        .map(|(i, row)| {
            let pattern: String = row
                .chars()
                .flat_map(|c| {
                    if ".^$[]()|*+?{}\\".contains(c) {
                        vec!['\\', c]
                    } else {
                        vec![c]
                    }
                })
                .collect();
            format!(
                "#{{==:#{{C/r:^{pattern} *$}},{}}}",
                i + 1,
                pattern = escape_format(&pattern)
            )
        })
        .collect();
    checks.into_iter().reduce(|a, b| format!("#{{&&:{a},{b}}}"))
}

pub(crate) fn check(mode: &str, capture: &str, expected: &str) -> Option<String> {
    let raw: Vec<_> = capture.lines().collect();
    let rows = rows(capture);
    if mode == "tmux-rows" {
        let starts: Vec<_> = rows
            .iter()
            .enumerate()
            .filter(|(_, row)| {
                row.starts_with("› /new  ")
                    || row.starts_with("› /model  ")
                    || [
                        "  Where should the new conversation run?",
                        "  Select Model and Effort",
                        "  Advanced Reasoning",
                    ]
                    .contains(&row.as_str())
                    || row.starts_with("  Select Reasoning Level for ")
            })
            .map(|(i, _)| i)
            .collect();
        if starts.len() != 1 {
            return None;
        }
        return Some(format!(
            "#{{&&:{},#{{==:#{{pane_current_path}},{}}}}}",
            row_checks(&rows, starts[0])?,
            escape_format(expected)
        ));
    }
    let footer_re = re(
        r"^  Fast (?:on|off) · [^·]+ · (?:~|/)[^·]+ · Context (?:100|[0-9]{1,2})% used(?: · Main \[default\])?(?: · ← for agents| · [^·…]*…)?(?: {2,}⚠ [1-9][0-9]* warnings? · f2 to view)?$",
    );
    let footers: Vec<_> = rows
        .iter()
        .filter(|row| footer_re.is_match(row))
        .map(|row| row.trim())
        .collect();
    let yes = |valid: bool| valid.then(String::new);
    match mode {
        "busy" => {
            let start = rows
                .iter()
                .rposition(|row| row.starts_with("› "))
                .map_or(0, |i| i.saturating_sub(6));
            let status = re(
                r"^(?:• (?:Working|Waiting for|Compacting|Thinking)\b.*\(|\s+[1-9][0-9]* background terminals? running · |\s+tab to queue message|.*\s[0-9]{1,3}% context left\s*$)",
            );
            yes(rows[start..].iter().any(|row| status.is_match(row)))
        }
        "busy-slash" => yes(rows
            .iter()
            .filter(|row| row.as_str() == "› /new  start a new chat during a conversation")
            .count()
            == 1
            && rows.iter().filter(|row| row.as_str() == "› /new").count() == 1
            && check("busy", capture, "").is_some()),
        "footer" => {
            (footers.len() == 1).then(|| footers[0].split(" · Context ").next().unwrap().to_owned())
        }
        "supported-footer" => yes(footer_parts(expected).is_some()),
        "reset" => {
            if footers.len() != 1 || !footers[0].contains(" · Context 0% used") {
                return None;
            }
            let current = footer_parts(footers[0].split(" · Context ").next()?)?;
            let previous = footer_parts(expected)?;
            yes(current.0 == previous.0 && current.3 == previous.3)
        }
        "direct-reset" => {
            check("reset", capture, expected)?;
            let mut content: Vec<_> = rows
                .iter()
                .filter(|row| !row.is_empty())
                .map(String::as_str)
                .collect();
            let header = re(r"^  >_ OpenAI Codex \(v[0-9]+\.[0-9]+\.[0-9]+\)$");
            let headers: Vec<_> = content
                .iter()
                .enumerate()
                .filter(|(_, row)| header.is_match(row))
                .map(|(i, _)| i)
                .collect();
            if headers.len() != 1
                || content[..headers[0]]
                    .iter()
                    .any(|row| re(r"[•›─⚠]|esc to|Context|Codex").is_match(row))
            {
                return None;
            }
            content.drain(..headers[0]);
            let (_, model, effort, cwd) = footer_parts(expected)?;
            if content.len() > 2 && re(r"^  permissions: [^›•\x00-\x1f]+$").is_match(content[2])
            {
                content.remove(2);
            }
            if content.len() > 3
                && content[content.len() - 3]
                    == format!(
                        "• Model changed to {} {effort} for this session only",
                        model.to_lowercase()
                    )
            {
                content.remove(content.len() - 3);
            }
            if content.len() < 5 {
                return None;
            }
            let middle = &content[2..content.len() - 2];
            yes(middle
                .iter()
                .filter(|row| row.starts_with("  Tip: "))
                .count()
                == 1
                && middle
                    .iter()
                    .all(|row| re(r"^  [^›•\x00-\x1f]+$").is_match(row))
                && header.is_match(content[0])
                && content[1] == format!("     {cwd}")
                && content[content.len() - 2] == "› Ask Codex to do anything"
                && content.last()?.trim() == footers[0])
        }
        "fresh" => {
            yes(footers.len() == 1
                && footers[0].starts_with(&format!("{expected} · Context 0% used")))
        }
        "slash" | "model-slash" => {
            let (command, description) = if mode == "slash" {
                ("/new", "start a new chat during a conversation")
            } else {
                ("/model", "choose what model and reasoning effort to use")
            };
            let title = format!("› {command}  {description}");
            let starts: Vec<_> = rows
                .iter()
                .enumerate()
                .filter(|(_, row)| **row == title)
                .map(|(i, _)| i)
                .collect();
            if starts.len() != 1 || !highlighted(raw[starts[0]]) {
                return None;
            }
            let tail: Vec<_> = rows[starts[0]..]
                .iter()
                .filter(|row| !row.is_empty())
                .map(String::as_str)
                .collect();
            yes(tail.len() == 3
                && tail[1] == format!("› {command}")
                && footers.len() == 1
                && tail[2].trim() == footers[0]
                && footers[0].split(" · Context ").next()? == expected)
        }
        "menu" => {
            let title = "  Where should the new conversation run?";
            let starts: Vec<_> = rows
                .iter()
                .enumerate()
                .filter(|(_, row)| row.as_str() == title)
                .map(|(i, _)| i)
                .collect();
            if starts.len() != 1 {
                return None;
            }
            let tail: Vec<_> = rows[starts[0]..]
                .iter()
                .filter(|row| !row.is_empty())
                .map(String::as_str)
                .collect();
            let legacy = [
                title,
                "› 1. Current checkout  Keep using the current working directory",
                "  2. New worktree      Create an isolated managed checkout",
                "  enter select · esc back",
            ];
            let current = [
                title,
                "› 1. Use current Git worktree  Keep using the current working directory",
                "  2. Create new Git worktree   Create a separate checkout of this repository in another directory",
                "  enter select · esc back",
            ];
            yes((tail == legacy || tail == current)
                && raw[starts[0]..]
                    .iter()
                    .find(|row| row.contains("› 1. "))
                    .is_some_and(|row| highlighted(row)))
        }
        kind => {
            let (selected, desired) = picker(
                &rows,
                &raw,
                kind.strip_prefix("navigate-").unwrap_or(kind),
                expected,
            )?;
            Some(if kind.starts_with("navigate-") {
                format!("{selected}:{desired}")
            } else {
                String::new()
            })
        }
    }
}

pub(crate) fn entry(args: &[String]) -> i32 {
    let Some(mode) = args.first() else { return 1 };
    let mut capture = String::new();
    if std::io::stdin().read_to_string(&mut capture).is_err() {
        return 1;
    }
    match check(mode, &capture, args.get(1).map_or("", String::as_str)) {
        Some(output) => {
            if !output.is_empty() {
                println!("{output}");
            }
            0
        }
        None => 1,
    }
}

#[cfg(test)]
#[path = "../tests/support/codex_new.rs"]
mod tests;
