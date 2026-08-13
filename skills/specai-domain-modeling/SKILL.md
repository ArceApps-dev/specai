---
name: specai-domain-modeling
description: >-
  Build and maintain a project glossary (CONTEXT.md) and Architecture
  Decision Records (ADRs) during the write-prd phase and implementation.
  Activates when the user mentions a domain concept or when architectural
  trade-offs are decided.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
license: MIT
---

# Domain Modeling (Shared Language)

Build a shared language between the user, the agents, and the codebase.
One precise term replaces fifteen vague words — session after session.

## ABSOLUTE RULE (INQUEBRANTABLE)

**Every project MUST have a `CONTEXT.md`. Every architectural trade-off decision MUST be recorded as an ADR. These files are living documents — update them as the domain evolves.**

## When to Activate

This skill activates automatically during the `grill-me` clarification step
after grounding. It also activates when:

- The user introduces a new term that has domain-specific meaning
- An architectural trade-off is being decided
- The agent finds itself using 10+ words to describe something that should be a named concept
- At session start: agent checks `CONTEXT.md` to align on terminology

## CONTEXT.md — Domain Glossary

A file at the project root (`CONTEXT.md`) that maps project jargon to
precise definitions. Every agent reads it at session start.

### Format

```markdown
# Project Glossary

## Core Concepts
- **<term>**: <one-sentence definition>
- **<term>**: <one-sentence definition>

## Relationships
- **<term A>** depends on/is composed of/triggers **<term B>**

## Architecture Decisions
See `ADRs/` for full decision records.
```

### Rules for terms
- Each term = one line, maximum two sentences
- Define how terms relate to each other (composes, triggers, depends on)
- Terms that share a prefix form a namespace (e.g., `materialización`, `materialización en cascada`)
- If a term has synonyms, pick one and note the alias
- Never add a term the codebase doesn't use

### When to register a term
- The user says something domain-specific twice in different ways
- The agent finds itself paraphrasing the same concept in 10+ words
- A variable/function/file name needs a concept label
- Two terms collide or overlap — resolve and pick one

### Example (Course Video Manager)

```markdown
# Course Video Manager — Glossary

## Core Concepts
- **materializar**: asignar una lección a una ubicación real en el sistema de archivos
- **cascada de materialización**: cuando materializar un curso fuerza materializar todas sus lecciones
- **curso padre**: curso que contiene secciones y lecciones
- **metadatos de lección**: título, duración, orden y estado de una lección

## Relationships
- Un **curso padre** contiene **secciones**
- Una **sección** contiene **lecciones**
- **materializar** un curso desencadena **cascada de materialización**
```

## ADRs — Architecture Decision Records

Decision records in `docs/adr/YYYYMMDD-<slug>.md` (or `ADRs/` at project root).

### When to create an ADR
- Choosing between 2+ architectural approaches
- A decision that will be expensive to change later
- A non-obvious constraint or trade-off
- A rejected approach that someone will propose again next week

### ADR format

```markdown
# ADR-NNN: <title>

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | deprecated | superseded

## Context
<What problem are we solving? What constraints exist?>

## Decision
<What did we decide? One sentence.>

## Alternatives Considered
- **Option A**: <description> — rejected because <reason>
- **Option B**: <description> — rejected because <reason>

## Consequences
<What gets easier? What gets harder? What's the follow-up?>
```

### Rules for ADRs
- Status starts as `proposed`, moves to `accepted` when implemented
- If superseded, add a link to the new ADR and mark status `superseded`
- Never delete old ADRs — they're the project's decision history
- ADRs are immutable once `accepted`: if the decision changes, write a new ADR
- File name: `ADR-<NNN>-<lowercase-kebab-slug>.md`

## When NOT to create an ADR
- Obvious decisions (use the stdlib, follow the framework convention)
- Decisions that are trivial to change (rename a variable, add a parameter)
- Decisions already documented in the tech stack choice

## Integration with specai Flow

```
Grill-me clarification step after grounding:
  ├── User mentions domain concepts → register in CONTEXT.md
  ├── Architectural trade-off emerges → create draft ADR
  └── CONTEXT.md loaded at session start for terminology alignment

Implementation:
  ├── New domain terms surface → append to CONTEXT.md
  ├── ADR moves to `accepted` when implemented
  └── Naming follows glossary (variables, functions, files)

Iteration:
  ├── Domain evolves → CONTEXT.md updated
  └── Decision reversed → new ADR supersedes old one
```

## Output Format

When registering a term during conversation:

```
📝 CONTEXT.md: added **<term>** — <one-line definition>
```

When creating an ADR:

```
📋 ADR-<NNN> created: **<title>** at docs/adr/<filename>.md
```

## Token Efficiency

- `CONTEXT.md` is loaded once at session start (low cost)
- Terms reduce future token usage by 60-80% for domain descriptions
- ADRs prevent re-debating decisions (saves entire conversation rounds)
- The agent references terms, not re-explains concepts

## Example Session

```
User: "I want to build a playlist generator that creates smart playlists
       based on listening history, skipping tracks the user has already
       heard recently."

Agent: 📝 CONTEXT.md: added **lista inteligente** — playlist auto-generada
       por reglas (historial, género, BPM) con filtro de tracks ya escuchados

Agent: Q: Should duplicate tracks across playlists be allowed?
       Recommended: No — each track appears once per smart list. Reason:
       keeps the "recently heard" filter meaningful. [A/B/C?]
```
