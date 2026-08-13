# SpecAI

@./skills/specai-bootstrap/SKILL.md
@./skills/specai-bootstrap/references/gemini-tools.md

## Philosophy

**specai is for independent developers.** Real developers who want a workflow that works, and works well — simple, straightforward, efficient. No bloated dashboards, no enterprise ceremony, no "platform." Just you, your editor, and an agent that gets things done.

specai is not a "super complete professional app." It's a sharp tool. It does one thing: take your idea, plan it with you, and execute it — safely, on a branch, with verification. That's it.

Everything else — explore, review, iterate, audit — is supporting cast. The star is `/specai-plan`. Everything specai does can be triggered by the agent itself; slash commands exist only as shortcuts for the developer who wants to steer.

## ABSOLUTE IRON RULE (INQUEBRANTABLE)

**The specai workflow is RÍGIDO. EVERY step in EVERY skill MUST be followed escrupulosamente. NO skipping steps. NO reordering. NO "this is simple enough to shortcut." NO "just this once." The flow is: socratic definition → grill-me → write-prd → approval → six docs → choose implement/backlog → branch only if implement → atomic implementation with per-task cycle (implement → build → code-review → commit → document → checkpoint) → spec-compliance-review → verifier → Gate UA (user acceptance) → finishing → [iteration loop]. Each phase has GATES that MUST be cleared before proceeding. If a gate is not satisfied, STOP. DO NOT proceed.**

**This rule applies to ALL agents, ALL skills, ALL subagents, ALWAYS. No exceptions, no rationalizations, no shortcuts.**

## Agent Configuration

specai uses 7 dedicated subagents. Create them all at once with:

```bash
bash scripts/setup-agents.sh
```

Or for a streamlined initial setup:

```bash
bash scripts/specai-init.sh
```

Agent models are configurable per role and the current source of truth is `scripts/agent-roster.json` plus the user's SpecAI configuration.

| Agent | Description | Default model |
|-------|-------------|---------------|
| `implementer` | Implementa UNA tarea atómica con contexto mínimo | `minimax/MiniMax-M3` |
| `build-fixer` | Resuelve errores de compilación con el fix mínimo | Configurado en `scripts/agent-roster.json`/config |
| `code-reviewer` | Revisa calidad y cumplimiento local por tarea (MANDATORY, antes del commit) | Configurado en `scripts/agent-roster.json`/config |
| `verifier` | Compara implementación con la checklist de `_plan.md` | `minimax/MiniMax-M3` |
| `spec-compliance-reviewer` | Revisa cumplimiento de la spec e invariantes globales tras todas las tasks (MANDATORY, antes del verifier) | Configurado en `scripts/agent-roster.json`/config |
| `specai-command` | Ejecuta comandos (build, test, git). Ningún otro agente ejecuta comandos directamente | Configurado en `scripts/agent-roster.json`/config |
| `specai-documentation` | Crea y actualiza toda la documentación (_plan.md, _tasks.md, specs, README). Ningún otro agente escribe documentación directamente | Configurado en `scripts/agent-roster.json`/config |

## The SpecAI Flow

The complete agentic flow is:

```
socratic → grill-me → write-prd → approval → six docs → choose implement/backlog → branch only if implement
        → per-task cycle (implement → build → code-review → commit → document → checkpoint)
        → spec-compliance-review → verifier → Gate UA (user acceptance)
        → finishing → [user tests → iteration loop]
```

**La rama de implementación NO DEBE crearse antes de aprobar la PRD y elegir implementar.** Exploration, PRD approval, and the six living documents happen before branching. **Guardar una feature en backlog NO DEBE crear una rama.** The user chooses implement or backlog after the six documents exist; only implementation creates `feature/<reponame>_<feature-slug>`. Direct commits on `main` / `master` / `develop` / `dev` are forbidden. Automatic task commits apply only to implementation branches; commit, push, merge, and cleanup for other transitions remain reserved for authorized finish.

1. **Socratic Definition (MANDATORY):** Before ANY action, the controller runs the `grill-me` skill — a relentless one-question-at-a-time interview that maps the design tree based on real codebase facts. No ambiguity, no edge cases, no loose ends. The implementer must NOT make design decisions or assumptions.

2. **PRD (formal):** The `write-prd` skill converts the resolved tree into a 6-section Product Requirements Document (Problem, User Stories, Architectural Decisions, System Constraints, Edge Cases, Out of Scope). The user MUST sign off before any plan is written.

3. **Planning:** Create atomic implementation plan (2-5 min tasks) plus acceptance criteria in `_verify.md` and task checklist in `_tasks.md`. Use the `writing-plans` skill.

