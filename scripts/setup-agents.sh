#!/bin/bash
# setup-agents.sh — Inject specai subagents into OpenCode config
# Reads model config from ~/.config/specai/config.json
# Writes agent definitions into ~/.config/opencode/opencode.json
#
# Usage: bash scripts/setup-agents.sh

set -e

CONFIG_DIR="$HOME/.config/specai"
CONFIG_FILE="$CONFIG_DIR/config.json"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="$SCRIPT_DIR/agent-roster.json"
HARNESS_CONTRACT="${SPECAI_HARNESS_CONTRACT:-$SCRIPT_DIR/agent-harness-contract.json}"

# Force OpenCode harness configuration for OpenCode agent setup
export SPECAI_HARNESS=opencode
# Source configuration helper
source "$(dirname "$0")/lib-config.sh"

# Validate the native harness contract before reading or writing any projection.
python3 "$SCRIPT_DIR/validate-harness-contract.py" "$HARNESS_CONTRACT" --roster "$ROSTER_FILE" >/dev/null

roster_default_model() {
  python3 - "$ROSTER_FILE" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    roster = json.load(f)
for agent in roster["agents"]:
    if agent["name"] == sys.argv[2]:
        print(agent["defaultModel"])
        break
else:
    raise SystemExit(f"agent not found in roster: {sys.argv[2]}")
PY
}

MODEL_IMPLEMENTER=$(read_model implementer "$(roster_default_model implementer)")
MODEL_BUILDFIXER=$(read_model build-fixer "$(roster_default_model build-fixer)")
MODEL_CODEREVIEWER=$(read_model code-reviewer "$(roster_default_model code-reviewer)")
MODEL_VERIFIER=$(read_model verifier "$(roster_default_model verifier)")
MODEL_SPECCOMPLIANCE=$(read_model spec-compliance-reviewer "$(roster_default_model spec-compliance-reviewer)")
MODEL_COMMAND=$(read_model specai-command "$(roster_default_model specai-command)")
MODEL_DOCUMENTATION=$(read_model specai-documentation "$(roster_default_model specai-documentation)")
LANGUAGE=$(read_language)
COMMIT_MODE=$(read_commit_mode)

echo "🔧 specai: injecting agent definitions..."
echo "   Config: $CONFIG_FILE"
echo "   Models:"
echo "     implementer             → $MODEL_IMPLEMENTER"
echo "     build-fixer            → $MODEL_BUILDFIXER"
echo "     code-reviewer          → $MODEL_CODEREVIEWER"
echo "     verifier               → $MODEL_VERIFIER"
echo "     spec-compliance-reviewer → $MODEL_SPECCOMPLIANCE"
echo "     specai-command        → $MODEL_COMMAND"
echo "     specai-documentation   → $MODEL_DOCUMENTATION"
  echo "   Language: $LANGUAGE"
  echo "   Commit mode: $COMMIT_MODE"
  echo ""

# Build agent descriptions with language context
if [[ "$LANGUAGE" == "auto" ]]; then
  LANG_DESC=""
else
  LANG_DESC=" (documents in $LANGUAGE)"
fi

