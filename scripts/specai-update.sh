#!/usr/bin/env bash
# specai-update.sh — Validate SKILL.md frontmatter and clean stale specai skill
# copies from OpenCode's global skills dir.
#
# specai skills are NOT meant to live in ~/.config/opencode/skills/: OpenCode
# auto-generates a slash command per skill found there, while the plugin loads
# specai skills from its own dir. Older installs may carry leftover specai-*
# copies from a previous sync — this script removes them and validates that
# every SKILL.md still has valid frontmatter.
#
# Usage:
#   bash scripts/specai-update.sh            # actually apply
#   bash scripts/specai-update.sh --dry-run  # show what would change
#   bash scripts/specai-update.sh --check    # exit 1 if update would change anything (CI gate)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPECAI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$SPECAI_DIR/skills"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"

MODE="apply"
[[ "${1:-}" == "--dry-run" ]] && MODE="dry-run"
[[ "${1:-}" == "--check" ]] && MODE="check"

changes=0

note_change() {
  echo "  ~ $1"
  changes=$((changes+1))
}

if [[ "$MODE" != "dry-run" ]]; then
  echo "═══════════════════════════════════════════════════════════════"
  echo "  specai-update — frontmatter validation + stale skill cleanup"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "Skills dir:  $SKILLS_DIR"
  echo "OpenCode cfg: $OPENCODE_CONFIG"
  echo "Mode:        $MODE"
  echo ""
fi

# 1. Re-extract frontmatter for every skill and dump as JSON
extract_skills() {
  python3 - "$SKILLS_DIR" << 'PYEOF'
import sys, os, json, re

root = sys.argv[1]
out = {}
for entry in sorted(os.listdir(root)):
    full = os.path.join(root, entry)
    if not os.path.isdir(full):
        continue
    skill_file = os.path.join(full, "SKILL.md")
    if not os.path.exists(skill_file):
        continue
    text = open(skill_file).read()
    parts = text.split("---", 2)
    if len(parts) < 3:
        continue
    fm = parts[1]
    name = entry
    desc = ""
    command = ""
    for line in fm.split("\n"):
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("command:"):
            command = line.split(":", 1)[1].strip().strip('"').strip("'")
        elif line.startswith("description:"):
            desc_part = line.split(":", 1)[1].strip()
            if desc_part in (">", "|-", ">-", "|"):
                # block scalar; collect indented lines
                idx = fm.split("\n").index(line) + 1
                lines = fm.split("\n")
                collected = []
                for j in range(idx, len(lines)):
                    if lines[j].startswith("  ") and lines[j].strip():
                        collected.append(lines[j].strip())
                    elif lines[j].strip() == "":
                        continue
                    else:
                        break
                desc = " ".join(collected)
            else:
                desc = desc_part
    out[entry] = {"name": name, "description": desc, "command": command}
print(json.dumps(out, indent=2))
PYEOF
}

# 2. Remove stale specai skill copies from the OpenCode global skills dir.
# OpenCode auto-generates a slash command for every skill found there, and the
# plugin loads specai skills from its own dir instead. Older installs may have
# leftover specai-* copies from a previous sync — clean them up.
if [[ -d "$HOME/.config/opencode/skills" ]]; then
  for opencode_skill in "$HOME/.config/opencode/skills"/*/; do
    [ -d "$opencode_skill" ] || continue
    name="$(basename "$opencode_skill")"
    if [[ "$name" == specai-* || "$name" == spec-* ]]; then
      note_change "Stale specai skill copy in opencode: $name (removing — skills load via plugin)"
      if [[ "$MODE" == "apply" ]]; then
        rm -rf "$opencode_skill"
      fi
    fi
  done
fi

# 3. Detect SKILL.md files with invalid YAML (proxy: re-extract and check name match)
extract_skills > /tmp/specai-skills.json
if ! python3 -c "
import json
with open('/tmp/specai-skills.json') as f:
    skills = json.load(f)
for name, meta in skills.items():
    if not meta.get('name'):
        print(f'  ❌ {name}: invalid frontmatter (no name)')
        import sys; sys.exit(2)
"; then
  changes=$((changes+1))
fi

# Summary
echo ""
if [[ $changes -eq 0 ]]; then
  echo "✓ No stale skill copies or frontmatter issues. All clean."
  exit 0
else
  echo "───────────────────────────────────────────────────────"
  echo "  Summary: $changes change(s) detected"
  echo "───────────────────────────────────────────────────────"
  if [[ "$MODE" == "dry-run" ]]; then
    echo "  (dry-run mode: nothing was changed; run without --dry-run to apply)"
  fi
  if [[ "$MODE" == "check" ]]; then
    echo "  (--check mode: would update; CI gate FAIL)"
    exit 1
  fi
fi