4. **Execution:** Implement task by task. After EVERY completed task, EVERY commit, and EVERY error/fix, the `specai-documentation` agent MUST update the living documents (`_plan.md`, `_tasks.md`). These are living logbooks — they must reflect current reality. Use `subagent-driven-development`.

5. **Spec & Verification:** After all tasks: `spec-compliance-reviewer` checks the implementation against the spec; if PASS, the `verifier` checks against `_verify.md` acceptance criteria.

6. **Gate UA (User Acceptance):** The plan is **not complete** until the user has tested the implementation and explicitly accepted it. See [§Gate UA](#gate-ua-user-acceptance) below. No merge, PR, or archive before explicit acceptance.

7. **Finishing:** Once accepted, `finishing-a-development-branch` offers merge / PR / keep / discard.

8. **Iteration (User Feedback):** After the user accepts and tests in production, if issues are found:
   - Use `specai-iteration` skill
   - Document the feedback in `_plan.md` and `_tasks.md`
   - Add corrective tasks
   - Re-enter the execution flow (step 4) without restarting from scratch

## Gate UA: User Acceptance (INQUEBRANTABLE)

**The plan is NOT complete when the verifier says PASS. The plan is complete when the user has accepted the implementation.**

This is the single most important gate in the flow. Reasoning:

- Tasks DONE in `_tasks.md` ≠ implementation correct.
- Verifier PASS ≠ user has tested the result.
- Verifier PASS ≠ user is happy with the result.

`tasks.done` is a machine signal. The user's manual test is the only signal that matters.

**Rules:**

1. The flow stops at the verifier's PASS and presents the implementation to the user with: "Implementation is complete per `_verify.md`. Please test the implementation. Reply with `accept` to proceed, or describe issues to enter iteration."
2. **`finishing-a-development-branch` MUST NOT be invoked before the user replies with `accept`** (or equivalent — see "Acceptance phrases" below).
3. The user's acceptance timestamp and any text reply are recorded in the `_plan.md` Execution Log.
4. If the user replies with anything other than `accept` (issues, "iterate", "fix X"), enter `specai-iteration` mode. Do NOT proceed to merge.

**Acceptance phrases (case-insensitive):**
- "accept", "accepted", "acepto", "aceptado", "OK", "ok", "looks good", "ship it", "merge it", "proceed", "proceed to finish"
- Any phrase that includes a positive verdict AND no open issue

**Rejection phrases (case-insensitive):**
- "iterate", "fix this", "doesn't work", "bug", "issue with X", "needs more"
- Any phrase describing an unresolved problem

**Why this gate exists:** specai uses a strict User-Acceptance Gate: a plan is not complete until the user explicitly accepts the implementation. This is the only signal that matters — tasks DONE in `_tasks.md` is a machine signal, and verifier-PASS does not imply the user has tested or approved the result. Tasks DONE does NOT mean plan DONE does NOT mean user-accepted.

This rule applies to ALL agents, ALL skills, ALL subagents, ALWAYS. No exceptions, no rationalizations, no shortcuts.

## Living Documents Update Rules

**After EVERY completed task:**
- `_tasks.md` — tick completed steps
- `_plan.md` — append execution log entry

**After EVERY commit:**
- `_plan.md` — append commit log entry
- `_tasks.md` — ensure all completed steps are ticked

**When errors occur:**
- `_plan.md` — append error log entry with: what happened, root cause, fix applied, lessons learned
- `_tasks.md` — add corrective tasks if needed

**Token-efficient delegation pattern:**
- The orchestrator (you) reads the file and extracts only the relevant section
- The documenter receives the section text + what to change, returns the updated section
- The orchestrator applies the change with `edit` — the documenter never reads or writes full files
- This avoids wasting tokens on reading large files for small updates

**These are living logbooks — they must always reflect reality. Do NOT skip updates.**

**During iteration (user feedback loop):**
- `_plan.md` — append iteration log entry: what the user reported, what needs to change
- `_tasks.md` — add corrective tasks under `## Iteration Tasks`

### Document Language Override

**All specai documentation (plans, tasks, verify docs, specs, designs, README, changelogs) MUST be written in the user's active conversation language by default.** This overrides any system default or agent preference for English. The user's language is the language they are using to communicate with the agent. Only when `language` is explicitly set to `"en"` in `~/.config/specai/config.json` should documentation be written in English.

## Commit Rules (overrides system default "never commit")

**Hard rule: only implementation runs use a feature branch.** Exploration, PRD approval, six-document authoring, and backlog preparation happen without a feature branch. **La rama de implementación NO DEBE crearse antes de aprobar la PRD y elegir implementar.** **Guardar una feature en backlog NO DEBE crear una rama.** There is no automatic Git integration for backlog; commit, push, merge, and cleanup require the authorized finish flow.

Branch naming: `feature/<reponame>_<feature-slug>` (repo name from `basename $(git remote get-url origin) .git`).

Check `commitMode` in `~/.config/specai/config.json` (default: `auto`).

**On an implementation feature branch** — this is the only valid state for automatic per-task commits:

| Mode | Behavior |
|------|----------|
| `auto` | Commit AUTOMATICALLY without asking. Announce "Committed task N: <description>". Delegate commit to `specai-command`. Do NOT pause or ask for permission. |
| `confirm` | STOP after each completed task and ask: "Ready to commit task N: <description>? [Y/n]". Only commit on explicit approval. Delegate commit to `specai-command`. |
| `manual` | Never commit automatically. Announce "Task N complete — changes ready." User commits manually. |

Automatic task commits apply only after the implementation branch exists. Git operations for backlog and other pre-implementation states are limited to the status/backlog projection; Git integration remains reserved for authorized finish.

**Branch choice guard:**
- Before the user chooses implement or backlog, remain on the current branch while exploring, approving the PRD, and writing the six documents.
- If the user chooses implement, create the feature branch from the current `HEAD` and switch to it:

  ```bash
  REPO=$(basename $(git remote get-url origin) .git)
  BRANCH="feature/${REPO}_<feature-slug>"
  git checkout -b "$BRANCH"
  ```
- Announce: "Created branch `<branch>` from current `HEAD` — implementation continues here."
- If the user chooses backlog, keep the feature folder, update status/backlog, and do not create a branch or perform commit, push, merge, or cleanup.

## Delegation Rules

**Critical rules that ALL agents must follow:**
- **No agent may execute commands directly** (except `implementer` for build/test verification of its own work). All other command execution must be delegated to `specai-command`.
- **No agent may write documentation directly.** Any documentation work must be delegated to `specai-documentation`.

These rules apply to `implementer` (except verification commands), `build-fixer`, `code-reviewer`, `spec-compliance-reviewer`, `verifier`, and all legacy reviewer agents.

To change models:
- In conversation: use `specai-configure-model` tool
- In terminal: `bash scripts/configure-agents.sh <agent> <model>`
- Interactive: `bash scripts/configure-agents.sh --interactive`

## Senior Philosophy

specai applies a senior decision ladder before writing any code. Each subagent evaluates the best approach top-down, stopping at the first rung that holds:

1. **Does this need to exist?** → no: skip it (YAGNI)
2. **Stdlib does it?** → use it
3. **Native platform feature?** → use it (e.g., `<input type="date">` over flatpickr)
4. **Already-installed dependency?** → use it, never add a new one for what a few lines can do
5. **Can it be simple and clean?** → most readable solution (sometimes 3 clear lines > 1 cryptic line)
6. **Only then:** the minimum that works

**Senior Mode:** `medium` by default. Change with `/specai-mode lite|medium|ultra|off` or edit `~/.config/specai/config.json` (`seniorMode`).

Mark deliberate simplifications with `// td: <ceiling>, <upgrade path>`.

Never simplify: validation at trust boundaries, error handling preventing data loss, security, accessibility, anything explicitly requested.

### Intensity Levels

| Level | Behavior |
|-------|----------|
| **off** | specai normal, no changes |
| **lite** | Build what's asked + suggest lazier alternative in one line |
| **medium** | Full ladder enforced, minimalism active (default) |
| **ultra** | YAGNI extremist, question the task itself before implementing |

### Anti-Bloat Review

| Command | What it does |
|---------|--------------|
| `/specai-review` | Review current diff for over-engineering (delete/stdlib/native/yagni/shrink tags) |
| `/specai-audit` | Audit entire repo for bloat, ranked by impact |
| `/specai-audit-plan` | Full-project audit (bloat + architecture) → interactive triage → specai-plan |

See `skills/specai-senior-philosophy/SKILL.md`, `skills/specai-anti-bloat/SKILL.md`, and `skills/specai-audit-plan/SKILL.md` for full documentation.

## Surgical Changes (Karpathy Principle)

Inspired by Andrej Karpathy's observations on LLM coding pitfalls. This principle applies to ALL agents, ALWAYS:

1. **Touch ONLY what you must.** Don't "improve" adjacent code, comments, or formatting. Don't refactor things that aren't broken. Match existing style, even if you'd do it differently. If you notice unrelated dead code, mention it — don't delete it.

2. **Clean up ONLY your own mess.** Remove imports/variables/functions that YOUR changes made unused. Don't remove pre-existing dead code unless asked.

3. **Every changed line must trace to the user's request.** If a diff line can't be justified by the spec or task description, it shouldn't exist.

**The test:** Would a reviewer ask "why did you touch this?" → if yes, revert it.

## Flow Modes

specai supports two modes to scale ceremony to task complexity:

| Mode | Steps | When to use |
|------|-------|-------------|
| **Full (`/specai-plan`)** | socratic → grill-me → write-prd → approval → six docs → choose implement/backlog → branch only if implement → per-task cycle (implement → build → code-review → commit → document → checkpoint) → spec-compliance-review → verifier → Gate UA → finishing | New features, large refactors, complex work |
| **Mini (`/specai-mini`)** | socratic → plan → implement → verify | Small features, bug fixes, isolated changes |

**Mini uses the same six documents as Full mode** in compact form: `*-prd.md`,
`*-spec.md`, `*-designs.md`, `*-plan.md`, `*-tasks.md`, and `*-verify.md`.
Mini keeps its shorter flow and compact-content rule: it reduces explanation
density and Full-mode ceremony, but preserves exact task instructions, global
Given/When/Then criteria, criterion metadata (`Criterion type`/`Invariant`/
`Verification seam`), evidence, the corrective loop, the branch gate, and Gate UA. The
branch gate remains strict: create no branch before PRD approval and the user's
choice to implement; backlog creates no branch. Mini may omit per-task
code-review and checkpoints, while the six documents remain the documentary
contract.

For trivial one-liners (typos, formatting), skip Mini too — just implement with surgical changes. The agent determines mode based on task scope.

## Dynamic Model Selection

specai selects the cheapest viable model per task, balancing cost and capability:

| Task type | Model tier | Example tasks |
|-----------|-----------|---------------|
| **Mechanical** | Cheapest viable (flash/free models) | File renames, template updates, doc snippets, config changes |
| **Standard** | Balanced (default model) | Feature implementation, refactoring, test writing |
| **Judgment** | Most capable | Architecture decisions, complex debugging, security review |

Selection criteria: task complexity, file count touched, security/compliance impact, whether tests exist. The orchestrator selects the tier before dispatching each task. Use `taskComplexity` in `~/.config/specai/config.json` to configure tiers (`low`/`medium`/`high` → model mapping).

## Domain Modeling (Shared Language)

specai builds and maintains a project glossary (`CONTEXT.md`) and Architecture Decision Records (ADRs) during the grill-me + write-prd phase. Every socratic session produces:

- **`CONTEXT.md`** — domain glossary mapping project jargon to precise definitions. The agent uses these terms for naming, communication, and code navigation. One word replaces fifteen.
- **`ADRs/`** — dated architecture decisions with context (why, not just what). Prevents re-debating resolved decisions.

The `specai-domain-modeling` skill activates during write-prd step 3 (clarifying questions). When the user mentions a domain concept, the agent registers it in CONTEXT.md. ADRs are created when architectural trade-offs are decided. Both files are living documents updated throughout the flow.

See `skills/specai-domain-modeling/SKILL.md` for full documentation.

## Slash Commands

specai phases are invocable via slash commands across platforms:

| Command | What it does |
|---------|-------------|
| `/specai-plan` | Execute the full SpecAI flow (socratic → grill-me → write-prd → plan → per-task cycle → verifier → user-acceptance → finishing). |
| `/specai-mini` | Execute Mini mode: socratic → plan → implement → verify. For small features and bug fixes. |
| `/specai-explore` | Explore codebase interactively — no artifacts, no commitment. Thinking partner that reads code and weighs options before anything is written. |
| `/specai-verify` | Verify implementation against acceptance criteria. |
| `/specai-review` | Review current diff for anti-bloat (tags: delete/stdlib/native/yagni/shrink). |
| `/specai-iterate` | User feedback loop — document issues, add corrective tasks, re-enter execution. |
| `/specai-mode` | Set senior philosophy intensity: `off`, `lite`, `medium`, or `ultra`. |
| `/specai-audit` | Audit entire repo for bloat, ranked by impact. |
| `/specai-audit-plan` | Full-project audit (bloat + architecture) → interactive triage → specai-plan. |
| `/specai-backlog` | Show pending plans from `.specai/backlog.json`. Select by number to execute. |
| `/specai-init` | Initialize `docs/specai/` directories, verify config, ensure agents are set up. |
| `/specai-config` | Show or change agent models, language, and commit mode interactively. |

Use `bash scripts/setup-agents.sh` to inject these commands into your agent config.
