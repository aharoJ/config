use super::*;
use std::os::unix::fs::symlink;

struct Fixture {
    base: PathBuf,
    root: PathBuf,
    identity: Value,
    dispatch: Value,
    ledger: Value,
    authority: Value,
    preserve: bool,
}
impl Fixture {
    fn new() -> Self {
        let base = home().unwrap().join("desk/tmp").join(format!(
            "p3x-protocol-{}",
            crate::runtime::fresh_id().unwrap()
        ));
        let root = base.join("project");
        fs::create_dir_all(root.join("reviews/schema")).unwrap();
        fs::write(
            root.join("reviews/schema/resolve-ledger.schema.json"),
            include_bytes!("../fixtures/panel-ledger.schema.json"),
        )
        .unwrap();
        let identity = json!({"topic":"config-dispatch-fixture","cycle_type":"implementation","cycle":"owned-native-control","round":4});
        let mut f = Self {
            base,
            root,
            identity,
            dispatch: json!({}),
            ledger: json!({}),
            authority: Value::Null,
            preserve: false,
        };
        let intake = f
            .root
            .join("reviews/config-dispatch-fixture/intakes/audit-r4.md");
        fs::create_dir_all(intake.parent().unwrap()).unwrap();
        fs::write(&intake, include_bytes!("../fixtures/panel-intake.md")).unwrap();
        let canonical = reference(&intake).unwrap();
        let manifest=f.put_path(&intake.with_extension("manifest.json"),&json!({"status":"PASS","output":intake,"sha256":format!("sha256:{}",canonical["sha256"].as_str().unwrap()),"bytes":fs::metadata(&intake).unwrap().len()}));
        let delivered = f.stream("delivered", include_bytes!("../fixtures/panel-intake.md"));
        let prompt = f.stream("prompt", b"Read the bound technical input.\n");
        let projection=f.proof("projection",json!({"canonical_input":canonical,"delivered_input":delivered,"exclusion_pass":true,"fidelity_pass":true}));
        let packet = json!({"canonical_input":canonical,"manifest":manifest,"delivered_input":delivered,"prompt":prompt,"projection_review":projection});
        let adapter = json!({"id":"config-panel-dispatch","version":"1","source_sha256":hash(include_bytes!("../fixtures/panel-ledger.schema.json"))});
        let launcher = f.proof(
            "launcher",
            json!({"adapter":adapter,"launcher_version":"1"}),
        );
        let policy = f.proof("policy", json!({"authorized":true}));
        let mut seat = decode(include_bytes!("../fixtures/panel-collected-seat.json")).unwrap();
        let native = f.stream("native", include_bytes!("../fixtures/panel-final.md"));
        let final_ref = f.stream("final", include_bytes!("../fixtures/panel-final.md"));
        let bound = merge(
            fields(&seat, &["seat_id"]),
            fields(&seat["attempts"][0], &["attempt_id", "session_id"]),
        );
        let reads=f.proof("reads",merge(merge(bound.clone(),fields(&packet,&["canonical_input","delivered_input","manifest","prompt"])),json!({"native_session_ref":native,"final_ref":final_ref,"actual_reads_verified":true})));
        let admission=f.proof("admission",merge(merge(bound,fields(&packet,&["canonical_input","delivered_input","manifest","prompt"])),json!({"status":"current","admitted":true,"raw_verdict":"PASS","native_session_ref":native,"final_ref":final_ref,"launched_at":"2026-10-15T00:00:01Z"})));
        for (key, value) in [
            ("launcher_ref", launcher.clone()),
            ("native_session_ref", native),
            ("final_ref", final_ref),
            ("reads_ref", reads),
            ("admission_ref", admission),
        ] {
            seat["attempts"][0][key] = value;
        }
        f.dispatch = merge(
            f.identity.clone(),
            json!({"delivery_mode":"agentic","packet":packet,"adapter":adapter,"launcher_version":"1","launcher_ref":launcher,"redispatch_policy_ref":policy,"activation":{"mode":"record_only","first_round":4,"authorization_ref":null,"qualification_ref":null},"seats":[seat],"decision_checks":[],"identity_records":[]}),
        );
        f.refresh();
        f
    }
    fn put_path(&self, path: &Path, value: &Value) -> Value {
        fs::write(path, serde_json::to_vec(value).unwrap()).unwrap();
        reference(path).unwrap()
    }
    fn stream(&self, name: &str, bytes: &[u8]) -> Value {
        let path = self.base.join(format!("{name}.data"));
        fs::write(&path, bytes).unwrap();
        reference(&path).unwrap()
    }
    fn proof(&self, name: &str, value: Value) -> Value {
        self.put_path(
            &self.base.join(format!("{name}.json")),
            &merge(json!({"context":self.identity}), value),
        )
    }
    fn refresh(&mut self) {
        self.authority = self.put_path(&self.base.join("dispatch.json"), &self.dispatch);
        let mut panel = fields(
            &self.dispatch,
            &[
                "adapter",
                "activation",
                "packet",
                "redispatch_policy_ref",
                "seats",
                "decision_checks",
                "identity_records",
            ],
        );
        panel["contract_version"] = json!("1");
        panel["authority_ref"] = self.authority.clone();
        if let Some(r) = self.dispatch.get("resolve_authority_ref") {
            panel["resolve_authority_ref"] = r.clone();
        }
        self.ledger = merge(
            fields(&self.identity, &["topic", "cycle_type", "round"]),
            json!({"agentic_panel":panel,"panel":{"dispatched":["a","web"],"responded":["a","web"]},"verdicts":{"models":[{"model":"a","verdict":"PASS"},{"model":"web","verdict":"PASS"}]},"findings":[],"action":"roll"}),
        );
    }
    fn value(&self) -> Value {
        json!({"dispatch":self.dispatch,"authority":self.authority,"ledger":self.ledger,"project_root":self.root})
    }
    fn valid(&self) {
        assert_eq!(verify(&self.value()).unwrap(), json!(["a", "web"]));
    }
    fn fails(&self, kind: &str) {
        let error = verify(&self.value()).unwrap_err();
        assert!(error.contains(kind), "{error}");
    }
    fn replace(&mut self, old: &Value, new: &Value) {
        fn walk(v: &mut Value, old: &Value, new: &Value) {
            if v == old {
                *v = new.clone();
                return;
            }
            match v {
                Value::Object(o) => {
                    for v in o.values_mut() {
                        walk(v, old, new)
                    }
                }
                Value::Array(a) => {
                    for v in a {
                        walk(v, old, new)
                    }
                }
                _ => (),
            }
        }
        walk(&mut self.dispatch, old, new);
        self.refresh();
    }
    fn edit_proof(&mut self, r: &Value, edit: impl FnOnce(&mut Value)) {
        let mut value = read(r).unwrap();
        edit(&mut value);
        let next = self.put_path(Path::new(s(r, "path").unwrap()), &value);
        self.replace(r, &next);
    }
    fn qualified(&mut self) {
        let adapter = self.dispatch["adapter"].clone();
        let authorization = self.proof(
            "activation",
            json!({"authorized":true,"adapter":adapter,"first_round":4}),
        );
        let qualification = self.proof(
            "qualification",
            json!({"authorized":true,"adapter":adapter,"first_round":4,"qualified":true}),
        );
        self.dispatch["activation"] = json!({"mode":"qualified","first_round":4,"authorization_ref":authorization,"qualification_ref":qualification});
        let attempt = &self.dispatch["seats"][0]["attempts"][0];
        let account=self.proof("account",merge(merge(fields(attempt,&["attempt_id","session_id","final_ref"]),json!({"seat_id":"a"})),json!({"grounded_reasoning":"Bound technical input reviewed.","material_limitations":[]})));
        self.dispatch["seats"][0]["attempts"][0]["account_ref"] = account;
        self.refresh();
    }
    fn add_decision(&mut self, kind: &str) {
        let common = json!({"kind":kind,"decision_id":"done"});
        let subject = self.proof(
            "subject",
            merge(
                common.clone(),
                json!({"subject_id":"lead","session_id":"lead-session"}),
            ),
        );
        let checker = self.proof(
            "checker",
            merge(
                common.clone(),
                json!({"subject_id":"checker","session_id":"checker-session"}),
            ),
        );
        let proof=self.proof("decision-proof",merge(common.clone(),json!({"subject_ref":subject,"checker_identity_ref":checker,"independent":true,"reproduction_or_proof":true,"scope_authority_checked":true})));
        let authority=self.proof("decision-authority",merge(common.clone(),json!({"subject_ref":subject,"checker_identity_ref":checker,"proof_ref":proof,"authorized":true})));
        let mut check = merge(
            common.clone(),
            json!({"subject_ref":subject,"checker_identity_ref":checker,"proof_ref":proof,"authority_ref":authority}),
        );
        if kind == "shared_domain_design" {
            check["caller_domain_review_ref"]=self.proof("caller-review",merge(common,json!({"subject_ref":subject,"checker_identity_ref":checker,"proof_ref":proof,"independent":true,"reproduction_or_proof":true,"scope_authority_checked":true,"caller_effects":"checked","representative_pre_post_outcomes":"checked","late_handlers":"checked","lifetimes":"checked"})));
        }
        self.dispatch["decision_checks"] = json!([check]);
        let session = self.dispatch["seats"][0]["attempts"][0]["session_id"].clone();
        self.dispatch["identity_records"] = json!([{"role":"lead","subject_id":"lead","session_id":"lead-session","requested_profile":"requested","effective_profile":null,"effective_family":null,"evidence_ref":null,"unknowns":["unproved"]},{"role":"checker","subject_id":"checker","session_id":"checker-session","requested_profile":"requested","effective_profile":null,"effective_family":null,"evidence_ref":null,"unknowns":["unproved"]},{"role":"seat","subject_id":"a","session_id":session,"requested_profile":"requested","effective_profile":null,"effective_family":null,"evidence_ref":null,"unknowns":["unproved"]}]);
        self.refresh();
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        if !self.preserve {
            let _ = fs::remove_dir_all(&self.base);
        }
    }
}

