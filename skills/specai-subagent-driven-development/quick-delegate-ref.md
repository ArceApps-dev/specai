# Quick Delegate Reference

Minimal templates for dispatching each subagent. Use when you know the flow and don't need the full prompt text.

For Codex, every dispatch uses a fresh session with `fork_context: false`.
Prefix the actual full-flow handoff with `/specai-plan` (`/specai-mini` in Mini
mode). If `wait_agent` returns `timed_out: true`, poll the same handle again;
it is not a terminal result and must not trigger a retry or cancellation.

## specai-command (single)

```
delegate(prompt="
  command: npm run build
  workdir: /home/user/project
  description: verify build
", agent="specai-command")
```

## specai-command (batch)

```
delegate(prompt="
  commands:
    - command: npm run build
      description: verify build
    - command: npm test
      description: run tests
      continue_on_failure: true
    - command: git add . && git commit -m 'feat: ...'
      description: commit
  workdir: /home/user/project
", agent="specai-command")
```

## implementer

```
delegate(prompt="
  [Task N title]
  [description, 2-5 sentences]
  Acceptance: [checklist]
  Files: [paths]
  Spec context: [minimal]
  (full implementer-prompt.md)
", agent="implementer")
```

## build-fixer

```
delegate(prompt="
  Build error: [paste error log]
  Task: [what was being built]
  Relevant code: [files and lines]
  (full build-fixer-prompt.md)
", agent="build-fixer")
```

## verifier

```
delegate(prompt="
  Plan: docs/.../_plan.md
  Project: /path
  Scope: [optional subset of criteria]
  (full verifier-prompt.md)
", agent="verifier")
```

## specai-documentation

```
delegate(prompt="
  Task N completed: [summary]
  What was done: [description]
  Problems: [any issues/fixes]
  (full documentation-prompt.md or documenter-prompt.md)
", agent="specai-documentation")
```
