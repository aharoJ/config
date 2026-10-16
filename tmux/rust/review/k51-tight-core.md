# Five-module relay core — Red round-two PASS

The core is identity, composer, store, runtime and cli, with shared entry points. It retains exact signed routing, composer checks, verified archives, permanent reservations, durable input/submit barriers, one foreground delivery owner, same-server focus/activity-gated Enter and actual-child cleanup. Receipt proof, pruning/reuse and pending resume are unavailable. Unsupported receipt fields/states refuse.

Red passed the tight core in red-k51-tight-core-r2.md. Reviewed source inventory digest: b43567c2bfceeb04db20686fc2e52ec25c766123f512ff6b63148a581977ffe8. Both previous findings are resolved: the reproduced activity case asserts actual server activity refusal, zero Enter and permanent unknown; undeployed receipt compatibility is removed.

Evidence: 15 default tests pass (0.56 s body; 2.382 s Cargo wall); strict all-target Clippy passes. Signed fixture diagnostics pass: activity 3.215 s, delivery 10.468 s, nine-boundary crash test 10.549 s. Their fixtures share one server per diagnostic and wait on bounded events. No real client launched. Historical ENXIO failures and native safe/unsafe/privacy HOLD remain; no deployment clearance is implied. Full local evidence is retained under the K51 package and hash manifests.

K52 commit preparation changes only test traceability: the same corpus location derives from normal HOME rather than a machine-specific home literal, and ignored-test reasons now state their current explicit fixture scope. Production core code is unchanged from the Red-reviewed pin. All older source is retained in the local attic.
