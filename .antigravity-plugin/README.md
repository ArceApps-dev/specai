# SpecAI for Antigravity — Installation Guide

## Overview

SpecAI brings agentic development workflows to Antigravity. It provides a complete methodology for AI-assisted software development from design clarification through delivery.

## Installation

SpecAI is distributed as an Antigravity plugin. The easiest way to install it is through the manager script in this repository.

### Option 1: Using the manager script (recommended)

Run the script from the project root:

```bash
./specai install      # one-shot install
./specai update       # re-link after git pull
./specai uninstall    # remove the plugin symlink
```

The install command creates a symlink from the repo's `.antigravity-plugin/` directory to:

`~/.gemini/config/plugins/specai/`

After installation, **restart Antigravity** so it picks up the plugin.

### Option 2: Manual plugin symlink (alternative)

```bash
mkdir -p ~/.gemini/config/plugins
ln -s /path/to/specai/.antigravity-plugin ~/.gemini/config/plugins/specai
```

## Available Skills

After installation, these skills will be available in Antigravity (mirroring the upstream `skills/` directory in this repo):

| Skill | Description |
|-------|-------------|
| **specai-bootstrap** | Session-start rules: how to discover and invoke skills |
| **specai-grill-me** | Socratic one-question-at-a-time interview for design clarification |
| **specai-write-prd** | Synthesize the interview into a 6-section PRD |
| **specai-writing-plans** | Atomic implementation plans with acceptance criteria |
| **specai-subagent-driven-development** | Execute plans task-by-task with the agent team |
| **specai-test-driven-development** | RED-GREEN-REFACTOR cycle |
| **specai-systematic-debugging** | 4-phase root-cause analysis |
| **specai-code-review** | Pre-commit code review |
| **specai-requesting-code-review** | Pre-review checklist |
| **specai-receiving-code-review** | How to respond to review feedback |
| **specai-using-git-worktrees** | Parallel development with isolated branches |
| **specai-finishing-a-development-branch** | Merge / PR / keep / discard workflow |
| **specai-iteration** | User feedback loop after completion |
| **specai-senior-philosophy** | Anti-overengineering decision ladder |
| **specai-verification-before-completion** | Verify before declaring done |
| **specai-antigravity-bridge** | Anti-`enter_plan_mode` guard — keeps Antigravity aligned with the specai flow |

> The list above is a curated subset of all skills shipped in `skills/`. Run `./specai install && ls .antigravity-plugin/skills/` to see what was actually linked into the symlink.

## Quick Start

1. Install: `./specai install`
2. Restart Antigravity.
3. Open a project.
4. Type `/specai-` in the agent chat — Antigravity will autocomplete skill names.

### Example Usage

```
You: /specai-grill-me
Antigravity: (loads the grill-me skill) What would you like to build?

You: A real-time notifications system
Antigravity: (one question at a time — your answer determines the next question)
```

## How It Works

SpecAI turns Antigravity into a multi-agent development team:

1. **Socratic clarification (`grill-me`)** — one question at a time, mapped against the real codebase, no assumptions.
2. **PRD (`write-prd`)** — the resolved tree becomes a 6-section Product Requirements Document.
3. **Plan (`writing-plans`)** — atomic tasks (2–5 min), acceptance criteria, branch-first.
4. **Subagent-driven execution** — each task by an `implementer` → build → review → commit → document.
5. **Verification** — `verifier` checks the plan; **`Gate UA` (user acceptance)** is the only signal that matters.

## Configuration

### Document Language

SpecAI writes documentation in the language you configure. Add to your workspace rules:

```
* Always respond in <your language> for specai skills
```

### Customizing a Single Skill

To override one skill, copy it to your workspace and edit the copy:

```bash
mkdir -p .agents/skills
cp -r ~/.gemini/config/plugins/specai/skills/specai-writing-plans .agents/skills/
# Edit .agents/skills/specai-writing-plans/SKILL.md
```

## Requirements

- Antigravity CLI or IDE (version compatible with Gemini-plugin discovery).
- Google account for authentication.
- Chrome (only if you use browser subagent features).

## Troubleshooting

**Skills not appearing?**
- Restart Antigravity after installation.
- Confirm `~/.gemini/config/plugins/specai` exists and points to this repo's `.antigravity-plugin/`.
- Run `bash scripts/specai-doctor.sh` — it flags drift between `skills/` and the symlinked plugin.

**Skills loading but behaving oddly?**
- Antigravity's `Provide Feedback` in Agent Manager captures useful traces.
- Open an issue: https://github.com/ArceApps/specai/issues

## License

MIT — same as the specai project.
