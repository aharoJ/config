# Changelog

## v1.0 — net.fish Cross-Review Hardening (2026-03-25)

6-round adversarial multi-model code review (6 independent LLMs: Kimi, DeepSeek, Gemini, Grok, Codex, Claude Code) of the `net` fish function. 21 bugs found and fixed, 0 regression tests (no test framework — dotfiles project). Finding rate: 7 → 3 → 4 → 5 → 2 → 0.

### Modified: `fish/internal/net/net.fish`

**R1 (6 models):**
- **P1**: Median crash when <3 dig queries succeed (`$sorted[2]` OOB)
- **P2**: No mDNSResponder bypass caveat on bench output
- **P2**: Compare diff labels ambiguous (`+N` → `↓N`)
- **P2**: `net home` hardcoded Cloudflare DNS → moved to Option C (router upstream)
- **P3**: Added `net quality`, `net curltime`, `net flush`, `net wifi` subcommands

**R2 (6 models):**
- **P1**: Median variable scoping — `set -l` inside fish if-block doesn't leak (0/6 caught, found by triage)
- **P2**: Removed obsolete `net compare` (both profiles use DHCP after Option C)
- **P2**: Added "unknown" fallbacks to `net wifi` for empty fields

**R3 (6 models):**
- **P2**: Signal/noise awk field — `$6` was `/`, corrected to `$7`
- **P2**: `net wifi` completely broken — fish command substitution collapses newlines (0/6 caught, found by live testing)
- **P3**: Removed dead `$bssid` variable
- **P3**: Defensive `math -s0` on median

**R4 (5 models):**
- **P2**: Guard `mktemp` failure in wifi
- **P3**: `networkQuality` command existence check
- **P3**: Suppress `killall` stderr in flush, report partial success
- **P3**: `curl --` separator for argument injection prevention
- **P3**: Renamed "signal:" to "sig/noise:" label

**R5 (5 models):**
- **P3**: flush tracks both dscacheutil and killall exit status independently
- **P3**: home/work guards DNS clear + DHCP renewal with `and`/`or` chain

**R6 (5 models):** All-PASS convergence (3/5 PASS, 2 FAIL with verified false positives only).

### Architecture Changes
- DNS moved from hardcoded Cloudflare on Mac (Option A) to router upstream Cloudflare + Mac DHCP (Option C)
- `net compare` removed (obsolete under Option C)
- `net wifi` uses tmpfile to preserve newlines from `system_profiler`

### New Subcommands
- `net quality` — wraps `networkQuality -v` (throughput + RPM)
- `net curltime [url]` — curl timing breakdown (dns/connect/tls/ttfb/total)
- `net flush` — flush mDNSResponder + Directory Services cache
- `net wifi` — WiFi connection details (SSID, channel, PHY, tx rate, signal/noise)

## 2026-03-19 — Hammerspoon Nuke & Rebuild + Claude Code Keybindings

Nuked the old GPT/Grok-built stackline (~2,500 lines) and rebuilt Hammerspoon from scratch (~150 lines). Moved config into dotfiles repo. Also tweaked Claude Code keybindings and default modes.

### Hammerspoon

1. **`hammerspoon/`** — New clean config with modular architecture (`init.lua`, `modules/reload.lua`, `modules/stack-indicators.lua`, `modules/utils.lua`)
2. **Stack indicators** — App icon pills on window edges for yabai stacks. Queries current space only, groups by `stack-index`, theme-aware (light/dark), click-to-focus
3. **Symlink** — `~/.hammerspoon/init.lua → ~/.config/hammerspoon/init.lua` so config is tracked in dotfiles
4. **Auto-reload** — Pathwatcher reloads on any `.lua` file save. IPC enabled for `hs` CLI commands
5. **`fish/internal/yabai/yr.fish`** — Added `hs -c "hs.reload()"` so Hyper+Q reloads hammerspoon alongside yabai + skhd

### Claude Code

6. **`~/.claude/keybindings.json`** — Rebound `Tab → chat:cycleMode` (was Shift+Tab), unbound Shift+Tab
7. **`~/.claude/settings.json`** — Default to plan mode + bypass permissions

## 2026-03-18 — Pre-commit Secret Scanner

Added a 3-layer pre-commit hook (ported from `~/.notes/`) to prevent accidental secret leaks in this public repo.

### Changes

1. **`.pre-commit-hook`** — Source template with path blocking (`stripe/`, `gh/`), content scanning (31 patterns), and allowlist support
2. **`.hook-allowlist`** — Initial allowlist (the hook file itself)
3. **`.gitignore`** — Added `stripe/` (Stripe CLI credentials directory)
4. **`CLAUDE.md`** — Documented hook architecture and post-clone install step

## 2026-02-26 — Fish Notes System Audit & Patch

Multi-model audit (lead_triage, deepseek, gemini-lite, gpt-nano, grok) across 2 passes, 86 findings triaged. 25 edits applied across 14 files.

### Critical fixes (showstoppers)

1. **nleitner.fish**: `<=` → `not test \>` in `_nleitner_run` and `_nleitner_status` — cards were NEVER showing as due (Fish `test` has no `<=` operator)
2. **nsync.fish**: `\s*` → `[[:space:]]*` in pre-commit hook — secret detection was non-functional on macOS (POSIX ERE doesn't support `\s`)

### Correctness fixes

3. **__notes_require.fish**: Added `-w` writable check for `NOTES_DIR`
4. **note.fish**: Added error check for `_notes_ensure_journal` failure
5. **nq.fish**: Robust error handling for journal creation + empty entry after sanitization guard
6. **nleitner.fish**: Deck name validation (reject slashes/dots = path traversal prevention)
7. **nleitner.fish**: Q/A count mismatch guard before drilling
8. **nleitner.fish**: `_nleitner_date_add` fallback when both date forms fail
9. **nleitner.fish**: Check `_nleitner_reconcile` return status
10. **nleitner.fish**: Empty deck name validation
11. **nleitner.fish**: Check `mkdir` return status for deck/state dirs
12. **nrate.fish**: Validate tmp file non-empty before `mv` (prevents note destruction)
13. **nrate.fish**: File existence check before awk
14. **nerror.fish**: Fix fzf preview path (was losing directory via `basename`)
15. **npresleep.fish**: Resolve paths to absolute before dedup check
16. **npresleep.fish**: Read queue line-by-line instead of command substitution

### Robustness fixes (unchecked mkdir)

17-21. **ncalibrate.fish, nerror.fish, nstruggle.fish, nwhy.fish, nrecall.fish**: All now check `mkdir -p` return status

### UX fixes

22. **ninterleave.fish**: Quit prompt accepts Q/q with whitespace trimming
23. **ninterleave.fish**: Check awk availability before shuffling

### Declined / not applicable (reviewed, no action needed)

- `$EDITOR` fallback (P3 — always set in `config.fish`)
- `seq` availability (ships with macOS)
- `__notes_slug` char coverage (current set covers all dangerous chars for APFS)
- `nf` cd not returning (by design — note functions operate in `$NOTES_DIR`)
- `git pull --rebase` (intentional, documented)
- Pre-commit hook "bashisms" (false positive — hook is pure POSIX sh)
