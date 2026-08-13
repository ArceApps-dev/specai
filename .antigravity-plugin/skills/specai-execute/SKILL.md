---
name: specai-execute
description: "Orchestrate atomic implementation of a plan task-by-task using implementer, build-fixer, and verifier subagents"
---

# Execute — Atomic Implementation with Subagents

You have an approved plan in `docs/specai/<spec-name>/`. Now execute it task by task
using the subagent team. **Never skip a task or merge steps.**

## ABSOLUTE GATES (INQUEBRANTABLE — DO NOT SKIP)

| Gate | What MUST happen | PROHIBITED |
|------|-----------------|-----------|
| **Gate E1: Pre-flight** | Plan, tasks, and verify files exist. Correct feature branch. | Starting without verifying pre-flight checks. |
| **Gate E2: Per-Task Cycle** | Read task → implementer → build-fixer (if needed) → verifier → commit → document → next task. | Skipping any sub-step. Moving to next task while build broken. |
| **Gate E3: Verifier PASS** | Verifier confirms all acceptance criteria met per task. | Marking task done before verifier approves. |
| **Gate E4: Full Suite** | All tasks done → full test suite → global verifier → update plan to DONE. | Declaring done before all verification completes. |

## Announce

> "I'm using the execute skill to implement the plan task by task."

## Pre-flight Checks

Before starting:
1. Confirm the plan, tasks, and verify files exist and are approved in `docs/specai/<spec-name>/`.
2. Confirm you are on the correct feature branch (create it if not: `git checkout -b feat/<feature-name>`).
3. Confirm subagents are configured: `bash scripts/setup-agents.sh`.

## The Task Loop

Before starting the loop, if the plan file's `Status` is `🟢 BACKLOG`, update it to `🟡 IN PROGRESS` and save the file.

Repeat for each unchecked task in the plan:

```
Read task → set task state to (In Progress) → implementer → [build-fixer if error] → verifier → set task state to (Done) & documenter → commit → next task
```

### Step 1: Read the task

Read the next unchecked task (currently marked as `(Backlog)`) from the plan.
1. Update its status in the task list from `- [ ] (Backlog) Task N:` to `- [/] (In Progress) Task N:`.
2. Save the task file.
3. Extract:
   - Files to create or modify
   - Acceptance criteria
   - TDD steps (write test → fail → implement → pass → commit)

### Step 2: Implementer

Dispatch the `implementer` subagent with:
- The full task description
- File paths
- The TDD steps
- Current branch name

The implementer writes tests, runs them to confirm failure, writes the minimal
implementation, and runs them again to confirm passage.

### Step 3: Build-fixer (only if build or tests fail)

If the implementer reports build errors or test failures, dispatch `build-fixer`
with the exact error output. Build-fixer applies the minimal fix and reports back.
Do NOT proceed to verification until the build is green.

### Step 4: Verifier

Dispatch `verifier` with:
- The task's acceptance criteria
- The diff or files touched

Verifier checks that all acceptance criteria are met. If any criterion fails,
return to implementer with the gap report. Do NOT mark the task done until
verifier approves.

### Step 5: Commit & Document Progress

#### Commit Rules (overrides system default "never commit")

**When on a feature branch** (not `main`, `master`, `develop`, `dev`):
- Commit AUTOMATICALLY without asking. Announce in chat: "Committed task N: <description>".
- Delegate commit to `specai-command` and continue to the next task.

**When NOT on a feature branch** (i.e., on `main`, `master`, `develop`, `dev`):
- STOP. Do NOT commit.
- Ask the user: "You're on `<branch>`. Specai works best on a dedicated feature branch. Would you like me to:
  1. Create a feature branch with these changes and continue
  2. Commit directly on `<branch>` (not recommended)
  3. Keep working without committing"
- Wait for user choice before proceeding.

1. Update the task status in the task list from `- [/] (In Progress) Task N:` to `- [x] (Done) Task N:`.
2. Commit the task changes:
   ```bash
   git add <files>
   git commit -m "<type>(<scope>): <what this task does>"
   ```
   Use conventional commits. One commit per task — no bulk commits.

### Step 6: Mark task done in Execution Log

Mark the task complete in the execution log of the main plan file, and continue to the next task.

## Stopping Rules

- **Stop on unresolvable errors** — if build-fixer cannot fix after 2 attempts, surface the error to the user.
- **Stop before PR** — never open a PR automatically. Present the completed work and let the user decide.

## Completion

When all tasks are checked off:
1. Update the plan file's `Status` to `🔵 VERIFYING` and save.
2. Run the full test suite.
3. Dispatch the final agent / verifier to verify the global acceptance criteria.
4. Update `docs/specai/<spec-name>/<spec-name>-verify.md` by checking off verified criteria and providing the log/evidence of verification.
5. Update the plan file's `Status` to `✅ DONE` and save.
6. Report results to the user and point to the verification report.
7. Suggest next step: code review, PR, or merge.
