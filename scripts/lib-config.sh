#!/bin/bash
# lib-config.sh — Shared helper to read specai configuration

CONFIG_DIR="$HOME/.config/specai"

# Resolve active harness config file
get_config_file() {
  # 1. Explicit environment variable override
  if [[ -n "$SPECAI_HARNESS" ]]; then
    echo "${CONFIG_DIR}/config.${SPECAI_HARNESS}.json"
    return
  fi

  # 2. Check if running inside Antigravity agent
  if [[ -n "$ANTIGRAVITY_AGENT" ]]; then
    echo "${CONFIG_DIR}/config.antigravity.json"
    return
  fi

  # 3. Check if parent process is opencode
  local parent_proc
  parent_proc=$(ps -o comm= -p $PPID 2>/dev/null || true)
  if [[ "$parent_proc" == *"opencode"* ]]; then
    echo "${CONFIG_DIR}/config.opencode.json"
    return
  fi

  # 4. Fallback to global config
  echo "${CONFIG_DIR}/config.json"
}

GLOBAL_CONFIG_FILE="${CONFIG_DIR}/config.json"
CONFIG_FILE=$(get_config_file)

# Read value from a specific json file
read_json_val() {
  local file="$1"
  local query="$2"
  local default="$3"
  if [[ -f "$file" ]]; then
    python3 -c "
import json
try:
    with open('$file') as f:
        c = json.load(f)
    keys = '$query'.split('.')
    val = c
    for k in keys:
        val = val[k]
    print(val)
except:
    print('$default')
" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Read model from config (with hierarchical inheritance)
read_model() {
  local agent="$1"
  local default="$2"
  local config_file
  config_file=$(get_config_file)
  
  # 1. Try active harness-specific config file first
  local val
  val=$(read_json_val "$config_file" "agentModels.${agent}" "__NOT_FOUND__")
  if [[ "$val" != "__NOT_FOUND__" ]]; then
    echo "$val"
    return
  fi
  
  # 2. Try global config file
  if [[ "$config_file" != "$GLOBAL_CONFIG_FILE" ]]; then
    val=$(read_json_val "$GLOBAL_CONFIG_FILE" "agentModels.${agent}" "__NOT_FOUND__")
    if [[ "$val" != "__NOT_FOUND__" ]]; then
      echo "$val"
      return
    fi
  fi
  
  # 3. Fallback to default
  echo "$default"
}

# Read language from config
read_language() {
  local config_file
  config_file=$(get_config_file)
  
  local val
  val=$(read_json_val "$config_file" "language" "__NOT_FOUND__")
  if [[ "$val" != "__NOT_FOUND__" ]]; then
    echo "$val"
    return
  fi
  
  if [[ "$config_file" != "$GLOBAL_CONFIG_FILE" ]]; then
    val=$(read_json_val "$GLOBAL_CONFIG_FILE" "language" "__NOT_FOUND__")
    if [[ "$val" != "__NOT_FOUND__" ]]; then
      echo "$val"
      return
    fi
  fi
  
  echo "auto"
}

# Read commit mode from config
read_commit_mode() {
  local config_file
  config_file=$(get_config_file)
  
  local val
  val=$(read_json_val "$config_file" "commitMode" "__NOT_FOUND__")
  if [[ "$val" != "__NOT_FOUND__" ]]; then
    echo "$val"
    return
  fi
  
  if [[ "$config_file" != "$GLOBAL_CONFIG_FILE" ]]; then
    val=$(read_json_val "$GLOBAL_CONFIG_FILE" "commitMode" "__NOT_FOUND__")
    if [[ "$val" != "__NOT_FOUND__" ]]; then
      echo "$val"
      return
    fi
  fi
  
  echo "auto"
}
