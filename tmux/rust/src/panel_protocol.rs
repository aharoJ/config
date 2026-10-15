use crate::{
    panel_io::*,
    panel_schema::{self, list},
};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};

const CTX: &str = "dispatch-context-missing-or-conflicting";
const ATT: &str = "attempt-session-authority-missing-or-conflicting";
const HASH: &str = "dispatch-hash-missing-or-mismatch";
const CYCLE: &str = "cycle-authority-missing-or-conflicting";
const QUAL: &str = "qualification-authority-missing-or-conflicting";
const LAUNCH: &str = "launcher-authority-missing-or-conflicting";
const DELIVER: &str = "delivered-input-authority-missing-or-conflicting";
const INTAKE: &str = "canonical-intake-missing-or-invalid";
const MANIFEST: &str = "canonical-manifest-missing-or-invalid";
const DECISION: &str = "decision-proof-missing-or-conflicting";
const IDENTITY: &str = "decision-identity-missing-or-conflicting";
fn require(ok: bool, kind: &str, detail: &str) -> Result<()> {
    check(ok, &format!("agentic-dependency:{kind}: {detail}"))
}
fn named<T>(result: Result<T>, kind: &str) -> Result<T> {
    result.map_err(|e| format!("agentic-dependency:{kind}: {e}"))
}
fn reference_ok(v: &Value) -> bool {
    closed(v, &["path", "sha256"])
        && v["path"]
            .as_str()
            .is_some_and(|p| Path::new(p).is_absolute())
        && v["sha256"].as_str().is_some_and(|h| {
            h.len() == 64
                && h.bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        })
}
fn nonblank(v: &Value) -> bool {
    v.as_str().is_some_and(|s| !s.trim().is_empty())
}
fn passing(v: &Value) -> bool {
    v == "PASS" || v == "PASS_WITH_MONITORING"
}
fn same(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Bool(a), Value::Number(_)) => panel_schema::equal(&json!(u8::from(*a)), b),
        (Value::Number(_), Value::Bool(b)) => panel_schema::equal(a, &json!(u8::from(*b))),
        (Value::Object(a), Value::Object(b)) => {
            a.len() == b.len() && a.iter().all(|(k, a)| b.get(k).is_some_and(|b| same(a, b)))
        }
        (Value::Array(a), Value::Array(b)) => {
            a.len() == b.len() && a.iter().zip(b).all(|(a, b)| same(a, b))
        }
        _ => panel_schema::equal(a, b),
    }
}
fn contains(v: &Value, r: &Value) -> bool {
    if reference_ok(v) && v == r {
        return true;
    }
    match v {
        Value::Object(o) => o.values().any(|v| contains(v, r)),
        Value::Array(a) => a.iter().any(|v| contains(v, r)),
        _ => false,
    }
}
#[derive(Default)]
struct Reader {
    files: BTreeSet<String>,
    total: usize,
    sizes: BTreeMap<String, usize>,
    identities: BTreeMap<String, (u64, u64)>,
}
impl Reader {
    fn bytes(
        &mut self,
        r: &Value,
        proof: bool,
        kind: &str,
        derive: bool,
        external: Option<&Path>,
    ) -> Result<(Value, Vec<u8>)> {
        require(
            reference_ok(r),
            kind,
            "expected absolute path and independent lowercase SHA-256",
        )?;
        let raw = s(r, "path")?;
        let path = Path::new(raw);
        require(
            raw.split('/')
                .skip(1)
                .all(|c| !c.is_empty() && c != "." && c != ".."),
            kind,
            "noncanonical evidence path",
        )?;
        require(
            self.files.contains(raw) || self.files.len() < 2048,
            kind,
            "unique file budget exceeded",
        )?;
        self.files.insert(raw.into());
        if let Some(root) = external {
            let root_meta = named(fs::metadata(root).map_err(|e| e.to_string()), kind)?;
            require(
                !path.starts_with(root),
                kind,
                "dispatch authority must be external",
            )?;
            for ancestor in path.ancestors().skip(1) {
                let info = named(
                    fs::symlink_metadata(ancestor).map_err(|e| e.to_string()),
                    kind,
                )?;
                require(
                    (info.dev(), info.ino()) != (root_meta.dev(), root_meta.ino()),
                    kind,
                    "dispatch authority must be external",
                )?;
            }
        }
        let (bytes, meta) = named(path_snapshot(path), kind)?;
        require(
            external.is_none() || meta.nlink() == 1,
            kind,
            "external dispatch authority must be single-link",
        )?;
        require(
            bytes.len() <= if proof { 256 * 1024 } else { 64 * 1024 * 1024 }
                && self
                    .total
                    .checked_add(bytes.len())
                    .is_some_and(|n| n <= 512 * 1024 * 1024),
            kind,
            "evidence byte budget exceeded",
        )?;
        self.total += bytes.len();
        self.sizes.insert(raw.into(), bytes.len());
        self.identities.insert(raw.into(), (meta.dev(), meta.ino()));
        let actual = json!({"path":raw,"sha256":hash(&bytes)});
        require(derive || actual == *r, kind, "evidence hash mismatch")?;
        Ok((actual, bytes))
    }
    fn read(&mut self, r: &Value, kind: &str) -> Result<Value> {
        let (_, bytes) = self.bytes(r, true, kind, false, None)?;
        let value = named(decode(&bytes), kind)?;
        require(value.is_object(), kind, "JSON proof must be an object")?;
        Ok(value)
    }
    fn stream(&mut self, r: &Value, kind: &str) -> Result<()> {
        self.bytes(r, false, kind, false, None).map(|_| ())
    }
    fn dispatch(&mut self, r: &Value, root: &Path) -> Result<Value> {
        let (_, bytes) = self.bytes(r, true, HASH, false, Some(root))?;
        let value = named(decode(&bytes), HASH)?;
        require(value.is_object(), HASH, "JSON proof must be an object")?;
        Ok(value)
    }
    fn actual(&mut self, path: &Path, proof: bool, kind: &str) -> Result<(Value, Value)> {
        let (r, bytes) = self.bytes(
            &json!({"path":path,"sha256":"0".repeat(64)}),
            proof,
            kind,
            true,
            None,
        )?;
        let value = if proof {
            let value = named(decode(&bytes), kind)?;
            require(value.is_object(), kind, "JSON proof must be an object")?;
            value
        } else {
            Value::Null
        };
        Ok((r, value))
    }
}
struct Context {
    identity: Value,
    dispatch: Value,
    authority: Value,
    root: PathBuf,
    sequence: Value,
    operation: Value,
}
fn absolute(path: &Path) -> Result<PathBuf> {
    let path = if path.is_absolute() {
        path.to_owned()
    } else {
        io(std::env::current_dir())?.join(path)
    };
    let mut normalized = PathBuf::new();
    for part in path.components() {
        match part {
            Component::ParentDir => {
                normalized.pop();
            }
            Component::CurDir => (),
            part => normalized.push(part.as_os_str()),
        }
    }
    Ok(normalized)
}
fn resolve(
    root: &Path,
    identity: &Value,
    authority: &Value,
    sequence: &Value,
) -> Result<(Context, Reader)> {
    require(
        identity["topic"].as_str().is_some_and(|s| {
            regex::Regex::new("^[a-z0-9][a-z0-9-]*$")
                .unwrap()
                .is_match(s)
        }) && ["research", "implementation"]
            .iter()
            .any(|v| identity["cycle_type"] == *v)
            && identity["round"].as_u64().is_some_and(|n| n > 0)
            && nonblank(&identity["cycle"]),
        CYCLE,
        "exact operation identity required",
    )?;
    require(
        authority.is_object() && nonblank(&authority["path"]),
        "dispatch-evidence-missing",
        "independent dispatch evidence required",
    )?;
    require(
        reference_ok(authority),
        HASH,
        "operator path/hash pair required",
    )?;
    let root = absolute(root)?;
    require(
        !Path::new(s(authority, "path")?).starts_with(&root),
        CTX,
        "dispatch authority must be external",
    )?;
    let mut reader = Reader::default();
    let dispatch = reader.dispatch(authority, &root)?;
    let allowed = [
        "topic",
        "cycle_type",
        "cycle",
        "round",
        "delivery_mode",
        "packet",
        "adapter",
        "launcher_version",
        "launcher_ref",
        "redispatch_policy_ref",
        "activation",
        "seats",
        "decision_checks",
        "identity_records",
        "sequence_context",
        "resolve_authority_ref",
    ];
    require(
        dispatch
            .as_object()
            .is_some_and(|o| o.keys().all(|k| allowed.contains(&k.as_str())))
            && dispatch["delivery_mode"] == "agentic"
            && subset(&dispatch, identity),
        CTX,
        "dispatch operation identity/fields conflict",
    )?;
    let stem = if identity["cycle_type"] == "implementation" {
        "audit"
    } else {
        "research"
    };
    let base = root
        .join("reviews")
        .join(s(identity, "topic")?)
        .join("intakes")
        .join(format!("{stem}-r{}", identity["round"]));
    let base = base.to_str().ok_or("intake path is not UTF-8")?;
    require(
        [
            ".commit-marker.json",
            ".commit-marker.json.tmp",
            ".md.tmp",
            ".manifest.json.tmp",
        ]
        .iter()
        .all(|suffix| fs::symlink_metadata(format!("{base}{suffix}")).is_err()),
        INTAKE,
        "pending canonical publication",
    )?;
    let (intake, _) = reader.actual(Path::new(&format!("{base}.md")), false, INTAKE)?;
    let (manifest_ref, manifest) =
        reader.actual(Path::new(&format!("{base}.manifest.json")), true, MANIFEST)?;
    require(
        manifest["status"] == "PASS"
            && manifest["sha256"] == format!("sha256:{}", s(&intake, "sha256")?)
            && manifest["bytes"].as_u64() == Some(reader.sizes[s(&intake, "path")?] as u64)
            && manifest["output"] == intake["path"],
        MANIFEST,
        "compiler sidecar does not bind actual intake",
    )?;
    let packet = &dispatch["packet"];
    require(
        closed(
            packet,
            &[
                "canonical_input",
                "manifest",
                "delivered_input",
                "prompt",
                "projection_review",
            ],
        ),
        CTX,
        "closed packet authority required",
    )?;
    require(
        packet["canonical_input"] == intake && packet["manifest"] == manifest_ref,
        CTX,
        "dispatch does not bind canonical repository bytes",
    )?;
    require(
        dispatch["sequence_context"] == *sequence,
        CTX,
        "independent sequence admission context conflicts",
    )?;
    reader.stream(&packet["delivered_input"], DELIVER)?;
    reader.stream(&packet["prompt"], "prompt-authority-missing-or-conflicting")?;
    let schema = panel_schema::load(&root)?;
    let mut contract = fields(
        &dispatch,
        &[
            "packet",
            "adapter",
            "activation",
            "redispatch_policy_ref",
            "seats",
            "decision_checks",
            "identity_records",
        ],
    );
    contract["contract_version"] = json!("1");
    contract["authority_ref"] = authority.clone();
    if let Some(r) = dispatch.get("resolve_authority_ref") {
        contract["resolve_authority_ref"] = r.clone();
    }
    require(
        panel_schema::validate(&contract, &schema["$defs"]["agentic_panel"], &schema)?.is_empty(),
        CTX,
        "closed independent dispatch contract malformed",
    )?;
    let mut context = Context {
        identity: identity.clone(),
        dispatch,
        authority: authority.clone(),
        root,
        sequence: sequence.clone(),
        operation: Value::Null,
    };
    let dispatch = &context.dispatch;
    let projection = report(
        &context,
        &dispatch["packet"]["projection_review"],
        None,
        false,
        &mut reader,
        DELIVER,
    )?;
    require(
        projection["canonical_input"] == intake
            && projection["delivered_input"] == dispatch["packet"]["delivered_input"]
            && projection["exclusion_pass"] == true
            && projection["fidelity_pass"] == true,
        DELIVER,
        "independent exclusion/fidelity proof missing",
    )?;
    require(
        closed(&dispatch["adapter"], &["id", "version", "source_sha256"])
            && dispatch["adapter"]["id"]
                .as_str()
                .is_some_and(|s| !s.is_empty())
            && dispatch["adapter"]["version"]
                .as_str()
                .is_some_and(|s| !s.is_empty())
            && dispatch["launcher_version"]
                .as_str()
                .is_some_and(|s| !s.is_empty()),
        LAUNCH,
        "adapter/launcher identity missing",
    )?;
    let launcher = report(
        &context,
        &dispatch["launcher_ref"],
        None,
        false,
        &mut reader,
        LAUNCH,
    )?;
    require(
        launcher["adapter"] == dispatch["adapter"]
            && launcher["launcher_version"] == dispatch["launcher_version"],
        LAUNCH,
        "launcher configuration identity conflicts",
    )?;
    let policy = report(
        &context,
        &dispatch["redispatch_policy_ref"],
        None,
        false,
        &mut reader,
        ATT,
    )?;
    require(
        policy["authorized"] == true,
        CTX,
        "prospective redispatch policy not authorized",
    )?;
    if let Some(reference) = dispatch.get("resolve_authority_ref") {
        let operation = report(&context, reference, None, false, &mut reader, ATT)?;
        require(
            operation["authorized"] == true
                && operation["role"] == "lead"
                && list(&dispatch["identity_records"]).iter().any(|r| {
                    r["role"] == "lead"
                        && r["subject_id"] == operation["subject_id"]
                        && r["session_id"] == operation["session_id"]
                })
                && operation["reports"].is_array()
                && list(&operation["reports"]).len() <= 2048
                && list(&operation["reports"]).iter().all(reference_ok),
            ATT,
            "resolve operation authority incomplete",
        )?;
        context.operation = operation;
    }
    reader.dispatch(authority, &context.root)?;
    Ok((context, reader))
}
fn report(
    context: &Context,
    r: &Value,
    bound: Option<&Value>,
    operation: bool,
    reader: &mut Reader,
    kind: &str,
) -> Result<Value> {
    report_check(context, r, bound, operation, false, reader, kind)
}
fn report_check(
    context: &Context,
    r: &Value,
    bound: Option<&Value>,
    operation: bool,
    retained: bool,
    reader: &mut Reader,
    kind: &str,
) -> Result<Value> {
    require(
        reference_ok(r)
            && if operation {
                list(&context.operation["reports"]).contains(r)
            } else {
                contains(&context.dispatch, r)
            },
        kind,
        "report reference is not authorized by independent dispatch",
    )?;
    let mut independent = Value::Null;
    for seat in list(&context.dispatch["seats"]) {
        for attempt in list(&seat["attempts"]) {
            if [
                "reads_ref",
                "admission_ref",
                "account_ref",
                "supersession_ref",
                "exception_ref",
                "transport_ref",
            ]
            .iter()
            .any(|k| attempt[*k] == *r)
            {
                require(
                    retained
                        || (seat["attempt_id"] == attempt["attempt_id"]
                            && attempt["status"] == "current"),
                    kind,
                    "noncurrent/unselected pointer has no current dependent authority",
                )?;
                independent = merge(
                    fields(seat, &["seat_id"]),
                    fields(attempt, &["attempt_id", "session_id"]),
                );
                if let Some(bound) = bound {
                    require(
                        subset(&independent, bound),
                        kind,
                        "caller report identity conflicts with independent attempt/session",
                    )?;
                }
            }
        }
    }
    let value = reader.read(r, kind)?;
    require(
        ["expected_context", "expected_hash", "expected_sha256"]
            .iter()
            .all(|k| value.get(*k).is_none()),
        kind,
        "report-supplied expected authority rejected",
    )?;
    require(
        same(&value["context"], &context.identity),
        kind,
        "report operation context conflicts",
    )?;
    require(
        context.sequence.is_null() || same(&value["sequence_context"], &context.sequence),
        kind,
        "report sequence context conflicts",
    )?;
    let required = if independent.is_null() {
        bound
    } else {
        Some(&independent)
    };
    if let Some(bound) = required {
        require(
            subset(&value, bound),
            kind,
            "report seat/attempt/session conflicts",
        )?;
    }
    if operation {
        let durable = reader.read(&context.dispatch["resolve_authority_ref"], kind)?;
        require(
            durable == context.operation
                && value["reproduced"] == true
                && value["producer_id"] == durable["subject_id"]
                && value["producer_session_id"] == durable["session_id"],
            kind,
            "resolve reproduction producer/authority conflicts",
        )?;
    }
    Ok(value)
}
fn qualification(panel: &Value, context: &Context, reader: &mut Reader) -> Result<bool> {
    let activation = &panel["activation"];
    require(
        same(activation, &context.dispatch["activation"]) && activation.is_object(),
        QUAL,
        "independent activation conflicts",
    )?;
    if activation["mode"] == "record_only" {
        for key in ["authorization_ref", "qualification_ref"] {
            if !activation[key].is_null() {
                report(context, &activation[key], None, false, reader, QUAL)?;
            }
        }
        return Ok(false);
    }
    require(
        activation["mode"] == "qualified"
            && activation["first_round"]
                .as_u64()
                .zip(context.identity["round"].as_u64())
                .is_some_and(|(a, b)| a <= b),
        QUAL,
        "qualified activation boundary conflicts",
    )?;
    for key in ["authorization_ref", "qualification_ref"] {
        let proof = report(context, &activation[key], None, false, reader, QUAL)?;
        require(
            proof["authorized"] == true
                && proof["adapter"] == context.dispatch["adapter"]
                && same(&proof["first_round"], &activation["first_round"]),
            QUAL,
            "compatible independent qualified authority missing",
        )?;
        require(
            key != "qualification_ref" || proof["qualified"] == true,
            QUAL,
            "adapter/fixtures/consumer qualification missing",
        )?;
    }
    Ok(true)
}
fn grounded(account: &Value) -> bool {
    nonblank(&account["grounded_reasoning"])
        && account["material_limitations"].is_array()
        && list(&account["material_limitations"]).iter().all(nonblank)
}
fn deficient(account: &Value) -> bool {
    account["material_deficiency"] == true
        && match account["kind"].as_str() {
            Some("positive_contradiction") => {
                ["claimed_invocation", "claimed_result"]
                    .iter()
                    .all(|k| account[*k].as_str().is_some_and(|s| !s.is_empty()))
                    && account["reruns_resolved"] == true
                    && account["contradiction_proved"] == true
            }
            Some("qualified_absence") => [
                "necessary_record_action_claim",
                "complete_bound_coverage",
                "qualified_event_decoding",
            ]
            .iter()
            .all(|k| account[*k] == true),
            _ => false,
        }
}
fn attempt_instant(value: &Value) -> Result<chrono::DateTime<chrono::FixedOffset>> {
    let value = value.as_str().ok_or("attempt instant required")?;
    require(
        regex::Regex::new(
            r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$",
        )
        .unwrap()
        .is_match(value),
        ATT,
        "attempt ordering requires whole-second ISO-8601",
    )?;
    require(
        value
            .get(17..19)
            .and_then(|s| s.parse::<u32>().ok())
            .is_some_and(|s| s < 60)
            && value.get(..4) != Some("0000"),
        ATT,
        "attempt instant components invalid",
    )?;
    named(instant(value), ATT)
}
fn history(seat: &Value, retained: &[(Value, Value)], policy: &Value) -> Result<()> {
    if retained.len() < 2 && !retained.iter().any(|(a, _)| a["status"] == "superseded") {
        return Ok(());
    }
    require(
        policy["max_redispatches"]
            .as_u64()
            .is_some_and(|n| n <= 15 && retained.len().saturating_sub(1) <= n as usize)
            && policy["technical_causes"].is_array()
            && !list(&policy["technical_causes"]).is_empty()
            && list(&policy["technical_causes"]).iter().all(nonblank)
            && policy["exhaustion"] == "non-response",
        ATT,
        "bounded prospective technical retry policy missing or exhausted",
    )?;
    let mut ordered = retained
        .iter()
        .map(|pair| {
            attempt_instant(&pair.1["admission_ref"]["launched_at"]).map(|time| (time, pair))
        })
        .collect::<Result<Vec<_>>>()?;
    ordered.sort_by_key(|(time, _)| *time);
    require(
        attempt_instant(&policy["authorized_at"])? <= ordered[0].0,
        ATT,
        "redispatch policy does not precede initial launch",
    )?;
    for pair in ordered.windows(2) {
        let (old, proofs) = pair[0].1;
        let (new, _) = pair[1].1;
        let admission = &proofs["admission_ref"];
        let supersession = &proofs["supersession_ref"];
        require(
            !(admission["admitted"] == true && admission["raw_verdict"] == "FAIL"),
            ATT,
            "admitted FAIL cannot justify or be replaced by retry",
        )?;
        require(
            ["superseded", "launch_failed"]
                .iter()
                .any(|v| old["status"] == *v)
                && supersession["authorized"] == true
                && list(&policy["technical_causes"]).contains(&supersession["cause"])
                && supersession["technical"] == true
                && supersession["replacement_attempt_id"] == new["attempt_id"]
                && supersession["replacement_session_id"] == new["session_id"],
            ATT,
            "retry lacks committed technical supersession/replacement identity",
        )?;
        let committed = attempt_instant(&supersession["committed_at"])?;
        require(
            pair[0].0 <= committed && committed < pair[1].0,
            ATT,
            "supersession must commit before replacement launch",
        )?;
        require(
            old["session_id"] != new["session_id"],
            ATT,
            "replacement requires fresh session identity",
        )?;
    }
    let last = &ordered.last().unwrap().1 .0;
    require(
        last["status"] != "superseded"
            && (seat["attempt_id"].is_null() || seat["attempt_id"] == last["attempt_id"]),
        ATT,
        "failed or missing replacement cannot revive predecessor",
    )
}
fn admission_packet(
    admission: &Value,
    reads: &Value,
    attempt: &Value,
    packet: &Value,
) -> Result<()> {
    require(
        ["canonical_input", "delivered_input", "manifest", "prompt"]
            .iter()
            .all(|k| admission[*k] == packet[*k]),
        ATT,
        "admission does not bind frozen canonical/delivered packet",
    )?;
    require(
        reads.is_object()
            && reads["native_session_ref"] == attempt["native_session_ref"]
            && reads["final_ref"] == attempt["final_ref"]
            && reads["actual_reads_verified"] == true
            && ["canonical_input", "delivered_input", "manifest", "prompt"]
                .iter()
                .all(|k| reads[*k] == packet[*k]),
        ATT,
        "admission lacks bound actual session-read evidence",
    )
}
fn decision_identities(panel: &Value, subject: &Value, checker: &Value) -> Result<()> {
    let mut expected = vec![
        (
            "lead",
            subject["subject_id"].clone(),
            subject["session_id"].clone(),
        ),
        (
            "checker",
            checker["subject_id"].clone(),
            checker["session_id"].clone(),
        ),
    ];
    for seat in list(&panel["seats"]) {
        if let Some(attempt) = list(&seat["attempts"])
            .iter()
            .find(|a| a["attempt_id"] == seat["attempt_id"])
        {
            expected.push((
                "seat",
                seat["seat_id"].clone(),
                attempt["session_id"].clone(),
            ));
        }
    }
    for (role, subject, session) in expected {
        let matches: Vec<_> = list(&panel["identity_records"])
            .iter()
            .filter(|r| {
                r["role"] == role && r["subject_id"] == subject && r["session_id"] == session
            })
            .collect();
        require(
            matches.len() == 1 && nonblank(&subject) && nonblank(&session),
            IDENTITY,
            "applicable role identity record missing or ambiguous",
        )?;
        let record = matches[0];
        require(
            nonblank(&record["requested_profile"]),
            IDENTITY,
            "requested identity profile missing",
        )?;
        let unknown = ["effective_profile", "effective_family", "evidence_ref"]
            .iter()
            .any(|k| record[*k].is_null());
        require(
            !unknown
                || (record["unknowns"].is_array()
                    && !list(&record["unknowns"]).is_empty()
                    && list(&record["unknowns"]).iter().all(nonblank)),
            IDENTITY,
            "unproved effective identity requires explicit unknowns",
        )?;
        require(
            (record["effective_profile"].is_null() && record["effective_family"].is_null())
                || !record["evidence_ref"].is_null(),
            IDENTITY,
            "effective identity claim requires recorded evidence",
        )?;
    }
    Ok(())
}
fn decision(check: &Value, context: &Context, reader: &mut Reader) -> Result<()> {
    require(
        ["reclassification", "convergence", "shared_domain_design"]
            .iter()
            .any(|k| check["kind"] == *k)
            && nonblank(&check["decision_id"]),
        DECISION,
        "recorded decision kind/id missing",
    )?;
    let mut keys = vec![
        "subject_ref",
        "checker_identity_ref",
        "proof_ref",
        "authority_ref",
    ];
    if check["kind"] == "shared_domain_design" || check.get("caller_domain_review_ref").is_some() {
        keys.push("caller_domain_review_ref");
    }
    let mut reports = BTreeMap::new();
    for key in keys {
        reports.insert(
            key,
            report(context, &check[key], None, false, reader, DECISION)?,
        );
    }
    let subject = &reports["subject_ref"];
    let checker = &reports["checker_identity_ref"];
    let proof = &reports["proof_ref"];
    let authority = &reports["authority_ref"];
    decision_identities(&context.dispatch, subject, checker)?;
    let leads: Vec<_> = list(&context.dispatch["identity_records"])
        .iter()
        .filter(|r| r["role"] == "lead")
        .collect();
    require(
        leads.len() == 1
            && fields(subject, &["subject_id", "session_id"])
                == fields(leads[0], &["subject_id", "session_id"]),
        DECISION,
        "decision subject is not the authorized lead",
    )?;
    require(
        [
            &subject["subject_id"],
            &subject["session_id"],
            &checker["subject_id"],
            &checker["session_id"],
        ]
        .into_iter()
        .all(nonblank)
            && subject["subject_id"] != checker["subject_id"]
            && subject["session_id"] != checker["session_id"]
            && reports
                .values()
                .all(|r| r["decision_id"] == check["decision_id"] && r["kind"] == check["kind"])
            && [proof, authority].into_iter().all(|r| {
                r["subject_ref"] == check["subject_ref"]
                    && r["checker_identity_ref"] == check["checker_identity_ref"]
            })
            && authority["proof_ref"] == check["proof_ref"]
            && proof["independent"] == true
            && proof["reproduction_or_proof"] == true
            && proof["scope_authority_checked"] == true
            && authority["authorized"] == true,
        DECISION,
        "independent decision proof incomplete",
    )?;
    if check["kind"] == "shared_domain_design" {
        let review = &reports["caller_domain_review_ref"];
        require(
            review["subject_ref"] == check["subject_ref"]
                && review["checker_identity_ref"] == check["checker_identity_ref"]
                && review["proof_ref"] == check["proof_ref"]
                && [
                    "independent",
                    "reproduction_or_proof",
                    "scope_authority_checked",
                ]
                .iter()
                .all(|k| review[*k] == true)
                && [
                    "caller_effects",
                    "representative_pre_post_outcomes",
                    "late_handlers",
                    "lifetimes",
                ]
                .iter()
                .all(|k| nonblank(&review[*k])),
            DECISION,
            "shared-domain decision caller review incomplete",
        )?;
    }
    Ok(())
}
fn accounting(ledger: &Value) -> Result<()> {
    let panel = &ledger["agentic_panel"];
    let seats = list(&panel["seats"]);
    let mode = &panel["activation"]["mode"];
    require(
        mode != "qualified"
            || panel["activation"]["first_round"]
                .as_f64()
                .zip(ledger["round"].as_f64())
                .is_none_or(|(first, round)| round >= first),
        ATT,
        "qualified accounting precedes boundary",
    )?;
    for r in list(&panel["identity_records"]) {
        let unknown = ["effective_profile", "effective_family", "evidence_ref"]
            .iter()
            .any(|k| r[*k].is_null());
        require(
            !unknown || r["unknowns"] != json!([]),
            ATT,
            "unproved effective identity requires explicit unknowns",
        )?;
        require(
            (r["effective_profile"].is_null() && r["effective_family"].is_null())
                || !r["evidence_ref"].is_null(),
            ATT,
            "effective identity claim requires recorded evidence",
        )?;
    }
    let mut ids = BTreeSet::new();
    let mut sessions = BTreeMap::new();
    let mut files = BTreeMap::new();
    let mut responded = BTreeSet::new();
    for seat in seats {
        let id = s(seat, "seat_id")?;
        require(
            !id.trim().is_empty() && ids.insert(id.to_owned()),
            ATT,
            "duplicate or blank logical seat",
        )?;
        let mut attempts = BTreeMap::new();
        let mut current = Vec::new();
        for attempt in list(&seat["attempts"]) {
            let attempt_id = s(attempt, "attempt_id")?;
            require(
                !attempt_id.trim().is_empty() && attempts.insert(attempt_id, attempt).is_none(),
                ATT,
                "duplicate or blank retained attempt",
            )?;
            let owner = (id.to_owned(), attempt_id.to_owned());
            if let Some(session) = attempt["session_id"].as_str() {
                require(
                    sessions.get(session).is_none_or(|prior| prior == &owner),
                    ATT,
                    "retained session identity shared across owners",
                )?;
                sessions.insert(session.to_owned(), owner.clone());
            }
            for key in ["native_session_ref", "final_ref"] {
                if let Some(path) = attempt[key]["path"].as_str() {
                    let role = (owner.clone(), key);
                    require(
                        files.get(path).is_none_or(|prior| prior == &role),
                        ATT,
                        "retained native identity shared across roles or owners",
                    )?;
                    files.insert(path.to_owned(), role);
                }
            }
            if attempt["status"] == "current" {
                current.push(attempt_id);
            }
        }
        let selected = seat["attempt_id"]
            .as_str()
            .and_then(|id| attempts.get(id).copied());
        require(
            seat["attempt_id"].is_null() || selected.is_some(),
            ATT,
            "selected attempt absent",
        )?;
        require(
            current.len() <= 1 && (current.is_empty() || seat["attempt_id"] == current[0]),
            ATT,
            "must select sole current attempt",
        )?;
        require(
            selected.is_none_or(|a| a["status"] != "superseded"),
            ATT,
            "superseded attempt cannot revive",
        )?;
        if let (Some(a), Some(b)) = (seat["admitted"].as_bool(), seat["responding"].as_bool()) {
            require(a == b, ATT, "protocol response must equal admission")?;
        }
        if seat["responding"] == true {
            responded.insert(id.to_owned());
        }
        require(
            seat["admitted"] != true
                || selected.is_some_and(|a| {
                    a["status"] == "current"
                        && a["native_session_ref"].is_object()
                        && a["final_ref"].is_object()
                        && (passing(&seat["raw_verdict"]) || seat["raw_verdict"] == "FAIL")
                }),
            ATT,
            "admission requires current native/final and verdict",
        )?;
        require(
            seat["raw_verdict"].is_null() || selected.is_some_and(|a| a["final_ref"].is_object()),
            ATT,
            "raw verdict requires retained selected final",
        )?;
        let passed =
            seat["admitted"] == true && seat["responding"] == true && passing(&seat["raw_verdict"]);
        require(
            seat["pass_floor_eligible"] != true || passed,
            ATT,
            "floor credit requires admitted responding PASS",
        )?;
        require(
            !(mode == "record_only" && passed && seat["pass_floor_eligible"] == false),
            ATT,
            "record_only cannot remove account floor credit",
        )?;
        require(
            !(mode == "qualified" && passed && seat["pass_floor_eligible"] == false)
                || selected.is_some_and(|a| a["admission_ref"].is_object()),
            ATT,
            "qualified removal requires bound admission",
        )?;
        for key in ["admission_cause", "floor_cause"] {
            require(
                seat[key].as_str().is_none_or(|s| !s.trim().is_empty()),
                ATT,
                "cause must be nonblank",
            )?;
        }
    }
    let strings = |v: &Value| {
        list(v)
            .iter()
            .filter_map(Value::as_str)
            .map(str::to_owned)
            .collect::<BTreeSet<_>>()
    };
    if ledger["panel"]["dispatched"].is_array() {
        require(
            ids.is_subset(&strings(&ledger["panel"]["dispatched"])),
            ATT,
            "logical seat was not dispatched",
        )?;
    }
    if ledger["panel"]["responded"].is_array() {
        require(
            strings(&ledger["panel"]["responded"])
                .intersection(&ids)
                .cloned()
                .collect::<BTreeSet<_>>()
                == responded,
            ATT,
            "response projection conflicts",
        )?;
    }
    if ledger["verdicts"]["models"].is_array() {
        for seat in seats {
            let rows: Vec<_> = list(&ledger["verdicts"]["models"])
                .iter()
                .filter(|r| r["model"] == seat["seat_id"])
                .collect();
            require(
                rows.len() == 1,
                ATT,
                "logical seat requires one raw verdict row",
            )?;
            let r = rows[0];
            require(
                (seat["raw_verdict"].is_null() || r["verdict"] == seat["raw_verdict"])
                    && ((r["responded"] != "no")
                        == (seat["admitted"] == true && seat["responding"] == true)),
                ATT,
                "raw verdict/response projection conflicts",
            )?;
        }
    }
    for finding in list(&ledger["findings"]) {
        let mut seen = BTreeSet::new();
        for p in list(&finding["unadmitted_evidence"]) {
            let seat = seats.iter().find(|s| s["seat_id"] == p["seat_id"]);
            let attempt = seat.and_then(|s| {
                list(&s["attempts"])
                    .iter()
                    .find(|a| a["attempt_id"] == p["attempt_id"])
            });
            require(
                seen.insert((s(p, "seat_id")?.to_owned(), s(p, "attempt_id")?.to_owned()))
                    && attempt.is_some_and(|a| {
                        a["final_ref"].is_object() && a["final_ref"] == p["final_ref"]
                    })
                    && seat.is_none_or(|s| {
                        s["admitted"] != true || s["attempt_id"] != p["attempt_id"]
                    }),
                ATT,
                "unadmitted provenance duplicate/unknown/final/admission conflict",
            )?;
            null_reproduction(finding, p)?;
        }
    }
    Ok(())
}
fn null_reproduction(finding: &Value, p: &Value) -> Result<()> {
    require(!p["reproduction_ref"].is_null()||(finding["classification"].is_null()&&["not-reproducible","not-yet-reproduced"].iter().any(|s|p["reproduction_status"]==*s)&&nonblank(&p["reproduction_reason"])),ATT,"classified unadmitted finding requires reproduction; unclassified null needs status and reason")
}
fn evidence(ledger: &Value, context: &Context, reader: &mut Reader) -> Result<()> {
    let panel = &ledger["agentic_panel"];
    let dispatch = &context.dispatch;
    let mut keys = vec![
        "contract_version",
        "adapter",
        "activation",
        "packet",
        "authority_ref",
        "redispatch_policy_ref",
        "seats",
        "decision_checks",
        "identity_records",
    ];
    if panel.get("resolve_authority_ref").is_some() {
        keys.push("resolve_authority_ref");
    }
    require(
        panel.is_object() && panel["contract_version"] == "1" && closed(panel, &keys),
        "required-contract-missing",
        "closed version-1 contract required",
    )?;
    require(
        ["topic", "cycle_type", "round"]
            .iter()
            .all(|k| same(&ledger[*k], &context.identity[*k])),
        CYCLE,
        "ledger operation identity conflicts",
    )?;
    require(
        panel["authority_ref"] == context.authority,
        CTX,
        "original independent authority reference conflicts",
    )?;
    for (key, error) in [
        ("canonical_input", CTX),
        ("manifest", CTX),
        ("delivered_input", DELIVER),
        ("projection_review", DELIVER),
        ("prompt", "prompt-authority-missing-or-conflicting"),
    ] {
        require(
            panel["packet"][key] == dispatch["packet"][key],
            error,
            "recorded packet conflicts",
        )?;
    }
    require(
        panel["resolve_authority_ref"] == dispatch["resolve_authority_ref"]
            && panel["redispatch_policy_ref"] == dispatch["redispatch_policy_ref"],
        CTX,
        "recorded operation/redispatch authority conflicts",
    )?;
    require(
        panel["adapter"] == dispatch["adapter"],
        LAUNCH,
        "recorded adapter conflicts",
    )?;
    let qualified = qualification(panel, context, reader)?;
    if ledger.get("panel").is_some() {
        accounting(ledger)?;
    }
    require(
        same(&panel["seats"], &dispatch["seats"])
            && !list(&dispatch["seats"]).is_empty()
            && list(&dispatch["seats"]).len() <= 64,
        ATT,
        "retained/current attempt or session authority conflicts",
    )?;
    let mut native_owners = BTreeMap::new();
    for seat in list(&dispatch["seats"]) {
        require(
            seat["attempts"].is_array() && list(&seat["attempts"]).len() <= 16,
            ATT,
            "bounded attempt authority required",
        )?;
        let mut retained = Vec::new();
        for attempt in list(&seat["attempts"]) {
            require(
                attempt["launcher_ref"] == dispatch["launcher_ref"],
                LAUNCH,
                "attempt launcher conflicts",
            )?;
            let bound = merge(
                fields(seat, &["seat_id"]),
                fields(attempt, &["attempt_id", "session_id"]),
            );
            for key in ["native_session_ref", "final_ref"] {
                if !attempt[key].is_null() {
                    reader.stream(&attempt[key], ATT)?;
                    let identity = reader.identities[s(&attempt[key], "path")?];
                    let owner = (seat["seat_id"].clone(), attempt["attempt_id"].clone(), key);
                    require(
                        native_owners
                            .get(&identity)
                            .is_none_or(|prior| prior == &owner),
                        ATT,
                        "retained native file identity shared across roles or owners",
                    )?;
                    native_owners.insert(identity, owner);
                }
            }
            let mut proofs = json!({});
            for key in [
                "reads_ref",
                "admission_ref",
                "account_ref",
                "supersession_ref",
                "exception_ref",
                "transport_ref",
            ] {
                if !attempt[key].is_null() {
                    proofs[key] = report_check(
                        context,
                        &attempt[key],
                        Some(&bound),
                        false,
                        true,
                        reader,
                        ATT,
                    )?;
                }
            }
            let admission = &proofs["admission_ref"];
            require(
                admission["status"] == attempt["status"]
                    && admission["native_session_ref"] == attempt["native_session_ref"]
                    && admission["final_ref"] == attempt["final_ref"],
                ATT,
                "admission does not bind retained native/final identity",
            )?;
            if attempt["attempt_id"] == seat["attempt_id"] {
                require(
                    admission["admitted"] == seat["admitted"]
                        && admission["raw_verdict"] == seat["raw_verdict"],
                    ATT,
                    "selected admission/verdict conflicts",
                )?;
                if seat["admitted"] == true {
                    admission_packet(
                        admission,
                        &proofs["reads_ref"],
                        attempt,
                        &dispatch["packet"],
                    )?;
                    let account = &proofs["account_ref"];
                    require(
                        account.is_null() || account["final_ref"] == attempt["final_ref"],
                        ATT,
                        "account final identity conflicts",
                    )?;
                    if qualified && passing(&seat["raw_verdict"]) {
                        require(seat["pass_floor_eligible"]==!( !grounded(account)||deficient(account)),QUAL,"qualified credit disagrees with bound material contradiction/absence proof")?;
                    }
                }
            }
            retained.push((attempt.clone(), proofs));
        }
        history(
            seat,
            &retained,
            &reader.read(&dispatch["redispatch_policy_ref"], CTX)?,
        )?;
    }
    for finding in list(&ledger["findings"]) {
        for p in list(&finding["unadmitted_evidence"]) {
            null_reproduction(finding, p)?;
            reader.stream(&p["final_ref"], ATT)?;
            if !p["reproduction_ref"].is_null() {
                let attempt = list(&dispatch["seats"])
                    .iter()
                    .filter(|s| s["seat_id"] == p["seat_id"])
                    .flat_map(|s| list(&s["attempts"]))
                    .find(|a| a["attempt_id"] == p["attempt_id"])
                    .ok_or_else(|| {
                        format!("agentic-dependency:{ATT}: unknown retained seat/attempt")
                    })?;
                let bound = merge(
                    fields(p, &["seat_id", "attempt_id"]),
                    fields(attempt, &["session_id"]),
                );
                let reproduction = report(
                    context,
                    &p["reproduction_ref"],
                    Some(&bound),
                    true,
                    reader,
                    ATT,
                )?;
                require(
                    reproduction["final_ref"] == attempt["final_ref"]
                        && p["final_ref"] == attempt["final_ref"],
                    ATT,
                    "reproduction retained final identity conflicts",
                )?;
            }
        }
    }
    for key in ["decision_checks", "identity_records"] {
        require(
            panel[key] == dispatch[key],
            CTX,
            "independent decision/identity authority conflicts",
        )?;
    }
    require(
        !["close", "advance"].iter().any(|v| ledger["action"] == *v)
            || list(&panel["decision_checks"])
                .iter()
                .any(|d| d["kind"] == "convergence"),
        DECISION,
        "fresh completion requires independent convergence decision evidence",
    )?;
    for check in list(&panel["decision_checks"]) {
        decision(check, context, reader)?;
    }
    for record in list(&panel["identity_records"]) {
        if !record["evidence_ref"].is_null() {
            let proof = report(context, &record["evidence_ref"], None, false, reader, ATT)?;
            require(
                [
                    "subject_id",
                    "session_id",
                    "effective_profile",
                    "effective_family",
                ]
                .iter()
                .all(|k| proof[*k] == record[*k]),
                ATT,
                "effective identity evidence conflicts",
            )?;
        }
    }
    reader.dispatch(&context.authority, &context.root)?;
    reader.stream(&dispatch["packet"]["canonical_input"], INTAKE)?;
    reader.read(&dispatch["packet"]["manifest"], MANIFEST)?;
    Ok(())
}
pub(crate) fn verify(value: &Value) -> Result<Value> {
    let identity = fields(
        &value["dispatch"],
        &["topic", "cycle_type", "cycle", "round"],
    );
    let (initial, _) = resolve(
        Path::new(s(value, "project_root")?),
        &identity,
        &value["authority"],
        &value["dispatch"]["sequence_context"],
    )?;
    for _ in 0..2 {
        let (context, mut reader) = resolve(
            &initial.root,
            &identity,
            &initial.authority,
            &initial.sequence,
        )?;
        require(
            context.dispatch == initial.dispatch,
            CTX,
            "dispatch authority changed",
        )?;
        evidence(&value["ledger"], &context, &mut reader)?;
    }
    let ledger = &value["ledger"];
    let mut sources = BTreeSet::new();
    for row in list(&ledger["verdicts"]["models"]) {
        if passing(&row["verdict"]) && row["responded"] != "no" {
            sources.insert(s(row, "model")?.to_owned());
        }
    }
    for seat in list(&ledger["agentic_panel"]["seats"]) {
        let id = s(seat, "seat_id")?;
        sources.remove(id);
        if seat["admitted"] == true
            && seat["responding"] == true
            && passing(&seat["raw_verdict"])
            && (ledger["agentic_panel"]["activation"]["mode"] == "record_only"
                || seat["pass_floor_eligible"] == true)
        {
            sources.insert(id.into());
        }
    }
    Ok(json!(sources))
}

#[cfg(test)]
#[path = "../tests/support/panel_protocol.rs"]
mod tests;
