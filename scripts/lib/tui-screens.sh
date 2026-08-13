#!/usr/bin/env bash
# tui-screens.sh — Screen rendering for specai TUI

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tui-utils.sh"
source "${SCRIPT_DIR}/tui-models.sh"
source "${SCRIPT_DIR}/tui-profiles.sh"

# Resolve configuration file dynamically
if [[ -z "$CONFIG_FILE" ]]; then
  source "${SCRIPT_DIR}/../lib-config.sh"
  CONFIG_FILE=$(get_config_file)
fi

# Read current config value
read_config_value() {
  local key="$1"
  python3 -c "
import json, sys
try:
    with open('${CONFIG_FILE}') as f:
        c = json.load(f)
    keys = '${key}'.split('.')
    val = c
    for k in keys:
        val = val[k]
    print(val)
except:
    print('')
" 2>/dev/null
}

# Show dashboard with current configuration
show_dashboard() {
  clear
  local harness_name="Global"
  if [[ "$CONFIG_FILE" == *"antigravity"* ]]; then
    harness_name="Antigravity / Gemini"
  elif [[ "$CONFIG_FILE" == *"opencode"* ]]; then
    harness_name="OpenCode"
  elif [[ "$CONFIG_FILE" == *"codex"* ]]; then
    harness_name="Codex"
  elif [[ "$CONFIG_FILE" == *"claude"* ]]; then
    harness_name="Claude Code"
  fi

  print_header "🔧 specai configuration (${harness_name})"

  echo -e "${BOLD}Models:${NC}"
  local agents=("implementer" "build-fixer" "code-reviewer" "verifier" "spec-compliance-reviewer" "specai-command" "specai-documentation" "spec-reviewer" "code-quality-reviewer" "final-reviewer")

  for agent in "${agents[@]}"; do
    local model
    model=$(read_config_value "agentModels.${agent}")
    local indicator=""
    if [[ -n "$model" ]]; then
      indicator=$(get_availability_indicator "$model")
    fi
    printf "  %-28s → %s %s\n" "$agent" "${model:-not set}" "$indicator"
  done

  echo ""
  print_divider

  local lang commit senior
  lang=$(read_config_value "language")
  commit=$(read_config_value "commitMode")
  senior=$(read_config_value "seniorMode")
  local soul
  soul=$(read_config_value "soul.preset")

  echo -e "${BOLD}Settings:${NC}"
  echo -e "  Language: ${CYAN}${lang:-auto}${NC}  |  Commit: ${CYAN}${commit:-auto}${NC}  |  Senior: ${CYAN}${senior:-medium}${NC}  |  Soul: ${CYAN}${soul:-default}${NC}"
  echo ""
}

# Show main menu and return selection
show_main_menu() {
  local options=(
    "Select Environment (Harness)"
    "Agent Models"
    "Profiles"
    "Language"
    "Commit Mode"
    "Senior Mode"
    "Soul"
    "Reset Defaults"
    "Exit"
  )

  show_menu "Main Menu" "${options[@]}"
}

# Show agent selector and return agent name
show_agent_selector() {
  local agents=("implementer" "build-fixer" "code-reviewer" "verifier" "spec-compliance-reviewer" "specai-command" "specai-documentation" "spec-reviewer" "code-quality-reviewer" "final-reviewer")

  # Build display list with current models
  local display_list=()
  for agent in "${agents[@]}"; do
    local model
    model=$(read_config_value "agentModels.${agent}")
    display_list+=("${agent} (${model:-not set})")
  done

  local selected
  selected=$(choose_from_list "Select agent" "${display_list[@]}")

  if [[ -n "$selected" ]]; then
    # Extract agent name from "agent (model)" format
    echo "${selected%% (*}"
  fi
}

# Show model selector and return model name
show_model_selector() {
  local agent="$1"
  local current_model
  current_model=$(read_config_value "agentModels.${agent}")

  # Build model list with formatted entries
  local model_names=()
  local model_display=()

  for entry in "${MODEL_CATALOG[@]}"; do
    local model="${entry%%|*}"
    model_names+=("$model")
    model_display+=("$(format_model_entry "$entry")")
  done

  # Add custom model option
  model_names+=("custom")
  model_display+=("✏️  Enter custom model name")

  local selected_display
  selected_display=$(choose_from_list "Select model for ${agent}" "${model_display[@]}")

  if [[ -n "$selected_display" ]]; then
    # Find the index of selected display
    for i in "${!model_display[@]}"; do
      if [[ "${model_display[$i]}" == "$selected_display" ]]; then
        if [[ "${model_names[$i]}" == "custom" ]]; then
          get_input "Enter model name (provider/model)"
        else
          echo "${model_names[$i]}"
        fi
        return
      fi
    done
  fi
}

# Show profile selector and return profile ID
show_profile_selector() {
  local profile_names=()
  local profile_display=()

  for id in "${PROFILE_IDS[@]}"; do
    profile_names+=("$id")
    profile_display+=("$(get_profile_name "$id")\n$(get_profile_description "$id")")
  done

  local selected
  selected=$(choose_from_list "Select profile" "${profile_display[@]}")

  if [[ -n "$selected" ]]; then
    get_profile_id_from_name "$selected"
  fi
}

# Show language selector
show_language_selector() {
  local languages=("auto" "en")
  local display=()
  local labels=("Idioma del usuario (User's language)" "Siempre en inglés (Always English)")

  for i in "${!languages[@]}"; do
    display+=("${languages[$i]} — ${labels[$i]}")
  done

  local selected
  selected=$(choose_from_list "Select language" "${display[@]}")

  if [[ -n "$selected" ]]; then
    echo "${selected%% — *}"
  fi
}

# Show commit mode selector
show_commit_mode_selector() {
  local modes=("auto" "confirm" "manual")
  local display=(
    "auto — Commit automatically without asking"
    "confirm — Ask before each commit"
    "manual — Never commit automatically"
  )

  local selected
  selected=$(choose_from_list "Select commit mode" "${display[@]}")

  if [[ -n "$selected" ]]; then
    echo "${selected%% *}"
  fi
}

# Show senior mode selector
show_senior_mode_selector() {
  local modes=("off" "lite" "medium" "ultra")
  local display=(
    "off — Normal specai, no changes"
    "lite — Build what's asked + suggest lazier alternative"
    "medium — Full ladder enforced, minimalism active (default)"
    "ultra — YAGNI extremist, question the task itself"
  )

  local selected
  selected=$(choose_from_list "Select senior mode" "${display[@]}")

  if [[ -n "$selected" ]]; then
    echo "${selected%% *}"
  fi
}

# Show reset confirmation
show_reset_confirm() {
  echo ""
  warn "This will reset ALL settings to defaults."
  warn "Current config will be lost."
  echo ""

  confirm_action "Continue with reset?"
}
