#!/bin/bash
# checkpoint-save.sh — Report session checkpoint metadata without persistence
# Usage: bash scripts/checkpoint-save.sh \
#          --branch "feature/..." \
#          --last-task "T3" \
#          --tasks-completed "T1,T2,T3" \
#          --tasks-in-progress "T4,T5" \
#          --plan "docs/.../_plan.md" \
#          --tasks "docs/.../_tasks.md"

set -e

BRANCH=""
LAST_TASK=""
TASKS_COMPLETED=""
TASKS_IN_PROGRESS=""
TASKS_IN_PROGRESS_SET=0
PLAN_FILE=""
TASKS_FILE=""
BUILD_HASH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --last-task) LAST_TASK="$2"; shift 2 ;;
    --tasks-completed) TASKS_COMPLETED="$2"; shift 2 ;;
    --tasks-in-progress) TASKS_IN_PROGRESS="$2"; TASKS_IN_PROGRESS_SET=1; shift 2 ;;
    --plan) PLAN_FILE="$2"; shift 2 ;;
    --tasks) TASKS_FILE="$2"; shift 2 ;;
    --build-hash) BUILD_HASH="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" || -z "$LAST_TASK" || "$TASKS_IN_PROGRESS_SET" -eq 0 ]]; then
  echo "❌ --branch, --last-task, and --tasks-in-progress are required"
  exit 1
fi

GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "ℹ️ Checkpoint persistence disabled; use the feature task and plan documents for recovery."
echo "   Timestamp: $TIMESTAMP"
echo "   Branch: $BRANCH"
echo "   Git: $GIT_HASH"
echo "   Last task: $LAST_TASK"
echo "   Completed: $TASKS_COMPLETED"
echo "   In progress: $TASKS_IN_PROGRESS"
echo "   Build: $BUILD_HASH"
echo "   Plan: $PLAN_FILE"
echo "   Tasks: $TASKS_FILE"
