use angelstar_runtime::composer::{classify, Composer};
use std::process::Command;

#[test]
#[ignore = "requires ANGELSTAR_CORPUS pointing to the frozen historical corpus and jq"]
fn historical_corpus() {
    let root = std::path::PathBuf::from(std::env::var("ANGELSTAR_CORPUS").unwrap());
    let manifest = root.join("manifest.json");
    let hash = Command::new("shasum")
        .args(["-a", "256"])
        .arg(&manifest)
        .output()
        .unwrap();
    assert!(hash.status.success());
    assert!(String::from_utf8(hash.stdout)
        .unwrap()
        .starts_with("4ea87002e5202a5f4d11b82264b3ffa1ccee5f97b6d0c8dd16d93981236c8bdc "));
    let output = Command::new("jq").args(["-j", ".cases[] | [.name, (.capture_file // \"\"), (.capture // \"\"), (.glyph // \"›\"), .cursor_x, .cursor_y, (.pane_width // 167), .input_exit, .capture_sha256] | .[] | tostring, \"\\u0000\""])
        .arg(&manifest).output().unwrap();
    assert!(output.status.success());
    let fields: Vec<&str> = std::str::from_utf8(&output.stdout)
        .unwrap()
        .split_terminator('\0')
        .collect();
    assert_eq!(fields.len(), 52 * 9);
    let mut mismatches = Vec::new();
    let mut corrected_startup_cases = 0;
    for case in fields.chunks_exact(9) {
        let capture = if case[1].is_empty() {
            case[2].to_owned()
        } else {
            let path = root.join(case[1]);
            let hash = Command::new("shasum")
                .args(["-a", "256"])
                .arg(&path)
                .output()
                .unwrap();
            assert!(hash.status.success());
            assert!(String::from_utf8(hash.stdout)
                .unwrap()
                .starts_with(&format!("{} ", case[8])));
            std::fs::read_to_string(path).unwrap()
        };
        let got = classify(
            &capture,
            case[3].chars().next().unwrap(),
            case[4].parse().unwrap(),
            case[5].parse().unwrap(),
            case[6].parse().unwrap(),
        );
        let expected_empty = if case[0] == "sol-startup-without-footer" {
            assert_eq!(case[7], "1");
            assert_eq!(case[8], "17e0ed7b7e063e1b4327b67e8155e54c2913a0af210bc65b938cb4e56570a107");
            corrected_startup_cases += 1;
            true
        } else {
            case[7] == "0"
        };
        if (got == Composer::EmptyCandidate) != expected_empty {
            mismatches.push(format!(
                "{}: expected exit {}, got {got:?}",
                case[0], case[7]
            ));
        }
    }
    assert_eq!(corrected_startup_cases, 1);
    assert!(
        mismatches.is_empty(),
        "{} /52 mismatches:\n{}",
        mismatches.len(),
        mismatches.join("\n")
    );
}
