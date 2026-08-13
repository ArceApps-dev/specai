---
name: specai-evals
description: Verifies that every SKILL.md complies with its own declared gates (frontmatter valid, required sections present, dependencies referenced). Run via scripts/specai-evals.sh.
command: "/specai-evals"
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# specai-evals

The contract checker. Every `SKILL.md` declares gates ("MUST do X", "must NOT do Y"). This skill + script verifies the repo's SKILL.md files actually comply with what they declare.

## What it checks

For each `skills/<name>/SKILL.md`:

1. **Frontmatter is valid YAML** with at minimum: `name`, `description`.
2. **The `name` field matches the directory name**.
3. **The `description` is non-empty and one line** (or valid `>-` block scalar).
4. **If the skill declares "MUST NOT do X"**, the skill body does not contain "X" in a positive imperative.
5. **If the skill declares "required skills"** (e.g. `write-prd` requires `grill-me`), the required skills directory exists.
6. **For skills with hard "GATE" sections** (`bootstrap`, `writing-plans`, `subagent-driven-development`, `verification-before-completion`, `finishing-a-development-branch`, `iteration`), the section title text matches the expected pattern.

## How to run

```
bash scripts/specai-evals.sh           # full eval
bash scripts/specai-evals.sh --strict  # fail on warn
bash scripts/specai-evals.sh --json    # machine-readable
```

The script is `scripts/specai-evals.sh`. It walks `skills/*/SKILL.md`, applies the checks above, and prints a per-skill summary.

## Why this skill exists

The 2026-07-08 audit found that `skills/specai-brainstorming/SKILL.md` was marked DEPRECATED but its redirect file kept grep-ing true. The bootstrap skill required 3 plan docs before code, but no test verified a SKILL.md actually enforced its own gates. `specai-evals` is the executable counterpart to those prose-only declarations.

Pattern borrowed from the broader ecosystem's eval-driven skill libraries.

## Boundaries

**This skill does:**
- Walk `skills/*/SKILL.md`
- Validate frontmatter
- Cross-check declared dependencies
- Print per-skill and aggregate status

**This skill does NOT:**
- Modify any file
- Auto-fix violations
- Decide whether a violation is acceptable (the user decides)

## When to run

- Before any release.
- After adding a new skill.
- After editing any skill's frontmatter.
- As part of CI (TODO: wire into `.github/workflows/`).

## Recovery when eval reports fails

1. Read the per-skill report.
2. For YAML errors: the file is structurally broken; fix the frontmatter.
3. For "name mismatch": rename the directory or fix the YAML `name` field.
4. For "MUST NOT violated": read the skill's own declaration; either remove the violation or remove the declaration.
5. For "required skill missing": create the required skill (or remove the dependency claim).
6. For "gate section missing": the skill is missing its core rule. Either add the section or note this as a known gap.