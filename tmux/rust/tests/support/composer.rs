use super::*;
#[test]
fn composer_rules() {
    let empty = "❯\u{a0}\n────────────────────\n";
    assert_eq!(classify(empty, '❯', 2, 0, 20), Composer::EmptyCandidate);
    assert_eq!(screen('❯', empty, 2, 0, 20, "relay: #x"), Screen::Empty);
    for (text, x) in [
        ("❯\u{a0}human-draft\n────────────────────\n", 13),
        ("❯\u{a0} \n────────────────────\n", 3),
        ("❯\u{a0}draft\nunknown\n", 7),
    ] {
        assert_ne!(classify(text, '❯', x, 0, 20), Composer::EmptyCandidate);
    }
    let staged = "❯\u{a0}relay: #x\n────────────────────\n";
    assert_eq!(
        screen('❯', staged, 11, 0, 20, "relay: #x"),
        Screen::Staged(b"relay: #x".to_vec())
    );
    for x in [0, 2, 10, 12] {
        assert_eq!(screen('❯', staged, x, 0, 20, "relay: #x"), Screen::Hold);
    }
    assert_eq!(screen('❯', staged, 11, 0, 20, "relay: #y"), Screen::Hold);
    assert_eq!(
        screen('❯', "unrecognized", 0, 0, 20, "relay: #x"),
        Screen::Hold
    );
    assert!(row("\x1b[8mhidden").is_err());
    assert!(row("\x1b[badm").is_err());
    let codex = "› relay: #x\n\n  model · context\n";
    assert_eq!(
        screen('›', codex, 11, 0, 40, "relay: #x"),
        Screen::Staged(b"relay: #x".to_vec())
    );
}
#[test]
fn historical_corpus() {
    use sha2::{Digest, Sha256};
    let root = std::path::PathBuf::from(std::env::var_os("HOME").unwrap())
        .join("desk")
        .join("audits/relay/rustify/review/keeper2-slice/corpus");
    let bytes = std::fs::read(root.join("manifest.json")).unwrap();
    assert_eq!(
        format!("{:x}", Sha256::digest(&bytes)),
        "4ea87002e5202a5f4d11b82264b3ffa1ccee5f97b6d0c8dd16d93981236c8bdc"
    );
    let manifest: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    let cases = manifest["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 52);
    for case in cases {
        let capture = match case["capture_file"].as_str() {
            Some(p) => {
                let raw = std::fs::read(root.join(p)).unwrap();
                assert_eq!(
                    format!("{:x}", Sha256::digest(&raw)),
                    case["capture_sha256"].as_str().unwrap()
                );
                String::from_utf8(raw).unwrap()
            }
            None => case["capture"].as_str().unwrap().to_owned(),
        };
        let glyph = case["glyph"]
            .as_str()
            .unwrap_or("›")
            .chars()
            .next()
            .unwrap();
        let x = case["cursor_x"].as_u64().unwrap() as usize;
        let y = case["cursor_y"].as_u64().unwrap() as usize;
        let width = case["pane_width"].as_u64().unwrap_or(167) as usize;
        let expected = case["input_exit"].as_i64().unwrap() == 0
            || case["name"] == "sol-startup-without-footer";
        assert_eq!(
            classify(&capture, glyph, x, y, width) == Composer::EmptyCandidate,
            expected,
            "{}",
            case["name"]
        );
    }
}
