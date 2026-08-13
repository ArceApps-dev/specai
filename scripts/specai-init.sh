#!/bin/bash
# specai-init.sh — Bootstrap specai with 7 core agents (no legacy agents)
# Detects the current platform, reads/writes config, injects agent definitions
#
# Usage:
#   bash scripts/specai-init.sh              # Bootstrap with 7 core agents
#   bash scripts/specai-init.sh --dry-run    # Show what would be done
#   bash scripts/specai-init.sh --scope PATH # Initialize project specs and report one scoped preflight
#   bash scripts/specai-init.sh --uninstall  # Remove specai from config

set -e

CONFIG_DIR="$HOME/.config/specai"
CONFIG_FILE="$CONFIG_DIR/config.json"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="$SCRIPT_DIR/agent-roster.json"
PROJECT_ROOT="${SPECIAI_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_SPECS_DIR="$PROJECT_ROOT/docs/specai/project"

# Source configuration helper
source "$SCRIPT_DIR/lib-config.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DRY_RUN=false
UNINSTALL=false
SCOPE=""

while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    --scope)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "❌ --scope requires a relative path to one affected semantic unit"
        exit 1
      fi
      SCOPE="$2"
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "   Usage: bash scripts/specai-init.sh [--dry-run] [--scope PATH] [--uninstall]"
      exit 1
      ;;
  esac
  shift
done

# Default config derives its core agent models from the canonical roster.
DEFAULT_CONFIG=$(python3 - "$ROSTER_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    roster = json.load(f)

config = {
    "agentModels": {
        agent["name"]: agent["defaultModel"] for agent in roster["agents"]
    },
    "language": "auto",
    "seniorMode": "medium",
    "commitMode": "auto",
    "taskComplexity": {
        "low": "openrouter/deepseek/deepseek-v4-flash-free",
        "medium": "minimax/MiniMax-M3",
        "high": "minimax/MiniMax-M3",
    },
}
print(json.dumps(config, indent=2))
PY
)

# ---- Platform Detection ----
detect_platform() {
  if [[ -f "$OPENCODE_CONFIG" ]]; then
    echo "opencode"
  elif command -v claude &>/dev/null; then
    echo "claude"
  elif command -v codex &>/dev/null; then
    echo "codex"
  elif command -v gemini &>/dev/null; then
    echo "gemini"
  else
    echo "unknown"
  fi
}

ensure_config() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "   📋 Would ensure config dir: $CONFIG_DIR"
    return
  fi
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo "   ✅ Created config: $CONFIG_FILE"
  else
    echo "   ⏭️  Config exists: $CONFIG_FILE"
  fi
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

ensure_project_specs() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "   📋 Would ensure project specs directory: $PROJECT_SPECS_DIR"
    return
  fi

  mkdir -p "$PROJECT_SPECS_DIR"
  echo "   ✅ Project specs directory ready: $PROJECT_SPECS_DIR (idempotent)"
}

