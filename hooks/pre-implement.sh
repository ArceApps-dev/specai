#!/bin/bash
# pre-implement.sh — Enforcement gate: block code changes without spec + plan
# Install: ln -s ../../hooks/pre-implement.sh .git/hooks/pre-commit
# Or: copy to .git/hooks/pre-commit

set -e

# ---- Configuration ----
SPEC_DIR="docs/specai"
PLAN_FILE="_plan.md"
SPEC_FILE="_spec.md"
REQUIRED_FILES=()

# Find the most recent specai directory
LATEST_SPEC=$(ls -dt ${SPEC_DIR}/*/ 2>/dev/null | head -1 || echo "")

echo "🔒 specai enforcement gate: pre-implement check"

# Check if we're on a specai feature branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

if [[ "$BRANCH" != feature/* ]]; then
  echo "   ⚠️  Not on a feature branch ($BRANCH). Skipping spec checks."
  exit 0
fi

# Check for plan file
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "   ❌ BLOCKED: No _plan.md found."
  echo "   specai requires a plan before implementation."
  echo "   Run '/specai-propose' or '/specai-execute' to create one."
  echo "   To bypass (emergency only): git commit --no-verify"
  exit 1
fi

# Check for spec file
if [[ -n "$LATEST_SPEC" ]] && [[ ! -f "${LATEST_SPEC}designs.md" ]] && [[ ! -f "$SPEC_FILE" ]]; then
  echo "   ⚠️  Warning: No design spec found. Continuing but recommended to create one."
fi

echo "   ✅ Spec/Plan check passed."
exit 0
