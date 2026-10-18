use serde::Deserialize;
use std::collections::HashMap;
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Write};
use std::os::fd::AsRawFd;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use unicode_width::UnicodeWidthChar;

const HELP: &str = "usage: tmux-lanes <file.toml>\nRead-only board; reloads every 15 seconds; Ctrl-C exits.\nTOML: session, title, optional footer = [\"Next: ...\"], and [[lanes]] with name, window, job, result, end.\nOptional lane started is Unix seconds. Result paths are relative to the TOML file.\n";
static STOP: AtomicBool = AtomicBool::new(false);

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Board {
    session: String,
    title: String,
    #[serde(default)]
    footer: Vec<String>,
    lanes: Vec<Lane>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Lane {
    name: String,
    window: String,
    job: String,
    result: PathBuf,
    end: String,
    started: Option<u64>,
}

fn parse(text: &str, base: &Path) -> Result<Board, String> {
    let mut board: Board = toml::from_str(text).map_err(|e| e.to_string())?;
    if board.lanes.is_empty() {
        return Err("at least one lane is required".into());
    }
    for field in [&board.session, &board.title]
        .into_iter()
        .chain(&board.footer)
        .chain(
            board
                .lanes
                .iter()
                .flat_map(|l| [&l.name, &l.window, &l.job, &l.end]),
        )
    {
        if field.trim().is_empty() || field.chars().any(char::is_control) {
            return Err(
                "text fields must be nonempty single lines without control characters".into(),
            );
        }
    }
    for lane in &mut board.lanes {
        if lane.result.as_os_str().is_empty() {
            return Err("result path must be nonempty".into());
        }
        lane.result = base.join(&lane.result);
    }
    Ok(board)
}

fn load(path: &Path) -> Result<Board, String> {
    fs::read_to_string(path)
        .map_err(|e| e.to_string())
        .and_then(|text| parse(&text, path.parent().unwrap_or(Path::new("."))))
}

fn reload(path: &Path, board: &mut Board) -> Option<&'static str> {
    match load(path) {
        Ok(next) => {
            *board = next;
            None
        }
        Err(_) => Some("config error; showing last valid board"),
    }
}

#[derive(Default)]
struct ResultFile {
    done: bool,
    size: Option<u64>,
    modified: Option<u64>,
}

fn result(lane: &Lane) -> io::Result<ResultFile> {
    let file = match OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(&lane.result)
    {
        Ok(file) => file,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(ResultFile::default()),
        Err(e) => return Err(e),
    };
    let metadata = file.metadata()?;
    if !metadata.is_file() {
        return Err(io::Error::other("result is not a regular file"));
    }
    let mut result = ResultFile {
        done: false,
        size: Some(metadata.len()),
        modified: metadata
            .modified()
            .ok()
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map(|time| time.as_secs()),
    };
    let marker = format!("END {}", lane.end);
    for line in BufReader::new(file).lines() {
        if line? == marker {
            result.done = true;
            break;
        }
    }
    Ok(result)
}

fn tmux(args: &[&str]) -> Result<String, String> {
    let output = crate::tmux_lab::bounded(Command::new("tmux").arg("-N").args(args), 2)?;
    if output.code != 0 {
        return Err(if output.code == 124 {
            "tmux timed out".into()
        } else {
            "tmux unavailable".into()
        });
    }
    Ok(String::from_utf8_lossy(&output.out).into_owned())
}

fn windows(snapshot: &str, session: &str) -> HashMap<String, Vec<String>> {
    let mut windows: HashMap<String, Vec<String>> = HashMap::new();
    for line in snapshot.lines() {
        let fields: Vec<_> = line.split('\t').collect();
        if fields.len() == 3 && fields[0] == session {
            windows
                .entry(fields[1].to_owned())
                .or_default()
                .push(fields[2].to_owned());
        }
    }
    windows
}

fn activity(pane: &str) -> (&str, bool) {
    let seat = pane
        .lines()
        .rev()
        .find_map(|line| {
            line.find("Working (")
                .or_else(|| line.find("Worked for "))
                .map(|start| &line[start..])
        })
        .unwrap_or("");
    let running = pane
        .lines()
        .rev()
        .find_map(|line| {
            if line.contains("Worked for ") {
                Some(false)
            } else if line.contains("Working (") || line.contains("esc to interrupt") {
                Some(true)
            } else {
                None
            }
        })
        .unwrap_or(false);
    (seat, running)
}

