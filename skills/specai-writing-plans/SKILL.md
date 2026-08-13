---
name: specai-writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

## Absolute Gates (INQUEBRANTABLE)

| Gate | What MUST happen | PROHIBITED actions |
|------|-----------------|-------------------|
| **Gate P1: Spec is Clean** | No ambiguity markers remain. Spec has been user-reviewed and approved. | Creating plan from ambiguous or unreviewed spec. |
| **Gate P2: Branch Timing** | La rama NO DEBE crearse antes de aprobar la PRD y elegir implementar. | Crear una rama durante la exploración, antes de aprobar la PRD o al guardar en backlog. |
| **Gate P2.5: Dependencies Audited** | All new packages/dependencies are listed, verified for legitimacy, and mapped to human checkpoints. | Adding installation tasks for new dependencies without verifying their legitimacy and adding human verification checkpoints. |
| **Gate P3: All Files Created (IMPRESCINDIBLE)** | `<spec-name>-prd.md`, `<spec-name>-spec.md`, `<spec-name>-designs.md`, `<spec-name>-plan.md`, `<spec-name>-tasks.md`, and `<spec-name>-verify.md` all exist with complete content. These six files are MANDATORY — no implementation can begin without them. | Proceeding to execution with missing or placeholder-filled files. |
| **Gate P4: Self-Review Passes** | No placeholders ("TBD", "TODO", "implement later"), spec coverage complete, type consistency verified. | Handing off plan to implementer with gaps or inconsistencies. |
| **Gate P5: User Approves Plan** | User explicitly says "yes" or "proceed" to the plan and task list. | Starting execution or dispatching implementers without user approval. |

## Document Set

Full and Mini modes produce a single folder under `docs/specai/<spec-name>/` (e.g. `docs/specai/20260528-sistema-hibrido-generacion-puzzles/`) containing exactly these six artifacts, all with the same `<spec-name>` prefix:

- `<spec-name>-prd.md` — The approved product requirements document.
- `<spec-name>-spec.md` — The functional contract and delta against the affected project spec.
- `<spec-name>-designs.md` — Populated from brainstorming designs.
- `<spec-name>-plan.md` — The implementation plan with constraints, architectural notes, and execution log.
- `<spec-name>-tasks.md` — The atomic task list (2-5 min each).
- `<spec-name>-verify.md` — Criterios de aceptación globales y plantilla de verificación final. Acceptance criteria live ONLY here, never in `_plan.md`.

Create the six artifacts in this directory. Do not use flat subdirectories like `plans` or `specs`.

Mini mode uses the same six artifacts in a compact form: `prd.md`, `spec.md`, `designs.md`, `plan.md`, `tasks.md`, and `verify.md`. Compactness reduces explanation density and ceremony only; it does not remove task fields, global Given/When/Then criteria, evidence, corrective loop, branch gate, or user-acceptance gate.

## Branch Creation (after PRD approval and execution choice)

**ABSOLUTELY MANDATORY in both modes: Exploration, the approved PRD, and all six living documents are created before the feature branch. Create the feature branch only after the user chooses implementation.**

Exploration, the PRD, and all six living documents are created without a feature branch. La rama NO DEBE crearse antes de aprobar la PRD y elegir implementar. The same implementation-choice gate applies in both modes.

Only after the user chooses **Start implementation now** may the implementation branch be created:

```bash
# Get repo name
basename $(git remote get-url origin) .git

# Create branch
git checkout -b feature/<reponame>_<slug>
```

The six living documents remain in `docs/specai/<spec-name>/` and implementation proceeds on `feature/<reponame>_<slug>` only after that choice.

If the user chooses **Save to Backlog**, keep the feature folder, update its status and backlog projection, and exit without creating a branch. Guardar una feature en backlog NO DEBE crear una rama.

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `specai:specai-using-git-worktrees` skill at execution time.

**Pre-condition:** If the spec has ambiguity markers (see `specai-socratic-clarifier`),
run the clarifier first. This skill assumes the spec is unambiguous. Ambiguous specs
produce ambiguous plans, which produce costly rework.

**Save plans to the active feature folder:**
- `docs/specai/<spec-name>/<spec-name>-prd.md` — Approved product requirements document
- `docs/specai/<spec-name>/<spec-name>-spec.md` — Functional contract and delta against the affected project spec
- `docs/specai/<spec-name>/<spec-name>-designs.md` — Design alternatives and decisions
- `docs/specai/<spec-name>/<spec-name>-plan.md` — Implementation plan with constraints, architectural notes, and execution log
- `docs/specai/<spec-name>/<spec-name>-tasks.md` — Atomic task list
- `docs/specai/<spec-name>/<spec-name>-verify.md` — Criterios de aceptación globales y plantilla de verificación final. This is the single source of truth for acceptance criteria.

