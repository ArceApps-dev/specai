---
name: specai-plan
description: Execute the canonical full SpecAI flow from grounded definition through user acceptance.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-plan — Flujo SpecAI canónico

Ejecuta el flujo completo y rígido para una nueva funcionalidad:

`grounding → grill-me → write-prd → approval → six documents → choose implement/backlog → branch only if implement → per-task cycle → spec-compliance-reviewer → verifier → Gate UA → finishing`

No se puede saltar, reordenar ni abreviar ninguna fase.

Mini mode uses the same six feature artifacts in a compact form with the shared `<spec-name>` prefix: `<spec-name>-prd.md`, `<spec-name>-spec.md`, `<spec-name>-designs.md`, `<spec-name>-plan.md`, `<spec-name>-tasks.md`, and `<spec-name>-verify.md`. Compactness reduces explanation density and ceremony only; it does not remove task fields, global Given/When/Then criteria, evidence, corrective loop, branch gate, or user-acceptance gate.

## Reglas del flujo

1. **Grounding:** inspeccionar el código, configuración y entrypoints relevantes antes de formular preguntas.
2. **Grill-me:** entrevistar al usuario una pregunta cada vez, solo sobre decisiones que el código no resuelva.
3. **Write PRD:** generar el PRD formal y obtener aprobación antes de planificar.
4. **Writing plans:** crear los seis artefactos vivos: PRD, spec, designs, plan, tasks y verify.
5. **Documentación y elección:** crear los seis documentos vivos sin rama; después elegir implementar o guardar en backlog; crear la rama `feature/<reponame>_<feature-slug>` solo si se elige implementar. La rama de implementación NO DEBE crearse antes de aprobar la PRD y elegir implementar. Guardar una feature en backlog NO DEBE crear una rama.
6. **Per-task cycle:** por cada tarea: registrar `TASK_STARTED` → implementar → build/test → code review → commit → documentar.
7. **Spec-compliance-reviewer:** revisar el cumplimiento completo de la spec después de todas las tareas.
8. **Verifier:** comprobar la implementación contra `_verify.md`, única fuente de criterios de aceptación.
9. **Gate UA:** detenerse y pedir pruebas y aceptación explícita del usuario antes de finalizar.
10. **Finishing:** solo después de `accept` o equivalente, ofrecer merge, PR, conservar o limpiar la rama.

El verifier cierra el objetivo, no solo las tareas: solo puede devolver `PASS`
si la invariante `GOAL_COMPLETE` de `_verify.md` es cierta. Si devuelve
`FAIL`, `PARTIAL` o `UNVERIFIED`, el documentador añade tareas correctivas con
instrucciones concretas y el controlador vuelve a despachar al implementador;
el flujo no entra en Gate UA hasta obtener un `PASS` completo contra el
`HEAD` actual.

Cada criterio de `_verify.md` debe declarar `Criterion type`, `Invariant`,
`Verification seam` y `Given / When / Then`. Las tareas verifican cambios
locales; los criterios verifican el objetivo completo. En criterios
`ARCHITECTURE` o `INTEGRATION`, el `spec-compliance-reviewer` y el verifier
deben comprobar explícitamente la relación entre los componentes en la seam
declarada, sin inferirla de que las tareas estén marcadas como completadas.
Antes de cada commit, el `code-reviewer` debe emitir tanto un veredicto de
calidad como `Compliance verdict: PASS` para las aserciones locales de la
tarea.

## Handoff de agentes y espera

Cuando el flujo despache un subagente, el controlador debe aplicar el contrato
de Codex en `specai-bootstrap/references/codex-tools.md`: crear siempre una
sesión nueva con `fork_context: false`, comenzar el handoff con
`/specai-plan` (o `/specai-mini` en Mini), y enviar únicamente el contexto
mínimo permitido. Nunca se debe heredar la conversación completa ni enviar el
plan entero a un documentador.

Si `wait_agent` devuelve `timed_out: true`, solo ha terminado el intervalo de
espera. El controlador conserva el handle y vuelve a consultar; no interrumpe,
no marca fallo y no relanza el agente. Solo un estado terminal permite cerrar
el handoff.

### Lifecycle acotado de Codex

Antes de `spawn_agent`, el adaptador comprueba que `[features]
multi_agent = true`. Si falta esa capacidad, el handoff termina como
`TASK_BLOCKED` con una acción de reparación; no se ejecuta inline ni se usa un
fallback silencioso. Todo handoff registra `Max Runtime: 900 seconds`,
`Deadline: 900 seconds`, `Heartbeat every 30 seconds` y `Poll interval: 15
seconds`.

Mientras no exista un estado terminal, se conserva el mismo handle. Al vencer
el deadline se solicita la cancelación nativa mediante `cancel_agent`, se
registra `TASK_FAILED` con el motivo `deadline_exceeded` y después se libera el
handle con `close_agent`. Nunca se relanza el trabajo automáticamente ni se
reutiliza contexto heredado.

## Preflight incremental de cobertura

El grounding debe identificar la unidad semántica afectada por la feature y limitar la revisión a ese código, sus entrypoints, pruebas y documentación relacionada. No se debe inventariar todo el repositorio para crear specs globales.

Antes de escribir la PRD, comprobar si existe una spec de proyecto para esa unidad bajo `docs/specai/project/`. Si falta, está obsoleta o contradice el código, informar de la brecha y ofrecer crear o actualizar la spec revisando únicamente el alcance afectado. El documentador crea la spec; el controlador no la fabrica silenciosamente. Si el usuario no acepta documentar esa brecha, el flujo se detiene por falta de fuente de verdad.

`bash scripts/specai-init.sh --scope <ruta-o-unidad>` prepara `docs/specai/project/` de forma idempotente y deja explícito el alcance del preflight; no crea un inventario de carpetas, módulos o archivos del proyecto.

## Estados y ownership

- Cada tarea usa exactamente `pending`, `in_progress` o `completed`.
- El bloque de tarea contiene `**Status:** ...` y un único `**Completed:** [ ]`/`[x]`.
- Al iniciar, solo se cambia `Status` a `in_progress`; al completar, tras build/tests y review, se cambia `Status` a `completed` y `Completed` a `[x]`.
- Los pasos internos no son seguimiento vivo y no se marcan durante la ejecución.
- El controlador es dueño del todo y coordina las transiciones.
- `specai-documentation` es el único dueño de estados, checks y logs en la documentación viva.
- El implementador no escribe documentación; el controlador entrega sus eventos al documentador.
- `specai-command` ejecuta comandos; los commits y la documentación son seriales. El estado de sesión se conserva efímeramente y no se persiste en el checkout.
- Varias tareas pueden estar `in_progress` solo si sus workspaces y archivos de escritura están aislados.

## Recuperación documental y estado de sesión

Antes de despachar un implementador, el `Execution Log` de `*-plan.md` debe contener `TASK_STARTED` con `timestamp`, `branch`, `git_hash`, `task_id` y contexto. Una nueva sesión lee los bloques `Status: in_progress` de `*-tasks.md` y los correlaciona con ese log; recupera todos los activos o, si no hay ninguno, la primera tarea `pending` con dependencias satisfechas. Cualquier inconsistencia bloquea y pide aclaración. TodoWrite se reconstruye como espejo de esos documentos y no es una fuente persistente.
