use crate::identity;
use std::path::{Path, PathBuf};

fn process_arguments(pid: u32) -> Option<(PathBuf, Vec<String>)> {
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
    let executable = PathBuf::from(std::str::from_utf8(&bytes[4..at]).ok()?);
    if !executable.is_absolute() {
        return None;
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
    Some((executable, result))
}
fn arguments(pid: u32) -> Option<Vec<String>> {
    Some(process_arguments(pid)?.1)
}
pub(crate) fn executable_path(pid: u32) -> Option<PathBuf> {
    Some(process_arguments(pid)?.0)
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
pub(crate) fn foreground(pid: u32, pane: u32) -> bool {
    let Some((group, _, tty)) = groups(pid) else {
        return false;
    };
    let Some((_, foreground, root_tty)) = groups(pane) else {
        return false;
    };
    foreground != 0 && group == foreground && tty == root_tty
}
pub(crate) fn agent_image(pid: u32, pane: u32, path: &Path) -> Option<char> {
    if !foreground(pid, pane) {
        return None;
    }
    let name = path.file_name()?.to_str()?;
    if native_agy_path(path, &identity::account_home().ok()?) {
        return Some('>');
    }
    match app(pid,path)? {
        "claude"=>Some('❯'),
        "codex" if name=="node" || crate::model_guard::re(r"/@openai/codex(?:/node_modules/@openai/codex-[^/]+)?/vendor/[^/]+/(?:bin/)?codex$").is_match(&path.to_string_lossy())=>Some('›'),
        _=>None,
    }
}
pub(crate) fn native_codex_path(path: &Path) -> bool {
    path.to_str().is_some_and(|path| {
        crate::model_guard::re(r"/node_modules/@openai/codex(?:/node_modules/@openai/codex-[^/]+)?/vendor/[^/]+/(?:bin/)?codex$")
            .is_match(path)
    })
}
fn native_agy_path(path: &Path, home: &Path) -> bool {
    let installed = home.join(".local/bin/agy");
    path == installed || std::fs::canonicalize(&installed).is_ok_and(|resolved| resolved == path)
}
fn native_relay_path(path: &Path, home: &Path) -> Option<char> {
    if native_agy_path(path, home) {
        return Some('>');
    }
    if path == home.join(".local/bin/claude")
        || (path.parent()? == home.join(".local/share/claude/versions")
            && crate::model_guard::re(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][\w.-]+)?$")
                .is_match(path.file_name()?.to_str()?))
    {
        return Some('❯');
    }
    native_codex_path(path).then_some('›')
}
pub(crate) fn relay_image(pid: u32, pane: u32, path: &Path) -> Option<char> {
    let expected = native_relay_path(path, &identity::account_home().ok()?)?;
    (agent_image(pid, pane, path)? == expected).then_some(expected)
}

pub(crate) fn detail(pid: u32) -> identity::Result<String> {
    let process = identity::kernel_process(pid).ok_or("foreground ancestry changed")?;
    let groups = groups(pid).ok_or("foreground group unavailable")?;
    let argv = arguments(pid).ok_or("foreground arguments unavailable")?;
    Ok(format!("{process:?}:{groups:?}:{argv:?}"))
}

#[cfg(test)]
mod relay_tests {
    use super::*;
    #[test]
    #[ignore = "read-only kernel executable evidence for an explicitly selected process"]
    fn live_kernel_executable() {
        let pid = std::env::var("ANGELSTAR_BIND_NATIVE_PID")
            .unwrap()
            .parse()
            .unwrap();
        println!(
            "kernel executable: {}",
            executable_path(pid).unwrap().display()
        );
    }
    #[test]
    fn native_agy_install_and_resolved_target_without_version_pins() {
        let home = identity::account_home()
            .unwrap()
            .join("desk/tmp")
            .join(format!(
                "agy-admission-{}",
                crate::runtime::fresh_id().unwrap()
            ));
        let installed = home.join(".local/bin/agy");
        std::fs::create_dir_all(installed.parent().unwrap()).unwrap();
        let other = std::env::current_exe().unwrap();
        std::fs::hard_link(&other, &installed).unwrap();
        assert_eq!(native_relay_path(&installed, &home), Some('>'));
        for version in ["1.3.6", "1.4.0"] {
            let target = home.join(format!("agy-{version}"));
            if version == "1.3.6" {
                std::fs::rename(&installed, &target).unwrap();
            } else {
                std::fs::rename(&installed, home.join("previous-link")).unwrap();
                std::fs::hard_link(&other, &target).unwrap();
            }
            std::os::unix::fs::symlink(&target, &installed).unwrap();
            assert_eq!(native_relay_path(&target, &home), Some('>'));
            assert_eq!(native_relay_path(&installed, &home), Some('>'));
        }
        assert_eq!(native_relay_path(&other, &home), None);
        assert_eq!(native_relay_path(Path::new("/bin/sh"), &home), None);
        assert!(std::process::Command::new("/usr/bin/trash")
            .arg(&home)
            .status()
            .unwrap()
            .success());
    }
    #[test]
    #[ignore = "explicitly authorized installed Agy images; never launches a client"]
    fn installed_agy_images_have_version_agnostic_admission() {
        let root = identity::account_home()
            .unwrap()
            .join("desk/tmp")
            .join(format!(
                "agy-installed-{}",
                crate::runtime::fresh_id().unwrap()
            ));
        for key in ["ANGELSTAR_AGY_OLD_IMAGE", "ANGELSTAR_AGY_NEW_IMAGE"] {
            let image = std::fs::canonicalize(std::env::var_os(key).unwrap()).unwrap();
            let home = root.join(key);
            let installed = home.join(".local/bin/agy");
            std::fs::create_dir_all(installed.parent().unwrap()).unwrap();
            std::os::unix::fs::symlink(&image, &installed).unwrap();
            assert_eq!(native_relay_path(&image, &home), Some('>'));
            assert_eq!(native_relay_path(&installed, &home), Some('>'));
            assert_eq!(
                native_relay_path(&std::env::current_exe().unwrap(), &home),
                None
            );
            println!("admitted native Agy image: {}", image.display());
        }
        assert!(std::process::Command::new("/usr/bin/trash")
            .arg(root)
            .status()
            .unwrap()
            .success());
    }
    #[test]
    fn native_relay_versions_and_non_client_paths() {
        assert_eq!(
            crate::composer::classify(
                include_str!("../tests/fixtures/claude-native302-idle.ansi"),
                '❯',
                2,
                8,
                149
            ),
            crate::composer::Composer::EmptyCandidate
        );
        let home = Path::new("/test-account");
        assert_eq!(
            native_relay_path(&home.join(".local/bin/claude"), home),
            Some('❯')
        );
        for version in ["2.1.296", "2.1.302", "3.20.100", "3.0.0-beta.1"] {
            assert_eq!(
                native_relay_path(
                    &home.join(format!(".local/share/claude/versions/{version}")),
                    home
                ),
                Some('❯')
            );
        }
        let codex = home.join(".local/share/fnm/node-versions/v22.19.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex");
        assert_eq!(native_relay_path(&codex, home), Some('›'));
        for path in [
            "/bin/sleep",
            "/tmp/claude",
            "/other-account/.local/share/claude/versions/2.1.302",
            "/test-account/.local/share/claude/versions/latest",
            "/test-account/.local/share/claude/versions/2.1.302/claude",
            "/tmp/node_modules/@openai/codex/vendor/aarch64-apple-darwin/bin/codex-code-mode-host",
        ] {
            assert_eq!(native_relay_path(Path::new(path), home), None, "{path}");
        }
        assert!(relay_image(
            std::process::id(),
            std::process::id(),
            &std::env::current_exe().unwrap()
        )
        .is_none());
        assert!(identity::Client::bind(std::process::id()).is_err());
    }
    #[test]
    fn pinned_deepseek_claude_is_refused() {
        let home = Path::new("/test-account");
        for relative in [
            ".local/cc-pinned-2.1.153/node_modules/.bin/claude",
            ".local/cc-pinned-2.1.153/node_modules/@anthropic-ai/claude-code/bin/claude.exe",
        ] {
            let path = home.join(relative);
            assert_eq!(native_relay_path(&path, home), None, "{relative}");
            assert_eq!(native_relay_path(&path, Path::new("/other-account")), None);
        }
    }
}
