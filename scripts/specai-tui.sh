#!/usr/bin/env bash
# specai-tui.sh — Professional TUI for configuring specai

set -eo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
ROSTER_FILE="${SCRIPT_DIR}/agent-roster.json"

# Source library files
source "${LIB_DIR}/tui-utils.sh"
source "${LIB_DIR}/tui-models.sh"
source "${LIB_DIR}/tui-profiles.sh"
source "${LIB_DIR}/tui-screens.sh"

# Source configuration helper
source "${SCRIPT_DIR}/lib-config.sh"
CONFIG_FILE=$(get_config_file)

SETUP_SCRIPT="${SCRIPT_DIR}/setup-agents.sh"
SOUL_DIR="${SCRIPT_DIR}/../souls"

# Ensure config directory exists
write_default_config() {
  local antigravity=false
  [[ "$CONFIG_FILE" == *"antigravity"* ]] && antigravity=true

  python3 - "$ROSTER_FILE" "$CONFIG_FILE" "$antigravity" <<'PY'
import json
import sys

roster_path, config_path, antigravity = sys.argv[1:]
with open(roster_path, encoding="utf-8") as f:
    core_models = {
        agent["name"]: agent["defaultModel"] for agent in json.load(f)["agents"]
    }

config = {
    "agentModels": core_models,
    "language": "auto",
    "commitMode": "auto",
    "seniorMode": "medium",
    "judgment_day": False,
}
with open(config_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
PY
}

ensure_config() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    write_default_config
    success "Created default config: $CONFIG_FILE"
  fi
}

# Write a single agent model
write_agent_model() {
  local agent="$1"
  local model="$2"

  python3 - "${CONFIG_FILE}" "${agent}" "${model}" <<'PY'
import json
import sys
config_file, agent, model = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
if 'agentModels' not in c:
    c['agentModels'] = {}
c['agentModels'][agent] = model
with open(config_file, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2)
PY
}

# Write a config value
write_config_value() {
  local key="$1"
  local value="$2"

  python3 - "${CONFIG_FILE}" "${key}" "${value}" <<'PY'
import json
import sys
config_file, key, value = sys.argv[1:]
with open(config_file, encoding='utf-8') as f:
    c = json.load(f)
keys = key.split('.')
d = c
for k in keys[:-1]:
    if k not in d:
        d[k] = {}
    d = d[k]
d[keys[-1]] = value
with open(config_file, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2)
PY
}

# Apply profile to config
apply_profile() {
  local profile_id="$1"
  local models
  models=($(get_profile_models "$profile_id"))

  for entry in "${models[@]}"; do
    local agent="${entry%%=*}"
    local model="${entry#*=}"
    write_agent_model "$agent" "$model"
  done
}

# Reset config to defaults
reset_config() {
  rm -f "$CONFIG_FILE"
  ensure_config
}

# Apply changes by running setup-agents.sh
apply_changes() {
  if [[ -f "$SETUP_SCRIPT" ]]; then
    with_spinner "Applying changes..." bash "$SETUP_SCRIPT"
  else
    warn "setup-agents.sh not found, changes saved but not applied"
  fi
}

# Handle agent model editing
handle_agent_models() {
  while true; do
    local agent
    agent=$(show_agent_selector)

    if [[ -z "$agent" ]]; then
      break
    fi

    local model
    model=$(show_model_selector "$agent")

    if [[ -n "$model" ]]; then
      write_agent_model "$agent" "$model"
      success "Set ${agent} → ${model}"
      apply_changes
    fi
  done
}

# Handle profile selection
handle_profiles() {
  local profile_id
  profile_id=$(show_profile_selector)

  if [[ -z "$profile_id" ]]; then
    return
  fi

  # Show preview
  echo ""
  format_profile_preview "$profile_id"
  echo ""

  if confirm_action "Apply this profile?"; then
    apply_profile "$profile_id"
    success "Profile applied"
    apply_changes
  fi
}

# Handle language change
handle_language() {
  local lang
  lang=$(show_language_selector)

  if [[ -n "$lang" ]]; then
    write_config_value "language" "$lang"
    success "Language set to: $lang"
    apply_changes
  fi
}

