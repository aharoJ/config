# Cross-Review Protocol Reference

## 1. Methodology

Adversarial multi-model code review: send code to 5+ independent web LLMs, collect findings, triage, fix real issues, iterate until all models say "ship it."

**Models to use** (minimum 4, ideally 5-6): Kimi, DeepSeek, Claude (web), ChatGPT, Gemini, Grok.

**Mode 3 enforcement**: Each round is fully independent. No model sees prior round findings. This prevents anchoring bias (Lou 2024: 37% anchoring index in LLMs). Independence is structural, not instructional -- models receive only the current artifact and audit questions, never a list of known issues.

**Round lifecycle**: generate template -> generate-intake.sh -> paste to web LLMs -> collect findings -> triage (CC classifies) -> fix real issues -> generate next round template -> repeat.

## 2. Template Structure Convention

```markdown
# Code Quality Audit: <Component> (Round N[ -- Final])

> **For**: Independent adversarial code audit by web LLMs
> **From**: Angel (aharoJ) + Claude
> **Date**: <YYYY-MM-DD>
> **Context**: <Round context -- what happened in prior rounds, what this round focuses on>

---

## Review History

### Round 1 (N models: <model list>)

Found X P1s, Y P2s, Z P3s, all fixed:
1. **P1**: <description> -- <fix summary>
2. **P2**: <description> -- <fix summary>
...

### Round N -- Findings Evaluated and Rejected

<Items raised but determined non-issues, with reasoning>

---

## Your Role

<What reviewers should do this round -- verify fixes, find what prior rounds missed, judge production readiness>

## What NOT to Re-Audit (Settled Across N Rounds)

<Bulleted list of items evaluated and accepted -- prevents re-raising>

## Output Format

- **PASS**: "Ship it. No blockers found." + confidence level
- **FAIL**: List every issue with severity, reproduction, and fix

If you find NOTHING new, say so honestly. Don't manufacture findings to justify your existence. After N rounds of hardening with M fixes, a clean PASS is the expected outcome.

---

## Source Code (All Fixes Applied)

{{FILE:path/to/file}}

{{FILE:path/to/tests}}
```

### Required Sections

| Section | Purpose | When to include |
|---|---|---|
| Review History | Accumulated record of all prior rounds | Round 2+ |
| Findings Evaluated and Rejected | Items raised but dismissed, with reasoning | Round 2+ (if any dismissed) |
| Your Role | What reviewers should focus on this round | Always |
| What NOT to Re-Audit | Settled items (do not re-raise) | Round 2+ |
| Output Format | PASS/FAIL instructions | Always |
| Source Code | `{{FILE:...}}` markers for all relevant files | Always |

### Round 1 Template (No Prior History)

For the first round, omit Review History and What NOT to Re-Audit. Include:
- Header with context explaining what the module does
- Numbered audit questions (Q1-Q9 style)
- Each question targets a specific concern: edge cases, line-by-line bugs, correctness, test coverage, security, etc.
- Source Code section with `{{FILE:...}}` markers

## 3. Template Naming

- First round: `<component>-audit.md`
- Subsequent: `<component>-audit-v2.md`, `<component>-audit-v3.md`, etc.
- Template name for generate-intake.sh: filename without `.md` extension
- Generated output: `docs/prompts/llm.intake.<template-name>.md`

## 4. Triage Classification

**Golden rule**: Read actual source code for every finding. Do NOT trust the LLM's quoted code -- it may be hallucinated or outdated.

### FALSE POSITIVE Categories

- **Already handled**: Code already addresses the concern (LLM missed it or quoted stale code)
- **Design intent**: Behavior is intentional
- **Hypothetical**: Scenario cannot occur given actual usage patterns or architectural constraints
- **Incorrect assumption**: LLM misunderstands the codebase, language, or library behavior
- **Out of scope**: Valid observation but not a bug

### REAL ISSUE Criteria