# Generate specai agents JSON snippet
SPECAI_AGENTS=$(python3 - \
  "$OPENCODE_CONFIG" "$ROSTER_FILE" "$SCRIPT_DIR" "$LANG_DESC" \
  "$MODEL_IMPLEMENTER" "$MODEL_BUILDFIXER" "$MODEL_CODEREVIEWER" \
  "$MODEL_VERIFIER" "$MODEL_SPECCOMPLIANCE" "$MODEL_COMMAND" \
  "$MODEL_DOCUMENTATION" <<'PY'
import json
import os
import sys

(opencode_config_path, roster_path, script_dir, lang_desc,
 model_implementer, model_buildfixer, model_codereviewer, model_verifier,
 model_speccompliance, model_command, model_documentation) = sys.argv[1:]
model_values = {
    "implementer": model_implementer,
    "build-fixer": model_buildfixer,
    "code-reviewer": model_codereviewer,
    "verifier": model_verifier,
    "spec-compliance-reviewer": model_speccompliance,
    "specai-command": model_command,
    "specai-documentation": model_documentation,
}

agents = {
    "implementer": {
        "mode": "subagent",
        "description": f"Implementa UNA tarea atómica con contexto mínimo{lang_desc}",
        "permission": {
            "bash": "allow",
            "read": "allow",
            "edit": "allow",
            "glob": "allow",
            "grep": "allow",
            "webfetch": "allow",
            "todowrite": "allow"
        }
    },
    "build-fixer": {
        "mode": "subagent",
        "description": f"Resuelve errores de compilación con el fix mínimo{lang_desc}",
        "permission": {
            "read": "allow",
            "edit": "allow",
            "glob": "allow",
            "grep": "allow"
        }
    },
    "code-reviewer": {
        "mode": "subagent",
        "description": f"Revisa la calidad del código por tarea (obligatorio, antes del commit){lang_desc}",
        "permission": {
            "read": "allow",
            "edit": "deny",
            "glob": "allow",
            "grep": "allow"
        }
    },
    "verifier": {
        "mode": "subagent",
        "description": f"Compara implementación con la checklist de aceptación de _plan.md{lang_desc}",
        "permission": {
            "read": "allow",
            "glob": "allow",
            "grep": "allow"
        }
    },
    "specai-command": {
        "mode": "subagent",
        "description": f"Ejecuta comandos (build, test, git). Ningún otro agente ejecuta comandos directamente{lang_desc}",
        "permission": {
            "bash": "allow",
            "read": "allow"
        }
    },
    "specai-documentation": {
        "mode": "subagent",
        "description": f"Crea y actualiza toda la documentación (_plan.md, _tasks.md, specs, README). Ningún otro agente escribe documentación directamente{lang_desc}",
        "permission": {
            "read": "allow",
            "edit": "allow",
            "glob": "allow",
            "grep": "allow"
        }
    },
    "spec-compliance-reviewer": {
        "mode": "subagent",
        "description": f"Revisa cumplimiento de la spec después de todas las tareas (obligatorio, antes del verifier){lang_desc}",
        "permission": {
            "read": "allow",
            "edit": "deny",
            "glob": "allow",
            "grep": "allow"
        }
    }
}

with open(roster_path, encoding='utf-8') as rf:
    roster = {agent['name'] for agent in json.load(rf)['agents']}

for name, definition in agents.items():
    if name not in roster:
        raise SystemExit(f'agent is not declared in roster: {name}')
    definition['model'] = model_values[name]

# Inject into opencode.json
try:
    with open(opencode_config_path, encoding='utf-8') as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

if 'agent' not in cfg:
    cfg['agent'] = {}

# Remove only the retired SpecAI role names. Unrelated user-defined agents are
# preserved; the canonical seven are then replaced from the roster below.
for legacy_name in ("spec-reviewer", "code-quality-reviewer", "final-reviewer"):
    cfg['agent'].pop(legacy_name, None)

# Add/replace specai agents
for name, agent_def in agents.items():
    cfg['agent'][name] = agent_def

# Remove specai settings if they exist to prevent schema validation failure in OpenCode
if 'specai' in cfg:
    del cfg['specai']


# Inject slash commands from commands.json (source of truth for correct schema)
import os
commands_json = os.path.join(script_dir, '..', '.opencode', 'commands.json')
if 'command' not in cfg:
    cfg['command'] = {}
try:
    with open(commands_json) as cf:
        commands = json.load(cf)
    for name, cmd_def in commands.items():
        cfg['command'][name] = cmd_def
except FileNotFoundError:
    print(f'⚠️  commands.json not found at {commands_json} — slash commands not injected')

with open(opencode_config_path, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2)

print("✅ Agents and commands written to opencode.json")
PY
)

echo "$SPECAI_AGENTS"
echo ""
echo "📋 Current specai agent models:"
echo "   implementer            → $MODEL_IMPLEMENTER"
echo "   build-fixer           → $MODEL_BUILDFIXER"
echo "   code-reviewer         → $MODEL_CODEREVIEWER"
echo "   verifier              → $MODEL_VERIFIER"
echo "   spec-compliance-reviewer → $MODEL_SPECCOMPLIANCE"
echo "   specai-command       → $MODEL_COMMAND"
echo "   specai-documentation  → $MODEL_DOCUMENTATION"
echo ""
echo "   To change models: bash scripts/configure-agents.sh"
echo "   Config file: $CONFIG_FILE"
