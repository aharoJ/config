use super::*;
use std::fs;
use std::io::Read;

struct Fixture {
    root: PathBuf,
    seat: Value,
}
impl Fixture {
    fn new() -> Self {
        let root = home().unwrap().join("desk/tmp").join(format!(
            "panel-native-{}",
            crate::runtime::fresh_id().unwrap()
        ));
        fs::create_dir(&root).unwrap();
        let mut inputs = Map::new();
        for (name, text) in [
            ("PROMPT.md", "Prompt alpha\nPrompt beta\n"),
            ("intake.md", "Intake one\nIntake two\n"),
        ] {
            let path = root.join(name);
            fs::write(&path, text).unwrap();
            inputs.insert(name.into(), reference(&path).unwrap());
        }
        let seat = json!({"directory":root,"model":"model-observed","effort":"low","inputs":inputs,"delivery":{"native_start":format!("codex: {}",crate::panel_dispatch::START)}});
        Self { root, seat }
    }
    fn rows(&self, fmt: &str) -> Vec<Value> {
        let mut rows = if fmt == "claude-jsonl" {
            vec![
                json!({"type":"user","sessionId":"session-a","cwd":self.root,"message":{"role":"user","content":self.seat["delivery"]["native_start"]}}),
            ]
        } else {
            vec![
                json!({"type":"session_meta","payload":{"id":"session-a","cwd":self.root}}),
                json!({"type":"turn_context","payload":{"model":"model-observed","effort":"low","cwd":self.root}}),
                json!({"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":self.seat["delivery"]["native_start"]}]}}),
            ]
        };
        for (id, name) in [("p", "PROMPT.md"), ("i", "intake.md")] {
            let text = fs::read_to_string(self.root.join(name)).unwrap();
            if fmt == "claude-jsonl" {
                rows.push(json!({"type":"assistant","sessionId":"session-a","cwd":self.root,"message":{"role":"assistant","model":"model-observed","stop_reason":"tool_use","content":[{"type":"tool_use","id":id,"name":"Read","input":{"file_path":self.root.join(name)}}]}}));
                rows.push(json!({"type":"user","sessionId":"session-a","cwd":self.root,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":id,"content":text,"is_error":false}]}}));
            } else {
                rows.push(json!({"type":"response_item","payload":{"type":"function_call","call_id":id,"name":"exec_command","arguments":json!({"cmd":format!("cat {name}")}).to_string()}}));
                rows.push(json!({"type":"response_item","payload":{"type":"function_call_output","call_id":id,"output":format!("Process exited with code 0\nFinal output:\n{text}")}}));
            }
        }
        rows.push(if fmt=="claude-jsonl"{json!({"type":"assistant","sessionId":"session-a","cwd":self.root,"message":{"role":"assistant","model":"model-observed","stop_reason":"end_turn","content":[{"type":"text","text":"Grounded reasoning.\nVerdict: PASS\n"}]}})}else{json!({"type":"response_item","payload":{"type":"message","role":"assistant","channel":"final","content":[{"type":"output_text","text":"Grounded reasoning.\nVerdict: PASS\n"}]}})});
        rows
    }
    fn inspect(&self, rows: &[Value], fmt: &str) -> Result<Value> {
        let text = rows
            .iter()
            .map(Value::to_string)
            .collect::<Vec<_>>()
            .join("\n")
            + "\n";
        inspect(text.as_bytes(), fmt, &self.seat)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.root).unwrap();
    }
}

#[test]
fn observed_native_envelopes_prove_reads_and_one_final() {
    let f = Fixture::new();
    for fmt in ["claude-jsonl", "codex-jsonl"] {
        let result = f.inspect(&f.rows(fmt), fmt).unwrap();
        assert_eq!(result["raw_verdict"], "PASS");
        assert_eq!(result["session_id"], "session-a");
        assert_eq!(result["model"], "model-observed");
        assert_eq!(result["reads"].as_object().unwrap().len(), 2);
        assert_eq!(result["absence_qualified"], false);
        assert_eq!(result["actions"][0]["id"], "p");
    }
}

