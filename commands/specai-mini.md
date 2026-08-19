---
description: "Execute Mini mode (grill-me grounding → plan → implement → verify) for small features and bug fixes."
---
Execute Mini mode for a small feature or bug fix:

1. Load specai-grill-me. Inspect relevant code and configuration before asking exactly one design question at a time, and ask only when the codebase cannot answer.
2. Create the six compact execution documents without a branch.
3. Choose implement or backlog.
4. If implementation is chosen, create a feature branch only after PRD approval and the user's implementation choice; backlog creates no branch.
5. Before implementation, preflight scripts/agent-harness-contract.json and dispatch through the active native harness: OpenCode delegate, Codex spawn_agent/wait_agent with multi_agent = true, or Antigravity invoke_subagent. Use a fresh session with fork_context: false and record Max Runtime: 900 seconds, Deadline: 900 seconds, Heartbeat every 30 seconds, and Poll interval: 15 seconds. A missing capability is TASK_BLOCKED: never execute inline or use a silent fallback. Record TASK_STARTED with timestamp, branch, git_hash, task_id, and context.
6. Implement with surgical changes.
7. Verify the fix works against the global goal contract and stop at Gate UA for manual testing and explicit user acceptance before finishing.

Mini creates the same six documents in compact form. The six documents are *-prd.md, *-spec.md, *-designs.md, *-plan.md, *-tasks.md, and *-verify.md. Compactness reduces explanation density and ceremony only; it does not remove exact task instructions, global Given/When/Then criteria, criterion metadata (Criterion type/Invariant/Verification seam), evidence, corrective loop, branch gate, or Gate UA. Mini keeps the shorter flow and may omit the Full-mode per-task code-review and checkpoints. Recover between sessions from *-tasks.md and the Execution Log of *-plan.md; TodoWrite is only the session mirror. Any human approval or review checkpoint is a decision gate only, never persistent session state.

Begin by loading specai-grill-me and grounding the request in the codebase.