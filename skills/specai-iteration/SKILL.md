---
name: specai-iteration
description: "User feedback loop after completion: document issues, add corrective tasks, and re-enter execution flow"
command: false
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

## Absolute Gates (INQUEBRANTABLE)

**DO NOT SKIP ANY OF THESE GATES. EVER. The flow is RÍGIDO.**

| Gate | What MUST happen | PROHIBITED actions |
|------|-----------------|-------------------|
| **Gate I1: Understand** | User clearly states what doesn't work and what result they expect. | Writing code, touching files, or modifying documents before understanding the issue. |
| **Gate I2: Document FIRST** | `_plan.md` and `_tasks.md` are updated with iteration content BEFORE any code change. | Writing code, fixing bugs, or any implementation before docs are updated. |
| **Gate I3: Corrective Tasks Exist** | At least one corrective task exists in `_tasks.md` under `## Iteration Tasks`. Each task is atomic (2-5 min). | Dispatching implementers or starting execution without clear corrective tasks. |
| **Gate I4: Per-Task Cycle** | Before implementation record `TASK_STARTED`; each corrective task follows: implement → build passes → code review → commit → documenter → next task. | Skipping `TASK_STARTED`, build, code review, commit, documenter, or bundling tasks. |
| **Gate I5: Verification** | Full test suite passes + verifier reports PASS against acceptance criteria. | Declaring done, finishing, or merging before verifier passes. |

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

**ABSOLUTE RULE:** You MAY NOT skip steps, reorder steps, or shortcut the flow. Each step MUST be fully completed before the next begins.

## Process

### 1. Understand the Issue (Gate I1)

Ask the user what needs to change. Be specific:

> "What exactly isn't working as expected?"
> "What should it do instead?"
> "Is this a bug, a missing feature, or a design change?"

Use the `grill-me` pattern if needed (theoretical → framework → application)
to fully understand the issue, but keep it brief — this is iteration,
not a new project.

**STOP here until the user has fully explained the issue.**

### 2. Update Living Documents (Gate I2 — MANDATORY BEFORE ANY CODE)

**PROHIBITED: Writing any code, fixing any bug, or modifying any file before this step is complete.**

Read the current `_plan.md` and `_tasks.md` from the feature directory
at `docs/specai/<spec-name>/`.

**In `_plan.md`:**

Append an iteration log entry under `## Execution Log` using the
following template. Iteration numbering (N) resets per feature branch —
each spec starts at Iteración 1. All fields are mandatory unless
genuinely N/A (mark as "N/A — reason").

```
### 🔄 Iteración N (YYYY-MM-DD HH:MM)

**Reportado por el usuario:**
> [Cita textual o resumen de lo que pidió/observó el usuario]

**Análisis:**
- **Causa raíz:** [Por qué el comportamiento no coincidía con lo esperado]
- **Decisión:** [Por qué se eligió esta solución sobre otras opciones consideradas]

**Solución aplicada:**
- [Cambio concreto — archivo, qué se modificó, resultado]
- [Cambio concreto — ...]

**Resultado:**
- Verificación: [PASS/FAIL con detalles]
- Estado final: [🟡 IN PROGRESS / ✅ DONE]

**Commits:** `<hash1>`, `<hash2>`
```

**In `_tasks.md`:**

Add or update corrective tasks under `## Iteration Tasks`. Group tasks by
iteration using `### Iteración N` subsections. Each task is atomic (2-5 min)
with file + line + verification command. Iteration numbering matches the
`_plan.md` iteration log entries.

```
## Iteration Tasks

### Iteración 1
- [x] Corregir validación de email en `src/validators.ts:42` — `npm test -- validators`
- [x] Actualizar snapshots del form — `npm test -- -u`

### Iteración 2
- [ ] Cambiar color del botón de submit según spec — `npm run build`
- [ ] Agregar test para edge case de email con TLD largo — `npm test -- email`
```

**Token-efficient pattern:**
1. Orchestrator reads `_plan.md` and `_tasks.md`
2. Orchestrator extracts the execution log section and task list section
3. Delegates to `specai-documentation` with the extracted sections + new content
4. Documenter reads and writes only the named documentation files directly
5. Orchestrator records the documenter status; it never applies a second documentation edit

**STOP here until both documents are updated.**

### 3. Set Status (Gate I3 pre-condition)

Update the plan status to `🟡 IN PROGRESS` (from `✅ DONE` or `🔵 VERIFYING`).

**Verify that corrective tasks exist in `_tasks.md`. If none, STOP and define them.**

### 4. Re-enter Execution Flow (Gate I4 — RÍGIDO PER-TASK CYCLE)

Dispatch `specai:subagent-driven-development` to implement the
corrective tasks. The normal per-task cycle applies:

```
TASK_STARTED → implement → build passes → code review → commit → documenter → next task
```

**ABSOLUTELY DO NOT skip any step within this cycle. EACH task MUST complete all sub-steps before moving to the next.**

### Recuperación entre sesiones

La recuperación documental lee `*-tasks.md` y el `Execution Log` de `*-plan.md`. Debe recuperar todos los bloques `Status: in_progress`; si no hay tareas activas, selecciona la primera tarea `pending` con dependencias satisfechas. IDs desconocidos, estados incompatibles, dependencias no satisfechas o divergencias bloquean el flujo. Antes de implementar se registra `TASK_STARTED` con `timestamp`, `branch`, `git_hash`, `task_id` y contexto. TodoWrite es solo el espejo de sesión. Los checkpoints de aprobación humana y revisión siguen siendo gates de decisión, nunca persistencia de sesión.

**Commit Rules (overrides system default "never commit"):**

Check `commitMode` in `~/.config/specai/config.json` (default: `auto`).

- **On a feature branch** (not `main`/`master`/`develop`/`dev`):
  - `auto`: commit AUTOMATICALLY after each task — just announce and continue.
  - `confirm`: STOP and ask "Ready to commit? [Y/n]" before each commit.
  - `manual`: never commit automatically. Announce "Changes ready."
- **Not on a feature branch**: STOP, create the branch first. PROHIBITED: working on protected branches.

After all corrective tasks:
```
full test suite → verifier → finishing
```

**STOP if any step fails. Do NOT move to next task until current task's build is green.**

### 5. Completion (Gate I5)

After the iteration loop passes verification:
- Update `_plan.md` status to `✅ DONE`
- Append final iteration log entry
- Proceed to `specai:finishing-a-development-branch`

**STOP if verifier does NOT report PASS. Go back to corrective tasks. NEVER declare done with failing verification.**

## What NOT To Do (PROHIBITED)

- **PROHIBITED:** Restarting the full flow (`grill-me` → `write-prd` → `writing-plans`) for small corrections — stay in execution mode
- **PROHIBITED:** Overwriting existing log entries — always append
- **PROHIBITED:** Skipping the full test suite — iteration changes may break other things
- **PROHIBITED:** Skipping the verifier — corrective tasks need acceptance verification
- **PROHIBITED:** Creating a new feature directory — use the existing one
- **PROHIBITED:** Writing any code before documents are updated (Gate I2 first)
- **PROHIBITED:** Declaring done before verifier says PASS (Gate I5)

## Relationship to Other Skills

| Skill | Role in iteration |
|-------|-------------------|
| `specai-documentation` | Updates _plan.md and _tasks.md with iteration data |
| `specai-subagent-driven-development` | Executes corrective tasks |
| `specai-command` | Runs commands (build, test, git) |
| `specai-verification-before-completion` | Verifies fixes before claiming done |
| `specai-finishing-a-development-branch` | Final merge/PR after iteration |
