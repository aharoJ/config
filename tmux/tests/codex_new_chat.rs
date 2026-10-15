use super::*;

#[test]
fn kernel_group_matches_the_callers_own_session() {
    let (_, group, _) = identity::kernel_terminal(std::process::id()).unwrap();
    assert_eq!(group, unsafe { libc::getpgrp() } as u32);
}

#[test]
fn real_caller_routes_and_refusals() {
    for window in ["codex", "red", "terra", "rp-schema", "001"] {
        let args = vec![window.into()];
        let (socket, session, selected, profile) = parse_route(
            &args,
            Some("/private/tmp/tmux-501/default,1793,3"),
            Some("gwt"),
        )
        .unwrap();
        assert_eq!(socket, Path::new("/private/tmp/tmux-501/default"));
        assert_eq!(session, "gwt");
        assert_eq!(selected, window);
        assert!(profile.is_none());
        let error =
            parse_route(&args, Some("/private/tmp/tmux-501/default,1793,3"), None).unwrap_err();
        assert_eq!(error.0, 1);
        assert!(error.1.contains("CODEX_SEND_SESSION is required"));
    }
    for args in [vec![], vec!["config".into(), "terra".into()]] {
        assert_eq!(
            parse_route(&args, Some("/socket,0,0"), Some("config"))
                .unwrap_err()
                .1,
            "usage: codex-new-chat <window-name> [<model> <effort>]"
        );
    }
    for session in ["", "gwt:codex", "config.tt", "config tt"] {
        assert!(
            parse_route(&["codex".into()], Some("/socket,0,0"), Some(session))
                .unwrap_err()
                .1
                .contains("CODEX_SEND_SESSION")
        );
    }
    for window in ["", "gwt:codex", "has space", "@1", "%2"] {
        assert!(
            parse_route(&[window.into()], Some("/socket,0,0"), Some("config"))
                .unwrap_err()
                .1
                .contains("window name")
        );
    }
    assert!(parse_route(&["codex".into()], None, Some("config"))
        .unwrap_err()
        .1
        .contains("TMUX is not set"));
}

#[test]
fn explicit_recovery_profile_retains_fast_and_checkout() {
    for model in [
        "gpt-6.1-sol",
        "gpt-6-astra",
        "gpt-6-sol",
        "gpt-6-luna",
        "gpt-5.6-sol",
        "gpt-5.6-terra",
        "gpt-5.6-luna",
        "gpt-5.5",
    ] {
        for effort in ["low", "medium", "high", "xhigh", "max", "ultra"] {
            let args = ["red".into(), model.into(), effort.into()];
            let parsed = parse_route(&args, Some("/socket,0,0"), Some("config-tt"));
            if matches!(model, "gpt-6-luna" | "gpt-5.6-luna") && effort == "ultra" {
                assert!(parsed.is_err());
                continue;
            }
            let (_, _, _, profile) = parsed.unwrap();
            let desired =
                guard::desired("Fast on · GPT-6.1-Sol low · ~/some checkout", &profile).unwrap();
            assert!(desired.starts_with("Fast on · "));
            assert!(desired.ends_with(&format!(" {effort} · ~/some checkout")));
            assert_eq!(
                guard::footer_parts(&desired).unwrap().1.to_lowercase(),
                model
            );
        }
    }
    for (model, effort) in [
        ("GPT-6.1-Sol", "low"),
        ("unknown", "low"),
        ("gpt-6.1-sol", "bogus"),
    ] {
        let error =
            parse_route(&["red".into(), model.into(), effort.into()], None, None).unwrap_err();
        assert!(error.1.contains("unsupported model/effort"));
    }
}

#[test]
fn observation_binds_identity_geometry_and_checkout() {
    let before = State {
        mode: false,
        dead: false,
        pid: 1,
        command: "codex".into(),
        width: 215,
        height: 50,
        session: "config-tt".into(),
        window: "test".into(),
        x: 2,
        y: 9,
        tty: "/dev/ttys999".into(),
        cwd: "/checkout".into(),
    };
    let mut cursor = before.clone();
    cursor.x = 30;
    cursor.y = 15;
    assert!(before.same_target(&cursor));
    let mut mutations = vec![before.clone(); 10];
    mutations[0].mode = true;
    mutations[1].dead = true;
    mutations[2].pid = 2;
    mutations[3].command = "node".into();
    mutations[4].width = 80;
    mutations[5].height = 24;
    mutations[6].session = "other".into();
    mutations[7].window = "renamed".into();
    mutations[8].tty = "/dev/ttys998".into();
    mutations[9].cwd = "/other-checkout".into();
    assert!(mutations.iter().all(|after| !before.same_target(after)));
}
