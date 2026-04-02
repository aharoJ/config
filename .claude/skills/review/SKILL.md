---
name: review
description: LLM cross-review workflow for adversarial multi-model code review. Use when the user says "/review", "cross-review", or any /review subcommand (scope, check, bundle, resolve, close).
argument-hint: <scope|check|bundle|resolve|close> [component-name]
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---

# LLM Cross-Review Skill

## CRITICAL — Read Before Anything

1. **Read `~/.notes/projects/review/protocol.md`** on your first `/review` command in this session. It is the canonical spec. This skill file gives you the procedures; protocol.md gives you template formats, model intel, and classification criteria.
2. **Follow every step below in order.** Do not skip steps, improvise procedures, or "optimize" the workflow. The sequence exists because every shortcut was tried and failed.
3. **ALWAYS write drafts before intakes** — a draft in `research/` or `audit/`, then an intake in `intakes/`. Two separate files. Never skip the draft.
4. **ALWAYS run `/review close` exactly as specified** — do not summarize, paraphrase, or skip close steps. Every substep (CHANGELOG, constraints, runbook, roadmap, commit) is mandatory.
5. **NEVER create empty scaffold directories** — only create a directory when you are writing a file into it.

## BANNED — v1 Conventions (DO NOT USE)

These are OBSOLETE patterns from a previous version. If you find yourself writing any of these, STOP and use the v2 paths from the Directory Convention section below.

- **BANNED directory**: `templates/` — use `reviews/<topic>/` instead
- **BANNED directory**: `generated/` — use `reviews/<topic>/intakes/` instead
- **BANNED directory**: `rounds/` — use `reviews/<topic>/research/` or `audit/` instead
- **BANNED prefix**: `llm.intake.` — intake files are named `<type>-r<N>.md` (e.g., `research-r1.md`, `audit-r1.md`)
- **BANNED file**: `gotchas.md` — use `constraints.md`
- **BANNED commands**: `generate`, `triage`, `ship`, `audit` — use `scope`, `check`, `bundle`, `resolve`, `close`

If the project has existing v1 artifacts (`templates/`, `generated/`, `llm.intake.*`), leave them alone — they are historical. Write ALL new artifacts using v2 conventions only.

---

## The Loop

```
scope → check → bundle → [user pastes to 5+ LLMs] → resolve → bundle → [paste] → resolve → ... → close
 once    once    ╰───────────── repeat until all PASS ─────────────╯                              once
```

---

## Command Dispatch

Parse the user's argument and jump to the matching section below.

| Argument | What it does |
|---|---|
| `scope` | Define review target — once per review |
| `check` | CC internal pre-filter — once, skip for research |
| `bundle` | Create intake doc — each round |
| `resolve` | Classify findings + fix + sweep — each round |
| `close` | Finalize: changelog + constraints + runbook + commit — once |

If no argument is given, ask the user which command they want.

---

### `/review scope <component>`

1. Identify the component: source files, tests, tightly-coupled deps, build config.
2. Confirm with the developer: file list, line count, excluded areas.
3. Determine review type: **research** (design decisions) or **audit** (code correctness).
4. Read the project's `constraints.md` to avoid re-raising known constraints. Create it if missing: `# Constraints — <project name>`.
5. If `roadmap.md` exists, identify which phase this review belongs to. Create it if the project has multiple phases and no roadmap.

**Output**: Shared understanding of target. No dedicated scope file — held in conversation context.

---

### `/review check <component>`

**Skip for research-type reviews.** Only applies when there is code to audit.

1. Spawn **4 parallel subagents** via the Agent tool. Each gets fresh context (no shared findings):
   - **Security**: auth, injection, CSRF, trust boundaries, data flows
   - **Correctness**: logic bugs, type coercion, boundary validation, loop bounds
   - **Architecture**: design violations, module boundaries, state management, concurrency
   - **Test Coverage**: untested paths, missing edge cases, assertion quality
2. Each agent receives: full source + tests + `constraints.md` + mindset + output format (`**P0/P1/P2/P3**: <title> -- <file:line> -- <description> -- <proof>`)
3. Triage: count corroboration (2+ agents = high confidence). Classify each as REAL ISSUE or FALSE POSITIVE by **reading actual source code**.
4. Fix confirmed issues. Add regression tests if project has a test suite; document verification otherwise.
5. **Cross-pattern sweep**: grep entire codebase for same bug patterns. Fix all instances.
6. Run tests. Report: subagent round summary, bugs fixed with severities.

**CC subagents share model-family blind spots. Web LLM validation via `bundle` is NOT optional.**

---

### `/review bundle <component>`

1. Find source files for the component.
2. Check `reviews/<topic>/<type>/` for prior rounds.
3. **No prior rounds**: Write fresh draft at `reviews/<topic>/<type>/<topic>-r1.md`.
   - Read protocol.md for the exact template format (Research Template or Audit Template).
