---
name: specai-backlog
description: Use cuando el usuario invoque /specai-backlog, consulte planes pendientes o seleccione una feature del backlog para decidir si implementarla.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.2"
---

# Visor y selector de backlog

Lee `.specai/backlog.json`, valida su contrato y presenta features completas como planes seleccionables. Cada entrada representa una feature fechada y debe conservar su identidad documental.

## Contrato de cada entrada

Toda entrada debe incluir estos campos:

```json
{
  "feature_id": "YYYYMMDD-slug",
  "feature_dir": "docs/specai/YYYYMMDD-slug",
  "plan_dir": "docs/specai/YYYYMMDD-slug/YYYYMMDD-slug-plan.md",
  "status": "backlog"
}
```

- `feature_id` es la identidad estable y debe coincidir con el prefijo común de la feature.
- `feature_dir` identifica la carpeta de la feature. La reconciliación acepta la carpeta activa `docs/specai/<feature_id>/` y la carpeta archivada `docs/specai/feature/<feature_id>/`.
- `plan_dir` debe apuntar a una ruta real dentro de `feature_dir` y al plan de la misma `feature_id`.
- `status` usa exactamente estos estados wire: `backlog`, `in_progress`, `verifying`, `ready_to_finish`, `done`.
- Durante `sync`, `in-progress` solo se acepta como token legacy de entrada y se normaliza inmediatamente a `in_progress`.
- Las interfaces nuevas solo emiten estados wire con guion bajo: `backlog`, `in_progress`, `verifying`, `ready_to_finish` y `done`.

No se aceptan entradas sin identidad, con rutas huérfanas, con prefijos incoherentes ni con estados alternativos fuera de esa normalización de `sync`. La sincronización y reconciliación valida tanto las carpetas activas como las archivadas, detecta `feature_id` duplicados, colisiones de rutas, planes ausentes, destinos incompatibles y conflictos de estado, y nunca sobrescribe silenciosamente una entrada.

## `/specai-backlog` sin argumentos

1. Leer y reconciliar `.specai/backlog.json` con las carpetas activa y archive.
2. Informar cada conflicto antes de presentar elementos seleccionables.
3. Excluir `done`, salvo que se use `--done`.
4. Mostrar `feature_id`, estado, `feature_dir` y el resumen del plan:

```text
BACKLOG — N planes

[1] 🟢 BACKLOG       20260804-example
    feature_dir: docs/specai/20260804-example
    plan_dir: docs/specai/20260804-example/20260804-example-plan.md
    <resumen del plan>
```

Si la lista está vacía o todos los elementos están en `done`, mostrar `BACKLOG — vacío. No hay planes pendientes.`

## `/specai-backlog --done`

Usar la misma validación, pero incluir también las entradas con estado `done`.

## Selección e implementación

Seleccionar un elemento de backlog no crea una rama hasta que el usuario elige implementar.

Al seleccionar una entrada:

1. Resolverla por número o `feature_id` y leer el plan desde `plan_dir`.
2. Presentar la elección explícita: mantener/guardar en backlog o implementar.
3. Si el usuario mantiene la feature en backlog, conservar `feature_dir`, validar/actualizar únicamente el estado `backlog` y la proyección del backlog. No crear rama, worktree ni ejecutar Git: no hacer `checkout`, commit, merge ni pull.
4. Solo si el usuario elige implementar, actualizar el estado a `in_progress` y crear la rama de implementación `feature/<reponame>_<feature-slug>`; después delegar en `specai-executing-plans`.

La elección de backlog es una operación documental y de reconciliación. La creación de rama y cualquier operación Git pertenecen exclusivamente al camino de implementación elegido por el usuario.

## Estados posteriores

| Estado wire | Significado |
|---|---|
| `backlog` | Feature guardada, sin implementación elegida y sin rama. |
| `in_progress` | Implementación elegida y en ejecución. |
| `verifying` | Implementación terminada, pendiente de verificación. |
| `ready_to_finish` | Verificación y aceptación completadas; lista para finish autorizado. |
| `done` | Feature finalizada y archivada según el contrato de finish. |

Las transiciones deben conservar `feature_id`, `feature_dir` y `plan_dir`. Un conflicto o una ruta que deje de existir detiene la reconciliación y se informa al usuario; no se corrige inventando rutas ni sobrescribiendo datos.

## Integración con el flujo specai

El backlog contiene planes completos, no tareas sueltas. La skill de ejecución toma el control solo después de elegir implementar. La verificación puede mover el estado a `verifying` o `ready_to_finish`; el finish autorizado establece `done` y archiva la feature conforme a sus seis documentos.
