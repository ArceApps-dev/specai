#!/usr/bin/env bash
set -euo pipefail

# post-task.sh — Enforcement gate: warn on missing handoff after task completion
# Install: ln -s ../../hooks/post-task.sh .git/hooks/post-commit

echo "🔒 specai enforcement gate: post-task check"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
SPEC_ROOT="${SPECIAI_ROOT:-$REPO_ROOT}"
SPEC_DIR="$SPEC_ROOT/docs/specai"

LATEST_SPEC=""
if [[ -d "$SPEC_DIR" ]]; then
  LATEST_SPEC="$(find "$SPEC_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null \
    | while IFS= read -r -d '' directory; do
        feature_id="$(basename "$directory")"
        plan_file="$directory/${feature_id}-plan.md"
        [[ -f "$plan_file" ]] || continue
        printf '%s\t%s\n' "$(stat -c %Y "$plan_file" 2>/dev/null || stat -f %m "$plan_file")" "$directory"
      done \
    | sort -rn | head -1 | cut -f2- || true)"
fi

warnings=0

if [[ -n "$LATEST_SPEC" ]]; then
  feature_id="$(basename "$LATEST_SPEC")"
  PLAN_FILE="$LATEST_SPEC/${feature_id}-plan.md"
  TASKS_FILE="$LATEST_SPEC/${feature_id}-tasks.md"
  LAST_MODIFIED=$(stat -c %Y "$PLAN_FILE" 2>/dev/null || stat -f %m "$PLAN_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - LAST_MODIFIED))
  if [[ $AGE -gt 3600 ]]; then  # Older than 1 hour
    echo "   ⚠️  Warning: $PLAN_FILE hasn't been updated in over an hour."
    echo "   Living documents should be updated after each task."
    ((warnings++))
  fi
  if [[ -f "$TASKS_FILE" ]]; then
    UNCHECKED=$(grep -c '^\- \[ \]' "$TASKS_FILE" 2>/dev/null || true)
    CHECKED=$(grep -c '^\- \[[xX]\]' "$TASKS_FILE" 2>/dev/null || true)
    echo "   📋 Tasks: $CHECKED completed, $UNCHECKED remaining"
  else
    echo "   ⚠️  Warning: feature tasks file is missing: $TASKS_FILE"
    ((warnings++))
  fi
else
  echo "   ⚠️  No feature plan found under docs/specai/<feature-id>."
fi

# Check for domain model updates
if [[ -f "CONTEXT.md" ]]; then
  echo "   📝 CONTEXT.md present — terminology aligned"
fi

if [[ $warnings -gt 0 ]]; then
  echo "   💡 Tip: Delegate doc updates to specai-documentation agent."
fi

exit 0
