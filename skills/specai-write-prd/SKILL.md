---
name: specai-write-prd
description: "Generate the formal Product Requirements Document (PRD) from consolidated agreements."
command: false
---

# Writing the Product Requirements Document (PRD)

This skill guides the agent in synthesizing grounded `grill-me` clarifications, consolidated agreements, and design decisions into a formal, structured Product Requirements Document (PRD). The PRD serves as the single source of truth for the implementation plan and verification criteria.

## Absolute Gates (INQUEBRANTABLE)

| Gate | What MUST happen | PROHIBITED actions |
|------|-----------------|-------------------|
| **Gate PRD1: Context & Approach Approved** | The user has chosen an architectural approach and approved the general design. | Generating a PRD before clarifying requirements. |
| **Gate PRD2: Draft Completed** | All required sections (Problem/Solution, User Stories, Architectural Decisions, System Constraints, Edge Cases, Out of Scope) are fully populated. | Leaving placeholders, missing sections, or TBD remarks. |
| **Gate PRD3: User Approved PRD** | The user explicitly reviews and approves the PRD document. | Proceeding to `writing-plans` or writing code without user sign-off on the PRD. |

## Process Checklist

1. **Consolidate Inputs**: Gather the grounded `grill-me` discussion context, chosen design approach, and any glossary terms/ADRs.
2. **Determine File Location**: The PRD must be written to `docs/specai/YYYYMMDD-<topic>/YYYYMMDD-<topic>-prd.md` (substituting the actual date and topic).
3. **Draft the PRD**: Write the PRD using the structured template below.
4. **Conduct Verification Audit**:
   - Check if all user stories are written in the Agile format.
   - Check if architectural decisions clearly define the module boundaries and seams (costuras).
   - Verify that System Constraints (Must-NOTs) are explicit.
5. **Present to the User**: Share a summary of the PRD and the path to the file with the user.
6. **Obtain Sign-Off**: Once approved, create the other five documents (`-spec.md`, `-designs.md`, `-plan.md`, `-tasks.md`, and `-verify.md`) without creating a branch, then transition to the implementation choice and plans (`writing-plans`). La PRD no se commitea ni crea rama antes de su aprobación.

---

## PRD Template & Guidelines

Every generated PRD must follow this structure exactly:

```markdown
# Product Requirements Document: <Feature Title>

**Date:** YYYY-MM-DD
**Status:** DRAFT | APPROVED

## 1. Problem Statement & Solution

### Problem Statement
- Describe the core problem from the user's perspective.
- Focus on the pain points, current limitations, and business or UX impact of the current state.

### Solution
- Provide a high-level overview of the proposed solution.
- Explain how it addresses the pain points without introducing unnecessary complexity.

---

## 2. User Stories

Write extensive user stories covering all core flows and secondary paths. Every story must strictly follow this Agile format:

> **As a** <actor/role>, **I want to** <action/feature> **so that** <value/benefit>.

*Example:*
1. **As a** developer, **I want to** validate the frontmatter format of a skill file automatically **so that** I can catch configuration errors before committing.
2. **As a** developer, **I want to** view a clear summary of verification failures **so that** I can target my fixes efficiently.

---

## 3. Architectural Decisions

Specify how the software will be structured. Focus on clean modules, testability, and isolation.

### Module Architecture
- Define the modules to be created or modified.
- Specify their inputs, outputs, and public interfaces.
- Do NOT inline code snippets unless they represent a core data structure, schema, or state machine defined during prototyping.

### Verification Seams (Costuras)
- Define the exact boundaries and layers where automated verification will occur (e.g., unit test boundaries, mock boundaries, integration checkpoints).
- Keep verification seams high enough to test external behavior rather than internal implementation details.

### Avoiding Side Effects
- Explicitly outline rules and mechanisms to prevent changes from affecting adjacent code or modules.
- Enforce clean segregation and state isolation.

---

## 4. System Constraints (Must-NOTs)

List the strict boundaries that the implementation must respect.
*Examples:*
- The code **must NOT** import external libraries if the functionality exists in the standard library.
- The module **must NOT** modify global state.
- The execution **must NOT** run synchronously or block the main thread.

---

## 5. Edge Case Analysis

List scenarios that deviate from the happy path and describe how the system must handle them:
- **Empty/Null States**: How to handle empty directories, empty strings, missing fields.
- **Error Boundaries**: What happens when disk writes fail, network drops, or inputs are malformed.
- **Scale/Limits**: What happens under extremely large inputs or concurrent operations.

---

## 6. Out of Scope

Clearly define the boundaries of this change to prevent scope creep.
- List related features, performance enhancements, or platforms that are explicitly deferred to future work.
```
