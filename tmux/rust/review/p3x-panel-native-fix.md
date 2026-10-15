# #p3x native panel fix: NO-GO / Divergence at F10

F11-F13 update: `p3x-panel-readiness.md` proves and fixes the readiness failure and records a successful fresh full Codex cycle through the public sender. The F10 snapshot below is historical for launch/readiness; its validator parity limits remain unchanged and outside the F11-F13 scope.

**NO-GO.** The native replacements are implemented, but the required real Codex cycle has not passed. F9 reaches its readiness deadline before Start. At F10 the task brief explicitly requires stopping and sending a Divergence report. This report supersedes the withdrawn GO in `p3x-panel-live.md` and the earlier exhausted-budget report in `p3x-panel-fix-divergence.md`. Angel authorized a separate F1-F10 budget in `~/desk/tmp/relay/port/panel-fix.md`; it has now been used.

The interpreter configuration table is deleted. Protocol validation is native Rust in `panel_protocol.rs` and `panel_schema.rs`; seat launch is native Rust in `panel_launch.rs`. There is no interpreter process, inline executable code argument, login-shell wrapper, or runtime import of owner implementation files. The selected project/schema bytes remain data authority; the native binary's digest identifies the implementation. Both original tool aliases still point to the same multicall binary. Nothing is deployed.

## Source and fixture provenance

Read-only source hashes are in `~/desk/tmp/relay/port/panel-evidence/fix/sources.sha256`, rechecked unchanged during F8.

| Source | SHA256 |
| --- | --- |
| `~/.skills/review-protocol/agentic_consumers.py` | `28dd85c109f48319dd474cc16e069998e3c511394bef96401979dbcf2b584da5` |
| `~/.skills/review-protocol/ledger_schema.py` | `8f68eabf5b12d950ad105bde8de9bd46b131040a030155c1758d9fc24bdb51ac` |
| Owner's `reviews/schema/resolve-ledger.schema.json` | `48f42b0f1895fe3c3d06550e22a64ef2d0195998afdb1f3c43252ff6326622fb` |
| `~/.config/fish/internal/tmux/tai.fish` | `e5e2cfdabd62f4b3cac879deeb0fb7500d11438299f06f985a2a3952b969962c` |
| `~/.config/fish/internal/claude/_agent_limit.fish` | `f7946f6ea4d4a440d31d1ce95d19895960681b7ae3a48aff2822cb80c5952ffb` |
| `~/.config/fish/internal/claude/deepseek.fish` | `0974d8b25f6e0c6b78998837127d258eb8f5bace51762f2e7673b71aff4f4125` |

The original dispatcher/helper hashes and live caller inventory are retained in the historical report and `~/desk/tmp/relay/port/panel-caller-files.txt`; no caller was changed. Dispatcher phases and documented routing prefixes remain the live contract. The external-owner APIs actually called were `_load_ledger_schema`, `_js_validate`, `resolve_agentic_context`, `validate_agentic_evidence`, and `agentic_pass_sources`. Only their reachable checks for this dispatcher were ported; no ledger CLI, skeleton generator, sequence admission engine, historical-ledger discovery or protocol command suite was added.

Fast-test fixtures in `tests/fixtures/` include the owner's unmodified real schema and a real collected Codex seat, final and intake from `panel-evidence/corrected/plain-1792087248231923000/interactive-batch/collected.json`, `a-final.md`, and that run's `round-4/project/.../audit-r4.md`. The collected seat's path fields were normalized to `/fixtures/collected/<basename>`; digests and session metadata were retained. Tests rebind actual bytes into fresh owned graphs. `panel-codex-idle.ansi` comes from the F6 real idle Codex capture, with its private seat cwd normalized to `/fixtures/seat` and empty trailing screen rows removed. These are explicitly test artifacts, not production admission claims.

## Validator check-to-source and fast-case map

`A` below means the pinned `agentic_consumers.py`; `L` means the pinned `ledger_schema.py`. Test names are in `tests/support/panel_protocol.rs` unless prefixed `schema:` or `launch:`. Parameter loops exercise each listed field/guard individually, with a valid graph as their positive control.

