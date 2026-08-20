---
name: specai-agent-models
description: Use when the user asks to change, inspect, or customize which AI model a specai subagent uses, or when they want to override the default model per role (implementer, documenter, build-fixer, verifier, reviewer, etc.)
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Agent Models

Each specai subagent uses a configurable AI model. The authoritative roster and default models are defined only in `scripts/agent-roster.json`; consumers MUST read that file instead of maintaining or presenting a second roster here. Models use the complete `provider/model` format.

**ABSOLUTE RULE: Always use the full provider/model format (e.g., `openrouter/anthropic/claude-sonnet-4`). Never guess or abbreviate model names. Config changes require running `bash scripts/setup-agents.sh` to apply.**

## Config File

Agent models are stored in `~/.config/specai/config.json`:

The `agentModels` keys correspond to the names in `scripts/agent-roster.json`. If the file doesn't exist, defaults are used.

Consumers that need the available agents or their defaults must read `scripts/agent-roster.json` directly. Do not copy its roster or model values into another document.

## How to Change a Model (3 ways)

### Tool call (in conversation)
Use `specai-configure-model`:
```
specai-configure-model agent="implementer" model="minimax/MiniMax-M3"
```

### CLI script
```bash
bash scripts/configure-agents.sh                 # Show current
bash scripts/configure-agents.sh implementer minimax/MiniMax-M3  # Change one
bash scripts/configure-agents.sh --interactive   # Interactive mode
bash scripts/configure-agents.sh --reset         # Reset to defaults
```

### Manual edit
Edit `~/.config/specai/config.json`, then run:
```bash
bash scripts/setup-agents.sh
```

## Validation

Models are validated by OpenCode at agent creation time. Use the full provider/model format (e.g., `minimax/MiniMax-M3`).

## Language Setting

The `language` field in `~/.config/specai/config.json` controls the default language for generated documents (plans, tasks, designs, specs, changelogs, READMEs). Only two options are available:

- `"auto"` (default): match the user's active conversation language
- `"en"`: always generate in English

Change it with:
```bash
bash scripts/configure-agents.sh --language auto
bash scripts/configure-agents.sh --language en
```

## Dynamic Model Selection (taskComplexity)

The `taskComplexity` field in `~/.config/specai/config.json` enables per-task model selection based on task complexity, balancing cost and capability:

```json
{
  "taskComplexity": {
    "low": "openrouter/deepseek/deepseek-v4-flash-free",
    "medium": "minimax/MiniMax-M3",
    "high": "minimax/MiniMax-M3"
  }
}
```

| Tier | Used for | Suggested model |
|------|----------|-----------------|
| **low** | Mechanical tasks: file renames, template updates, doc snippets, config changes | Cheapest viable (flash/free) |
| **medium** | Standard tasks: feature implementation, refactoring, test writing | Default model |
| **high** | Judgment tasks: architecture decisions, complex debugging, security review | Most capable model |

The orchestrator selects the tier before dispatching each task based on: task complexity, file count touched, security/compliance impact, and whether tests exist.

## Flow Modes (flowMode)

The `flowMode` field controls which workflow the orchestrator uses:

- `"auto"` (default): agent determines mode based on task scope
- `"full"`: always use the complete SpecAI flow (grounding → grill-me → write-prd → approval → six documents → choose implement/backlog → branch only if implement → per-task cycle → spec-compliance-reviewer → verifier → HTD de aceptación → Gate UA → finishing)
- `"mini"`: use Mini mode for all tasks (grounding → grill-me → compact six feature artifacts → implementation/backlog choice → branch only if implementation → implement → verify)

Both modes use the same six feature artifacts: `prd.md`, `spec.md`,
`designs.md`, `plan.md`, `tasks.md`, and `verify.md`. Mini reduces content
density and ceremony only; it preserves exact task instructions, global
`Given / When / Then` criteria, criterion metadata, evidence, the corrective
loop, branch timing, and Gate UA. In `full`, the PRD is approved before the
six documents are created. In both modes, the six artifacts are created
without a branch; choosing backlog preserves the feature folder without
creating a branch, and only choosing implementation creates the
implementation branch.

Override per-task with `/specai-execute` or `/specai-mini`.

## Enforcement Gates

Install git hooks to enforce specai discipline at the OS level:

```bash
bash scripts/install-hooks.sh
```

This adds:
- **pre-commit** (`pre-implement.sh`): blocks commits without all six feature artifacts
- **post-commit** (`post-task.sh`): warns on stale living documents

Bypass once with `git commit --no-verify`. Uninstall with `bash scripts/install-hooks.sh --uninstall`.
```
