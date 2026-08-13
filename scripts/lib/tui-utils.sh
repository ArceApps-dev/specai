#!/usr/bin/env bash
# tui-utils.sh — Utility functions for specai TUI

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Detect if gum is available
has_gum() {
  command -v gum &>/dev/null
}

# Print styled header
print_header() {
  local title="$1"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}  ${title}${NC}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo ""
}

# Print section divider
print_divider() {
  echo -e "${DIM}───────────────────────────────────────────────────${NC}"
}

# Show menu with gum or bash fallback
# Usage: show_menu "Title" "Option 1" "Option 2" "Option 3"
# Returns: selected item text
show_menu() {
  local title="$1"
  shift
  local options=("$@")

  if has_gum; then
    gum choose --header "$title" "${options[@]}"
  else
    # Bash fallback with arrow navigation
    local selected=0
    while true; do
      clear
      print_header "$title"

      for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
          echo -e " ${CYAN}>${NC} ${BOLD}${options[$i]}${NC}"
        else
          echo -e "   ${options[$i]}"
        fi
      done

      echo ""
      echo -e "${DIM}↑↓ Navigate  Enter Select  q Back${NC}"

      read -rsn1 key
      case "$key" in
        $'\x1b')
          read -rsn2 key
          case "$key" in
            '[A') ((selected > 0)) && ((selected--)) ;;
            '[B') ((selected < ${#options[@]}-1)) && ((selected++)) ;;
          esac
          ;;
        '') echo "${options[$selected]}"; return 0 ;;
        q) return 1 ;;
      esac
    done
  fi
}

# Choose from list with gum or bash
# Usage: choose_from_list "Header" "item1" "item2" ...
# Returns: selected item
choose_from_list() {
  local header="$1"
  shift
  local items=("$@")

  if has_gum; then
    gum choose --header "$header" "${items[@]}"
  else
    show_menu "$header" "${items[@]}"
  fi
}

# Get text input with gum or bash
# Usage: get_input "Prompt" "default value"
# Returns: user input
get_input() {
  local prompt="$1"
  local default="${2:-}"

  if has_gum; then
    gum input --placeholder "$prompt" --value "$default"
  else
    read -rp "$prompt [$default]: " input
    echo "${input:-$default}"
  fi
}

# Confirm with gum or bash
# Usage: confirm_action "Are you sure?"
# Returns: 0=yes, 1=no
confirm_action() {
  local message="$1"

  if has_gum; then
    gum confirm "$message"
  else
    read -rp "$message [y/N]: " answer
    [[ "$answer" =~ ^[yYsS]$ ]]
  fi
}

# Spinner with gum or bash
# Usage: with_spinner "Loading..." command args...
with_spinner() {
  local title="$1"
  shift

  if has_gum; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    echo -e "${DIM}${title}${NC}"
    "$@"
  fi
}

# Print success message
success() {
  echo -e "${GREEN}✓${NC} $1"
}

# Print error message
error() {
  echo -e "${RED}✗${NC} $1"
}

# Print warning message
warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Print info message
info() {
  echo -e "${BLUE}ℹ${NC} $1"
}
