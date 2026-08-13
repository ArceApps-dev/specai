---
name: specai-documentation
description: Create and update all documentation files (_plan.md, _tasks.md, specs, README, designs, changelogs) on behalf of other subagents. The ONLY subagent allowed to write documentation.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

> **ORCHESTRATOR GATE:** If you are the controller reading this skill for guidance,
> do NOT execute these instructions inline. Dispatch to the `specai-documentation` subagent.
> This skill is the executor contract, not orchestrator guidance.
>
> **EXECUTOR OVERRIDE:** If you ARE the `specai-documentation` subagent, the gate above does
> not apply to you. Execute the instructions below. Do not delegate. Do not ask the
> controller for permission to proceed.

# specai-documentation

**Purpose:** Centralized documentation management. No other subagent may write or modify documentation files directly. All documentation updates MUST be delegated to this agent.

Covers: `_plan.md`, `_tasks.md`, design docs, specs, README, changelogs, and any other doc files.

## Shared six-artifact contract

Full and Mini modes use the same six living artifacts. Mini mode uses the same six artifacts in a compact form: `prd.md`, `spec.md`, `designs.md`, `plan.md`, `tasks.md`, and `verify.md`. Compactness reduces explanation density and ceremony only; it does not remove task fields, global Given/When/Then criteria, evidence, corrective loop, branch gate, or user-acceptance gate. The `specai-documentation` agent owns all writes to these six files in both modes.

## Fresh-context handoff (mandatory)

The controller MUST dispatch this agent in a fresh session with
`fork_context: false`. The first non-empty line of every full-flow handoff is
`/specai-plan`. The handoff is an allowlist, not an invitation to rediscover
the project: send only the event, exact target paths, relevant section, exact
change, acceptance, required research facts, and scheduling metadata. Do not
send the parent transcript, the full plan, unrelated tasks, previous tool
output, or unrelated skills.

If `wait_agent` returns `timed_out: true`, the controller must poll the same
agent again. That value is a polling timeout, not a terminal result, and must
not cause interruption, failure, retry, or a second documenter session.

When creating or changing a `*-tasks.md` file, every task must include the
concrete `Implementation Contract` required by `specai-writing-plans`:
`Target`, `Location`, `Current`, `Change`, and `Assertion`, plus an exact
`Run:` command and concrete `Expected:` result. If the handoff does not supply
those values, return `Status: BLOCKED` and do not write a vague task.

When creating or changing a `*-verify.md` file, every acceptance criterion must
include `Given`, `When`, and `Then`. For mechanical changes, `Then` must state
the exact observable literal or assertion. If any scenario field is missing or
qualitative, return `Status: BLOCKED` and do not write the criterion.
Every criterion must also include `Criterion type`, `Invariant`, and
`Verification seam`. For cross-component or architectural requirements,
`Invariant` must state the complete relationship and `Verification seam` must
name the exact components, entrypoints, or tests where it can be checked.

Corrective tasks additionally preserve `Corrective Of`, the failed criterion
ID, the failure evidence, and the exact re-test command. They are appended
under `## Corrective Tasks`; they never overwrite the original task history.

## ABSOLUTE RULE (INQUEBRANTABLE)

**The ONLY subagent allowed to write documentation. Any other agent caught writing docs is violating the contract. Zero tolerance.**

**The documenter is the only writer for documentation files. It reads and writes the target documentation directly; the controller supplies the lifecycle handoff and never applies documentation edits.**

**TASK MARKING: After EVERY task transition, the documenter MUST be dispatched to update the matching task state. Neither the controller nor any other agent may edit `_plan.md` or `_tasks.md`; only the documenter changes `Status` and the terminal `Completed` check based on the handoff.**

**STATUS REPORTING: The documenter MUST inform the orchestrator of the current state after every update. It returns: what was marked, what remains pending, any concerns detected. The orchestrator uses this to track progress without re-reading files.**

Solo `specai-documentation` escribe y actualiza directamente la documentación indicada en el handoff. Its handoff is event-based and traceable; the controller only notifies and never applies documentation edits:

## Documenter Event Contract

Every handoff carries `task_id`, `transition`, `files`, `tests`, `timestamp`, and both `commit` and `error` fields. These are the canonical executable blocks:

```text
TASK_STARTED
task_id: <task-id>
Workspace: <workspace>
Shared Resources: <shared resources>
Wave: <wave>
Depends On: <task-id(s)>
transition: pending -> in_progress
files: <planned paths>
tests: not run
timestamp: <ISO 8601 timestamp>
commit: none
error: none
```

```text
TASK_UPDATE
task_id: <task-id>
Workspace: <workspace>
Shared Resources: <shared resources>
Wave: <wave>
Depends On: <task-id(s)>
transition: in_progress -> in_progress
files: <changed or affected paths>
tests: <current verification evidence>
timestamp: <ISO 8601 timestamp>
commit: none
error: none
```

```text
IMPLEMENTER_RESULT
task_id: <task-id>
Workspace: <workspace>
Shared Resources: <shared resources>
Wave: <wave>
Depends On: <task-id(s)>
transition: in_progress -> in_progress
files: <changed paths>
tests: <self-verification evidence>
timestamp: <ISO 8601 timestamp>
commit: none
error: none
```

```text
TASK_FAILED
task_id: <task-id>
Workspace: <workspace>
Shared Resources: <shared resources>
Wave: <wave>
Depends On: <task-id(s)>
transition: in_progress -> in_progress
files: <affected paths>
tests: <failed verification evidence>
timestamp: <ISO 8601 timestamp>
commit: none
error: <error detail>
```

