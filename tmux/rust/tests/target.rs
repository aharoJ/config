use angelstar_runtime::target::*;

fn fixture() -> Snapshot {
    let mut s = Snapshot::default();
    s.sessions
        .insert(SessionId(2), "config::tmux-to-rust".into());
    s.sessions
        .insert(SessionId(3), "config::tmux-to-rust-sibling".into());
    s.windows.insert(
        SessionId(2),
        vec![Window {
            id: WindowId(8),
            name: "codex".into(),
        }],
    );
    s.windows.insert(
        SessionId(3),
        vec![Window {
            id: WindowId(9),
            name: "codex".into(),
        }],
    );
    s.panes.insert(
        WindowId(8),
        vec![Pane {
            id: PaneId(10),
            pid: 123,
            dead: false,
        }],
    );
    s.panes.insert(
        WindowId(9),
        vec![Pane {
            id: PaneId(11),
            pid: 124,
            dead: false,
        }],
    );
    s
}
#[test]
fn last_colon_route() {
    assert_eq!(
        split_route("config::tmux-to-rust:codex"),
        Ok(("config::tmux-to-rust", "codex"))
    );
}
#[test]
fn absent_route_separator() {
    assert_eq!(split_route("codex"), Err(Error::MissingWindow));
}
#[test]
fn exact_ids_not_name_expression() {
    let s = fixture();
    let t = resolve(&s, "config::tmux-to-rust", "codex", None).unwrap();
    assert_eq!(t.session_id, SessionId(2));
    assert_eq!(t.window.id, WindowId(8));
    assert_eq!(t.selector(), "%10");
}
#[test]
fn prefix_is_not_a_session_match() {
    assert_eq!(
        resolve(&fixture(), "config::tmux", "codex", None),
        Err(Error::MissingSession)
    );
}
#[test]
fn duplicate_session_is_ambiguous() {
    let mut s = fixture();
    s.sessions
        .insert(SessionId(4), "config::tmux-to-rust".into());
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "codex", None),
        Err(Error::AmbiguousSession)
    );
}
#[test]
fn duplicate_window_is_ambiguous() {
    let mut s = fixture();
    s.windows.get_mut(&SessionId(2)).unwrap().push(Window {
        id: WindowId(12),
        name: "codex".into(),
    });
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "codex", None),
        Err(Error::AmbiguousWindow)
    );
}
#[test]
fn split_pane_requires_selection() {
    let mut s = fixture();
    s.panes.get_mut(&WindowId(8)).unwrap().push(Pane {
        id: PaneId(12),
        pid: 125,
        dead: false,
    });
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "codex", None),
        Err(Error::AmbiguousPane)
    );
}
#[test]
fn explicit_pane_must_belong_to_window() {
    assert_eq!(
        resolve(
            &fixture(),
            "config::tmux-to-rust",
            "codex",
            Some(PaneId(11))
        ),
        Err(Error::MissingPane)
    );
}
#[test]
fn dead_pane_is_not_selected() {
    let mut s = fixture();
    s.panes.get_mut(&WindowId(8)).unwrap()[0].dead = true;
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "codex", None),
        Err(Error::MissingPane)
    );
}
#[test]
fn format_like_names_are_data() {
    let mut s = fixture();
    s.sessions.insert(SessionId(2), "x:#{pane_id},'".into());
    s.windows.get_mut(&SessionId(2)).unwrap()[0].name = "#{session_name}".into();
    let t = resolve(&s, "x:#{pane_id},'", "#{session_name}", None).unwrap();
    assert_eq!(t.selector(), "%10");
}
#[test]
fn numeric_name_is_an_exact_name() {
    let mut s = fixture();
    s.windows.get_mut(&SessionId(2)).unwrap()[0].name = "7".into();
    assert_eq!(
        resolve(&s, "config::tmux-to-rust", "7", None)
            .unwrap()
            .window
            .id,
        WindowId(8)
    );
}
#[test]
fn respawn_changes_snapshot() {
    let mut s = fixture();
    let expected = resolve(&s, "config::tmux-to-rust", "codex", None).unwrap();
    s.panes.get_mut(&WindowId(8)).unwrap()[0].pid = 999;
    assert_eq!(revalidate(&s, &expected), Err(Error::Changed));
}
