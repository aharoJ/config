# Changelog

## v1.9 — Phase 8 Guest WiFi Implementation + Cross-Review Hardening (2026-03-29)

Phase 8: Guest WiFi with bandwidth priority for family visitors. 5-round adversarial multi-model review (3 research + 2 code audit rounds, 5 LLMs each, 25 total reviews). 2 code bugs found and fixed. Research finding rate: converged R3. Code audit finding rate: 2 → 0. Gotchas #66-#67 added.

### Infrastructure deployed (router UCI + nftables)

| Component | Detail |
|---|---|
| Bridge | `br-guest` (192.168.20.0/24), `delegate='0'` (no IPv6 PD) |
| WiFi | `flint-guest` on radio0 (2.4GHz only), WPA2-PSK (`psk2+ccmp`), `isolate='0'` (AirDrop) |
| DHCP | Pool .100-.199, 4h lease, IPv6 disabled |
| Firewall | `guest` zone (input=REJECT, forward=REJECT), guest→wan forwarding |
| Input rules | Allow-Guest-DHCP (UDP 67), Allow-Guest-DNS (TCP/UDP 53), Allow-Guest-ICMP (echo-request) |
| DNS redirect | DNAT port 53 → 192.168.20.1 (catches hardcoded DNS like 8.8.8.8) |
| SQM/CAKE | `layer_cake.qos`, `diffserv4 wash nat dual-srchost/dual-dsthost`, `squash_dscp='0'` |
| DSCP marking | nftables chain in fw4: guest traffic → CS1 (Bulk tin) via `ip saddr` + `ct original ip saddr` |
| nlbwmon | Guest added to `local_network` for per-device bandwidth tracking |

### Research decisions (3 rounds, 15 model reviews)

| Decision | Consensus | Rationale |
|---|---|---|
| New `br-guest` bridge | 5/5 R1 | Clean L2 isolation, proven Phase 5 pattern |
| CAKE `diffserv4` + DSCP CS1 marking | 5/5 R1 | Dynamic priority — guests get idle bandwidth, yield under contention |
| 2.4GHz only for guest | User decision | Separate radio = zero 5GHz airtime contention with owner devices |
| WPA2-PSK (`psk2+ccmp`) | 4/5 R1 | Compatibility for older kid devices |
| Client isolation disabled | 5/5 R1 | Family AirDrop/gaming between cousins |
| Captive portal dismissed | 5/5 R1 | Overkill for family guest network |
| 4h lease time | User decision | Transient guests, don't hoard the pool |
| `.lan` leakage accepted | User decision | Firewall blocks access to .lan IPs regardless |
| `squash_dscp='0'` + `wash` | 5/5 R2-R3 | Preserve marks for CAKE classification, strip before ISP |
| Upload-only bandwidth priority | User decision | Download (400 Mbps) unlikely to bottleneck; upload (23.5 Mbps) is scarce |

### Modified: `fish/internal/net/net.fish`

**Code audit R1 (5 models: Gemini, GPT, Kimi, DeepSeek, CC):**
- **P0**: Ingress DSCP mark in nftables prerouting doesn't reach CAKE on ifb4eth1 — tc ingress redirect fires before netfilter. Empirically verified. **Decision: Accept upload-only priority.** Documented as Gotcha #66. (2/5 CC, DeepSeek-R2)
- **P2**: Monitor awk regex `/192\.168\.20\./` not field-anchored — could false-match on hostname/client-id. Fixed: `$3 ~ /^192\.168\.20\./`. Documented as Gotcha #67. (4/5)

**Code audit R2 (5 models: Gemini, GPT, Kimi, DeepSeek, CC — 1/5 PASS, rest re-raised settled items):**
- 0 new real bugs. Converged at 0 findings.

**Phase 8 fish changes:**
- `net devices`: 3rd VLAN branch `192.168.20.*` → "guest" (cyan color)
- `net monitor`: awk counts guest devices separately, 3-way display (main/iot/guest), field-anchored regex
- `net scan`: guest VLAN detection from IP prefix
- `net dns`: guest VLAN classification (cyan color)

### Gotchas added
- **#66**: nftables DSCP marks in prerouting don't reach CAKE on ifb4eth1 (ingress) — tc redirect fires before netfilter
- **#67**: awk regex in SSH command substitutions must be field-anchored (`$3 ~`)

### Cross-review templates
- Research R1: `templates/rounds/guest-wifi/guest-wifi-research.md`
- Research R2: `templates/rounds/guest-wifi/guest-wifi-research-v2.md`
- Research R3: `templates/rounds/guest-wifi/guest-wifi-research-v3.md`
- Code audit R1: `templates/rounds/guest-wifi/guest-wifi-audit.md`
- Code audit R2: `templates/rounds/guest-wifi/guest-wifi-audit-v2.md`