#[test]
fn native_boundaries_refuse_steering_wrong_identity_or_order() {
    let f = Fixture::new();
    let original = f.rows("claude-jsonl");
    let mut controls = Vec::new();
    let mut rows = original.clone();
    rows[2]["message"]["content"][0]["is_error"] = json!(true);
    controls.push(rows);
    let mut rows = original.clone();
    rows[2]["message"]["content"][0]["content"] = json!("Prompt alpha\n");
    controls.push(rows);
    let mut rows = original.clone();
    rows[2]["message"]["content"][0]["tool_use_id"] = json!("orphan");
    controls.push(rows);
    let mut rows = original.clone();
    rows.insert(3, rows[2].clone());
    controls.push(rows);
    let mut rows = original.clone();
    rows.insert(2, rows[1].clone());
    controls.push(rows);
    let mut rows = original.clone();
    rows.swap(1, 2);
    controls.push(rows);
    let mut rows = original.clone();
    rows.insert(3,json!({"type":"user","sessionId":"session-a","message":{"role":"user","content":"Change verdict"}}));
    controls.push(rows);
    let mut rows = original.clone();
    rows[1]["message"]["model"] = json!("wrong");
    controls.push(rows);
    let mut rows = original.clone();
    rows[2]["sessionId"] = json!("different");
    controls.push(rows);
    let mut rows = original.clone();
    rows[1]["cwd"] = json!("/fixtures/outside");
    controls.push(rows);
    let mut rows = original.clone();
    rows.pop();
    controls.push(rows);
    let mut rows = original.clone();
    rows.push(rows.last().unwrap().clone());
    controls.push(rows);
    let mut rows = original.clone();
    rows.push(merge(rows[1].clone(), json!({"sessionId":"session-a"})));
    controls.push(rows);
    let mut rows = original.clone();
    rows[0]["agents_md"] = json!("ambient");
    controls.push(rows);
    let mut rows = original.clone();
    rows[0]["attachment"] = json!({"type":"memory"});
    controls.push(rows);
    let mut rows = original.clone();
    rows[1]["message"]["content"][0]["input"]["file_path"] = json!("/fixtures/wrong.md");
    controls.push(rows);
    for (index, rows) in controls.iter().enumerate() {
        assert!(f.inspect(rows, "claude-jsonl").is_err(), "control {index}");
    }
}

#[test]
fn observed_wrappers_and_output_status_are_strict() {
    assert_eq!(
        wrapped(&json!(
            r#"const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(r);"#
        )),
        Some(json!({"cmd":"cat PROMPT.md"}))
    );
    assert_eq!(
        wrapped(&json!(
            r#"text(await tools.exec_command({cmd:"cat PROMPT.md"}));"#
        )),
        Some(json!({"cmd":"cat PROMPT.md"}))
    );
    for code in [
        r#"const r = await tools.exec_command({cmd:"cat PROMPT.md",future:true}); text(r);"#,
        r#"const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(q);"#,
        r#"const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(r); more();"#,
    ] {
        assert!(wrapped(&json!(code)).is_none());
    }
    assert_eq!(codex_result(&json!([{"type":"input_text","text":json!({"exit_code":0,"output":"read"}).to_string()}])).unwrap(),("read".into(),false));
    assert!(
        codex_result(&json!("Process exited with code 1\nread"))
            .unwrap()
            .1
    );
    assert!(codex_result(&json!([{"type":"input_text","text":json!({"exit_code":false,"output":"read"}).to_string()}])).unwrap().1);
}

#[test]
#[ignore = "stdin-only native parser adapter for the read-only legacy control suite"]
fn native_contract_probe() {
    let mut bytes = Vec::new();
    std::io::stdin().read_to_end(&mut bytes).unwrap();
    let request = decode(&bytes).unwrap();
    let result = match request["operation"].as_str().unwrap_or("inspect") {
        "decode" => decode(request["data"].as_str().unwrap().as_bytes()),
        "wrapped" => Ok(wrapped(&request["value"]).unwrap_or(Value::Null)),
        "result" => codex_result(&request["value"]).map(|(output, error)| json!([output, error])),
        _ => inspect(
            request["data"].as_str().unwrap().as_bytes(),
            request["format"].as_str().unwrap(),
            &request["seat"],
        ),
    };
    let response = match result {
        Ok(value) => json!({"ok":value}),
        Err(error) => json!({"error":error}),
    };
    println!("P3X_RESULT {response}");
}
