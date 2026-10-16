use crate::panel_io::*;
use regex::Regex;
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;

const SUPPORTED: &[&str] = &[
    "$ref",
    "$defs",
    "$id",
    "$schema",
    "type",
    "enum",
    "const",
    "required",
    "properties",
    "additionalProperties",
    "items",
    "minItems",
    "maxItems",
    "uniqueItems",
    "minLength",
    "minimum",
    "pattern",
    "oneOf",
    "allOf",
    "anyOf",
    "if",
    "then",
    "else",
    "not",
    "title",
    "description",
];
pub(crate) fn list(v: &Value) -> &[Value] {
    v.as_array().map(Vec::as_slice).unwrap_or(&[])
}
fn names(v: &Value) -> BTreeSet<String> {
    list(v)
        .iter()
        .filter_map(Value::as_str)
        .map(str::to_owned)
        .collect()
}
fn props(v: &Value) -> impl Iterator<Item = (&String, &Value)> {
    v.as_object().into_iter().flatten()
}
fn node_id(v: &Value) -> usize {
    v as *const Value as usize
}
fn inert(v: &Value) -> bool {
    v == &json!(true)
        || v.as_object().is_some_and(|o| {
            o.keys().all(|k| {
                ["$defs", "$id", "$schema", "title", "description"].contains(&k.as_str())
                    || k.starts_with("x-")
            })
        })
}
fn type_ok(v: &Value, kind: &str) -> Result<bool> {
    Ok(match kind {
        "object" => v.is_object(),
        "array" => v.is_array(),
        "string" => v.is_string(),
        "integer" => v.as_f64().is_some_and(|n| n.fract() == 0.),
        "number" => v.is_number(),
        "boolean" => v.is_boolean(),
        "null" => v.is_null(),
        _ => return Err("unknown schema type".into()),
    })
}
pub(crate) fn equal(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Number(a), Value::Number(b)) => {
            let integer = |n: &serde_json::Number| {
                n.as_i64()
                    .map(i128::from)
                    .or_else(|| n.as_u64().map(i128::from))
            };
            match (integer(a), integer(b)) {
                (Some(a), Some(b)) => a == b,
                (Some(a), None) => b
                    .as_f64()
                    .is_some_and(|b| b.fract() == 0. && b as i128 == a),
                (None, Some(b)) => a
                    .as_f64()
                    .is_some_and(|a| a.fract() == 0. && a as i128 == b),
                _ => a.as_f64() == b.as_f64(),
            }
        }
        (Value::Array(a), Value::Array(b)) => {
            a.len() == b.len() && a.iter().zip(b).all(|(a, b)| equal(a, b))
        }
        (Value::Object(a), Value::Object(b)) => {
            a.len() == b.len() && a.iter().all(|(k, a)| b.get(k).is_some_and(|b| equal(a, b)))
        }
        _ => a == b,
    }
}
fn resolve<'a>(reference: &Value, root: &'a Value) -> Result<&'a Value> {
    let reference = reference
        .as_str()
        .filter(|s| s.starts_with("#/"))
        .ok_or("unsupported non-local schema reference")?;
    root.pointer(&reference[1..])
        .ok_or_else(|| format!("unresolvable schema reference: {reference}"))
}
fn pattern(raw: &str) -> Result<Regex> {
    static CACHE: std::sync::OnceLock<std::sync::Mutex<BTreeMap<String, Regex>>> =
        std::sync::OnceLock::new();
    let cache = CACHE.get_or_init(|| std::sync::Mutex::new(BTreeMap::new()));
    if let Some(compiled) = cache
        .lock()
        .map_err(|_| "pattern cache unavailable")?
        .get(raw)
        .cloned()
    {
        return Ok(compiled);
    }
    let space = r"\t\x0b\x0c \u{00a0}\u{1680}\u{2000}-\u{200a}\u{202f}\u{205f}\u{3000}\u{feff}\n\r\u{2028}\u{2029}";
    let mut converted = String::new();
    let mut chars = raw.chars();
    let mut class = false;
    while let Some(c) = chars.next() {
        if c == '\\' {
            let next = chars.next().ok_or("incomplete schema pattern escape")?;
            match next {
                'S' if !class => converted.push_str(&format!("[^{space}]")),
                's' => {
                    if class {
                        converted.push_str(space)
                    } else {
                        converted.push_str(&format!("[{space}]"))
                    }
                }
                'd' => converted.push_str(if class { "0-9" } else { "[0-9]" }),
                'w' => converted.push_str(if class { "a-zA-Z0-9_" } else { "[a-zA-Z0-9_]" }),
                _ => {
                    converted.push('\\');
                    converted.push(next);
                }
            }
        } else {
            if c == '[' {
                class = true;
            } else if c == ']' {
                class = false;
            }
            if c == '.' && !class {
                converted.push_str("[^\\n\\r\\u{2028}\\u{2029}]");
            } else {
                converted.push(c);
            }
        }
    }
    let compiled = Regex::new(&converted)
        .map_err(|e| format!("unsupported or invalid schema pattern: {e}"))?;
    let mut cache = cache.lock().map_err(|_| "pattern cache unavailable")?;
    if cache.len() >= 512 {
        cache.clear();
    }
    cache.insert(raw.into(), compiled.clone());
    Ok(compiled)
}
pub(crate) fn validate(v: &Value, schema: &Value, root: &Value) -> Result<Vec<String>> {
    let mut errors = Vec::new();
    evaluate(v, schema, root, "$", 0, &mut errors)?;
    Ok(errors)
}
fn valid(v: &Value, schema: &Value, root: &Value, path: &str, depth: usize) -> Result<bool> {
    let mut errors = Vec::new();
    evaluate(v, schema, root, path, depth, &mut errors)?;
    Ok(errors.is_empty())
}
fn evaluate(
    v: &Value,
    schema: &Value,
    root: &Value,
    path: &str,
    depth: usize,
    errors: &mut Vec<String>,
) -> Result<()> {
    check(depth <= 120, "schema instance recursion limit")?;
    if let Some(value) = schema.as_bool() {
        if !value {
            errors.push(format!("{path}: false schema"));
        }
        return Ok(());
    }
    let object = schema.as_object().ok_or("schema node is not an object")?;
    check(
        object
            .keys()
            .all(|k| SUPPORTED.contains(&k.as_str()) || k.starts_with("x-")),
        "unsupported schema keyword",
    )?;
    if let Some(reference) = object.get("$ref") {
        evaluate(v, resolve(reference, root)?, root, path, depth + 1, errors)?;
    }
    if let Some(kinds) = object.get("type") {
        let kinds = if kinds.is_string() {
            vec![kinds.clone()]
        } else {
            list(kinds).to_vec()
        };
        let mut matches = false;
        for kind in kinds {
            matches |= type_ok(v, kind.as_str().ok_or("schema type is not a name")?)?;
        }
        if !matches {
            errors.push(format!("{path}: type mismatch"));
            return Ok(());
        }
    }
    if object.get("const").is_some_and(|c| !equal(c, v)) {
        errors.push(format!("{path}: const mismatch"));
    }
    if object
        .get("enum")
        .is_some_and(|a| !list(a).iter().any(|c| equal(c, v)))
    {
        errors.push(format!("{path}: enum mismatch"));
    }
    if let Some(text) = v.as_str() {
        if schema["minLength"]
            .as_u64()
            .is_some_and(|n| text.chars().count() < n as usize)
        {
            errors.push(format!("{path}: minLength"));
        }
        if let Some(raw) = schema["pattern"].as_str() {
            if !pattern(raw)?.is_match(text) {
                errors.push(format!("{path}: pattern mismatch"));
            }
        }
    }
    if let (Some(n), Some(min)) = (v.as_f64(), schema["minimum"].as_f64()) {
        if n < min {
            errors.push(format!("{path}: minimum"));
        }
    }
    if let Some(values) = v.as_array() {
        if schema["minItems"]
            .as_u64()
            .is_some_and(|n| values.len() < n as usize)
        {
            errors.push(format!("{path}: minItems"));
        }
        if schema["maxItems"]
            .as_u64()
            .is_some_and(|n| values.len() > n as usize)
        {
            errors.push(format!("{path}: maxItems"));
        }
        if schema["uniqueItems"] == true
            && values
                .iter()
                .enumerate()
                .any(|(i, x)| values[..i].iter().any(|y| equal(x, y)))
        {
            errors.push(format!("{path}: duplicate items"));
        }
        if let Some(items) = object.get("items") {
            for (i, x) in values.iter().enumerate() {
                evaluate(x, items, root, &format!("{path}[{i}]"), depth + 1, errors)?;
            }
        }
    }
    if let Some(values) = v.as_object() {
        for key in names(&schema["required"]) {
            if !values.contains_key(&key) {
                errors.push(format!("{path}: missing field {key}"));
            }
        }
        for (key, sub) in props(&schema["properties"]) {
            if let Some(x) = values.get(key) {
                evaluate(x, sub, root, &format!("{path}.{key}"), depth + 1, errors)?;
            }
        }
        for (key, x) in values {
            if schema["properties"].get(key).is_none() {
                if schema["additionalProperties"] == false {
                    errors.push(format!("{path}: additional property {key}"));
                } else if schema["additionalProperties"].is_object() {
                    evaluate(
                        x,
                        &schema["additionalProperties"],
                        root,
                        &format!("{path}.{key}"),
                        depth + 1,
                        errors,
                    )?;
                }
            }
        }
    }
    if let Some(sub) = object.get("not") {
        if valid(v, sub, root, path, depth + 1)? {
            errors.push(format!("{path}: prohibited match"));
        }
    }
    for sub in list(&schema["allOf"]) {
        evaluate(v, sub, root, path, depth + 1, errors)?;
    }
    for key in ["anyOf", "oneOf"] {
        if let Some(alts) = object.get(key) {
            let mut count = 0;
            for sub in list(alts) {
                if valid(v, sub, root, path, depth + 1)? {
                    count += 1;
                }
            }
            if (key == "anyOf" && count == 0) || (key == "oneOf" && count != 1) {
                errors.push(format!("{path}: {key} branch count {count}"));
            }
        }
    }
    if let Some(condition) = object.get("if") {
        let arm = if valid(v, condition, root, path, depth + 1)? {
            "then"
        } else {
            "else"
        };
        if let Some(sub) = object.get(arm) {
            evaluate(v, sub, root, path, depth + 1, errors)?;
        }
    }
    Ok(())
}
fn preflight(
    node: &Value,
    root: &Value,
    refs: &HashSet<usize>,
    seen: &mut HashSet<(usize, Vec<usize>)>,
    depth: usize,
) -> Result<()> {
    check(depth <= 120, "schema preflight depth limit")?;
    if node.is_boolean() {
        return Ok(());
    }
    let object = node
        .as_object()
        .ok_or("schema position must be object or boolean")?;
    let mut ancestry: Vec<_> = refs.iter().copied().collect();
    ancestry.sort();
    if !seen.insert((node_id(node), ancestry)) {
        return Ok(());
    }
    check(
        object
            .keys()
            .all(|k| SUPPORTED.contains(&k.as_str()) || k.starts_with("x-")),
        "unsupported schema keyword",
    )?;
    for key in ["properties", "$defs"] {
        if let Some(v) = object.get(key) {
            check(v.is_object(), "schema map keyword shape")?;
        }
    }
    for key in ["required", "enum", "allOf", "anyOf", "oneOf"] {
        if let Some(v) = object.get(key) {
            check(v.is_array(), "schema array keyword shape")?;
        }
    }
    for key in ["pattern", "$ref"] {
        if let Some(v) = object.get(key) {
            check(v.is_string(), "schema text keyword shape")?;
        }
    }
    for key in ["minLength", "minItems", "maxItems"] {
        if let Some(v) = object.get(key) {
            check(
                v.as_u64().is_some(),
                "schema nonnegative integer keyword shape",
            )?;
        }
    }
    if let Some(v) = object.get("minimum") {
        check(v.is_number(), "schema numeric minimum shape")?;
    }
    if let Some(v) = object.get("uniqueItems") {
        check(v.is_boolean(), "schema uniqueness shape")?;
    }
    check(
        list(&node["required"]).iter().all(Value::is_string),
        "schema required names",
    )?;
    if let Some(v) = object.get("type") {
        let kinds = if v.is_string() {
            vec![v]
        } else {
            check(v.is_array(), "schema type shape")?;
            list(v).iter().collect()
        };
        check(!kinds.is_empty(), "empty schema type")?;
        let mut seen = HashSet::new();
        for kind in kinds {
            let name = kind.as_str().ok_or("schema type name")?;
            type_ok(&Value::Null, name)?;
            check(seen.insert(name), "duplicate schema type")?;
        }
    }
    if let Some(v) = node["pattern"].as_str() {
        pattern(v)?;
    }
    let mut here = refs.clone();
    here.insert(node_id(node));
    if let Some(r) = object.get("$ref") {
        let target = resolve(r, root)?;
        check(!here.contains(&node_id(target)), "cyclic schema reference")?;
        preflight(target, root, &here, seen, depth + 1)?;
    }
    for key in ["properties", "$defs"] {
        for (_, sub) in props(&node[key]) {
            preflight(sub, root, &HashSet::new(), seen, depth + 1)?;
        }
    }
    let empty_refs = HashSet::new();
    for key in ["if", "then", "else", "not", "items", "additionalProperties"] {
        if let Some(sub) = object.get(key) {
            preflight(
                sub,
                root,
                if ["if", "then", "else", "not"].contains(&key) {
                    &here
                } else {
                    &empty_refs
                },
                seen,
                depth + 1,
            )?;
        }
    }
    for key in ["allOf", "anyOf", "oneOf"] {
        if let Some(sub) = object.get(key) {
            check(!list(sub).is_empty(), "empty schema combinator")?;
            for sub in list(sub) {
                preflight(sub, root, &here, seen, depth + 1)?;
            }
        }
    }
    Ok(())
}
fn condition(node: &Value) -> Result<()> {
    let Some(cond) = node.get("if") else {
        return Ok(());
    };
    let cond = cond
        .as_object()
        .ok_or("derivation condition must be an object")?;
    check(
        cond.keys()
            .all(|k| ["properties", "required", "title", "description"].contains(&k.as_str())),
        "unreadable derivation condition",
    )?;
    for (name, spec) in props(cond.get("properties").unwrap_or(&Value::Null)) {
        let spec = spec
            .as_object()
            .ok_or("unreadable derivation property condition")?;
        check(
            spec.keys()
                .all(|k| ["const", "enum", "title", "description"].contains(&k.as_str()))
                && !(spec.contains_key("const") && spec.contains_key("enum")),
            "unreadable condition constraint",
        )?;
        check(
            names(cond.get("required").unwrap_or(&Value::Null)).contains(name),
            "optional derivation condition discriminator",
        )?;
    }
    Ok(())
}
fn carries(
    node: &Value,
    root: &Value,
    visible: &BTreeSet<String>,
    refs: &mut HashSet<usize>,
    negation: usize,
    conditional: bool,
) -> Result<bool> {
    if !node.is_object() || !refs.insert(node_id(node)) {
        return Ok(false);
    }
    let required = names(&node["required"]);
    let mut result = if negation == 0 {
        !required.is_empty()
    } else {
        (negation.is_multiple_of(2) || conditional) && !required.is_subset(visible)
    };
    if let Some(r) = node.get("$ref") {
        result |= carries(
            resolve(r, root)?,
            root,
            visible,
            refs,
            negation,
            conditional,
        )?;
    }
    if let Some(sub) = node.get("not") {
        result |= carries(sub, root, visible, refs, negation + 1, conditional)?;
    }
    for key in ["if", "then", "else"] {
        if let Some(sub) = node.get(key) {
            result |= carries(
                sub,
                root,
                visible,
                refs,
                negation,
                negation > 0 && key == "if",
            )?;
        }
    }
    for key in ["allOf", "anyOf", "oneOf"] {
        for sub in list(&node[key]) {
            result |= carries(sub, root, visible, refs, negation, conditional)?;
        }
    }
    refs.remove(&node_id(node));
    Ok(result)
}
fn gate(node: &Value, root: &Value, visible: &BTreeSet<String>) -> Result<bool> {
    carries(node, root, visible, &mut HashSet::new(), 0, false)
}
fn normal_walk(
    node: &Value,
    root: &Value,
    visible: &BTreeSet<String>,
    read_any: bool,
) -> Result<()> {
    if let Some(n) = node.get("not") {
        check(
            !carries(n, root, visible, &mut HashSet::new(), 1, false)?,
            "positive root requirement hidden by negation",
        )?;
    }
    for sub in list(&node["oneOf"]) {
        check(!gate(sub, root, visible)?, "hidden oneOf requirement")?;
    }
    if let Some(alts) = node.get("anyOf") {
        check(
            list(alts)
                .iter()
                .any(|a| a == &json!(true) || a.is_object()),
            "unsatisfiable derivation anyOf",
        )?;
        for sub in list(alts) {
            if sub.is_object() && gate(sub, root, visible)? {
                check(read_any, "hidden anyOf requirement")?;
                check(
                    props(sub)
                        .all(|(k, _)| ["required", "title", "description"].contains(&k.as_str())),
                    "value constraint beside derivation alternative",
                )?;
            }
        }
    }
    Ok(())
}
fn emitted(root: &Value, cycle: &str) -> Result<BTreeSet<String>> {
    let mut keys = names(&root["required"]);
    let probe = json!({"cycle_type":cycle,"action":"__UNSET__"});
    for branch in list(&root["allOf"]) {
        let mut selected = branch;
        if let Some(cond) = branch.get("if") {
            check(
                names(&cond["required"])
                    .iter()
                    .all(|n| ["cycle_type", "action", "sequence_evidence"].contains(&n.as_str())),
                "unknown derivation presence discriminator",
            )?;
            let mut holds = names(&cond["required"])
                .iter()
                .all(|n| probe.get(n).is_some());
            for (key, spec) in props(&cond["properties"]) {
                if let Some(v) = spec.get("const") {
                    holds &= probe.get(key) == Some(v);
                } else if let Some(v) = spec.get("enum") {
                    holds &= list(v).contains(&probe[key]);
                } else {
                    return Err("unsupported derivation condition".into());
                }
            }
            selected = &branch[if holds { "then" } else { "else" }];
        }
        keys.extend(names(&selected["required"]));
        let alternatives = list(&selected["anyOf"]);
        for sub in alternatives.iter().filter(|s| s.is_object()) {
            check(
                props(sub).all(|(k, _)| ["required", "title", "description"].contains(&k.as_str())),
                "unreadable derivation anyOf",
            )?;
        }
        if !alternatives.iter().any(|s| s == &json!(true))
            && !alternatives
                .iter()
                .filter(|s| s.is_object())
                .any(|s| names(&s["required"]).is_subset(&keys))
        {
            if let Some(first) = alternatives.iter().find(|s| s.is_object()) {
                keys.extend(names(&first["required"]));
            }
        }
    }
    Ok(keys)
}
fn shape_accepts(node: &Value, keys: &BTreeSet<String>) -> bool {
    if inert(node) {
        return true;
    }
    if !node.is_object()
        || !props(node).all(|(k, _)| {
            [
                "$defs",
                "$id",
                "$schema",
                "title",
                "description",
                "type",
                "properties",
                "required",
                "additionalProperties",
                "allOf",
            ]
            .contains(&k.as_str())
                || k.starts_with("x-")
        })
    {
        return false;
    }
    if let Some(kind) = node.get("type") {
        if kind != "object" && !list(kind).contains(&json!("object")) {
            return false;
        }
    }
    if props(&node["properties"]).any(|(k, s)| keys.contains(k) && !inert(s))
        || !names(&node["required"]).is_subset(keys)
    {
        return false;
    }
    if keys.iter().any(|k| node["properties"].get(k).is_none())
        && node.get("additionalProperties").is_some_and(|s| !inert(s))
    {
        return false;
    }
    list(&node["allOf"]).iter().all(|s| shape_accepts(s, keys))
}
fn root_combinators(
    node: &Value,
    root: &Value,
    keys: &BTreeSet<String>,
    cycle: &str,
    seen: &mut HashSet<usize>,
) -> Result<()> {
    if !node.is_object() || !seen.insert(node_id(node)) {
        return Ok(());
    }
    condition(node)?;
    if let Some(alts) = node.get("oneOf") {
        check(
            list(alts).iter().all(|s| s == &json!(false) || inert(s))
                && list(alts).iter().filter(|s| inert(s)).count() == 1,
            "nonneutral root oneOf",
        )?;
    }
    if let Some(alts) = node.get("anyOf") {
        let readable = list(alts).iter().all(|s| {
            s == &json!(false)
                || s.as_object().is_some_and(|o| {
                    o.keys()
                        .all(|k| ["required", "title", "description"].contains(&k.as_str()))
                })
        });
        let safe = list(alts).iter().any(inert)
            || readable
            || list(alts)
                .iter()
                .any(|s| s.is_object() && shape_accepts(s, keys));
        check(safe, "unsafe root anyOf")?;
    }
    if let Some(r) = node.get("$ref") {
        root_combinators(resolve(r, root)?, root, keys, cycle, seen)?;
    }
    for sub in list(&node["allOf"]) {
        root_combinators(sub, root, keys, cycle, seen)?;
    }
    if let Some(cond) = node.get("if") {
        let mut truth = Some(true);
        for k in names(&cond["required"]) {
            if !keys.contains(&k) {
                truth = Some(false);
            }
        }
        if truth != Some(false) {
            for (k, spec) in props(&cond["properties"]) {
                if !keys.contains(k) {
                    continue;
                }
                let known = match k.as_str() {
                    "cycle_type" => Some(cycle),
                    "action" => Some("__UNSET__"),
                    _ => None,
                };
                if spec.get("const").is_some() || spec.get("enum").is_some() {
                    if let Some(known) = known {
                        if spec.get("const").is_some_and(|v| v != known)
                            || spec
                                .get("enum")
                                .is_some_and(|v| !list(v).contains(&json!(known)))
                        {
                            truth = Some(false);
                            break;
                        }
                    } else {
                        truth = None;
                    }
                }
            }
        }
        if truth != Some(false) {
            root_combinators(&node["then"], root, keys, cycle, seen)?;
        }
        if truth != Some(true) {
            root_combinators(&node["else"], root, keys, cycle, seen)?;
        }
    }
    Ok(())
}
fn normal_form(root: &Value) -> Result<()> {
    let mut visible = names(&root["required"]);
    for branch in list(&root["allOf"]) {
        visible.extend(names(&branch["if"]["required"]));
        visible.extend(props(&branch["if"]["properties"]).map(|(k, _)| k.clone()));
    }
    condition(root)?;
    normal_walk(root, root, &visible, false)?;
    if let Some(r) = root.get("$ref") {
        check(
            !gate(resolve(r, root)?, root, &visible)?,
            "root reference hides requirements",
        )?;
    }
    if root.get("if").is_some() {
        for arm in ["then", "else"] {
            check(
                !gate(&root[arm], root, &visible)?,
                "root conditional hides requirements",
            )?;
        }
    }
    for branch in list(&root["allOf"]) {
        if !branch.is_object() {
            continue;
        }
        condition(branch)?;
        normal_walk(branch, root, &visible, true)?;
        if branch.get("$ref").is_some() {
            check(
                !gate(branch, root, &visible)?,
                "branch reference hides requirements",
            )?;
        }
        if branch.get("if").is_some() {
            check(
                list(&branch["required"]).is_empty() && list(&branch["anyOf"]).is_empty(),
                "unconditional requirements beside condition",
            )?;
        } else {
            check(
                branch.get("then").is_none() && branch.get("else").is_none(),
                "inert derivation arm",
            )?;
        }
        for sub in std::iter::once(branch).chain([&branch["then"], &branch["else"]]) {
            normal_walk(sub, root, &visible, true)?;
            for nested in list(&sub["allOf"]) {
                check(
                    !gate(nested, root, &visible)?,
                    "nested allOf hides requirements",
                )?;
            }
            if !std::ptr::eq(sub, branch) {
                if sub.get("$ref").is_some() {
                    check(
                        !gate(sub, root, &visible)?,
                        "arm reference hides requirements",
                    )?;
                }
                if sub.get("if").is_some() {
                    for arm in ["then", "else"] {
                        check(
                            !gate(&sub[arm], root, &visible)?,
                            "nested conditional hides requirements",
                        )?;
                    }
                }
            }
        }
    }
    let declared: BTreeSet<_> = props(&root["properties"]).map(|(k, _)| k.clone()).collect();
    let mut required = names(&root["required"]);
    for branch in list(&root["allOf"]) {
        for sub in std::iter::once(branch).chain(if branch.get("if").is_some() {
            vec![&branch["then"], &branch["else"]]
        } else {
            vec![]
        }) {
            required.extend(names(&sub["required"]));
            for alt in list(&sub["anyOf"]) {
                required.extend(names(&alt["required"]));
            }
        }
    }
    check(
        required.is_subset(&declared),
        "required root property undeclared",
    )?;
    for cycle in ["research", "implementation"] {
        let mut keys = emitted(root, cycle)?;
        check(
            keys.is_subset(&declared),
            "emitted root property undeclared",
        )?;
        for key in ["cycle_type", "action"] {
            if visible.contains(key) {
                keys.insert(key.into());
            }
        }
        root_combinators(root, root, &keys, cycle, &mut HashSet::new())?;
    }
    Ok(())
}
pub(crate) fn load(root: &Path) -> Result<Value> {
    let path = root.join("reviews/schema/resolve-ledger.schema.json");
    let before = io(fs::symlink_metadata(&path))?;
    check(before.nlink() == 1, "schema must be single-link")?;
    let schema = decode(&path_bytes(&path)?)?;
    let after = io(fs::symlink_metadata(path))?;
    check(
        after.nlink() == 1 && (before.dev(), before.ino()) == (after.dev(), after.ino()),
        "schema identity changed",
    )?;
    preflight(&schema, &schema, &HashSet::new(), &mut HashSet::new(), 0)?;
    normal_form(&schema)?;
    Ok(schema)
}

#[cfg(test)]
#[path = "../tests/support/panel_schema.rs"]
mod tests;
