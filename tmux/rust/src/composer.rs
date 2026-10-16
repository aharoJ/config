#[derive(Debug, PartialEq, Eq)]
pub struct Row {
    pub text: String,
    pub visible_text_is_dim: bool,
    pub has_dim_style: bool,
    pub has_background_style: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub struct InvalidStyle;

pub fn row(raw: &str) -> Result<Row, InvalidStyle> {
    scan(raw, false).map(|(row, _)| row)
}

fn scan(raw: &str, mut dim: bool) -> Result<(Row, bool), InvalidStyle> {
    let normalized = crate::model_guard::normalize(raw, true);
    let mut raw = normalized.as_str();
    let mut text = String::new();
    let mut visible = false;
    let mut all_dim = true;
    let mut has_dim_style = false;
    let mut has_background_style = false;
    while !raw.is_empty() {
        if let Some(rest) = raw.strip_prefix("\x1b[") {
            let end = rest.find('m').ok_or(InvalidStyle)?;
            let parameters = &rest[..end];
            if !parameters
                .bytes()
                .all(|b| b.is_ascii_digit() || b == b';' || b == b':')
            {
                return Err(InvalidStyle);
            }
            let values: Vec<&str> = parameters.split(';').collect();
            let mut at = 0;
            while at < values.len() {
                let parts: Vec<&str> = values[at].split(':').collect();
                let number = |s: &str| -> Result<u16, InvalidStyle> {
                    if s.is_empty() {
                        Ok(0)
                    } else {
                        s.parse().map_err(|_| InvalidStyle)
                    }
                };
                let code = number(parts[0])?;
                if matches!(code, 38 | 48 | 58) {
                    has_background_style |= code == 48;
                    if parts.len() > 1 {
                        let mode = number(parts[1])?;
                        if !((mode == 5 && parts.len() == 3)
                            || (mode == 2 && matches!(parts.len(), 5 | 6)))
                        {
                            return Err(InvalidStyle);
                        }
                        for value in &parts[2..] {
                            number(value)?;
                        }
                    } else {
                        let mode = values.get(at + 1).ok_or(InvalidStyle)?;
                        let count = match number(mode)? {
                            5 => 2,
                            2 => 4,
                            _ => return Err(InvalidStyle),
                        };
                        for offset in 1..=count {
                            let value = values.get(at + offset).ok_or(InvalidStyle)?;
                            if value.is_empty() || value.contains(':') {
                                return Err(InvalidStyle);
                            }
                            number(value)?;
                        }
                        at += count;
                    }
                } else {
                    if parts.len() != 1 {
                        return Err(InvalidStyle);
                    }
                    has_background_style |= matches!(code, 7 | 40..=47 | 100..=107);
                    match code {
                        0 | 22 => dim = false,
                        2 => {
                            dim = true;
                            has_dim_style = true;
                        }
                        8 => return Err(InvalidStyle),
                        _ => (),
                    }
                }
                at += 1;
            }
            raw = &rest[end + 1..];
        } else {
            let ch = raw.chars().next().ok_or(InvalidStyle)?;
            if ch.is_control() && !matches!(ch, '\t' | '\r' | '\n') {
                return Err(InvalidStyle);
            }
            text.push(ch);
            if !ch.is_whitespace() {
                visible |= ch != '\u{200b}';
                all_dim &= dim;
            }
            raw = &raw[ch.len_utf8()..];
        }
    }
    Ok((
        Row {
            text,
            visible_text_is_dim: visible && all_dim,
            has_dim_style,
            has_background_style,
        },
        dim,
    ))
}

#[derive(Debug, PartialEq, Eq)]
pub enum Marker {
    Empty,
    Ghost,
    Draft,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Composer {
    EmptyCandidate,
    Draft,
    Unrecognized,
}

pub fn classify(capture: &str, glyph: char, x: usize, y: usize, width: usize) -> Composer {
    if width == 0 || x > width {
        return Composer::Unrecognized;
    }
    let rows: Vec<&str> = capture.split_inclusive('\n').collect();
    let Some(raw) = rows.get(y) else {
        return Composer::Unrecognized;
    };
    let Ok(prompt) = row(raw) else {
        return Composer::Unrecognized;
    };
    let Some((leading, _)) = prompt.text.split_once(glyph) else {
        return if (0..y)
            .rev()
            .find(|start| marker(rows[*start], glyph).is_ok())
            .is_some_and(|start| wrapped_candidate(&rows, start, glyph, y, width))
        {
            Composer::EmptyCandidate
        } else {
            Composer::Unrecognized
        };
    };
    if !leading.chars().all(|ch| matches!(ch, ' ' | '\u{a0}')) {
        return Composer::Unrecognized;
    }
    if glyph == '>' && x != leading.chars().count() + 2 {
        return Composer::Draft;
    }
    if glyph == '>' {
        if width < 8
            || raw.trim_end_matches(['\r', '\n']) != "\x1b[94m>\x1b[39m"
            || y == 0
            || divider_width(rows[y - 1]) != Some(width)
            || rows
                .get(y + 1)
                .is_none_or(|r| divider_width(r) != Some(width))
        {
            return Composer::Draft;
        }
        let Some(footer) = rows.get(y + 2).and_then(|r| row(r).ok()) else {
            return Composer::Unrecognized;
        };
        let text = footer.text.trim_end_matches(['\r', '\n']);
        let footer_matches = text == "? for shortcuts"
            || text.strip_prefix("? for shortcuts").is_some_and(|rest| {
                rest.starts_with(char::is_whitespace)
                    && rest
                        .trim_start()
                        .strip_prefix("Gemini ")
                        .is_some_and(|rest| rest.contains(" · "))
            });
        return if footer_matches && !rows[y + 2..].iter().any(|r| divider_width(r).is_some()) {
            Composer::EmptyCandidate
        } else {
            Composer::Draft
        };
    }
    match marker(raw, glyph) {
        Ok(Marker::Empty) if x != leading.chars().count() + 2 => return Composer::Draft,
        Ok(Marker::Ghost)
            if glyph == '›'
                && prompt.text.trim_end_matches(['\r', '\n']) == "› Ask Codex to do anything"
                && rows[y + 1..]
                    .iter()
                    .all(|r| matches!(*r, "" | "\n" | "\r\n")) =>
        {
            return Composer::EmptyCandidate;
        }
        Ok(Marker::Empty | Marker::Ghost) => (),
        Ok(Marker::Draft) => return Composer::Draft,
        Err(_) => return Composer::Unrecognized,
    }
    if wrapped_candidate(&rows, y, glyph, y, width) {
        return Composer::EmptyCandidate;
    }
    if glyph == '›' {
        let Some(separator) = rows.get(y + 1) else {
            return Composer::Unrecognized;
        };
        if !matches!(*separator, "" | "\n" | "\r\n") {
            return Composer::Draft;
        }
        let Some(footer) = rows.get(y + 2) else {
            return Composer::Unrecognized;
        };
        if !codex_footer(footer) {
            return Composer::Draft;
        }
        return if blank_tail(&rows[y + 3..]) {
            Composer::EmptyCandidate
        } else {
            Composer::Draft
        };
    }
    if glyph != '❯' || width < 8 {
        return Composer::Unrecognized;
    }
    if rows
        .get(y + 1)
        .is_none_or(|r| divider_width(r) != Some(width))
    {
        return Composer::Draft;
    }
    if rows[y + 2..].iter().any(|r| divider_width(r).is_some()) {
        return Composer::Draft;
    }
    Composer::EmptyCandidate
}

fn divider_width(raw: &str) -> Option<usize> {
    row(raw).ok().and_then(|r| {
        let text = r.text.trim_end_matches(['\r', '\n']);
        let core = text.trim_matches([' ', '\t', '\u{a0}']);
        (core.chars().count() >= 8 && core.chars().all(|ch| ch == '─'))
            .then(|| text.chars().count())
    })
}
pub fn ready(glyph: char, capture: &str, x: usize, y: usize, width: usize) -> bool {
    if x != 2 || classify(capture, glyph, x, y, width) != Composer::EmptyCandidate {
        return false;
    }
    if glyph != '›' {
        return true;
    }
    let rows: Vec<_> = capture.split_inclusive('\n').collect();
    rows.get(y + 1)
        .is_some_and(|row| matches!(*row, "" | "\n" | "\r\n"))
        && rows.get(y + 2).is_some_and(|row| codex_footer(row))
        && blank_tail(&rows[y + 3..])
}

fn codex_footer(raw: &str) -> bool {
    row(raw).is_ok_and(|r| {
        !r.has_background_style
            && r.text.strip_prefix("  ").is_some_and(|text| {
                text.starts_with(|ch: char| !ch.is_whitespace() && ch != '\u{200b}')
            })
    })
}

fn blank_tail(rows: &[&str]) -> bool {
    rows.iter()
        .all(|r| row(r).is_ok_and(|r| r.text.chars().all(char::is_whitespace)))
}

fn wrapped_candidate(
    rows: &[&str],
    start: usize,
    glyph: char,
    cursor: usize,
    width: usize,
) -> bool {
    if !matches!(marker(rows[start], glyph), Ok(Marker::Ghost)) {
        return false;
    }
    let Ok((_, mut dim)) = scan(rows[start], false) else {
        return false;
    };
    for at in start + 1..rows.len() {
        if glyph == '❯' && divider_width(rows[at]).is_some() {
            return at > cursor
                && at > start + 1
                && divider_width(rows[at]) == Some(width)
                && !rows[at + 1..].iter().any(|r| divider_width(r).is_some());
        }
        if glyph == '›' {
            if rows[at].starts_with("\x1b[49m") && codex_footer(rows[at]) {
                return at > cursor && blank_tail(&rows[at + 1..]);
            }
            if matches!(rows[at], "" | "\n" | "\r\n") {
                return at > cursor
                    && rows.get(at + 1).is_some_and(|r| codex_footer(r))
                    && blank_tail(&rows[at + 2..]);
            }
        }
        let Ok((continuation, next_dim)) = scan(rows[at], dim) else {
            return false;
        };
        if !continuation.visible_text_is_dim {
            return false;
        }
        dim = next_dim;
    }
    false
}

pub fn marker(raw: &str, glyph: char) -> Result<Marker, InvalidStyle> {
    if !matches!(glyph, '❯' | '›') {
        return Err(InvalidStyle);
    }
    let (prefix, tail) = raw.split_once(glyph).ok_or(InvalidStyle)?;
    if !row(prefix)?
        .text
        .chars()
        .all(|ch| matches!(ch, ' ' | '\t' | '\u{a0}'))
    {
        return Err(InvalidStyle);
    }
    let input = row(tail)?;
    let text = input.text.trim_end_matches(['\r', '\n']);
    if text.contains(['\r', '\n']) {
        return Err(InvalidStyle);
    }
    if glyph == '❯'
        && (text == "\u{a0}" || (text == "\u{a0} " && tail == "\u{a0}\x1b[7m \x1b[0m\n"))
    {
        return Ok(Marker::Empty);
    }
    if text.starts_with([' ', '\u{a0}'])
        && input.has_dim_style
        && (input.visible_text_is_dim || text.chars().all(char::is_whitespace))
    {
        return Ok(Marker::Ghost);
    }
    Ok(Marker::Draft)
}

#[derive(Debug, PartialEq, Eq)]
pub enum Screen {
    Empty,
    Staged(Vec<u8>),
    Hold,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Receipt {
    pub submitted: usize,
    pub queued: usize,
    pub queue_prompt: bool,
}
pub fn receipt(
    glyph: char,
    capture: &str,
    x: usize,
    y: usize,
    width: usize,
    wire: &str,
) -> Receipt {
    let rows: Vec<_> = capture.lines().collect();
    if y >= rows.len() || width < 8 || !wire.bytes().all(|b| (32..=126).contains(&b)) {
        return Receipt::default();
    }
    let normal = match glyph {
        '❯' => format!("\x1b[38;5;246m\x1b[48;5;237m❯ \x1b[38;5;231m{wire}\x1b[39m"),
        '›' => format!("\x1b[1m›\x1b[0m {wire}"),
        _ => return Receipt::default(),
    };
    let mut result = Receipt {
        submitted: rows[..y]
            .iter()
            .filter(|row| {
                **row == normal
                    || (glyph == '›'
                        && (**row == format!("\x1b[1;2m› \x1b[0m{wire}")
                            || **row == format!("\x1b[1;2m› \x1b[0m\x1b[48;2;66;66;79m{wire}")))
            })
            .count(),
        ..Default::default()
    };
    let claude_queue_hint = if y >= 4
        && rows[y - 3] == "\x1b[49m  \x1b[38;5;246mctrl+x ctrl+s to send now\x1b[39m"
        && rows[y - 2].is_empty()
    {
        Some(y - 4)
    } else if y >= 6
        && rows[y - 5] == "\x1b[49m  \x1b[38;5;246mctrl+x ctrl+s to send now\x1b[39m"
        && rows[y - 4].is_empty()
        && rows[y - 2].is_empty()
    {
        Some(y - 6)
    } else if y >= 7
        && rows[y - 6] == "\x1b[49m  \x1b[38;5;246mctrl+x ctrl+s to send now\x1b[39m"
        && rows[y - 5].is_empty()
        && rows[y - 2].is_empty()
    {
        Some(y - 7)
    } else {
        None
    };
    if let Some(queued_end) = claude_queue_hint.filter(|_| {
        glyph == '❯'
            && divider_width(rows[y - 1]) == Some(width)
            && rows.get(y + 1).and_then(|row| divider_width(row)) == Some(width)
    }) {
        result.queue_prompt = x == 2
            && matches!(rows[y],
                "\x1b[38;5;246m❯\u{a0}\x1b[2m\x1b[39mPress up to edit queued messages\x1b[0m"
                | "\x1b[38;5;246m❯\u{a0}\x1b[2m\x1b[39mPress\x1b[0m \x1b[2mup\x1b[0m \x1b[2mto\x1b[0m \x1b[2medit\x1b[0m \x1b[2mqueued\x1b[0m \x1b[2mmessages\x1b[0m");
        let queued = format!("\x1b[38;5;246m\x1b[48;5;237m❯ {wire}\x1b[39m");
        for raw in rows[..=queued_end]
            .iter()
            .rev()
            .take_while(|raw| raw.starts_with("\x1b[38;5;246m\x1b[48;5;237m❯ "))
        {
            result.queued += usize::from(*raw == queued);
        }
    }
    if glyph == '›' && y >= 3 && rows[y - 1].is_empty() {
        result.queue_prompt = x == 2
            && matches!(rows[y],
                "\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m"
                | "\x1b[1m›\x1b[0m\x1b[48;2;57;57;71m \x1b[2mAsk Codex to do anything\x1b[0m\x1b[48;2;57;57;71m")
            && classify(capture, glyph, x, y, width) == Composer::EmptyCandidate;
        let header = "\x1b[2m• \x1b[0mMessages to be submitted after next tool call\x1b[2m (press \x1b[0;1mesc\x1b[0;2m to interrupt and send immediately)\x1b[0m";
        if let Some(start) = rows[..y - 1].iter().rposition(|raw| *raw == header) {
            if rows[start + 1..y - 1]
                .iter()
                .all(|raw| raw.starts_with("\x1b[2m  ↳ ") && raw.ends_with("\x1b[0m"))
            {
                let queued = format!("\x1b[2m  ↳ {wire}\x1b[0m");
                result.queued = rows[start + 1..y - 1]
                    .iter()
                    .filter(|raw| **raw == queued)
                    .count();
            }
        }
    }
    result
}
/// Conservative one-line staged-byte oracle. Unrecognized layouts, styles,
/// wrapping, cursor edits and Unicode wires cannot authorize Enter.
pub fn screen(glyph: char, capture: &str, x: usize, y: usize, width: usize, wire: &str) -> Screen {
    if classify(capture, glyph, x, y, width) == Composer::EmptyCandidate {
        return Screen::Empty;
    }
    if width == 0 || !wire.bytes().all(|b| (32..=126).contains(&b)) {
        return Screen::Hold;
    }
    let rows: Vec<&str> = capture.split_inclusive('\n').collect();
    let Some(raw) = rows.get(y) else {
        return Screen::Hold;
    };
    let Ok(row) = row(raw) else {
        return Screen::Hold;
    };
    let Some((prefix, tail)) = row.text.trim_end_matches(['\r', '\n']).split_once(glyph) else {
        return Screen::Hold;
    };
    if !prefix.chars().all(|c| c == ' ' || c == '\u{a0}')
        || row.has_dim_style
        || (row.has_background_style
            && !(glyph == '›'
                && raw
                    .strip_prefix("\x1b[1m›\x1b[0m\x1b[48;2;57;57;71m ")
                    .is_some_and(|tail| tail.trim_end_matches(['\r', '\n']) == wire)))
    {
        return Screen::Hold;
    }
    let expected = format!(" {wire}");
    if tail != expected && tail != format!("\u{a0}{wire}") {
        return Screen::Hold;
    }
    let prompt_x = prefix.chars().count() + 2;
    if x != prompt_x + wire.len() || x >= width {
        return Screen::Hold;
    }
    // Substitute only the independently exact staged prompt, then reuse the
    // classifier to require the recognized application's surrounding layout.
    let empty = match glyph {
        '❯' => format!("{prefix}❯\u{a0}\n"),
        _ => format!("{prefix}›\x1b[2m \x1b[0m\n"),
    };
    let mut check = rows.iter().map(|r| (*r).to_owned()).collect::<Vec<_>>();
    check[y] = empty;
    if classify(&check.concat(), glyph, prompt_x, y, width) != Composer::EmptyCandidate {
        return Screen::Hold;
    }
    Screen::Staged(wire.as_bytes().to_vec())
}

#[cfg(test)]
#[path = "../tests/support/composer.rs"]
mod tests;
