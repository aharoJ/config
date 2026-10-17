use super::*;
use std::os::unix::fs::symlink;

#[test]
fn relay_start_refuses_unknown_transport_before_routing() {
    for kind in ["unknown", "agy", "", "ASTRA"] {
        assert_eq!(
            relay_start(&Value::Null, &json!({"transport":kind})).unwrap_err(),
            "unsupported transport"
        );
    }
}

#[test]
fn parser_preserves_documented_phases_and_argument_exits() {
    assert!(parse(&[]).is_err());
    assert!(parse(&["--help".into()]).unwrap().is_none());
    for phase in [
        "prepare", "launch", "own", "wait", "collect", "retain", "verify", "cleanup",
    ] {
        assert!(parse(&[phase.into()]).is_err());
    }
    let args = ["prepare", "--request=a", "--batch", "b", "--sha256", "c"].map(str::to_owned);
    let (phase, opts) = parse(&args).unwrap().unwrap();
    assert_eq!(phase, "prepare");
    assert_eq!(opts["request"], "a");
    assert_eq!(opts["batch"], "b");
    assert_eq!(opts["sha256"], "c");
    assert!(parse(
        &[
            "prepare",
            "--request",
            "a",
            "--batch",
            "b",
            "--sha256",
            "c",
            "--unknown",
            "d"
        ]
        .map(str::to_owned)
    )
    .is_err());
}

#[test]
fn launch_claim_key_matches_the_legacy_sorted_encoding() {
    let request = json!({"project_root":"/fixtures/project","topic":"topic","cycle_type":"implementation","cycle":"c","round":1});
    let expected=hash(br#"{"cycle": "c", "cycle_type": "implementation", "project_root": "/fixtures/project", "round": 1, "topic": "topic"}"#);
    assert_eq!(
        slot(&request).unwrap().file_name().unwrap(),
        format!("{expected}.json").as_str()
    );
    let unicode = merge(request, json!({"cycle":"é😀"}));
    let expected=hash(br#"{"cycle": "\u00e9\ud83d\ude00", "cycle_type": "implementation", "project_root": "/fixtures/project", "round": 1, "topic": "topic"}"#);
    assert_eq!(
        slot(&unicode).unwrap().file_name().unwrap(),
        format!("{expected}.json").as_str()
    );
}

#[test]
fn evidence_requires_stable_real_bytes_closed_hashes_and_exclusive_output() {
    let root = home().unwrap().join("desk/tmp").join(format!(
        "panel-evidence-test-{}",
        crate::runtime::fresh_id().unwrap()
    ));
    fs::create_dir(&root).unwrap();
    let path = root.join("proof.json");
    let reference = fresh(&path, &json!({"proof":true})).unwrap();
    assert_eq!(read(&reference).unwrap(), json!({"proof":true}));
    assert!(fresh(&path, &json!({"replace":true})).is_err());
    assert_eq!(fs::metadata(&path).unwrap().mode() & 0o777, 0o444);
    assert!(read(&merge(reference.clone(), json!({"extra":true}))).is_err());
    assert!(read(&merge(reference.clone(), json!({"sha256":"0".repeat(64)}))).is_err());
    let link = root.join("link.json");
    symlink(&path, &link).unwrap();
    assert!(path_bytes(&link).is_err());
    let directory = root.join("linked-directory");
    symlink(&root, &directory).unwrap();
    assert!(path_bytes(&directory.join("proof.json")).is_err());
    assert!(path_bytes(&root.join("../proof.json")).is_err());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn strict_json_rejects_ambiguity_without_treating_quoted_braces_as_depth() {
    for bytes in [
        br#"{"a":1,"a":2}"#.as_slice(),
        br#"{"x":NaN}"#,
        br#"{"x":Infinity}"#,
        br#"{"x":1} trailing"#,
    ] {
        assert!(decode(bytes).is_err());
    }
    assert!(decode(format!("{}0{}", "[".repeat(33), "]".repeat(33)).as_bytes()).is_err());
    assert!(decode(format!("{}0{}", "[".repeat(32), "]".repeat(32)).as_bytes()).is_ok());
    assert!(decode(br#"{"x":"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["}"#).is_ok());
}
