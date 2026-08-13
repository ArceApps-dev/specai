# specai for OpenCode

Complete guide for using specai with [OpenCode.ai](https://opencode.ai).

## Installation

Add specai to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["specai@git+https://github.com/ArceApps/specai.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager.

specai skills are loaded by the plugin's custom `skill` tool from the plugin's
own directory. They are deliberately NOT copied to `~/.config/opencode/skills/`,
because OpenCode auto-generates a slash command for every skill found there —
only the real slash commands (from `commands.json`) should appear.

Verify by asking: "Tell me about your specai"

## Setup

Run the agent setup script:

```bash
bash scripts/setup-agents.sh
```

This registers the seven core subagents defined in `scripts/agent-roster.json`:
- `implementer`
- `build-fixer`
- `code-reviewer`
- `verifier`
- `spec-compliance-reviewer`
- `specai-command`
- `specai-documentation`

## Usage

### Finding Skills

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
```

### Loading a Skill

```
use skill tool to load specai/brainstorming
```

### Personal Skills

Create your own skills in `~/.config/opencode/skills/` or `.opencode/skills/`.

## How It Works

The plugin does two things:

1. **Injects bootstrap context** via `experimental.chat.messages.transform` hook
2. **Registers slash commands** from `.opencode/commands.json` via the `config` hook

specai skills are loaded on demand by the plugin's overridden `skill` tool and
are never registered in OpenCode's skill system, so no slash command is
auto-generated per skill.

### Tool Mapping

Skills written for Claude Code are automatically adapted for OpenCode:

- `TodoWrite` → `todowrite`
- `Task` with subagents → `delegate(prompt, agent="name")`
- `Skill` tool → OpenCode's native `skill` tool
- File operations → Native OpenCode tools

## Troubleshooting

### Plugin not loading

1. Check OpenCode logs: `opencode run --print-logs "hello" 2>&1 | grep -i specai`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Skills not found

1. Use OpenCode's `skill` tool to list available skills
2. Check that the plugin is loading (see above)

## Getting Help

- Report issues: https://github.com/ArceApps/specai/issues
- Main documentation: https://github.com/ArceApps/specai
