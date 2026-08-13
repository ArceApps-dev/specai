---
name: specai-assumptions-consolidation
description: "Consolidate agreements and list numbered technical assumptions from the design discussion."
command: false
---

# specai-assumptions-consolidation

**Purpose:** Consolidate design agreements and explicitly document technical assumptions made during the design and brainstorming phases. This ensures both the user and the implementer agents share an unambiguous mental model, preventing architectural misalignment and costly refactoring.

## ABSOLUTE RULES (INQUEBRANTABLE)

1. **Explicit Numbered List:** All technical assumptions MUST be documented as a strictly numbered list (e.g., `1.`, `2.`, `3.`). No bullet points (`-` or `*`) are allowed for the technical assumptions section.
2. **Clear Decisions Summary:** A separate section summarizing key agreed-upon decisions from the conversation history must precede the assumptions list.
3. **Traceability:** Every assumption must map to a potential technical risk or constraint identified in the conversation.
4. **No Placeholders:** All statements must be concrete, specific, and actionable.

## When to Use

- At the transition point between Brainstorming/Design Discussion and Plan Writing.
- Whenever a design fork has been resolved and the codebase path needs to be locked down.
- Prior to creating the final implementation checklist/tasks.

## Process

### Step 1: Analyze Conversational History
Scan the conversation logs and design notes to extract:
- **Explicit Decisions:** Decisions clearly agreed upon by the user and agent.
- **Implicit Assumptions:** Architectural patterns, libraries, schemas, or behaviors assumed by the agent but not explicitly debated.
- **Technical Constraints:** OS, language versions, library versions, or environment limitations.

### Step 2: Write the Summary of Agreed-upon Decisions
Group the agreements into clear categories (e.g., Scope, Architecture, UX/UI, Data Model).
For example:
- **Architecture:** Use of Clean Architecture with separate domain and infrastructure layers.
- **State Management:** Leverage standard React context instead of introducing Redux.

### Step 3: Generate the Strictly Numbered Technical Assumptions List
Draft the technical assumptions. Each must be numbered sequentially (`1.`, `2.`, `3.`) and clearly describe the assumed behavior, interface, or technical dependency.
For example:
1. The application will target Node.js version 18.x or higher.
2. The UI database schema relies on PostgreSQL version 14 UUID fields for primary keys.
3. Network calls will assume standard JSON responses without custom binary wrapping.

## Example Output Structure

```markdown
### Summary of Agreed-upon Decisions
- **Decision A:** Description of Decision A.
- **Decision B:** Description of Decision B.

### Strictly Numbered Technical Assumptions
1. Technical assumption description.
2. Technical assumption description.
3. Technical assumption description.
```

## Assumptions Review & Feedback Loop

When the user provides feedback on the numbered assumptions list (e.g. "change 3 and 5" or "assumption 2 is wrong because..."):

1. **Clarify and Analyze**:
   - Identify the specific numbered assumptions the user disagrees with.
   - Seek to understand the underlying context and alternative constraints.
   - Analyze how these adjustments affect the overall architecture.
2. **Adjust Design & Domain Model**:
   - Update the system's design model and domain glossary (`CONTEXT.md` or ADRs) to reflect the corrected assumptions.
3. **Regenerate the Numbered Assumptions List**:
   - Formulate corrected versions of the assumptions.
   - Regenerate the list, highlighting the changes for clarity.
   - Do NOT proceed to writing implementation plans until all assumptions are explicitly agreed upon.

## What NOT To Do

- Do NOT use bullet points (`*` or `-`) for the technical assumptions list; it MUST be a numbered list (1, 2, 3...).
- Do NOT list vague or generic assumptions (e.g., "The code will be clean"). Every assumption must be specific and verifiable.
- Do NOT skip the agreed-upon decisions summary. Both sections are required.
- Do NOT continue to planning until all assumptions are explicitly agreed upon.
