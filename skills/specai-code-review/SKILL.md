---
name: specai-code-review
description: Automated code review integrated into the per-task and end-of-flow cycles. Two specialized agents — code-reviewer (per task) and spec-compliance-reviewer (after all tasks, before verifier). Checks quality, architecture, security, performance, anti-bloat, spec compliance, and regressions.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Code Review (specai)

Automated code review integrated into the specai flow. Two specialized agents dispatched at different points, each with focused responsibilities.

## ABSOLUTE RULE (INQUEBRANTABLE)

**Code review is MANDATORY. Every task MUST pass code review before commit. The full implementation MUST pass spec compliance review before verification. No exceptions, no "it's simple enough," no skipping.**

## The Two Agents

| Agent | When | Focus | Scope |
|-------|------|-------|-------|
| `code-reviewer` | After build+tests pass, before commit (per-task) | "Did we build it right?" | Single task diff |
| `spec-compliance-reviewer` | After all tasks complete, before verifier | "Did we build the right thing?" | Full implementation |

```
Per-Task Cycle:
  TASK_STARTED → implementer → build ✓ → tests ✓ → code-reviewer → gate → commit → documenter

After All Tasks:
  full test suite → spec-compliance-reviewer → verifier → finishing
```

**Why two agents:**
- `code-reviewer` catches quality issues when they're cheapest to fix — right after the task, with minimal context
- `spec-compliance-reviewer` sees the full picture once all pieces are in place — catches cross-task inconsistencies a per-task reviewer can't see

## Agent 1: code-reviewer (Per-Task)

Dispatched after build and tests pass, before commit.

### Review Dimensions

| Dimension | What it checks |
|-----------|---------------|
| **Code quality** | Single responsibility, coupling/cohesion, naming clarity, DRY without premature abstraction |
| **Architecture** | Correct pattern (MVVM, MVC, Clean, etc.), layers respected, dependency injection where applicable |
| **Errors & edge cases** | Error handling completeness, null/undefined safety, boundary conditions, race conditions |
| **Performance** | N+1 queries, memory leaks, unnecessary allocations, blocking I/O, excessive re-renders |
| **Security** | Input validation at trust boundaries, no secrets in code, SQL injection, XSS, auth bypasses |
| **Testing** | Tests verify real behavior (not mock vacuums), edge cases covered, meaningful assertions |
| **Task compliance** | Every criterion mapped to this task is satisfied exactly; local PASS never substitutes for global invariant verification |
| **Anti-bloat** | `delete:`, `stdlib:`, `native:`, `yagni:`, `shrink:` tags |
| **Spec drift** | Ejecutar o exigir evidencia de `bash scripts/specai-drift.sh check <Feature-ID>`; cualquier `SPEC_DRIFT` bloquea el review |

### Technology Awareness

The reviewer adapts its checks to the project's technology stack. It inspects the codebase to determine:
- Language & runtime (TypeScript, Kotlin, Python, Go, Rust, etc.)
- Framework (React, Next.js, Vue, Spring, Django, etc.)
- Architecture pattern (MVVM, MVC, Clean Architecture, etc.)
- Testing framework (Jest, Pytest, JUnit, etc.)

Checks are tailored accordingly — e.g., Kotlin/Android gets compose lifecycle + coroutine checks, TypeScript/React gets hook rules + effect cleanup checks, Python/Django gets migration + ORM query checks.

### Output Format

```
### Strengths
[What's well done? Be specific with file:line references.]

### Issues

#### Critical (Must Fix — blocks commit)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix — fix before proceeding)
[Architecture problems, missing error handling, test gaps, performance issues]

#### Minor (Nice to Have)
[Code style, naming improvements, minor optimizations]

For each issue:
- File:line reference
- What's wrong
- Why it matters
- Suggested fix

### Anti-Bloat Report
[One line per finding. Tags: delete, stdlib, native, yagni, shrink]
net: -N lines possible. OR Lean already. Ship.

### Task Compliance
| Criterion | Evidence | Status |
|-----------|----------|--------|
| C<N> | exact file, symbol, assertion, or command output | PASS/FAIL |

**Compliance verdict:** PASS | FAIL

### Verdict
**Quality verdict:** CLEAN | CRITICAL | IMPORTANT | MINOR
```

## Agent 2: spec-compliance-reviewer (End-of-Flow)

Dispatched after all tasks complete and full test suite passes, before the verifier.

### Review Dimensions

