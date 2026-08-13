---
name: specai-command
description: Execute shell commands with auto-truncation, caching, and trace support. Single and batch modes.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

> **ORCHESTRATOR GATE:** If you are the controller reading this skill for guidance,
> do NOT execute these instructions inline. Dispatch to the `specai-command` subagent.
> This skill is the executor contract, not orchestrator guidance.
>
> **EXECUTOR OVERRIDE:** If you ARE the `specai-command` subagent, the gate above does
> not apply to you. Execute the instructions below. Do not delegate. Do not ask the
> controller for permission to proceed.

# specai-command

**Purpose:** Centralized command execution. Runs shell commands and returns
results efficiently — output is auto-truncated to avoid token waste.

## ABSOLUTE RULE (INQUEBRANTABLE)

**The ONLY subagent allowed to execute shell commands. Any other agent (except implementer for build/test verification) caught running commands directly is violating the contract. Zero tolerance.**

**All git operations, builds, test suites, linting, and any shell command MUST flow through specai-command.**

## Features

| Feature | Description |
|---------|-------------|
| **Auto-truncation** | First 10 + last 5 lines by default. Full stderr on failure. |
| **`full_log: true`** | Disable truncation, get complete output. |
| **Command cache** | Skip execution if watched files haven't changed. |
| **Batch mode** | Run multiple commands sequentially, stop on first failure. |
| **Auto-retry** | One retry on transient errors (network, resource). |
| **Trace** | Optional input/output character/line metrics. |

## When to Use

- Any subagent needs to run a build/compile command
- Any subagent needs to run tests
- Any subagent needs git operations (commit, branch, status)
- Any subagent needs to execute ANY shell command

## Cache Strategy

Used to avoid redundant builds. Flow:

1. After first `npm run build`, specai-command computes `file_hash` of `src/`
2. Controller stores this hash
3. Before next build, controller sends `cache_watch: ["src/"]` + `cache_key: <stored_hash>`
4. If files unchanged → `CACHED` (0 tokens wasted)
5. If files changed → runs build, returns new hash

This is especially valuable when multiple tasks only touch tests or docs
but not source code.

## Rules for Other Subagents

- You MUST NOT run any shell command directly
- You MUST delegate ALL command execution to `specai-command`
- Exception: `implementer` may run build/test commands to verify its own work
- Use `full_log: true` only when you need the complete output
- Use `cache_watch` for builds that may be redundant

## Integration

Dispatched via `delegate(prompt=[command + context], agent="specai-command")`.

Prompt template: `./command-prompt.md`
