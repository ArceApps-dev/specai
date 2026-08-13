---
name: specai-antigravity-bridge
description: Use when Antigravity's plan mode conflicts with the specai flow — guards against parallel plan creation when _plan.md/_tasks.md exist. Activates on keywords: "plan mode", "specai flow", "enter_plan_mode", "AGENTS.md", "_plan.md", "_tasks.md".
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

## Problem

Antigravity activates its own `enter_plan_mode` tool by default. Inside a project running the specai workflow, this means it proposes a parallel plan that ignores `_plan.md` / `_tasks.md` and skips the socratic → brainstorming → planning gates. OpenCode and Claude Code respect the specai rules in `AGENTS.md`; Antigravity does not.

## Behavior Rules

These are absolute directives. Follow them exactly.

1. NEVER call `enter_plan_mode` if `_plan.md` or `_tasks.md` exist in the working tree.
2. NEVER propose a parallel plan; read the existing `_plan.md` and follow it task-by-task.
3. If no specai plan exists AND the user explicitly invokes `specai:plan` (or `/specai-plan`), follow the socratic flow before writing any plan.
4. If neither condition holds, `enter_plan_mode` is permitted (default Antigravity behavior).

If you violate these rules, the developer must restart the session.

## Decision Tree

> User request
>    │
>    ├── `_plan.md` OR `_tasks.md` exists?
>    │     YES → read, follow, do NOT enter plan mode
>    │     NO  ↓
>    ├── User invoked `specai:plan` explicitly?
>    │     YES → socratic → brainstorming → writing-plans
>    │     NO  → `enter_plan_mode` is permitted (default Antigravity behavior)

## AGENTS.md Guard Block

For defense in depth, paste this block at the top of your project's `AGENTS.md`. Antigravity reads `AGENTS.md` by default — this block tells it explicitly to respect the specai flow.

```markdown
## Antigravity Bridge — specai mode

If `_plan.md` or `_tasks.md` exist in this repo, follow them strictly. DO NOT call `enter_plan_mode` and DO NOT propose a new plan. Branch discipline applies: any code change happens on `feature/<repo>_<slug>`, never on `main`. Commit per atomic task.
```

## Workflow Example

You open Antigravity in a repo where `specai:plan` already ran (so `_plan.md` and `_tasks.md` exist).

1. You type: `add a logout button`.
2. Antigravity matches the keyword `_plan.md` and loads `specai-antigravity-bridge`.
3. The skill instructs Antigravity to read `_plan.md` and `_tasks.md` and follow them.
4. Antigravity identifies the next pending task and proceeds — without calling `enter_plan_mode`.

Counter-example: you open Antigravity in a brand-new repo and type `let's build X`.

1. No `_plan.md` exists, so the skill does not block plan mode.
2. Antigravity enters its built-in plan mode (or, if you prefer specai flow, you can invoke `/specai-plan` explicitly to switch to the socratic path).

## References

- `specai:bootstrap` — the entry-point skill that teaches how to invoke all specai skills correctly.
- `specai:writing-plans` — produces the `_plan.md` / `_tasks.md` this guard protects.
- `specai:subagent-driven-development` — the per-task execution loop.
- `AGENTS.md` (this repo) — the root rule file that Antigravity reads.