run_scoped_preflight() {
  [[ -z "$SCOPE" ]] && return

  if [[ "$SCOPE" == /* || "$SCOPE" == .. || "$SCOPE" == ../* || "$SCOPE" == */../* ]]; then
    echo "   ❌ Scoped preflight failed: --scope must stay within the repository and use a relative path: $SCOPE"
    return 1
  fi
  local scope_path="$PROJECT_ROOT/$SCOPE"

  if [[ ! -e "$scope_path" ]]; then
    echo "   ❌ Scoped preflight failed: code scope does not exist: $SCOPE"
    return 1
  fi

  local project_root_real scope_path_real
  project_root_real="$(realpath "$PROJECT_ROOT")"
  scope_path_real="$(realpath "$scope_path")"
  case "$scope_path_real" in
    "$project_root_real"/*) ;;
    *)
      echo "   ❌ Scoped preflight failed: scope resolves outside the repository: $SCOPE"
      return 1
      ;;
  esac

  local unit_name
  unit_name="$(basename "$scope_path_real")"
  local spec_found=false
  local spec
  shopt -s nullglob
  for spec in "$PROJECT_SPECS_DIR"/*.md; do
    if [[ "$(basename "$spec")" == "$unit_name"* || "$(basename "$spec")" == *"$unit_name"* ]]; then
      spec_found=true
      break
    fi
  done
  shopt -u nullglob

  echo "   🔎 Scoped preflight — affected semantic unit: $SCOPE"
  echo "   Review only this unit's relevant code and its project spec."
  if [[ "$spec_found" == true ]]; then
    echo "   ✅ PROJECT_SPEC_FOUND — matching project spec exists for: $unit_name"
  else
    echo "   ⚠️  PROJECT_SPEC_MISSING — no matching project spec exists for: $unit_name"
    echo "   Action required: the documenter must review this scoped code and offer to create its project spec."
  fi
  echo "   No full-project inventory is performed."
}

uninstall_specai() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "   📋 Would remove specai agents from: $OPENCODE_CONFIG"
    return
  fi

  if [[ ! -f "$OPENCODE_CONFIG" ]]; then
    echo "   ⏭️  No opencode config found — nothing to uninstall"
    return
  fi

  echo "   Removing specai agent definitions from OpenCode config..."
  python3 - "$OPENCODE_CONFIG" "$ROSTER_FILE" <<'PY'
import json
import sys

config_path, roster_path = sys.argv[1:]
with open(config_path, encoding="utf-8") as f:
    config = json.load(f)
with open(roster_path, encoding="utf-8") as f:
    roster = json.load(f)

agents_removed = 0
if 'agent' in config:
    specai_agents = [agent['name'] for agent in roster['agents']]
    for agent in specai_agents:
        if agent in config['agent']:
            del config['agent'][agent]
            agents_removed += 1

with open(config_path, 'w', encoding="utf-8") as f:
    json.dump(config, f, indent=2)
print(f'   ✅ Removed {agents_removed} agent(s)')
PY
}

write_opencode_agents() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "   📋 Would write 7 core agents to: $OPENCODE_CONFIG"
    return
  fi

  if [[ ! -f "$OPENCODE_CONFIG" ]]; then
    echo "   ⚠️  No opencode config found at $OPENCODE_CONFIG"
    echo "   specai currently only supports OpenCode."
    echo "   Run 'opencode' once to generate the config file, then re-run this script."
    exit 1
  fi



  python3 - "$OPENCODE_CONFIG" "$ROSTER_FILE" "$CONFIG_FILE" "$SCRIPT_DIR" <<'PY'
import json
import sys

opencode_config_path, roster_path, specai_config_path, script_dir = sys.argv[1:]
with open(opencode_config_path, encoding="utf-8") as f:
    config = json.load(f)
with open(roster_path, encoding="utf-8") as f:
    roster = {agent['name']: agent['defaultModel'] for agent in json.load(f)['agents']}
try:
    with open(specai_config_path, encoding="utf-8") as f:
        configured_models = json.load(f).get('agentModels', {})
except (FileNotFoundError, json.JSONDecodeError):
    configured_models = {}

# Ensure agent key exists
if 'agent' not in config:
    config['agent'] = {}

# 7 core agents
agents = {
    'specai-command': {
        'mode': 'subagent',
        'description': 'Ejecuta comandos (build, test, git). Ningún otro agente ejecuta comandos directamente',
        'permission': {'bash': 'allow', 'read': 'allow'}
    },
    'specai-documentation': {
        'mode': 'subagent',
        'description': 'Crea y actualiza toda la documentación (_plan.md, _tasks.md, specs, README). Ningún otro agente escribe documentación directamente',
        'permission': {'read': 'allow', 'edit': 'allow', 'glob': 'allow', 'grep': 'allow'}
    },
    'implementer': {
        'mode': 'subagent',
        'description': 'Implementa UNA tarea atómica con contexto mínimo',
        'permission': {'bash': 'allow', 'read': 'allow', 'edit': 'allow', 'glob': 'allow', 'grep': 'allow'}
    },
    'build-fixer': {
        'mode': 'subagent',
        'description': 'Resuelve errores de compilación con el fix mínimo',
        'permission': {'read': 'allow', 'edit': 'allow', 'glob': 'allow', 'grep': 'allow'}
    },
    'code-reviewer': {
        'mode': 'subagent',
        'description': 'Revisa la calidad del código por tarea (obligatorio, antes del commit)',
        'permission': {'read': 'allow', 'edit': 'deny', 'glob': 'allow', 'grep': 'allow'}
    },
    'verifier': {
        'mode': 'subagent',
        'description': 'Compara implementación con los criterios de aceptación de _verify.md',
        'permission': {'read': 'allow', 'glob': 'allow', 'grep': 'allow'}
    },
    'spec-compliance-reviewer': {
        'mode': 'subagent',
        'description': 'Revisa cumplimiento de la spec después de todas las tareas (obligatorio, antes del verifier)',
        'permission': {'read': 'allow', 'edit': 'deny', 'glob': 'allow', 'grep': 'allow'}
    }
}

for name, definition in agents.items():
    if name not in roster:
        raise SystemExit(f'agent is not declared in roster: {name}')
    definition['model'] = configured_models.get(name, roster[name])

config['agent'].update(agents)

# Inject slash commands from commands.json (source of truth — objects with template + description)
import os
commands_json = os.path.join(script_dir, '..', '.opencode', 'commands.json')
if 'command' not in config:
    config['command'] = {}
try:
    with open(commands_json) as cf:
        commands = json.load(cf)
    for name, cmd_def in commands.items():
        config['command'][name] = cmd_def
except FileNotFoundError:
    print(f'⚠️  commands.json not found at {commands_json} — slash commands not injected')

with open(opencode_config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2)

print('   ✅ Injected 7 core agents + slash commands into OpenCode config')
PY
}

# ---- Main ----

echo ""
echo -e "${BLUE}🔧 specai-init — Bootstrap${NC}"
echo "=================================="

PLATFORM=$(detect_platform)

# NOTE: specai skills are NOT synced to ~/.config/opencode/skills/.
# OpenCode auto-generates a slash command per skill found there. The plugin
# (.opencode/plugins/specai.js) overrides the skill tool to load specai skills
# from the plugin's own skills/ dir, so no global copy is needed.
echo -e "   Platform detected: ${GREEN}${PLATFORM}${NC}"

if [[ "$UNINSTALL" == true ]]; then
  echo ""
  echo "🗑️  Uninstalling specai..."
  uninstall_specai
  echo ""
  echo -e "${GREEN}✅ specai uninstalled.${NC}"
  exit 0
fi

ensure_config
ensure_project_specs
run_scoped_preflight
echo ""

if [[ "$PLATFORM" == "opencode" ]]; then
  write_opencode_agents
elif [[ "$PLATFORM" == "claude" ]] || [[ "$PLATFORM" == "codex" ]]; then
  echo "   ⚠️  specai currently supports OpenCode for agent injection."
  echo "   For $PLATFORM, install skills manually into the skills directory."
  echo "   See docs/ for platform-specific instructions."
elif [[ "$PLATFORM" == "antigravity" ]]; then
  echo "   Antigravity discovers skills automatically from the workspace plugin."
  echo "   Run ./specai install if you haven't yet, then restart Antigravity."
elif [[ "$PLATFORM" == "gemini" ]]; then
  echo "   ⚠️  specai no longer ships a Gemini CLI bridge (Gemini CLI as a coding"
  echo "   harness is currently unsupported). Use Antigravity instead."
else
  echo "   ⚠️  No supported platform detected."
  echo "   specai supports OpenCode, Claude Code, Codex, and Antigravity."
fi

echo ""

# Show summary
if [[ "$DRY_RUN" == false ]]; then
  echo -e "${GREEN}✅ specai initialization complete.${NC}"
  echo ""
  echo "   Core agents (7):"
  python3 - "$ROSTER_FILE" "$CONFIG_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    roster = json.load(f)["agents"]
with open(sys.argv[2], encoding="utf-8") as f:
    configured = json.load(f).get("agentModels", {})
for agent in roster:
    name = agent["name"]
    print(f"     • {name:<24} → {configured.get(name, agent['defaultModel'])}")
PY
  echo ""
  echo "   To add legacy agents (spec-reviewer, code-quality-reviewer, final-reviewer):"
  echo "   bash scripts/setup-agents.sh"
  echo ""
  echo "   Re-run 'bash scripts/setup-agents.sh' if you need to refresh agent definitions."
  echo ""
  echo -e "   Config: ${BLUE}$CONFIG_FILE${NC}"
fi