| Ported check | Exact source lines | Fast case(s) |
| --- | --- | --- |
| Closed absolute reference and lowercase 64-character hash | A:43-47 | `missing_dispatch_and_hash`, `reader_refuses_symlinks_and_noncanonical_components` |
| Canonical components, directory descriptors/no-follow, regular file, pre/open/late identity | A:100-152,178-188 | `reader_refuses_symlinks_and_noncanonical_components`, `schema_is_single_link_and_no_follow`, existing evidence controls |
| External dispatch must be outside the actual project directory and single-link | A:118-151,245-249 | `external_dispatch_location_and_single_link` |
| 2,048 unique files, repeated-byte charging, 256 KiB JSON / 64 MiB stream / 512 MiB total | A:105-107,152-173 | `reader_json_unique_file_and_repeated_byte_budgets`, `stream_file_budget_refuses_oversized_regular_evidence` |
| Exact durable hash, strict UTF-8/object JSON, duplicate/nonfinite/depth refusal | A:54-84,159-177,191-202 | `reader_duplicate_depth_nonfinite_and_object_limits`, `native_final_bytes_and_same_inode_roles` |
| Operation slug, cycle kind, nonblank cycle, positive integer round | A:236-240 | `operation_slug_cycle_and_integer_round` |
| Required independently expected dispatch path/hash, closed fields and exact operation | A:241-253 | `missing_dispatch_and_hash`, `closed_dispatch_fields`, `ledger_operation` |
| Four pending publication markers, canonical intake path | A:254-263 | `pending_publication_all_four_markers`, `actual_intake_digest_binding` |
| Compiler sidecar PASS/digest/integer byte count/output | A:264-269 | `compiler_sidecar_status_digest_size_and_output` |
| Closed packet, actual canonical and manifest references, durable delivered/prompt bytes | A:270-281 | `actual_intake_digest_binding`, `delivered_and_prompt_durable_hashes`, `ledger_packet` |
| Independently supplied sequence context and every dependent report's context | A:275-278,379-380 | `sequence_context_is_required_on_every_dependent_report` |
| Selected schema is present, single-link, no-follow, strict JSON and late identity checked | L:1266-1310 | `schema_is_single_link_and_no_follow`, `schema:actual_schema_preflight_and_normal_form` |
| Full schema graph preflight, keyword names/value shapes, all patterns, local refs, cycles/depth | L:1051-1264 | `schema:preflight_checks_untaken_branches_and_keyword_shapes`, `schema:preflight_refuses_same_scope_reference_cycles` |
| Boolean schema, JSON type/number equality, const, enum | L:74-110,891-950 | `schema:schema_truth_numbers_and_boolean_equality`, `schema:schema_does_not_round_distinct_large_integer_constants` |
| String length, recorded ECMA whitespace/anchors/patterns, numeric minimum | L:849-861,952-963 | `schema:references_hash_absolute_path_and_required_binding`, `schema:canonical_nonblank_pattern_uses_ecma_whitespace` |
| Array min/max/uniqueness/items; required fields, properties and closure | L:965-1000 | `schema:all_seat_required_fields_are_checked`, `schema:closed_seat_and_attempts_refuse_unknown_fields`, `schema:scalar_types_enums_lengths_and_attempt_limit`, `schema:schema_truth_numbers_and_boolean_equality` |
| Ref siblings, not/allOf/anyOf/oneOf/if/then/else | L:919-926,1002-1030 | `schema:schema_truth_numbers_and_boolean_equality`, `schema:supersession_and_native_reference_conditions`, `schema:qualified_activation_requires_both_independent_proofs` |
| Root requirement normal form, evaluable discriminators, declared required keys | L:1411-1622,1624-2033,2400-2507 | `schema:actual_schema_preflight_and_normal_form`, `schema:normal_form_refuses_hidden_requirements_and_undeclared_names` |
| Closed independent dispatch panel schema | A:282-291 | Real artifact acceptance and all schema cases above |
| Projection binds actual canonical/delivered bytes and both exclusion/fidelity passes | A:296-302 | `projection_context_exclusion_and_fidelity` |
| Adapter identity/hash, launcher version/config identity | A:303-313 | `launcher_version_and_adapter_binding`, `attempt_launcher_binding`, `ledger_adapter` |
| Prospective policy authorization | A:314-317 | `prospective_policy_authorization` |
| Resolve operation authorization, unique applicable lead identity, bounded valid report refs | A:318-328 | `resolve_operation_needs_authorization_lead_identity_and_bounded_report_references` |
| Re-read durable dispatch, never cache proof success | A:329,461-467,583-586,757-761 | `native_final_bytes_and_same_inode_roles`, whole verifier controls; every verifier repeats resolution/evidence |
| Expected report must be independently authorized; report cannot supply expected authority | A:342-353,375-376,398-408 | `report_self_expected_authority_is_refused`, retained reproduction cases |
| Bound report operation, seat/attempt/session and current-vs-retained selection | A:354-384 | `reports_bind_seat_attempt_and_native_session`, `current_dependencies_refuse_noncurrent_pointers_but_retention_can_read_them` |
| Re-read resolve authority and bind reproduced lead producer/session | A:385-391 | `classified_retained_reproduction_needs_authorized_lead_producer_and_bound_final` |
| Record-only optional proofs; qualified mode, boundary, authorized compatible adapter proofs | A:411-433 | `qualified_authorization_and_adapter_proofs`, `ledger_activation` |
| Closed version-1 ledger contract, operation, original authority, packet/adapter/policy identity | A:439-481 | `closed_contract`, `contract_version`, `ledger_operation`, `ledger_authority`, `ledger_packet`, `ledger_adapter`, `ledger_redispatch_policy` |
| Exact independently retained roster, bounded attempts and launcher | A:487-499 | `retained_attempt_binding`, `attempt_launcher_binding`, schema bounds |
| Durable native/final bytes, report identity, admission status/native/final/selected verdict | A:500-519 | `native_final_bytes_and_same_inode_roles`, `reports_bind_seat_attempt_and_native_session`, `admissions_bind_status_native_final_and_verdict` |
| Admitted packet/read evidence and actual reads | A:520-524,681-690 | `admission_and_reads_bind_every_packet_member`, `reads_must_prove_actual_reads` |
| Grounded account, final identity, proved contradiction/qualified absence and exact qualified floor | A:525-531,693-697,743-754 | `qualified_grounded_account_and_material_deficiency`, `positive_contradiction_and_qualified_absence_require_all_proofs` |
| Whole-second real instants and timezone components | A:700-705; L:3054-3063 | `whole_second_ordering_and_valid_timezone_components` |
| Retry budget/causes/exhaustion/prospective authorization; ordered committed replacement edges; no admitted FAIL retry or predecessor revival | A:708-740 | `retry_policy_precedes_launch_and_supersession_precedes_replacement` |
| Native/final inode ownership across roles and attempts | A:533-545 | `native_final_bytes_and_same_inode_roles` |
| Classified retained findings require authorized reproduction; null requires unclassified status/reason | A:546-566 | `retained_unadmitted_findings_need_explicit_non_reproduction`, `classified_retained_reproduction_needs_authorized_lead_producer_and_bound_final` |
| Exact decision/identity records; fresh close/advance requires convergence | A:567-582 | `decision_authority_binding`, `identity_authority_binding`, `convergence_required`, `convergence_evidence_allows_current_close` |
| Decision kind/id, authorized lead, independent distinct checker/session, bound proof and authorization | A:594-637,652-678 | `all_decision_kinds_require_independent_binding`, `decision_identity_coverage_and_unknowns`, `effective_identity_evidence_and_requested_profiles_are_checked` |
| Shared-domain caller review bindings and all four material accounts | A:638-648 | `shared_domain_caller_review_requires_all_four_material_accounts` |
| Effective identity evidence and explicit unknowns | A:577-582,652-678; L:2119-2134 | `effective_identity_evidence_and_requested_profiles_are_checked`, `decision_identity_coverage_and_unknowns` |
| Recorded accounting: boundary, unique seats/attempts/sessions/files, current selection, admission/response/verdict/floor/causes | L:2109-2229 (called only when `panel` exists, A:483-486) | `response_projection`, `raw_verdict_projection`, `retained_attempt_binding`, qualification and schema controls |
| Dispatched/responded/raw verdict projections and unique verdict row | L:2230-2251 | `dispatch_projection`, `response_projection`, `raw_verdict_projection`, `verdict_row_uniqueness` |
| Retained provenance uniqueness, known owner/final and no admitted-current unadmitted evidence | L:2253-2279 | retained reproduction controls, native verifier `unadmitted-classified` case |
| Mixed-panel raw PASS sources, nonresponse exclusion, recorded vs qualified seat floor | A:757-771 | `real_artifact_record_only_acceptance_and_pass_sources`, `qualified_grounded_account_and_material_deficiency`, retained reproduction acceptance |

