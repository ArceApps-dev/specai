---
description: "Execute Mini mode (grill-me grounding → plan → implement → verify → HTD de aceptación → Gate UA) for small features and bug fixes."
---
Execute Mini mode for a small feature or bug fix:

1. Load specai-grill-me. Inspect relevant code and configuration before asking exactly one design question at a time, and ask only when the codebase cannot answer.
2. Create the six compact execution documents without a branch.
3. Choose implement or backlog.
4. If implementation is chosen, create a feature branch only after PRD approval and the user's implementation choice; backlog creates no branch.
5. Before implementation, preflight scripts/agent-harness-contract.json and dispatch through the active native harness: OpenCode delegate, Codex spawn_agent/wait_agent with multi_agent = true, or Antigravity invoke_subagent. Use a fresh session with fork_context: false and record Max Runtime: 900 seconds, Deadline: 900 seconds, Heartbeat every 30 seconds, and Poll interval: 15 seconds. A missing capability is TASK_BLOCKED: never execute inline or use a silent fallback. Record TASK_STARTED with timestamp, branch, git_hash, task_id, and context.
6. Implement with surgical changes.
7. Immediately after verifier PASS and before asking for acceptance, present a short HTD de aceptación grounded in verified current-HEAD facts. Include Artefacto / arranque with the exact install/open/run command or why manual launch is not applicable; a prioritized list of changed visible/behavioral scenarios, each with Ruta, Acción, and Esperado; No hace falta probar only for explicitly out-of-scope or already-covered items; and a final request to test this HTD de aceptación and reply accept/acepto or report an issue. Never invent paths or expected behavior; if a fact is unavailable, state that manual verification is blocked or ask for the missing detail. Record Gate UA HTD: presentado and HTD presentado with timestamp in the Execution Log, then the acceptance timestamp and exact text. No se puede pedir `accept` before presenting the HTD de aceptación; missing/negative/ambiguous responses require clarification or iteration. Only after the user tests the HTD and explicitly accepts may finishing begin.

Mini creates the same six documents in compact form. The six documents are *-prd.md, *-spec.md, *-designs.md, *-plan.md, *-tasks.md, and *-verify.md. Compactness reduces explanation density and ceremony only; it does not remove exact task instructions, global Given/When/Then criteria, criterion metadata (Criterion type/Invariant/Verification seam), evidence, corrective loop, branch gate, or Gate UA. Mini keeps the shorter flow and may omit the Full-mode per-task code-review and checkpoints. Recover between sessions from *-tasks.md and the Execution Log of *-plan.md; TodoWrite is only the session mirror. Any human approval or review checkpoint is a decision gate only, never persistent session state.

Begin by loading specai-grill-me and grounding the request in the codebase.