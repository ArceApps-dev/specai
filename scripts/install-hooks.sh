#!/bin/bash
# install-hooks.sh — Install specai enforcement gates as git hooks
# Usage: bash scripts/install-hooks.sh [--uninstall]

set -e

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo "")"
GIT_HOOKS="${GIT_DIR}/hooks"

UNINSTALL=false
[[ "$1" == "--uninstall" ]] && UNINSTALL=true

if [[ -z "$GIT_DIR" ]]; then
  echo "❌ Not in a git repository."
  exit 1
fi

if [[ "$UNINSTALL" == true ]]; then
  echo "🗑️  Removing specai hooks..."
  for hook in pre-implement post-task; do
    if [[ -L "${GIT_HOOKS}/${hook}" ]] || [[ -f "${GIT_HOOKS}/${hook}" ]]; then
      rm -f "${GIT_HOOKS}/${hook}"
      echo "   ✓ Removed ${hook}"
    fi
  done
  echo "✅ Hooks uninstalled."
  exit 0
fi

echo "🔧 Installing specai enforcement gates..."
mkdir -p "${GIT_HOOKS}"

# pre-commit: requires spec + plan before code changes
ln -sf "${HOOKS_DIR}/pre-implement.sh" "${GIT_HOOKS}/pre-commit"
echo "   ✓ pre-commit  → pre-implement.sh (blocks code without spec+plan)"

# post-commit: warns on stale living documents
ln -sf "${HOOKS_DIR}/post-task.sh" "${GIT_HOOKS}/post-commit"
echo "   ✓ post-commit → post-task.sh (warns on stale docs)"

echo ""
echo "✅ Enforcement gates installed."
echo "   To uninstall: bash scripts/install-hooks.sh --uninstall"
echo "   To bypass once: git commit --no-verify"
