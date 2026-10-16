# S5x pre-deploy sweep

2026-10-14. Five review agents covered delivery, identity/store, real-caller
parity, safety, and the deployment plan. The session permits three concurrent
subagents, so the final two lanes started as earlier lanes finished. This is
one consolidated fix round of the authorized three. No deployment occurred.

## Confirmed defects corrected

1. The delivery validator interpreted literal `set-buffer` data containing
   `#(`, `#{E:` or `#{T:` as executable format expressions. It now recognizes
   only the exact non-nested literal-buffer command before that scan. CR/LF,
   malformed buffer names, extra arguments, format flags and nested buffer
   commands still refuse. The focused offline regression failed before the
   correction and passes afterward; the authority suite retains the refusal
   cases.
2. Store reload checked content hashes and ledger structure but accepted
   internally consistent metadata with a sender label or code absent from the
   archived wire. Wire reads now share the existing publication attribution
   predicate. The new regression changes archive and attempt metadata while
   preserving the original wire and its hash; both label and code mutations
   now refuse as corrupt. The code-mutation case failed before the correction.
3. Tmux consumed a final semicolon in the buffer-data argument. A signed
   private probe reproduced truncation; the Rust delivery fixture then reached
   input-unknown with zero submissions and `post-paste bytes changed; no Enter`.
   Runtime now escapes that final argument semicolon while preserving the
   archive and expected wire. The same private fixture passes with both a
   trailing semicolon and an existing backslash before it, including exact
   submitted bytes and untouched decoys.

## Verification

The default Cargo suite passes 21 tests with seven specialized tests ignored;
the measured body remains about 0.6 seconds. Strict all-target Clippy, rustfmt
and whitespace checks pass. The delivery-authority suite passes eight tests;
the signed cleanup suite passes fourteen. The extended signed private delivery
fixture passes in 14.51 seconds. It remains ignored in the default suite.
The release build succeeds. Cargo's installed launcher is broken, so checks
used the existing stable toolchain's `bin` directory directly on PATH.

No native client was launched. Tests that created tmux servers used signed
private sockets under `~/desk/tmp`; their cleanup retired those sockets.
Production tmux use was read-only target identification. The existing K72
keeper record remains historical evidence for its exact native clients.

## Deployment blockers and known gaps

The external deployment plan is `s5x-deploy-plan.md`. Deployment
remains on HOLD pending caller migration and Angel's approval:

- Net rehearsal parses legacy delivered-record text, schemas and six-hex
  codes. An offline Node reproduction demonstrates its wrong fallback with
  Rust's submitted JSON. It must consume the reviewed attempt/archive/wire
  contract before cutover.
- Current callers lack required store/socket provisioning; some recipes also
  omit the now-required explicit Codex session. Agent memories describe
  pending exit 6 as background-owned, although Rust has no surviving worker or
  resume API. These caller changes are outside this worktree's authorized
  edits. A built binary alone does not resolve them.
- The binary retains compile-time helper paths through `delivery_guard.py`,
  `cleanup_guard.py` and `tools/test-server-cleanup`. Release packaging must
  preserve that chain. Existing model/new-chat/agy tools still need their
  legacy sibling helpers; `relay-stable` must not be indiscriminately replaced.
- Native images and renderer versions remain exactly pinned. K72 grants no
  fresh native launch or deployment authority. The accepted edit/disconnect
  and wall-clock rollback residuals remain unchanged.
- Format-like target-name evaluation and a strict whole-call wait bound equal
  to the CLI budget were not proven. No speculative change was made.
- A suspected directory-stream leak could not be reproduced: this filesystem
  rejected invalid UTF-8 filename creation with EILSEQ before enumeration.
  The failed setup test was removed and no identity fix was retained.

Detailed lane reports, red/green logs and private socket evidence are retained
in the shared external S5x audit package. Angel's pre-existing staged
paths are excluded from the fix commit and checked against the recorded index
hash before and after committing.