All files use the exact same `<spec-name>` base name (which is the directory name) and are living documents updated as progress is made.

- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## Dependency Validation

If the plan introduces any new external library, package, or dependency (e.g., via `npm`, `pip`, `cargo`, `gem`, etc.) that is not already in the project dependencies, you MUST run a validation check:
1. **Check project dependencies**: Verify if the package is already listed in the project's dependency manifest (e.g., `package.json`, `requirements.txt`).
2. **Registry & Reputation Verification**: Look up the package's registry page (like npmjs.com or pypi.org) to check its age, download counts, and repository health. Look for indicators of typosquatting or low reputation.
3. **Plan documentation**: List all new packages in the `## Dependency & Package Validation` section of `<spec-name>-plan.md`.
4. **Human Verification Checkpoint**: Any installation of a new/unverified package MUST have an explicit `checkpoint:human-verify` task/step in `<spec-name>-tasks.md` before the actual installation is executed.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity & Horizontal Layers

**Cada tarea debe ser ultra-granular (3 a 5 minutos) y organizarse de manera horizontal (ej. Base de Datos, API, UI de manera separada):**
- Cada paso de código debe especificar explícitamente su **costura de verificación (seam)**: la interfaz pública, endpoint, o método exacto donde se observará y probará el comportamiento, junto con el comando de prueba correspondiente.
- El plan debe guiar la ejecución de forma incremental paso a paso:
  - "Escribir el test para el componente/endpoint X" - paso
  - "Verificar que el test falla" - paso
  - "Implementar el cambio horizontal en X" - paso
  - "Verificar que el test pasa" - paso
  - "Commit" - paso

## Concrete task contract (mandatory)

Una tarea no es ejecutable si solo dice “mejorar la legibilidad”, “ajustar
estilos”, “actualizar el método” o “añadir validaciones”. Cada tarea que
modifique código debe incluir un bloque `**Implementation Contract:**` con
estos cinco campos:

```markdown
**Implementation Contract:**
- **Target:** `.quiz-question` / `QuizRenderer.render()` / `parse_answer()`
- **Location:** `path/to/file.ext`, regla, clase o método exacto
- **Current:** `font-size: 45px`
- **Change:** `font-size: 45px` -> `font-size: 64px`
- **Assertion:** `test_quiz_question_font_size_is_64px`
```

`Target` y `Location` identifican el selector, clase, función o método exacto
en backticks. `Current` y `Change` contienen los literales antes y después;
no se permite sustituirlos por “más grande”, “legible” o “adecuado”. Una tarea
solo de verificación usa `Current: N/A — ...` y
`Change: N/A — verification-only; ...`, pero debe indicar el artefacto exacto
y su aserción observable. Los pasos deben incluir un comando `Run:` exacto y
un `Expected:` concreto.

Antes de guardar `<spec-name>-tasks.md`, el controlador debe ejecutar:

```bash
python3 scripts/validate-task-contract.py docs/specai/<spec-name>/<spec-name>-tasks.md
```

Si falla, la documentación no está terminada: el documentador debe corregir
la tarea con los símbolos y valores concretos antes de continuar.

## Goal verification contract (mandatory)

`<spec-name>-verify.md` no es un resumen ni una lista decorativa de tests. Es
el contrato de cierre del objetivo completo. Debe declarar una única
invariante:

```text
GOAL_COMPLETE iff every criterion is PASS, every task is completed, no corrective task is open, and the latest evidence belongs to the current HEAD.
```

Cada criterio global tiene un ID (`C1`, `C2`, ...), se vincula a una o más
tareas (`T1`, `T2`, ...), incluye un comando exacto, un resultado esperado,
evidencia y estado. Cada tarea incluye `**Criteria:**` con los IDs que cubre.
Así se puede detectar tanto una tarea olvidada como una tarea marcada como
terminada sin haber cumplido el objetivo que cubría.

Las tareas y los criterios cumplen dos niveles distintos de prueba:

- **Tarea:** demuestra que un cambio local concreto se ha aplicado y funciona.
- **Criterio global:** demuestra que el resultado completo y sus relaciones
  entre componentes cumplen el objetivo. Nunca se considera PASS por sumar
  casillas de tareas completadas.

