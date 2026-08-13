# Cognitive Documentation Patterns

Reference for `specai-documentation` agent when creating or updating living documents.
Apply these patterns to reduce cognitive load for the agents and humans reading the files.

## The Six Patterns

| Pattern | Rule |
|---------|------|
| **Lead with the answer** | Put the decision, action, or outcome first. Context comes after. |
| **Progressive disclosure** | Happy path first. Details, edge cases, and references after. |
| **Chunking** | Group related information into small sections. Flat lists ≤5 items. |
| **Signposting** | Use headings so readers can orient without reading everything. |
| **Recognition over recall** | Tables, checklists, examples over prose that must be memorized. |
| **Review empathy** | Design docs so an agent verifies intent by reading only its relevant section. |

## Applied to Each File

### `_tasks.md`
- Lead with task title and files — not the steps.
- Each step = one action. "And" in a step = split it.
- Include expected output for each command: "Expected: PASS", "Expected: exit 0".

### `_plan.md` (Acceptance Criteria section)
- Each criterion = one observable outcome, not a task description.
  - ❌ "Implement the retry function"
  - ✅ "POST /login retries 3 times on 503 and succeeds on the third attempt"
- Execution log is append-only. Never edit past entries.

### `_spec.md`
- One capability block per domain. Do not mix capabilities.
- Each scenario: GIVEN/WHEN/THEN, max 4 lines.
- Status marker at end of each block: `[ ] pending` or `[verified]`.

### `_design.md`
- Architecture decisions as a table: Option | Tradeoff | Decision.
- Data flow as ASCII diagram — no prose where a diagram works.
- Decisions Log at the bottom: date + decision + reason.

## Anti-Patterns to Avoid

- Writing "the implementation does X" in the spec. Spec language: "the system MUST X".
- Adding implementation explanation to the execution log. Log purpose: traceability, not explanation.
- Copying content that already exists in another document. Reference it; do not duplicate.
- Writing a criterion that only the implementer could verify. Criteria must be user-observable.