4. **Prior rounds exist**: Write `<topic>-r<N+1>.md` carrying forward Review History + Findings Evaluated and Rejected + What NOT to Re-Audit.
5. Expand draft to intake:
   - **With `{{FILE:path}}` markers**: Read each file, wrap in code fence with language annotation, output to `reviews/<topic>/intakes/<type>-r<N>.md`.
   - **Without `{{FILE:}}` markers**: Copy draft to `reviews/<topic>/intakes/<type>-r<N>.md` using intake naming (`research-r1.md` or `audit-r1.md`).
6. Tell the developer: intake ready at path, paste to 4+ LLMs (ideally 5-6).

**CRITICAL**: Draft and intake are SEPARATE files.
- Draft → `reviews/<topic>/research/<topic>-r1.md` or `reviews/<topic>/audit/<topic>-r1.md`
- Intake → `reviews/<topic>/intakes/research-r1.md` or `reviews/<topic>/intakes/audit-r1.md`

**Size warning**: If intake exceeds 150KB, warn developer — Kimi breaks at ~170KB.

---

### `/review resolve`

**For audit reviews** (code correctness):

1. For every finding: **read the actual source code** (never trust LLM quotes — ~60% FP rate in early rounds).
2. Classify as FALSE POSITIVE or REAL ISSUE. Present summary table.
   - FP categories: already handled, design intent, hypothetical, incorrect assumption, out of scope
   - REAL ISSUE subcategories: FIXABLE, WONTFIX, MITIGATED
3. Fix real issues. Write regression tests (if test suite). **Run tests.**
4. Update `constraints.md`: WONTFIX/MITIGATED issues, design intent FPs that reveal constraints.
5. **Cross-pattern sweep**: grep codebase for same patterns. Fix all. Re-run tests.
6. Note which model(s) found each issue.
7. Report: round #, bugs resolved with severities, FPs dismissed.
8. **Not converged** → tell developer: run `/review bundle` for next round.
9. **Converged** → tell developer: run `/review close`.

**For research reviews** (design decisions):

1. Aggregate model recommendations per question: ADOPT / DISMISS / INVESTIGATE.
2. Lock decisions: 3+ model agreement → locked → record in `decisions.md` with date, rationale, consensus.
3. INVESTIGATE items → new research round. 2 follow-up max, then force-disposition (DISMISS, ADOPT with caveats, DEFER to roadmap, or ACCEPT RISK in constraints).
4. All locked + no INVESTIGATE → converged → write runbook → audit rounds (if code) or `/review close` (if research-only).
5. Report: round #, decisions locked, items investigating, items force-dispositioned.

**Convergence**: All models (minimum 4) return PASS or PASS-with-caveats. Every P0-P3 dispositioned.

---

### `/review close`

**Do NOT skip or improvise any step.**

0. **Run tests** (if project has a test suite). If tests fail on source code → abort, return to `/review resolve`. If fail on test file only → fix, re-run, proceed.
1. **CHANGELOG.md** — update (or create) with newest-first entry. Read protocol.md for exact format (audit vs research templates).
2. **constraints.md** — append all new constraints sequentially. Read file first to find last number. Never renumber.
3. **PASS-with-caveats** — persist any model caveats as operational constraints in `constraints.md`.
4. **Runbook** — update if the review produced new verified results or implementation changes.
5. **roadmap.md** — mark phase COMPLETE with date, round count, finding count, model count.
6. **Commit**: `vX.Y -- <component> cross-review hardening (N rounds, M bugs resolved)` (audit) or `vX.Y -- <component> cross-review research (N rounds, M decisions locked)` (research).

---

## Directory Convention

```
~/.notes/projects/<project>/
├── roadmap.md
├── constraints.md
├── decisions.md
├── CHANGELOG.md
├── runbook/                      # technical deliverables
│   └── <topic>.md
└── reviews/
    └── <topic>/                  # one phase = one topic directory
        ├── research/             # drafts: <topic>-r<N>.md
        ├── audit/                # drafts: <topic>-r<N>.md
        └── intakes/              # expanded: <type>-r<N>.md
```

**One Phase = One Topic Directory** — every roadmap phase gets its own topic dir under `reviews/`. Never mix artifacts from different phases.

## File Naming

| Artifact | Location | Naming | Example |
|---|---|---|---|
| Research draft | `reviews/<topic>/research/` | `<topic>-r<N>.md` | `speed-r1.md` |
| Audit draft | `reviews/<topic>/audit/` | `<topic>-r<N>.md` | `speed-r1.md` |
| Intake | `reviews/<topic>/intakes/` | `<type>-r<N>.md` | `research-r1.md` |
| Runbook | `runbook/` | `<topic>.md` | `runbook/speed.md` |

## Read protocol.md for

- **Template formats**: Research R1, Audit R1, Round 2+ additions (headers, Review History, Rejected Findings, What NOT to Re-Audit)
- **Model intel**: Rankings, round strategy, when to drop models, minimum 4 per round
- **Classification criteria**: FP categories, severity mapping (P0-P3), multi-model corroboration rules
- **Cross-pattern sweep**: Full procedure for grepping + fixing pattern matches
- **Convergence details**: Ship-ready criteria, PASS-with-caveats handling
