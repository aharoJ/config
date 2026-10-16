use crate::{panel_dispatch::*, panel_io::*, panel_native};
use serde_json::{json, Value};
use std::path::Path;

pub(crate) fn collect(args: &Args) -> Result<Value> {
    let launch_ref = authority(args, "launched", "sha256")?;
    let launch = read(&launch_ref)?;
    let request = request_check(&launch["request_ref"])?;
    let preparation = read(&launch["prepared_ref"])?;
    check(
        launch["phase"] == "launched"
            && launch["adapter"] == adapter()?
            && launch["context"] == context(&request)
            && preparation["request_ref"] == launch["request_ref"]
            && launch["batch"] == preparation["batch"],
        "collection launch/preparation/source conflict",
    )?;
    let seats = a(&launch, "seats")?;
    let prepared = a(&preparation, "seats")?;
    let roster = a(&request, "roster")?;
    check(
        seats.len() == prepared.len() && prepared.len() == roster.len(),
        "collection roster length mismatch",
    )?;
    for ((seat, prepared), wanted) in seats.iter().zip(prepared).zip(roster) {
        check(
            subset(seat, prepared) && subset(seat, wanted),
            "collection roster/profile/input drift",
        )?;
        for reference in seat["inputs"]
            .as_object()
            .ok_or("seat inputs missing")?
            .values()
        {
            read_bytes(reference)?;
        }
    }
    let native_ref = authority(args, "native-index", "native-sha256")?;
    let native = read(&native_ref)?;
    check(
        closed(&native, &["context", "launch_ref", "seats"])
            && native["context"] == launch["context"]
            && native["launch_ref"] == launch_ref,
        "independent native index context conflict",
    )?;
    let evidence = a(&native, "seats")?;
    check(evidence.len() == seats.len(), "native roster mismatch")?;
    check(
        seats.iter().all(|seat| seat["transport"] != "gemini"),
        "Agy automatic admission unqualified; use retain, not collect",
    )?;
    let batch = Path::new(s(&launch, "batch")?);
    let mut outputs = Vec::new();
    for (seat, evidence) in seats.iter().zip(evidence) {
        check(
            closed(
                evidence,
                &[
                    "seat_id",
                    "attempt_id",
                    "native_ref",
                    "format",
                    "descendants",
                    "boundary_review_ref",
                    "account_ref",
                ],
            ),
            "closed native row required",
        )?;
        check(
            fields(evidence, &["seat_id", "attempt_id"])
                == fields(seat, &["seat_id", "attempt_id"])
                && evidence["format"] == format(s(seat, "transport")?)?,
            "native row identity/order mismatch",
        )?;
        let id = s(seat, "seat_id")?;
        let data = read_bytes(&evidence["native_ref"])?;
        let snapshot = fresh_bytes(&batch.join(format!("{id}-native.jsonl")), &data)?;
        let mut diagnostics = panel_native::inspect(&data, s(evidence, "format")?, seat)?;
        let boundary = read(&evidence["boundary_review_ref"])?;
        check(
            boundary["context"] == launch["context"]
                && fields(&boundary, &["seat_id", "attempt_id"])
                    == fields(seat, &["seat_id", "attempt_id"])
                && boundary["session_id"] == diagnostics["session_id"]
                && boundary["native_ref"] == evidence["native_ref"]
                && boundary["descendants"] == evidence["descendants"],
            "independent native boundary binding mismatch",
        )?;
        check(
            boundary["launch_ref"] == launch_ref
                && boundary["pane"] == seat["pane"]
                && boundary["session_binding_verified"] == true,
            "native session/launch binding missing",
        )?;
        check(
            boundary["independent"] == true
                && boundary["isolation_pass"] == true
                && boundary["external_input_pass"] == true,
            "native boundary admission failed",
        )?;
        check(
            boundary["final_sha256"] == hash(s(&diagnostics, "final_text")?.as_bytes())
                && [Some("PASS"), Some("PASS_WITH_MONITORING"), Some("FAIL")]
                    .contains(&boundary["raw_verdict"].as_str()),
            "independent selected-final/verdict binding required",
        )?;
        if !diagnostics["raw_verdict"].is_null() {
            check(
                diagnostics["raw_verdict"] == boundary["raw_verdict"],
                "literal native verdict conflicts with independent interpretation",
            )?;
        }
        diagnostics["raw_verdict"] = boundary["raw_verdict"].clone();
        for descendant in a(evidence, "descendants")? {
            read_bytes(descendant)?;
        }
        let final_ref = fresh_bytes(
            &batch.join(format!("{id}-final.md")),
            s(&diagnostics, "final_text")?.as_bytes(),
        )?;
        diagnostics.as_object_mut().unwrap().remove("final_text");
        let bound = merge(
            fields(seat, &["seat_id", "attempt_id"]),
            json!({"context":launch["context"],"session_id":diagnostics["session_id"]}),
        );
        let packet = fields(
            &request["packet"],
            &["canonical_input", "delivered_input", "manifest", "prompt"],
        );
        let reads = fresh(
            &batch.join(format!("{id}-reads.json")),
            &merge(
                merge(bound.clone(), packet.clone()),
                json!({"native_session_ref":snapshot,"final_ref":final_ref,"actual_reads_verified":true,"native_reads":diagnostics["reads"]}),
            ),
        )?;
        let admission = fresh(
            &batch.join(format!("{id}-admission.json")),
            &merge(
                merge(bound.clone(), packet),
                json!({"status":"current","admitted":true,"raw_verdict":diagnostics["raw_verdict"],"native_session_ref":snapshot,"final_ref":final_ref,"launched_at":seat["launched_at"],"boundary_review_ref":evidence["boundary_review_ref"]}),
            ),
        )?;
        let diagnostic = fresh(
            &batch.join(format!("{id}-diagnostics.json")),
            &merge(
                merge(bound.clone(), diagnostics.clone()),
                json!({"native_session_ref":snapshot,"final_ref":final_ref}),
            ),
        )?;
        let attempt = json!({"attempt_id":seat["attempt_id"],"session_id":diagnostics["session_id"],"status":"current","launcher_ref":request["launcher_ref"],"native_session_ref":snapshot,"reads_ref":reads,"final_ref":final_ref,"admission_ref":admission,"account_ref":evidence["account_ref"],"supersession_ref":null,"exception_ref":null,"transport_ref":null});
        let eligible = [Some("PASS"), Some("PASS_WITH_MONITORING")]
            .contains(&diagnostics["raw_verdict"].as_str());
        let canonical = merge(
            fields(seat, &["seat_id", "attempt_id"]),
            json!({"responding":true,"admitted":true,"raw_verdict":diagnostics["raw_verdict"],"admission_cause":"bound candidate; requires independent dispatch and consumer verification","pass_floor_eligible":eligible,"floor_cause":"record-only candidate; qualified account checks remain prospective","attempts":[attempt]}),
        );
        check(
            protocol(s(&request, "protocol_root")?, "protocol_schema", &canonical)? == json!([]),
            "canonical seat receipt shape failed",
        )?;
        outputs.push(merge(bound,json!({"native_session_ref":snapshot,"final_ref":final_ref,"reads_ref":reads,"admission_ref":admission,"diagnostic_ref":diagnostic,"account_ref":evidence["account_ref"],"raw_verdict":diagnostics["raw_verdict"],"canonical_record_only_seat":canonical})));
    }
    read(&native_ref)?;
    request_check(&launch["request_ref"])?;
    fresh(
        &batch.join("collected.json"),
        &json!({"phase":"collected","context":launch["context"],"launch_ref":launch_ref,"native_index_ref":native_ref,"adapter":adapter()?,"seats":outputs,"admission_authority":"candidate-only: independently bind in canonical dispatch before consuming"}),
    )
}
