# Publishing a specai release to the public mirror

This document is the canonical how-to for cutting a new release of `specai`
and publishing the sanitized mirror to `github.com/ArceApps/specai` (public).

Audience: an AI agent or human operator who has never published a release
of this repo before and needs to do it without re-deriving the workflow.

## TL;DR (5 commands)

```bash
# 1. Make your changes on a feature branch — never on main
git checkout main
git pull origin main
git checkout -b release/<version>

# 2. Bump the version across all manifests
bash scripts/bump-version.sh <new-version>
#   (this updates package.json, .claude-plugin/plugin.json,
#    .cursor-plugin/plugin.json, .codex-plugin/plugin.json,
#    .claude-plugin/marketplace.json, gemini-extension.json)
#
#   The script reminds you to update RELEASE-NOTES.md manually
#   at the end — see step 3.

# 3. Add a new section at the TOP of RELEASE-NOTES.md
#    Format: "## vX.Y.Z (YYYY-MM-DD)" followed by Added / Changed /
#    Removed bullet groups.
#    Use the new version number, today's date.

# 4. Commit, push, tag
git add -A
git commit -m "chore: prepare release <new-version>"
git push origin release/<version>
git tag v<new-version>
git push origin v<new-version>

# 5. Publish the sanitized mirror to the public repo
#    (Currently a manual one-shot script — see below).
```

## Why a manual step?

The `.github/workflows/public-mirror.yml` workflow that previously mirrored
on tag push was removed because it could not authenticate cross-repo
pushes reliably from within Actions (HTTP 403 from `github-actions[bot]`).
The first release (`v1.0.0`) and any subsequent one until the workflow
is re-introduced are pushed by hand using the operator's local `gh auth`
credentials.

## Publishing the sanitized mirror (step 5 in detail)

This is the actual one-shot that produced `v1.0.0`. Re-run it for each
new release. **Use a clean staging directory** — do not run it from the
private repo itself.

```bash
# Clone the tag we just pushed
git clone https://github.com/ArceApps/specai-private /tmp/specai-staging
cd /tmp/specai-staging
git checkout v<new-version>

# Apply the Política A exclusion list (must match the .gitignore block)
INTERNAL=(
  "RELEASE-NOTES.md"
  ".specai"
  "tests"
  "hooks"
  "docs/specai"
  "docs/plans"
  "docs/windows"
  "docs/testing.md"
  ".version-bump.json"
)
for p in "${INTERNAL[@]}"; do
  [ -e "$p" ] && rm -rf "$p"
done

# Commit the sanitized tree
git config user.name  "specai Public Mirror Bot"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -m "chore: release <new-version>" \
           -m "Mirrored from ArceApps/specai-private at tag v<new-version>." \
           -m "Internal paths (tests/, hooks/, docs/specai/, RELEASE-NOTES.md, etc.) are NOT mirrored."

# Push --force to the public mirror
git push https://github.com/ArceApps/specai.git HEAD:main --force

# Push the tag so `git clone --branch v<new-version>` works for users
git push https://github.com/ArceApps/specai.git refs/tags/v<new-version>:refs/tags/v<new-version>
```

After the push, create the GitHub Release with the vX.Y.Z section from
`RELEASE-NOTES.md` as the body. The Release title is `specai <new-version>`.

## What is in the public mirror vs. the private canónico

`ArceApps/specai-private` (private, canónico) contains everything — your
working notes, `docs/specai/` specs, `tests/` fixtures, `RELEASE-NOTES.md`,
the `hooks/` runtime, `.specai/` local state, and `.version-bump.json`.

`ArceApps/specai` (public, mirror) contains only the product: README,
LICENSE, the skill library under `skills/`, the scripts under `scripts/`,
the per-harness plugins under `.claude-plugin/`, `.cursor-plugin/`,
`.codex-plugin/`, `.gemini-plugin/`, `.antigravity-plugin/`, the public
documentation under `docs/` (only the four files at the root of `docs/` —
`AI-PROVIDERS.md`, `COMPARISON.md`, `FAILURE-MODES.md`,
`README.opencode.md`), and the OpenCode plugin manifests under
`.opencode/`.

The exclusion list lives in two places that **must stay in sync**:

- `.gitignore` of the private repo, lines starting `# Paths explicitly
  excluded from the public mirror`. The shell block above reads from
  this same list.
- The `INTERNAL` bash array in this file. If you ever re-introduce the
  workflow, copy this list into its `INTERNAL` array.

## If `scripts/bump-version.sh` is not yet set up to remind about RELEASE-NOTES

The version bump script currently updates only the manifests. Until the
release-reminder is wired into it (a planned follow-up), the operator
must add the release-notes section manually after the bump. Search for
"WORKFLOW: REMINDER TO UPDATE RELEASE-NOTES" in the worktree if you
want to find the follow-up site.

## Verifying a release

After publishing, in a fresh shell:

```bash
# Does the public tree match what we expect?
gh api repos/ArceApps/specai/git/trees/main?recursive=1 | jq '.tree | length'
# Expected: ~219 entries (144 blobs + 75 trees) at the time of v1.0.0.

# Are the tags present?
gh api repos/ArceApps/specai/tags --jq '.[].name'

# Does the release exist and have the right body?
gh release view v<new-version> --repo ArceApps/specai --json body --jq '.body | length'
# Expected: a few thousand characters of release notes.
```

## When you reintroduce the workflow

If you re-add `.github/workflows/public-mirror.yml`, the auth strategy
that worked locally is **plain `gh` CLI** (it is preinstalled on
`ubuntu-latest` runners). Plan:

1. Generate a fine-grained PAT with `Contents: Read and write` on both
   `ArceApps/specai-private` and `ArceApps/specai`.
2. Store it as `PUBLIC_RELEASE_TOKEN` secret on the private repo.
3. In the workflow step that does the push, use:
   ```yaml
   env:
     GH_TOKEN: ${{ secrets.PUBLIC_RELEASE_TOKEN }}
   run: |
     gh repo sync ArceApps/specai \
       --source ArceApps/specai-private --force
   ```
4. Verify with a probe repo (e.g. `ArceApps/_mirror_test`) before
   pointing it at the real public repo.

Before doing any of this, run a 5-line end-to-end script in local that
mimics the runner workflow exactly (host, secret, URL, push). It is
cheaper to debug locally than on each Actions run.
