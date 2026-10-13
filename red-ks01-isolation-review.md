# KS01 test-isolation review

**Verdict: PASS for static test execution approval.**
**Counts: P0 0 · P1 0 · P2 1**

This was a source-only review of `tmux/tests`, test-facing paths in
`tmux/tools`, and `tmux/rust`. No test or tmux command was run.

## Boundary verified

- `test-server-cleanup` creates a fresh, signed per-run capability under
  `~/desk/tmp`, maps logical labels to a hashed socket below that private
  root, and records the socket inode, peer PID/generation, tmux start time,
  and server marker before it is reusable or stoppable.
- The default server, aliases of it, inherited `$TMUX`, outside-`~/desk/tmp`
  paths, non-private parents, missing records, replayed capabilities, and
  changed socket/process identities fail closed.
- Cleanup sends an explicit `-N -S <recorded-socket>` request only after
  revalidation and a server-side identity condition. It does not use
  PID-file/`ps` ownership as authority, `killpg`, `pkill`, or `killall`.
- The proxy path accepts only the exact leased physical `-S` received from a
  relay wrapper, strips it, and then re-enters the strict single-selector
  guard. Matrix, real-capture, automatic-binding, and paste-collision
  wrappers therefore cannot combine a named socket with an ambient route.
- Test-facing `run` now rejects renamed/non-tmux executable paths before a
  backend can run; the legacy `private-tmux-guard` uses the same strict entry.
- Delegated tmux backends receive `json.dumps(current_lease())`, so an
  explicit-`-S` bootstrap first creates or revalidates the signed current-run
  capability instead of indexing a possibly absent environment variable. The
  child environment cannot select a different capability.
- Native Python fixtures use the guarded private route. Rust's legacy ambient
  `Snapshot::capture()` fails with `InvalidNamespace`; bound capture uses an
  explicit socket and removes `TMUX`/`TMUX_PANE`. Ambient Rust fixtures are
  compile-disabled, while active native fixtures are private or fake Unix
  sockets.

## Lifecycle supplement (2026-10-12)

**Verdict: PASS for the stale-owned-socket retirement path.**

- `retire_dead_socket` reloads the current signed same-run record, requires
  the recorded PID generation to be gone, probes the Unix socket, and only
  continues on `ConnectionRefusedError`. A live listener, an unavailable
  identity check, or another socket error is refused rather than removed.
- It checks the socket's owner, type, device, and inode against the signed
  record after the refused probe, immediately before unlinking. The caller
  has already required a canonical non-protected path below `~/desk/tmp` and
  a private parent directory.
- `stop` first applies the existing server-side marker/PID/start-time/socket
  condition. After a successful native stop it polls the recorded kernel
  generation at 10 ms intervals for at most 0.5 seconds, then retires only
  the now-dead recorded socket. A server that remains live, a changed socket,
  or an unverified exit fails closed.

The focused private lingering-dead-inode regression now exercises the
retirement branch without issuing another tmux backend request after the
server is proven gone.

## Lab interruption handoff supplement (2026-10-12)

**Verdict: PASS for static lab rerun approval.** Signals received while the
lab is initializing, including during `Popen`, remain queued until the return
value has been assigned to `child`. The queued interruption is then raised
into the existing finalizer, which terminates and, if necessary, kills only
that retained `Popen` child. No process-group signal, PID discovery, or
ambient tmux cleanup path was added.

## Rust fixture lifetime supplement (2026-10-12)

**Verdict: PASS.** The active Rust action-guard fixture explicitly drops its
read-only `Namespace` peer after `verify_peer_image` and before asking the
signed-lease helper to stop the server. This allows the proven server to exit
without retaining a stale client connection; the helper still performs its
own current-record, inode, peer/kernel, marker, and conditional-stop checks.

## Matrix retirement caller supplement (2026-10-12)

The new `cleanup_guard.stop_label(self.socket)` call is authority-safe: the
logical label is mapped through the current signed lease and reaches the
already-reviewed identity-checked stop path. It has no name-only or ambient
tmux fallback.

**Resolved P2: validated-source teardown sequencing.**
`cleanup_session` now discards both the ordinary and source-session tracking
entries only after every guarded `kill-window` call succeeds, and then
evaluates the final signed-stop condition. If a window close fails, neither
entry is discarded and no premature server retirement is attempted.

## Deliberately quarantined / non-test paths

Legacy Rust live-server cases are compile-disabled with `cfg(any())`; the
remaining unsafe descendant/escape cases are explicit skipped tests. They are
not executable in the normal suite. Production delivery, watcher, and
operator-rescue tools still have intentional interactive production-server
routes; they are not test lifecycle paths and were not treated as test
approval routes.

## P2 — handoff packaging

The current worktree still shows the required `tmux/rust/`,
`tmux/tests/cleanup_guard.py`, and
`tmux/tests/cleanup-guard-regression.py` as untracked. Include them in the
change set before handoff. This is a packaging/completeness concern, not a
route to Angel's everyday tmux server: without the shim, the affected tests
fail before their guarded tmux actions.

## Conclusion

I found no remaining static route from an enabled test lifecycle to Angel's
everyday tmux server through a name-only socket, discovered PID, whole-process
group stop, or missing same-run ownership record. The current guarded test
paths may proceed to execution.
