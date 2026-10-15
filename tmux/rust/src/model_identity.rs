use crate::identity;
use std::path::Path;

fn arguments(pid: u32) -> Option<Vec<String>> {
    let mut mib = [libc::CTL_KERN, libc::KERN_PROCARGS2, pid as i32];
    let mut bytes = vec![0u8; 262144];
    let mut length = bytes.len();
    if unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            3,
            bytes.as_mut_ptr().cast(),
            &mut length,
            std::ptr::null_mut(),
            0,
        )
    } != 0
        || length < 5
    {
        return None;
    }
    bytes.truncate(length);
    let argc = i32::from_ne_bytes(bytes[..4].try_into().ok()?);
    if !(1..=4096).contains(&argc) {
        return None;
    }
    let mut at = 4;
    while *bytes.get(at)? != 0 {
        at += 1;
    }
    while bytes.get(at) == Some(&0) {
        at += 1;
    }
    let mut result = Vec::new();
    for _ in 0..argc {
        let end = at + bytes.get(at..)?.iter().position(|b| *b == 0)?;
        result.push(std::str::from_utf8(&bytes[at..end]).ok()?.into());
        at = end + 1;
    }
    Some(result)
}
pub fn app(pid: u32, path: &Path) -> Option<&'static str> {
    let path_text = path.to_str()?;
    let name = path.file_name()?.to_str()?;
    if matches!(name, "codex" | "claude") {
        return Some(if name == "codex" { "codex" } else { "claude" });
    }
    if crate::model_guard::re(r"/claude/versions/[0-9]+\.[0-9]+\.[0-9]+(?:[-+][\w.-]+)?$")
        .is_match(path_text)
    {
        return Some("claude");
    }
    if name != "node" {
        return None;
    }
    let argv = arguments(pid)?;
    let entry = argv.get(1)?;
    if entry.starts_with('-') {
        return None;
    }
    let entry = std::fs::canonicalize(entry).ok()?;
    let entry = entry.to_str()?;
    if entry.ends_with("/@openai/codex/bin/codex.js") {
        Some("codex")
    } else if entry.ends_with("/@anthropic-ai/claude-code/cli.js") {
        Some("claude")
    } else {
        None
    }
}
fn groups(pid: u32) -> Option<(u32, u32, u32)> {
    let mut bytes = [0u8; 136];
    unsafe extern "C" {
        fn proc_pidinfo(
            pid: i32,
            flavor: i32,
            arg: u64,
            buffer: *mut libc::c_void,
            size: i32,
        ) -> i32;
    }
    if unsafe { proc_pidinfo(pid as i32, 3, 0, bytes.as_mut_ptr().cast(), 136) } != 136 {
        return None;
    }
    Some((
        u32::from_ne_bytes(bytes[100..104].try_into().ok()?),
        u32::from_ne_bytes(bytes[112..116].try_into().ok()?),
        u32::from_ne_bytes(bytes[108..112].try_into().ok()?),
    ))
}
pub(crate) fn agent_image(pid: u32, pane: u32, path: &Path) -> Option<char> {
    let (group, _, tty) = groups(pid)?;
    let (_, foreground, root_tty) = groups(pane)?;
    if foreground == 0 || group != foreground || tty != root_tty {
        return None;
    }
    let name = path.file_name()?.to_str()?;
    if name == "agy" {
        return Some('>');
    }
    match app(pid,path)? {
        "claude"=>Some('❯'),
        "codex" if name=="node" || crate::model_guard::re(r"/@openai/codex(?:/node_modules/@openai/codex-[^/]+)?/vendor/[^/]+/(?:bin/)?codex$").is_match(&path.to_string_lossy())=>Some('›'),
        _=>None,
    }
}
pub(crate) fn detail(pid: u32) -> identity::Result<String> {
    let process = identity::kernel_process(pid).ok_or("foreground ancestry changed")?;
    let groups = groups(pid).ok_or("foreground group unavailable")?;
    let argv = arguments(pid).ok_or("foreground arguments unavailable")?;
    Ok(format!("{process:?}:{groups:?}:{argv:?}"))
}
