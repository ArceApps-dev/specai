#!/usr/bin/env bash
# tui-profiles.sh — Predefined configuration profiles

# Profile definitions
# Format: "agent=model"

PROFILE_ECONOMIC_NAME="💰 Economic"
PROFILE_ECONOMIC_DESC="All agents use cheapest model (deepseek-free). Best for: testing, simple tasks"
PROFILE_ECONOMIC=(
  "implementer=deepseek/deepseek-v4-flash-free"
  "build-fixer=deepseek/deepseek-v4-flash-free"
  "code-reviewer=deepseek/deepseek-v4-flash-free"
  "verifier=deepseek/deepseek-v4-flash-free"
  "spec-compliance-reviewer=deepseek/deepseek-v4-flash-free"
  "specai-command=deepseek/deepseek-v4-flash-free"
  "specai-documentation=deepseek/deepseek-v4-flash-free"
  "spec-reviewer=deepseek/deepseek-v4-flash-free"
  "code-quality-reviewer=deepseek/deepseek-v4-flash-free"
  "final-reviewer=deepseek/deepseek-v4-flash-free"
)

PROFILE_BALANCED_NAME="⚖️ Balanced"
PROFILE_BALANCED_DESC="Core agents: capable model, others: cheap. Best for: daily development"
PROFILE_BALANCED=(
  "implementer=minimax/MiniMax-M3"
  "build-fixer=deepseek/deepseek-v4-flash-free"
  "code-reviewer=deepseek/deepseek-v4-flash-free"
  "verifier=minimax/MiniMax-M3"
  "spec-compliance-reviewer=deepseek/deepseek-v4-flash-free"
  "specai-command=deepseek/deepseek-v4-flash-free"
  "specai-documentation=deepseek/deepseek-v4-flash-free"
  "spec-reviewer=deepseek/deepseek-v4-flash-free"
  "code-quality-reviewer=deepseek/deepseek-v4-flash-free"
  "final-reviewer=deepseek/deepseek-v4-flash-free"
)

PROFILE_PREMIUM_NAME="💎 Premium"
PROFILE_PREMIUM_DESC="All agents use best available model. Best for: complex projects, production"
PROFILE_PREMIUM=(
  "implementer=minimax/MiniMax-M3"
  "build-fixer=minimax/MiniMax-M3"
  "code-reviewer=minimax/MiniMax-M3"
  "verifier=minimax/MiniMax-M3"
  "spec-compliance-reviewer=minimax/MiniMax-M3"
  "specai-command=minimax/MiniMax-M3"
  "specai-documentation=minimax/MiniMax-M3"
  "spec-reviewer=minimax/MiniMax-M3"
  "code-quality-reviewer=minimax/MiniMax-M3"
  "final-reviewer=minimax/MiniMax-M3"
)

# List of profile identifiers
PROFILE_IDS=("economic" "balanced" "premium")

# Get profile name by ID
get_profile_name() {
  local id="$1"
  case "$id" in
    economic) echo "$PROFILE_ECONOMIC_NAME" ;;
    balanced) echo "$PROFILE_BALANCED_NAME" ;;
    premium) echo "$PROFILE_PREMIUM_NAME" ;;
  esac
}

# Get profile description by ID
get_profile_description() {
  local id="$1"
  case "$id" in
    economic) echo "$PROFILE_ECONOMIC_DESC" ;;
    balanced) echo "$PROFILE_BALANCED_DESC" ;;
    premium) echo "$PROFILE_PREMIUM_DESC" ;;
  esac
}

# Get profile models by ID
# Usage: get_profile_models "balanced"
# Returns: array of "agent=model" strings
get_profile_models() {
  local id="$1"
  case "$id" in
    economic)
      echo "${PROFILE_ECONOMIC[@]}"
      ;;
    balanced)
      echo "${PROFILE_BALANCED[@]}"
      ;;
    premium)
      echo "${PROFILE_PREMIUM[@]}"
      ;;
  esac
}

# List all profiles for selection
list_profiles() {
  for id in "${PROFILE_IDS[@]}"; do
    echo "$(get_profile_name "$id")"
  done
}

# Get profile ID from display name
get_profile_id_from_name() {
  local name="$1"
  case "$name" in
    *Economic*) echo "economic" ;;
    *Balanced*) echo "balanced" ;;
    *Premium*) echo "premium" ;;
  esac
}

# Format profile preview for confirmation
format_profile_preview() {
  local id="$1"
  local models
  models=($(get_profile_models "$id"))

  echo "Profile: $(get_profile_name "$id")"
  echo "Description: $(get_profile_description "$id")"
  echo ""
  echo "Agent assignments:"

  for entry in "${models[@]}"; do
    local agent="${entry%%=*}"
    local model="${entry#*=}"
    printf "  %-30s → %s\n" "$agent" "$model"
  done
}