Todo criterio debe declarar `Criterion type`, `Invariant` y `Verification seam`.
Los tipos permitidos son `BEHAVIOR`, `ARCHITECTURE`, `INTEGRATION`, `VISUAL`,
`MECHANICAL`, `NONFUNCTIONAL`, `SECURITY` y `DOCUMENTATION`. `Invariant` es la
propiedad que debe permanecer verdadera; `Verification seam` identifica las
clases, componentes, métodos, entrypoints, artefactos o pruebas donde el
verifier puede observarla directamente.

Para una paridad entre pantallas, por ejemplo, el criterio global debe expresar
la relación completa: ambos entrypoints usan el mismo componente de pantalla,
la fuente de datos se adapta por juego y no existen dos layouts duplicados.
Las tareas pueden crear el componente, adaptar los datos y escribir las
pruebas, pero el verifier debe comprobar de nuevo esa relación completa desde
el `Verification seam`.

Todos los criterios usan el mismo escenario obligatorio, incluidos los cambios
mecánicos. Cada criterio debe declarar:

```markdown
- **Given:** estado inicial o artefacto exacto
- **When:** acción, comando o comprobación que se ejecuta
- **Then:** resultado observable exacto; en cambios mecánicos debe incluir el literal objetivo
```

Para un cambio mecánico, por ejemplo, `Then` debe decir que la regla contiene
`font-size: 64px`; no puede decir solamente “el texto es más grande”. Para un
flujo, `Given` describe el estado inicial, `When` la acción y `Then` el
resultado verificable. No existen criterios sin escenario ni una variante
abreviada para tareas simples.

El verifier no puede devolver `PASS` si existe un criterio `FAIL`, `PARTIAL` o
`UNVERIFIED`, una tarea `pending`/`in_progress`, evidencia de otro `HEAD`, o
una tarea correctiva abierta. Si falla, el controlador delega al documentador
una tarea correctiva con `Corrective Of`, criterio fallido, archivo, símbolo,
valor actual, valor objetivo, comando y resultado esperado; después vuelve a
despachar un implementador con ese handoff concreto. No se entra en Gate UA.

Antes de iniciar implementación, el controlador valida ambos contratos:

```bash
python3 scripts/validate-task-contract.py docs/specai/<spec-name>/<spec-name>-tasks.md
python3 scripts/validate-verification-contract.py docs/specai/<spec-name>/<spec-name>-verify.md --tasks docs/specai/<spec-name>/<spec-name>-tasks.md
```

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use specai:specai-subagent-driven-development (recommended) or specai:specai-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Status:** [ 🟢 BACKLOG | 🟡 IN PROGRESS | 🔵 VERIFYING | ✅ DONE ]

