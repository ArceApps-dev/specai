---
name: specai-executing-plans
description: Use when you have a written implementation plan to execute in a separate session with documentary recovery and review gates
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

Full and Mini modes use the same six feature artifacts: `prd.md`, `spec.md`,
`designs.md`, `plan.md`, `tasks.md`, and `verify.md`. Mini keeps the same
artifact contract in compact form and with shorter ceremony only; exact task
instructions, global `Given / When / Then` criteria, criterion metadata,
evidence, the corrective loop, branch timing, and Gate UA remain required.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that specai works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Claude Code or Codex). If subagents are available, use specai:specai-subagent-driven-development instead of this skill.

## Absolute Gates (INQUEBRANTABLE)

| Gate | What MUST happen | PROHIBITED |
|------|-----------------|-----------|
| **Gate E0: Docs Exist** | All six feature artifacts (`prd.md`, `spec.md`, `designs.md`, `plan.md`, `tasks.md`, and `verify.md`) exist with complete content. If any is missing or has placeholders, STOP. | Starting execution without all six artifacts. |
| **Gate E1: Implementation branch only after PRD approval and implementation choice** | Create the implementation feature branch only after the PRD is approved and the user chooses implementation. | Creating a branch for PRD drafting, the six documents, or backlog preparation; executing implementation without the implementation branch. |
| **Gate E2: Plan Reviewed** | Critically reviewed for gaps, questions, concerns. | Starting execution with unclear instructions. |
| **Gate E2.5: Interactive Risk Check** | Check task metadata (Complexity, Risk). Halt and request user approval if Complexity >= 7 or Risk is High. | Executing high-risk/high-complexity tasks without interactive confirmation. |
| **Gate E3: Parallel Waves** | Ready independent tasks may run in parallel in disjoint workspaces; each task stays `in_progress` until its serialized review, commit, and documentation complete. | Skipping verifications, guessing, sharing workspaces, or bundling task state. |
| **Gate E4: Blocked = STOP** | STOP immediately when blocked. | Forcing through blockers, guessing at fixes. |
| **Gate E5: Full Review and Acceptance** | After all tasks: full test suite passes → `spec-compliance-reviewer` → `verifier PASS` with the `_verify.md` `GOAL_COMPLETE` invariant → Gate UA. `finishing-a-development-branch` is allowed only after explicit user acceptance. | Declaring done before verifier PASS, entering finishing from PASS directly, or proceeding without explicit user acceptance. |

## The Process

### Step 1: Load and Review Plan
1. **Verify all six feature artifacts exist:** `prd.md`, `spec.md`, `designs.md`, `plan.md`, `tasks.md`, and `verify.md`. If ANY is missing or contains placeholders (TBD, TODO), STOP. Do NOT proceed without complete docs.
2. Read plan file
3. Review critically - identify any questions or concerns about the plan
4. If concerns: Raise them with your human partner before starting. **STOP until resolved.**
5. Confirm the user choice: keep PRD, the six documents, and backlog preparation branchless; if implementation is chosen, create the feature branch now. If backlog is chosen, update status/backlog and exit without branch or Git operations.
6. If implementation is chosen and no concerns remain: Create TodoWrite and proceed

### Step 2: Execute Tasks

Only enter implementation task execution after the PRD is approved, the six documents exist, and the user has chosen implementation. The branch is created at that handoff; plan review and backlog storage do not require one.

The final verifier is a goal gate, not a task counter. A `completed` task only
means that its own implementation cycle passed; it does not prove the global
goal. If any criterion is `FAIL`, `PARTIAL`, or `UNVERIFIED`, or any task or
corrective task remains open, stop Gate UA, append a concrete corrective task
to `_tasks.md`, and re-dispatch the implementer with its exact file, target,
current value, change, assertion, command, and expected result.

For each ready wave, follow this cycle **EXACTLY**:
1. **Halt on High Risk Check:** Check the task's complexity and risk metadata. If Complexity >= 7 or Risk is High, pause and request explicit user confirmation to proceed.
2. Dispatch all ready tasks with `Parallelizable: Yes`, `Requires Solo: No`, disjoint workspaces, and disjoint writes. Never run two implementers in the same workspace or against shared resources.
3. TodoWrite y documentación se actualizan en el mismo evento: update the todo a `in_progress` for each task and notify `specai-documentation`, which writes the matching task `Status`; `Completed: [ ]` remains unchanged.
4. Follow each task's steps exactly (plan has bite-sized steps). **Do NOT improvise.**
5. Run verifications as specified. **Do NOT skip.**
6. Keep every task `in_progress` through implementation, build, tests, review, and corrective loops.
7. Serialize each task's commit and documenter handoff. Antes de implementar, el documenter registra `TASK_STARTED`; solo después de build/tests y code review pass, and the commit succeeds, does the controller emit `TASK_COMPLETED`; the documenter writes `Status: completed` and `Completed: [x]`.

