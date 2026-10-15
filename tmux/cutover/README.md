# Prepared relay cutover

This directory prepares the four relay surfaces and their callers for an
explicitly approved cutover. Preparing packages, caller payloads and a
transaction does not activate them. Production links and caller files change
only through the installer's activation operation.

`package.py` builds the Rust source at its permanent package path so the
compiled delivery/helper paths remain valid. It also snapshots the actual
tracked Python tools, including concurrent working-tree changes, into the
rollback package. Both packages contain exact file, mode, source and link
inventories and a common dispatcher with explicit socket/store configuration.
Their immutable `transport.json` descriptors let Net retain the correct
read/status implementation after a pointer rollback.

`stage-callers.py` and `validate-callers.py` prepare and check active operator
instructions. Generated full document copies remain local and ignored;
the exact before/after hashes and transaction payloads are retained externally
for review. The changed Net modules and schemas in `staged/home` are tracked
explicitly. They accept both reviewed transports, bind the actual sender,
peer and full task wire, and refuse unproved success or automatic resend.

`install.py --prepare` copies the pinned before/after caller bytes into a
transaction beneath the desk directory. It verifies destinations, aliases,
modes, public links and both packages. Activation first enrolls all four public
links through the Python package, applies the compatible caller changes, then
switches the one pointer to Rust. Interrupted enrollment stays on Python;
the transaction journal and pinned payloads support explicit resume.
`--rollback` requires the exact current Rust candidate and restores the
Python pointer in one command. It retains compatible callers, both packages
and the Rust store, without resending or canceling any attempt.

`drain.py` is read-only. It checks configured inbox roots, old queue formats,
live senders including wrappers before handoff, the production Rust store,
and target generations. Ambiguous possible sender arguments refuse the
check. Terminal historical records and locks belonging to retired peers
remain retained without replay. Activation repeats the actual drain and
server-identity check before enrollment and before switching the pointer.

`smoke.py` implements a separately approved single-window refusal smoke.
It binds the complete package inventory, exact server/session identities,
driver hash and public entries before creating its own target/source/decoy
panes. It sends once to an incompatible owned sleep target and requires
proved no-input refusal, unchanged decoy and exact durable state. It creates
no native client and touches no existing agent pane. An unresolved operation
stops further server calls. A new native-positive matrix is not claimed.

The exact running Claude 2.1.296 image is admitted by size/hash alongside
the existing 2.1.299 and Codex profiles. Read-only binding, a sanitized current
composer fixture and the normal/private regression suites support that
addition. A moving `claude` link pointing at an unsupported newer image is
not equivalent to these pins.

Run the offline cutover tests with Python unittest discovery in `tests`,
`test_callers.py`, and Node's test runner on `tests/net-relay.test.mjs`.
The crate's default suite remains fast; signed private runtime diagnostics
remain separate ignored tests. The final external handoff supplies literal
commit/package/transaction hashes, the later activation sequence and the
single rollback command. Until that sequence receives final approval,
there is no deployment or smoke execution.
