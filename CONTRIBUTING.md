# Contributing to specai

Thanks for your interest in contributing to specai. This document explains how
the project is governed, how to set up a local development environment, and
how to land a change.

> **Project status.** specai is currently maintained by **ArceApps**
> ([github.com/ArceApps](https://github.com/ArceApps)). The canonical source of
> truth lives in **`ArceApps/specai-private`**; the public mirror at
> [`ArceApps/specai`](https://github.com/ArceApps/specai) is generated via a
> release-time publishing pipeline. **Open all PRs against `dev` — never
> against `main`.** `main` is the released branch.

---

## 1. Code of Conduct

By participating, you agree to abide by [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
Reports of unacceptable behavior should be sent to the maintainers listed in
`CODEOWNERS`.

---

## 2. Project governance

### 2.1 Current model (during growth)

| Role | Who | Permissions |
|------|-----|-------------|
| **Owner** | `ArceApps` (`CODEOWNERS` first entry) | Final review on every area; can approve PRs that touch protected paths; cuts releases |
| **Maintainer** | TBD (opt-in by owner) | Merge rights on non-`CODEOWNERS`-only paths after promotion |
| **Contributor** | Anyone with merged PRs | No direct merge access; submits PRs and addresses review |

### 2.2 Promoting a contributor to maintainer

A contributor becomes a maintainer after **all** of the following:

1. At least **two non-trivial PRs** merged into `dev`.
2. Has **authored the review on at least one PR from another contributor**.
3. Submit a PR adding themselves to `CODEOWNERS` under `/skills/`, `/scripts/`,
   or another non-protected area they own, **with the existing owner as the
   co-owner for the line they are claiming**. Self-add to lines the owner owns
   alone are not accepted.
4. The owner accepts the promotion in a public comment on the PR.

Promotion is **opt-out**: a maintainer can hand the role back at any time.

### 2.3 Adding an owner

Owner additions require an explicit PR signed off by **all** current owners.
Treated as a security change; reviewed with extra scrutiny.

---

## 3. Types of contributions

specai accepts the following kinds of contributions:

- **Bug reports** — `.github/ISSUE_TEMPLATE/bug_report.md`.
- **Feature requests** — `.github/ISSUE_TEMPLATE/feature_request.md`.
- **Platform/IDE support requests** — `.github/ISSUE_TEMPLATE/platform_support.md`.
- **Pull requests** — see §4 below.
- **Documentation fixes** — README, `docs/`, blog posts. Lowest review bar.

Issues filed by AI agents are welcome, but please identify the model + harness
in the issue body — see each template's "Environment" section.

---

## 4. Development setup

```bash
# 1. Clone the canonical (private) repo
gh repo clone ArceApps/specai-private ~/Projects/github/ArceApps/specai-private
cd ~/Projects/github/ArceApps/specai-private

# 2. (Optional) install the plugin into your harness
./specai install
bash scripts/setup-agents.sh

# 3. Sanity check
bash scripts/specai-doctor.sh
```

A passing `specai-doctor` is **required** before you open a PR (see §5.5).

---

## 5. Pull request workflow

### 5.1 Branching

- **All work on a feature branch.** Never commit directly to `dev` or `main`.
- Branch name: `feature/<short-slug>` (e.g. `feature/plugin-audit-and-contributing`).
- One branch per logical change. Unrelated cleanups → separate PR.

### 5.2 Commits

- Atomic commits. Each commit should leave the tree in a coherent state.
- Subject line ≤ 72 characters, imperative mood ("add X", not "added X").
- Body explains **why**, not what. Diff explains what.
- No fixup commits in the final history of a PR; squash before requesting review.

### 5.3 Required checks before opening the PR

| Check | Command |
|-------|---------|
| `specai-doctor` passes | `bash scripts/specai-doctor.sh` |
| Doctor hasn't gone stale | `bash scripts/specai-update.sh --check` (exits non-zero if SKILL frontmatter drifted) |
| JSON configs parse | `python3 -m json.tool < .opencode/commands.json > /dev/null` |
| No new obsolete references | `grep -rE 'brainstorming|specai-(execute|new|socratic-clarifier|assumptions-review)' .antigravity-plugin/ .claude-plugin/ .codex-plugin/ .cursor-plugin/ .opencode/ scripts/` — must be empty |

### 5.4 Skill changes require evaluation

Per `PULL_REQUEST_TEMPLATE.md`, if your PR touches a skill (anything under
`skills/**/SKILL.md`):

- Run `specai:writing-skills` first to apply the skill-authoring checklist.
- Run at least one adversarial probe against the modified skill and paste
  transcripts in the PR description (the PR template has a "Rigor" section).
- Don't modify carefully-tuned content (Red Flags tables, rationalizations,
  "human partner" language) without evaluation evidence showing the change is
  an improvement.

### 5.5 PR review process

1. Open the PR against **`dev`**. The PR template will reject PRs against
   `main` without comment.
2. Fill every required field in `.github/PULL_REQUEST_TEMPLATE.md`. Empty
   placeholders will close the PR without review.
3. Wait for review. The owner can request changes; address them in new commits
   or reply with reasoning.
4. Merge policy: the owner squashes and merges once `specai-doctor` +
   `specai-update --check` + CI are green and review is approved.
5. The release pipeline (`scripts/bump-version.sh` + GitHub Actions mirror)
   pulls `dev` → `main` → public mirror on the next `v*` tag.

### 5.6 Adding a new harness

If your PR adds support for a new IDE or harness:

- Add a new top-level directory (e.g. `.your-plugin/`) following the existing
  harness conventions; reference `./skills/` directly in your `plugin.json` —
  do **not** duplicate the skill files.
- The PR template has a "Clean-session transcript" section. **Fill it.**
  The required smoke test phrase is `Let's make a react todo list`; the
  harness must auto-trigger `specai-grill-me` (or `specai-bootstrap` →
  `specai-grill-me`) before any code is written.
- PRs that ship manual file copies, `npx skills` shims, or per-session
  opt-in will be closed. The integration must load the specai bootstrap at
  session start. See `PULL_REQUEST_TEMPLATE.md` for details.
- **Exception — harnesses that discover skills directly from a directory**
  (no plugin-manifest layer; examples: Hermes by reading `$HERMES_HOME/skills/<name>/SKILL.md`)
  do **not** need a `.your-plugin/` directory. Instead, extend `./specai`
  (the manager) with an `install-<harness>` subcommand that symlinks the
  skills into the harness's discovery directory. The single source of
  truth stays `./skills/`; the manager just bridges into the target.

---

## 6. What does **not** belong in this repo

- **Project-specific skills.** If you want a skill that only benefits one
  domain (e.g. a specific ML framework), publish a separate plugin that
  depends on specai, or include it in your project's `.agents/`.
- **Third-party service integrations.** Anything that promotes a paid service
  is rejected for the core library; ship it as a separate plugin.
- **Bundled unrelated changes.** A PR that fixes a typo and rewrites a skill
  will be split or closed.

---

## 7. Releases

Releases are managed by the owner via `scripts/bump-version.sh`. The mirror
to `ArceApps/specai` is automated by GitHub Actions on push of a `v*` tag.
**Don't push tags yourself** until you understand the mirror's exclusion
list — see `RELEASE.md` for the contract.

---

## 8. Getting help

- File an issue (templates in `.github/ISSUE_TEMPLATE/`).
- Read `AGENTS.md` for how the specai workflow expects you to think.
- Read `docs/FAILURE-MODES.md` before opening "it doesn't work" issues.
