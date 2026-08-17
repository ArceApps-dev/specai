---
name: specai-antigravity-bridge
description: Use when Antigravity's plan mode conflicts with the specai flow — guards against parallel plan creation when _plan.md/_tasks.md exist. Activates on keywords: "plan mode", "specai flow", "enter_plan_mode", "AGENTS.md", "_plan.md", "_tasks.md".
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

## Problem

Antigravity activates its own `enter_plan_mode` tool by default. Inside a project running the specai workflow, this means it can propose a parallel plan that ignores `_plan.md` / `_tasks.md` and skips the socratic → grill-me → planning gates. The bridge keeps that plan mode behind the SpecAI gates and routes approved role work through Antigravity's native `invoke_subagent` harness.

## Behavior Rules

These are absolute directives. Follow them exactly.

1. NEVER call `enter_plan_mode` if `_plan.md` or `_tasks.md` exist in the working tree.
2. NEVER propose a parallel plan; read the existing `_plan.md` and follow it task-by-task.
3. If no specai plan exists AND the user explicitly invokes `specai:plan` (or `/specai-plan`), follow the socratic flow before writing any plan.
4. If neither condition holds, `enter_plan_mode` is permitted (default Antigravity behavior).
5. During an approved implementation, dispatch only the named role through `invoke_subagent` with a fresh session and the minimal handoff allowlist.
6. Apply the shared harness policy: `Max Runtime: 900 seconds`, `Deadline: 900 seconds`, `Heartbeat every 30 seconds`, and bounded polling. A missing native capability is `TASK_BLOCKED`; never execute inline or use a silent fallback.
7. Serialize writes to `_plan.md` and `_tasks.md` through `specai-documentation`; command execution belongs to `specai-command`.

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

For an approved implementation, the next dispatch is always native:
`invoke_subagent(role, fresh_session, minimal_handoff)`. If the role cannot be
resolved or the harness lacks the required capability, stop as `TASK_BLOCKED`
and report the repair action.

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
5. For the task handoff, Antigravity calls `invoke_subagent` for the canonical role, keeps the handle through non-terminal polling, and records the lifecycle event in the living documents.

Counter-example: you open Antigravity in a brand-new repo and type `let's build X`.

1. No `_plan.md` exists, so the skill does not block plan mode.
2. Antigravity enters its built-in plan mode (or, if you prefer specai flow, you can invoke `/specai-plan` explicitly to switch to the socratic path).

## References

- `specai:bootstrap` — the entry-point skill that teaches how to invoke all specai skills correctly.
- `specai:writing-plans` — produces the `_plan.md` / `_tasks.md` this guard protects.
- `specai:subagent-driven-development` — the per-task execution loop.
- `scripts/agent-harness-contract.json` — shared dispatch, capability, and deadline contract.
- `AGENTS.md` (this repo) — the root rule file that Antigravity reads.
