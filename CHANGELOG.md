# Changelog

## v1.3 — Phase 4 Monitoring Cross-Review Hardening (2026-03-27)

4-round adversarial multi-model review (5 independent LLMs × 4 rounds = 20 reviews) of Phase 4 monitoring implementation. 2 research rounds (tool selection) + 2 code audit rounds (implementation). 15 bugs found and fixed, 0 regression tests (no test framework). Finding rate: 14 → 1 → 0.

### Research decisions (2 rounds, 10 model reviews)
- **nlbwmon** for per-device bandwidth (5/5 unanimous R1)
- **Router-side DHCP hotplug** for new device detection (5/5 R2)
- **Fish functions** over TUI dashboards (5/5 R1)
- **socat + launchd** for Mac syslog receiver (3/5 R1, validated R2)
- **SSH ControlMaster** for responsive CLI commands (5/5 R1)
- Dismissed: netdata (too heavy), vnStat (interface-only), arpwatch (Mac sleeps), collectd (CLI sufficient)

### Modified: `fish/internal/net/net.fish`

**4 new subcommands added:** `net devices`, `net monitor`, `net scan`, `net traffic`

**Code audit R1 (5 models: Gemini, GPT, Kimi, DeepSeek, Claude):**
- **P0**: `net scan` false "all clear" on SSH failure — empty MAC list → `unknown_count=0`. Fixed: SSH reachability guard (5/5)
- **P0**: `net traffic` prints header with no data on SSH failure. Fixed: SSH guard + sentinel pattern (4/5)
- **P1**: socat `fork` per UDP packet → resource exhaustion on Mac. Fixed: `UDP4-RECV` single-process mode (5/5)
- **P1**: N+1 SSH calls in `net scan` — one SSH per unknown device. Fixed: single SSH call, local parsing (5/5)
- **P1**: Hostname spaces break `net devices` — space-split parsing. Fixed: awk tab-delimited on router (5/5)
- **P1**: `net monitor` `free` field guard wrong (-ge 4, accesses $parts[7]). Fixed: `/proc/meminfo` awk parsing (5/5)
- **P2**: DHCP hook TOCTOU race — concurrent writes. Fixed: `flock -x 200` (5/5)
- **P2**: socat binds `0.0.0.0` — exposed on public WiFi. Fixed: bound to `192.168.1.220` (5/5)
- **P2**: nlbwmon duplicate `lan` in local_network. Fixed: single entry (5/5)
- **P2**: nlbwmon 24h commit → data loss on reboot. Fixed: reduced to 2h (2/5)
- **P2**: `net traffic` wastes SSH round-trip on existence check. Fixed: combined into single SSH (2/5)
- **P2**: DHCP hook unbounded file growth. Fixed: 500-line cap with `tail -n 500` rotation (4/5)
- **P2**: MAC addresses in known-devices.conf (privacy). Fixed: added to `.gitignore` (2/5)
- **P2**: No log rotation for router.log. Fixed: newsyslog config (4/5)

**Code audit R2 (5 models: Gemini, GPT, Kimi, DeepSeek, Claude):**
- **P2**: socat `UDP-RECVFROM` exits after one packet — log gaps during bursts. Fixed: `UDP4-RECV` (3/5). 2/5 PASS.
- All 14 R1 fixes verified landed (5/5)

### New files
- `~/.notes/projects/wifi/monitoring.md` — Phase 4 runbook
- `~/.notes/projects/wifi/templates/rounds/monitoring/monitoring-research-flint.md` — research R1
- `~/.notes/projects/wifi/templates/rounds/monitoring/monitoring-research-flint-v2.md` — research R2
- `~/.notes/projects/wifi/templates/rounds/monitoring/monitoring-audit.md` — code audit R1
- `~/.notes/projects/wifi/templates/rounds/monitoring/monitoring-audit-v2.md` — code audit R2
- `~/.config/net/known-devices.conf` — device inventory (gitignored)
- `~/Library/LaunchAgents/local.router.syslog.plist` — socat syslog receiver

