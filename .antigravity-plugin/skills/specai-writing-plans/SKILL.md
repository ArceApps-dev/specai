---
name: specai-writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code. Creates implementation plans with atomic tasks.
---

# Writing Plans

## ABSOLUTE GATES (INQUEBRANTABLE — DO NOT SKIP)

| Gate | What MUST happen | PROHIBITED |
|------|-----------------|-----------|
| **Gate P1: Spec Clean** | No ambiguity markers. Spec user-reviewed. | Creating plan from ambiguous spec. |
| **Gate P2: Branch FIRST** | Feature branch created BEFORE any file written. | Writing files on `main`/`master`/`develop`/`dev`. |
| **Gate P3: All Files Complete** | `-plan.md`, `-tasks.md`, `-verify.md` all exist with no placeholders. | Handing off incomplete files to implementer. |
| **Gate P4: Self-Review Passes** | No "TBD", "TODO", "implement later". Type consistency verified. | Shipping plan with gaps. |
| **Gate P5: User Approved** | User explicitly says "yes" to the plan. | Starting execution without approval. |

## Overview

Write comprehensive implementation plans assuming the engineer has zero context. Document everything: which files to touch, code, testing, how to verify. DRY. YAGNI. TDD. Frequent commits.

**Announce:** "I'm using the writing-plans skill to create the implementation plan."

**Save documents to the active feature folder:**
- `docs/specai/<spec-name>/<spec-name>-plan.md` — The core implementation plan structure
- `docs/specai/<spec-name>/<spec-name>-tasks.md` — The checklist of atomic tasks
- `docs/specai/<spec-name>/<spec-name>-verify.md` — Criterios de aceptación y plantilla de verificación final para el agente final

### Verification Template (`<spec-name>-verify.md`)
Every verification file MUST start with:
```markdown
# [Feature Name] Final Verification Report

## Global Acceptance Criteria Checklist
- [ ] AC1: <acceptance criterion 1>
- [ ] AC2: <acceptance criterion 2>

## Verification Logs & Evidence
*Provide details of the verification steps run (e.g. commands, output, test results) to prove each acceptance criterion.*
- **AC1 Verification:**
  - Status: PENDING / VERIFIED
  - Evidence: [Evidence or notes]
- **AC2 Verification:**
  - Status: PENDING / VERIFIED
  - Evidence: [Evidence or notes]
```

## Scope Check

If the spec covers multiple independent subsystems, suggest splitting into separate plans — one per subsystem.

## File Structure

Map out which files will be created or modified:
- Design units with clear boundaries
- Each file has one clear responsibility
- Follow existing patterns in the codebase

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test"
- "Run it to make sure it fails"
- "Implement the minimal code to make the test pass"
- "Run the tests and make sure they pass"
- "Commit"

## Plan Document Header

Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
**Status:** [ 🟢 BACKLOG | 🟡 IN PROGRESS | 🔵 VERIFYING | ✅ DONE ]

---

## Acceptance Criteria

What "done" means:
- [ ] <criterion 1>
- [ ] <criterion 2>

## Constraints & Guardrails

- <constraint that applies to the whole implementation>

---

## Task List
```

## Task Structure

```markdown
### Task 1: [Component Name]

**Files:**
- Create: `path/to/file.py`
- Modify: `path/to/existing.py:123-145`
- Test: `tests/path/to/test.py`

**Acceptance for this task:**
- [ ] <criterion>

**Steps:**

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

```
Run: pytest tests/path/test.py::test_name -v
Expected: FAIL
```

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

```
Run: pytest tests/path/test.py::test_name -v
Expected: PASS
```

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## No Placeholders

Every step must contain actual content. Never write:
- "TBD", "TODO", "implement later"
- "Add appropriate error handling"
- "Write tests for the above"
- "Similar to Task N"

## Remember
- Exact file paths always
- Complete code in every step
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the plan:
1. **Spec coverage** — Can you point to a task for each spec requirement?
2. **Placeholder scan** — Any "TBD", "TODO", or vague requirements?
3. **Type consistency** — Do names match across tasks?

## Execution Handoff

