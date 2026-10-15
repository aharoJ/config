# Integrated Rust checks

The active relay, model, fresh-chat and panel implementations are multicall
surfaces in `tmux/rust`. Stage one built `angelstar-runtime` with command-name
symlinks in a private PATH directory. Public links and installed legacy copies
are not test fixtures and must remain unchanged.

Run from the repository root:

```text
cargo fmt --manifest-path tmux/rust/Cargo.toml --check
cargo clippy --locked --manifest-path tmux/rust/Cargo.toml --all-targets -- -D warnings
cargo test --locked --manifest-path tmux/rust/Cargo.toml
```

The default suite covers the relay state/store/identity/composer guards, model
picker and settling rules, fresh-chat captures and recovery profiles, and panel
trust/evidence/protocol/schema/cleanup controls. The shared model and fresh-chat
corpus checks both guards against the seven-model capture and native reset.
The old shared script aggregators and mixed model renderer are replaced by
these Rust checks and the explicit native harnesses below. Remaining legacy
investigation scripts are historical and do not establish integrated parity.

Run each signed private gate explicitly with `cargo test --locked --manifest-path
tmux/rust/Cargo.toml --lib <test-name> -- --ignored --exact`:

- `runtime::tests::private_delivery`
- `runtime::tests::effect_faults`
- `runtime::tests::activity_gate`
- `runtime::tests::activity_elsewhere_then_quiet`
- `test_server::lease_rejections`

The supervising Rust harness creates a fresh signed capability, claims its
socket before creation, and verifies socket/server generations during cleanup.
An inherited path, label, PID or pane hint alone does not grant authority.
Never stop the default or caller server. Never signal a discovered PID or
process group. Cleanup is limited to the run's verified socket and owned child
objects; unknown or uncontained state remains a failure.

# Native parity

Build an optimized candidate and native harness with `cargo test --release
--locked --manifest-path tmux/rust/Cargo.toml --no-run`. Freeze its commit and
SHA256, then select that candidate through private PATH symlinks from a plain
pane in an owned `config-tt:p3x-test-*` window. Inherit actual TMUX/TMUX_PANE.
Only documented caller env prefixes are permitted. Keep exact argv, env,
captures, receipts, exits and cleanup evidence under the run's desk directory.

The ignored `panel_plain::native_interactive_start_collect_cleanup` integration
case launches one fresh Codex seat, delivers one sanctioned Start, verifies full
prompt/intake reads and one native final, collects its bound receipts, and
retires only that owned seat. Run the compiled `panel_plain` test executable
with `--ignored --exact native_interactive_start_collect_cleanup --nocapture`.
Its PATH must also select the pinned candidate's public sender aliases.
Test authority proofs do not certify a production panel's admission or
independence. See the panel review files for retained validator limits.

Model and fresh-chat spot checks use their documented command shapes against
an owned interactive Codex pane. Relay checks use the user's existing visible
Claude pane and an owned Codex target; never start a headless Claude process.
No guard may be stubbed or weakened to make a native row pass. Uncertain input
must not be automatically replayed. Remove owned test panes/windows afterward.

# Capture provenance

Published captures use synthetic account identities and directories, with
unrelated private transcript prose replaced. ANSI styling, row widths,
wrapping and cursor metadata are retained. Manifest digests identify the
published bytes; `/fixtures/` identifiers are labels rather than raw-evidence
paths. Synthetic-derived cases remain explicitly distinct from native captures.