### Router changes (via SSH, not in dotfiles repo)
- nlbwmon installed and configured (`/var/lib/nlbwmon`, 2h commit, LZ4 compression)
- DHCP hotplug hook at `/etc/hotplug.d/dhcp/90-newdev` (flock, 500-line cap)
- Syslog port changed from 514 to 5514

### Infrastructure
- SSH ControlMaster multiplexing added to `~/.ssh/config` (Host flint)
- `~/.config/net/` directory for monitoring data (router.log, known-devices, socat.err)
- `.gitignore` updated for monitoring files

### Gotchas
- 8 new constraints (#35-42) added to gotchas.md from Phase 4 cross-review

---

## v1.2 — Phase 3 Security Hardening (2026-03-26)

3-round adversarial research cross-review (5 LLMs × 3 rounds = 15 reviews). 14 hardening actions converged, 0 code bugs (router UCI commands only). Finding rate: 12 → 5 → 0.

### Router changes (via SSH, not in dotfiles repo)
- SSH key-only auth (Ed25519, password disabled) — P0
- WireGuard vpn zone isolation (input=REJECT, explicit DNS+SSH allow) — P0
- uhttpd bound to 192.168.1.1 only — P1
- IPv6 echo-request DROP (ordered before ACCEPT) — P1
- DNS-over-HTTPS via https-dns-proxy → NextDNS (profile 534aee) — P1
- 2.4GHz country code US — P1
- WAN drop logging (10/min) — P2
- Remote syslog to Mac — P2
- WireGuard keepalive, SSH/LuCI timeouts, sysctl hardening — P2

### New files
- `~/.notes/projects/wifi/security.md` — Phase 3 runbook
- `~/.ssh/config` — Host flint alias with Ed25519 key
- `~/.ssh/flint_ed25519` / `.pub` — router SSH key
- `~/.config/wireguard/flint2.conf` — WireGuard client config (gitignored)

---

## v1.1 — Phase 2 Ad/Malware Blocking: NextDNS Deployment (2026-03-25)

2-round research cross-review (5 LLMs each: Gemini, Codex, Claude, Kimi, DeepSeek) + 2-round code audit (5 LLMs each). 3 bugs found and fixed in `net.fish`, 0 regression tests (no test framework). Finding rate: 3 → 0.

### Research decisions (2 rounds, 10 model reviews)
- **NextDNS Pro** ($20/year) replaces Cloudflare 1.1.1.2 as router upstream DNS
- Both router DNS entries = NextDNS IPs (no Cloudflare secondary — round-robin bypass defeats blocking)
- Blocklists: OISD (full) + NextDNS Ads & Trackers (2 max — stacking counterproductive)
- uBlock Origin MV2 easy mode in Vivaldi (medium mode dismissed — breaks streaming/university)
- Bitdefender web protection works without VPN tunnel
- Router-only NextDNS (no Mac profile — preserves WesternU captive portal)

### Modified: `fish/internal/net/net.fish`

**Code audit R1 (5 models: Gemini, Codex, Claude, DeepSeek, Kimi):**
- **P2**: `%-12s` column overflow — `cloudflare-mw` is 13 chars, broke bench output alignment. Fixed: `%-14s` (5/5)
- **P3**: Missing Phase 2 `patched:` entry in file header (5/5)
- **P3**: Stale `date:` header (2026-03-24 → 2026-03-25) (2/5)

**Code audit R2 (5 models):** All-PASS convergence (5/5 PASS).

**Phase 2 deploy changes (pre-audit):**
- Comments updated: Cloudflare → NextDNS as router upstream
- `net bench`: tests `1.1.1.2` (Cloudflare malware) as comparison baseline instead of `1.1.1.1`
- `net home`/`net work`: no logic changes (DHCP DNS is router-agnostic)

### New files
- `~/.notes/projects/wifi/ad-blocking.md` — Phase 2 runbook
- `~/.notes/projects/wifi/templates/rounds/ad-blocking/` — research + audit intake templates
- `~/.notes/projects/wifi/gotchas.md` — 5 new constraints (#9-13) from Phase 2 cross-review

### Infrastructure
- `generate-intake.sh` now supports subdirectory templates (`speed/`, `ad-blocking/`)
- Templates reorganized: `rounds/<phase>/` and `generated/<phase>/`

---

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
