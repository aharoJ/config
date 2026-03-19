---
name: review
description: LLM cross-review workflow for adversarial multi-model code audit. Use when the user says "/review", "cross-review", "adversarial audit", "generate intake", "triage findings", or "ship review". Automates generating intake docs, triaging web LLM findings, and shipping hardened code.
argument-hint: <audit|generate|triage|ship> [component-name]
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---

# LLM Cross-Review Skill

Dispatch on `$0`: `audit` | `generate` | `triage` | `ship` | empty -> print usage.

Read `${CLAUDE_SKILL_DIR}/references/protocol.md` for template structure, classification criteria, and file format conventions.

---

## Audit (`/review audit <component>`)

Goal: Run CC subagent pre-rounds to find bugs before web LLMs touch the code. Cuts manual web LLM rounds roughly in half.

1. Find source files for the component (same as Generate step 1).
2. Spawn **4 parallel subagents** using the Agent tool, each with a calibrated adversarial mindset. Each agent gets a fresh context (Mode 3 by construction — no shared findings). Provide each agent with:
   - The full source code of the component + tests + tightly-coupled deps
   - GOTCHAS.md if it exists (to avoid re-raising known constraints)
   - Their specific mindset instructions (below)
   - Output format: list issues as `**P0/P1/P2/P3**: <title> — <file:line> — <description> — <reproduction or proof>`

**Mindset 1 — Security Adversary**: Find auth/injection/input-validation bugs. Think like an attacker. Focus on trust boundaries, untrusted input, and data flows.

**Mindset 2 — Correctness Pedant**: Find logic/type/boundary-validation bugs. Line-by-line reading. Check every conditional, every loop bound, every type coercion, every default value.

**Mindset 3 — Architecture Critic**: Find design/abstraction/invariant violations. Check module boundaries, state management, error propagation, and idempotency guarantees.

**Mindset 4 — Test Coverage Hunter**: Find untested code paths, missing edge-case tests, configs that pass for wrong reasons. Cross-reference actual behavior against expected.

3. Collect results from all 4 agents. Triage internally:
   - Count corroboration (2+ agents find same issue = high confidence)
   - Classify each as REAL ISSUE or FALSE POSITIVE (read actual source code)
   - Fix confirmed issues.
4. **Cross-pattern sweep**: For every bug class found, grep the **entire codebase** for the same pattern. Don't wait for another model to find each instance.
5. Report: subagent round summary, bugs fixed with severities, then auto-generate web LLM intake (proceed to Generate).

---

## Generate (`/review generate <component>`)

Goal: Create an intake doc for `$1` that the user pastes into 5+ web LLMs (Kimi, DeepSeek, Claude, ChatGPT, Gemini, Grok).

1. Find source files for the component: config files, scripts, Lua modules, Fish functions, related configs.
2. Check `scripts/templates/$1-audit*.md` for prior rounds.
3. **No prior rounds**: Write fresh template at `scripts/templates/$1-audit.md`. Follow the protocol.md template structure: header with metadata, module description, 6-9 audit questions, Output Format (PASS/FAIL), Source Code with `{{FILE:path}}` markers.
4. **Prior rounds exist**: Read latest template. Write `$1-audit-v<N+1>.md` carrying forward Review History + What NOT to Re-Audit, updating for this round's context.
5. Run: `./scripts/generate-intake.sh <template-name> > docs/prompts/llm.intake.<template-name>.md`
6. Copy intake to clipboard: `cat docs/prompts/llm.intake.<template-name>.md | pbcopy`
7. Tell user: intake ready and copied to clipboard, paste into 5+ web LLMs, then `/review triage`. See protocol.md section 8 for model-specific guidance.

---

## Triage (`/review triage`)

Goal: Classify findings the user pasted from web LLMs. Fix real issues. Generate next round.

1. For every finding: **read the actual source code** (don't trust LLM quotes). Classify as FALSE POSITIVE or REAL ISSUE per protocol.md section 4. Present a summary table.
2. Fix real issues. Update GOTCHAS.md if any fix introduces a non-obvious design constraint.
3. **Cross-pattern sweep**: For every bug class fixed, grep the **entire codebase** for the same pattern. Fix all instances now — don't wait for models to find them in the next round.
4. Auto-generate next round template (vN+1) with updated Review History + settled items. Run generate-intake.sh. Copy to clipboard.
5. Report: round number, bugs fixed with severities, false positives dismissed, next intake path.

---

## Ship (`/review ship`)

Goal: Finalize the cross-review cycle. Version bump, changelog, commit.

1. Increment version in CHANGELOG.md. Add entry per protocol.md section 5 (newest-first).
2. Update CLAUDE.md if any references changed.
3. Stage only review-related files. Commit: `vX.Y -- <component> cross-review hardening (N rounds, M bugs fixed)`
4. Report: version, rounds, bugs fixed by severity.
