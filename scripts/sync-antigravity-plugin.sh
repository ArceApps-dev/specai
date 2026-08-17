#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--root PATH] [--check]\n' "$0" >&2
}

root="${SPECIAI_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
check_only=0

while (($# > 0)); do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      root="$2"
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

skills_root="$root/skills"
plugin_root="$root/.antigravity-plugin"
projection_root="$plugin_root/skills"
agent_root="$plugin_root/agents"
roster_file="$root/scripts/agent-roster.json"

if [[ ! -d "$skills_root" ]]; then
  printf 'ANTIGRAVITY_PROJECTION_BLOCKED: missing canonical skills directory: %s\n' "$skills_root" >&2
  exit 1
fi

mapfile -t skill_dirs < <(find "$skills_root" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
if ((${#skill_dirs[@]} == 0)); then
  printf 'ANTIGRAVITY_PROJECTION_BLOCKED: canonical skills directory is empty: %s\n' "$skills_root" >&2
  exit 1
fi

declare -A expected_targets=()
for skill_dir in "${skill_dirs[@]}"; do
  skill_name="$(basename "$skill_dir")"
  if [[ ! "$skill_name" =~ ^specai-[a-z0-9-]+$ ]]; then
    printf 'ANTIGRAVITY_PROJECTION_BLOCKED: invalid skill directory: %s\n' "$skill_name" >&2
    exit 1
  fi
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    printf 'ANTIGRAVITY_PROJECTION_BLOCKED: canonical skill is missing SKILL.md: %s\n' "$skill_name" >&2
    exit 1
  fi
  expected_targets["$skill_name"]="../../skills/$skill_name"
done

if [[ -z "${expected_targets[specai-bootstrap]+present}" ]]; then
  printf 'ANTIGRAVITY_PROJECTION_BLOCKED: required canonical skill is missing: specai-bootstrap\n' >&2
  exit 1
fi

validate_agent_projection() {
  python3 - "$agent_root" "$roster_file" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
roster_path = Path(sys.argv[2])
try:
    roster = json.loads(roster_path.read_text(encoding="utf-8"))
    expected = {agent["name"] for agent in roster["agents"]}
except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError):
    raise SystemExit(f"ANTIGRAVITY_PROJECTION_BLOCKED: invalid roster: {roster_path}")
if not root.is_dir():
    raise SystemExit(f"ANTIGRAVITY_PROJECTION_BLOCKED: missing agent directory: {root}")
files = {path.stem for path in root.glob("*.md") if path.is_file()}
if files != expected:
    raise SystemExit(
        f"ANTIGRAVITY_PROJECTION_BLOCKED: agent roles {sorted(files)} != {sorted(expected)}"
    )
for role in sorted(expected):
    path = root / f"{role}.md"
    raw = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n([\s\S]*?)\n---\n", raw)
    if not match:
        raise SystemExit(f"ANTIGRAVITY_PROJECTION_BLOCKED: invalid frontmatter: {path}")
    frontmatter = match.group(1)
    required = {
        "name:": role,
        "description:": None,
        "subagent:": "true",
        "mainAgent:": "false",
        "model:": None,
        "commandExecutionPolicy:": "sandbox",
        "tools:": None,
    }
    for key, expected_value in required.items():
        line = next((item for item in frontmatter.splitlines() if item.startswith(key)), None)
        if line is None or (expected_value is not None and line.split(":", 1)[1].strip() != expected_value):
            raise SystemExit(f"ANTIGRAVITY_PROJECTION_BLOCKED: {path} missing valid {key}")
    if "/specai-plan" not in raw and "/specai-mini" not in raw:
        raise SystemExit(f"ANTIGRAVITY_PROJECTION_BLOCKED: {path} missing SpecAI handoff entrypoint")
print(f"agent projection: PASS ({len(expected)} roles)")
PY
}

validate_agent_projection

supports_symlinks() {
  local probe_dir
  probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/specai-antigravity-symlink.XXXXXX")" || return 1
  if ln -s target "$probe_dir/link" 2>/dev/null; then
    rm -rf -- "$probe_dir"
    return 0
  fi
  rm -rf -- "$probe_dir"
  return 1
}

is_materialized_skill_valid() {
  local link="$1"
  local source_skill="$2"
  [[ -d "$link" && ! -L "$link" && -f "$link/SKILL.md" ]] || return 1
  [[ "$(find "$link" -mindepth 1 -maxdepth 1 -type f -name SKILL.md -printf '%f\n' | wc -l)" == '1' ]] || return 1
  cmp -s "$source_skill" "$link/SKILL.md"
}

is_projection_entry_valid() {
  local link="$1"
  local target="$2"
  local source_skill="$3"

  if [[ -L "$link" ]]; then
    [[ "$(readlink "$link")" == "$target" ]]
    return
  fi
  is_materialized_skill_valid "$link" "$source_skill"
}

materialize_skill() {
  local link="$1"
  local source_skill="$2"
  mkdir -p -- "$link"
  cp -- "$source_skill" "$link/SKILL.md"
}

symlink_mode=0
if supports_symlinks; then
  symlink_mode=1
fi

if ((check_only)); then
  [[ -d "$projection_root" ]] || {
    printf 'ANTIGRAVITY_PROJECTION_OUT_OF_SYNC: missing projection directory: %s\n' "$projection_root" >&2
    exit 1
  }
else
  mkdir -p "$projection_root"
fi

declare -A seen=()
for skill_dir in "${skill_dirs[@]}"; do
  skill_name="$(basename "$skill_dir")"
  target="${expected_targets[$skill_name]}"
  link="$projection_root/$skill_name"
  source_skill="$skill_dir/SKILL.md"
  seen["$skill_name"]=1
  if is_projection_entry_valid "$link" "$target" "$source_skill"; then
    continue
  fi
  if ((check_only)); then
    printf 'ANTIGRAVITY_PROJECTION_OUT_OF_SYNC: %s\n' "$link" >&2
    exit 1
  fi
  if [[ -e "$link" || -L "$link" ]]; then
    rm -rf -- "$link"
  fi
  if ((symlink_mode)) && ln -s "$target" "$link" 2>/dev/null; then
    continue
  fi
  if [[ -e "$link" || -L "$link" ]]; then
    rm -rf -- "$link"
  fi
  materialize_skill "$link" "$source_skill"
done

while IFS= read -r -d '' entry; do
  name="$(basename "$entry")"
  if [[ -z "${seen[$name]+present}" ]]; then
    if ((check_only)); then
      printf 'ANTIGRAVITY_PROJECTION_OUT_OF_SYNC: stale projection entry: %s\n' "$entry" >&2
      exit 1
    fi
    rm -rf -- "$entry"
  fi
done < <(find "$projection_root" -mindepth 1 -maxdepth 1 -print0)

if ((check_only)); then
  printf 'Antigravity projection: PASS (%d skills, symlink-or-copy)\n' "${#expected_targets[@]}"
else
  if ((symlink_mode)); then
    printf 'Antigravity projection: SYNCED (%d skills, symlink)\n' "${#expected_targets[@]}"
  else
    printf 'Antigravity projection: SYNCED (%d skills, copy)\n' "${#expected_targets[@]}"
  fi
fi
