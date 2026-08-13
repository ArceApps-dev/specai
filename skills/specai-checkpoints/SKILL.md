---
name: specai-checkpoints
description: Recuperación documental y conservación efímera del estado de sesión, sin persistencia de checkpoints.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-checkpoints

## Propósito

Esta skill conserva el nombre histórico por compatibilidad conceptual, pero no crea ni restaura checkpoints persistentes. La recuperación entre sesiones se reconstruye exclusivamente desde los bloques `Status: in_progress` de `*-tasks.md` y el `Execution Log` de `*-plan.md`.

## Contrato de sesión

- El estado operativo se conserva en memoria mientras la sesión está activa.
- Antes de implementar cada tarea se registra `TASK_STARTED` en el `Execution Log` con `timestamp`, `branch`, `git_hash`, `task_id` y contexto.
- La documentación mantiene los estados canónicos `pending`, `in_progress` y `completed`.
- TodoWrite es únicamente el espejo operativo de la documentación; no es fuente de recuperación.
- Los human approval checkpoints y review checkpoints siguen siendo controles de decisión, no persistencia de sesión.

## Recuperación documental

Al iniciar o reanudar una sesión:

1. Leer los `*-tasks.md` y el `Execution Log` de sus `*-plan.md`.
2. Correlacionar cada `Status: in_progress` con su `TASK_STARTED` y contexto.
3. Recuperar todas las tareas `in_progress`, no solo la última.
4. Si no hay tareas activas, seleccionar la primera `pending` cuyas dependencias estén satisfechas.
5. Bloquear el flujo y pedir aclaración ante IDs desconocidos, estados incompatibles, dependencias no satisfechas, log incompatible o divergencia del checkout.
6. Reconstruir TodoWrite desde esos documentos, sin convertirlo en almacenamiento.

El `git_hash` valida el checkout documentado, pero no selecciona por sí solo la tarea a reanudar. Los metadatos de sesión que no estén en los documentos se pierden al interrumpirse la sesión y no deben inventarse ni escribirse en el checkout.

## No persistencia

El flujo MUST NOT crear archivos JSON de checkpoint, una carpeta de checkpoints ni una representación equivalente dentro del checkout. Los JSON antiguos, si existen, no son fuente de verdad y solo pueden limpiarse mediante una acción explícita fuera del flujo.

Ninguna instrucción activa debe llamar a scripts de guardado/restauración de checkpoints ni exigir que se guarde un checkpoint después de cada tarea. La finalización de una tarea requiere build/tests, revisión, commit autorizado y actualización documental; no requiere persistencia adicional.

## Integración

Después de cada transición relevante, el controlador entrega al documentador el evento correspondiente (`TASK_STARTED`, `TASK_UPDATE`, `IMPLEMENTER_RESULT`, `TASK_FAILED` o `TASK_COMPLETED`). El documentador actualiza el estado y el log; no se añade un paso de guardado de checkpoint.
