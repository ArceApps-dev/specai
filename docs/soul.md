# Soul de specai

El **soul** define cómo habla specai: voz, tono y hábitos de respuesta. Es configuración por usuario, no documentación del proyecto, no un skill y no `_design.md`.

## Ubicación y precedencia

- Configuración: `~/.config/specai/config.json` → `soul.path`.
- Archivo activo: normalmente `~/.config/specai/soul.md`.
- Fallback: `souls/default.md` del repositorio cuando el archivo configurado no existe.
- `specai-init.sh` instala el default solo si todavía no existe un soul local.

El contenido se inyecta antes de `specai-bootstrap` en el bloque de system prompt de OpenCode. Se aplica a todas las respuestas, skills, subagentes y slash commands. Cambia la presentación, no el flujo, el código ni las gates de aceptación.

## Presets

`souls/` contiene muestras ordenadas de más expresivas a más lacónicas:

`mentor` → `companion` → `editor` → `default` → `caveman`

Son copias iniciales editables. specai no sobrescribe el soul local después de instalarlo.

## Gestión

```bash
bash scripts/soul.sh list
bash scripts/soul.sh set mentor
bash scripts/soul.sh set caveman
bash scripts/soul.sh edit
bash scripts/soul.sh show
bash scripts/soul.sh path
```

La TUI también expone `Soul` como ajuste persistente. `design.md` queda fuera de este mecanismo y pertenece a otra tarea.
