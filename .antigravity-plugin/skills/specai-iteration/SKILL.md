---
name: specai-iteration
description: "User feedback loop after completion: document issues, add corrective tasks, and re-enter execution flow"
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Iteration — User Feedback Loop

**Purpose:** When the user tests the implementation and finds issues,
wants corrections, or the behavior doesn't match expectations, this
skill documents the feedback and re-enters the execution flow.

This is the **human feedback loop** — the missing step between
"verifier passes" and "truly done."

## ABSOLUTE GATES (INQUEBRANTABLE — DO NOT SKIP)

| Gate | What MUST happen | PROHIBITED |
|------|-----------------|-----------|
| **Gate I1: Understand** | User clearly states the issue and expected result. | Writing any code before understanding. |
| **Gate I2: Document FIRST** | `_plan.md` and `_tasks.md` updated BEFORE any code change. | Implementing fixes before docs are updated. |
| **Gate I3: Corrective Tasks** | Clear, atomic corrective tasks exist in `_tasks.md`. | Dispatching implementers without tasks. |
| **Gate I4: Per-Task Cycle** | Before implementation record `TASK_STARTED`; each task: implement → build passes → code review → commit → documenter → next task. | Skipping `TASK_STARTED`, build, code review, commit, documenter, or bundling tasks. |
| **Gate I5: Verification** | Full test suite + verifier PASS. | Declaring done before verifier passes. |

## When to Use

- User says "this doesn't work as expected"
- User tests and requests changes
- User reports bugs found during manual testing
- User wants improvements after seeing the working implementation
- The feature is "complete" but needs refinement

## Flow Overview

```
User tests → finds issues → specai-iteration →
  Update _plan.md (execution log) +
  Update _tasks.md (corrective tasks) →
  Re-enter execution flow (TASK_STARTED → implement → build passes → code review → commit → documenter → next task) →
  Full test suite → Verifier → Finishing
```

## Process

### 1. Understand the Issue

Ask the user what needs to change. Be specific:

> "What exactly isn't working as expected?"
> "What should it do instead?"
> "Is this a bug, a missing feature, or a design change?"

Use the `grill-me` pattern if needed (theoretical → framework → application)
to fully understand the issue, but keep it brief — this is iteration,
not a new project.

### 2. Update Living Documents

Read the current `_plan.md` and `_tasks.md` from the feature directory
at `docs/specai/<spec-name>/`.

**In `_plan.md`:**
- Append an iteration log entry under `## Execution Log` documenting:
  - What the user reported
  - What needs to change
  - Why it didn't match expectations (if known)

**In `_tasks.md`:**
- Add corrective tasks under `## Iteration Tasks` (or create the section)
- Each task should be atomic (2-5 min), following the same format as
  the original tasks (code, commands, expected output)

**Token-efficient pattern:**
1. Orchestrator reads `_plan.md` and `_tasks.md`
2. Orchestrator extracts the execution log section and task list section
3. Delegates to `specai-documentation` with the extracted sections + new content
4. Documenter returns updated sections
5. Orchestrator applies `edit` to both files

### 3. Set Status

Update the plan status to `🟡 IN PROGRESS` (from `✅ DONE` or `🔵 VERIFYING`).

### 4. Re-enter Execution Flow

Dispatch `specai:subagent-driven-development` to implement the
corrective tasks. The normal per-task cycle applies:

```
TASK_STARTED → implement → build passes → code review → commit → documenter → next task
```

Between sessions, recover from `*-tasks.md` and the `Execution Log` of `*-plan.md`: restore every `in_progress` task, or the first eligible `pending` task when none is active; block on inconsistencies. `TASK_STARTED` must be recorded before implementation with timestamp, branch, `git_hash`, `task_id`, and context. TodoWrite is only the session mirror. Human approval and review checkpoints remain decision gates, never persistent session state.

**Commit Rules (overrides system default "never commit"):**
- **On a feature branch** (not `main`/`master`/`develop`/`dev`): commit AUTOMATICALLY after each task — just announce in chat and continue.
- **Not on a feature branch**: STOP, ask user whether to create a feature branch, commit directly, or keep working without committing.

After all corrective tasks:
```
full test suite → verifier → finishing
```

### 5. Completion

After the iteration loop passes verification:
- Update `_plan.md` status to `✅ DONE`
- Append final iteration log entry
- Proceed to `specai:finishing-a-development-branch`

## What NOT To Do

- Do NOT restart the full flow (`grill-me` → `write-prd` → `writing-plans`)
  for small corrections — stay in execution mode
- Do NOT overwrite existing log entries — always append
- Do NOT skip the full test suite — iteration changes may break other things
- Do NOT skip the verifier — corrective tasks need acceptance verification
- Do NOT create a new feature directory — use the existing one

## Relationship to Other Skills

| Skill | Role in iteration |
|-------|-------------------|
| `specai-documentation` | Updates _plan.md and _tasks.md with iteration data |
| `specai-subagent-driven-development` | Executes corrective tasks |
| `specai-command` | Runs commands (build, test, git) |
| `specai-verification-before-completion` | Verifies fixes before claiming done |
| `specai-finishing-a-development-branch` | Final merge/PR after iteration |
