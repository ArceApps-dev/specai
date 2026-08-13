#!/usr/bin/env bash
# Manage the per-user specai soul.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/specai"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SOUL_DIR="${SCRIPT_DIR}/../souls"
SOUL_FILE="${CONFIG_DIR}/soul.md"

usage() {
  printf 'Usage: %s {list|show|set PRESET|edit|reset PRESET|path}\n' "$0"
}

ensure_config() {
  mkdir -p "$CONFIG_DIR"
  [[ -f "$CONFIG_FILE" ]] || printf '{"language":"auto"}\n' > "$CONFIG_FILE"
}

set_config() {
  local preset="$1"
  python3 - "$CONFIG_FILE" "$preset" <<'PY'
import json, sys
path, preset = sys.argv[1:]
with open(path) as f: data = json.load(f)
data['soul'] = {'path': 'soul.md', 'preset': preset}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PY
}

case "${1:-}" in
  list)
    find "$SOUL_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort
    ;;
  show)
    [[ -f "$SOUL_FILE" ]] && cat "$SOUL_FILE" || { echo "No soul configured: $SOUL_FILE" >&2; exit 1; }
    ;;
  set|reset)
    preset="${2:-default}"
    [[ -f "$SOUL_DIR/$preset.md" ]] || { echo "Unknown soul preset: $preset" >&2; exit 1; }
    ensure_config
    cp "$SOUL_DIR/$preset.md" "$SOUL_FILE"
    chmod 600 "$SOUL_FILE"
    set_config "$preset"
    echo "Soul set to $preset ($SOUL_FILE)"
    ;;
  edit)
    ensure_config
    touch "$SOUL_FILE"
    "${EDITOR:-vi}" "$SOUL_FILE"
    ;;
  path)
    printf '%s\n' "$SOUL_FILE"
    ;;
  *)
    usage
    exit 2
    ;;
esac