Source JSON numeric equality is retained for context comparisons; schema equality distinguishes booleans from numbers and does not round distinct large integer constants. Source-level human-readable diagnostics are not copied verbatim; named dependency/refusal behavior and exit outcomes are the parity contract.

## Seat launch and ownership

| Native step | Read-only source |
| --- | --- |
| Physical seat cwd, four kinds, exact model/effort args and appended isolation | tai:164-214,224-236 |
| Native trust before window creation | tai:216-217; existing `panel-seat-trust` port |
| TMPDIR scratch, provider private temp/CLAUDE variables, Codex private home | tai:182,219-222 |
| Exact named session/window/cwd/env | tai:130-152; original dispatcher:476 replaces the default window with the requested window |
| Codex direct CLI, no-daemon/strict config and named filesystem/network policy | tai:180-185; `_agent_limit codex` deliberately selects the executable rather than the shell function |
| Claude direct CLI, confined tools/settings/safe mode | tai:187-191 |
| DeepSeek pinned Claude, confined args and endpoint/auth/model environment | tai:192-196; deepseek:1-104 |
| Agy CLI flags and native sandbox | tai:174-179; agy wrapper's `_agent_limit` call |
| Disposable-child soft/hard process limit, default/validated cap, fail-open limit calls | `_agent_limit`:33-104 |
| Own/pane registration before CLI starts | dispatcher:375-409,476; native plan/release gate records own before `exec` |