# Handle commit mode change
handle_commit_mode() {
  local mode
  mode=$(show_commit_mode_selector)

  if [[ -n "$mode" ]]; then
    write_config_value "commitMode" "$mode"
    success "Commit mode set to: $mode"
    apply_changes
  fi
}

# Handle senior mode change
handle_senior_mode() {
  local mode
  mode=$(show_senior_mode_selector)

  if [[ -n "$mode" ]]; then
    write_config_value "seniorMode" "$mode"
    success "Senior mode set to: $mode"
    apply_changes
  fi
}

handle_soul() {
  local presets=()
  shopt -s nullglob
  for file in "$SOUL_DIR"/*.md; do presets+=("$(basename "$file" .md)"); done
  shopt -u nullglob
  presets+=("custom")
  local selected
  selected=$(choose_from_list "Select soul preset" "${presets[@]}")
  [[ -z "$selected" ]] && return
  mkdir -p "$CONFIG_DIR"
  if [[ "$selected" == "custom" ]]; then
    touch "$CONFIG_DIR/soul.md"
    "${EDITOR:-vi}" "$CONFIG_DIR/soul.md"
  else
    cp "$SOUL_DIR/${selected}.md" "$CONFIG_DIR/soul.md"
  fi
  python3 - "$CONFIG_FILE" "$selected" <<'PY'
import json, sys
path, preset = sys.argv[1:]
with open(path) as f: c = json.load(f)
c['soul'] = {'path': 'soul.md', 'preset': preset}
with open(path, 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
PY
  success "Soul set to: $selected"
}

# Handle reset
handle_reset() {
  if show_reset_confirm; then
    reset_config
    success "Configuration reset to defaults"
    apply_changes
  fi
}

# Handle harness change
handle_harness() {
  local options=(
    "Global (config.json)"
    "Antigravity / Gemini (config.antigravity.json)"
    "OpenCode (config.opencode.json)"
    "Codex (config.codex.json)"
    "Claude Code (config.claude.json)"
  )

  local selected
  selected=$(choose_from_list "Select Environment to Configure" "${options[@]}")

  if [[ -n "$selected" ]]; then
    case "$selected" in
      "Global (config.json)")
        CONFIG_FILE="${CONFIG_DIR}/config.json"
        ;;
      "Antigravity / Gemini (config.antigravity.json)")
        CONFIG_FILE="${CONFIG_DIR}/config.antigravity.json"
        ;;
      "OpenCode (config.opencode.json)")
        CONFIG_FILE="${CONFIG_DIR}/config.opencode.json"
        ;;
      "Codex (config.codex.json)")
        CONFIG_FILE="${CONFIG_DIR}/config.codex.json"
        ;;
      "Claude Code (config.claude.json)")
        CONFIG_FILE="${CONFIG_DIR}/config.claude.json"
        ;;
    esac
    
    # Resolve SPECAI_HARNESS name
    SPECAI_HARNESS=$(echo "$CONFIG_FILE" | sed -E 's/.*config\.([a-z_]+)\.json/\1/; s/.*config\.json/global/')
    if [[ "$SPECAI_HARNESS" == "global" ]]; then
      unset SPECAI_HARNESS
    fi
    
    ensure_config
    success "Switched active environment to: $selected"
    apply_changes
  fi
}

# Main loop
main() {
  ensure_config

  while true; do
    show_dashboard

    local choice
    choice=$(show_main_menu)

    case "$choice" in
      "Select Environment (Harness)")
        handle_harness
        ;;
      "Agent Models")
        handle_agent_models
        ;;
      "Profiles")
        handle_profiles
        ;;
      "Language")
        handle_language
        ;;
      "Commit Mode")
        handle_commit_mode
        ;;
      "Senior Mode")
        handle_senior_mode
        ;;
      "Soul")
        handle_soul
        ;;
      "Reset Defaults")
        handle_reset
        ;;
      "Exit"|"")
        echo ""
        info "Configuration saved."
        break
        ;;
    esac
  done
}

# Run main
main