After saving all plan files, ask the user if they want to start the implementation or save it to backlog and exit:

> "Plan, tasks, and verification template complete and saved to `docs/specai/<spec-name>/`.
> 
> How would you like to proceed?
> 1. **Start implementation now** (triggers `/specai-execute` pointing to the directory `docs/specai/<spec-name>/`)
> 2. **Save to Backlog and exit** (marks the plan status as `🟢 BACKLOG`, saves the files, and ends the current feature session, resetting context for the next `/specai-new` run)"

If the user chooses option 2, execute the following steps in order:

1. Update the plan file's `Status` to `🟢 BACKLOG`.
2. Ask the user: "Priority for this task? [high/medium/low] (default: medium)"
3. Run: `bash scripts/backlog.sh add <name> <date> <priority> <plan_dir>`
   - Show: "Added to backlog as item #N"
4. Stage and commit on the current feature branch:
   ```bash
   git add docs/specai/<spec-name>/ .specai/backlog.json
   git commit -m "feat: save <spec-name> to backlog"
   ```
5. Capture the feature branch name:
   ```bash
   FEATURE_BRANCH=$(git branch --show-current)
   ```
6. Detect the base branch by checking local branches in priority order:
   ```bash
   for candidate in main master develop dev; do
     if git rev-parse --verify "$candidate" &>/dev/null; then
       BASE_BRANCH="$candidate"
       break
     fi
   done
   if [ -z "$BASE_BRANCH" ]; then
     BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || BASE_BRANCH="main"
   fi
   ```
7. Switch to the base branch and pull latest:
   ```bash
   git checkout "$BASE_BRANCH" && git pull
   ```
8. Attempt a `--no-ff` merge to preserve the feature branch in history:
   ```bash
   git merge --no-ff "$FEATURE_BRANCH"
   ```
9. **On merge success (exit code 0):**
   - Delete the local feature branch: `git branch -d "$FEATURE_BRANCH"`
   - Show: "✓ Plan saved to backlog. Branch `$FEATURE_BRANCH` merged into `$BASE_BRANCH` with history preserved."
   - Clean up all session feature state variables and end the conversation cleanly.

10. **On merge conflict (non-zero exit code):**
    - Show the conflicting files: `git diff --name-only --diff-filter=U`
    - Present two options:
      > "⚠️ Merge conflict detected in the following files:
      > [list of conflicting files]
      >
      > A. **Auto-resolve:** I will resolve conflicts automatically (feature branch version wins for plan/docs files; `.specai/backlog.json` arrays are merged and deduplicated with `jq`), complete the merge, and delete the feature branch.
      > B. **Manual resolve:** Abort the merge, return to the feature branch, and leave the repository intact for you to resolve manually."
    - **If user chooses A (Auto-resolve):**
      - For each conflicting file under `docs/specai/<spec-name>/`: run `git checkout --theirs <file>`
      - For `.specai/backlog.json`:
        ```bash
        git show MERGE_HEAD:.specai/backlog.json > /tmp/backlog_theirs.json
        git show HEAD:.specai/backlog.json > /tmp/backlog_ours.json
        jq -s '.[0] + .[1] | unique_by(.id)' /tmp/backlog_ours.json /tmp/backlog_theirs.json > .specai/backlog.json
        ```
      - Stage all resolved files: `git add .`
      - Complete the merge: `git commit -m "feat: merge $FEATURE_BRANCH to backlog (auto-resolved conflicts)"`
      - Delete the local feature branch: `git branch -d "$FEATURE_BRANCH"`
      - Show: "✓ Conflicts resolved automatically. Branch `$FEATURE_BRANCH` merged into `$BASE_BRANCH`."
    - **If user chooses B (Manual resolve):**
      - Run: `git merge --abort`
      - Run: `git checkout "$FEATURE_BRANCH"`
      - Show: "Merge aborted. You are back on `$FEATURE_BRANCH`. Resolve conflicts manually, then run:
        ```bash
        git checkout $BASE_BRANCH && git merge --no-ff $FEATURE_BRANCH && git branch -d $FEATURE_BRANCH
        ```"