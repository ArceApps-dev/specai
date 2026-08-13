#!/bin/bash
# checkpoint-restore.sh — Explain document-based recovery without reading JSON
# Usage:
#   bash scripts/checkpoint-restore.sh --latest       # Explain document-based recovery
#   bash scripts/checkpoint-restore.sh --list         # Explain document-based recovery
#   bash scripts/checkpoint-restore.sh --file <path>  # Explain document-based recovery

set -e

case "$1" in
  --list|--latest|--file)
    echo "ℹ️ Checkpoint restore disabled; use la documentación viva para reanudar."
    ;;
  *)
    echo "Usage:"
    echo "  bash scripts/checkpoint-restore.sh --latest"
    echo "  bash scripts/checkpoint-restore.sh --list"
    echo "  bash scripts/checkpoint-restore.sh --file <path>"
    exit 1
    ;;
esac
