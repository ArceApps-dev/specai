#!/usr/bin/env bash
# specai-evals.sh — Contract checker for skills/*/SKILL.md
#
# Verifies that each skill's frontmatter is valid YAML, the name matches
# its directory, required-skill dependencies exist, and declared gates
# have the expected shape.
#
# Usage:
#   bash scripts/specai-evals.sh           # full eval (warn-only by default)
#   bash scripts/specai-evals.sh --strict  # exit non-zero on warn
#   bash scripts/specai-evals.sh --json    # machine-readable output

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPECAI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$SPECAI_DIR/skills"

STRICT="false"
JSON="false"
[[ "${1:-}" == "--strict" ]] && STRICT="true"
[[ "${1:-}" == "--json" ]] && JSON="true"

results_ok=0
results_warn=0
results_fail=0

# Collect results for JSON mode
results=()

note_ok() {
  if [[ "$JSON" != "true" ]]; then echo "  ✅ $1"; fi
  results_ok=$((results_ok+1))
  results+=("ok|$1")
}

note_warn() {
  if [[ "$JSON" != "true" ]]; then echo "  ⚠️  $1"; fi
  results_warn=$((results_warn+1))
  results+=("warn|$1")
}

note_fail() {
  if [[ "$JSON" != "true" ]]; then echo "  ❌ $1"; fi
  results_fail=$((results_fail+1))
  results+=("fail|$1")
}

if [[ "$JSON" != "true" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  specai-evals v1.0"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Skills dir: $SKILLS_DIR"
  echo ""
fi

# Parse simple YAML frontmatter without external dependencies.
# Handles flat key:value pairs and `key: >-` block scalars.
parse_yaml() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" << 'PYEOF'
import sys, re

file, key = sys.argv[1], sys.argv[2]
text = open(file).read()
parts = text.split('---', 2)
if len(parts) < 3:
    print('NO_FRONTMATTER')
    sys.exit(0)

frontmatter = parts[1]
# Try to find the key
pattern = re.compile(r'^' + re.escape(key) + r':\s*(.*)$', re.MULTILINE)
m = pattern.search(frontmatter)
if not m:
    print('')
    sys.exit(0)

val = m.group(1).rstrip()
if val in ('>', '|-', '>-', '|'):
    # Block scalar; collect indented lines
    start = m.end()
    lines = []
    for line in frontmatter[start:].split('\n'):
        if line.startswith('  ') or line.strip() == '':
            stripped = line.strip()
            if stripped:
                lines.append(stripped)
        else:
            break
    print(' '.join(lines))
else:
    # Strip surrounding quotes if present
    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
        val = val[1:-1]
    print(val)
PYEOF
}

# Walk every skill
shopt -s nullglob
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    note_warn "$skill_name: directory exists but no SKILL.md"
    continue
  fi

  # 1. Frontmatter present?
  if ! head -1 "$skill_file" | grep -q "^---$"; then
    note_fail "$skill_name: no frontmatter (file should start with ---)"
    continue
  fi

  # 2. name field
  declared_name=$(parse_yaml "$skill_file" name)
  if [[ -z "$declared_name" || "$declared_name" == "BLOCK_SCALAR" || "$declared_name" == "NO_FRONTMATTER" ]]; then
    note_fail "$skill_name: 'name' field missing or invalid"
  elif [[ "$declared_name" != "$skill_name" ]]; then
    note_fail "$skill_name: 'name' field says '$declared_name' (mismatch)"
  else
    :  # ok
  fi

  # 3. description present and non-empty
  desc=$(parse_yaml "$skill_file" description)
  if [[ -z "$desc" || "$desc" == "BLOCK_SCALAR" || "$desc" == "NO_FRONTMATTER" ]]; then
    note_warn "$skill_name: 'description' field missing or invalid"
  fi

  # 4. Body content
  body_lines=$(wc -l < "$skill_file")
  if [[ $body_lines -lt 10 ]]; then
    note_warn "$skill_name: only $body_lines lines (looks too short for a real skill)"
  else
    note_ok "$skill_name: $body_lines lines, frontmatter valid"
  fi

  # 5. Skill-specific gate presence
  case "$skill_name" in
    specai-bootstrap)
      if ! grep -q "Documentation Gates\|IMPRESCINDIBLE\|INQUEBRANTABLE" "$skill_file"; then
        note_warn "$skill_name: bootstrap should declare INQUEBRANTABLE documentation gates"
      fi
      ;;
    specai-grill-me)
      if ! grep -q "Required Skills" "$skill_file" || ! grep -q "specai-bootstrap" "$skill_file"; then
        note_warn "$skill_name: grill-me must declare specai-bootstrap as a dependency"
      fi
      if ! grep -q "Gate G1" "$skill_file" || ! grep -qi "grounding evidence" "$skill_file"; then
        note_warn "$skill_name: grill-me must enforce a grounding evidence gate"
      fi
      if ! grep -q "Gate G2" "$skill_file" || ! grep -qi "response check\|response enforcement" "$skill_file"; then
        note_warn "$skill_name: grill-me must enforce one question per response"
      fi
      ;;
    specai-agent-clarification)
      if ! grep -q "Required Skills" "$skill_file" || ! grep -q "specai-bootstrap" "$skill_file"; then
        note_warn "$skill_name: clarification must declare specai-bootstrap as a dependency"
      fi
      if ! grep -q "Bootstrap gate" "$skill_file" || ! grep -q "Specification gate" "$skill_file"; then
        note_warn "$skill_name: clarification must enforce bootstrap and specification gates"
      fi
      if grep -q "Escribe tu propia respuesta" "$skill_file"; then
        note_warn "$skill_name: hardcoded Spanish custom-response text remains"
      fi
      if grep -qi "trigger.*\/specai-plan" "$skill_file"; then
        note_warn "$skill_name: clarification must hand off to the controller instead of triggering commands"
      fi
      ;;
    specai-writing-plans)
      if ! grep -q "^## Absolute Gates\|^Gate P" "$skill_file"; then
        note_warn "$skill_name: writing-plans should declare '## Absolute Gates'"
      fi
      ;;
    specai-subagent-driven-development)
      if ! grep -q "Gate S0\|Gate S1\|Gates S" "$skill_file"; then
        note_warn "$skill_name: subagent-driven-development should declare 'Gate S0' (per-task cycle)"
      fi
      ;;
    specai-verification-before-completion|verification-before-completion)
      if ! grep -qi "evidence" "$skill_file"; then
        note_warn "$skill_name: verification-before-completion should require evidence before claims"
      fi
      ;;
    specai-finishing-a-development-branch)
      if ! grep -q "Gate UA\|User Acceptance\|user.acceptance" "$skill_file"; then
        note_warn "$skill_name: finishing-a-development-branch should reference Gate UA"
      fi
      ;;
    specai-iteration)
      if ! grep -qi "corrective" "$skill_file"; then
        note_warn "$skill_name: iteration should declare corrective-task mechanism"
      fi
      ;;
  esac

