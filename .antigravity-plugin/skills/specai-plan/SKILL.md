---
name: specai-plan
description: "Execute the canonical SpecAI flow: grounding → grill-me → write-prd → approval → six documents → choose implement/backlog → branch only if implement → per-task cycle → spec-compliance-reviewer → verifier → Gate UA → finishing"
---

# specai-plan — Flujo SpecAI canónico

Execute the complete workflow for a new feature. **Do NOT write code or living documentation until the PRD and plan are approved.**

`grounding → grill-me → write-prd → approval → six documents → choose implement/backlog → branch only if implement → per-task cycle → spec-compliance-reviewer → verifier → Gate UA → finishing`

## Iron Rule

Every step MUST be followed. No skipping, no reordering, no "this is simple enough."

**Crucial Override:** When executing this skill, ignore any native, platform, or system planning flow (such as native IDE/agent `implementation_plan.md` or task workflows). Execute ONLY this specai planning workflow.

## Flujo

1. **Grounding:** inspeccionar código, configuración y entrypoints antes de preguntar.
2. **Grill-me:** cargar `specai-grill-me` y preguntar una cuestión cada vez cuando el código no dé la respuesta.
3. **Write PRD:** cargar `specai-write-prd` y obtener aprobación del PRD.
4. **Six documents:** crear la PRD aprobada y los otros cinco documentos sin rama.
5. **Elección y branch:** elegir implementar o guardar en backlog; guardar en backlog conserva la carpeta y no crea rama. Crear `feature/<reponame>_<feature-slug>` solo si el usuario elige implementar.
6. **Per-task cycle:** registrar `TASK_STARTED` → implementar → build/test → code review → commit → documentar por tarea.
7. **Spec-compliance-reviewer:** revisar el cumplimiento tras todas las tareas.
8. **Verifier:** verificar contra `_verify.md`, única fuente de aceptación.
9. **Gate UA:** pedir pruebas y aceptación explícita del usuario antes de finalizar.
10. **Finishing:** cargar `specai-finishing-a-development-branch` solo tras la aceptación.

## Estados y ownership

- Estados de tarea: `pending`, `in_progress`, `completed`; solo el estado y el check final `Completed` se actualizan durante la ejecución.
- Los pasos internos no se marcan como seguimiento vivo.
- El controlador es dueño del todo; `specai-documentation` es dueño de estados, checks y logs documentales.
- El implementador no escribe documentación y `specai-command` ejecuta comandos.
- Varias tareas solo pueden estar `in_progress` con workspaces y archivos aislados; commits y documentación son seriales. TodoWrite es solo el espejo de sesión.

## Recuperación documental

Antes de implementar se registra `TASK_STARTED` en el `Execution Log` con `timestamp`, `branch`, `git_hash`, `task_id` y contexto. Entre sesiones, la recuperación lee los estados `in_progress` de `*-tasks.md` y su `Execution Log` en `*-plan.md`, recupera todos los activos o selecciona la primera tarea `pending` con dependencias satisfechas cuando no hay activos. IDs desconocidos, estados incompatibles, dependencias no satisfechas o divergencias bloquean el flujo. Los checkpoints de aprobación humana o revisión siguen siendo gates de decisión y no persistencia de sesión.

Si el usuario reporta problemas tras la aceptación, cargar `specai-iteration`, documentar el feedback y reentrar en el ciclo.
