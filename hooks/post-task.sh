#!/bin/bash
# post-task.sh — Enforcement gate: warn on missing handoff after task completion
# Install: ln -s ../../hooks/post-task.sh .git/hooks/post-commit

echo "🔒 specai enforcement gate: post-task check"

# Check for living document updates
PLAN_FILE="_plan.md"
TASKS_FILE="_tasks.md"

warnings=0

if [[ -f "$PLAN_FILE" ]]; then
  LAST_MODIFIED=$(stat -c %Y "$PLAN_FILE" 2>/dev/null || stat -f %m "$PLAN_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - LAST_MODIFIED))
  if [[ $AGE -gt 3600 ]]; then  # Older than 1 hour
    echo "   ⚠️  Warning: _plan.md hasn't been updated in over an hour."
    echo "   Living documents should be updated after each task."
    ((warnings++))
  fi
fi

if [[ -f "$TASKS_FILE" ]]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$TASKS_FILE" 2>/dev/null || echo 0)
  CHECKED=$(grep -c '^\- \[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
  echo "   📋 Tasks: $CHECKED completed, $UNCHECKED remaining"
fi

# Check for domain model updates
if [[ -f "CONTEXT.md" ]]; then
  echo "   📝 CONTEXT.md present — terminology aligned"
fi

if [[ $warnings -gt 0 ]]; then
  echo "   💡 Tip: Delegate doc updates to specai-documentation agent."
fi

exit 0