done

# 6. Cross-skill dependency check
# Only check references inside explicit dependency sections to avoid
# false positives (the body may mention /specai-plan as a slash command,
# not as a skill dependency).
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name="$(basename "$(dirname "$skill_file")")"
  # Extract content of sections titled "Required Skills" or "Required Sub-Skills"
  deps_block=$(awk '
    /^##[[:space:]]+(Required Skills|Required Sub-Skills|Required Subagent|Dependencies|Subagent Roles)/ {flag=1; next}
    /^##[[:space:]]/ {flag=0}
    flag {print}
  ' "$skill_file")
  while IFS= read -r ref; do
    # only check `specai-X` style names (skip /slash-command mentions and prose)
    ref=$(echo "$ref" | grep -oE "specai-[a-z][a-z-]*" | head -1)
    [[ -z "$ref" ]] && continue
    if [[ "$ref" != "$skill_name" && ! -d "$SKILLS_DIR/$ref" ]]; then
      note_warn "$skill_name: dependency '$ref' declared in 'Required Skills' but directory does not exist"
    fi
  done <<< "$deps_block"
done

# Summary
if [[ "$JSON" == "true" ]]; then
  printf '{"ok":%d,"warn":%d,"fail":%d,"checks":[' "$results_ok" "$results_warn" "$results_fail"
  first=1
  for r in "${results[@]}"; do
    status="${r%%|*}"
    msg="${r#*|}"
    msg=${msg//\"/\\\"}
    if [[ $first -eq 1 ]]; then first=0; else printf ","; fi
    printf '{"status":"%s","msg":"%s"}' "$status" "$msg"
  done
  printf ']}\n'
else
  echo ""
  echo "───────────────────────────────────────────────────────"
  echo "  Summary: $results_ok ok · $results_warn warn · $results_fail fail"
  echo "───────────────────────────────────────────────────────"
fi

# Exit code
if [[ $results_fail -gt 0 ]]; then
  exit 2
elif [[ "$STRICT" == "true" && $results_warn -gt 0 ]]; then
  exit 1
else
  exit 0
fi
