#!/usr/bin/env bash
# tui-models.sh — Model catalog and provider detection

# Model catalog: "provider/model|description|tier"
# Tiers: economic, balanced, premium
MODEL_CATALOG=(
  # Minimax
  "minimax/MiniMax-M3|minimax flagship model|premium"
  "minimax/MiniMax-M1|minimax fast model|balanced"

  # DeepSeek
  "deepseek/deepseek-v4|deepseek latest|premium"
  "deepseek/deepseek-v4-flash|deepseek fast|balanced"
  "deepseek/deepseek-v4-flash-free|deepseek free tier|economic"

  # OpenAI
  "openai/gpt-4o|GPT-4o multimodal|premium"
  "openai/gpt-4o-mini|GPT-4o Mini fast|balanced"
  "openai/gpt-4.1|GPT-4.1 latest|premium"
  "openai/gpt-4.1-mini|GPT-4.1 Mini|balanced"
  "openai/o3|o3 reasoning model|premium"
  "openai/o4-mini|o4-mini reasoning|balanced"

  # Anthropic
  "anthropic/claude-sonnet-4-20250514|Claude Sonnet 4|premium"
  "anthropic/claude-haiku-3.5|Claude Haiku 3.5 fast|balanced"

  # Google
  "google/gemini-2.5-pro|Gemini 2.5 Pro|premium"
  "google/gemini-2.5-flash|Gemini 2.5 Flash|balanced"
  "google/Gemini 3.5 Flash (High)|Gemini 3.5 Flash High performance|premium"
  "google/Gemini 3.5 Flash|Gemini 3.5 Flash Standard|balanced"
  "google/Gemini 3.5 Flash (Low)|Gemini 3.5 Flash Low cost|economic"

  # Groq
  "groq/llama-3.3-70b|Llama 3.3 70B via Groq|balanced"
  "groq/llama-3.1-8b|Llama 3.1 8B via Groq|economic"

  # Ollama (local)
  "ollama/llama3.3|Llama 3.3 local|balanced"
  "ollama/qwen2.5|Qwen 2.5 local|balanced"
  "ollama/deepseek-v4|DeepSeek v4 local|balanced"
  "ollama/gemma3|Gemma 3 local|economic"

  # Qwen (Chinese models)
  "qwen/qwen-2.5-72b|Qwen 2.5 72B|premium"
  "qwen/qwen-2.5-32b|Qwen 2.5 32B|balanced"
  "qwen/qwen-2.5-7b|Qwen 2.5 7B|economic"

  # Mistral
  "mistral/mistral-large|Mistral Large|premium"
  "mistral/mistral-small|Mistral Small|balanced"

  # OpenRouter
  "openrouter/deepseek/deepseek-v4|DeepSeek via OpenRouter|premium"
  "openrouter/deepseek/deepseek-v4-flash-free|DeepSeek free via OpenRouter|economic"
  "openrouter/meta-llama/llama-3.3-70b|Llama via OpenRouter|balanced"
  "openrouter/anthropic/claude-sonnet-4|Claude via OpenRouter|premium"
  "openrouter/openai/gpt-4o|GPT-4o via OpenRouter|premium"
  "openrouter/google/gemini-2.5-pro|Gemini via OpenRouter|premium"
)

# Get all unique providers
get_providers() {
  local providers=()
  for entry in "${MODEL_CATALOG[@]}"; do
    local model="${entry%%|*}"
    local provider="${model%%/*}"
    # Add if not already in array
    local found=0
    for p in "${providers[@]}"; do
      [[ "$p" == "$provider" ]] && found=1 && break
    done
    [[ $found -eq 0 ]] && providers+=("$provider")
  done
  echo "${providers[@]}"
}

# Get models for a specific provider
# Usage: get_models_by_provider "openai"
get_models_by_provider() {
  local provider="$1"
  local models=()

  for entry in "${MODEL_CATALOG[@]}"; do
    local model="${entry%%|*}"
    if [[ "$model" == "${provider}/"* ]]; then
      models+=("$entry")
    fi
  done

  echo "${models[@]}"
}