| Dimension | What it checks |
|-----------|---------------|
| **Spec compliance** | Implementation matches specification — nothing missing, nothing extra |
| **Regressions** | Side effects outside intended scope, files modified unexpectedly |
| **Cross-task consistency** | Naming conventions, patterns, and architectural consistency across all tasks |
| **Global invariants** | Every `ARCHITECTURE`/`INTEGRATION` criterion's `Invariant` holds at its declared `Verification seam` |
| **Plan alignment** | All planned tasks implemented, no undocumented deviations |
| **Acceptance readiness** | Preview of `_verify.md` criteria — are any obviously not met? |

Antes del veredicto, `spec-compliance-reviewer` debe comprobar que el gate estructural de `SPEC_DRIFT` pasa para la Feature ID y revisar semánticamente el código frente a la spec de feature, la spec global, el delta, el diseño y la evidencia. Un fallo estructural o una contradicción semántica produce `FAIL`; no se puede degradar a warning.

### Output Format

```
### Spec Compliance
[Per-requirement: ✅ Met / ❌ Missing / ⚠️ Deviation. File:line references.]

### Regression Detection
[Unexpected changes outside scope. Files, lines, why it's a concern.]

### Cross-Task Consistency
[Naming clashes, conflicting patterns, architectural inconsistencies.]

### Verdict
PASS (ready for verifier) | FAIL (corrective tasks needed)
```

## Orchestrator Decision Tree

### After code-reviewer (per-task):

```
Reviewer Verdict:
├── Quality CLEAN + Compliance PASS → proceed to commit
├── Compliance FAIL → create a concrete corrective task before commit
├── CRITICAL → MUST fix before commit
│   ├── Atomic fix (≤10 lines, 1 file, straightforward) → orchestrator applies fix directly
│   └── Complex fix → dispatch implementer → re-run build+tests → re-dispatch reviewer
├── IMPORTANT → fix before proceeding
│   └── Same decision tree as CRITICAL (atomic vs complex)
└── MINOR → document for backlog, proceed to commit
```

The reviewer MUST NOT return a commit-ready result without both a quality
verdict and `Compliance verdict: PASS`. This local compliance check proves the
task's own criteria only; the end-of-flow reviewer and verifier still check
cross-task and global invariants independently.

### After spec-compliance-reviewer (end-of-flow):

```
Reviewer Verdict:
├── PASS → proceed to verifier
└── FAIL → generate corrective tasks in _tasks.md → re-enter per-task loop
```

## Documentation

After each review, `specai-documentation` MUST update:

**Per-task review:**
- `_tasks.md` — Mark task review checkbox, add corrective tasks if CRITICAL/IMPORTANT
- `_plan.md` Execution Log — Append `### Code Review: Task N` with verdict, issue summary, actions taken

**End-of-flow review:**
- `_tasks.md` — Add reviewed checkbox at bottom, corrective tasks if FAIL
- `_plan.md` Execution Log — Append `### Spec Compliance Review` with full verdict
- Optionally: `_review.md` — Full review report (generated by spec-compliance-reviewer agent)

**These are living documents — they must always reflect reality. Do NOT skip updates.**

## Delegation Rules

- **No agent may execute commands directly.** All builds, tests, and git operations MUST go through `specai-command`.
- **No agent may write documentation directly.** All document updates MUST go through `specai-documentation`.
- Both `code-reviewer` and `spec-compliance-reviewer` are READ-ONLY — they read code and report findings. They never modify code.

## Integration

**Required workflow skills:**
- **specai:specai-subagent-driven-development** — Provides the per-task cycle this skill integrates into
- **specai:specai-documentation** — All review documentation
- **specai:specai-command** — All command execution

**Related skills:**
- **specai:specai-anti-bloat** — Tags used by the reviewer (read-only, manual invocation)
- **specai:specai-verification-before-completion** — The verifier that runs after spec compliance review
- **specai:specai-iteration** — User feedback loop if review finds issues needing user input

## Red Flags

**Never:**
- Skip code review because "it's simple"
- Ignore or downgrade a failing `SPEC_DRIFT` gate
- Dispatch both reviewers in parallel (code-reviewer MUST complete before commit)
- Let the reviewer apply fixes directly (it's READ-ONLY)
- Skip re-review after fixes (if CRITICAL/IMPORTANT issues were fixed, re-dispatch)
- Proceed with CRITICAL or IMPORTANT issues unfixed
- Ignore cross-task consistency findings from spec-compliance-reviewer
- Skip documentation after review

**If the reviewer is wrong:**
- Push back with technical reasoning
- Show code/tests that prove correctness
- If disagreement persists, escalate to user

**If the reviewer finds a plan deviation that was intentional:**
- Document it in `_plan.md` with rationale
- If deviation is significant, ask user before proceeding
