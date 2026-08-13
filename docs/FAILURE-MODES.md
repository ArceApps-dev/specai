# specai — Failure Modes Catalogue

> Canonical list of things that go wrong in a specai run, what they look like, and how to recover.
>
> New failures should be appended. If a recovery is non-obvious, link to the relevant skill or command.

## 1. Writing code on a protected branch

**Symptom:** `git commit` succeeds locally but `git push` is rejected, or the controller detects it's on `main` after the commit.

**Cause:** specai's Iron Rule says feature branch first. The orchestrator may have lost the branch context.

**Recovery:**
1. `git stash` (don't lose work)
2. `git checkout -b feature/<repo>_<feature-slug>` from current HEAD
3. `git stash pop`
4. Resume. If commits already exist on main, cherry-pick or merge to feature branch and continue.

**Prevention:** always create the feature branch before any plan file write. The `scripts/specai-doctor.sh` check #4 detects this and warns.

## 2. `// td:` without a ceiling

**Symptom:** implementer adds a `// td:` comment like `// td: global lock` with no upgrade path.

**Cause:** Senior Philosophy says `// td: <ceiling>, <upgrade path>` is the format. Without the upgrade path, the comment is decoration, not intent.

**Recovery:**
1. Identify the simplify choice (the comment's location)
2. Rewrite to `// td: <ceiling>, add <trigger-condition> when <symptom>`
3. Re-run code-reviewer

**Prevention:** the senior-philosophy skill (`/specai-mode`) explicitly states the format. Code-reviewer should reject `// td:` without an upgrade path.

## 3. Verifier says PASS without running tests

**Symptom:** `verifier` subagent returns "PASS" but `npm test` (or equivalent) was never invoked.

**Cause:** The verifier had read-only permission (by design — `specai-verification-before-completion`), but the orchestrator forgot to actually run the test suite before dispatching the verifier.

**Recovery:**
1. Re-dispatch `specai-command` to run the full test suite.
2. If failures, dispatch implementer to fix.
3. Re-dispatch verifier AFTER tests pass.
4. Do not declare done until both PASS.

**Prevention:** treat "verifier PASS" as suspect unless the test-suite log is in the execution log right above.

## 4. Brainstorming / grill-me contradiction across docs

**Symptom:** AGENTS.md says one flow, the integration plugin docs say another.

**Cause:** This was the rot that triggered the 2026-07-08 audit. Three docs (AGENTS.md, README.md, README.es.md) described the socratic pattern three different ways.

**Recovery:** run `bash scripts/specai-doctor.sh` — it greps for `brainstorming` references in active docs. Anything reported is rot.

**Prevention:** treat the four entry-point docs (AGENTS.md, README.md, README.es.md, `docs/COMPARISON.md`) as one source-of-truth unit. Change one, change all.

## 5. Plan folder created on main

**Symptom:** `docs/specai/<spec-name>/` exists but the git branch is `main`.

**Cause:** orchestrator skipped the branch-first step.

**Recovery:** same as Failure #1 — branch the work retroactively.

**Prevention:** `writing-plans` skill Gate P2 (branch FIRST) is `INQUEBRANTABLE`. If the gate is bypassed, the plan folder should not be created.

## 6. `auditing` branch creates backlog items but never executes

**Symptom:** `.specai/backlog.json` grows, plans never get picked up.

**Cause:** `/specai-audit-plan` adds findings as backlog items; the user is supposed to triage. Without explicit triage, items rot.

**Recovery:** run `/specai-backlog`, review items, pick by number.

**Prevention:** the audit-triage is the user's responsibility, not the orchestrator's. The skill explicitly says "Force user to address all findings (they choose)" is a Red Flag.

## 7. Specai-doctor reports `specai-command` not on cheap model

**Symptom:** the doctor's check #9 fails.

**Cause:** config drifted — `agentModels.specai-command` was set to a premium model manually.

**Recovery:**
1. Edit `~/.config/specai/config.json`
2. Set `agentModels.specai-command` to `openrouter/deepseek/deepseek-v4-flash-free`
3. Re-run `bash scripts/setup-agents.sh`
4. Re-run `bash scripts/specai-doctor.sh` to confirm.

## 8. User-Acceptance Gate (UA) skipped

**Symptom:** merge happens, then the user reports "I never tested this".

**Cause:** `finishing-a-development-branch` was invoked without the user's explicit `accept`.

**Recovery:**
1. Revert the merge (or close the PR if not merged).
2. The implementation is fine; only the gate was skipped.
3. Have the user test the running implementation.
4. Wait for `accept` (or equivalent — see AGENTS.md §Gate UA acceptance phrases).
5. Re-invoke `finishing-a-development-branch`.

**Prevention:** the AGENTS.md `## Gate UA` section is `INQUEBRANTABLE`. If the orchestrator offers merge options without first recording user acceptance in `_plan.md` Execution Log, that is a violation.

## 9. `senior-philosophy` mode changed mid-flow

**Symptom:** implementer's behavior drifts: starts introducing abstractions mid-feature that weren't there before.

**Cause:** `~/.config/specai/config.json` was edited between tasks. Or `/specai-mode` was invoked during the run.

**Recovery:**
1. Pause the implementer.
2. Verify the mode: `bash scripts/specai-doctor.sh` (look for "Senior mode:" line).
3. If mode was changed deliberately, accept the new behavior — but ask the user to confirm the change applies to the entire remaining run, not just the current task.
4. If mode was changed accidentally, restore from git: `git diff ~/.config/specai/config.json` and revert.

**Prevention:** treat the mode setting as session-stable. Document any deliberate change in `_plan.md` execution log.

## 10. Living documents drift from reality

**Symptom:** `_tasks.md` says "all done", but the implementation isn't actually finished. Or `_plan.md` Execution Log doesn't reflect the latest commit.

**Cause:** `specai-documentation` was bypassed on a commit.

**Recovery:**
1. `bash scripts/specai-doctor.sh` does not currently detect this (TODO).
2. Manual: re-read `_tasks.md` and `_plan.md` against `git log` and update if needed.
3. Going forward: never commit without first dispatching `specai-documentation`.

**Prevention:** the `subagent-driven-development` skill Gate S5.5 makes documenter dispatch non-optional. If you're tempted to skip it, you're doing it wrong.

## 11. Subagent returns BLOCKED but nothing actionable in the message

**Symptom:** `implementer` returns "BLOCKED" without saying what it's blocked on.

**Cause:** The implementer was given insufficient context or hit an ambiguity not covered by the task spec.

**Recovery:**
1. Read the implementer's full output (not just the status).
2. If ambiguity, resolve with the user.
3. Re-dispatch with the missing context.

**Prevention:** ensure each task entry in `_tasks.md` includes enough "Spec context (minimal)" for the implementer to work without re-reading the full plan.

## 12. Build cache says CACHED but build is actually stale

**Symptom:** orchestrator skips rebuild because `cache_key` matches, but the test environment has changed (new system dependency, new env var, etc.).

**Cause:** the cache key is based on file hashes only. Non-file state changes don't invalidate.

**Recovery:**
1. Pass `--no-cache` to `specai-command` for that build.
2. If problem persists, set `cache_watch: []` for that task.
3. Update `scripts/lib-cache.md` (TODO) to document this edge case.

**Prevention:** for the first build after a CI environment change, always pass `cache_watch: []`.

---

## Adding to this list

When you encounter a new failure mode:

1. Reproduce it once.
2. Write the **Symptom / Cause / Recovery / Prevention** quad as above.
3. Add a number and link from the relevant skill (`verification-before-completion`, `systematic-debugging`, etc.).
4. Commit on a feature branch with message `failure-modes: add #N <one-line summary>`.