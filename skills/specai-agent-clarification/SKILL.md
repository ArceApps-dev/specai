---
name: specai-agent-clarification
description: "Presents unresolved technical edge-case questions after grounding and design, before planning."
command: false
---

# specai-agent-clarification

**Purpose:** Ensure implementing subagents have absolute clarity on technical requirements, boundaries, and type definitions BEFORE drafting the implementation plan. This prevents backtracking, incorrect assumptions, and architecture refactoring mid-implementation.

## Required Skills

- `specai-bootstrap` — establishes the active language and the execution contract.

Before this skill asks or presents any clarification, the controller MUST confirm that `specai-bootstrap` has run for the current conversation. If it has not, stop and complete bootstrap first.

## Why This Skill is Essential

While business requirements are defined during design, developers (and subagents) often face technical uncertainties when they begin writing the implementation plan.
By proactively identifying and resolving technical edge cases, the agent ensures that the plan is precise, realistic, and matches the user's codebase architecture.

## When to Use

- Invoke this skill **after grounding and design**, but **before** starting the writing of `_plan.md` or `_tasks.md`.
- Load it only for unresolved technical edge cases identified after grounding and design. If the codebase answers a question, omit it.
- Run this whenever the implementing subagent identifies technical gaps, missing limits, or ambiguous boundaries in the specifications.

## Preconditions and Gates

1. **Bootstrap gate:** Read the active conversation language from the completed bootstrap state. Prompts, option labels, and custom-response text MUST use that language; do not embed a fixed locale-specific phrase in this skill.
2. **Specification gate:** Before formulating questions, locate the approved specification and design documents for the feature. If either is missing, stop and report that clarification is blocked; do not invent requirements or start planning.
3. **Scope gate:** Only ask about technical edge cases that remain unresolved after grounding and design. Business decisions belong in the design interview.

---

## Technical Dimensions of Clarification

When formulating clarification questions, group them into the following technical dimensions:

### 1. Data Types, Nullability, and Constraints
- **Questions to ask:**
  - Can fields be null or undefined? What are the default values if omitted?
  - What are the string length limits, numeric ranges (min/max), or specific date formats?
  - Should relationships between entities be strictly cascade-deleted, set to null, or restricted?
- **Goal:** Ensure database schemas and TypeScript/Type interfaces are correctly specified.

### 2. Limits and Scaling Boundaries
- **Questions to ask:**
  - What is the maximum size of payloads or files that can be processed?
  - How should pagination behave? What is the default and maximum page size?
  - Are there rate limits, throttle windows, or timeout thresholds to enforce?
- **Goal:** Set limits to prevent system abuse and design suitable buffer sizes.

### 3. Empty and Error States
- **Questions to ask:**
  - How should the system behave when there is no data to return? (e.g., empty arrays, empty database table).
  - Which HTTP status codes or error formats should be returned under specific failure modes?
  - What is the retry policy for external API failures?
- **Goal:** Define graceful degradation pathways and clear error user-experiences.

### 4. Concurrency and Race Conditions
- **Questions to ask:**
  - How do we handle double-clicks or duplicate form submissions?
  - Is optimistic locking required for updating concurrent resources, or is last-write-wins acceptable?
- **Goal:** Prevent race conditions in database mutations or state updates.

---

## How to Formulate Questions

Follow these styling rules when presenting questions to the user:

1. **Be Specific:** Reference actual file names, types, or API endpoints.
2. **Present Recommendations:** Do not just ask a question; present a recommended option based on the project's existing conventions and explain *why*.
3. **Provide Selectable Options:** Offer multiple-choice options (A, B, C) and a custom input choice to save the user time.
4. **Limit the Scope:** Ask a maximum of 3-5 high-impact questions per round to avoid overloading the user.

### Example Presentation:

```markdown
## Technical Clarification Needed

Before I write the implementation plan, please clarify the following technical details:

1. **Nullability of `metadata` in user profile payload:**
   Currently, the design lists `metadata` as optional.
   * *Recommended option:* Make it nullable in the database but default to an empty JSON object `{}` in the API schema to simplify frontend parsing.
   * **A)** Accept recommendation (Default to `{}`)
   * **B)** Strictly nullable (`null` allowed)
   * **C)** [Custom response in the active conversation language]

2. **Empty state for search API `/api/v1/search`:**
   * *Recommended option:* Return `HTTP 200` with an empty array `[]` and total count `0` instead of throwing `HTTP 404`.
   * **A)** Accept recommendation (Return `HTTP 200` + `[]`)
   * **B)** Return `HTTP 404`
   * **C)** [Custom response in the active conversation language]

3. **String length limit for `custom_slug`:**
   * *Recommended option:* Enforce a limit of 100 characters to match the indexing constraints of the database column.
   * **A)** Accept recommendation (100 characters max)
   * **B)** Enforce a limit of 255 characters
   * **C)** [Custom response in the active conversation language]
```

---

## Step-by-Step Process for the Agent

1. **Scan Specification:** Analyze the specifications, designs, or recent changes. Identify components, types, or endpoints where technical behavior is not fully defined.
2. **Simulate Implementation:** Put yourself in the shoes of the `implementer` subagent. Identify the exact questions you would need to ask to write clean, assertion-backed code.
3. **Compile Questions:** Group the doubts by technical dimension and format them using the multiple-choice schema.
4. **Ask User:** Present the questions clearly and wait for the user's responses.
5. **Integrate Decisions:** Update the specifications and context documentation (`CONTEXT.md`, specification files) with the resolved answers.
6. **Proceed to Planning:** Once all critical technical edge cases have been resolved, return the decisions and remaining assumptions to the controller. The controller may then start `/specai-plan` or write implementation plans; this skill has no command capability and MUST NOT trigger commands itself.

---

## Anti-Patterns (What NOT to Do)

- **Do NOT ask business-logic questions:** This skill is for technical implementation details. Business rules must be resolved during design or specs.
- **Do NOT present open-ended essays:** Always offer recommendations and option letters to speed up decision-making.
- **Do NOT guess when in doubt:** If a constraint has database integrity implications, ask the user. Guessing leads to schema migrations and code churn.
- **Do NOT continue without bootstrap and approved spec/design documents:** report the unmet gate to the controller.
- **Do NOT execute or trigger slash commands:** return control to the controller for the next workflow phase.