- Reproducible scenario OR provable code path
- Specific: points to exact line(s) with concrete failure mode
- Not already handled by existing code

### Severity Mapping

- **P0**: Data corruption, security holes, silent wrong behavior
- **P1**: Functional bugs that affect correctness but have workarounds
- **P2**: Code quality, edge cases unlikely in normal use
- **P3**: Style, naming, minor improvements

### Multi-Model Corroboration

- 3+ models report same issue: very high confidence it is real
- 2 models: high confidence
- 1 model: extra scrutiny required, but do not dismiss automatically -- solo findings can be the most valuable (ensemble diversity)

## 5. CHANGELOG Entry Format

Insert newest-first.

```markdown
## vX.Y -- <Component> Cross-Review Hardening (<YYYY-MM-DD>)

N-round adversarial multi-model code review (M+ independent LLMs) of `<component>`. K bugs found and fixed.

### Modified: `<file>`

- **P1**: <fix description>
- **P2**: <fix description>

### Tests

- Added N regression tests
- All tests passing (total count)
```

## 6. GOTCHAS.md Entry Format

Read GOTCHAS.md to find the current last number (create the file if it doesn't exist). Append new entries sequentially.

```
N. **Brief title**: problem description. Resolution statement.
```

Only add entries for validated failure modes where:
- The fix is already in the code
- The gotcha prevents re-introduction of the bug
- It is not obvious from reading the code alone

## 7. Convergence Criteria

A component is **ship-ready** when:
- A full round produces all-PASS across 4+ independent models
- No new P0, P1, or P2 findings
- P3-only findings are acceptable (document in What NOT to Re-Audit if out of scope)

Typical convergence: 2-5 rounds depending on module complexity.

## 8. Model Performance Intel

Empirical data from 77+ bugs across multiple projects:

| Model | Strength | When to use | Caveats |
|---|---|---|---|
| **ChatGPT** | Strongest adversarial auditor. Finds bugs in later rounds when others converge. | All rounds. Essential for later rounds. | None — always include. |
| **Gemini** | Second-strongest. Consistent across all rounds. | All rounds. | None. |
| **Claude (web)** | Thorough initial analysis. Good first-round coverage. | All rounds, but converges by R2-3. | Same model family as CC subagents — shares blind spots. |
| **Grok** | Strong independent perspective. Good for corroboration. | All rounds. | Newer to the rotation — less historical data. |
| **DeepSeek** | Fast converger. Good R1 coverage. | Round 1 primarily. Limited utility after R2. | Converges too fast for later rounds. |
| **Kimi** | Capable when it works. | Round 1 only, small-to-medium modules. | **Breaks on ~170KB+ intakes** (returns off-topic). Skip for large modules. |

**Round strategy**:
- **R1**: All 5-6 models (maximum coverage)
- **R2-3**: Drop DeepSeek if it PASSed R1. Drop Kimi if intake is large.
- **R4+**: ChatGPT + Gemini are most likely to find remaining issues. Others optional.

## 9. Cross-Pattern Sweep

When a bug is found and fixed, **immediately grep the entire codebase for the same pattern** before generating the next round. The same class of bug often appears in multiple places.

**Process**: Fix the instance -> derive the pattern -> grep the entire codebase -> fix all instances -> add regression tests for each.

## 10. CC Subagent Pre-Rounds

Before sending to web LLMs, run 4 parallel CC subagents with calibrated adversarial mindsets. This is Mode 3 by construction (each agent gets fresh context, no shared findings).

**Validated results**: Subagents typically find ~60% of bugs before web LLMs. Net effect: ~50% fewer manual web LLM rounds needed.

**Mindsets** (see SKILL.md `/review audit` for full descriptions):
1. Security Adversary
2. Correctness Pedant
3. Architecture Critic
4. Test Coverage Hunter

**Important**: CC subagents share model-family blind spots. Web LLM validation is NOT optional — it catches what same-model reviewers miss. Subagents are a pre-filter, not a replacement.
