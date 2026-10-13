#![cfg(target_os = "macos")]

use angelstar_runtime::target::{kernel_ancestry, kernel_process};

#[test]
fn kernel_identity_has_real_generation_and_stable_self_pid() {
    let pid = std::process::id();
    let first = kernel_process(pid).unwrap();
    assert_eq!(first.pid, pid);
    assert!(first.parent > 0);
    assert!(first.start_seconds > 0);
    assert!(first.start_microseconds < 1_000_000);
    assert_eq!(kernel_process(pid), Some(first));
}

#[test]
fn kernel_parent_is_observed_for_an_owned_child_and_disappears_after_reap() {
    let mut child = std::process::Command::new("/bin/sleep")
        .arg("10")
        .spawn()
        .unwrap();
    let pid = child.id();
    let observed = kernel_process(pid);
    child.kill().unwrap();
    child.wait().unwrap();
    let identity = observed.unwrap();
    assert_eq!(identity.pid, pid);
    assert_eq!(identity.parent, std::process::id());
    assert!(identity.start_seconds > 0);
    assert_eq!(kernel_process(pid), None);
}

#[test]
fn invalid_kernel_pid_is_not_coerced_to_another_process() {
    assert_eq!(kernel_process(0), None);
    assert_eq!(kernel_process(u32::MAX), None);
}

#[test]
fn kernel_ancestry_joins_real_parent_edges_and_rechecks_generations() {
    let pid = std::process::id();
    let chain = kernel_ancestry(pid).unwrap();
    assert_eq!(chain[0].pid, pid);
    assert_eq!(chain.last().unwrap().parent, 1);
    let ids = chain
        .iter()
        .map(|row| row.pid)
        .collect::<std::collections::HashSet<_>>();
    assert_eq!(ids.len(), chain.len());
    for pair in chain.windows(2) {
        assert_eq!(pair[0].parent, pair[1].pid);
    }
    for row in chain {
        assert_eq!(kernel_process(row.pid), Some(row));
    }
}

#[test]
fn missing_kernel_ancestry_does_not_invent_a_parent() {
    assert_eq!(kernel_ancestry(0), None);
    assert_eq!(kernel_ancestry(u32::MAX), None);
}
