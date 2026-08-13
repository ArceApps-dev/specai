#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s classify --repo PATH [--ref REF] | release-notes --notes PATH --tag TAG | --mode MODE --repo PATH --destination PATH [--ref REF] [--confirmation VALUE]\n' "$0" >&2
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

json_array() {
  local -n items=$1
  local first=1 item

  printf '['
  for item in "${items[@]}"; do
    if ((first)); then
      first=0
    else
      printf ','
    fi
    printf '"'
    json_escape "$item"
    printf '"'
  done
  printf ']'
}

json_string() {
  printf '"'
  json_escape "$1"
  printf '"'
}

json_nullable_string() {
  if [[ -n "$1" ]]; then
    json_string "$1"
  else
    printf 'null'
  fi
}

sort_paths() {
  local -n items=$1
  if ((${#items[@]} == 0)); then
    return
  fi
  mapfile -t items < <(printf '%s\n' "${items[@]}" | LC_ALL=C sort -u)
}

is_allowed() {
  case "$1" in
    AGENTS.md|CLAUDE.md|CODE_OF_CONDUCT.md|CODEOWNERS|CONTRIBUTING.md|GEMINI.md|LICENSE|README.md|README.es.md|RELEASE.md|gemini-extension.json|package.json|specai)
      return 0
      ;;
    docs/AI-PROVIDERS.md|docs/COMPARISON.md|docs/FAILURE-MODES.md|docs/README.opencode.md|docs/soul.md)
      return 0
      ;;
    .antigravity-plugin/*|.opencode/*|assets/*|hooks/*|scripts/*|skills/*|souls/*)
      return 0
      ;;
    .agents/plugins/marketplace.json|.claude-plugin/plugin.json|.codex-plugin/plugin.json|.cursor-plugin/plugin.json)
      return 0
      ;;
  esac
  return 1
}

is_excluded() {
  case "$1" in
    .codex/*|.claude-plugin/marketplace.json|.github/*|.gitattributes|.gitignore|.specai/*|.version-bump.json|CONTEXT.md|RELEASE-NOTES.md|docs/adr/*|docs/plans/*|docs/specai/*|docs/testing.md|docs/windows/*|tests/*)
      return 0
      ;;
  esac
  return 1
}

CLASSIFIED_ALLOWED_PATHS=()
CLASSIFIED_EXCLUDED_PATHS=()
CLASSIFIED_UNKNOWN_PATHS=()
CLASSIFICATION_ERROR=''

classify_paths() {
  local repo="$1"
  local ref="$2"
  local -a allowed_paths=()
  local -a excluded_paths=()
  local -a unknown_paths=()
  local path tree_entries_file=''

  CLASSIFICATION_ERROR=''

  git -C "$repo" rev-parse --verify "$ref^{commit}" >/dev/null

  if ! tree_entries_file=$(mktemp "${TMPDIR:-/tmp}/specai-classify.XXXXXX"); then
    CLASSIFICATION_ERROR='CLASSIFY_LS_TREE_FAILED'
    return 1
  fi
  if ! git -C "$repo" ls-tree -r -z --name-only "$ref" > "$tree_entries_file" 2>/dev/null; then
    rm -f -- "$tree_entries_file"
    CLASSIFICATION_ERROR='CLASSIFY_LS_TREE_FAILED'
    return 1
  fi

  while IFS= read -r -d '' path; do
    if is_allowed "$path"; then
      allowed_paths+=("$path")
    elif is_excluded "$path"; then
      excluded_paths+=("$path")
    else
      unknown_paths+=("$path")
    fi
  done < "$tree_entries_file"
  rm -f -- "$tree_entries_file"

  sort_paths allowed_paths
  sort_paths excluded_paths
  sort_paths unknown_paths

  CLASSIFIED_ALLOWED_PATHS=("${allowed_paths[@]}")
  CLASSIFIED_EXCLUDED_PATHS=("${excluded_paths[@]}")
  CLASSIFIED_UNKNOWN_PATHS=("${unknown_paths[@]}")

  ((${#unknown_paths[@]} == 0))
}

validate_manifest_references() {
  local repo="$1"
  local ref="$2"

  python3 - "$repo" "$ref" <<'PY'
import json
import posixpath
import subprocess
import sys

repo, ref = sys.argv[1:]
manifest_paths = subprocess.check_output(
    ["git", "-C", repo, "ls-tree", "-r", "--name-only", ref],
    text=True,
).splitlines()

manifest_paths = [
    path for path in manifest_paths
    if path.endswith("plugin.json") or path == ".agents/plugins/marketplace.json"
]

for manifest_path in manifest_paths:
    content = subprocess.check_output(
        ["git", "-C", repo, "show", f"{ref}:{manifest_path}"],
        text=True,
    )
    try:
        manifest = json.loads(content)
    except json.JSONDecodeError:
        continue

    def visit(value):
        if isinstance(value, dict):
            for child in value.values():
                yield from visit(child)
        elif isinstance(value, list):
            for child in value:
                yield from visit(child)
        elif isinstance(value, str) and value.startswith("./"):
            yield value

    for reference in visit(manifest):
        candidate = reference[2:]
        candidate = candidate.rstrip("/") or "."
        if candidate == ".":
            exists = True
        elif not posixpath.normpath(candidate).startswith("../"):
            exists = subprocess.run(
                ["git", "-C", repo, "cat-file", "-e", f"{ref}:{candidate}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode == 0
        else:
            exists = False
        if not exists:
            raise SystemExit(1)
PY
}

validate_codex_marketplace() {
  local repo="$1"
  local ref="$2"

  python3 - "$repo" "$ref" <<'PY'
import json
import subprocess
import sys

repo, ref = sys.argv[1:]
manifest_path = ".agents/plugins/marketplace.json"

exists = subprocess.run(
    ["git", "-C", repo, "cat-file", "-e", f"{ref}:{manifest_path}"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0
if not exists:
    raise SystemExit(0)

content = subprocess.check_output(
    ["git", "-C", repo, "show", f"{ref}:{manifest_path}"],
    text=True,
)
try:
    manifest = json.loads(content)
except json.JSONDecodeError:
    raise SystemExit(1)

if not isinstance(manifest, dict):
    raise SystemExit(1)
if manifest.get("name") != "specai":
    raise SystemExit(1)
if manifest.get("interface", {}).get("displayName") != "specai":
    raise SystemExit(1)

plugins = manifest.get("plugins")
if not isinstance(plugins, list) or len(plugins) != 1:
    raise SystemExit(1)

plugin = plugins[0]
if not isinstance(plugin, dict):
    raise SystemExit(1)
if plugin.get("name") != "specai":
    raise SystemExit(1)
if plugin.get("source") != {"source": "local", "path": "./"}:
    raise SystemExit(1)
if plugin.get("policy") != {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL",
}:
    raise SystemExit(1)
if plugin.get("category") != "Coding":
    raise SystemExit(1)
PY
}

PUBLIC_ROOT_MESSAGE='SpecAI public mirror root'
PUBLIC_ROOT_TRAILER='SpecAI-Mirror-Root: true'
PUBLIC_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$'
PUBLIC_SNAPSHOT_TREE=''
PUBLIC_SNAPSHOT_COMMIT=''
PUBLIC_SNAPSHOT_NOOP='0'
PUBLIC_SNAPSHOT_ERROR=''
PUBLIC_TAG_OUTCOME='SUCCESS'
PUBLIC_RELEASE_MARKER='<!-- specai-public-mirror:managed -->'
PUBLIC_RELEASE_OUTCOME='SKIPPED'
PUBLIC_LOCK_DIR=''

release_publication_lock() {
  local lock_dir="${PUBLIC_LOCK_DIR:-}"
  PUBLIC_LOCK_DIR=''
  if [[ -n "$lock_dir" ]]; then
    rmdir -- "$lock_dir" 2>/dev/null || true
  fi
}

acquire_publication_lock() {
  local destination="$1"
  PUBLIC_LOCK_DIR="${MIRROR_LOCK_DIR:-$destination/.git/specai-public-mirror.lock}"
  if ! mkdir -- "$PUBLIC_LOCK_DIR" 2>/dev/null; then
    PUBLIC_LOCK_DIR=''
    printf '%s\n' 'CONCURRENCY_CONFLICT' >&2
    return 1
  fi
  trap 'release_publication_lock' EXIT
}

build_public_snapshot() {
  local repo="$1"
  local ref="$2"
  local destination="$3"
  local source_sha="$4"
  local force_root="${5:-0}"
  local guard_main="${6:-0}"
  local result_file

  PUBLIC_SNAPSHOT_ERROR=''
  if [[ "$guard_main" == '1' ]]; then
    local current_main='' current_root_marker='' current_source_trailer=''
    if current_main=$(git -C "$destination" rev-parse --verify refs/heads/main^{commit} 2>/dev/null); then
      current_root_marker=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Root,valueonly)' "$current_main" 2>/dev/null || true)
      current_source_trailer=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Source-SHA,valueonly)' "$current_main" 2>/dev/null || true)
      if [[ "$current_root_marker" != 'true' || ! "$current_source_trailer" =~ ^[0-9a-f]{40}$ ]]; then
        PUBLIC_SNAPSHOT_ERROR='DESTINATION_DIVERGENCE'
        return 1
      fi
    fi
  fi

  if ! result_file=$(mktemp); then
    [[ -z "$result_file" ]] || rm -f -- "$result_file"
    return 1
  fi
  if [[ -z "$result_file" || ! -f "$result_file" ]]; then
    rm -f -- "$result_file"
    return 1
  fi
  if ! (
    set -euo pipefail
    local index_file
    if ! index_file=$(mktemp "${destination}/.git/public-mirror-index.XXXXXX"); then
      exit 1
    fi
    if [[ -z "$index_file" || ! -f "$index_file" ]]; then
      exit 1
    fi
    local tree_entries_file
    if ! tree_entries_file=$(mktemp); then
      exit 1
    fi
    if [[ -z "$tree_entries_file" || ! -f "$tree_entries_file" ]]; then
      exit 1
    fi
    trap 'rm -f -- "$index_file" "$tree_entries_file"' EXIT

    export GIT_INDEX_FILE="$index_file"
    git -C "$destination" read-tree --empty || exit 1

    local mode object_id path object_type copied_object_id
    if ((${#CLASSIFIED_ALLOWED_PATHS[@]} > 0)); then
      if ! git -C "$repo" ls-tree -r -z \
        --format='%(objectmode)%x00%(objectname)%x00%(path)' \
        "$ref" -- "${CLASSIFIED_ALLOWED_PATHS[@]}" > "$tree_entries_file"; then
        exit 1
      fi
      while IFS= read -r -d '' mode \
        && IFS= read -r -d '' object_id \
        && IFS= read -r -d '' path; do
        object_type=$(git -C "$repo" cat-file -t "$object_id") || exit 1
        if ! git -C "$destination" cat-file -e "$object_id" 2>/dev/null; then
          copied_object_id=$(git -C "$repo" cat-file "$object_type" "$object_id" \
            | git -C "$destination" hash-object -t "$object_type" -w --stdin) || exit 1
          [[ "$copied_object_id" == "$object_id" ]] || exit 1
        fi
        git -C "$destination" update-index --add --cacheinfo "$mode,$object_id,$path" || exit 1
      done < "$tree_entries_file"
    fi

    local tree parent='' message public_commit current_main='' current_tree='' snapshot_noop='0'
    local root_marker='' source_trailer=''
    tree=$(git -C "$destination" write-tree) || exit 1
    if [[ "$force_root" != '1' ]] && current_main=$(git -C "$destination" rev-parse --verify refs/heads/main^{commit} 2>/dev/null); then
      current_tree=$(git -C "$destination" rev-parse "${current_main}^{tree}") || exit 1
      if [[ "$current_tree" == "$tree" ]]; then
        snapshot_noop='1'
        public_commit="$current_main"
      else
        root_marker=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Root,valueonly)' "$current_main" 2>/dev/null || true)
        source_trailer=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Source-SHA,valueonly)' "$current_main" 2>/dev/null || true)
      fi
      if [[ "$snapshot_noop" != '1' && "$root_marker" == 'true' && "$source_trailer" =~ ^[0-9a-f]{40}$ ]]; then
        parent="$current_main"
      fi
    fi

    if [[ "$snapshot_noop" == '1' ]]; then
      :
    elif [[ -n "$parent" ]]; then
      message=$(printf 'SpecAI public mirror snapshot\n\nSpecAI-Mirror-Root: true\nSpecAI-Mirror-Source-SHA: %s\n' "$source_sha")
      public_commit=$(printf '%s\n' "$message" | \
        GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-SpecAI Mirror}" \
        GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-specai-mirror@example.invalid}" \
        GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-SpecAI Mirror}" \
        GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-specai-mirror@example.invalid}" \
        git -C "$destination" commit-tree "$tree" -p "$parent") || exit 1
    else
      message=$(printf '%s\n\nSpecAI-Mirror-Root: true\nSpecAI-Mirror-Source-SHA: %s\n' \
        "$PUBLIC_ROOT_MESSAGE" "$source_sha")
      public_commit=$(printf '%s\n' "$message" | \
        GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-SpecAI Mirror}" \
        GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-specai-mirror@example.invalid}" \
        GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-SpecAI Mirror}" \
        GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-specai-mirror@example.invalid}" \
        git -C "$destination" commit-tree "$tree") || exit 1
    fi

    printf '%s\n%s\n%s\n' "$tree" "$public_commit" "$snapshot_noop" > "$result_file" || exit 1
  ); then
    rm -f -- "$result_file"
    return 1
  fi

  PUBLIC_SNAPSHOT_TREE=$(sed -n '1p' "$result_file")
  PUBLIC_SNAPSHOT_COMMIT=$(sed -n '2p' "$result_file")
  PUBLIC_SNAPSHOT_NOOP=$(sed -n '3p' "$result_file")
  rm -f -- "$result_file"

  if [[ -n "${MIRROR_SNAPSHOT_FILE:-}" ]]; then
    printf '%s\n' "$PUBLIC_SNAPSHOT_COMMIT" > "$MIRROR_SNAPSHOT_FILE"
  fi
}

sync_public_tag() {
  local destination="$1"
  local tag="$2"
  local tag_ref="refs/tags/$tag"
  local existing_ref_oid=''
  local existing_commit=''
  local root_marker=''
  local source_trailer=''
  local zero_oid

  PUBLIC_TAG_OUTCOME='SUCCESS'
  if git -C "$destination" show-ref --verify --quiet "$tag_ref"; then
    if ! existing_ref_oid=$(git -C "$destination" rev-parse --verify "$tag_ref" 2>/dev/null); then
      PUBLIC_TAG_OUTCOME='DIVERGENCE'
      return 1
    fi
    if ! existing_commit=$(git -C "$destination" rev-parse --verify "$tag_ref^{commit}" 2>/dev/null); then
      PUBLIC_TAG_OUTCOME='DIVERGENCE'
      return 1
    fi
    if [[ "$existing_commit" != "$PUBLIC_SNAPSHOT_COMMIT" ]]; then
      root_marker=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Root,valueonly)' "$existing_commit" 2>/dev/null || true)
      source_trailer=$(git -C "$destination" show -s --format='%(trailers:key=SpecAI-Mirror-Source-SHA,valueonly)' "$existing_commit" 2>/dev/null || true)
      if [[ "$root_marker" == 'true' && "$source_trailer" =~ ^[0-9a-f]{40}$ ]]; then
        if ! git -C "$destination" update-ref "$tag_ref" "$PUBLIC_SNAPSHOT_COMMIT" "$existing_ref_oid"; then
          PUBLIC_TAG_OUTCOME='FAILED'
          return 1
        fi
        PUBLIC_TAG_OUTCOME='SUCCESS'
        return 0
      fi
      PUBLIC_TAG_OUTCOME='DIVERGENCE'
      return 1
    fi
    PUBLIC_TAG_OUTCOME='NOOP'
    return 0
  fi

  zero_oid=$(printf '%040d' 0)
  if ! git -C "$destination" update-ref "$tag_ref" "$PUBLIC_SNAPSHOT_COMMIT" "$zero_oid"; then
    PUBLIC_TAG_OUTCOME='FAILED'
    return 1
  fi
}

validate_destination_identity() {
  local repo="$1"
  local destination="$2"
  local destination_repository="${MIRROR_DESTINATION_REPOSITORY:-ArceApps/specai}"
  local repo_real_path
  local destination_real_path
  local fetch_urls
  local push_urls
  local origin_url

  if [[ "$destination_repository" != 'ArceApps/specai' ]]; then
    printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
    return 1
  fi

  fetch_urls=$(git -C "$destination" remote get-url --all origin 2>/dev/null) || {
    printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
    return 1
  }
  push_urls=$(git -C "$destination" remote get-url --push --all origin 2>/dev/null) || {
    printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
    return 1
  }
  while IFS= read -r origin_url; do
    case "$origin_url" in
      'https://github.com/ArceApps/specai.git'|'git@github.com:ArceApps/specai.git'|'ssh://git@github.com/ArceApps/specai.git')
        ;;
      *)
        printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
        return 1
        ;;
    esac
  done <<< "$fetch_urls"
  while IFS= read -r origin_url; do
    case "$origin_url" in
      'https://github.com/ArceApps/specai.git'|'git@github.com:ArceApps/specai.git'|'ssh://git@github.com/ArceApps/specai.git')
        ;;
      *)
        printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
        return 1
        ;;
    esac
  done <<< "$push_urls"

  repo_real_path=$(cd -- "$repo" && pwd -P)
  destination_real_path=$(cd -- "$destination" && pwd -P)
  if [[ "$repo_real_path" == "$destination_real_path" ]]; then
    printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
    return 1
  fi
}

replace_public_main_with_root() {
  local destination="$1"
  local current_main=''
  local zero_oid

  if current_main=$(git -C "$destination" rev-parse --verify refs/heads/main^{commit} 2>/dev/null); then
    git -C "$destination" update-ref refs/heads/main "$PUBLIC_SNAPSHOT_COMMIT" "$current_main"
  else
    zero_oid=$(printf '%040d' 0)
    git -C "$destination" update-ref refs/heads/main "$PUBLIC_SNAPSHOT_COMMIT" "$zero_oid"
  fi
}

cleanup_public_branches() {
  local destination="$1"
  local refs_file
  local branch_ref
  local branch_oid

  refs_file=$(mktemp)
  if ! git -C "$destination" for-each-ref --format='%(refname)' refs/heads > "$refs_file"; then
    rm -f -- "$refs_file"
    printf '%s\n' 'PUBLICATION_FAILED' >&2
    return 1
  fi

  while IFS= read -r branch_ref; do
    [[ -n "$branch_ref" ]] || continue
    [[ "$branch_ref" == 'refs/heads/main' ]] && continue
    if [[ "$branch_ref" != refs/heads/* ]] || ! branch_oid=$(git -C "$destination" rev-parse --verify "$branch_ref^{commit}" 2>/dev/null); then
      rm -f -- "$refs_file"
      printf '%s\n' 'PUBLICATION_FAILED' >&2
      return 1
    fi
    if ! git -C "$destination" update-ref -d "$branch_ref" "$branch_oid"; then
      rm -f -- "$refs_file"
      printf '%s\n' 'PUBLICATION_FAILED' >&2
      return 1
    fi
  done < "$refs_file"

  rm -f -- "$refs_file"
}

cleanup_public_tags() {
  local destination="$1"
  local refs_file
  local tag_ref
  local tag
  local tag_oid

  refs_file=$(mktemp)
  if ! git -C "$destination" for-each-ref --format='%(refname)' refs/tags > "$refs_file"; then
    rm -f -- "$refs_file"
    printf '%s\n' 'PUBLICATION_FAILED' >&2
    return 1
  fi

  while IFS= read -r tag_ref; do
    [[ -n "$tag_ref" ]] || continue
    [[ "$tag_ref" == refs/tags/* ]] || {
      rm -f -- "$refs_file"
      printf '%s\n' 'PUBLICATION_FAILED' >&2
      return 1
    }
    tag="${tag_ref#refs/tags/}"
    if ! tag_oid=$(git -C "$destination" rev-parse --verify "$tag_ref" 2>/dev/null); then
      rm -f -- "$refs_file"
      printf '%s\n' 'PUBLICATION_FAILED' >&2
      return 1
    fi
    if [[ "$tag" =~ $PUBLIC_TAG_PATTERN ]]; then
      if ! git -C "$destination" update-ref "$tag_ref" "$PUBLIC_SNAPSHOT_COMMIT" "$tag_oid"; then
        rm -f -- "$refs_file"
        printf '%s\n' 'PUBLICATION_FAILED' >&2
        return 1
      fi
      continue
    fi
    if ! git -C "$destination" update-ref -d "$tag_ref" "$tag_oid"; then
      rm -f -- "$refs_file"
      printf '%s\n' 'PUBLICATION_FAILED' >&2
      return 1
    fi
  done < "$refs_file"

  rm -f -- "$refs_file"
}

emit_classification() {
  printf '{"allowed_paths":'
  json_array CLASSIFIED_ALLOWED_PATHS
  printf ',"excluded_paths":'
  json_array CLASSIFIED_EXCLUDED_PATHS
  printf ',"unknown_paths":'
  json_array CLASSIFIED_UNKNOWN_PATHS
  printf '}\n'
}

write_audit_record() {
  local repo="$1"
  local ref="$2"
  local destination="$3"
  local mode="$4"
  local source_sha="$5"
  local outcome="$6"
  local error_code="$7"
  local source_repository="${MIRROR_SOURCE_REPOSITORY:-${GITHUB_REPOSITORY:-ArceApps/specai-private}}"
  local destination_repository="${MIRROR_DESTINATION_REPOSITORY:-ArceApps/specai}"
  printf '{"source_repository":'
  json_string "$source_repository"
  printf ',"source_ref":'
  json_string "$ref"
  printf ',"source_sha":'
  json_string "$source_sha"
  printf ',"destination_repository":'
  json_string "$destination_repository"
  printf ',"mode":'
  json_string "$mode"
  printf ',"allowed_paths":'
  json_array CLASSIFIED_ALLOWED_PATHS
  printf ',"excluded_paths":'
  json_array CLASSIFIED_EXCLUDED_PATHS
  printf ',"unknown_paths":'
  json_array CLASSIFIED_UNKNOWN_PATHS
  printf ',"public_commit":'
  json_nullable_string ''
  printf ',"public_tag":'
  json_nullable_string ''
  printf ',"public_release":'
  json_nullable_string ''
  printf ',"outcome":'
  json_string "$outcome"
  printf ',"error_code":'
  json_nullable_string "$error_code"
  printf '}\n'
}

write_audit() {
  [[ -n "${MIRROR_AUDIT_FILE:-}" ]] || return 0

  local temporary_file

  if ! temporary_file=$(mktemp "${MIRROR_AUDIT_FILE}.tmp.XXXXXX"); then
    return 1
  fi
  if ! write_audit_record "$@" > "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
  if ! mv -f -- "$temporary_file" "$MIRROR_AUDIT_FILE"; then
    rm -f -- "$temporary_file"
    return 1
  fi
}

write_audit_direct() {
  [[ -n "${MIRROR_AUDIT_FILE:-}" ]] || return 0

  if ! write_audit_record "$@" > "$MIRROR_AUDIT_FILE"; then
    return 1
  fi
}

prime_publication_audit() {
  [[ -n "${MIRROR_AUDIT_FILE:-}" ]] || return 0

  write_audit_record "$@" > "$MIRROR_AUDIT_FILE"
}

publication_failed() {
  local repo="$1"
  local ref="$2"
  local destination="$3"
  local mode="$4"
  local source_sha="$5"

  if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'PARTIAL' 'PUBLICATION_FAILED'; then
    if ! write_audit_direct "$repo" "$ref" "$destination" "$mode" "$source_sha" 'PARTIAL' 'PUBLICATION_FAILED'; then
      printf '%s\n' 'AUDIT_WRITE_FAILED' >&2
    fi
  fi
  printf '%s\n' 'PUBLICATION_FAILED' >&2
  return 1
}

classify() {
  local repo=''
  local ref='HEAD'
  local option

  while (($# > 0)); do
    option="$1"
    case "$option" in
      --repo)
        [[ $# -ge 2 ]] || { usage; return 2; }
        repo="$2"
        shift 2
        ;;
      --ref)
        [[ $# -ge 2 ]] || { usage; return 2; }
        ref="$2"
        shift 2
        ;;
      *)
        usage
        return 2
        ;;
    esac
  done

  [[ -n "$repo" && -d "$repo/.git" ]] || { usage; return 2; }
  git -C "$repo" rev-parse --verify "$ref^{commit}" >/dev/null

  if ! classify_paths "$repo" "$ref"; then
    if [[ -n "$CLASSIFICATION_ERROR" ]]; then
      printf '%s\n' "$CLASSIFICATION_ERROR" >&2
      return 1
    fi
    emit_classification
    printf '%s\n' 'UNKNOWN_PATH' >&2
    return 1
  fi
  emit_classification
}

extract_public_release_notes() {
  local notes_file="$1"
  local tag="$2"
  local public_notes=''

  if [[ ! -f "$notes_file" ]]; then
    printf '%s\n' 'INVALID_RELEASE_NOTES' >&2
    return 1
  fi

  if ! public_notes=$(awk -v tag="$tag" '
    BEGIN {
      tag_heading = "## " tag
      in_tag = 0
      in_public = 0
      found_public = 0
      body_count = 0
    }
    $0 == tag_heading {
      in_tag = 1
      next
    }
    in_tag && /^##[[:space:]]/ {
      exit
    }
    in_tag && $0 == "### Public release notes" {
      in_public = 1
      found_public = 1
      next
    }
    in_tag && in_public && /^###[[:space:]]/ {
      in_public = 0
      exit
    }
    in_tag && in_public {
      body[++body_count] = $0
    }
    END {
      while (body_count > 0 && body[body_count] ~ /^[[:space:]]*$/) {
        delete body[body_count--]
      }
      while (body_count > 0 && body[1] ~ /^[[:space:]]*$/) {
        for (i = 1; i < body_count; i++) {
          body[i] = body[i + 1]
        }
        delete body[body_count--]
      }
      if (!found_public || body_count == 0) {
        exit 1
      }
      for (i = 1; i <= body_count; i++) {
        print body[i]
      }
    }
  ' "$notes_file"); then
    printf '%s\n' 'INVALID_RELEASE_NOTES' >&2
    return 1
  fi

  printf '%s\n' "$public_notes"
}

prepare_public_release_body() {
  local repo="$1"
  local ref="$2"
  local tag="$3"
  local body_file="$4"
  local source_notes_file
  local public_notes_file

  source_notes_file=$(mktemp)
  public_notes_file=$(mktemp)

  if ! git -C "$repo" show "$ref:RELEASE-NOTES.md" > "$source_notes_file" 2>/dev/null; then
    rm -f -- "$source_notes_file" "$public_notes_file"
    return 2
  fi
  if ! extract_public_release_notes "$source_notes_file" "$tag" > "$public_notes_file" 2>/dev/null; then
    rm -f -- "$source_notes_file" "$public_notes_file"
    return 1
  fi

  {
    printf '%s\n' "$PUBLIC_RELEASE_MARKER"
    cat "$public_notes_file"
  } > "$body_file"
  rm -f -- "$source_notes_file" "$public_notes_file"
}

release_view_indicates_not_found() {
  local release_view_error="$1"
  local normalized_error

  normalized_error=$(printf '%s' "$release_view_error" | tr '[:upper:]' '[:lower:]')
  if [[ "$normalized_error" == *'command not found'* || "$normalized_error" == *'gh: not found'* ]]; then
    return 1
  fi
  if [[ "$normalized_error" != *$'\n'* &&
    "$normalized_error" =~ ^http/[0-9]+([.][0-9]+)?[[:space:]]+404[[:space:]]+not[[:space:]]+found[[:space:]]*$ ]]; then
    return 0
  fi
  [[ "$normalized_error" =~ ^release[[:space:]]+(not[[:space:]]+found|does[[:space:]]+not[[:space:]]+exist)[[:space:][:punct:]]*$ ]]
}

release_view_failure_category() {
  local release_view_status="$1"
  local release_view_error="$2"
  local normalized_error

  if release_view_indicates_not_found "$release_view_error"; then
    printf '%s' 'NOT_FOUND'
    return
  fi
  normalized_error=$(printf '%s' "$release_view_error" | tr '[:upper:]' '[:lower:]')
  if [[ "$normalized_error" =~ http[[:space:]]*([0-9]{3}) ]]; then
    case "${BASH_REMATCH[1]}" in
      401|403) printf '%s' 'AUTHORIZATION_FAILURE' ;;
      5[0-9][0-9]) printf '%s' 'REMOTE_FAILURE' ;;
      *) printf '%s' 'HTTP_FAILURE' ;;
    esac
    return
  fi
  case "$release_view_status" in
    126|127) printf '%s' 'COMMAND_FAILURE' ;;
    2) printf '%s' 'TRANSPORT_FAILURE' ;;
    *) printf '%s' 'RELEASE_VIEW_FAILURE' ;;
  esac
}

sync_public_release() {
  local tag="$1"
  local body_file="$2"
  local gh_bin="${MIRROR_GH_BIN:-gh}"
  local destination_repository="${MIRROR_DESTINATION_REPOSITORY:-ArceApps/specai}"
  local release_json=''
  local existing_tag=''
  local existing_body_file
  local release_view_error_file
  local release_view_error
  local release_view_status=0
  local release_view_category=''

  PUBLIC_RELEASE_OUTCOME='SUCCESS'
  existing_body_file=$(mktemp)
  release_view_error_file=$(mktemp)

  if release_json=$("$gh_bin" release view "$tag" --repo "$destination_repository" --json tagName,body 2>"$release_view_error_file"); then
    rm -f -- "$release_view_error_file"
    if ! existing_tag=$(printf '%s' "$release_json" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("tagName", ""))'); then
      PUBLIC_RELEASE_OUTCOME='FAILED'
      rm -f -- "$existing_body_file"
      return 1
    fi
    if [[ "$existing_tag" != "$tag" || ! "$existing_tag" =~ $PUBLIC_TAG_PATTERN ]]; then
      PUBLIC_RELEASE_OUTCOME='DIVERGENCE'
      rm -f -- "$existing_body_file"
      return 1
    fi
    if ! printf '%s' "$release_json" | python3 -c 'import json, pathlib, sys; pathlib.Path(sys.argv[1]).write_text(json.load(sys.stdin).get("body", ""), encoding="utf-8")' "$existing_body_file"; then
      PUBLIC_RELEASE_OUTCOME='FAILED'
      rm -f -- "$existing_body_file"
      return 1
    fi
    if cmp -s "$existing_body_file" "$body_file"; then
      PUBLIC_RELEASE_OUTCOME='NOOP'
      rm -f -- "$existing_body_file"
      return 0
    fi
    PUBLIC_RELEASE_OUTCOME='DIVERGENCE'
    rm -f -- "$existing_body_file"
    return 1
  else
    release_view_status=$?
  fi

  release_view_error=$(<"$release_view_error_file")
  rm -f -- "$release_view_error_file"
  if ! release_view_indicates_not_found "$release_view_error"; then
    release_view_category=$(release_view_failure_category "$release_view_status" "$release_view_error")
    printf 'GH_RELEASE_VIEW_FAILED status=%s category=%s\n' "$release_view_status" "$release_view_category" >&2
    PUBLIC_RELEASE_OUTCOME='FAILED'
    rm -f -- "$existing_body_file"
    return 1
  fi

  if ! "$gh_bin" release create "$tag" --repo "$destination_repository" --title "$tag" --notes-file "$body_file" >/dev/null 2>&1; then
    PUBLIC_RELEASE_OUTCOME='FAILED'
    rm -f -- "$existing_body_file"
    return 1
  fi
  rm -f -- "$existing_body_file"
}

cleanup_public_releases() {
  local gh_bin="${MIRROR_GH_BIN:-gh}"
  local destination_repository="${MIRROR_DESTINATION_REPOSITORY:-ArceApps/specai}"
  local release_list_file
  local release_json_file
  local tag
  local invalid_reference=0

  release_list_file=$(mktemp)
  release_json_file=$(mktemp)
  if ! "$gh_bin" release list --repo "$destination_repository" --limit 1000 --json tagName > "$release_json_file" 2>/dev/null; then
    rm -f -- "$release_list_file" "$release_json_file"
    printf '%s\n' 'INVALID_REFERENCE' >&2
    return 1
  fi
  if ! python3 - "$release_json_file" > "$release_list_file" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(data, list):
    raise SystemExit(1)
for item in data:
    if not isinstance(item, dict) or not isinstance(item.get("tagName"), str):
        raise SystemExit(1)
    print(item["tagName"])
PY
  then
    rm -f -- "$release_list_file" "$release_json_file"
    printf '%s\n' 'INVALID_REFERENCE' >&2
    return 1
  fi
  rm -f -- "$release_json_file"

  while IFS= read -r tag; do
    if [[ ! "$tag" =~ $PUBLIC_TAG_PATTERN ]]; then
      if ! "$gh_bin" release delete "$tag" --repo "$destination_repository" --yes >/dev/null 2>&1; then
        rm -f -- "$release_list_file" "$release_json_file"
        printf '%s\n' 'INVALID_REFERENCE' >&2
        return 1
      fi
      invalid_reference=1
    fi
  done < "$release_list_file"

  if ((invalid_reference)); then
    rm -f -- "$release_list_file"
    printf '%s\n' 'INVALID_REFERENCE' >&2
    return 1
  fi
  rm -f -- "$release_list_file"
}

release_notes() {
  local notes_file=''
  local tag=''
  local option

  while (($# > 0)); do
    option="$1"
    case "$option" in
      --notes)
        [[ $# -ge 2 ]] || { usage; return 2; }
        notes_file="$2"
        shift 2
        ;;
      --tag)
        [[ $# -ge 2 ]] || { usage; return 2; }
        tag="$2"
        shift 2
        ;;
      *)
        usage
        return 2
        ;;
    esac
  done

  [[ -n "$notes_file" && -n "$tag" ]] || { usage; return 2; }
  extract_public_release_notes "$notes_file" "$tag"
}

run_mode() {
  local mode=''
  local repo=''
  local destination=''
  local ref='HEAD'
  local confirmation=''
  local option

  while (($# > 0)); do
    option="$1"
    case "$option" in
      --mode)
        [[ $# -ge 2 ]] || { usage; return 2; }
        mode="$2"
        shift 2
        ;;
      --repo)
        [[ $# -ge 2 ]] || { usage; return 2; }
        repo="$2"
        shift 2
        ;;
      --destination)
        [[ $# -ge 2 ]] || { usage; return 2; }
        destination="$2"
        shift 2
        ;;
      --ref)
        [[ $# -ge 2 ]] || { usage; return 2; }
        ref="$2"
        shift 2
        ;;
      --confirmation)
        [[ $# -ge 2 ]] || { usage; return 2; }
        confirmation="$2"
        shift 2
        ;;
      *)
        usage
        return 2
        ;;
    esac
  done

  [[ "$mode" == 'main' || "$mode" == 'tag' || "$mode" == 'initial-cleanup' ]] || { usage; return 2; }
  [[ -n "$repo" && -d "$repo/.git" ]] || { usage; return 2; }
  [[ -n "$destination" && -d "$destination/.git" ]] || { usage; return 2; }

  if [[ "$mode" == 'initial-cleanup' && "$confirmation" != 'INITIAL_CLEANUP' ]]; then
    printf '%s\n' 'INITIAL_CLEANUP_NOT_CONFIRMED' >&2
    return 1
  fi

  local source_sha=''
  if ! prime_publication_audit "$repo" "$ref" "$destination" "$mode" '' 'PARTIAL' 'PUBLICATION_FAILED'; then
    printf '%s\n' 'AUDIT_WRITE_FAILED' >&2
    return 1
  fi
  if ! source_sha=$(git -C "$repo" rev-parse --verify "$ref^{commit}" 2>/dev/null); then
    if ! write_audit "$repo" "$ref" "$destination" "$mode" '' 'BLOCKED' 'INVALID_SOURCE_REF'; then
      printf '%s\n' 'AUDIT_WRITE_FAILED' >&2
      return 1
    fi
    printf '%s\n' 'INVALID_SOURCE_REF' >&2
    return 1
  fi

  # Publication side effects must remain below this validation barrier.
  # Unknown paths return before any commit-tree, push, or gh operation.
  if ! classify_paths "$repo" "$ref"; then
    if [[ -n "$CLASSIFICATION_ERROR" ]]; then
      if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' "$CLASSIFICATION_ERROR"; then
        printf '%s\n' 'AUDIT_WRITE_FAILED' >&2
        return 1
      fi
      printf '%s\n' "$CLASSIFICATION_ERROR" >&2
      return 1
    fi
    emit_classification
    if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'UNKNOWN_PATH'; then
      printf '%s\n' 'AUDIT_WRITE_FAILED' >&2
      return 1
    fi
    printf '%s\n' 'UNKNOWN_PATH' >&2
    return 1
  fi
  if ! validate_manifest_references "$repo" "$ref"; then
    write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INVALID_REFERENCE'
    printf '%s\n' 'INVALID_REFERENCE' >&2
    return 1
  fi
  if ! validate_codex_marketplace "$repo" "$ref"; then
    write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INVALID_MANIFEST'
    printf '%s\n' 'INVALID_MANIFEST' >&2
    return 1
  fi
  local public_tag=''
  if [[ "$mode" == 'tag' ]]; then
    public_tag="${ref#refs/tags/}"
    if [[ ! "$public_tag" =~ $PUBLIC_TAG_PATTERN ]]; then
      write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INVALID_REFERENCE'
      printf '%s\n' 'INVALID_REFERENCE' >&2
      return 1
    fi
  fi
  if ! validate_destination_identity "$repo" "$destination"; then
    write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INITIAL_CLEANUP_NOT_CONFIRMED'
    return 1
  fi
  if ! acquire_publication_lock "$destination"; then
    write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'CONCURRENCY_CONFLICT'
    return 1
  fi
  if [[ "$mode" == 'initial-cleanup' ]]; then
    if ! build_public_snapshot "$repo" "$ref" "$destination" "$source_sha" '1' || \
      ! replace_public_main_with_root "$destination" || \
      ! cleanup_public_branches "$destination" || \
      ! cleanup_public_tags "$destination"; then
      publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
      return 1
    fi
    if ! cleanup_public_releases; then
      write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INVALID_REFERENCE'
      return 1
    fi
    if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'SUCCESS' ''; then
      publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
      return 1
    fi
    return 0
  fi
  local guard_main='0'
  if [[ "$mode" == 'main' ]]; then
    guard_main='1'
  fi
  if ! build_public_snapshot "$repo" "$ref" "$destination" "$source_sha" '0' "$guard_main"; then
    if [[ "$PUBLIC_SNAPSHOT_ERROR" == 'DESTINATION_DIVERGENCE' ]]; then
      write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'DESTINATION_DIVERGENCE'
      printf '%s\n' 'DESTINATION_DIVERGENCE' >&2
      return 1
    fi
    publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
    return 1
  fi
  if [[ "$mode" == 'main' ]]; then
    if [[ "$PUBLIC_SNAPSHOT_NOOP" == '1' ]]; then
      if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'NOOP' ''; then
        publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
        return 1
      fi
      printf '%s\n' 'NOOP'
      return 0
    fi

    local destination_main=''
    if destination_main=$(git -C "$destination" rev-parse --verify refs/heads/main^{commit} 2>/dev/null); then
      if ! git -C "$destination" update-ref refs/heads/main "$PUBLIC_SNAPSHOT_COMMIT" "$destination_main"; then
        publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
        return 1
      fi
    else
      if ! git -C "$destination" update-ref refs/heads/main "$PUBLIC_SNAPSHOT_COMMIT"; then
        publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
        return 1
      fi
    fi
    if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'SUCCESS' ''; then
      publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
      return 1
    fi
  elif [[ "$mode" == 'tag' ]]; then
    if ! sync_public_tag "$destination" "$public_tag"; then
      if [[ "$PUBLIC_TAG_OUTCOME" == 'FAILED' ]]; then
        publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
        return 1
      fi
      write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'DESTINATION_DIVERGENCE'
      printf '%s\n' 'DESTINATION_DIVERGENCE' >&2
      return 1
    fi
    local release_body_file
    local release_notes_status=0
    release_body_file=$(mktemp)
    prepare_public_release_body "$repo" "$ref" "$public_tag" "$release_body_file" || release_notes_status=$?
    if [[ "$release_notes_status" != '0' ]]; then
      rm -f -- "$release_body_file"
      if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'INVALID_RELEASE_NOTES'; then
        publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
        return 1
      fi
      printf '%s\n' 'INVALID_RELEASE_NOTES' >&2
      return 1
    fi
    if [[ "$release_notes_status" == '0' ]]; then
      if ! sync_public_release "$public_tag" "$release_body_file"; then
        rm -f -- "$release_body_file"
        if [[ "$PUBLIC_RELEASE_OUTCOME" == 'FAILED' ]]; then
          publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
          return 1
        fi
        write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'BLOCKED' 'DESTINATION_DIVERGENCE'
        printf '%s\n' 'DESTINATION_DIVERGENCE' >&2
        return 1
      fi
    fi
    rm -f -- "$release_body_file"
    local tag_audit_outcome="$PUBLIC_TAG_OUTCOME"
    if [[ "$PUBLIC_TAG_OUTCOME" == 'SUCCESS' || "$PUBLIC_RELEASE_OUTCOME" == 'SUCCESS' ]]; then
      tag_audit_outcome='SUCCESS'
    elif [[ "$PUBLIC_TAG_OUTCOME" == 'NOOP' && "$PUBLIC_RELEASE_OUTCOME" == 'NOOP' ]]; then
      tag_audit_outcome='NOOP'
    fi
    if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" "$tag_audit_outcome" ''; then
      publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
      return 1
    fi
    if [[ "$PUBLIC_SNAPSHOT_NOOP" == '1' && "$PUBLIC_RELEASE_OUTCOME" != 'SUCCESS' ]]; then
      printf '%s\n' 'NOOP'
    fi
    return 0
  fi
  if ! write_audit "$repo" "$ref" "$destination" "$mode" "$source_sha" 'SUCCESS' ''; then
    publication_failed "$repo" "$ref" "$destination" "$mode" "$source_sha"
    return 1
  fi
}

case "${1:-}" in
  classify)
    shift
    classify "$@"
    ;;
  release-notes)
    shift
    release_notes "$@"
    ;;
  --mode)
    run_mode "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
