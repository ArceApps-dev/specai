#!/bin/bash
# pre-implement.sh — Enforcement gate: block code changes without spec + plan
# Install: ln -s ../../hooks/pre-implement.sh .git/hooks/pre-commit
# Or: copy to .git/hooks/pre-commit

set -euo pipefail

# Resolve state from the consumer project, never from the SpecAI distribution.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
SPEC_ROOT="${SPECIAI_ROOT:-$REPO_ROOT}"
SPEC_DIR="$SPEC_ROOT/docs/specai"

find_latest_feature_dir() {
  [[ -d "$SPEC_DIR" ]] || return 0
  find "$SPEC_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null \
    | while IFS= read -r -d '' directory; do
        feature_id="$(basename "$directory")"
        [[ -f "$directory/${feature_id}-plan.md" ]] || continue
        printf '%s\t%s\n' "$(stat -c %Y "$directory/${feature_id}-plan.md" 2>/dev/null || stat -f %m "$directory/${feature_id}-plan.md")" "$directory"
      done \
    | sort -rn | head -1 | cut -f2-
}

echo "🔒 specai enforcement gate: pre-implement check"

# Check if we're on a specai feature branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

if [[ "$BRANCH" != feature/* ]]; then
  echo "   ⚠️  Not on a feature branch ($BRANCH). Skipping spec checks."
  exit 0
fi

# Check for the active feature plan
LATEST_SPEC="$(find_latest_feature_dir || true)"
if [[ -z "$LATEST_SPEC" ]]; then
  echo "   ❌ BLOCKED: No feature plan found under docs/specai/<feature-id>."
  echo "   specai requires a plan before implementation."
  echo "   Run '/specai-plan' to create one."
  echo "   To bypass (emergency only): git commit --no-verify"
  exit 1
fi

# Check for the task document that accompanies the plan.
feature_id="$(basename "$LATEST_SPEC")"
TASKS_FILE="$LATEST_SPEC/${feature_id}-tasks.md"
if [[ ! -f "$TASKS_FILE" ]]; then
  echo "   ❌ BLOCKED: No feature tasks file found: $TASKS_FILE"
  exit 1
fi

echo "   ✅ Spec/Plan check passed."
exit 0
