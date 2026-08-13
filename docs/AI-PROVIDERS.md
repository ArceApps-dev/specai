# AI Providers — Tier mapping and the cheap-model advantage

> **Why this doc exists.** specai routes subagents to different model tiers by default. This is a real cost advantage for high-volume workflows where most subagent calls are mechanical. This page documents how.

## The tier mapping

specai's 7 core subagents map to three tiers:

| Tier | Subagents | Default model | Why this tier |
| --- | --- | --- | --- |
| **Mechanical** | `specai-documentation`, `specai-command` | `openrouter/deepseek/deepseek-v4-flash-free` | Tasks are mechanical: write a doc fragment, run `git add && git commit`. Premium model is wasted. |
| **Standard** | `code-reviewer`, `spec-compliance-reviewer`, `build-fixer` | `openrouter/deepseek/deepseek-v4-flash-free` | Tasks are pattern-matching on small diffs. Cheap model handles well. |
| **Judgment** | `implementer`, `verifier` | `minimax/MiniMax-M3` | Tasks require creative problem-solving and verification against criteria. Premium model needed. |

## Why this matters

| Tool | Model routing | Cost per typical run |
| --- | --- | --- |
| **specai** | Mechanical-tier (4 of 7 subagents) on cheap | baseline |
| OpenSpec | Single agent, user's CLI model | all premium |
| BMad | 12+ specialist agents, all premium | all premium |
| GitHub Spec Kit | User's CLI model | all premium |
| Task Master | Multi-provider, all at user's chosen model | all premium |
| Kiro | AWS-bundled Claude only | premium |
| Aider | User's chosen model | all premium |
| Cursor | Cursor's bundled model | bundled (premium) |
| Continue | User's chosen model | all premium |

**Rule of thumb:** on a 22-task plan with `specai-documentation` and `specai-command` running ~5 times each, ~10 mechanical calls route to cheap. That can be 40-60% of total token spend depending on the plan.

## How to override

Edit `~/.config/specai/config.json`:

```json
{
  "agentModels": {
    "implementer": "anthropic/claude-sonnet-4-20250514",
    "verifier": "anthropic/claude-sonnet-4-20250514",
    "build-fixer": "openrouter/deepseek/deepseek-v4-flash-free",
    "code-reviewer": "openrouter/deepseek/deepseek-v4-flash-free",
    "spec-compliance-reviewer": "openrouter/deepseek/deepseek-v4-flash-free",
    "specai-command": "openrouter/deepseek/deepseek-v4-flash-free",
    "specai-documentation": "openrouter/deepseek/deepseek-v4-flash-free"
  },
  "seniorMode": "medium",
  "language": "auto",
  "commitMode": "auto"
}
```

Then run `bash scripts/setup-agents.sh` to apply.

In-conversation: use the `specai-configure-model` tool to change a single agent's model without touching config.json.

In-terminal: `bash scripts/configure-agents.sh <agent> <model>`.

## How to verify

`bash scripts/specai-doctor.sh` includes a check (item #9) that verifies `specai-documentation` and `specai-command` are on a cheap model. If you've manually configured them to premium, doctor will warn.

## Cost math (illustrative)

For a 22-task plan with a typical mix of work, observed token spend on the default configuration:

| Subagent | Calls | Avg tokens / call | Tier | Cost tier |
| --- | --- | --- | --- | --- |
| `implementer` | 22 | 8,000 | Judgment | premium |
| `verifier` | 1 | 12,000 | Judgment | premium |
| `code-reviewer` | 22 | 3,000 | Standard | cheap |
| `build-fixer` | ~3 | 4,000 | Standard | cheap |
| `spec-compliance-reviewer` | 1 | 8,000 | Standard | cheap |
| `specai-documentation` | 22 | 1,500 | Mechanical | cheap |
| `specai-command` | ~80 | 800 | Mechanical | cheap |

If all 7 subagents used the judgment tier, the mechanical/standard ones would cost ~3-5× more. The tiered routing pays for itself on any plan with more than ~5 tasks.

## How to add a new provider

1. Verify the provider's API is supported by your agent runtime (Claude Code, OpenCode, etc.).
2. Find the model identifier your runtime expects (e.g. `openrouter/deepseek/deepseek-v4-flash-free`, `anthropic/claude-sonnet-4-20250514`).
3. Update `agentModels.<role>` in `~/.config/specai/config.json`.
4. Run `bash scripts/setup-agents.sh`.
5. Verify with `bash scripts/specai-doctor.sh`.
6. Run a small task to confirm the model behaves as expected.

If the new provider is dramatically cheaper or better, propose it via `/specai-audit-plan` so the change becomes a tracked decision with rationale.

## What this page is NOT

- **Not a model benchmark.** Compare benchmarks via the models' own docs.
- **Not a substitute for `scripts/configure-agents.sh`.** That script changes the config; this page documents the philosophy.
- **Not a guarantee.** Cheap models may give worse results on hard tasks. The role assignment (Mechanical / Standard / Judgment) is a starting point; tune per project.

## Cross-references

- `AGENTS.md` § Agent Configuration — short table view.
- `scripts/specai-doctor.sh` — verification of cheap-model routing.
- `docs/COMPARISON.md` — how this compares to competitors (none have role-tiered routing).