---
```

## Complexity and Risk Assessment

For every task defined in the plan, you MUST explicitly evaluate and document:
1. **Complexity:** An integer score from 1 (trivial/mechanical changes) to 10 (complex core logic modifications or deep architectural shifts).
2. **Risk:** A rating of `Low`, `Medium`, or `High` regression risk.
3. **Checkpoint:** Yes/No. 
   * **Rule:** `Checkpoint: Yes` is only a human approval checkpoint for the task. If `Complexity >= 7` or `Risk` is `High`, you MUST set `Checkpoint: Yes` and add an explicit human approval step as the first step of the task; it never serializes session state.

## Research Context Persistence

For tasks that require specific knowledge discovered during brainstorming or exploration (such as exact APIs, web documentation, structural rules, or code snippets), you MUST provide a `**Research & Context:**` block to prevent stateless subagents from losing context.

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Control Metadata:**
- Complexity: [1-10]
- Risk: [Low | Medium | High]
- Checkpoint: [Yes | No]

**Research & Context:**
- [Optional: Relevant API models, documentation links, or code examples needed for this task]

**Implementation Contract:**
- **Target:** `exact selector, class, function, or method`
- **Location:** `exact/path/to/file.ext`, exact rule/class/method
- **Current:** `literal current value` or `N/A — explicit reason`
- **Change:** `literal current value` -> `literal target value`
- **Assertion:** `exact test name, selector assertion, or command output`

- [ ] **Step 1: Checkpoint: Human Approval** (MANDATORY if Checkpoint: Yes)
  - Pause execution and seek explicit confirmation from the developer to proceed.

- [ ] **Step 2: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 4: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## Task State Contract

Task blocks use these exact wire states: `pending`, `in_progress`, and `completed`. The visible label for `in_progress` is `in progress`. Every task block includes:

```markdown
**Status:** pending
**Completed:** [ ]
```

When a task starts, change only `Status` to `in_progress`. When build/tests and review are approved, change `Status` to `completed` and `Completed` to `[x]`. Internal steps are not live tracking and remain unmarked. Only `specai-documentation` updates task state and the final check in living documents.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

After saving all six files, ask the user if they want to start the implementation or save it to backlog and exit:

> "Plan, tasks checklist, and verification template complete and saved to `docs/specai/<spec-name>/`.
> 
> How would you like to proceed?
> 1. **Start implementation now:**
>    - Approve the PRD and then create `feature/<reponame>_<slug>`.
>    - Choose execution engine:
>      - **Subagent-Driven:** Use specai:specai-subagent-driven-development
>      - **Inline Execution:** Use specai:specai-executing-plans
> 2. **Save to Backlog and exit:**
>    - Set `Status` to `🟢 BACKLOG` in the plan file.
>    - Ask the user: "Priority for this task? [high/medium/low] (default: medium)"
>    - Update the backlog projection with the Feature ID, folder, status, and priority.
>    - Guardar una feature en backlog NO DEBE crear una rama.
>    - Do not commit, merge, pull, delete branches, or perform any other Git action; Git remains exclusively for authorized finish.
>    - Exit the current feature session and reset all context variables so the next `/specai-new` command starts fresh."

If the user chooses option 2, execute the following steps in order:

1. Update the plan file's `Status` to `🟢 BACKLOG`.
2. Ask the user: "Priority for this task? [high/medium/low] (default: medium)"
3. Update the backlog projection with the Feature ID, folder, status, and priority.
4. Exit the current feature session. Do not create a branch or perform any commit, merge, pull, branch deletion, or other Git action; Git remains exclusively for authorized finish.

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use specai:specai-subagent-driven-development
- The skill reads the `_tasks.md` file and dispatches one implementer per task
- The documenter subagent updates both files as work progresses
- The build-fixer subagent handles compilation errors
- The verifier subagent checks the final result against acceptance criteria
- Each task is committed when build passes

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use specai:specai-executing-plans
- Batch execution with documentary recovery and review gates

## Plan File Templates

### `<spec-name>-plan.md` Template

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use specai:specai-subagent-driven-development
> This plan has six artifacts: the PRD (`<spec-name>-prd.md`), spec (`<spec-name>-spec.md`), designs (`<spec-name>-designs.md`), plan (`<spec-name>-plan.md`), tasks list (`<spec-name>-tasks.md`), and verification report (`<spec-name>-verify.md`).
> Acceptance criteria live ONLY in `<spec-name>-verify.md` — never duplicate them here.
> The documenter subagent updates all files during execution.

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies/libraries]
**Status:** [ 🟢 BACKLOG | 🟡 IN PROGRESS | 🔵 VERIFYING | ✅ DONE ]

---

## Dependency & Package Validation

List any new external packages/libraries introduced by this plan, their source, and verification status:
- [ ] <package_name> (Source: <e.g., npm/PyPI>, Version: <version>, Status: <Approved | Pending Human Checkpoint>)

## Constraints & Guardrails

- <constraint that applies to the whole implementation>
- <e.g. "Do not break public API", "Must work offline">

## Architectural Notes

<Design decisions that the implementer must respect across tasks. Anything that
is not obvious from individual tasks but constrains the implementation.>

## Delta

> If this plan changes any **system-level** behaviour documented under `docs/specai/project/<spec>.md`, list the changes here. After successful implementation, the documenter MUST update the affected specs. This block is what makes feature-level changes traceable to system-level specs.
>
> Pattern borrowed from OpenSpec's `ADDED / MODIFIED / REMOVED Requirements` block. See `docs/COMPARISON.md`.

```
### ADDED Requirements
- (none, OR list which system-level requirements this plan adds)

### MODIFIED Requirements
- docs/specai/project/<spec>.md#<requirement-id>: <one-line description of change>

### REMOVED Requirements
- (none, OR list which system-level requirements this plan removes)
```

If the plan only changes feature-level behaviour (its own designs.md, plans.md, etc.), write:

```
### ADDED Requirements
- (no system-level changes)

### MODIFIED Requirements
- (no system-level changes)

