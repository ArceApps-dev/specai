---
name: specai-which
description: Given a user prompt, detect which specai flow matches and route to the right slash command. Removes the burden of memorising 11 commands.
command: "/specai-which"
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-which

**Read-only router.** Given a user prompt, decides which specai flow (or slash command) is the right response. Never modifies code.

## ABSOLUTE RULE (INQUEBRANTABLE)

**When uncertain between flows, ASK. Do not guess and execute.** The wrong flow wastes 30 minutes; a clarification costs 10 seconds.

## Decision tree

```
User prompt
    │
    ├── contains "implement", "build", "add", "fix", "create"?
    │     YES → is it a one-liner / trivial change?
    │             YES → /specai-mini
    │             NO  → does the user have an approved design?
    │                     YES → continue execution (controller dispatch)
    │                     NO  → /specai-plan (full flow)
    │
    ├── contains "explore", "understand", "what is", "how does"?
    │     YES → /specai-explore
    │
    ├── contains "verify", "did it work", "acceptance criteria"?
    │     YES → /specai-verify
    │
    ├── contains "review", "over-engineer", "yagni", "bloat"?
    │     YES → /specai-review
    │
    ├── contains "iterate", "feedback", "issue", "broken"?
    │     YES → /specai-iterate (assumes plan in flight)
    │
    ├── contains "audit", "health", "code quality", "architecture"?
    │     YES → /specai-audit  (bloat only)
    │     YES + contains "architecture" + wants interactive triage
    │           → /specai-audit-plan
    │
    ├── contains "backlog", "pending", "next plan"?
    │     YES → /specai-backlog
    │
    ├── contains "mode", "senior", "intensity", "ultra", "lite"?
    │     YES → /specai-mode
    │
    ├── contains "init", "setup", "first time", "install"?
    │     YES → /specai-onboarding
    │
    ├── contains "config", "model", "language"?
    │     YES → /specai-config
    │
    ├── contains "status", "where am I", "progress"?
    │     YES → /specai-status
    │
    └── ambiguous or none of the above:
          → /specai-help  (the user is probably lost)
```

## Flow

1. Read the user's prompt.
2. Walk the tree above.
3. If a clear match: respond with the slash command and a one-line rationale. Do NOT auto-invoke.
4. If ambiguous or low confidence: ask the user using the question tool.

## Example

```
User: "Can you add a dark mode toggle to settings?"
Agent: This sounds like a /specai-mini task — small, well-scoped.
       Run: /specai-mini "add dark mode toggle to settings"
       Or expand to a full plan if the change touches multiple files:
       Run: /specai-plan "add dark mode toggle to settings"
```

```
User: "What does the auth middleware look like?"
Agent: This is exploration, not implementation.
       Run: /specai-explore "auth middleware"
```

```
User: "It says all tasks done but the button doesn't work."
Agent: This is iteration feedback. A plan must be in flight.
       Run: /specai-iterate
       (specai will look up the current plan folder automatically.)
```

## Boundaries

**This skill does:**
- Read the user's prompt
- Match against the decision tree
- Recommend a slash command
- Ask when uncertain

**This skill does NOT:**
- Auto-invoke any slash command
- Modify any file
- Bypass the user's confirmation

The whole point is the user types something, gets "you probably want X", confirms, and then we proceed. The user is always the one who types the command.
