# specai vs. the alternatives

> **Honest positioning.** This page states — without marketing spin — when specai is the right tool and when one of the alternatives fits better.
>
> **Verification:** All facts (stars, fork counts, current versions) verified 2026-07-08 against the public repos. Numbers may drift; the qualitative picture does not.

## The honest one-liner per tool

| Tool | One sentence | Stars (Jul 2026) |
| --- | --- | --- |
| **specai** | A methodology-first framework that turns coding agents into disciplined engineers through **rigid per-task cycles**, **multi-role subagents with cheap-model routing**, and **living documents** plus an enforced User-Acceptance Gate. | small (independent project) |
| **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** | Spec-driven development with delta specs and versioned domain specs. Fluid, "enablers not gates", user-triggered `opsx:archive`. | 59.3k ★ |
| **[GitHub Spec Kit](https://github.com/github/spec-kit)** | Official first-party GitHub SDD toolkit with `constitution / specify / plan / tasks / implement` commands. Heavyweight, opinionated. | 119k ★ |
| **[BMad Method](https://github.com/bmad-code-org/BMAD-METHOD)** | Agile AI-driven development with 12+ specialist agents, scale-adaptive intelligence, and risk-based test strategy (TEA module). | 50.2k ★ |
| **[Task Master AI](https://github.com/eyaltoledano/claude-task-master)** | MCP-based task management with multi-AI provider support (Anthropic, OpenAI, Gemini, Perplexity, xAI, OpenRouter). | 27.8k ★ |
| **[AWS Kiro](https://kiro.dev)** | IDE with native spec-driven workflows (requirements → design → tasks) and dependency-graph parallel task execution. | n/a |
| **[Aider](https://aider.chat)** | AI pair-programming in the terminal with `CONVENTIONS.md` for project-specific rules. Lightweight, no methodology. | n/a |
| **[Cursor](https://docs.cursor.com)** | IDE with declarative `.cursorrules` files. Strong editor integration; minimal methodology. | n/a |
| **[Continue](https://github.com/continuedev/continue)** | Open-source coding agent for VS Code / JetBrains / CLI. Configuration-rich but methodology-light. | 34.7k ★ |

## When to use what

| If you want | Use |
| --- | --- |
| **Rigid per-task cycles with subagent discipline and YAGNI as an executable skill** | specai |
| **Fluid spec-driven dev where you archive changes yourself (`opsx:archive`) and version domain specs over time** | OpenSpec |
| **A first-party GitHub tool with strong brand trust and `constitution` governance** | GitHub Spec Kit |
| **Modular agile methodology with PM / Architect / UX / TEA roles and 34+ workflows** | BMad Method |
| **MCP-based task management that works across editors (Cursor, Windsurf, VS Code)** | Task Master AI |
| **An IDE that owns the whole spec workflow (requirements / design / tasks) with built-in dependency-graph execution** | AWS Kiro |
| **A convention file (`CONVENTIONS.md`) that the agent reads; nothing more** | Aider |
| **A feature-rich editor with declarative project rules** | Cursor |
| **An open-source coding agent for VS Code / JetBrains with rule files and a config layer** | Continue |

## specai's distinctives (defensible, not aspirational)

1. **YAGNI as an executable skill.**
   specai is the only tool that ships a 6-rung decision ladder (YAGNI → stdlib → native → existing dep → simple → minimum) with three enforcement mechanisms:
   - `// td:` markers in code that the implementer leaves as deliberate-simplification receipts.
   - `/specai-review` — diff-level reviewer that emits a `net: -N lines possible.` summary.
   - `/specai-audit` and `/specai-audit-plan` — repo-wide and project-wide bloat audits.

   None of OpenSpec, Spec Kit, BMad, Task Master, Kiro, Aider, Cursor, or Continue ships an equivalent enforced anti-overengineering gate.

2. **Role-tiered model routing for cost efficiency.**
   `specai-documentation` and `specai-command` are routed by default to `deepseek-v4-flash-free`. Only `implementer`, `verifier`, and `code-reviewer` reach the premium tier. None of the 10 alternatives has comparable role-tiered model selection. The cheap-model advantage is documented at `docs/AI-PROVIDERS.md`.

3. **User-Acceptance Gate (UA) — closed-loop implementation.**
   Implementation does NOT equal plan complete. The user must explicitly accept before `finishing-a-development-branch` runs. OpenSpec enforces the same via `opsx:archive`. BMad, Spec Kit, Task Master, Kiro, Aider, Cursor, and Continue do not have an equivalent gate; they assume verifier-PASS or test-PASS equals done.

4. **Living documents per feature, auto-updated.**
   `designs.md` + `plan.md` + `tasks.md` + `verify.md` per spec, kept current by `specai-documentation`. OpenSpec change folders are similar in structure; they are not auto-updated.

5. **Multi-harness via plugins without losing the methodology.**
   Plugins for OpenCode, Claude Code, Gemini CLI, Cursor, Copilot CLI, Antigravity, Factory Droid, Kimi, Pi. The methodology runs wherever the agent runs.

6. **i18n as a first-class concern.**
   README in English and Spanish; skill bodies in English with Spanish comments where helpful. None of the 9 alternatives ships multi-lingual docs.

## specai's trade-offs (honest)

- **Ceremony.** The Iron Rule gates and the per-task cycle add overhead. For trivial one-line edits, use `/specai-mini` or skip specai entirely.
- **Smaller community.** specai has fewer pre-built skills than the broader ecosystem but covers the same essential flow.
- **Mono-repo assumption.** The living-documents pattern assumes one spec → one feature → one branch in one repo. Cross-repo planning (OpenSpec's "stores" beta) is not supported.
- **No IDE integration.** Unlike Kiro (which owns the IDE) or Cursor (which integrates into the editor), specai is agent-runtime agnostic. You bring your own editor.

## The two philosophical axes

| | Rigor (gates enforced) | Fluidity (enablers, not gates) |
| --- | --- | --- |
| **Living documents** | specai (4 files per feature, auto-updated) | OpenSpec (5 artifacts per change, user-archiving) |
| **Acceptance** | specai (UA gate, user-triggered) | OpenSpec (`opsx:archive`) |
| **Spec discipline** | GitHub Spec Kit (constitution, clarify, analyze) | OpenSpec (enablers) |
| **Anti-bloat** | specai (YAGNI ladder, `// td:`, review/audit) | none |
| **Subagent discipline** | specai (7 specialized subagents, gates S0-S6) | BMad (12+ agents, scale-adaptive) |

**specai occupies the rigor axis.** If your pain is "the agent over-engineers and I can't stop it", specai is the answer. If your pain is "the agent makes untracked changes and I can't review them", OpenSpec is the answer. If your pain is "I want brand trust and a GitHub-maintained toolchain", GitHub Spec Kit is the answer.

## Cross-references

- [README.md](../README.md) — entry point and quick start
- [docs/AI-PROVIDERS.md](AI-PROVIDERS.md) — model tier mapping and the cheap-model advantage in detail
- [docs/FAILURE-MODES.md](FAILURE-MODES.md) — canonical error catalogue
- `docs/specai/audit-findings.md` — this audit's own findings, numbered as `/specai-audit-plan` Phase 3 output

---
*Verified 2026-07-08 against public repos. If anything is outdated, file an issue — this page is the public commitment to accuracy.*