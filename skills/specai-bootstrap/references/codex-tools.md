# Codex Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use your platform equivalent:

| Skill references | Codex equivalent |
|-----------------|------------------|
| `Task` tool (dispatch subagent) | `spawn_agent` (see [Subagent dispatch requires multi-agent support](#subagent-dispatch-requires-multi-agent-support)) |
| Multiple `Task` calls (parallel) | Multiple `spawn_agent` calls |
| Task returns result | `wait_agent` |
| Task completes automatically | `close_agent` to free slot |
| `TodoWrite` (task tracking) | `update_plan` |
| `Skill` tool (invoke a skill) | Skills load natively — just follow the instructions |
| `Read`, `Write`, `Edit` (files) | Use your native file tools |
| `Bash` (run commands) | Use your native shell tools |

## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`.

Legacy note: Codex builds before `rust-v0.115.0` exposed spawned-agent
waiting as `wait`. Current Codex uses `wait_agent` for spawned agents. The
`wait` name now belongs to code-mode `exec/wait`, which resumes a yielded exec
cell by `cell_id`; it is not the spawned-agent result tool.

## SpecAI subagent context contract

Every SpecAI subagent dispatch MUST start a fresh session:

```text
spawn_agent(..., fork_context: false)
```

`fork_context: true` is forbidden for SpecAI work. It copies the controller's
conversation, which can include old tool output, unrelated instructions, and
large session history. If the platform cannot create an independent session,
stop and report the dispatch as blocked; do not silently fall back to a forked
context.

The first non-empty line of a full-flow handoff is `/specai-plan`. For Mini
mode it is `/specai-mini`. The handoff contains only: the role, one event, the
exact target paths, the current relevant section, the concrete requested
change, acceptance criteria, research facts required for that change, and the
canonical scheduling fields. Never include the parent transcript, the full
plan, unrelated tasks, previous tool output, or unrelated skills. Do not ask a
new subagent to discover the workflow or reconstruct the project from history.

The controller must serialize shared-document writes. Independent document
targets may run in parallel only when their `Shared Resources` do not overlap.

## Waiting and timeout contract

`wait_agent` returning `timed_out: true` means only that this polling interval
ended. It is NOT a terminal agent result and MUST NOT trigger an interrupt,
failure record, retry with a copied context, or task completion. Keep the agent
handle and poll again with the same bounded interval until a terminal result is
returned. Only an explicit terminal status (`completed`, `failed`, `blocked`,
or an explicit user cancellation) may close the handoff. If an external hard
deadline requires cancellation, send an explicit cancellation first and record
the resulting terminal state as `TASK_FAILED`; never report a timeout alone as
the cause of failure.

## Bounded native lifecycle

Every Codex dispatch has a bounded lifecycle. Before calling `spawn_agent`, the
adapter must verify `[features] multi_agent = true`; if the capability is
missing, the handoff is `TASK_BLOCKED` and the adapter must report the repair
action. Inline execution, a forked controller context, and a silent fallback
are forbidden. In particular, **inline execution is forbidden** when the
native harness is unavailable.

The handoff records these canonical values:

- `Max Runtime: 900 seconds` — the total runtime budget for one handoff.
- `Deadline: 900 seconds` — the absolute deadline calculated at dispatch.
- `Heartbeat every 30 seconds` — an observable progress event that includes
  the same agent handle and current lifecycle state.
- `Poll interval: 15 seconds` — the bounded interval passed to `wait_agent`.

`timed_out: true` only ends the current poll. The controller retains the same
handle and polls again until a terminal state or the deadline. On deadline,
the adapter issues the explicit `cancel_agent` operation, records
`TASK_FAILED` with `deadline_exceeded`, and then closes the terminal handle with
`close_agent`. It must never relaunch the task with copied or inherited
context. A user cancellation follows the same explicit cancellation path and
records the user's reason.

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
