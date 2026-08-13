#!/bin/bash
# specai-doctor.sh — Smoke-test the specai installation
# Verifies the user's setup without modifying anything (unless --fix is passed).
#
# Usage:
#   bash scripts/specai-doctor.sh           # report only
#   bash scripts/specai-doctor.sh --fix     # auto-repair where possible
#   bash scripts/specai-doctor.sh --json    # machine-readable output

set -e

CONFIG_DIR="$HOME/.config/specai"
CONFIG_FILE="$CONFIG_DIR/config.json"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
SPECAI_DIR="$(cd "$(dirname "$0")/.." && pwd)"

MODE="report"
JSON="false"
[[ "${1:-}" == "--fix" ]] && MODE="fix"
[[ "${1:-}" == "--json" ]] && JSON="true"

report() {
  if [[ "$JSON" == "true" ]]; then
    return
  fi
  printf "  %s\n" "$1"
}

results_ok=0
results_warn=0
results_fail=0
results=()

check_ok() { report "✅ $1"; results_ok=$((results_ok+1)); results+=("ok|$1"); }
check_warn() { report "⚠️  $1"; results_warn=$((results_warn+1)); results+=("warn|$1"); }
check_fail() { report "❌ $1"; results_fail=$((results_fail+1)); results+=("fail|$1"); }