#[test]
fn real_artifact_record_only_acceptance_and_pass_sources() {
    Fixture::new().valid();
}
#[test]
fn existing_consumer_numeric_context_equality_is_preserved() {
    let mut f = Fixture::new();
    f.ledger["round"] = json!(4.0);
    f.ledger["agentic_panel"]["activation"]["first_round"] = json!(4.0);
    f.valid();
}
macro_rules! ledger_control {
    ($name:ident,$kind:expr,$edit:expr) => {
        #[test]
        fn $name() {
            let mut f = Fixture::new();
            f.valid();
            ($edit)(&mut f.ledger);
            f.fails($kind);
        }
    };
}
ledger_control!(
    closed_contract,
    "required-contract-missing",
    |v: &mut Value| {
        v["agentic_panel"]["extra"] = json!(true);
    }
);
ledger_control!(
    contract_version,
    "required-contract-missing",
    |v: &mut Value| {
        v["agentic_panel"]["contract_version"] = json!("2");
    }
);
ledger_control!(ledger_operation, CYCLE, |v: &mut Value| {
    v["round"] = json!(5);
});
ledger_control!(ledger_authority, CTX, |v: &mut Value| {
    v["agentic_panel"]["authority_ref"]["sha256"] = json!("0".repeat(64));
});
ledger_control!(ledger_packet, DELIVER, |v: &mut Value| {
    v["agentic_panel"]["packet"]["delivered_input"]["sha256"] = json!("0".repeat(64));
});
ledger_control!(ledger_adapter, LAUNCH, |v: &mut Value| {
    v["agentic_panel"]["adapter"]["version"] = json!("other");
});
ledger_control!(ledger_activation, QUAL, |v: &mut Value| {
    v["agentic_panel"]["activation"]["mode"] = json!("qualified");
});
ledger_control!(ledger_redispatch_policy, CTX, |v: &mut Value| {
    v["agentic_panel"]["redispatch_policy_ref"] = Value::Null;
});
ledger_control!(retained_attempt_binding, ATT, |v: &mut Value| {
    v["agentic_panel"]["seats"][0]["attempts"][0]["session_id"] = json!("wrong");
});
ledger_control!(response_projection, ATT, |v: &mut Value| {
    v["panel"]["responded"] = json!(["web"]);
});
ledger_control!(dispatch_projection, ATT, |v: &mut Value| {
    v["panel"]["dispatched"] = json!(["web"]);
});
ledger_control!(raw_verdict_projection, ATT, |v: &mut Value| {
    v["verdicts"]["models"][0]["verdict"] = json!("FAIL");
});
ledger_control!(verdict_row_uniqueness, ATT, |v: &mut Value| {
    v["verdicts"]["models"]
        .as_array_mut()
        .unwrap()
        .push(json!({"model":"a","verdict":"PASS"}));
});
ledger_control!(convergence_required, DECISION, |v: &mut Value| {
    v["action"] = json!("close");
});
ledger_control!(decision_authority_binding, CTX, |v: &mut Value| {
    v["agentic_panel"]["decision_checks"] = json!([{}]);
});
ledger_control!(identity_authority_binding, CTX, |v: &mut Value| {
    v["agentic_panel"]["identity_records"] = json!([{}]);
});

