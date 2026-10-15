use super::*;

#[test]
fn preservation_chain_is_required_before_target_resolution() {
    let root = home().unwrap().join("desk/tmp").join(format!(
        "panel-preservation-{}",
        crate::runtime::fresh_id().unwrap()
    ));
    fs::create_dir(&root).unwrap();
    let batch = root.join("batch");
    fs::create_dir(&batch).unwrap();
    let context = json!({"topic":"fixture","cycle_type":"implementation","cycle":"one","round":1});
    let adapter = json!({"id":"fixture-adapter","version":"1","source_sha256":"0".repeat(64)});
    let launcher = fresh(
        &root.join("launcher.json"),
        &json!({"context":context,"adapter":adapter}),
    )
    .unwrap();
    let request=fresh(&root.join("request.json"),&json!({"authorized":true,"topic":"fixture","cycle_type":"implementation","cycle":"one","round":1,"launcher_ref":launcher})).unwrap();
    let seat =
        json!({"seat_id":"a","attempt_id":"one","directory":"/fixtures/seat","window":"owned"});
    let prepared=fresh(&batch.join("prepared.json"),&json!({"phase":"prepared","context":context,"adapter":adapter,"request_ref":request,"batch":batch,"seats":[seat]})).unwrap();
    let launch = json!({"phase":"owned-launch","context":context,"adapter":adapter,"request_ref":request,"prepared_ref":prepared,"batch":batch,"seats":[seat]});
    let launch_ref = fresh(&root.join("launch.json"), &launch).unwrap();
    let index=fresh(&root.join("index.json"),&json!({"context":context,"launch_ref":launch_ref,"seats":[{"seat_id":"a","attempt_id":"one","native_ref":null,"non_observation":true,"cause":"no native observed"}]})).unwrap();
    let collection = json!({"phase":"unadmitted-retention","context":context,"adapter":adapter,"request_ref":request,"prepared_ref":prepared,"batch":batch,"launch_ref":launch_ref,"native_index_ref":index,"created_at":now(),"seats":[{"seat_id":"a","attempt_id":"one","native_session_ref":null,"final_ref":null,"admitted":false,"responding":false,"raw_verdict":null,"pass_floor_eligible":false,"cause":"no native observed","findings":"retain"}]});
    let collection_ref = fresh(&root.join("retained.json"), &collection).unwrap();
    preserved(&launch, &launch_ref, &collection, &collection_ref).unwrap();
    let mut controls = Vec::new();
    let mut wrong = collection.clone();
    wrong["phase"] = json!("anything");
    controls.push(wrong);
    let mut wrong = collection.clone();
    wrong["batch"] = json!("/fixtures/wrong-batch");
    controls.push(wrong);
    let mut wrong = collection.clone();
    wrong["context"]["round"] = json!(2);
    controls.push(wrong);
    let mut wrong = collection.clone();
    wrong["seats"][0]["cause"] = json!("");
    controls.push(wrong);
    let mut wrong = collection.clone();
    wrong["launch_ref"]["sha256"] = json!("f".repeat(64));
    controls.push(wrong);
    let mut wrong = collection.clone();
    wrong["seats"][0]["pass_floor_eligible"] = json!(true);
    controls.push(wrong);
    for wrong in controls {
        assert!(preserved(&launch, &launch_ref, &wrong, &collection_ref).is_err());
    }
    let mut wrong = launch.clone();
    wrong["phase"] = json!("prestart-recovery");
    assert!(preserved(&wrong, &launch_ref, &collection, &collection_ref).is_err());
    fs::remove_dir_all(root).unwrap();
}
