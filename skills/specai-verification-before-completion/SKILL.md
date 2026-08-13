---
name: specai-verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law (INQUEBRANTABLE)

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

**This law applies to ALL agents at ALL times. NO exceptions. NO shortcuts. NO rationalizations.**

## The Gate Function (FOLLOW EXACTLY — NO SKIPS)

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete) — delegate to specai-command
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

**PROHIBITED: Claiming any status (DONE, PASS, FIXED, COMPLETE) without completing ALL 5 steps above.**

## SPEC_DRIFT hard gate

Antes de ejecutar el verifier o afirmar que una feature está lista, el controlador debe ejecutar:

```bash
bash scripts/specai-drift.sh check <Feature-ID>
```

Un código de salida distinto de cero o cualquier informe `SPEC_DRIFT` bloquea la verificación. El controlador debe mostrar las fuentes discrepantes, pedir al documentador que actualice el documento dueño y repetir el gate. No se puede convertir el resultado en una advertencia ni continuar con criterios de aceptación, `ready_to_finish` o finish mientras exista deriva abierta. La revisión semántica de código, spec de feature, spec de proyecto, delta, diseño y evidencia sigue siendo obligatoria además de esta validación estructural.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

Every acceptance criterion must use the same `Given / When / Then` structure.
For mechanical changes, `Then` must state the exact observable literal or
assertion; “larger”, “correct”, or “more readable” is not verification evidence.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## User Acceptance Gate (INQUEBRANTABLE)

Verifier PASS ≠ done. The plan is NOT complete until the user has tested the implementation and explicitly accepted it.

**Rules:**
1. After verifier PASS, present the implementation to the user: "Implementation is complete per `_verify.md`. Please test. Reply `accept` to proceed, or describe issues."
2. Do NOT invoke `finishing-a-development-branch` before the user replies with `accept` (or equivalent).
3. Record the user's acceptance timestamp and text in `_plan.md` Execution Log.
4. If the user replies with issues / "iterate" / "fix X", enter `specai-iteration` mode. Do NOT proceed to merge.

**Acceptance phrases (case-insensitive):** "accept", "accepted", "acepto", "OK", "looks good", "ship it", "merge it", "proceed"

**Rejection phrases:** "iterate", "fix this", "doesn't work", "bug", "needs more"

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