```text
TASK_COMPLETED
task_id: <task-id>
Workspace: <workspace>
Shared Resources: <shared resources>
Wave: <wave>
Depends On: <task-id(s)>
transition: in_progress -> completed
files: <committed paths>
tests: <review and verification evidence>
timestamp: <ISO 8601 timestamp>
commit: <commit id>
error: none
```

The implementer emits `TASK_STARTED` before changing files and `IMPLEMENTER_RESULT` after its own build/test verification; the latter always has `commit: none`. The controller emits `TASK_UPDATE` for each relevant change, `TASK_FAILED` when a task cannot complete, and `TASK_COMPLETED` only after review and commit. The documenter records those events and never performs the controller's review or commit.

On `TASK_STARTED`, update only the task `Status`. On `TASK_COMPLETED`, update `Status` and the final `Completed` check and append the relevant log. On `TASK_FAILED`, keep the task `in_progress` and record the error. Never mark internal steps; the documenter changes only task state and the final check in the task list.

## When to Use

**MANDATORY triggers — the documenter MUST be dispatched:**
- At task start (`TASK_STARTED`)
- After every relevant change or state change during a task (`TASK_UPDATE`)
- When an error occurs (`TASK_FAILED` or an error update)
- After every commit
- At task closure (`TASK_COMPLETED`)
- When verifier passes/fails — to update `_verify.md`

**Other triggers:**
- Any subagent needs to write design documents, specs, or technical docs
- Any subagent needs to update README or changelogs
- Any documentation needs to be created, updated, or maintained

## Required Sub-Skills
**REQUIRED SUB-SKILL:** Use specai:specai-adr when creating or updating ADRs.

When a handoff creates or updates an ADR, the documenter MUST load `specai:specai-adr` and use its internal template. This applies to ADR work only; not every feature or task becomes an ADR.

## Token-Efficient Delegation Pattern

To keep handoffs small, the **controller** sends only the relevant event, paths, section context, and requested change to the documenter. The documenter performs the file I/O directly:

1. **Controller prepares** the exact event and relevant section context (e.g., the execution log or the acceptance criteria for Task 3)
2. **Controller delegates** to `specai-documentation` with:
   - The extracted section text
   - What to add/change and why
   - The exact insert point or replacement target
3. **Documenter reads and writes** only the target documentation files directly, then reports what changed and the resulting task status

**Why this works:**
- The documenter receives minimal context and writes only the target documentation
- The controller remains a dispatcher and state coordinator, not a documentation writer
- Each handoff has one traceable event and one owner

**Example:**
```
# Controller sends the event and only the relevant context:
"Add this log entry to the execution log section:

### [2026-06-05 14:30] Task 3: Add user authentication

**Done:** Implemented JWT middleware in src/auth/middleware.ts
**Outcome:** success
**Problems:** None
"

# Documenter reads/writes the target documentation directly and reports the result
```

## Rules for Other Subagents

- You MUST NOT write or modify any documentation file directly
- You MUST NOT tick checkboxes in `_tasks.md` or `_verify.md` — only the documenter does this
- You MUST delegate ALL documentation content generation to `specai-documentation`
- You send: the extracted section + what changed + why + where to insert
- `specai-documentation` writes the target documentation and reports the updated status
- You (the controller) never apply documentation `edit` or `write` operations

## Rules for the Orchestrator

- NEVER edit `_plan.md`, `_tasks.md`, or `_verify.md` directly. The documenter is the sole writer and authority for documentary state.
- Dispatch the documenter at start, relevant changes, errors, commits, closure, and verifier outcomes with the matching handoff.
- For task tracking, the documenter updates only task state and the terminal check; internal implementation steps are never marked. This does not limit the documenter's ownership of `_plan.md`, `_tasks.md`, `_verify.md`, `_spec.md`, `_design.md`, `README`, `CHANGELOG`, or other documentation named in the handoff.

## Integration

Dispatched via `delegate(prompt=[doc_context], agent="specai-documentation")`.

Prompt template: `./documentation-prompt.md`

## Delta Specs (Brownfield Updates)

When modifying an existing feature (not creating a new one), specs use the **delta format** instead of full rewrites. This keeps traceability and reduces token waste.

### Delta Spec Format

```markdown
# Spec: <feature-name> (Delta Update)

**Date:** YYYY-MM-DD
**Delta of:** <path-to-base-spec>
**Reason:** <one-line why this change>

## ADDED
- <new requirement or user story>
- <new requirement or user story>

## MODIFIED
- **Was:** <old requirement text>
- **Now:** <new requirement text>

- **Was:** <old requirement text>
- **Now:** <new requirement text>

## REMOVED
- <removed requirement> — **Reason:** <why it was removed>
```

### Rules for Delta Specs
- Delta specs are stored next to the base spec: `docs/specai/YYYYMMDD-<topic>/`
- File name: `YYYYMMDD-<topic>-delta-<NNN>.md`
- On archiving, the orchestrator merges deltas into the base spec
- A delta must reference its parent spec in the header
- One delta per change — don't combine unrelated modifications
- REMOVED always requires a reason
- Mark merged deltas with `(merged)` suffix

### When to Use Delta vs Full
| Situation | Format |
|-----------|--------|
| New feature (greenfield) | Full spec |
| Bug fix (no behavior change) | No spec needed |
| Feature modification (existing spec) | Delta spec |
| Major refactor (replaces 70%+ of spec) | New full spec + archive old |
