use super::*;
fn schema() -> Value {
    decode(include_bytes!("../fixtures/panel-ledger.schema.json")).unwrap()
}
fn seat() -> Value {
    decode(include_bytes!("../fixtures/panel-collected-seat.json")).unwrap()
}
#[test]
fn real_collected_seat_matches_protocol_schema() {
    let rules = schema();
    assert!(validate(&seat(), &rules["$defs"]["agentic_seat"], &rules)
        .unwrap()
        .is_empty());
}
#[test]
fn all_seat_required_fields_are_checked() {
    let rules = schema();
    for key in list(&rules["$defs"]["agentic_seat"]["required"]) {
        let mut value = seat();
        value.as_object_mut().unwrap().remove(key.as_str().unwrap());
        assert!(
            !validate(&value, &rules["$defs"]["agentic_seat"], &rules)
                .unwrap()
                .is_empty(),
            "{key}"
        );
    }
}
#[test]
fn closed_seat_and_attempts_refuse_unknown_fields() {
    let rules = schema();
    for attempt in [false, true] {
        let mut value = seat();
        let target = if attempt {
            &mut value["attempts"][0]
        } else {
            &mut value
        };
        target["unknown"] = json!(true);
        assert!(!validate(&value, &rules["$defs"]["agentic_seat"], &rules)
            .unwrap()
            .is_empty());
    }
}
#[test]
fn scalar_types_enums_lengths_and_attempt_limit() {
    let rules = schema();
    for (key, v) in [
        ("seat_id", json!("")),
        ("admitted", json!(1)),
        ("raw_verdict", json!("UNKNOWN")),
        ("attempt_id", json!(false)),
        ("floor_cause", json!("")),
        ("attempts", json!(vec![seat()["attempts"][0].clone(); 17])),
    ] {
        let mut value = seat();
        value[key] = v;
        assert!(
            !validate(&value, &rules["$defs"]["agentic_seat"], &rules)
                .unwrap()
                .is_empty(),
            "{key}"
        );
    }
}
#[test]
fn references_hash_absolute_path_and_required_binding() {
    let rules = schema();
    for v in [
        json!({"path":"relative","sha256":"a".repeat(64)}),
        json!({"path":"/fixtures/a","sha256":"A".repeat(64)}),
        json!({"path":"/fixtures/a","sha256":"a".repeat(63)}),
        json!({"path":"/fixtures/a"}),
    ] {
        assert!(!validate(&v, &rules["$defs"]["evidence_ref"], &rules)
            .unwrap()
            .is_empty());
    }
}
#[test]
fn supersession_and_native_reference_conditions() {
    let rules = schema();
    let mut value = seat()["attempts"][0].clone();
    value["status"] = json!("superseded");
    assert!(
        !validate(&value, &rules["$defs"]["agentic_attempt"], &rules)
            .unwrap()
            .is_empty()
    );
    value["supersession_ref"] = value["admission_ref"].clone();
    assert!(validate(&value, &rules["$defs"]["agentic_attempt"], &rules)
        .unwrap()
        .is_empty());
    value["native_session_ref"] = Value::Null;
    assert!(
        !validate(&value, &rules["$defs"]["agentic_attempt"], &rules)
            .unwrap()
            .is_empty()
    );
}
#[test]
fn qualified_activation_requires_both_independent_proofs() {
    let rules = schema();
    let mut value = json!({"mode":"qualified","first_round":1,"authorization_ref":null,"qualification_ref":null});
    assert!(
        !validate(&value, &rules["$defs"]["agentic_activation"], &rules)
            .unwrap()
            .is_empty()
    );
    let reference = seat()["attempts"][0]["admission_ref"].clone();
    value["authorization_ref"] = reference.clone();
    value["qualification_ref"] = reference;
    assert!(
        validate(&value, &rules["$defs"]["agentic_activation"], &rules)
            .unwrap()
            .is_empty()
    );
}
#[test]
fn actual_schema_preflight_and_normal_form() {
    let root = schema();
    preflight(&root, &root, &HashSet::new(), &mut HashSet::new(), 0).unwrap();
    normal_form(&root).unwrap();
}
#[test]
fn preflight_checks_untaken_branches_and_keyword_shapes() {
    for extra in [
        json!({"maximum":1}),
        json!({"type":"objct"}),
        json!({"minItems":true}),
        json!({"minLength":-1}),
        json!({"additionalProperties":[]}),
        json!({"items":[]}),
        json!({"anyOf":[]}),
        json!({"required":[1]}),
        json!({"type":["object","object"]}),
        json!({"minimum":false}),
        json!({"pattern":"["}),
        json!({"$ref":"https://invalid.test/"}),
    ] {
        let mut root = schema();
        root["$defs"]["unused"] = extra;
        assert!(preflight(&root, &root, &HashSet::new(), &mut HashSet::new(), 0).is_err());
    }
}
#[test]
fn preflight_refuses_same_scope_reference_cycles() {
    let mut root = schema();
    root["$defs"]["unused"] = json!({"allOf":[{"$ref":"#/$defs/unused"}]});
    assert!(preflight(&root, &root, &HashSet::new(), &mut HashSet::new(), 0).is_err());
}
#[test]
fn normal_form_refuses_hidden_requirements_and_undeclared_names() {
    for extra in [
        json!({"oneOf":[{"required":["hidden"]}]}),
        json!({"$ref":"#/$defs/hidden"}),
        json!({"if":true,"then":{"required":["hidden"]}}),
        json!({"required":["hidden"]}),
    ] {
        let mut root = schema();
        root["$defs"]["hidden"] = json!({"required":["hidden"]});
        root.as_object_mut()
            .unwrap()
            .extend(extra.as_object().unwrap().clone());
        assert!(normal_form(&root).is_err());
    }
}
#[test]
fn schema_truth_numbers_and_boolean_equality() {
    for (value, rules, expected) in [
        (json!(true), json!({"const":1}), false),
        (json!(1.0), json!({"type":"integer","const":1}), true),
        (json!([1, true]), json!({"uniqueItems":true}), true),
        (json!(null), json!(false), false),
        (json!("a"), json!({"not":{"const":"a"}}), false),
        (
            json!(1),
            json!({"$ref":"#/$defs/a","minimum":2,"$defs":{"a":{"type":"number"}}}),
            false,
        ),
    ] {
        assert_eq!(
            validate(&value, &rules, &rules).unwrap().is_empty(),
            expected
        );
    }
}
#[test]
fn schema_does_not_round_distinct_large_integer_constants() {
    let rules = json!({"const":9007199254740992u64});
    assert!(!validate(&json!(9007199254740993u64), &rules, &rules)
        .unwrap()
        .is_empty());
}
#[test]
fn canonical_nonblank_pattern_uses_ecma_whitespace() {
    let rules = json!({"pattern":"\\S"});
    assert!(!validate(&json!("\u{feff}"), &rules, &rules)
        .unwrap()
        .is_empty());
    assert!(validate(&json!("\u{85}"), &rules, &rules)
        .unwrap()
        .is_empty());
}
