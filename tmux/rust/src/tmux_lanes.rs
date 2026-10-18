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

const HELP: &str = "usage: tmux-lanes <file.toml>\nRead-only board; refreshes every 15 seconds; Ctrl-C exits.\nTOML: session, title, and [[lanes]] with name, window, job, result, end.\nOptional lane started is Unix seconds. Result paths are relative to the TOML file.\n";
static STOP: AtomicBool = AtomicBool::new(false);

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Board {
    session: String,
    title: String,
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
    for field in [&board.session, &board.title].into_iter().chain(
        board
            .lanes
            .iter()
            .flat_map(|l| [&l.name, &l.window, &l.job, &l.end]),
    ) {
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

fn result(lane: &Lane) -> io::Result<(bool, Option<u64>)> {
    let file = match OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(&lane.result)
    {
        Ok(file) => file,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok((false, None)),
        Err(e) => return Err(e),
    };
    let metadata = file.metadata()?;
    if !metadata.is_file() {
        return Err(io::Error::other("result is not a regular file"));
    }
    let marker = format!("END {}", lane.end);
    for line in BufReader::new(file).lines() {
        if line? == marker {
            return Ok((true, Some(metadata.len())));
        }
    }
    Ok((false, Some(metadata.len())))
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

fn draw(board: &Board, out: &mut impl Write) -> io::Result<()> {
    let columns = [10, 7, 26, 9, 10];
    let width = width();
    let row = |fields: &[&str]| {
        let line = fields
            .iter()
            .enumerate()
            .map(|(i, value)| cell(value, *columns.get(i).unwrap_or(&width.saturating_sub(67))))
            .collect::<Vec<_>>()
            .join(" ");
        cell(&line, width)
    };
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let snapshot = tmux(&[
        "list-windows",
        "-a",
        "-F",
        "#{session_name}\t#{window_name}\t#{pane_id}",
    ])
    .map(|text| windows(&text, &board.session));
    write!(out, "\x1b[H\x1b[2J")?;
    writeln!(
        out,
        "{}\n",
        cell(
            &format!(
                "{} · {} · read-only · 15s · Ctrl-C exits",
                board.title, board.session
            ),
            width
        )
    )?;
    writeln!(
        out,
        "{}",
        row(&["LANE", "STATE", "JOB", "ELAPSED", "RESULT (B)", "SEAT"])
    )?;
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
        let result = result(lane);
        let (status, size) = match result {
            Ok((done, size)) => (
                state(done, &pane),
                size.map(|n| n.to_string()).unwrap_or("-".into()),
            ),
            Err(_) => ("ERROR", "ERROR".into()),
        };
        let seat = match &pane {
            Ok(Some(text)) => activity(text).0,
            Ok(None) => "window missing",
            Err(e) => e,
        };
        writeln!(
            out,
            "{}",
            row(&[
                &lane.name,
                status,
                &lane.job,
                &elapsed(lane.started, now),
                &size,
                seat
            ])
        )?;
    }
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
    let board = match fs::read_to_string(path)
        .map_err(|e| e.to_string())
        .and_then(|text| parse(&text, path.parent().unwrap_or(Path::new("."))))
    {
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
        if let Err(e) = draw(&board, &mut out) {
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
