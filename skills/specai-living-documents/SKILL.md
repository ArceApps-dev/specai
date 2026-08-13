---
name: specai-living-documents
description: Use when maintaining the six feature documents in both Full and Mini modes during implementation. These files must always reflect current state.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Living Documents

The six feature documents that define a feature in either Full or Mini mode must
stay in sync with reality throughout implementation. Mini mode uses the same six artifacts in a compact form: `prd.md`, `spec.md`, `designs.md`, `plan.md`, `tasks.md`, and `verify.md`. Compactness reduces explanation density and ceremony only; it does not remove task fields, global Given/When/Then criteria, evidence, corrective loop, branch gate, or user-acceptance gate. The `specai-documentation` agent owns all writes to these files.

**IRON RULE: Living documents ALWAYS reflect current reality. Outdated documents = LYING.**

## The six feature documents for both modes

| File | Purpose | Mutability |
|------|---------|------------|
| `<spec-name>-prd.md` | Approved product requirements and scope | Updated only through approved requirement changes |
| `<spec-name>-spec.md` | Functional contract and project-spec delta | Updated when the contract changes |
| `<spec-name>-designs.md` | Architecture decisions, file map, data flow, interfaces | Updated when an approved design decision changes |
| `<spec-name>-plan.md` | Goal, constraints, architectural notes, execution log | Log grows (append-only). No acceptance criteria here — they live in `verify` |
| `<spec-name>-tasks.md` | Atomic task list with checks and dependencies | Tasks tick `[x]` when done and verified |
| `<spec-name>-verify.md` | Global acceptance criteria, evidence, and corrective state | Updated when criteria or verification state changes |

## File Size Targets

Keep each file small. Pass only the relevant section to each agent — not all six.

| File | Target | If exceeded |
|------|--------|-------------|
| `_spec.md` | ≤200 lines | Split by domain: `_spec-auth.md`, `_spec-api.md` |
| `_design.md` | ≤150 lines | Move reference material to a `_design-details.md` |
| `_plan.md` | Criteria ≤50 lines; log unbounded | — |
| `_tasks.md` | ≤30 lines per task | — |

## Update Rules

### Task State Contract

The canonical task-state contract is defined in `skills/specai-writing-plans/SKILL.md`. In living documents, `specai-documentation` owns task-state updates and changes only the task block's `**Status:**` and final `**Completed:** [ ]` or `**Completed:** [x]`; internal step checkboxes remain untouched.

### When a task completes

1. `_tasks.md` — `specai-documentation` changes only the completed task block to `**Status:** completed` and `**Completed:** [x]`; internal step checkboxes remain untouched.
2. `_plan.md` — append an entry to the Execution Log.
3. `_spec.md` — if the task confirmed or added behavior, update the affected requirement.
4. `_design.md` — if the task required a design decision change, update the Decisions Log.

### After EVERY commit

- `_plan.md` — append a commit log entry to the Execution Log noting what was committed and why.
- `_tasks.md` — ensure all completed steps in the committed task are ticked.

### When errors occur (build failures, test failures, bugs)

1. `_plan.md` — append an entry to the Execution Log documenting:
   - What error occurred
   - What caused it (root cause if known)
   - How it was fixed
   - Any lessons learned or decisions made
2. `_tasks.md` — if the error requires new work, add corrective tasks under `## Corrective Tasks`.

### Execution Log entry format

```markdown
### [2026-06-04 17:30] Task 2: Add token validation middleware

**Done:** Created `src/auth/middleware.ts` with `validateJWT()`. Tests: 8/8 pass.
**TDD Evidence:** Safety Net ✅ 3/3 | RED ✅ | TRIANGULATE ✅ 2 cases | REFACTOR ✅
**Outcome:** ✅ success
**Problems & fixes:** None.
```

### Error Log entry format

```markdown
### [2026-06-04 17:45] Error: Build failure in Task 2

**Error:** `ModuleNotFoundError: No module named 'jwt'`
**Cause:** Missing dependency in requirements.txt
**Fix:** Added `PyJWT==2.8.0` to requirements.txt and reinstalled
**Outcome:** ✅ resolved
**Notes:** Need to check if other auth modules have same issue
```

### Iteration Log entry format

When a user reports issues and corrective work is done during a `specai-iteration`
cycle, append an iteration log entry to the execution log:

```markdown
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

Iteration numbering (N) resets per feature branch — each spec starts at Iteración 1.
All fields are mandatory unless genuinely N/A (mark as "N/A — reason").

### When the verifier passes a task

- `_verify.md` — tick `[x]` on the corresponding acceptance criterion.
- `_spec.md` — mark the corresponding requirement as `[verified]`.

### When the verifier fails a task

- Verifier generates corrective tasks.
- Append them to `_tasks.md` under `## Corrective Tasks`.
- Execution log records the failure and what was generated.

## Dispatch Context Per Update

**Never pass full files to the documenter.** The orchestrator sends only the
event, exact target paths, relevant section, and requested change. The
documenter reads and writes the named documentation files directly and reports
the resulting state.

| Update trigger | Controller prepares | Documenter receives and writes |
|----------------|----------------------|-------------------|---------------------|
| Task complete | Event + target paths + relevant sections | Direct update of named docs |
| After commit | Event + target path + commit entry | Direct update of named doc |
| Error occurs | Event + target path + error entry | Direct update of named doc |
| Criterion verified | Event + target path + criterion | Direct update of named doc |
| Spec behavior confirmed | Event + target path + affected section | Direct update of named doc |
| Design decision changed | Event + target path + affected section | Direct update of named doc |

**Rule:** The documenter reads and writes only the named documentation files
directly. The orchestrator never applies a returned documentation patch.