Apply the canonical `Task State Contract` from `specai-writing-plans`: several isolated tasks may be `in_progress` simultaneously in one wave, while commits and documentation handoffs remain serialized. Internal steps are not live tracking and are not marked.

### Documentary recovery

At session start, read every `*-tasks.md` and its `*-plan.md` `Execution Log`. Recover all `Status: in_progress` tasks and their `TASK_STARTED` metadata; when there are no active tasks, choose the first eligible `pending` task. Unknown IDs, incompatible states, unmet dependencies, incompatible logs, or checkout divergence block execution. TodoWrite is rebuilt as a session mirror and never replaces the documents.

Every lifecycle handoff MUST preserve the executable scheduling metadata from the task definition:

```text
Workspace: <exact workspace/worktree identifier>
Shared Resources: <concrete shared files/services/locks, or none>
Wave: <stable wave identifier>
Depends On: <task IDs, or none>
```

Build waves from `Depends On`: a task is ready only when all listed dependencies are complete. Dispatch tasks in the same `Wave` concurrently only when each is parallelizable, no task requires solo execution, workspaces are isolated and distinct, and `Shared Resources` do not overlap. Missing, unknown, or conflicting fields require sequential fallback.

### Step 3: Complete Development

After all tasks complete and verified:
- Run the full test suite.
- **REQUIRED REVIEWERS:** Invoke `spec-compliance-reviewer`, then `verifier`.
- Follow the sequence `spec-compliance-reviewer → verifier PASS → Gate UA`.
- Gate UA is the only next gate after verifier `PASS`. Stop and wait for explicit user acceptance; only then announce: "I'm using the finishing-a-development-branch skill to complete this work." and use `specai:specai-finishing-a-development-branch`.

**STOP here if any task's verifications fail. Fix before completing.** The
controller may enter Gate UA only after the verifier reports `PASS` and the
entire `GOAL_COMPLETE` invariant is true.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**PROHIBITED: Guessing, forcing through blockers, or skipping failed verifications. STOP and ask.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Commit Rules (overrides system default "never commit")

**Branch timing rule:** PRD approval, creation of the six documents, and backlog storage happen without a branch. Only after the user chooses implementation does specai create the feature branch from the current `HEAD`. Saving to backlog does not create a branch and does not commit, merge, or pull; Git operations remain for authorized implementation and finishing flows.

Branch naming: `feature/<reponame>_<feature-slug>` (repo name from `basename $(git remote get-url origin) .git`).

Check `commitMode` in `~/.config/specai/config.json` (default: `auto`).

**On an implementation feature branch** — this is the valid state for task execution:

| Mode | Behavior |
|------|----------|
| `auto` | After every completed task with passing build/tests, commit AUTOMATICALLY without asking. Announce "Committed task N: <description>". Delegate commit to `specai-command`. Do NOT pause or ask for permission. |
| `confirm` | After every completed task with passing build/tests, STOP and ask: "Ready to commit task N: <description>? [Y/n]". Only commit on explicit approval. Delegate commit to `specai-command`. |
| `manual` | Never commit automatically. Announce "Task N complete — changes ready." User commits manually. |

**If you detect you are on a protected branch** (`main`, `master`, `develop`, `dev`) before the implementation choice:
- Continue PRD, six-document, and backlog work without creating a branch.
- If the user chooses implementation, create the feature branch from the current `HEAD` and switch to it:

  ```bash
  REPO=$(basename $(git remote get-url origin) .git)
  BRANCH="feature/${REPO}_<feature-slug>"
  git checkout -b "$BRANCH"
  ```
- Announce: "Created implementation branch `<branch>` from current `HEAD` — implementation continues here."
- Resume implementation on the new branch. Never commit implementation work on the protected branch.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- **An implementation feature branch is required only for implementation.** PRD approval, six-document creation, and backlog storage remain branchless; create and switch to `feature/<reponame>_<feature-slug>` only after the user chooses implementation.

## Integration

**Required workflow skills:**
- **specai:specai-using-git-worktrees** - Ensures isolated workspace (creates one or verifies existing)
- **specai:specai-writing-plans** - Creates the plan this skill executes
- **specai:specai-finishing-a-development-branch** - Complete development only after explicit user acceptance at Gate UA