---

## v1.7 — Phase 7 Wake-on-LAN Implementation + Cross-Review Hardening (2026-03-28)

Phase 7 (final): Wake-on-LAN for Ubuntu 24.04 LTS desktop, wired Ethernet on LAN port 4. Full implementation + 5-round adversarial multi-model review (2 research rounds + 3 code audit rounds, 5-6 LLMs each, 16 code reviews). 12 bugs found and fixed, 0 regression tests (no test framework). Finding rate: 10 → 1 → 1 → 0.

### Infrastructure deployed

| Component | Detail |
|---|---|
| Ubuntu SSH | openssh-server, key-only auth (password disabled), `ssh ubuntu` alias with ControlMaster |
| Ubuntu WoL | NetworkManager `802-3-ethernet.wake-on-lan magic`, `Wake-on: g` persists across suspend/resume |
| Ubuntu static IP | `192.168.1.60`, hostname `ubuntu`, WiFi disabled |
| Ubuntu hostname | `ubuntu.lan` via dnsmasq `dhcp.@host[]` + `dns='1'` |
| BIOS | WoL enabled, ErP disabled, Fast Boot disabled, AC recovery → Power On |
| Router | etherwake installed, static DHCP lease, DNS entry |
| Claude Code | Installed on Ubuntu, controllable via `ssh ubuntu` then `claude` |

### Research decisions (2 rounds, 10 model reviews, 5/5 PASS R2)

| Decision | Consensus | Rationale |
|---|---|---|
| etherwake (Layer 2) over wol/wakeonlan | 5/5 R1 | L2 doesn't need ARP, works on bridged interfaces |
| NetworkManager WoL persistence | 5/5 R1 | Native on Ubuntu 24.04 Desktop, systemd fallback if needed |
| Suspend (S3) as default power state | 5/5 R1 | LUKS blocks S5 cold boot (passphrase prompt), S3 bypasses |
| Disable WiFi on desktop | 5/5 R1 | WoL is Ethernet-only, WiFi adds confusion |
| Auto-suspend 30min idle | 4/5 R1 | Power savings when not in use |
| Static IP .60, hostname ubuntu | 5/5 R1 | Below DHCP pool (.110+), no conflicts |

### Modified: `fish/internal/net/net.fish`

**Code audit R1 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- **P1**: `ping -W 1` = 1ms on macOS (uses milliseconds, not seconds) — changed to `-W 1000` (4/5)
- **P1**: `net wake -` matches placeholder hostname `-` in known-devices.conf — added rejection guard (4/5)
- **P2**: MAC not validated before SSH command interpolation — added `string match -qr` regex validation (5/5)
- **P2**: SSH stderr suppressed with `2>/dev/null` hiding etherwake-not-installed — removed suppression, added specific error messages (5/5)
- **P2**: Comment lines not skipped in awk lookup — added `!/^#/` guard (2/5 CC, Grok)
- **P2**: Missing SSH pre-check unlike all other subcommands — added `ssh flint true` pre-check (2/5 DeepSeek, Grok)
- **P2**: Elapsed time used fixed counter, not wall clock — switched to `date +%s` (5/5)
- **P2**: Device type filter missing `laptop` (WiFi-only MacBooks) — added to blocked types (5/5)
- **P3**: TOCTOU dual awk lookups for MAC and type — combined into single awk pass (4/5)
- **P3**: known-devices.conf header said "tab-separated" but uses whitespace — fixed comment (4/5)

**Code audit R2 (6 models: Gemini, Codex, Kimi, DeepSeek, CC, Grok — 3/6 PASS):**
- **P3**: awk comment guard `!/^#/` doesn't skip indented comments — upgraded to `!/^[[:space:]]*#/` (4/6)

**Code audit R3 (6 models: Gemini, GPT, Kimi, DeepSeek, CC, Grok — 5/6 PASS):**
- **P3**: `net scan` instruction string missing hostname column (stale from pre-Phase 6) — added `Hostname` to format help (1/6 Gemini)

### Modified: `net/known-devices.conf`
- Added Ubuntu Desktop entry: `2c:f0:5d:d5:70:f6  Ubuntu-Desktop  desktop  main  ubuntu`
- Updated format comment: "tab-separated" → "whitespace-separated"

### Modified: `~/.ssh/config`
- Added `Host ubuntu` entry with ControlMaster multiplexing

