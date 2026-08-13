---
name: specai-status
description: Show at-a-glance state of the current specai flow — branch, last commits, latest execution-log entries, next pending task, verifier verdict.
command: "/specai-status"
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-status

Quick, visual status of the current specai run. **Read-only.** Does not modify anything.

## When to use

- "Where am I in the flow?"
- "What's the latest commit on this branch?"
- "What's the next task?"
- "Did the verifier pass?"
- "Is there an iteration log entry I should read?"

## What it shows

```
═══════════════════════════════════════════════════════════════
  specai STATUS  —  feature/specai_<feature>
═══════════════════════════════════════════════════════════════

📍 Branch      feature/specai_<feature>  (✓ not main/master/dev)
🕒 Last commit 3dd1f19  align audit work with /specai-audit-plan…
📁 Plan folder docs/specai/20260708-audit-driven-refactor/

📊 Plan status
   Designs   ✅ present
   Plan      ✅ present (Architecture: 3 sections)
   Tasks     ⏳ 7/22 ticked (32%)
   Verify    ⏳ 0/22 criteria met

🤖 Last verifier verdict  PASS / FAIL / PARTIAL / not run

📜 Last 5 execution log entries
   ### [2026-07-08 13:50] Q1: migrate IMPROVEMENT_PLAN.md
   ### [2026-07-08 13:55] Q2: remove legacy agents
   …

🟢 NEXT TASK
   Task 8 / 22: A1 — rewrite Complete Flow in AGENTS.md

═══════════════════════════════════════════════════════════════
```

## How to compute

1. `git rev-parse --abbrev-ref HEAD` → branch
2. `git log -1 --format='%h %s'` → last commit
3. Glob `docs/specai/<spec-name>/` → plan folder
4. Read `<spec-name>-tasks.md`, count `- [x]` vs `- [ ]` → task progress
5. Read `<spec-name>-verify.md` → criteria progress
6. Grep `### Verifier verdict` or scan last 30 lines of execution log → verifier result
7. Grep last 5 lines `### \[\d` in execution log → recent entries
8. Read the first `- [ ]` line of `_tasks.md` → next task

## Boundaries

**This skill does:**
- Read git state
- Read 4 plan files
- Print a compact status report

**This skill does NOT:**
- Modify anything
- Dispatch any subagent
- Move to next task automatically

If you want to act on the status, say "next" or "continue" — that re-engages the controller, which will dispatch the next implementer.