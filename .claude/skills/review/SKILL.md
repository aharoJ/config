---
name: review
description: LLM cross-review workflow for adversarial multi-model code audit. Use when the user says "/review", "cross-review", "adversarial audit", "generate intake", "triage findings", or "ship review". Automates generating intake docs, triaging web LLM findings, and shipping hardened code.
argument-hint: <audit|generate|triage|ship> [component-name]
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---

# LLM Cross-Review Skill

Read the canonical definitions from `~/.notes/` and follow them exactly:

1. **Skill logic**: `~/.notes/tooling/cross-review/skill.canonical.md` — dispatch, 4 commands (audit, generate, triage, ship), mindsets, key rules
2. **Protocol**: `~/.notes/tooling/cross-review/protocol.canonical.md` — template structure, triage classification, severity mapping, model intel, post-fix discipline
3. **Lessons**: `~/.notes/tooling/cross-review/lessons.md` — empirical data from 77+ bugs, model rankings, round strategy
4. **Gotchas**: `GOTCHAS.md` (project root, symlinked) — validated design constraints, avoid re-raising