`new-window` receives multiple command arguments, so tmux executes the native bootstrap directly. The bootstrap waits for the bound immutable own/release receipt, validates kind/profile/pane/source and then execs the selected CLI in the same owned process. It reads the DeepSeek key only into that process's environment; no key is written into an execution plan. There is no typed launch line or shell/function sourcing. CLI policy `-c` arguments are Codex configuration data; tmux `-c` selects cwd.

The retained launcher field `tai_sha256` now binds the native launch implementation (the runtime digest), as `trust_sha256` binds its native helper alias. Existing authorities bound to the removed implementation must be regenerated for the new binary. No live caller/authority was edited.

F8 exposed CLI startup repaint after the faster direct exec. F9 therefore waits, within the existing requested readiness deadline, for two seconds of identical empty native composer/geometry after resize. It reuses `composer::screen` and does not type or retry. The new fast case uses the real captured idle composer and rejects drafts, copy mode and wrong geometry. Agy remains outside the current core's native composer support, matching its existing unqualified/merge-dependent status.

Trust still emits the existing `panel-env.sh` environment artifact and passes its path as `CLAUDE_ENV_FILE` for the external Claude CLI contract. The native runtime never executes or sources this artifact. Its contents are an `export TMPDIR` assignment, not an interpreter bridge hidden in data. This artifact is explicitly disclosed; it is not a tracked/shipped script or a runtime subprocess target.

## Verification and parity

The default F9 suite passes **125 tests in 1.90 s**; fourteen explicit harness/probe cases and six pane cases are ignored by default. F9 all-target clippy with warnings denied passes. Formatter and staged diff checks are recorded at completion. No external owner implementation is executed by the candidate or its verifier controls.

F6 debug evidence remains preserved: the original 15-second sender deadline expired with a pending-no-input record. F8 optimized evidence remains preserved: exact input was pasted but Enter was refused on geometry movement, leaving an unknown record. Both fresh seats were closed by their test-owned guard. Neither claim was retried or Start resent. Production validation uses the optimized build while preserving the 15-second source sender budget.