### Router: `/etc/config/dhcp` (via UCI SSH)
- 1 `@host[]` entry: ubuntu → 192.168.1.60, MAC `2c:f0:5d:d5:70:f6`, `dns='1'`
- etherwake installed via `apk add etherwake`

### Gotchas added
- **#62**: macOS `ping -W` is milliseconds, not seconds
- **#63**: Validate MAC format before SSH command interpolation
- **#64**: Skip comment lines in awk lookups on config files
- **#65**: `known-devices.conf` uses `-` as placeholder hostname

### Cross-review templates
- Research R1: `templates/rounds/wake-on-lan/wake-on-lan-research.md`
- Research R2: `templates/rounds/wake-on-lan/wake-on-lan-research-v2.md`
- Code audit R1: `templates/rounds/wake-on-lan/wake-on-lan-audit.md`
- Code audit R2: `templates/rounds/wake-on-lan/wake-on-lan-audit-v2.md`
- Code audit R3: `templates/rounds/wake-on-lan/wake-on-lan-audit-v3.md`

---

## v1.5 — Phase 6 Local DNS Cross-Review Hardening (2026-03-27)

8-round adversarial multi-model review (5 independent LLMs × 8 rounds = 39 reviews) of Phase 6 local DNS hostname resolution. 4 research rounds (architecture decisions) + 4 code audit rounds (`net dns` fish function + UCI config). 8 bugs found and fixed, 0 regression tests (no test framework). Finding rate: 5 → 2 → 1 → 0.

### Research decisions (4 rounds, 19 model reviews)
- **TLD `.lan`** over `.local`/`.home.arpa` (4/4 R1) — `.local` conflicts with mDNS/Bonjour (RFC 6762)
- **`dhcp.@host[]` + `dns='1'`** for DHCP clients (4/4 R1) — creates A+PTR records via hosts file
- **`dhcp.@domain[]`** for router self-reference (4/4 R1) — router doesn't DHCP from itself
- **`local='/lan/'`** for authority (4/4 R1) — prevents all `.lan` leaks to NextDNS
- **Flat `.lan` for both VLANs** (3/4 R1) — DNS visibility is informational, firewall blocks traffic
- **DHCP pool start → 110** (4/5 R3) — keeps static IPs outside dynamic range
- Dismissed: `.local` TLD (mDNS conflict), `/etc/hosts` for router (not UCI-managed), second `@domain[]` for IoT gateway IP (causes round-robin), IoT subdomain `iot.lan` (unnecessary complexity)

### Modified: `fish/internal/net/net.fish`

**Code audit R1 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- **P1**: awk `gsub(/^./, ...)` stripped any character, not just quotes — latent corruption vector. Fixed: `gsub(/^'/, "", val); gsub(/'$/, "", val)` targeting single quotes specifically (5/5)
- **P2**: Silent empty results — printed headers with zero rows, no "no entries found" message. Fixed: `(count $entries) -eq 0` check (5/5)
- **P2**: `$status` only caught SSH transport failures — awk always exits 0, `uci` failures invisible. Fixed: `::UCI_FAIL::` sentinel with awk detection (1/5 CC, verified)
- **P3**: Unordered output from awk `for-in` hash iteration. Fixed: `| sort -t\t -k2` (4/5)
- **P3**: Header comment missing 4 subcommands (devices, monitor, scan, traffic). Fixed (1/5 CC)

**Code audit R2 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- **P1**: Pipeline masking — `sort` at end of pipeline swallowed awk's exit code, `$status` always 0. Fixed: split pipeline, `ssh|awk` first then sort separately (5/5)
- **P1**: awk `END` block runs after `exit 1` — partial data emitted on UCI failure. Fixed: `fail` flag in sentinel handler, `END` checks before output (2/5 Codex, DeepSeek)

**Code audit R3 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- **P2**: SSH failure not detected — only `$pipestatus[2]` (awk) checked, not `$pipestatus[1]` (SSH). Fixed: capture both into separate variables, check SSH first then awk (4/5)

**Code audit R4 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- 3/5 FAIL on false positive: claimed `$pipestatus` clobbered between `;`-separated `set` commands — disproven by empirical test (`false | true; set -l a $pipestatus[1]; set -l b $pipestatus[2]` → `a=1 b=0`)
- 2/5 PASS. Converged at 0 findings.

### Modified: `net/known-devices.conf`
- Added 5th column (hostname) for `.lan` DNS name cross-reference

