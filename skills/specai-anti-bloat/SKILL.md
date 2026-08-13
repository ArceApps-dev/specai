---
name: specai-anti-bloat
description: >-
  Anti-overengineering review for specai. Three sub-skills: review (diff-level),
  audit (repo-wide), and debt (ledger of // td: comments). Uses tags:
  delete, stdlib, native, yagni, shrink. Read-only, never applies fixes.
command: false
  audit (repo-wide), and debt (ledger of // td: comments). Uses tags:
  delete, stdlib, native, yagni, shrink. Read-only, never applies fixes.
  Use when the user says "review for over-engineering", "audit for bloat",
  "what can we delete", or invokes /specai-review, /specai-audit, /specai-debt.
metadata:
  author: ArceApps SpecAI
  version: "1.0"
license: MIT
---

# Anti-Bloat Review

Three sub-skills for detecting and tracking over-engineering in specai
projects. All are read-only — they list findings, never apply fixes.

## ABSOLUTE RULE (INQUEBRANTABLE)

**READ-ONLY. These sub-skills NEVER apply fixes, NEVER modify code, NEVER make edits. They only report findings. Applying fixes is a separate task that requires user approval.**

---

## Sub-Skill 1: Diff Review (`specai-anti-bloat-review`)

Review diffs for unnecessary complexity. One line per finding. The diff's
best outcome is getting shorter.

**Trigger:** `/specai-review`, "review for over-engineering", "what can we delete", "is this over-engineered", "simplify review"

### Tags

- `delete:` dead code, unused flexibility, speculative feature. Replacement: nothing.
- `stdlib:` hand-rolled thing the standard library ships. Name the function.
- `native:` dependency or code doing what the platform already does. Name the feature.
- `yagni:` abstraction with one implementation, config nobody sets, layer with one caller.
- `shrink:` same logic, fewer lines. Show the shorter form.

### Format

`L<line>: <tag> <what>. <replacement>.`, or `<file>:L<line>: ...` for multi-file diffs.

### Examples

✅ `L12-38: stdlib: 27-line validator class. "@" in email, 1 line, real validation is the confirmation mail.`

✅ `L4: native: moment.js imported for one format call. Intl.DateTimeFormat, 0 deps.`

✅ `repo.py:L88: yagni: AbstractRepository with one implementation. Inline it until a second one exists.`

✅ `L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.`

✅ `L30-44: shrink: manual loop builds dict. dict(zip(keys, values)), 1 line.`

### Scoring

End with: `net: -N lines possible.`
If nothing to cut: `Lean already. Ship.`

### Boundaries

Complexity only. Correctness bugs, security holes, and performance go to a
normal review pass, not this one. A single smoke test or `assert`-based
self-check is the minimum, not bloat — never flag it for deletion.
Does not apply the fixes, only lists them.

---

## Sub-Skill 2: Repo Audit (`specai-anti-bloat-audit`)

Diff review, but repo-wide. Scan the whole tree instead of a diff.
Rank findings biggest cut first.

**Trigger:** `/specai-audit`, "audit for over-engineering", "audit this codebase", "find bloat"

### Hunt

Deps the stdlib or platform already ships, single-implementation interfaces,
factories with one product, wrappers that only delegate, files exporting one
thing, dead flags and config, hand-rolled stdlib.

### Output

One line per finding, ranked: `<tag> <what to cut>. <replacement>. [path]`.
End with `net: -N lines, -M deps possible.`
Nothing to cut: `Lean already. Ship.`

### Boundaries

Complexity only. Lists findings, applies nothing. One-shot.

---

## Sub-Skill 3: Debt Ledger (`specai-anti-bloat-debt`)

Every deliberate senior simplification is marked with a `// td:` comment
naming its ceiling and upgrade path. This collects them into one ledger so a
deferral can't quietly become permanent.

**Trigger:** `/specai-debt`, "ponytail debt", "what did we mark to do later", "list the shortcuts"

### Scan

Grep the repo for comment markers, skipping `node_modules`, `.git`, and
build output:

```bash
grep -rnE '(#|//|--) ?td:' .
```

Each hit is one ledger row.

### Output

One row per marker, grouped by file:

```
<file>:<line> — <what was simplified>. ceiling: <the limit named>. upgrade: <the trigger to revisit>.
```

The convention is `// td: <ceiling>, <upgrade path>`, so pull the ceiling
and the trigger straight from the comment.

Flag the rot risk: any `// td:` comment that names no upgrade path or
trigger gets a `no-trigger` tag — those are the ones that silently rot.

End with `<N> markers, <M> with no trigger.`
Nothing found: `No // td: debt. Clean ledger.`

### Boundaries

Reads and reports only, changes nothing. To persist, ask and it writes the
ledger to a file (e.g. `SENIOR-DEBT.md`). One-shot.
