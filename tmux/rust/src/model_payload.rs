use crate::{composer, model_guard as guard, runtime};
use std::path::Path;
use unicode_general_category::{get_general_category, GeneralCategory as G};
use unicode_width::UnicodeWidthChar;

pub fn printable(text: &str) -> bool {
    !text.is_empty()
        && !text.chars().any(|c| {
            matches!(
                get_general_category(c),
                G::Control | G::Format | G::Surrogate | G::LineSeparator | G::ParagraphSeparator
            )
        })
}
pub fn cells(text: &str) -> Option<usize> {
    text.chars().try_fold(0, |sum, c| {
        if get_general_category(c) == G::Unassigned || c == '\u{fe0f}' {
            return None;
        }
        Some(
            sum + if unicode_normalization::char::canonical_combining_class(c) != 0 {
                0
            } else {
                c.width().unwrap_or(1).max(1)
            },
        )
    })
}
pub fn input(capture: &str, glyph: char, x: usize, y: usize, width: usize) -> i32 {
    if glyph == '»' {
        return 1;
    }
    match composer::classify(capture, glyph, x, y, width) {
        composer::Composer::EmptyCandidate => 0,
        composer::Composer::Draft => 1,
        composer::Composer::Unrecognized => {
            if guard::rows(capture)
                .iter()
                .any(|s| s.trim_start().starts_with(glyph))
            {
                1
            } else {
                2
            }
        }
    }
}
pub fn busy(capture: &str, glyph: char, y: usize) -> bool {
    if !matches!(glyph, '›' | '»') {
        return false;
    }
    let rows = guard::rows(capture);
    rows.get(y).is_some_and(|r|r.trim_start().starts_with(glyph)) && rows[y.saturating_sub(4)..y].iter().rev().find(|r|!r.trim().is_empty()).is_some_and(|r|guard::re(r"^• Working \((?:[0-9]+h )?(?:[0-9]+m )?[0-9]+s [•·] esc to interrupt\)(?: · [1-9][0-9]* background terminals? running · /ps to view · /stop to close)?$").is_match(r.trim()))
}
fn file(path: &str) -> Option<String> {
    std::fs::read_to_string(path).ok()
}
fn join(words: &[String]) -> String {
    words
        .iter()
        .map(|s| runtime::quote(s))
        .collect::<Vec<_>>()
        .join(" ")
}
pub fn nested(pane: &str, guarded: &str, deliver: &str, blocked: &str) -> String {
    join(&[
        "if-shell".into(),
        "-F".into(),
        "-t".into(),
        pane.into(),
        guarded.into(),
        deliver.into(),
        blocked.into(),
    ])
}
pub fn entry(args: &[String]) -> (i32, String) {
    let Some(mode) = args.first().map(String::as_str) else {
        return (2, String::new());
    };
    let args = &args[1..];
    let result = (|| -> Option<(bool, String)> {
        let get = |i| args.get(i).map(String::as_str);
        let output = match mode {
            "validate" => return Some((printable(&file(get(0)?)?), String::new())),
            "capacity" => {
                let text = file(get(0)?)?;
                let width = get(1)?.parse::<usize>().ok()?;
                return Some((width >= 4 && cells(&text)? <= width - 4, String::new()));
            }
            "chunks" => {
                let path = Path::new(get(0)?);
                std::fs::write(path.with_file_name("chunk-000000"), file(get(0)?)?).ok()?;
                String::new()
            }
            "tmux-nested" => nested(get(0)?, get(1)?, get(2)?, get(3)?),
            "cc-prepaste-command" => {
                let mut words = vec![
                    std::env::current_exe().ok()?.to_str()?.into(),
                    "--surface".into(),
                    "codex-model-payload-guard".into(),
                    "cc-prepaste".into(),
                ];
                words.extend_from_slice(args);
                join(&words)
            }
            "cc-prepaste" => return Some((crate::model::prepaste(args).is_ok(), String::new())),
            _ => return None,
        };
        Some((true, output))
    })();
    match result {
        Some((valid, output)) => (if valid { 0 } else { 1 }, output),
        None => (2, String::new()),
    }
}