Final F9 results: **five non-model pane cases pass, one interactive case fails**, 67.28 s total. **All 15 native verifier CLI cases pass**, 0.69 s. Candidate SHA256: `4e39c182695636f972ae41375d77bb07fd65e7552e4906471682ef2fb74ab4f0`. The F9 verifier copy and pane copies bind that same optimized candidate. Logs live at `~/desk/tmp/relay/port/panel-evidence/fix/`; every CLI invocation retains argv, caller TMUX/TMUX_PANE, isolated HOME where applicable, stdout/stderr and expected/actual exit.

The final failed interactive root is `panel-evidence/corrected/plain-1792090474779156000`; its existing 60-second requested readiness deadline exhausted before Start. No sender retry or second Start occurred. The exact cause of the live readiness mismatch has not been established; the captured-fixture unit test alone does not establish renderer parity. The independent successful native verifier root is `panel-evidence/fix/consumer-dd534fbb29f7d0ad009ef571d8744976`. Its `parity.json` publishes the original absolute fixture roots; those hash-bound graphs were preserved in place.

| Shape | Real caller environment | Expected | F9 actual / exit |
| --- | --- | --- | --- |
| Four trust kinds, physical/logical paths and repetition | Private plain pane, isolated HOME, actual inherited TMUX/TMUX_PANE | Correct trust and stable repeat / 0 | Pass / 0 |
| Trust path/marker/scratch refusals; missing args | Same | Refuse / 1 or 2 | Pass / 1 or 2 |
| Eight dispatcher phases missing required options; help | Same | Refuse / 2; help / 0 | Pass / 2 or 0 |
| Native prepare/wait/collect/retain; typed nonresponse | Explicit path/hash authority and copied candidate through PATH | Bound candidate receipts / 0 | Pass / 0 |
| Own and preserved owned cleanup; provider temp/trust retirement | Only fixture-owned windows/processes/temp/config | Scoped retirement / 0 | Pass / 0 |
| Missing seat executable before spawn | Controlled test PATH; no routing variables | Refuse with automatic retained recovery / 1 | Pass / 1 |
| Data-only protocol checkout | Selected real schema without implementation modules | Prepare / 0 | Pass / 0 |
| Record-only/qualified/independent-convergence verification | Explicit project/protocol/dispatch/ledger/path/hash options | Bound PASS and expected sources / 0 | Pass / 0 |
| Stale native, wrong session, self activation, bad projection, shared inode, malformed sidecar, bad reads/launcher/account/decision/hash and classified unadmitted evidence | Same | Named refusal / 1 | Pass / 1 |
| Real Codex launch and single sanctioned Start | Plain pane; native launch sets documented seat env; sender would set documented CODEX_SEND_SESSION | Launch and deliver / 0 | FAIL: readiness deadline / 1; no Start |
| Real native reads/final/wait/collect/cleanup cycle | Same | Full cycle / 0 | Not reached on final candidate; owned failure recovery ran |

## Command::new inventory

| Location | Concrete program |
| --- | --- |
| `src/panel_dispatch.rs:515` | Pinned `/opt/homebrew/bin/tmux` → `/opt/homebrew/Cellar/tmux/3.7c/bin/tmux`; documented namespace args retained |
| `src/panel_dispatch.rs:577` | `/bin/ps`; observed descendant custody |
| `src/panel_dispatch.rs:711` | Current native runtime, sender surfaces cc-msg/codex-send-to/agy-send-to |
| `src/panel_launch.rs`, `Command::new(program)` | Native exec of the selected external CLI: inherited-PATH `codex`, inherited-PATH `claude`, HOME's `.local/cc-pinned-2.1.153/node_modules/.bin/claude`, or inherited-PATH `agy`; kind/profile/pane/source checked before exec |
| `src/panel_cleanup.rs:408` | PATH `trash`, currently `/usr/bin/trash`; owned temp retirement |
| Inherited `src/identity.rs:396,695` | Namespace-validated pinned tmux and pinned `/opt/homebrew/bin/tmux` |
| Inherited `src/runtime.rs:233` | Current native runtime, owned relay producer |
| `tests/panel_plain.rs:84` | Fixture PATH aliases to the copied candidate |
| `tests/panel_plain.rs:205,478,495,508,532,609,623,628` | Pinned tmux; own test window lifecycle/captures |
| `tests/support/panel_protocol.rs`, `Command::new(&surface)` | Alias to the copied native candidate in the preserved verifier evidence directory |
| Inherited `tests/support/private_server.rs:41`; `identity.rs:112,154`; `runtime.rs:167,464` | Current Rust test executable |
| Inherited `tests/support/private_server.rs:89,129,183,203`; `runtime.rs:773` | Pinned tmux private fixture lifecycle |
| Inherited `tests/support/runtime.rs:87` | `/bin/cat`, owned test child |

