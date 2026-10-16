use sha2::{Digest, Sha256};
use std::fs::{self, DirBuilder, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;

type Result<T> = std::result::Result<T, String>;
const USAGE: &str = "usage: panel-catch <topic> <round> <panelist|--batch>\n       panel-catch --list <topic> <round>";
fn io<T>(result: std::io::Result<T>) -> Result<T> {
    result.map_err(|error| error.to_string())
}
fn directory(root: &Path, topic: &str, round: &str) -> Result<PathBuf> {
    if !root.is_absolute() || (root.exists() && !root.is_dir()) {
        return Err("PANEL_CATCH_ROOT must be an absolute directory path".into());
    }
    if topic.is_empty()
        || topic.len() > 128
        || !topic.as_bytes()[0].is_ascii_alphanumeric()
        || !topic
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b"._-".contains(&c))
    {
        return Err("topic must be a safe single path segment".into());
    }
    if round.is_empty() || round.starts_with('0') || !round.bytes().all(|c| c.is_ascii_digit()) {
        return Err("round must be a positive integer".into());
    }
    Ok(root.join(topic).join("panels").join(format!("r{round}")))
}
fn slug(who: &str) -> Result<String> {
    if who == "--batch" {
        return Ok("batch".into());
    }
    if who.starts_with("--") {
        return Err(format!("unknown option: {who}"));
    }
    let mut slug = String::new();
    for c in who.bytes() {
        let c = if c.is_ascii_alphanumeric() || b"._-".contains(&c) {
            char::from(c.to_ascii_lowercase())
        } else {
            '-'
        };
        if c != '-' || !slug.ends_with('-') {
            slug.push(c);
        }
    }
    let slug = slug.trim_matches('-').to_owned();
    if slug.is_empty() {
        return Err("panelist name reduced to nothing".into());
    }
    Ok(slug)
}
fn files(dir: &Path) -> Result<Vec<(String, u64)>> {
    let mut rows = Vec::new();
    for entry in io(fs::read_dir(dir))? {
        let entry = io(entry)?;
        if io(entry.file_type())?.is_file() {
            rows.push((
                entry.file_name().to_string_lossy().into_owned(),
                io(entry.metadata())?.len(),
            ));
        }
    }
    rows.sort();
    Ok(rows)
}
fn save(root: &Path, topic: &str, round: &str, who: &str, bytes: &[u8]) -> Result<String> {
    let dir = directory(root, topic, round)?;
    let stem = slug(who)?;
    if bytes.is_empty() {
        return Err("clipboard is empty; copy the response first".into());
    }
    io(DirBuilder::new().recursive(true).mode(0o700).create(&dir))?;
    let nonce = crate::runtime::fresh_id()?;
    let temporary = dir.join(format!(".panel-catch.{nonce}"));
    let now = chrono::DateTime::<chrono::Utc>::from(std::time::SystemTime::now());
    let timestamp = now.format("%Y%m%dT%H%M%SZ");
    let out = dir.join(format!("{stem}-{timestamp}-{nonce}.txt"));
    let result = (|| {
        let mut file = io(OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary))?;
        io(file.write_all(bytes))?;
        io(file.sync_all())?;
        io(fs::rename(&temporary, &out))
    })();
    if let Err(error) = result {
        if temporary.exists() {
            let _ = Command::new("/usr/bin/trash").arg(&temporary).status();
        }
        return Err(error);
    }
    let lines =
        bytes.iter().filter(|c| **c == b'\n').count() + usize::from(bytes.last() != Some(&b'\n'));
    let sha = format!("{:x}", Sha256::digest(bytes));
    Ok(format!("caught  {}\nbytes   {}\nlines   {lines}\nsha256  {}...\ncaught so far in r{round}: {} file(s)\n", out.display(), bytes.len(), &sha[..16], files(&dir)?.len()))
}
fn run(root: &Path, args: &[String]) -> Result<String> {
    if args == ["--help"] || args == ["-h"] {
        return Ok(format!("{USAGE}\n"));
    }
    if args.len() != 3 {
        return Err(USAGE.into());
    }
    if args[0] == "--list" {
        let dir = directory(root, &args[1], &args[2])?;
        let rows = files(&dir)?;
        let total: u64 = rows.iter().map(|(_, size)| size).sum();
        let mut output = format!("{}\n", dir.display());
        for (name, size) in rows {
            output.push_str(&format!("{size:>12} {name}\n"));
        }
        output.push_str(&format!("\ntotal bytes: {total}\n"));
        return Ok(output);
    }
    directory(root, &args[0], &args[1])?;
    slug(&args[2])?;
    let output = io(Command::new("/usr/bin/pbpaste").output())?;
    if !output.status.success() {
        return Err("pbpaste failed".into());
    }
    save(root, &args[0], &args[1], &args[2], &output.stdout)
}
pub fn entry(args: &[String]) -> i32 {
    let root = std::env::var_os("PANEL_CATCH_ROOT")
        .map(PathBuf::from)
        .map(Ok)
        .unwrap_or_else(|| crate::identity::account_home().map(|home| home.join("desk/audits")));
    match root.and_then(|root| run(&root, args)) {
        Ok(output) => {
            print!("{output}");
            0
        }
        Err(error) => {
            eprintln!("panel-catch: {error}");
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    #[test]
    fn captures_exact_bytes_privately_and_lists_them() {
        let root = crate::identity::account_home()
            .unwrap()
            .join("desk/tmp")
            .join(format!(
                "panel-catch-{}",
                crate::runtime::fresh_id().unwrap()
            ));
        let bytes = b"one\nlast\0\xff";
        let output = save(&root, "topic", "1", "Fable MAX", bytes).unwrap();
        let file = files(&root.join("topic/panels/r1"))
            .unwrap()
            .pop()
            .unwrap()
            .0;
        let path = root.join("topic/panels/r1").join(file);
        assert_eq!(fs::read(&path).unwrap(), bytes);
        assert_eq!(
            fs::metadata(&path).unwrap().permissions().mode() & 0o777,
            0o600
        );
        assert!(output.contains("lines   2\n"));
        assert!(output.contains("caught so far in r1: 1 file(s)"));
        let listed = run(&root, &["--list".into(), "topic".into(), "1".into()]).unwrap();
        assert!(listed.contains("total bytes: 10\n"));
        assert!(Command::new("/usr/bin/trash")
            .arg(root)
            .status()
            .unwrap()
            .success());
    }
    #[test]
    fn rejects_escaping_topics_invalid_rounds_and_empty_captures() {
        let root = Path::new("/fixtures/catch");
        for topic in ["../escape", "/absolute", ".hidden", "a/b"] {
            assert!(directory(root, topic, "1").is_err());
        }
        for round in ["", "0", "01", "-1", "1/2"] {
            assert!(directory(root, "topic", round).is_err());
        }
        assert!(save(root, "topic", "1", "--bad", b"data").is_err());
        assert!(save(root, "topic", "1", "name", b"").is_err());
    }
}