### Router: `/etc/config/dhcp` (via UCI SSH)
- 1 `@domain[]` entry (router → 192.168.1.1)
- 10 `@host[]` entries with `dns='1'` (9 new, 3 updated from existing)
- `dhcp.lan.start='110'` (pool adjustment)
- `domain`, `local`, `expandhosts`, `domainneeded` were already GL-MT6000 defaults

### Gotchas
- Added #55-#61 (7 new validated constraints from Phase 6)

## v1.4 — Phase 5 Device Isolation Cross-Review Hardening (2026-03-27)

4-round adversarial multi-model review (5 independent LLMs × 4 rounds = 20 reviews) of Phase 5 device isolation. 2 research rounds (VLAN architecture decisions) + 2 code audit rounds (fish functions + UCI config). 8 bugs found and fixed, 0 regression tests (no test framework). Finding rate: 7 → 1 → 0.

### Research decisions (2 rounds, 10 model reviews)
- **Separate bridge** (`br-iot`) over VLAN-filtering on `br-lan` (5/5 unanimous R1)
- **No `lan → iot` forwarding** initially — least-privilege (2/5 R1, decided conservative)
- **DNS redirect** (DNAT port 53) to catch hardcoded DNS in IoT devices (5/5 R1)
- **`bridge_isolate='1'`** closes cross-radio L2 gap between 2.4GHz and 5GHz IoT clients (5/5 R2)
- **`delegate='0'`** + `ra='disabled'` + `dhcpv6='disabled'` for IPv6 lockdown (adopted R1+R2)
- Dismissed: VLAN-filtering bridge (unnecessary for WiFi-only IoT), hidden SSID (breaks IoT devices), masquerade on iot zone (WAN masq covers egress)

### Modified: `fish/internal/net/net.fish`

**Code audit R1 (5 models: Gemini, GPT, Kimi, DeepSeek, CC):**
- **P1**: `grep -Fi` MAC lookup in `net scan` — substring match against entire line, matches comments and duplicates, returns list → `test` crash. Fixed: anchored `awk -v mac tolower($1)==mac` with `exit` + `string trim` (5/5)
- **P2**: SSH data calls unchecked after reachability check in `devices`, `scan`, `monitor`. Fixed: `$status` check after each data SSH call (4/5)
- **P2**: Race condition between `wc -l` and `grep -c` in `net monitor`. Fixed: single atomic `awk` pass outputs `"total iot"` on one line (4/5)
- **P2**: Missing ICMP echo-request rule on iot zone — Roku/Hisense ping gateway for connectivity check. Fixed: added `Allow-IoT-ICMP` firewall rule (2/5)
- **P3**: `\r\n` line endings in `known-devices.conf`. Fixed: `string trim` on awk output (4/5)
- **P3**: Race condition `wc -l` vs `grep -c`. Fixed: merged into single awk pass (3/5)
- **P3**: Third VLAN falls through to "main". Documented as future concern (2/5)

**Code audit R2 (5 models: Gemini, Codex, Kimi, DeepSeek, CC):**
- **P3**: `net traffic` missing SSH status check (consistency with other subcommands). Fixed (1/5). 3/5 PASS.
- All 7 R1 fixes verified landed (5/5)
- 2/5 FAIL on false positive: hallucinated `nlbw` CSV delimiter format (contradicted by Gotcha #38 + live output)

### Router changes (via SSH, not in dotfiles repo)
- `br-iot` bridge device + `iot` network interface (192.168.10.1/24, delegate=0)
- `iot` firewall zone (input=REJECT, output=ACCEPT, forward=REJECT)
- `iot → wan` forwarding (internet access for IoT devices)
- Allow-IoT-DHCP (UDP 67), Allow-IoT-DNS (TCP/UDP 53), Allow-IoT-ICMP (echo-request)
- Force-IoT-DNS redirect (DNAT port 53 → 192.168.10.1, catches hardcoded DNS)
- IoT DHCP pool (.100-.149, 12h lease, ra/dhcpv6 disabled)
- Static leases: Roku TV → 192.168.10.10, Hisense #2 → 192.168.10.11
- IoT WiFi SSIDs on radio0 + radio1 (psk2+ccmp, isolate=1, bridge_isolate=1)
- nlbwmon `local_network` updated to include `iot`

### Modified: `net/known-devices.conf`
- Added VLAN column (4th field: main/iot)
- 6 new devices discovered and added during Phase 5

### New files
- `~/.notes/projects/wifi/isolation.md` — Phase 5 runbook
- `~/.notes/projects/wifi/templates/rounds/isolation/` — 4 templates (2 research, 2 code audit)

### Gotchas
- 12 new constraints (#43-54) added from Phase 5 cross-review

---

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
