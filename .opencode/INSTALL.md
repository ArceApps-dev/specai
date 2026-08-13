# Installing specai for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- OpenCode Go subscription (for model access)

## Installation

Add specai to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["specai@git+https://github.com/ArceApps/specai.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all skills.

Verify by asking: "Tell me about your specai"

## Agent Setup

specai uses dedicated subagents per role. Run the setup script:

```bash
bash scripts/setup-agents.sh
```

Or create them manually (see `/AGENTS.md` for the exact commands).

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load specai/grill-me
```

## Updating

OpenCode installs specai through a git-backed package spec. Some OpenCode
and Bun versions pin that resolved git dependency in a lockfile or cache, so a
restart may not pick up the newest specai commit. If updates do not appear,
clear OpenCode's package cache or reinstall the plugin.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i specai`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Skills not found

1. Use `skill` tool to list what's discovered
2. Check that the plugin is loading (see above)

### Tool mapping

When skills reference Claude Code tools:
- `TodoWrite` → `todowrite`
- `Task` with subagents → Use `delegate(prompt, agent="name")`
- `Skill` tool → OpenCode's native `skill` tool
- File operations → your native tools

## Getting Help

- Report issues: https://github.com/ArceApps/specai/issues
- Full documentation: https://github.com/ArceApps/specai
