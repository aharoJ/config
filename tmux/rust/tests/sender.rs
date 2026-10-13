use angelstar_runtime::target::*;
use std::collections::HashMap;

fn snapshot() -> Snapshot {
    Snapshot::parse(b"$1\t@2\t%3\t123\t0\t1:s1:w\n$4\t@5\t%6\t456\t0\t1:t1:x\n").unwrap()
}

#[test]
fn source_candidate_follows_process_ancestry_not_unrelated_panes() {
    let parents = HashMap::from([(999, 888), (888, 123), (123, 1)]);
    let candidate = source_candidate(&snapshot(), 999, &parents).unwrap();
    assert_eq!(candidate.session_id, SessionId(1));
    assert_eq!(candidate.window.id, WindowId(2));
    assert_eq!(candidate.pane.id, PaneId(3));
    assert_eq!(candidate.pane.pid, 123);
    assert_eq!(candidate.session_name, "s");
    assert_eq!(candidate.window.name, "w");
}

#[test]
fn nearest_matching_ancestor_wins() {
    let parents = HashMap::from([(999, 456), (456, 123), (123, 1)]);
    assert_eq!(
        source_candidate(&snapshot(), 999, &parents)
            .unwrap()
            .pane
            .id,
        PaneId(6)
    );
    assert_eq!(
        source_candidate(&snapshot(), 123, &parents)
            .unwrap()
            .pane
            .id,
        PaneId(3)
    );
}

#[test]
fn vanished_or_cyclic_ancestry_is_unattributed() {
    for parents in [
        HashMap::new(),
        HashMap::from([(999, 888)]),
        HashMap::from([(999, 888), (888, 999)]),
        HashMap::from([(999, 999)]),
        HashMap::from([(999, 1)]),
    ] {
        assert!(source_candidate(&snapshot(), 999, &parents).is_none());
    }
    for process in [0, 1, u32::MAX] {
        assert!(source_candidate(&snapshot(), process, &HashMap::new()).is_none());
    }
}

#[test]
fn linked_session_source_is_ambiguous_not_invented() {
    let snapshot =
        Snapshot::parse(b"$1\t@2\t%3\t123\t0\t1:s1:w\n$4\t@2\t%3\t123\t0\t1:t1:w\n").unwrap();
    assert!(source_candidate(&snapshot, 123, &HashMap::new()).is_none());
}

#[test]
fn duplicate_live_pid_is_ambiguous_and_dead_pid_is_not_source() {
    let duplicate =
        Snapshot::parse(b"$1\t@2\t%3\t123\t0\t1:s1:w\n$1\t@2\t%4\t123\t0\t1:s1:w\n").unwrap();
    assert!(source_candidate(&duplicate, 123, &HashMap::new()).is_none());
    let dead = Snapshot::parse(b"$1\t@2\t%3\t123\t1\t1:s1:w\n").unwrap();
    assert!(source_candidate(&dead, 123, &HashMap::new()).is_none());
}

#[test]
fn source_names_are_metadata_not_route_expressions() {
    let snapshot =
        Snapshot::parse("$9\t@8\t%7\t123\t0\t7:team::x16:会 #{pane_id}:x\n".as_bytes()).unwrap();
    let candidate = source_candidate(&snapshot, 123, &HashMap::new()).unwrap();
    assert_eq!(candidate.session_name, "team::x");
    assert_eq!(candidate.window.name, "会 #{pane_id}:x");
}

#[test]
fn incomplete_metadata_and_long_ancestry_are_bounded() {
    let mut missing_session = snapshot();
    missing_session.sessions.remove(&SessionId(1));
    assert!(source_candidate(&missing_session, 123, &HashMap::new()).is_none());
    let mut missing_panes = snapshot();
    missing_panes.panes.remove(&WindowId(2));
    assert!(source_candidate(&missing_panes, 123, &HashMap::new()).is_none());
    let mut parents = (999..30_999)
        .map(|pid| (pid, pid + 1))
        .collect::<HashMap<_, _>>();
    parents.insert(30_999, 123);
    assert_eq!(
        source_candidate(&snapshot(), 999, &parents)
            .unwrap()
            .pane
            .id,
        PaneId(3)
    );
}
