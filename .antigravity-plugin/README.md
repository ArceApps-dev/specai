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

The install command first synchronizes the complete Antigravity projection from
the canonical `skills/` directory. It uses relative skill symlinks when the
environment supports them and materializes equivalent `SKILL.md` copies when
symlinks are unavailable. It then creates a symlink from the repo's
`.antigravity-plugin/` directory to:

`~/.gemini/config/plugins/specai/`

After installation, **restart Antigravity** so it picks up the plugin.

### Option 2: Manual plugin symlink (alternative)

```bash
./scripts/sync-antigravity-plugin.sh --check
mkdir -p ~/.gemini/config/plugins
ln -s /path/to/specai/.antigravity-plugin ~/.gemini/config/plugins/specai
```

## Available Skills

After installation, Antigravity exposes exactly 39 skills from the canonical
`skills/` directory in this repository:

`specai-adr`, `specai-agent-clarification`, `specai-agent-models`,
`specai-anti-bloat`, `specai-antigravity-bridge`,
`specai-assumptions-consolidation`, `specai-audit-plan`, `specai-backlog`,
`specai-bootstrap`, `specai-checkpoints`, `specai-code-review`,
`specai-command`, `specai-dispatching-parallel-agents`,
`specai-documentation`, `specai-domain-modeling`, `specai-evals`,
`specai-executing-plans`, `specai-finishing-a-development-branch`,
`specai-grill-me`, `specai-help`, `specai-improve-codebase-architecture`,
`specai-iteration`, `specai-judgment-day`, `specai-living-documents`,
`specai-onboarding`, `specai-plan`, `specai-receiving-code-review`,
`specai-requesting-code-review`, `specai-senior-philosophy`, `specai-status`,
`specai-subagent-driven-development`, `specai-systematic-debugging`,
`specai-test-driven-development`, `specai-using-git-worktrees`,
`specai-verification-before-completion`, `specai-which`, `specai-write-prd`,
`specai-writing-plans`, and `specai-writing-skills`.

The projection contains one entry for every canonical `skills/<name>/SKILL.md`.
Run `./scripts/sync-antigravity-plugin.sh --check` to verify that it is
complete and synchronized.

## Native subagents

Antigravity also discovers exactly seven native subagent definitions under
`.antigravity-plugin/agents/`, derived from `scripts/agent-roster.json`:

`implementer`, `build-fixer`, `code-reviewer`, `verifier`,
`spec-compliance-reviewer`, `specai-command`, and `specai-documentation`.

Each definition uses `subagent: true`, `mainAgent: false`, a sandbox command
policy, and a minimal role-specific tool allowlist. The bridge dispatches them
with `invoke_subagent`; missing native capacity is a blocked handoff, never an
inline fallback. The read-only diagnostic is:

```bash
bash scripts/specai-harness-doctor.sh --json
```

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
3. **Plan (`writing-plans`)** — atomic tasks (2–5 min), acceptance criteria, and a branch only after approval and the implementation choice.
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
- Run `bash scripts/sync-antigravity-plugin.sh --check` — it flags drift between `skills/` and the plugin projection.

**Skills loading but behaving oddly?**
- Antigravity's `Provide Feedback` in Agent Manager captures useful traces.
- Open an issue: https://github.com/ArceApps/specai/issues

## License

MIT — same as the specai project.