if [[ "$JSON" != "true" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  specai — doctor v1.0"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Repo: $SPECAI_DIR"
  echo "User config: $CONFIG_FILE"
  echo "OpenCode config: $OPENCODE_CONFIG"
  echo "Mode: $MODE"
  echo ""
fi

# 1. Config file
if [[ -f "$CONFIG_FILE" ]]; then
  check_ok "Config file present: $CONFIG_FILE"
  # Senior mode
  mode=$(python3 -c "
import json, sys
try:
  c = json.load(open('$CONFIG_FILE'))
  print(c.get('seniorMode', 'medium'))
except Exception as e:
  print('ERR: ' + str(e))
" 2>/dev/null)
  if [[ "$mode" == "ERR"* ]]; then
    check_fail "Cannot parse $CONFIG_FILE: $mode"
  else
    if [[ "$mode" =~ ^(off|lite|medium|ultra)$ ]]; then
      check_ok "Senior mode: $mode (run /specai-mode to change)"
    else
      check_warn "Senior mode '$mode' is not a known value"
    fi
  fi
  # Language
  lang=$(python3 -c "
import json
c = json.load(open('$CONFIG_FILE'))
print(c.get('language', 'auto'))
" 2>/dev/null || echo "ERR")
  [[ "$lang" != "ERR" ]] && check_ok "Document language: $lang"
  # Commit mode
  cm=$(python3 -c "
import json
c = json.load(open('$CONFIG_FILE'))
print(c.get('commitMode', 'auto'))
" 2>/dev/null || echo "ERR")
  [[ "$cm" != "ERR" ]] && check_ok "Commit mode: $cm"
else
  check_fail "Config file missing: $CONFIG_FILE (run bash scripts/specai-init.sh)"
fi

# 2. Required skills (active, not legacy)
for skill in specai-bootstrap specai-grill-me specai-write-prd specai-writing-plans specai-subagent-driven-development specai-verification-before-completion specai-finishing-a-development-branch specai-iteration specai-senior-philosophy specai-help; do
  if [[ -f "$SPECAI_DIR/skills/$skill/SKILL.md" ]]; then
    check_ok "Skill present: $skill"
  else
    check_warn "Skill missing: $skill"
  fi
done

# 3. Removed skills should NOT exist
for removed in specai-brainstorming specai-socratic-clarifier specai-assumptions-review; do
  if [[ -f "$SPECAI_DIR/skills/$removed/SKILL.md" ]]; then
    check_fail "Legacy/deprecated skill still present: $removed (delete it)"
  else
    check_ok "Deprecated skill absent: $removed"
  fi
done

# 4. Branch safety
branch=$(git -C "$SPECAI_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "ERR")
if [[ "$branch" == "ERR" ]]; then
  check_warn "Not a git repo or git unavailable"
elif [[ "$branch" =~ ^(main|master|develop|dev)$ ]]; then
  check_warn "Currently on protected branch '$branch' — specai forbids commits here. Create a feature branch first."
else
  check_ok "On feature branch: $branch"
fi

# 5. docs/specai/project/ structure
if [[ -d "$SPECAI_DIR/docs/specai/project" ]]; then
  count=$(ls -1 "$SPECAI_DIR/docs/specai/project" | wc -l)
  check_ok "docs/specai/project/ present ($count entries)"
else
  check_warn "docs/specai/project/ missing — run /specai-init"
fi

# 6. OpenCode agents
if [[ -f "$OPENCODE_CONFIG" ]]; then
  if python3 -c "
import json
c = json.load(open('$OPENCODE_CONFIG'))
agents = c.get('agent', {})
needed = ['implementer', 'build-fixer', 'code-reviewer', 'verifier',
          'spec-compliance-reviewer', 'specai-command', 'specai-documentation']
missing = [a for a in needed if a not in agents]
if missing:
  print('MISSING: ' + ','.join(missing))
  exit(0)
print('OK')
" 2>/dev/null | grep -q "OK"; then
    check_ok "OpenCode agents registered (7 core)"
  else
    missing=$(python3 -c "
import json
c = json.load(open('$OPENCODE_CONFIG'))
agents = c.get('agent', {})
needed = ['implementer', 'build-fixer', 'code-reviewer', 'verifier',
          'spec-compliance-reviewer', 'specai-command', 'specai-documentation']
print(','.join(a for a in needed if a not in agents))
" 2>/dev/null)
    check_warn "OpenCode missing agents: $missing (run bash scripts/setup-agents.sh)"
  fi
else
  check_warn "OpenCode config not found at $OPENCODE_CONFIG (opencode never ran yet?)"
fi

# 7. Acceptance criteria source
verifier_prompt="$SPECAI_DIR/skills/specai-subagent-driven-development/verifier-prompt.md"
if [[ -f "$verifier_prompt" ]] && grep -Fq '<topic>_verify.md' "$verifier_prompt" && grep -Fq 'ONLY place acceptance criteria live' "$verifier_prompt"; then
  check_ok "Acceptance criteria source: _verify.md"
else
  check_warn "Verifier acceptance source is not explicitly _verify.md"
fi

# 8. Q5 — subagent-driven-development size budget
sd_size=$(wc -l < "$SPECAI_DIR/skills/specai-subagent-driven-development/SKILL.md" 2>/dev/null || echo 0)
if [[ $sd_size -le 500 ]]; then
  check_ok "subagent-driven-development skill size: $sd_size lines (≤500 budget)"
else
  check_warn "subagent-driven-development skill is $sd_size lines (over 500 budget — consider trimming)"
fi

# 9. No obsolete brainstorming references in active docs
obs_refs=$(grep -rE "brainstorming" "$SPECAI_DIR/AGENTS.md" "$SPECAI_DIR/README.md" "$SPECAI_DIR/README.es.md" 2>/dev/null | wc -l)
if [[ "$obs_refs" -eq 0 ]]; then
  check_ok "No obsolete 'brainstorming' references in active docs (AGENTS.md, READMEs)"
else
  check_warn "Found $obs_refs obsolete 'brainstorming' references in active docs"
fi

# 10. Cheap-model routing for specai-documentation + specai-command
if [[ -f "$OPENCODE_CONFIG" ]]; then
  python3 -c "
import json
c = json.load(open('$OPENCODE_CONFIG'))
a = c.get('agent', {})
for name in ['specai-documentation', 'specai-command']:
  if name in a:
    m = a[name].get('model', '')
    if 'flash-free' in m or 'cheap' in m.lower() or 'haiku' in m.lower():
      print('OK')
      break
else:
  print('NOT_CHEAP')
" 2>/dev/null | grep -q "OK"
  if [[ $? -eq 0 ]]; then
    check_ok "Cheap-model routing for documentation/command agents (cost advantage)"
  else
    check_warn "specai-documentation / specai-command not on cheap model (consider deepseek-v4-flash-free)"
  fi
fi

# Summary
if [[ "$JSON" == "true" ]]; then
  printf '{"ok":%d,"warn":%d,"fail":%d,"checks":[' "$results_ok" "$results_warn" "$results_fail"
  first=1
  for r in "${results[@]}"; do
    status="${r%%|*}"
    msg="${r#*|}"
    if [[ $first -eq 1 ]]; then first=0; else printf ","; fi
    printf '{"status":"%s","msg":"%s"}' "$status" "$msg"
  done
  printf ']}\n'
else
  echo ""
  echo "───────────────────────────────────────────────────────"
  echo "  Summary: $results_ok ok · $results_warn warn · $results_fail fail"
  echo "───────────────────────────────────────────────────────"
  if [[ $results_fail -gt 0 ]]; then
    echo "  ✘ Setup is broken. Fix the ❌ items above."
    exit 2
  elif [[ $results_warn -gt 0 ]]; then
    echo "  ⚠ Setup works, with warnings. Consider addressing ⚠ items."
    exit 1
  else
    echo "  ✓ Setup is healthy."
    exit 0
  fi
fi
