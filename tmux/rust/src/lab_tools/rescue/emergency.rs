use super::*;
const SECONDS: u64 = 5;

#[cfg(test)]
pub(super) mod fixture;

pub(super) fn detach(c: &Config, e: &mut Evidence, p: &Proof<'_>) -> bool {
    #[cfg(test)]
    let mut trace = fixture::Trace::new(c, e, p);
    if socket_identity(&c.socket) != p.socket_id
        || lab::process_start(c.pid) != p.start
        || lab::path(c.pid)
            .and_then(|p| fs::canonicalize(p).ok())
            .as_deref()
            != Some(p.exe)
        || digest(p.exe).ok().as_deref() != Some(p.sha)
    {
        return false;
    }
    let owner = e.step(
        "emergency-socket-lsof",
        "/usr/sbin/lsof",
        &["-n", "-a", "-U", &c.socket.to_string_lossy()],
        2,
    );
    #[cfg(test)]
    trace.owner(&owner);
    if !owner.is_ok_and(|o| o.code == 0 && owners(&o.text()) == [c.pid]) {
        return false;
    }
    let uuid = e.step(
        "emergency-executable-uuid",
        "/usr/bin/dwarfdump",
        &["--uuid", &p.exe.to_string_lossy()],
        2,
    );
    #[cfg(test)]
    trace.uuid(&uuid);
    if !uuid.is_ok_and(|o| o.code == 0 && o.text().contains(p.uuid)) {
        return false;
    }
    let commands = [
        format!("process attach -p {}", c.pid),
        "process detach".into(),
        "quit".into(),
    ];
    #[cfg(test)]
    let commands = fixture::emergency_commands(commands.to_vec());
    #[cfg(test)]
    trace.begin(&commands, SECONDS);
    let result = e.debugger("emergency-detach", &commands, SECONDS);
    #[cfg(test)]
    trace.finished(&result, c.pid);
    result.is_ok_and(|o| o.code == 0 && o.text().contains(&format!("Process {} detached", c.pid)))
}
