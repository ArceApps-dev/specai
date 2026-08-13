#!/bin/bash
# uninstall-agents.sh — Remove specai agent definitions from OpenCode config
#
# Removes ONLY the agents injected by specai. Does not touch other agents
# or any other part of opencode.json.
#
# Usage: bash scripts/uninstall-agents.sh [--purge-config]
#   --purge-config  Also delete ~/.config/specai/ (models config, judgment_day setting, etc.)

set -e

OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
SPECAI_CONFIG_DIR="$HOME/.config/specai"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="$SCRIPT_DIR/agent-roster.json"

PURGE_CONFIG=false
if [[ "$1" == "--purge-config" ]]; then
  PURGE_CONFIG=true
fi

echo "🔧 specai: removing agent definitions from OpenCode..."

if [[ ! -f "$OPENCODE_CONFIG" ]]; then
  echo "⚠️  opencode.json not found at $OPENCODE_CONFIG — nothing to remove."
else
  python3 - "$OPENCODE_CONFIG" "$ROSTER_FILE" <<'PY'
import json
import sys

config_path, roster_path = sys.argv[1:]
with open(roster_path, encoding="utf-8") as f:
    agents_to_remove = [agent["name"] for agent in json.load(f)["agents"]]
# BEGIN legacy installation migration (non-public)
# Compatibility cleanup for installations created by older releases only.
agents_to_remove.extend(["spec-reviewer", "code-quality-reviewer", "final-reviewer"])
# END legacy installation migration (non-public)

with open(config_path, encoding="utf-8") as f:
    cfg = json.load(f)

removed = []
for agent in agents_to_remove:
    if cfg.get("agent", {}).pop(agent, None) is not None:
        removed.append(agent)

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)

if removed:
    for name in removed:
        print(f"  ✗ Removed agent: {name}")
else:
    print("  No specai agents found in opencode.json.")
PY
fi

if [[ "$PURGE_CONFIG" == "true" ]]; then
  if [[ -d "$SPECAI_CONFIG_DIR" ]]; then
    rm -rf "$SPECAI_CONFIG_DIR"
    echo "  ✗ Deleted $SPECAI_CONFIG_DIR"
  else
    echo "  ⚠️  $SPECAI_CONFIG_DIR not found — nothing to delete."
  fi
fi

echo ""
echo "✅ OpenCode uninstall complete."
if [[ "$PURGE_CONFIG" == "false" ]]; then
  echo "   Model config preserved at $SPECAI_CONFIG_DIR"
  echo "   To also delete it: bash scripts/uninstall-agents.sh --purge-config"
fi