### REMOVED Requirements
- (no system-level changes)
```

## Execution Log

_Living record, updated by the documenter subagent. Do not edit by hand._

<!-- Documenter appends entries here, format:
### [<ISO date> <ISO time>] Task <N>: <title>
**Done:** ...
**Why:** ...
**Outcome:** ✅ success | ❌ failed
**Problems & fixes:** ...
-->
```

### `<spec-name>-verify.md` Template

```markdown
# [Feature Name] — Verification Contract

**Goal ID:** `G-feature-goal`
**Goal:** [Una frase que describe el resultado completo observable]
**Goal completion invariant:** `GOAL_COMPLETE` iff every criterion is `PASS`, every task is `completed`, no corrective task is open, and the latest evidence belongs to the current `HEAD`.
**Status:** `OPEN`

## Acceptance Criteria

### C1 — [Resultado verificable]
- **Requirement:** [Comportamiento o valor exacto]
- **Criterion type:** `BEHAVIOR` | `ARCHITECTURE` | `INTEGRATION` | `VISUAL` | `MECHANICAL` | `NONFUNCTIONAL` | `SECURITY` | `DOCUMENTATION`
- **Invariant:** [Propiedad completa que debe permanecer verdadera]
- **Verification seam:** [Clases, componentes, métodos, entrypoints, artefactos o pruebas exactos]
- **Given:** [Estado inicial o artefacto exacto]
- **When:** [Acción, comando o comprobación exacta]
- **Then:** [Resultado observable exacto; incluir literales para cambios mecánicos]
- **Tasks:** `T1`
- **Verification command:** `exact command`
- **Expected:** `exact output or assertion`
- **Evidence:** `PENDING`
- **Status:** `PENDING`

## Coverage Matrix

| Criterion | Task IDs | Verification command | Status |
|---|---|---|---|
| `C1` | `T1` | `exact command` | `PENDING` |

## Verification State

- **Verifier verdict:** `NOT_RUN`
- **Last verified HEAD:** `PENDING`
- **Open failures:** `none`
- **Corrective loop:** `none`
```

### `<spec-name>-tasks.md` Template

```markdown
# [Feature Name] — Task List

> **For agentic workers:** Read this file once, then dispatch one implementer per task with minimal context.
> Tasks are atomic (2-5 min). Do not bundle tasks. Do not skip the order.

## Task 1: [Component name]

**Files:**
- Create: `path/to/file.py`
- Modify: `path/to/existing.py:123-145`
- Test: `tests/path/to/test.py`

**Criteria:** `C1`, `C2`

**Control Metadata:**
- Complexity: [1-10]
- Risk: [Low | Medium | High]
- Checkpoint: [Yes | No]

**Research & Context:**
- [Optional: Snippets, APIs, or doc links from brainstorming/exploration]

**Implementation Contract:**
- **Target:** `exact selector, class, function, or method`
- **Location:** `exact/path/to/file.ext`, exact rule/class/method
- **Current:** `literal current value` or `N/A — explicit reason`
- **Change:** `literal current value` -> `literal target value`
- **Assertion:** `exact test name, selector assertion, or command output`

**Spec context (minimal):**
<paste only the section of the design spec that this task needs>

**Acceptance for this task:**
- [ ] `<Assertion>` is observable in the named test or command output.
- [ ] Only the listed target and exact change are modified.

**Steps:**

- [ ] **Step 1: Checkpoint: Human Approval** (MANDATORY if Checkpoint: Yes)
  - Pause execution and seek explicit confirmation from the developer to proceed.
- [ ] **Step 2: Write the failing test**

```python
def test_specific_behavior():
    ...
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL

- [ ] **Step 4: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

---

## Task N: [Package Installation Component]

**Files:**
- Modify: `package.json`

**Criteria:** `C1`

**Implementation Contract:**
- **Target:** `dependencies.<package>`
- **Location:** `package.json`, `dependencies` object
- **Current:** `package absent` or `N/A — package already present`
- **Change:** `package absent` -> `package@<approved-version>`
- **Assertion:** `package.json` contains the approved version and the package manager verifies it

**Spec context (minimal):**
<relevant spec context>

**Acceptance for this task:**
- [ ] Package `<package>` is installed and verified.

**Steps:**

- [ ] **Step 1: Human Verification Checkpoint for package: <package>**
  - Check the package details, age, download counts, and repository legitimacy.
  - If approved, proceed; otherwise, seek alternatives or stop.
- [ ] **Step 2: Install package**
  Run: `npm install <package>` (or python equivalent)
- [ ] **Step 3: Commit**

---

## Task N+1: ...


(repeat for each atomic task)
```