fn state(done: bool, pane: &Result<Option<String>, String>) -> &'static str {
    if done {
        "DONE"
    } else {
        match pane {
            Err(_) => "ERROR",
            Ok(None) => "MISSING",
            Ok(Some(text)) if activity(text).1 => "RUNNING",
            Ok(Some(_)) => "IDLE",
        }
    }
}

fn elapsed(started: Option<u64>, now: u64) -> String {
    match started.and_then(|start| now.checked_sub(start)) {
        Some(s) if s < 3600 => format!("{}m{:02}s", s / 60, s % 60),
        Some(s) => format!("{}h{:02}m", s / 3600, s % 3600 / 60),
        None => "-".into(),
    }
}

fn cell(text: &str, width: usize) -> String {
    let mut out = String::new();
    let mut used = 0;
    for c in text.chars().filter(|c| !c.is_control()) {
        let n = c.width().unwrap_or(0);
        if used + n > width {
            break;
        }
        out.push(c);
        used += n;
    }
    out.push_str(&" ".repeat(width - used));
    out
}

fn width() -> usize {
    let mut size: libc::winsize = unsafe { std::mem::zeroed() };
    if unsafe { libc::ioctl(io::stdout().as_raw_fd(), libc::TIOCGWINSZ, &mut size) } == 0
        && size.ws_col > 0
    {
        usize::from(size.ws_col)
    } else {
        120
    }
}

fn epoch() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn clock(now: u64) -> String {
    let seconds = now as libc::time_t;
    let mut local: libc::tm = unsafe { std::mem::zeroed() };
    if unsafe { libc::localtime_r(&seconds, &mut local) }.is_null() {
        return "--:--:--".into();
    }
    format!(
        "{:02}:{:02}:{:02}",
        local.tm_hour, local.tm_min, local.tm_sec
    )
}

fn lane_row(
    lane: &Lane,
    pane: Result<Option<String>, String>,
    result: io::Result<ResultFile>,
    now: u64,
) -> [String; 6] {
    let (status, size, until) = match result {
        Ok(result) => (
            state(result.done, &pane),
            result.size.map(|n| n.to_string()).unwrap_or("-".into()),
            if result.done {
                result.modified.filter(|time| *time <= now)
            } else {
                Some(now)
            },
        ),
        Err(_) => ("ERROR", "ERROR".into(), Some(now)),
    };
    let seat = if status == "DONE" {
        "result complete"
    } else {
        match &pane {
            Ok(Some(text)) => activity(text).0,
            Ok(None) => "window missing",
            Err(e) => e,
        }
    };
    [
        lane.name.clone(),
        status.into(),
        lane.job.clone(),
        until
            .map(|end| elapsed(lane.started, end))
            .unwrap_or("-".into()),
        size,
        seat.into(),
    ]
}

fn wrapped(text: &str, width: usize) -> String {
    let mut out = String::new();
    let mut used = 0;
    for c in text.chars().filter(|c| !c.is_control()) {
        let n = c.width().unwrap_or(0);
        if used + n > width && used > 0 {
            out.push('\n');
            used = 0;
        }
        out.push(c);
        used += n;
    }
    out.push('\n');
    out
}