#[test]
fn operation_slug_cycle_and_integer_round() {
    let f = Fixture::new();
    for (key, bad) in [
        ("topic", json!("bad/path")),
        ("cycle_type", json!("other")),
        ("cycle", json!(" ")),
        ("round", json!(true)),
        ("round", json!(0)),
    ] {
        let mut value = f.value();
        value["dispatch"][key] = bad;
        assert!(verify(&value).unwrap_err().contains(CYCLE));
    }
}
#[test]
fn missing_dispatch_and_hash() {
    let f = Fixture::new();
    for (r, kind) in [
        (Value::Null, "dispatch-evidence-missing"),
        (json!({"path":"/fixtures/dispatch.json"}), HASH),
    ] {
        let mut value = f.value();
        value["authority"] = r;
        assert!(verify(&value).unwrap_err().contains(kind));
    }
}
#[test]
fn schema_is_single_link_and_no_follow() {
    let f = Fixture::new();
    let path = f.root.join("reviews/schema/resolve-ledger.schema.json");
    let alias = f.base.join("schema-link");
    fs::hard_link(&path, &alias).unwrap();
    assert!(verify(&f.value()).is_err());
    fs::remove_file(&alias).unwrap();
    fs::rename(&path, &alias).unwrap();
    symlink(&alias, &path).unwrap();
    assert!(verify(&f.value()).is_err());
}
#[test]
fn external_dispatch_location_and_single_link() {
    let mut f = Fixture::new();
    let original = PathBuf::from(s(&f.authority, "path").unwrap());
    let inside = f.root.join("dispatch.json");
    fs::copy(&original, &inside).unwrap();
    let mut value = f.value();
    value["authority"] = reference(&inside).unwrap();
    assert!(verify(&value).unwrap_err().contains(CTX));
    let alias = f.base.join("dispatch-link");
    fs::hard_link(&original, alias).unwrap();
    f.fails(HASH);
    f.authority = json!({"path":original,"sha256":"0".repeat(64)});
    f.fails(HASH);
}
#[test]
fn pending_publication_all_four_markers() {
    let f = Fixture::new();
    for suffix in [
        ".commit-marker.json",
        ".commit-marker.json.tmp",
        ".md.tmp",
        ".manifest.json.tmp",
    ] {
        let path = f.root.join(format!(
            "reviews/config-dispatch-fixture/intakes/audit-r4{suffix}"
        ));
        symlink("/fixtures/missing", &path).unwrap();
        f.fails(INTAKE);
        fs::remove_file(path).unwrap();
    }
    f.valid();
}
#[test]
fn compiler_sidecar_status_digest_size_and_output() {
    let f = Fixture::new();
    let path = Path::new(s(&f.dispatch["packet"]["manifest"], "path").unwrap());
    let original = fs::read(path).unwrap();
    for (key, bad) in [
        ("status", json!("FAIL")),
        ("sha256", json!("sha256:wrong")),
        ("bytes", json!(true)),
        ("bytes", json!(0)),
        ("output", json!("/fixtures/wrong")),
    ] {
        let mut value = decode(&original).unwrap();
        value[key] = bad;
        fs::write(path, serde_json::to_vec(&value).unwrap()).unwrap();
        f.fails(MANIFEST);
    }
    fs::write(path, original).unwrap();
    f.valid();
}
#[test]
fn closed_dispatch_fields() {
    let mut f = Fixture::new();
    f.dispatch["extra"] = json!(true);
    f.refresh();
    f.fails(CTX);
}
#[test]
fn actual_intake_digest_binding() {
    let f = Fixture::new();
    let path = s(&f.dispatch["packet"]["canonical_input"], "path").unwrap();
    fs::write(path, b"changed\n").unwrap();
    f.fails(MANIFEST);
}
#[test]
fn delivered_and_prompt_durable_hashes() {
    for key in ["delivered_input", "prompt"] {
        let f = Fixture::new();
        let path = s(&f.dispatch["packet"][key], "path").unwrap();
        fs::write(path, b"changed\n").unwrap();
        f.fails(if key == "prompt" {
            "prompt-authority"
        } else {
            DELIVER
        });
    }
}
#[test]
fn projection_context_exclusion_and_fidelity() {
    for key in [
        "context",
        "exclusion_pass",
        "fidelity_pass",
        "canonical_input",
        "delivered_input",
    ] {
        let mut f = Fixture::new();
        let r = f.dispatch["packet"]["projection_review"].clone();
        f.edit_proof(&r, |p| p[key] = Value::Null);
        f.fails(DELIVER);
    }
}
#[test]
fn report_self_expected_authority_is_refused() {
    for key in ["expected_context", "expected_hash", "expected_sha256"] {
        let mut f = Fixture::new();
        let r = f.dispatch["packet"]["projection_review"].clone();
        f.edit_proof(&r, |p| p[key] = json!("self"));
        f.fails(DELIVER);
    }
}
#[test]
fn launcher_version_and_adapter_binding() {
    for key in ["adapter", "launcher_version"] {
        let mut f = Fixture::new();
        let r = f.dispatch["launcher_ref"].clone();
        f.edit_proof(&r, |p| p[key] = Value::Null);
        f.fails(LAUNCH);
    }
}
#[test]
fn prospective_policy_authorization() {
    let mut f = Fixture::new();
    let r = f.dispatch["redispatch_policy_ref"].clone();
    f.edit_proof(&r, |p| p["authorized"] = json!(false));
    f.fails(CTX);
}
#[test]
fn attempt_launcher_binding() {
    let mut f = Fixture::new();
    f.dispatch["seats"][0]["attempts"][0]["launcher_ref"] =
        f.dispatch["packet"]["projection_review"].clone();
    f.refresh();
    f.fails(LAUNCH);
}
#[test]
fn native_final_bytes_and_same_inode_roles() {
    for shared in [false, true] {
        let f = Fixture::new();
        let native = Path::new(
            s(
                &f.dispatch["seats"][0]["attempts"][0]["native_session_ref"],
                "path",
            )
            .unwrap(),
        );
        let final_path =
            Path::new(s(&f.dispatch["seats"][0]["attempts"][0]["final_ref"], "path").unwrap());
        if shared {
            fs::remove_file(final_path).unwrap();
            fs::hard_link(native, final_path).unwrap();
        } else {
            fs::write(native, b"changed").unwrap();
        }
        f.fails(ATT);
    }
}
#[test]
fn reports_bind_seat_attempt_and_native_session() {
    for key in ["seat_id", "attempt_id", "session_id", "context"] {
        let mut f = Fixture::new();
        let r = f.dispatch["seats"][0]["attempts"][0]["reads_ref"].clone();
        f.edit_proof(&r, |p| p[key] = json!("wrong"));
        f.fails(ATT);
    }
}
#[test]
fn admissions_bind_status_native_final_and_verdict() {
    for key in [
        "status",
        "native_session_ref",
        "final_ref",
        "admitted",
        "raw_verdict",
    ] {
        let mut f = Fixture::new();
        let r = f.dispatch["seats"][0]["attempts"][0]["admission_ref"].clone();
        f.edit_proof(&r, |p| p[key] = Value::Null);
        f.fails(ATT);
    }
}
#[test]
fn admission_and_reads_bind_every_packet_member() {
    for key in ["canonical_input", "delivered_input", "manifest", "prompt"] {
        for report_key in ["admission_ref", "reads_ref"] {
            let mut f = Fixture::new();
            let r = f.dispatch["seats"][0]["attempts"][0][report_key].clone();
            f.edit_proof(&r, |p| p[key] = Value::Null);
            f.fails(ATT);
        }
    }
}
#[test]
fn reads_must_prove_actual_reads() {
    let mut f = Fixture::new();
    let r = f.dispatch["seats"][0]["attempts"][0]["reads_ref"].clone();
    f.edit_proof(&r, |p| p["actual_reads_verified"] = json!(false));
    f.fails(ATT);
}
#[test]
fn qualified_authorization_and_adapter_proofs() {
    let mut f = Fixture::new();
    f.qualified();
    f.valid();
    let r = f.dispatch["activation"]["qualification_ref"].clone();
    f.edit_proof(&r, |p| p["qualified"] = json!(false));
    f.fails(QUAL);
}
#[test]
fn qualified_grounded_account_and_material_deficiency() {
    let mut f = Fixture::new();
    f.qualified();
    f.valid();
    let r = f.dispatch["seats"][0]["attempts"][0]["account_ref"].clone();
    f.edit_proof(&r, |p| p["grounded_reasoning"] = json!(" "));
    f.fails(QUAL);
    f.dispatch["seats"][0]["pass_floor_eligible"] = json!(false);
    f.refresh();
    assert_eq!(verify(&f.value()).unwrap(), json!(["web"]));
}
#[test]
fn positive_contradiction_and_qualified_absence_require_all_proofs() {
    let mut f = Fixture::new();
    f.qualified();
    let account = read(&f.dispatch["seats"][0]["attempts"][0]["account_ref"]).unwrap();
    for (kind, fields) in [
        (
            "positive_contradiction",
            json!({"claimed_invocation":"compile","claimed_result":"success","reruns_resolved":true,"contradiction_proved":true}),
        ),
        (
            "qualified_absence",
            json!({"necessary_record_action_claim":true,"complete_bound_coverage":true,"qualified_event_decoding":true}),
        ),
    ] {
        let full = merge(
            merge(
                account.clone(),
                json!({"material_deficiency":true,"kind":kind}),
            ),
            fields.clone(),
        );
        assert!(grounded(&full) && deficient(&full));
        for key in fields.as_object().unwrap().keys() {
            let mut missing = full.clone();
            missing.as_object_mut().unwrap().remove(key);
            assert!(!deficient(&missing), "{kind} {key}");
        }
    }
}
#[test]
fn all_decision_kinds_require_independent_binding() {
    for kind in ["reclassification", "convergence", "shared_domain_design"] {
        let mut f = Fixture::new();
        f.add_decision(kind);
        f.valid();
        for key in [
            "independent",
            "reproduction_or_proof",
            "scope_authority_checked",
        ] {
            let r = f.dispatch["decision_checks"][0]["proof_ref"].clone();
            f.edit_proof(&r, |p| p[key] = json!(false));
            f.fails(DECISION);
            f.edit_proof(
                &f.dispatch["decision_checks"][0]["proof_ref"].clone(),
                |p| p[key] = json!(true),
            );
        }
    }
}
#[test]
fn decision_identity_coverage_and_unknowns() {
    let mut f = Fixture::new();
    f.add_decision("convergence");
    f.valid();
    f.dispatch["identity_records"][0]["unknowns"] = json!([]);
    f.refresh();
    f.fails(ATT);
    f.dispatch["identity_records"][0]["unknowns"] = json!(["unproved"]);
    f.dispatch["identity_records"]
        .as_array_mut()
        .unwrap()
        .remove(1);
    f.refresh();
    f.fails(IDENTITY);
}
#[test]
fn shared_domain_caller_review_requires_all_four_material_accounts() {
    for key in [
        "caller_effects",
        "representative_pre_post_outcomes",
        "late_handlers",
        "lifetimes",
    ] {
        let mut f = Fixture::new();
        f.add_decision("shared_domain_design");
        let r = f.dispatch["decision_checks"][0]["caller_domain_review_ref"].clone();
        f.edit_proof(&r, |p| p[key] = json!(" "));
        f.fails(DECISION);
    }
}
#[test]
fn convergence_evidence_allows_current_close() {
    let mut f = Fixture::new();
    f.add_decision("convergence");
    f.ledger["action"] = json!("close");
    f.valid();
}
#[test]
fn retained_unadmitted_findings_need_explicit_non_reproduction() {
    let f = Fixture::new();
    let p = json!({"reproduction_ref":null,"reproduction_status":"not-yet-reproduced","reproduction_reason":"Awaiting independent reproduction."});
    assert!(null_reproduction(&json!({"classification":null}), &p).is_ok());
    assert!(null_reproduction(&json!({"classification":"real"}), &p).is_err());
    for key in ["reproduction_reason", "reproduction_status"] {
        let mut bad = p.clone();
        bad[key] = Value::Null;
        assert!(null_reproduction(&json!({"classification":null}), &bad).is_err());
    }
    f.valid();
}
fn reproduced_fixture(change: Option<(&str, Value)>) -> Fixture {
    let mut f = Fixture::new();
    f.add_decision("reclassification");
    f.dispatch["seats"][0]["admitted"] = json!(false);
    f.dispatch["seats"][0]["responding"] = json!(false);
    f.dispatch["seats"][0]["pass_floor_eligible"] = json!(false);
    f.dispatch["seats"][0]["attempts"][0]["status"] = json!("disqualified");
    let r = f.dispatch["seats"][0]["attempts"][0]["admission_ref"].clone();
    f.edit_proof(&r, |p| {
        p["admitted"] = json!(false);
        p["status"] = json!("disqualified");
    });
    let attempt = &f.dispatch["seats"][0]["attempts"][0];
    let mut proof = merge(
        fields(attempt, &["attempt_id", "session_id", "final_ref"]),
        json!({"seat_id":"a","reproduced":true,"producer_id":"lead","producer_session_id":"lead-session"}),
    );
    if let Some((key, value)) = change {
        proof[key] = value;
    }
    let reproduction = f.proof("reproduction", proof);
    let operation=f.proof("resolve-operation",json!({"authorized":true,"role":"lead","subject_id":"lead","session_id":"lead-session","reports":[reproduction]}));
    f.dispatch["resolve_authority_ref"] = operation;
    f.refresh();
    f.ledger["panel"]["responded"] = json!(["web"]);
    f.ledger["verdicts"]["models"][0]["responded"] = json!("no");
    f.ledger["findings"] = json!([{"classification":"REAL ISSUE","unadmitted_evidence":[{"seat_id":"a","attempt_id":"one","final_ref":f.dispatch["seats"][0]["attempts"][0]["final_ref"],"reproduction_ref":reproduction}]}]);
    f
}
#[test]
fn classified_retained_reproduction_needs_authorized_lead_producer_and_bound_final() {
    let f = reproduced_fixture(None);
    assert_eq!(verify(&f.value()).unwrap(), json!(["web"]));
    for (key, value) in [
        ("reproduced", json!(false)),
        ("producer_id", json!("checker")),
        ("producer_session_id", json!("other")),
        ("final_ref", Value::Null),
        ("seat_id", json!("other")),
        ("attempt_id", json!("other")),
        ("session_id", json!("other")),
    ] {
        reproduced_fixture(Some((key, value))).fails(ATT);
    }
}
#[test]
fn resolve_operation_needs_authorization_lead_identity_and_bounded_report_references() {
    for key in ["authorized", "role", "subject_id", "session_id", "reports"] {
        let mut f = reproduced_fixture(None);
        let r = f.dispatch["resolve_authority_ref"].clone();
        let mut proof = read(&r).unwrap();
        proof[key] = Value::Null;
        let new = f.put_path(Path::new(s(&r, "path").unwrap()), &proof);
        f.dispatch["resolve_authority_ref"] = new;
        f.refresh();
        f.fails(ATT);
    }
}
#[test]
fn sequence_context_is_required_on_every_dependent_report() {
    let mut f = Fixture::new();
    let sequence = json!({"step_id":"owned-step","entry_global_round":4});
    f.dispatch["sequence_context"] = sequence.clone();
    f.refresh();
    f.fails(DELIVER);
    for selector in ["projection", "launcher", "policy", "reads", "admission"] {
        let r = match selector {
            "projection" => f.dispatch["packet"]["projection_review"].clone(),
            "launcher" => f.dispatch["launcher_ref"].clone(),
            "policy" => f.dispatch["redispatch_policy_ref"].clone(),
            "reads" => f.dispatch["seats"][0]["attempts"][0]["reads_ref"].clone(),
            _ => f.dispatch["seats"][0]["attempts"][0]["admission_ref"].clone(),
        };
        f.edit_proof(&r, |p| p["sequence_context"] = sequence.clone());
    }
    f.valid();
    let r = f.dispatch["seats"][0]["attempts"][0]["reads_ref"].clone();
    f.edit_proof(&r, |p| p["sequence_context"] = json!({"step_id":"other"}));
    f.fails(ATT);
}
#[test]
fn effective_identity_evidence_and_requested_profiles_are_checked() {
    let mut f = Fixture::new();
    f.add_decision("convergence");
    let record = f.dispatch["identity_records"][0].clone();
    let proof = f.proof(
        "identity-proof",
        merge(
            fields(&record, &["subject_id", "session_id"]),
            json!({"effective_profile":"native","effective_family":"fixture"}),
        ),
    );
    f.dispatch["identity_records"][0]["effective_profile"] = json!("native");
    f.dispatch["identity_records"][0]["effective_family"] = json!("fixture");
    f.dispatch["identity_records"][0]["evidence_ref"] = proof.clone();
    f.dispatch["identity_records"][0]["unknowns"] = json!([]);
    f.refresh();
    f.valid();
    f.edit_proof(&proof, |p| p["effective_family"] = json!("wrong"));
    f.fails(ATT);
    let mut f = Fixture::new();
    f.add_decision("convergence");
    f.dispatch["identity_records"][0]["requested_profile"] = json!(" ");
    f.refresh();
    f.fails(IDENTITY);
}
#[test]
fn reader_duplicate_depth_nonfinite_and_object_limits() {
    let f = Fixture::new();
    for bytes in [b"{\"a\":1,\"a\":2}".as_slice(), b"{\"a\":NaN}", b"[]"] {
        let r = f.stream("bad", bytes);
        assert!(Reader::default().read(&r, ATT).is_err());
    }
    let bytes = format!("{}0{}", "[".repeat(33), "]".repeat(33));
    let r = f.stream("bad", bytes.as_bytes());
    assert!(Reader::default().read(&r, ATT).is_err());
}
#[test]
fn reader_json_unique_file_and_repeated_byte_budgets() {
    let f = Fixture::new();
    let r = f.dispatch["launcher_ref"].clone();
    let mut reader = Reader {
        total: 512 * 1024 * 1024,
        ..Reader::default()
    };
    assert!(reader.read(&r, ATT).is_err());
    reader.total = 0;
    reader.files = (0..2048).map(|n| format!("/fixtures/{n}")).collect();
    assert!(reader.read(&r, ATT).is_err());
    let bytes = vec![b' '; 256 * 1024 + 1];
    let r = f.stream("large", &bytes);
    assert!(Reader::default().read(&r, ATT).is_err());
}
#[test]
fn reader_refuses_symlinks_and_noncanonical_components() {
    let f = Fixture::new();
    let real = Path::new(s(&f.dispatch["launcher_ref"], "path").unwrap());
    let alias = f.base.join("alias");
    symlink(real, &alias).unwrap();
    let r = json!({"path":alias,"sha256":f.dispatch["launcher_ref"]["sha256"]});
    assert!(Reader::default().read(&r, ATT).is_err());
    let mut r = f.dispatch["launcher_ref"].clone();
    r["path"] = json!(format!("{}/./launcher.json", f.base.display()));
    assert!(Reader::default().read(&r, ATT).is_err());
}
#[test]
fn current_dependencies_refuse_noncurrent_pointers_but_retention_can_read_them() {
    let f = Fixture::new();
    let (mut context, mut reader) =
        resolve(&f.root, &f.identity, &f.authority, &Value::Null).unwrap();
    let proof = f.proof(
        "prior-reads",
        json!({"seat_id":"a","attempt_id":"prior","session_id":"prior-session"}),
    );
    let mut old = context.dispatch["seats"][0]["attempts"][0].clone();
    old["attempt_id"] = json!("prior");
    old["session_id"] = json!("prior-session");
    old["status"] = json!("launch_failed");
    old["reads_ref"] = proof.clone();
    context.dispatch["seats"][0]["attempts"]
        .as_array_mut()
        .unwrap()
        .push(old);
    assert!(report(&context, &proof, None, false, &mut reader, ATT)
        .unwrap_err()
        .contains("noncurrent"));
    assert!(report_check(&context, &proof, None, false, true, &mut reader, ATT).is_ok());
}
#[test]
fn stream_file_budget_refuses_oversized_regular_evidence() {
    let f = Fixture::new();
    let path = f.base.join("oversized");
    fs::File::create(&path)
        .unwrap()
        .set_len(64 * 1024 * 1024 + 1)
        .unwrap();
    let r = json!({"path":path,"sha256":"0".repeat(64)});
    assert!(Reader::default().stream(&r, ATT).is_err());
}
#[test]
#[ignore = "explicit installed-candidate protocol verification from an owned plain pane"]
fn native_protocol_cli_controls() {
    use std::process::Command;
    let pane = std::env::var("TMUX_PANE").unwrap();
    let identity = crate::panel_dispatch::tmux(&[
        "display-message",
        "-p",
        "-t",
        &pane,
        "#{session_name}\t#{window_name}\t#{pane_id}",
    ])
    .unwrap();
    let columns: Vec<_> = identity.split('\t').collect();
    assert_eq!(columns[0], "config-tt");
    assert!(columns[1].starts_with("p3x-test-"));
    assert_eq!(columns[2], pane);
    let executable = std::env::current_exe()
        .unwrap()
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("angelstar-runtime");
    let evidence = home()
        .unwrap()
        .join("desk/tmp/relay/port/panel-evidence/fix")
        .join(format!("consumer-{}", crate::runtime::fresh_id().unwrap()));
    fs::create_dir(&evidence).unwrap();
    let candidate = evidence.join("angelstar-runtime");
    fs::copy(executable, &candidate).unwrap();
    let surface = evidence.join("panel-dispatch");
    symlink(&candidate, &surface).unwrap();
    let digest = hash(&fs::read(&candidate).unwrap());
    let mut rows = Vec::new();
    for case in [
        "record-only",
        "qualified",
        "stale-native",
        "wrong-session",
        "self-activation",
        "projection-failure",
        "shared-inode",
        "bad-sidecar",
        "bad-reads",
        "bad-launcher",
        "account-deficiency",
        "decision-valid",
        "decision-self",
        "bad-authority",
        "unadmitted-classified",
    ] {
        let mut f = Fixture::new();
        let launcher = f.dispatch["launcher_ref"].clone();
        f.dispatch["adapter"]["source_sha256"] = json!(digest);
        let adapter = f.dispatch["adapter"].clone();
        f.edit_proof(&launcher, |p| p["adapter"] = adapter);
        let expected = match case {
            "record-only" => 0,
            "qualified" => {
                f.qualified();
                0
            }
            "stale-native" => {
                let path = s(
                    &f.dispatch["seats"][0]["attempts"][0]["native_session_ref"],
                    "path",
                )
                .unwrap();
                fs::write(path, b"stale").unwrap();
                1
            }
            "wrong-session" => {
                f.ledger["agentic_panel"]["seats"][0]["attempts"][0]["session_id"] = json!("wrong");
                1
            }
            "self-activation" => {
                f.ledger["agentic_panel"]["activation"]["mode"] = json!("qualified");
                1
            }
            "projection-failure" => {
                let r = f.dispatch["packet"]["projection_review"].clone();
                f.edit_proof(&r, |p| p["fidelity_pass"] = json!(false));
                1
            }
            "shared-inode" => {
                let attempt = &f.dispatch["seats"][0]["attempts"][0];
                let path = s(&attempt["final_ref"], "path").unwrap();
                fs::remove_file(path).unwrap();
                fs::hard_link(s(&attempt["native_session_ref"], "path").unwrap(), path).unwrap();
                1
            }
            "bad-sidecar" => {
                let path = s(&f.dispatch["packet"]["manifest"], "path").unwrap();
                fs::write(path, b"{}").unwrap();
                1
            }
            "bad-reads" => {
                let r = f.dispatch["seats"][0]["attempts"][0]["reads_ref"].clone();
                f.edit_proof(&r, |p| p["actual_reads_verified"] = json!(false));
                1
            }
            "bad-launcher" => {
                let r = f.dispatch["launcher_ref"].clone();
                f.edit_proof(&r, |p| p["launcher_version"] = json!("wrong"));
                1
            }
            "account-deficiency" => {
                f.qualified();
                let r = f.dispatch["seats"][0]["attempts"][0]["account_ref"].clone();
                f.edit_proof(&r, |p| p["grounded_reasoning"] = json!(" "));
                1
            }
            "decision-valid" => {
                f.add_decision("convergence");
                f.ledger["action"] = json!("close");
                0
            }
            "decision-self" => {
                f.add_decision("convergence");
                let r = f.dispatch["decision_checks"][0]["checker_identity_ref"].clone();
                f.edit_proof(&r, |p| p["subject_id"] = json!("lead"));
                1
            }
            "bad-authority" => {
                f.authority["sha256"] = json!("0".repeat(64));
                1
            }
            _ => {
                f.ledger["findings"] = json!([{"classification":"real","unadmitted_evidence":[{"seat_id":"a","attempt_id":"one","final_ref":f.dispatch["seats"][0]["attempts"][0]["final_ref"],"reproduction_ref":null}]}]);
                1
            }
        };
        let ledger = f.put_path(&f.base.join("ledger.json"), &f.ledger);
        let output = evidence.join(format!("{case}.json"));
        let argv = vec![
            "verify".to_owned(),
            "--protocol-root".into(),
            f.root.to_string_lossy().into(),
            "--project-root".into(),
            f.root.to_string_lossy().into(),
            "--dispatch".into(),
            s(&f.authority, "path").unwrap().into(),
            "--sha256".into(),
            s(&f.authority, "sha256").unwrap().into(),
            "--ledger".into(),
            s(&ledger, "path").unwrap().into(),
            "--ledger-sha256".into(),
            s(&ledger, "sha256").unwrap().into(),
            "--output".into(),
            output.to_string_lossy().into(),
        ];
        let result = Command::new(&surface)
            .args(&argv)
            .current_dir(&f.base)
            .output()
            .unwrap();
        rows.push(json!({"case":case,"fixture_root":f.base,"argv":argv,"expected_exit":expected,"actual_exit":result.status.code(),"stdout":String::from_utf8_lossy(&result.stdout),"stderr":String::from_utf8_lossy(&result.stderr),"TMUX":std::env::var("TMUX").unwrap(),"TMUX_PANE":pane}));
        fs::write(
            evidence.join("parity.json"),
            serde_json::to_vec_pretty(&json!({"candidate_sha256":digest,"rows":rows})).unwrap(),
        )
        .unwrap();
        f.preserve = true;
        assert_eq!(
            result.status.code(),
            Some(expected),
            "{case}: {}",
            String::from_utf8_lossy(&result.stderr)
        );
    }
    println!("P3X_NATIVE_CONSUMERS_PASS {}", evidence.display());
}
#[test]
fn retry_policy_precedes_launch_and_supersession_precedes_replacement() {
    let f = Fixture::new();
    let mut old = f.dispatch["seats"][0]["attempts"][0].clone();
    old["status"] = json!("superseded");
    let mut new = old.clone();
    new["status"] = json!("current");
    new["attempt_id"] = json!("two");
    new["session_id"] = json!("fresh");
    let old_proofs = json!({"admission_ref":{"launched_at":"2026-10-15T00:00:01Z","admitted":false},"supersession_ref":{"authorized":true,"technical":true,"cause":"startup","replacement_attempt_id":"two","replacement_session_id":"fresh","committed_at":"2026-10-15T00:00:02Z"}});
    let new_proofs = json!({"admission_ref":{"launched_at":"2026-10-15T00:00:03Z"}});
    let policy = json!({"max_redispatches":1,"technical_causes":["startup"],"exhaustion":"non-response","authorized_at":"2026-10-15T00:00:00Z"});
    let seat = json!({"attempt_id":"two"});
    let retained = vec![
        (old.clone(), old_proofs.clone()),
        (new.clone(), new_proofs.clone()),
    ];
    history(&seat, &retained, &policy).unwrap();
    for key in [
        "authorized_at",
        "max_redispatches",
        "technical_causes",
        "exhaustion",
    ] {
        let mut p = policy.clone();
        p[key] = Value::Null;
        assert!(history(&seat, &retained, &p).is_err());
    }
    for key in [
        "authorized",
        "technical",
        "cause",
        "replacement_attempt_id",
        "replacement_session_id",
        "committed_at",
    ] {
        let mut proofs = old_proofs.clone();
        proofs["supersession_ref"][key] = Value::Null;
        assert!(history(
            &seat,
            &[(old.clone(), proofs), (new.clone(), new_proofs.clone())],
            &policy
        )
        .is_err());
    }
    let mut fail = old_proofs;
    fail["admission_ref"]["admitted"] = json!(true);
    fail["admission_ref"]["raw_verdict"] = json!("FAIL");
    assert!(history(&seat, &[(old, fail), (new, new_proofs)], &policy).is_err());
}
#[test]
fn whole_second_ordering_and_valid_timezone_components() {
    for time in [
        "2026-10-15T00:00:00.1Z",
        "2026-10-15T00:00:00+00:60",
        "2026-02-30T00:00:00Z",
        "2026-10-15T00:00:60Z",
    ] {
        assert!(attempt_instant(&json!(time)).is_err(), "{time}");
    }
    assert!(attempt_instant(&json!("2026-10-15T00:00:00-07:00")).is_ok());
}
