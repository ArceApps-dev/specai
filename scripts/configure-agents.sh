#!/bin/bash
# configure-agents.sh — Change specai subagent models and language at runtime
# Reads/writes ~/.config/specai/config.json and applies changes
#
# Usage:
#   bash scripts/configure-agents.sh                                    # Show current config
#   bash scripts/configure-agents.sh <agent> <model>                    # Change one agent model
#   bash scripts/configure-agents.sh --language <auto|en|es|...>        # Set document language
#   bash scripts/configure-agents.sh --interactive                      # Interactive mode
#   bash scripts/configure-agents.sh --reset                            # Reset to defaults

set -e

CONFIG_DIR="$HOME/.config/specai"
CONFIG_FILE="$CONFIG_DIR/config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="$SCRIPT_DIR/agent-roster.json"

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
    "commitMode": "auto",
    "seniorMode": "medium",
}
print(json.dumps(config, indent=2))
PY
)

mapfile -t ROSTER_AGENTS < <(python3 - "$ROSTER_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    for agent in json.load(f)["agents"]:
        print(agent["name"])
PY
)

VALID_AGENTS=("${ROSTER_AGENTS[@]}")

ensure_config() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo "   Created default config: $CONFIG_FILE"
  fi
}

read_config() {
  python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as f:
    c = json.load(f)
print(json.dumps(c, indent=2))
PY
}

write_model() {
  local agent="$1"
  local model="$2"
  python3 - "$CONFIG_FILE" "$agent" "$model" <<'PY'
import json
import sys
config_file, agent, model = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
if 'agentModels' not in c:
    c['agentModels'] = {}
c['agentModels'][agent] = model
with open(config_file, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2)
PY
}

set_language() {
  local lang="$1"
  python3 - "$CONFIG_FILE" "$lang" <<'PY'
import json
import sys
config_file, lang = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
c['language'] = lang
with open(config_file, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2)
PY
}

set_commit_mode() {
  local mode="$1"
  python3 - "$CONFIG_FILE" "$mode" <<'PY'
import json
import sys
config_file, mode = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
c['commitMode'] = mode
with open(config_file, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2)
PY
}

reset_config() {
  echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
}

show_current() {
  echo "📋 Current specai configuration:"
  echo ""
  read_config
  echo ""
  echo "   Config file: $CONFIG_FILE"
  local commit_mode
  commit_mode=$(python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as f:
    c = json.load(f)
print(c.get('commitMode', 'auto'))
PY
)
  echo "   commitMode: $commit_mode"
}

apply() {
  echo "⚙️  Applying to OpenCode..."
  bash "$SCRIPT_DIR/setup-agents.sh"
}

# --- Main ---

ensure_config

if [[ $# -eq 0 ]]; then
  show_current
  echo ""
  echo "   Commands:"
  echo "     bash scripts/configure-agents.sh <agent> <model>"
  echo "     bash scripts/configure-agents.sh --language <auto|en|es|...>"
  echo "     bash scripts/configure-agents.sh --commit-mode <auto|confirm|manual>"
  echo "     bash scripts/configure-agents.sh --interactive"
  echo "     bash scripts/configure-agents.sh --reset"
  echo "   Agents: ${VALID_AGENTS[*]}"
  exit 0
fi

if [[ "$1" == "--commit-mode" ]]; then
  if [[ -z "$2" ]]; then
    echo "❌ Missing commit mode. Usage: --commit-mode <auto|confirm|manual>"
    exit 1
  fi
  case "$2" in
    auto|confirm|manual) ;;
    *)
      echo "❌ Invalid commit mode: $2"
      echo "   Valid: auto, confirm, manual"
      exit 1
      ;;
  esac
  set_commit_mode "$2"
  echo "   ✓ Commit mode set to: $2"
  apply
  exit 0
fi

if [[ "$1" == "--language" ]]; then
  if [[ -z "$2" ]]; then
    echo "❌ Missing language code. Usage: --language <auto|en|es|...>"
    exit 1
  fi
  set_language "$2"
  echo "   ✓ Language set to: $2"
  apply
  exit 0
fi

if [[ "$1" == "--interactive" ]]; then
  echo "🔧 Interactive configuration"
  show_current
  echo ""
  for agent in "${VALID_AGENTS[@]}"; do
    current=$(python3 - "$CONFIG_FILE" "$agent" <<'PY'
import json
import sys
config_file, agent = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
print(c.get('agentModels', {}).get(agent, 'N/A'))
PY
)
    read -rp "   $agent (current: $current) → New model [Enter to keep]: " new_model
    if [[ -n "$new_model" ]]; then
      write_model "$agent" "$new_model"
      echo "   ✓ $agent → $new_model"
    fi
  done
  current_lang=$(python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as f:
    c = json.load(f)
print(c.get('language', 'auto'))
PY
)
  read -rp "   Language (current: $current_lang) → [Enter to keep]: " new_lang
  if [[ -n "$new_lang" ]]; then
    set_language "$new_lang"
    echo "   ✓ Language → $new_lang"
  fi
  current_commit=$(python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as f:
    c = json.load(f)
print(c.get('commitMode', 'auto'))
PY
)
  read -rp "   Commit mode (current: $current_commit) → auto/confirm/manual [Enter to keep]: " new_commit
  if [[ -n "$new_commit" ]]; then
    case "$new_commit" in
      auto|confirm|manual)
        set_commit_mode "$new_commit"
        echo "   ✓ Commit mode → $new_commit"
        ;;
      *)
        echo "   ⚠️  Invalid: $new_commit (valid: auto, confirm, manual). Keeping $current_commit."
        ;;
    esac
  fi
  apply
  exit 0
fi

if [[ "$1" == "--reset" ]]; then
  echo "🔄 Resetting to defaults..."
  reset_config
  apply
  show_current
  exit 0
fi

if [[ $# -eq 2 ]]; then
  agent="$1"
  model="$2"
  valid=0
  for a in "${VALID_AGENTS[@]}"; do
    [[ "$a" == "$agent" ]] && valid=1
  done
  if [[ $valid -eq 1 ]]; then
    write_model "$agent" "$model"
    echo "   ✓ $agent → $model"
    apply
  else
    echo "❌ Invalid agent: $agent"
    echo "   Valid: ${VALID_AGENTS[*]}"
    exit 1
  fi
  exit 0
fi

echo "❌ Invalid arguments"
echo "   Usage: bash scripts/configure-agents.sh [agent] [model]"
echo "          bash scripts/configure-agents.sh --language <code>"
echo "          bash scripts/configure-agents.sh --commit-mode <auto|confirm|manual>"
echo "          bash scripts/configure-agents.sh --interactive"
echo "          bash scripts/configure-agents.sh --reset"
exit 1