# Get models by tier
# Usage: get_models_by_tier "economic"
get_models_by_tier() {
  local tier="$1"
  local models=()

  for entry in "${MODEL_CATALOG[@]}"; do
    local entry_tier="${entry##*|}"
    if [[ "$entry_tier" == "$tier" ]]; then
      models+=("$entry")
    fi
  done

  echo "${models[@]}"
}

# Get model description
# Usage: get_model_description "openai/gpt-4o"
get_model_description() {
  local target="$1"

  for entry in "${MODEL_CATALOG[@]}"; do
    local model="${entry%%|*}"
    if [[ "$model" == "$target" ]]; then
      local desc="${entry#*|}"
      desc="${desc%|*}"
      echo "$desc"
      return 0
    fi
  done

  echo ""
}

# Get model tier
# Usage: get_model_tier "openai/gpt-4o"
get_model_tier() {
  local target="$1"

  for entry in "${MODEL_CATALOG[@]}"; do
    local model="${entry%%|*}"
    if [[ "$model" == "$target" ]]; then
      echo "${entry##*|}"
      return 0
    fi
  done

  echo "unknown"
}

# Detect available providers based on environment variables
detect_providers() {
  local available=()

  [[ -n "${OPENAI_API_KEY:-}" ]] && available+=("openai")
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] && available+=("anthropic")
  [[ -n "${MINIMAX_API_KEY:-}" ]] && available+=("minimax")
  [[ -n "${DEEPSEEK_API_KEY:-}" ]] && available+=("deepseek")
  if [[ -n "$ANTIGRAVITY_AGENT" ]]; then
    available+=("google")
  else
    [[ -n "${GOOGLE_API_KEY:-}" ]] && available+=("google")
  fi
  [[ -n "${GROQ_API_KEY:-}" ]] && available+=("groq")
  [[ -n "${OPENROUTER_API_KEY:-}" ]] && available+=("openrouter")
  [[ -n "${QWEN_API_KEY:-}" ]] && available+=("qwen")
  [[ -n "${MISTRAL_API_KEY:-}" ]] && available+=("mistral")

  # Detect Ollama local
  if command -v ollama &>/dev/null; then
    if curl -s --connect-timeout 2 http://localhost:11434/api/tags &>/dev/null; then
      available+=("ollama")
    fi
  fi

  echo "${available[@]}"
}

# Check if a specific provider is available
# Usage: is_provider_available "openai"
is_provider_available() {
  local provider="$1"
  local available
  available=($(detect_providers))

  for p in "${available[@]}"; do
    [[ "$p" == "$provider" ]] && return 0
  done

  return 1
}

# Get availability indicator for a model
# Usage: get_availability_indicator "openai/gpt-4o"
# Returns: "●" if available, "○" if not
get_availability_indicator() {
  local model="$1"
  local provider="${model%%/*}"

  if is_provider_available "$provider"; then
    echo "●"
  else
    echo "○"
  fi
}

# Format model entry for display
# Usage: format_model_entry "openai/gpt-4o|GPT-4o multimodal|premium"
format_model_entry() {
  local entry="$1"
  local model="${entry%%|*}"
  local desc="${entry#*|}"
  desc="${desc%|*}"
  local tier="${entry##*|}"
  local indicator
  indicator=$(get_availability_indicator "$model")

  # Color based on tier
  local tier_color="$NC"
  case "$tier" in
    economic) tier_color="$GREEN" ;;
    balanced) tier_color="$YELLOW" ;;
    premium) tier_color="$MAGENTA" ;;
  esac

  printf "%s %-40s ${DIM}%s${NC} ${tier_color}[%s]${NC}" "$indicator" "$model" "$desc" "$tier"
}

# Get all model names (for selection lists)
get_all_model_names() {
  local names=()
  for entry in "${MODEL_CATALOG[@]}"; do
    names+=("${entry%%|*}")
  done
  echo "${names[@]}"
}
