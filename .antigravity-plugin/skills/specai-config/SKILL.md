---
name: specai-config
description: Show or change specai configuration (models, language)
---

# Configure specai

Read and configure agent models or language setting for specai.

## ABSOLUTE RULE

**After ANY config change, MUST run `bash scripts/setup-agents.sh` to apply. Config changes without re-running setup = agents running with stale config.**

## Steps

1. **Read Configuration:** Read the current configuration from `~/.config/specai/config.json`.
2. **Show Configuration:** Display the current agent models and language setting to the user.
3. **Prompt for Changes:** Ask the user if they want to modify the models or language.
4. **Apply Changes:**
   - If they request a model change, use the configure command or update the json directly.
   - If they request a language change, update the configuration.
   - You can also run the configuration script:
     ```bash
     bash scripts/configure-agents.sh
     ```
5. **Verify and Setup:** After any change, run `bash scripts/setup-agents.sh` to update the subagents configuration.

## Configuration Options

| Key | Values | Description | Default |
|-----|--------|-------------|--------|
| `judgment_day` | `true` / `false` | Whether to run dual-blind review before each PR | `false` |

## judgment_day

When enabled, two independent reviewer subagents analyze the code in parallel before
every PR is created. Only issues confirmed by both reviewers get fixed. This catches
architectural drift and missing error handling that tests do not cover.

Token cost: ~3-5x a single reviewer, once per feature (not per task).
Recommended: enable for features with significant architectural surface area.

The setting is read at flow start (brainstorming) and propagated through the session.
You will not be prompted mid-flow.

```bash
# Show current Judgment Day setting
specai config show judgment_day

# Enable Judgment Day (dual-blind review before each PR)
specai config set judgment_day true

# Disable Judgment Day
specai config set judgment_day false
```