fn render(
    board: &Board,
    rows: &[[String; 6]],
    width: usize,
    warning: Option<&str>,
    now: u64,
) -> String {
    let width = width.max(1);
    let mut out = format!(
        "\x1b[H\x1b[2J{}\n{}\n\n",
        cell(&format!("{} · {}", board.title, board.session), width),
        cell(
            &format!("updated {} · read-only · 15s · Ctrl-C exits", clock(now)),
            width
        )
    );
    if let Some(warning) = warning {
        out.push_str(&wrapped(&format!("WARNING: {warning}"), width));
    }
    let header = ["LANE", "STATE", "JOB", "ELAPSED", "RESULT (B)", "SEAT"].map(str::to_owned);
    let time_width = rows.iter().map(|r| r[3].len()).max().unwrap_or(0).max(9);
    let size_width = rows.iter().map(|r| r[4].len()).max().unwrap_or(0).max(10);
    let core = 10 + 7 + time_width + size_width + 3;
    let table_row = |fields: &[String; 6], indices: &[usize], columns: &[usize]| {
        let line = indices
            .iter()
            .zip(columns)
            .map(|(i, w)| cell(&fields[*i], *w))
            .collect::<Vec<_>>()
            .join(" ");
        format!("{}\n", cell(&line, width))
    };
    if width >= core + 33 {
        let job = 26.min(width - core - 17);
        let columns = [10, 7, job, time_width, size_width, width - core - job - 2];
        for fields in std::iter::once(&header).chain(rows) {
            out.push_str(&table_row(fields, &[0, 1, 2, 3, 4, 5], &columns));
        }
    } else if width >= core {
        let columns = [10, 7, time_width, size_width];
        out.push_str(&table_row(&header, &[0, 1, 3, 4], &columns));
        let job = 26.min(width.saturating_sub(31));
        for fields in rows {
            out.push_str(&table_row(fields, &[0, 1, 3, 4], &columns));
            out.push_str(&format!(
                "  JOB: {} | SEAT: {}\n",
                cell(&fields[2], job),
                cell(&fields[5], width - job - 16)
            ));
        }
    } else {
        for fields in rows {
            for (label, value) in header.iter().zip(fields) {
                out.push_str(&wrapped(&format!("{label}: {value}"), width));
            }
            out.push('\n');
        }
    }
    if !board.footer.is_empty() {
        out.push('\n');
        for line in &board.footer {
            out.push_str(&wrapped(line, width));
        }
    }
    out
}

fn draw(board: &Board, warning: Option<&str>, out: &mut impl Write) -> io::Result<()> {
    let snapshot = tmux(&[
        "list-windows",
        "-a",
        "-F",
        "#{session_name}\t#{window_name}\t#{pane_id}",
    ])
    .map(|text| windows(&text, &board.session));
    let mut rows = Vec::new();
    for lane in &board.lanes {
        if STOP.load(Ordering::Relaxed) {
            break;
        }
        let pane = match &snapshot {
            Err(e) => Err(e.clone()),
            Ok(windows) => match windows.get(&lane.window).map(Vec::as_slice) {
                None => Ok(None),
                Some([pane]) => tmux(&["capture-pane", "-p", "-t", pane]).map(Some),
                Some(_) => Err("ambiguous window name".into()),
            },
        };
        rows.push(lane_row(lane, pane, result(lane), epoch()));
    }
    out.write_all(render(board, &rows, width(), warning, epoch()).as_bytes())?;
    out.flush()
}

extern "C" fn stop(_: libc::c_int) {
    STOP.store(true, Ordering::Relaxed);
}

pub fn entry(args: &[String]) -> i32 {
    if args == ["--help"] || args == ["-h"] {
        print!("{HELP}");
        return 0;
    }
    let [path] = args else {
        eprint!("{HELP}");
        return 2;
    };
    let path = Path::new(path);
    let mut board = match load(path) {
        Ok(board) => board,
        Err(e) => {
            eprintln!("tmux-lanes: {}: {e}", path.display());
            return 1;
        }
    };
    STOP.store(false, Ordering::Relaxed);
    unsafe {
        libc::signal(libc::SIGINT, stop as *const () as libc::sighandler_t);
        libc::signal(libc::SIGTERM, stop as *const () as libc::sighandler_t);
    }
    let mut out = io::stdout().lock();
    while !STOP.load(Ordering::Relaxed) {
        let warning = reload(path, &mut board);
        if let Err(e) = draw(&board, warning, &mut out) {
            eprintln!("tmux-lanes: {e}");
            return 1;
        }
        let next = Instant::now() + Duration::from_secs(15);
        while !STOP.load(Ordering::Relaxed) && Instant::now() < next {
            std::thread::sleep(Duration::from_millis(100));
        }
    }
    0
}

#[cfg(test)]
#[path = "../tests/support/tmux_lanes.rs"]
mod tests;