In the observed F9 environment, PATH `claude` is `~/.local/bin/claude` → `~/.local/share/claude/versions/2.1.300`, `agy` is the native `~/.local/bin/agy`, and `codex` is selected through the current fnm bin directory. The real Codex execution plan records its exact absolute selection. No Claude, DeepSeek or Agy model was launched by these checks. Their command/env vectors and trust/retirement paths have fast and no-model controls.

The final whole-crate grep is `panel-evidence/fix/grep-final.txt`: exit 0, six data matches. The exact required command was `git grep -n -i -E 'python|perl|fish|bash|/bin/sh' -- tmux/rust ':!*.md'`, after all new files were staged. Language-name matches are the external CLI's literal `Bash` tool name in transcript decoding, settings and `--tools` data, plus tests. They select no interpreter and contain no executable foreign-language body. No matching name is moved into an asset or encoded to conceal a launch. `commands-final.txt` is the unabridged current Command inventory.

## Scope and remaining integration limits

The schema adapter covers the pinned artifact and its recorded pattern vocabulary, with fail-closed handling of unsupported schema keywords/pattern syntax. The owner's complete ECMA-pattern compiler was not ported: valid future patterns outside the current vocabulary can be refused, so arbitrary changed project schemas do not have established exact parity. The translated normal-form gates also have source/fixture coverage rather than exhaustive owner-regression equivalence. These remain validator parity limits requiring review, not a blanket claim of identical validation for every caller-selected future schema. The selected project schema and evidence are re-read; only pure regex compilation is cached.

CLI lookup uses inherited PATH and the existing DeepSeek pin. No login-shell configuration is loaded and the old shell's deleted-fnm-link repair is not executed. The actual plain-pane PATH and all selected programs are recorded; that recovery behavior is outside the requested four-step native seat slice.

The separate #p4x agy-send-to registration remains a merge dependency; this lane does not duplicate that tool. Agy automatic collection/admission remains refused as in the live source. The independent #s11x relay cutover hold is unaffected. Native diagnostic wording/JSON formatting and the previously disclosed baseline trust differences remain outside exact text parity.

Full added/removed counts, final commit, final outcome and owned-window cleanup evidence are recorded at completion in the external summary. No public links, active config, relay-stable, callers, memories, other windows, sessions or servers were changed. No subagents or headless Claude were used.

Final row audit: 56 pane CLI invocations on the final candidate, 55 matching expected exits and one failed real launch; the five non-model pane cases account for 54 matching rows. The independent verifier adds 15 matching CLI rows. `final-row-counts.json` records the exact per-run totals. Private runner windows were `config-tt:p3x-test-fix-native` (@367/%404) and `config-tt:p3x-test-fix-consumers` (@369/%406); no test-created seat window remains.

Commit checks: formatter and staged diff checks pass. The credential hook first mistook a synthetic fixture root for a real home; the fixture root is now `/fixtures/operator`. Its complete next scan found only a literal environment-variable name in `.env(name, key.trim())`; the value is read at runtime and is not staged. The hook explicitly documents `git commit --no-verify` for a confirmed false positive; that exception was used for the F10 commit. The hook/allowlist were not edited, and the runtime variable name remains explicit in the source. The later F13 report update avoids repeating the synthetic path that triggered the privacy scanner.

Decision: **NO-GO / Divergence at F10.** Do not merge/deploy this as a completed panel port. Required remaining work is to reproduce and resolve the live readiness mismatch, pass a fresh real Codex lifecycle without replaying any prior claim/input, and close the stated validator parity limits. The runtime interpreter bridges are removed, but that alone does not satisfy the task's parity and end-to-end gate. No further implementation/test round is authorized by the current brief.
