---
name: specai-finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Absolute Gates (INQUEBRANTABLE)

**NEVER proceed to options without verifier `PASS`, a presented HTD de aceptación, and explicit user acceptance first.**

## SpecAI documental finish

Antes de presentar opciones de integración, el controlador debe ejecutar el finish documental sin efectos Git:

```bash
bash scripts/specai-finish.sh preflight <Feature-ID>
bash scripts/specai-finish.sh preview <Feature-ID>
```

El preflight exige seis artefactos fechados, ausencia de `SPEC_DRIFT`, delta de spec global aplicado, verifier PASS, HTD de aceptación presentado, Gate UA aceptado, tareas completadas y estado de backlog `ready_to_finish`. Si falla, se detiene y se resuelve la discrepancia con el documentador.

Solo después de actualizar la spec global y registrar el delta se puede archivar mediante:

```bash
bash scripts/specai-finish.sh archive <Feature-ID> --confirm-archive
```

El archivo mueve juntos los seis documentos a `docs/specai/feature/YYYYMMDD-slug/`, actualiza la entrada del backlog a `done` y es idempotente. Una colisión o fallo intermedio conserva la fuente activa y restaura el backlog. La operación no ejecuta Git y muestra `GIT_PENDING`; commit, push y merge requieren permiso explícito separado del usuario.

| Gate | What MUST happen | PROHIBITED |
|------|-----------------|-----------|
| **Gate UA: User Acceptance** | After verifier `PASS`, the controller MUST have presented a short HTD de aceptación with `Artefacto / arranque`, prioritized `Ruta`/`Acción`/`Esperado` scenarios, and `No hace falta probar`, then the user MUST have tested it and explicitly accepted the implementation (e.g. "accept", "acepto", "OK", "ship it"). The log MUST contain `Gate UA HTD: presentado`, `HTD presentado` with its timestamp, and the exact acceptance text/timestamp. | Invoking this skill on the user's behalf, asking for `accept` before presenting the HTD de aceptación, or assuming verifier-PASS equals done. See AGENTS.md §Gate UA. |
| **Gate F1: Tests Pass** | Full test suite MUST pass with 0 failures. | Presenting options, merging, or creating PRs with failing tests. |
| **Gate F2: Verifier Passed** | Verifier MUST have reported PASS before reaching this skill. | Skipping verification and jumping to finishing. |
| **Gate F3: Environment Detected** | Workspace state determined (normal repo, worktree, detached HEAD). | Presenting wrong menu for environment type. |
| **Gate F4: Exact Options** | Present exactly 4 options (or 3 for detached HEAD). No extra, no fewer. | Adding explanations, combining options, or presenting alternative flows. |
| **Gate F5: Confirm Destructive** | Require typed "discard" confirmation for Option 4. | Deleting work without explicit confirmation. |

## The Process

### Step 1: Verify Tests

**ABSOLUTELY MANDATORY: Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

**STOP. Do NOT proceed to Step 2 if any test fails.**

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

### Step 3: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 5: Execute Choice

#### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>

# Only after merge succeeds: cleanup worktree (Step 6), then delete branch
```

Then: Cleanup worktree (Step 6), then delete branch:

```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

## Judgment Day (adversarial review before PR)

Read the session setting established at flow start (from `specai-brainstorming`).

- If `judgment_day: true` → invoke `specai:specai-judgment-day` with the PR diff as target.
  Do NOT ask the user again — the setting was already confirmed at flow start.
- If `judgment_day: false` → skip, proceed to PR creation.

Note: the verifier already passed acceptance criteria. Judgment Day covers
code quality and architectural concerns that tests do not surface.

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

**Do NOT clean up worktree** — user needs it alive to iterate on PR feedback.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the worktree.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/`, `worktrees/`, or `~/.config/specai/worktrees/`:** specai created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up worktree for Option 2**
- **Problem:** Remove worktree user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/`, `worktrees/`, or `~/.config/specai/worktrees/`

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal

## Backlog Integration

After merge/PR creation, mark the plan as done in backlog:
1. Find the entry by matching `plan_dir`
2. Run `bash scripts/backlog.sh update-status <id> done`
