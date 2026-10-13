use super::*;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

fn fixture() -> (Prepared, PathBuf) {
    static SERIAL: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let path = PathBuf::from(std::env::var_os("HOME").expect("HOME required"))
        .join("desk/tmp")
        .join(format!(
            "angelstar-publication-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            SERIAL.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
    std::fs::create_dir(&path).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
    let target = Target {
        session_id: crate::target::SessionId(10),
        session_name: "config:会".into(),
        window: crate::target::Window {
            id: crate::target::WindowId(11),
            name: "receiver".into(),
        },
        pane: crate::target::Pane {
            id: crate::target::PaneId(12),
            pid: 123,
            dead: false,
        },
    };
    let envelope = envelope(
        Some(&target),
        "#k04 exact \"message\"\nnext 会🦀 #extra",
        "unused",
    )
    .unwrap();
    (
        Prepared {
            target: target.clone(),
            source: Some(target),
            envelope,
            ancestry: Vec::new(),
            server: None,
        },
        path,
    )
}

#[test]
fn precommit_faults_remove_pending_and_postcommit_faults_preserve_identity() {
    for phase in [
        "permissions",
        "metadata",
        "directory-sync",
        "verification",
        "root-recheck",
    ] {
        let (prepared, directory) = fixture();
        let id = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
        let result = prepared.publish_with_check(&directory, id, |at| {
            if at == phase {
                Err(std::io::ErrorKind::Interrupted.into())
            } else {
                Ok(())
            }
        });
        let entries = std::fs::read_dir(&directory)
            .unwrap()
            .map(|row| row.unwrap().path())
            .collect::<Vec<_>>();
        let path = directory.join(format!("{id}.json"));
        let valid = if matches!(phase, "permissions" | "metadata") {
            entries.is_empty()
                && matches!(
                    result,
                    Err(Error::Publication(std::io::ErrorKind::Interrupted))
                )
        } else {
            entries == [path.clone()]
                && matches!(result, Err(Error::PublicationCommittedUncertain { path: ref actual, cause: std::io::ErrorKind::Interrupted }) if actual == &path)
        };
        for entry in entries {
            std::fs::remove_file(entry).unwrap();
        }
        std::fs::remove_dir(directory).unwrap();
        assert!(valid, "{phase}: {result:?}");
    }
}

#[test]
fn inheritable_acl_is_rejected_even_with_private_mode_bits() {
    let (prepared, directory) = fixture();
    assert!(std::process::Command::new("/bin/chmod")
        .args([
            "+a",
            "everyone allow list,add_file,search,read,write,file_inherit"
        ])
        .arg(&directory)
        .status()
        .unwrap()
        .success());
    let result = prepared.publish(&directory, "ffffffffffffffffffffffffffffffff");
    let private_mode = std::fs::metadata(&directory).unwrap().permissions().mode() & 0o777 == 0o700;
    let empty = std::fs::read_dir(&directory).unwrap().next().is_none();
    assert!(std::process::Command::new("/bin/chmod")
        .arg("-N")
        .arg(&directory)
        .status()
        .unwrap()
        .success());
    std::fs::remove_dir(directory).unwrap();
    assert!(
        empty && private_mode && matches!(result, Err(Error::InvalidStore)),
        "{result:?}"
    );
}

#[test]
fn staged_acl_is_rejected_and_owned_pending_is_removed() {
    let (prepared, directory) = fixture();
    let result =
        prepared.publish_with_check(&directory, "11111111111111111111111111111111", |phase| {
            if phase == "permissions" {
                let pending = std::fs::read_dir(&directory)?.next().unwrap()?.path();
                assert!(std::process::Command::new("/bin/chmod")
                    .args(["+a", "everyone allow read,write"])
                    .arg(pending)
                    .status()?
                    .success());
            }
            Ok(())
        });
    let empty = std::fs::read_dir(&directory).unwrap().next().is_none();
    std::fs::remove_dir(directory).unwrap();
    assert!(
        empty
            && matches!(
                result,
                Err(Error::Publication(std::io::ErrorKind::PermissionDenied))
            ),
        "{result:?}"
    );
}

#[test]
fn postcommit_acl_change_is_uncertain_not_retryable_publication_failure() {
    let (prepared, directory) = fixture();
    let id = "22222222222222222222222222222222";
    let result = prepared.publish_with_check(&directory, id, |phase| {
        if phase == "verification" {
            assert!(std::process::Command::new("/bin/chmod")
                .args(["+a", "everyone allow list,search"])
                .arg(&directory)
                .status()?
                .success());
        }
        Ok(())
    });
    let path = directory.join(format!("{id}.json"));
    let valid = path.is_file()
        && matches!(result, Err(Error::PublicationCommittedUncertain { path: ref actual, cause: std::io::ErrorKind::PermissionDenied }) if actual == &path);
    assert!(std::process::Command::new("/bin/chmod")
        .arg("-N")
        .arg(&directory)
        .status()
        .unwrap()
        .success());
    std::fs::remove_file(path).unwrap();
    std::fs::remove_dir(directory).unwrap();
    assert!(valid, "{result:?}");
}

#[test]
fn published_record_roundtrips_full_payload_and_no_input_state() {
    let (prepared, directory) = fixture();
    let result = prepared.publish(&directory, "0123456789abcdef0123456789abcdef");
    eprintln!(
        "publication owned-root {} result {result:?}",
        directory.display()
    );
    if let Ok(value) = &result {
        let output = std::process::Command::new("jq")
            .args(["-j", ".full_message"])
            .arg(&value.path)
            .output()
            .unwrap();
        assert!(output.status.success());
        assert_eq!(output.stdout, prepared.envelope.render().as_bytes());
        let status = std::process::Command::new("jq").args(["-e", ".schema == \"angelstar-message\" and .version == 1 and .state == \"archived-no-input\" and .codes == [\"k04\",\"extra\"] and .target.session_id == \"10\""]).arg(&value.path).status().unwrap();
        assert!(status.success());
        assert!(value.pointer.contains("#k04 #extra -- full:"));
        assert!(value.pointer.contains(value.path.to_str().unwrap()));
        assert_eq!(
            std::fs::metadata(&value.path).unwrap().permissions().mode() & 0o777,
            0o600
        );
        std::fs::remove_file(&value.path).unwrap();
    }
    std::fs::remove_dir(&directory).unwrap();
    assert!(result.is_ok(), "{result:?}");
}

#[test]
fn publication_collision_never_replaces_existing_record() {
    let (prepared, directory) = fixture();
    let id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let path = directory.join(format!("{id}.json"));
    std::fs::write(&path, "foreign prior record").unwrap();
    let result = prepared.publish(&directory, id);
    eprintln!(
        "publication collision owned-root {} result {result:?}",
        directory.display()
    );
    assert_eq!(
        std::fs::read_to_string(&path).unwrap(),
        "foreign prior record"
    );
    std::fs::remove_file(path).unwrap();
    std::fs::remove_dir(&directory).unwrap();
    assert!(matches!(
        result,
        Err(Error::Publication(std::io::ErrorKind::AlreadyExists))
    ));
}

#[test]
fn nonprivate_and_symlink_store_paths_are_not_publish_targets() {
    let (prepared, directory) = fixture();
    let id = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    std::fs::set_permissions(&directory, std::fs::Permissions::from_mode(0o755)).unwrap();
    assert!(matches!(
        prepared.publish(&directory, id),
        Err(Error::InvalidStore)
    ));
    std::fs::set_permissions(&directory, std::fs::Permissions::from_mode(0o700)).unwrap();
    let link = directory.with_extension("link");
    std::os::unix::fs::symlink(&directory, &link).unwrap();
    let result = prepared.publish(&link, id);
    std::fs::remove_file(link).unwrap();
    std::fs::remove_dir(directory).unwrap();
    assert!(matches!(result, Err(Error::InvalidStore)));
}

#[test]
fn record_id_cannot_escape_the_owned_directory() {
    let (prepared, directory) = fixture();
    let results = [
        "",
        "../escape",
        "abc",
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "0123456789abcdef0123456789abcde\n",
    ]
    .map(|id| {
        matches!(
            prepared.publish(&directory, id),
            Err(Error::InvalidRecordId)
        )
    });
    std::fs::remove_dir(directory).unwrap();
    assert!(results.into_iter().all(|ok| ok));
}

#[test]
fn existing_record_symlink_is_not_followed_or_replaced() {
    let (prepared, directory) = fixture();
    let canary = directory.join("canary");
    std::fs::write(&canary, "untouched").unwrap();
    let id = "cccccccccccccccccccccccccccccccc";
    let path = directory.join(format!("{id}.json"));
    std::os::unix::fs::symlink(&canary, &path).unwrap();
    let result = prepared.publish(&directory, id);
    let unchanged = std::fs::read_to_string(&canary).unwrap() == "untouched";
    let still_link = std::fs::symlink_metadata(&path).unwrap().is_symlink();
    std::fs::remove_file(path).unwrap();
    std::fs::remove_file(canary).unwrap();
    std::fs::remove_dir(directory).unwrap();
    assert!(unchanged && still_link);
    assert!(matches!(
        result,
        Err(Error::Publication(std::io::ErrorKind::AlreadyExists))
    ));
}

#[test]
fn json_record_preserves_controls_unicode_and_large_numeric_ids_exactly() {
    let (mut prepared, directory) = fixture();
    prepared.target.session_id = crate::target::SessionId(u64::MAX);
    prepared.envelope = envelope(
        None,
        "#k04 \u{0}\u{1}\u{8}\u{c}\u{1f} \u{5c}\u{22}会🦀\n\r\t",
        "unused",
    )
    .unwrap();
    let result = prepared.publish(&directory, "dddddddddddddddddddddddddddddddd");
    let mut valid = false;
    if let Ok(value) = &result {
        let full = std::process::Command::new("jq")
            .args(["-j", ".full_message"])
            .arg(&value.path)
            .output()
            .unwrap();
        let sid = std::process::Command::new("jq")
            .args(["-j", ".target.session_id"])
            .arg(&value.path)
            .output()
            .unwrap();
        valid = full.status.success()
            && full.stdout == prepared.envelope.render().as_bytes()
            && sid.stdout == u64::MAX.to_string().as_bytes();
        std::fs::remove_file(&value.path).unwrap();
    }
    std::fs::remove_dir(directory).unwrap();
    assert!(valid, "{result:?}");
}
