---
name: specai-judgment-day
description: Use before creating a PR when adversarial dual-blind review is needed. Two independent judges review the same target in parallel; only issues confirmed by both get fixed.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Judgment Day — Dual Blind Review

> **ORCHESTRATOR GATE:** You are the controller. Do NOT review the code yourself.
> Dispatch Judge A and Judge B as separate subagents with identical instructions.
>
> **EXECUTOR OVERRIDE:** If you ARE a Judge subagent, ignore the gate. Review the
> assigned target independently. Do not communicate with the other judge.

## ABSOLUTE RULE (INQUEBRANTABLE)

**Launch BOTH judges in parallel. Wait for BOTH verdicts. Fix ONLY issues confirmed by BOTH. Maximum 2 fix iterations. Never review the code yourself as the controller. Never skip re-launching both judges after fixes.**

## When to Use

Optional step inside `specai-finishing-a-development-branch`, before PR creation.

Use when:
- The feature is architecturally significant
- You want independent review beyond acceptance criteria checking
- Tests pass but you want adversarial quality review

Do NOT use per task — token cost not justified for 2-5 minute atomic tasks.
The verifier already handles acceptance criteria per task.

## Hard Rules

- Launch Judge A and Judge B in parallel. Same target. Same criteria. Isolated contexts.
- Wait for BOTH verdicts before synthesis.
- Issues confirmed by BOTH judges → "confirmed" → eligible for fixing (ask first on round 1).
- Issue found by only ONE judge → "suspect" → report only, do not auto-fix.
- Judges contradict each other → "contradiction" → escalate to user.
- After any fix cycle: re-launch BOTH judges in parallel.
- Maximum 2 fix iterations. If issues remain after 2 rounds, ask user whether to continue.

## Issue Classification

| Finding | Label | Action |
|---------|-------|--------|
| Both agree: critical/warning | Confirmed | Fix (with user approval on round 1) |
| One judge only | Suspect | Report, do not fix |
| Judges contradict | Contradiction | Escalate to user |
| Warning only in extreme edge case | INFO | Report as informational, do not fix |

## Execution Steps

1. Identify review target: PR diff, specific files, or architecture slice.
2. Dispatch Judge A and Judge B via `delegate()` concurrently.
3. Collect both verdicts. Synthesize into confirmed / suspect / contradiction / INFO.
4. Present synthesis. Ask user before fixing Round 1 confirmed issues.
5. Dispatch a fix agent for approved confirmed issues.
6. Re-dispatch Judge A and Judge B after fixes.
7. Repeat until APPROVED or ESCALATED or user stops.

## Judge Prompt Template

Pass this to each judge subagent (identical for both):

```
You are reviewing [TARGET] as an independent code reviewer.
You do NOT know what another reviewer found — your verdict must be your own.

Reference documents (read only what is relevant to your findings):
- Spec: [path to _spec.md]
- Design: [path to _design.md]

Review for:
- Correctness against spec scenarios
- Design adherence (architectural drift, interface violations)
- Missing error handling or unspecified edge cases
- Naming clarity and code quality
- Coupling or cohesion problems

For each issue, classify as CRITICAL / WARNING / INFO.

Return a verdict table:
| Issue | File | Severity | Description |
|-------|------|----------|-------------|

Final verdict: ISSUES FOUND / CLEAN
```

## Output Contract

```markdown
## Judgment Day — [target]

Round: {N}

| Issue | File | Judge A | Judge B | Classification |
|-------|------|---------|---------|----------------|
| [issue] | [file] | ✅ Found | ✅ Found | Confirmed |
| [issue] | [file] | ✅ Found | ❌ Not found | Suspect |

Confirmed: {N} | Suspect: {N} | Contradictions: {N}

Fixes applied this round: {list or "None"}

JUDGMENT: APPROVED ✅ / ESCALATED ⚠️
```
