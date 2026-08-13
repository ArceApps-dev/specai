---
name: specai-onboarding
description: First-run guide for new specai users. Runs scripts/specai-doctor.sh, validates config, registers subagents, and walks the user through the first /specai-plan invocation.
command: "/specai-onboarding"
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-onboarding

The first 5 minutes of using specai. Read-only by default; offers to apply fixes when something's missing.

## ABSOLUTE RULE (INQUEBRANTABLE)

**This skill NEVER modifies anything without asking.** It validates and reports. The user must confirm each fix explicitly.

## The flow

```
User: /specai-onboarding

Agent:
  1. Run scripts/specai-doctor.sh
  2. Report results: N ok, M warn, K fail
  3. For each fail: explain + offer to fix
  4. For each warn: explain + ask if they want to address
  5. Show the "first plan" walkthrough (5 lines)
  6. Done.
```

## What doctor covers

`scripts/specai-doctor.sh` checks:

1. Config file present (`~/.config/specai/config.json`)
2. Senior mode valid (off/lite/medium/ultra)
3. Document language set
4. Commit mode valid (auto/confirm/manual)
5. Required skills present (10 core: bootstrap, grill-me, write-prd, writing-plans, subagent-driven-development, verification-before-completion, finishing, iteration, senior-philosophy, help)
6. Deprecated skills absent (brainstorming, socratic-clarifier, assumptions-review)
7. Branch state is compatible with the current phase; a protected branch is allowed before the implementation choice
8. `docs/specai/project/` exists
9. OpenCode agents registered (7 core)
10. `subagent-driven-development` skill size ≤ 500 lines
11. No obsolete `brainstorming` references in active docs
12. Cheap-model routing for documentation/command agents

## The "first plan" walkthrough

After doctor reports green (or the user has confirmed fixes):

```
Your setup is healthy. To run your first plan:

  La PRD y los seis documentos se crean sin rama; la rama se crea solo si el usuario elige implementar.

  1. Open your AI assistant (Claude Code, OpenCode, Gemini CLI,
     Cursor, etc.) and run:
       /specai-plan "your idea in one sentence"

  2. specai will guide you through:
       socratic → grill-me → write-prd → approval → six documents
               → choose implement/backlog → branch only if implement
               → per-task cycle → verifier → UA gate → finishing

  3. When all tasks complete and verifier says PASS:
       → specai pauses. YOU test the implementation.
       → Reply with "accept" to merge, or describe issues to iterate.

  4. Before the PRD, specai identifies one affected semantic unit. If its
     project spec is missing, it reports the gap and offers to create it by
     revisar solo el código relevante de esa unidad.

The single most important rule: you do NOT need to remember 11 slash
commands. Just say what you want and specai routes via specai-which.

  /specai-help   ← quick reference + Mermaid flow
  /specai-status ← "where am I?" at any time
```

## Boundaries

**This skill does:**
- Run `scripts/specai-doctor.sh`
- Explain findings
- Offer fixes one by one (with confirmation)
- Show the first-plan walkthrough

**This skill does NOT:**
- Modify config or files without explicit confirmation
- Dispatch subagents to make changes
- Skip the doctor step (it's the point of the skill)

## Recovery when doctor reports fails

| Failure | Fix to offer |
| --- | --- |
| Config file missing | Run `bash scripts/specai-init.sh` (creates default config) |
| Skill missing | Reinstall/update the plugin so its `skills/` dir is refreshed (skills load from the plugin dir, NOT `~/.config/opencode/skills/`) |
| Deprecated skill present | Delete `skills/<name>/` (the doctor named which one) |
| On protected branch before implementation choice | Continue onboarding; create a feature branch only if the user chooses implementation |
| `docs/specai/project/` missing | Run `bash scripts/specai-init.sh` (creates it idempotently) |
| OpenCode agents not registered | Run `bash scripts/setup-agents.sh` |
| `brainstorming` references found | Run `/specai-review` to find them, edit each |
| Cheap-model routing missing | Edit `~/.config/specai/config.json`, set `agentModels.specai-command` and `agentModels.specai-documentation` to `openrouter/deepseek/deepseek-v4-flash-free` |

## When NOT to use this skill

- If you already know specai works (use `/specai-status` instead).
- If you're debugging a specific failure (use `/specai-help` or read `docs/FAILURE-MODES.md`).
