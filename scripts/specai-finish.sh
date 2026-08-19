#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/specai-finish.sh preflight YYYYMMDD-slug [repo-root]
  bash scripts/specai-finish.sh preview YYYYMMDD-slug [repo-root]
  bash scripts/specai-finish.sh archive YYYYMMDD-slug [--confirm-archive] [repo-root]
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SPECIAI_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DRIFT_SCRIPT="$SCRIPT_DIR/specai-drift.sh"
BACKLOG_SCRIPT="$SCRIPT_DIR/backlog.sh"
COMMAND="${1:-}"
FEATURE_ID="${2:-}"
CONFIRM_ARCHIVE=false

if [[ -z "$COMMAND" || -z "$FEATURE_ID" ]]; then
  usage
  exit 2
fi
shift 2

while (( $# > 0 )); do
  case "$1" in
    --confirm-archive) CONFIRM_ARCHIVE=true ;;
    *)
      if [[ -n "${SPECIAI_ROOT:-}" ]]; then
        echo "❌ Unknown option: $1" >&2
        usage
        exit 2
      fi
      REPO_ROOT="$1"
      ;;
  esac
  shift
done

ACTIVE_DIR="$REPO_ROOT/docs/specai/$FEATURE_ID"
ARCHIVE_DIR="$REPO_ROOT/docs/specai/feature/$FEATURE_ID"
PROJECT_SPECS_DIR="$REPO_ROOT/docs/specai/project"
BACKLOG_FILE="$REPO_ROOT/.specai/backlog.json"
STAGING_ROOT=""
DRIFT_PROJECTION_ROOT=""
TRANSACTION_BACKUP_DIR=""
TRANSACTION_ACTIVE=false
TRANSACTION_DIAGNOSTIC=""

transaction_step() {
  local label="$1"
  shift
  local output
  local status
  if output="$("$@" 2>&1)"; then
    return 0
  else
    status=$?
  fi
  TRANSACTION_DIAGNOSTIC="${output:-$label failed}"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  fi
  return "$status"
}

run_drift_gate() {
  local root="${1:-$REPO_ROOT}"
  local output
  local status
  if [[ -n "${DRIFT_PROJECTION_ROOT:-}" && "$root" == "$DRIFT_PROJECTION_ROOT" ]]; then
    if output="$(SPECAI_ARCHIVE_STAGING=1 SPECIAI_ROOT="$root" \
      bash "$DRIFT_SCRIPT" check "$FEATURE_ID" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    else
      status=$?
    fi
  elif output="$(SPECIAI_ROOT="$root" bash "$DRIFT_SCRIPT" check "$FEATURE_ID" 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  else
    status=$?
  fi
  TRANSACTION_DIAGNOSTIC="$output"
  printf '%s\n' "$output" >&2
  return "$status"
}

snapshot_transaction_state() {
  local snapshot_root="$1"
  if ! mkdir -p "$snapshot_root"; then
    return 1
  fi
  if ! cp -a "$REPO_ROOT/docs/specai" "$snapshot_root/docs-specai"; then
    return 1
  fi
  if [[ -d "$REPO_ROOT/docs/adr" ]]; then
    if ! cp -a "$REPO_ROOT/docs/adr" "$snapshot_root/docs-adr"; then
      return 1
    fi
  else
    : > "$snapshot_root/docs-adr.absent"
  fi
  if [[ -d "$REPO_ROOT/.specai" ]]; then
    if ! cp -a "$REPO_ROOT/.specai" "$snapshot_root/dot-specai"; then
      return 1
    fi
  else
    : > "$snapshot_root/dot-specai.absent"
  fi
  write_transaction_manifest "$REPO_ROOT" "$snapshot_root/repository.manifest" \
    docs/specai docs/adr .specai \
    --transaction-root STAGING_ROOT "$STAGING_ROOT" \
    --transaction-root DRIFT_PROJECTION_ROOT "$DRIFT_PROJECTION_ROOT" \
    --transaction-root TRANSACTION_BACKUP_DIR "$TRANSACTION_BACKUP_DIR"
}

write_transaction_manifest() {
  local root="$1"
  local manifest="$2"
  shift 2
  python3 - "$root" "$manifest" "$@" <<'PY'
import hashlib
import os
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
manifest = Path(sys.argv[2])
manifest_resolved = manifest.resolve()
scopes = [Path(value) for value in sys.argv[3:]]


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def collect(path: Path, relative: Path, output: list[str]) -> None:
    if path.resolve(strict=False) == manifest_resolved:
        return
    if relative.as_posix() == "@transaction/TRANSACTION_BACKUP_DIR/repository.manifest":
        return
    key = relative.as_posix()
    if path.is_symlink():
        output.append(f"L\t{key}\t{os.readlink(path)}")
        return
    if not path.exists():
        output.append(f"M\t{key}")
        return
    info = path.lstat()
    if stat.S_ISDIR(info.st_mode):
        output.append(f"D\t{key}")
        for child in sorted(path.iterdir(), key=lambda item: item.name):
            collect(child, relative / child.name, output)
    elif stat.S_ISREG(info.st_mode):
        output.append(f"F\t{key}\t{digest(path)}")
    else:
        output.append(f"S\t{key}\t{info.st_mode}")


lines: list[str] = []
arguments = list(sys.argv[3:])
scopes: list[Path] = []
transaction_roots: list[tuple[str, Path | None]] = []
roots_only = False
index = 0
while index < len(arguments):
    argument = arguments[index]
    if argument == "--transaction-root":
        if index + 2 >= len(arguments):
            raise SystemExit("transaction root requires a label and path")
        raw_root = arguments[index + 2]
        transaction_roots.append(
            (arguments[index + 1], Path(raw_root) if raw_root else None)
        )
        index += 3
    elif argument == "--transaction-roots-only":
        roots_only = True
        index += 1
    else:
        scopes.append(Path(argument))
        index += 1

if scopes:
    for scope in scopes:
        collect(root / scope, scope, lines)
elif not roots_only:
    for child in sorted(root.iterdir(), key=lambda item: item.name):
        if child.name == ".git":
            continue
        collect(child, Path(child.name), lines)
for label, transaction_root in transaction_roots:
    relative = Path("@transaction") / label
    if transaction_root is None:
        lines.append(f"M\t{relative.as_posix()}")
    else:
        collect(transaction_root, relative, lines)
manifest.write_text("\n".join(sorted(lines)) + "\n", encoding="utf-8")
PY
}

compare_transaction_manifests() {
  local expected_manifest="$1"
  local actual_manifest="$2"
  python3 - "$expected_manifest" "$actual_manifest" <<'PY'
import sys
from pathlib import Path

expected = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
actual = Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
expected_by_path = {line.split("\t", 2)[1]: line for line in expected}
actual_by_path = {line.split("\t", 2)[1]: line for line in actual}
paths = sorted(set(expected_by_path) | set(actual_by_path))
mismatches = [path for path in paths if expected_by_path.get(path) != actual_by_path.get(path)]
for path in mismatches:
    print(f"FINISH_BLOCKED: staging/final identity mismatch: {path}", file=sys.stderr)
raise SystemExit(1 if mismatches else 0)
PY
}

compare_transaction_state() {
  local expected_root="$1"
  local actual_root="$2"
  local expected_manifest
  local actual_manifest
  local status
  expected_manifest="$(mktemp)"
  actual_manifest="$(mktemp)"
  write_transaction_manifest "$expected_root" "$expected_manifest" \
    docs/specai docs/adr .specai
  write_transaction_manifest "$actual_root" "$actual_manifest" \
    docs/specai docs/adr .specai
  if compare_transaction_manifests "$expected_manifest" "$actual_manifest"; then
    status=0
  else
    status=$?
  fi
  rm -f -- "$expected_manifest" "$actual_manifest"
  return "$status"
}

cleanup_transaction() {
  local cleanup_status=0
  if [[ -n "${STAGING_ROOT:-}" && -e "$STAGING_ROOT" ]]; then
    if ! STAGING_ROOT="$STAGING_ROOT" DRIFT_PROJECTION_ROOT="${DRIFT_PROJECTION_ROOT:-}" \
      TRANSACTION_BACKUP_DIR="${TRANSACTION_BACKUP_DIR:-}" rm -rf "$STAGING_ROOT"; then
      printf 'FINISH_CLEANUP_FAILED: cannot remove staging root %s\n' "$STAGING_ROOT" >&2
      cleanup_status=1
    elif [[ -e "$STAGING_ROOT" || -L "$STAGING_ROOT" ]]; then
      printf 'FINISH_CLEANUP_FAILED: staging root remains %s\n' "$STAGING_ROOT" >&2
      cleanup_status=1
    fi
  fi
  if [[ -n "${DRIFT_PROJECTION_ROOT:-}" && -e "$DRIFT_PROJECTION_ROOT" ]]; then
    if ! STAGING_ROOT="${STAGING_ROOT:-}" DRIFT_PROJECTION_ROOT="$DRIFT_PROJECTION_ROOT" \
      TRANSACTION_BACKUP_DIR="${TRANSACTION_BACKUP_DIR:-}" rm -rf "$DRIFT_PROJECTION_ROOT"; then
      printf 'FINISH_CLEANUP_FAILED: cannot remove drift projection %s\n' \
        "$DRIFT_PROJECTION_ROOT" >&2
      cleanup_status=1
    elif [[ -e "$DRIFT_PROJECTION_ROOT" || -L "$DRIFT_PROJECTION_ROOT" ]]; then
      printf 'FINISH_CLEANUP_FAILED: drift projection remains %s\n' \
        "$DRIFT_PROJECTION_ROOT" >&2
      cleanup_status=1
    fi
  fi
  if [[ -n "${TRANSACTION_BACKUP_DIR:-}" && -e "$TRANSACTION_BACKUP_DIR" ]]; then
    if ! STAGING_ROOT="${STAGING_ROOT:-}" DRIFT_PROJECTION_ROOT="${DRIFT_PROJECTION_ROOT:-}" \
      TRANSACTION_BACKUP_DIR="$TRANSACTION_BACKUP_DIR" rm -rf "$TRANSACTION_BACKUP_DIR"; then
      printf 'FINISH_CLEANUP_FAILED: cannot remove transaction backup %s\n' \
        "$TRANSACTION_BACKUP_DIR" >&2
      cleanup_status=1
    elif [[ -e "$TRANSACTION_BACKUP_DIR" || -L "$TRANSACTION_BACKUP_DIR" ]]; then
      printf 'FINISH_CLEANUP_FAILED: transaction backup remains %s\n' \
        "$TRANSACTION_BACKUP_DIR" >&2
      cleanup_status=1
    fi
  fi
  local roots_manifest roots_expected
  roots_manifest="$(mktemp)"
  roots_expected="$(mktemp)"
  write_transaction_manifest "$REPO_ROOT" "$roots_manifest" \
    --transaction-roots-only \
    --transaction-root STAGING_ROOT "${STAGING_ROOT:-}" \
    --transaction-root DRIFT_PROJECTION_ROOT "${DRIFT_PROJECTION_ROOT:-}" \
    --transaction-root TRANSACTION_BACKUP_DIR "${TRANSACTION_BACKUP_DIR:-}"
  printf '%b\n' \
    "M\t@transaction/DRIFT_PROJECTION_ROOT" \
    "M\t@transaction/STAGING_ROOT" \
    "M\t@transaction/TRANSACTION_BACKUP_DIR" >"$roots_expected"
  if ! compare_transaction_manifests "$roots_expected" "$roots_manifest"; then
    cleanup_status=1
  fi
  rm -f -- "$roots_manifest" "$roots_expected"
  return "$cleanup_status"
}

transaction_exit() {
  local status=$?
  local rollback_status=0
  local cleanup_status=0
  local rollback_output=""

  trap - EXIT
  if [[ "$TRANSACTION_ACTIVE" == true && "$status" -ne 0 ]]; then
    set +e
    rollback_output="$(rollback_transaction 2>&1)"
    rollback_status=$?
    set -e
    if [[ -n "$rollback_output" ]]; then
      printf '%s\n' "$rollback_output" >&2
    fi
    if [[ "$rollback_status" -ne 0 ]]; then
      printf 'FINISH_ROLLBACK_FAILED: original diagnostic follows\n' >&2
      printf '%s\n' "${TRANSACTION_DIAGNOSTIC:-archive transaction failed}" >&2
    fi
  fi

  set +e
  cleanup_transaction
  cleanup_status=$?
  set -e
  if [[ "$status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    status=1
  fi
  exit "$status"
}

readiness() {
  python3 - "$REPO_ROOT" "$FEATURE_ID" "$ACTIVE_DIR" "$ARCHIVE_DIR" "$BACKLOG_FILE" "$PROJECT_SPECS_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

repo_root, feature_id, active_raw, archive_raw, backlog_raw, project_specs_raw = sys.argv[1:]
active = Path(active_raw)
archive = Path(archive_raw)
backlog_path = Path(backlog_raw)
project_specs = Path(project_specs_raw)

if archive.is_dir() and not active.exists():
    print("already_archived")
    raise SystemExit(0)
if active.is_symlink() or archive.is_symlink():
    print("FINISH_BLOCKED: active/archive destinations must not be symlinks", file=sys.stderr)
    raise SystemExit(1)
if not active.is_dir() or archive.exists():
    print("FINISH_BLOCKED: collision or invalid active/archive destinations", file=sys.stderr)
    raise SystemExit(1)
if not project_specs.is_dir() or project_specs.is_symlink():
    print("FINISH_BLOCKED: project specs directory is unavailable", file=sys.stderr)
    raise SystemExit(1)
try:
    project_specs.resolve().relative_to(Path(repo_root).resolve())
except ValueError:
    print("FINISH_BLOCKED: project specs directory resolves outside repo", file=sys.stderr)
    raise SystemExit(1)

try:
    entries = json.loads(backlog_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"FINISH_BLOCKED: cannot read backlog: {exc}", file=sys.stderr)
    raise SystemExit(1)

matches = [
    entry for entry in entries
    if isinstance(entry, dict) and entry.get("feature_id") == feature_id
]
if len(matches) != 1:
    print(f"FINISH_BLOCKED: expected exactly one backlog entry for {feature_id}", file=sys.stderr)
    raise SystemExit(1)
entry = matches[0]
if entry.get("status") != "ready_to_finish":
    print(
        f"FINISH_BLOCKED: backlog status must be ready_to_finish, got {entry.get('status')}",
        file=sys.stderr,
    )
    raise SystemExit(1)

paths = {
    "prd": active / f"{feature_id}-prd.md",
    "spec": active / f"{feature_id}-spec.md",
    "designs": active / f"{feature_id}-designs.md",
    "plan": active / f"{feature_id}-plan.md",
    "tasks": active / f"{feature_id}-tasks.md",
    "verify": active / f"{feature_id}-verify.md",
}
texts = {}
for name, path in paths.items():
    if path.is_symlink():
        print(f"FINISH_BLOCKED: {name} artifact must not be a symlink", file=sys.stderr)
        raise SystemExit(1)
    try:
        texts[name] = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"FINISH_BLOCKED: cannot read {name}: {exc}", file=sys.stderr)
        raise SystemExit(1)

checks = (
    ("spec", r"(?im)^\s*(?:\*\*)?Delta status\s*:\s*(?:\*\*)?\s*applied\s*(?:\*\*)?\s*$", "project spec delta is not applied"),
    ("plan", r"(?im)^\s*(?:\*\*)?Gate UA\s*[:：]\s*(?:\*\*)?\s*(?:accepted|acepto|aceptado|ok)\s*(?:\*\*)?\s*$", "Gate UA is not accepted"),
    ("plan", r"(?im)^\s*(?:\*\*)?Code review\s*[:：]\s*(?:\*\*)?\s*PASS\s*(?:\*\*)?\s*$", "code review has not passed"),
    ("plan", r"(?im)^\s*(?:\*\*)?Spec compliance review\s*[:：]\s*(?:\*\*)?\s*PASS\s*(?:\*\*)?\s*$", "spec compliance review has not passed"),
    ("tasks", r"(?im)^\s*(?:\*\*)?Status\s*:\s*(?:\*\*)?\s*(?:completed|done)\s*(?:\*\*)?\s*$", "tasks are not completed"),
    ("verify", r"(?im)^\s*(?:\*\*)?(?:Verifier|Resultado|Verdict)\s*[:：]\s*(?:\*\*)?\s*PASS\s*(?:\*\*)?\s*$", "verifier has not passed"),
)
for name, pattern, message in checks:
    if not re.search(pattern, texts[name]):
        print(f"FINISH_BLOCKED: {message}", file=sys.stderr)
        raise SystemExit(1)

delta_pattern = re.compile(r"(?im)^\s*(?:\*\*)?Delta status\s*:\s*(?:\*\*)?\s*applied\s*(?:\*\*)?\s*$")
project_updates = []
for project_spec in sorted(project_specs.glob("*.md")):
    if project_spec.is_symlink():
        continue
    try:
        project_text = project_spec.read_text(encoding="utf-8")
    except OSError:
        continue
    if feature_id in project_text and delta_pattern.search(project_text):
        project_updates.append(project_spec)
if not project_updates:
    print("FINISH_BLOCKED: project spec delta is not applied", file=sys.stderr)
    raise SystemExit(1)

print("ready")
PY
}

validate_provenance_scopes() {
  python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
for relative in (Path("docs/specai/project"), Path("docs/adr")):
    scope = root / relative
    if not (scope.exists() or scope.is_symlink()):
        continue
    if scope.is_symlink():
        try:
            scope.resolve().relative_to(root)
        except ValueError:
            print(f"SPEC_DRIFT: provenance scope resolves outside repo: {relative}", file=sys.stderr)
            raise SystemExit(1)
        print(f"SPEC_DRIFT: provenance scope must not be a symlink: {relative}", file=sys.stderr)
        raise SystemExit(1)
    if not scope.is_dir():
        print(f"SPEC_DRIFT: provenance scope is not a directory: {relative}", file=sys.stderr)
        raise SystemExit(1)
    try:
        scope.resolve().relative_to(root)
    except ValueError:
        print(f"SPEC_DRIFT: provenance scope resolves outside repo: {relative}", file=sys.stderr)
        raise SystemExit(1)
PY
}

update_provenance_at() {
  local root="$1"
  local backup_root="${2:-}"
  python3 - "$root" "$FEATURE_ID" "$backup_root" <<'PY'
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
feature_id = sys.argv[2]
backup_root_raw = sys.argv[3]
backup_root = Path(backup_root_raw) if backup_root_raw else None
active = f"{feature_id}"
archived = f"feature/{feature_id}"

scopes = [repo_root / "docs" / "specai" / "project", repo_root / "docs" / "adr"]
for scope in scopes:
    if not scope.is_dir():
        continue
    if scope.is_symlink():
        raise SystemExit(f"provenance scope must not be a symlink: {scope}")
    try:
        scope.resolve().relative_to(repo_root)
    except ValueError:
        raise SystemExit(f"provenance scope resolves outside repo: {scope}")
    for path in sorted(scope.glob("*.md")):
        if path.is_symlink():
            raise SystemExit(f"provenance update blocked by symlink: {path}")
        text = path.read_text(encoding="utf-8")
        updated = text.replace(f"docs/specai/{active}", f"docs/specai/{archived}")
        updated = re.sub(
            rf"\.\./specai/{re.escape(active)}(?=[/#)\\s])",
            f"../specai/{archived}",
            updated,
        )
        updated = re.sub(
            rf"\.\./{re.escape(active)}(?=[/#)\\s])",
            f"../{archived}",
            updated,
        )
        if updated == text:
            continue
        if backup_root is not None:
            relative = path.relative_to(repo_root)
            backup_path = backup_root / relative
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup_path)
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", delete=False,
        ) as temp:
            temp.write(updated)
            temp_path = Path(temp.name)
        os.replace(temp_path, path)
PY
}

restore_provenance() {
  local backup_root="${1:-}"
  if [[ -z "$backup_root" || ! -d "$backup_root" ]]; then
    printf 'provenance backup is missing\n' >&2
    return 1
  fi
  python3 - "$REPO_ROOT" "$backup_root" <<'PY'
import shutil
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
backup_root = Path(sys.argv[2])
for backup in backup_root.rglob("*.md"):
    relative = backup.relative_to(backup_root)
    destination = repo_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copy2(backup, destination)
    except OSError as exc:
        raise SystemExit(f"cannot restore provenance {relative}: {exc}")
PY
}

validate_archive_parent() {
  local archive_parent="$REPO_ROOT/docs/specai/feature"
  if [[ -L "$archive_parent" ]]; then
    local repo_real parent_real
    repo_real="$(realpath "$REPO_ROOT")"
    parent_real="$(realpath "$archive_parent")"
    case "$parent_real" in
      "$repo_real"/*) ;;
      *)
        echo "SPEC_DRIFT: archive parent resolves outside repo" >&2
        return 1
        ;;
    esac
  elif [[ -e "$archive_parent" && ! -d "$archive_parent" ]]; then
    echo "SPEC_DRIFT: archive parent is not a directory" >&2
    return 1
  fi
  python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
candidate = root / "docs" / "specai" / "feature"
current = root
for component in ("docs", "specai", "feature"):
    current = current / component
    if not (current.exists() or current.is_symlink()):
        continue
    if component == "feature" and not current.is_dir():
        print("SPEC_DRIFT: archive parent is not a directory", file=sys.stderr)
        raise SystemExit(1)
    resolved = current.resolve(strict=False)
    try:
        resolved.relative_to(root)
    except ValueError:
        print("SPEC_DRIFT: archive parent resolves outside repo", file=sys.stderr)
        raise SystemExit(1)
print("archive_parent_ready")
PY
}

rewrite_archived_feature_links() {
  local archive_dir="$1"
  local direction="${2:-forward}"
  if [[ "$direction" != forward && "$direction" != reverse ]]; then
    echo "FINISH_BLOCKED: invalid archive link rewrite direction: $direction" >&2
    return 1
  fi
  python3 - "$archive_dir" "$direction" <<'PY'
import os
import sys
import tempfile
from pathlib import Path

archive_dir = Path(sys.argv[1])
direction = sys.argv[2]
for path in sorted(archive_dir.rglob("*.md")):
    if path.is_symlink():
        raise SystemExit(f"SPEC_DRIFT: archived artifact must not be a symlink: {path}")
    text = path.read_text(encoding="utf-8")
    if direction == "forward":
        updated = text.replace("](../project/", "](../../project/")
        updated = updated.replace("](../../adr/", "](../../../adr/")
    else:
        updated = text.replace("](../../project/", "](../project/")
        updated = updated.replace("](../../../adr/", "](../../adr/")
    if updated == text:
        continue
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent,
        prefix=f".{path.name}.", delete=False,
    ) as temp:
        temp.write(updated)
        temp_path = Path(temp.name)
    os.replace(temp_path, path)
PY
}

update_backlog_at() {
  local root="$1"
  python3 - "$root/.specai/backlog.json" "$FEATURE_ID" <<'PY'
import json
import os
import sys
import tempfile
from pathlib import Path

backlog_path = Path(sys.argv[1])
feature_id = sys.argv[2]
entries = json.loads(backlog_path.read_text(encoding="utf-8"))
matches = [
    entry for entry in entries
    if isinstance(entry, dict) and entry.get("feature_id") == feature_id
]
if len(matches) != 1 or matches[0].get("status") != "ready_to_finish":
    raise SystemExit("backlog transition requires exactly one ready_to_finish entry")
entry = matches[0]
archive_dir = f"docs/specai/feature/{feature_id}"
entry["status"] = "done"
entry["feature_dir"] = archive_dir
entry["plan_dir"] = f"{archive_dir}/{feature_id}-plan.md"
entry["branch"] = entry.get("branch", "")
payload = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
with tempfile.NamedTemporaryFile(
    "w", encoding="utf-8", dir=backlog_path.parent,
    prefix=f".{backlog_path.name}.", delete=False,
) as temp:
    temp.write(payload)
    temp_path = temp.name
os.replace(temp_path, backlog_path)
PY
}

run_backlog_reconcile() {
  local root="$1"
  local output
  local status
  if output="$(SPECIAI_ROOT="$root" bash "$BACKLOG_SCRIPT" reconcile 2>&1)"; then
    return 0
  else
    status=$?
    TRANSACTION_DIAGNOSTIC="$output"
    printf '%s\n' "$output" >&2
    if grep -Fq 'unindexed feature director' <<<"$output"; then
      printf 'unindexed feature directories: archive staging is invalid\n' >&2
    fi
    return "$status"
  fi
}

stage_archive() {
  local status
  if ! STAGING_ROOT="$(mktemp -d "$REPO_ROOT/.specai-archive-${FEATURE_ID}.XXXXXX")"; then
    return 1
  fi
  if ! transaction_step stage-mkdir mkdir -p \
    "$STAGING_ROOT/docs/specai" "$STAGING_ROOT/.specai"; then
    return 1
  fi
  if ! transaction_step stage-specai-copy cp -a \
    "$REPO_ROOT/docs/specai/." "$STAGING_ROOT/docs/specai/"; then
    return 1
  fi
  if [[ -d "$REPO_ROOT/docs/adr" ]]; then
    if ! transaction_step stage-adr-copy cp -a \
      "$REPO_ROOT/docs/adr/." "$STAGING_ROOT/docs/adr/"; then
      return 1
    fi
  fi
  if ! transaction_step stage-specai-copy cp -a \
    "$REPO_ROOT/.specai/." "$STAGING_ROOT/.specai/"; then
    return 1
  fi
  if ! transaction_step stage-feature-dir mkdir -p \
    "$STAGING_ROOT/docs/specai/feature"; then
    return 1
  fi
  if transaction_step stage-mv mv \
    "$STAGING_ROOT/docs/specai/$FEATURE_ID" \
    "$STAGING_ROOT/docs/specai/feature/$FEATURE_ID"; then
    :
  else
    return $?
  fi
  if transaction_step stage-rewrite rewrite_archived_feature_links \
    "$STAGING_ROOT/docs/specai/feature/$FEATURE_ID" forward; then
    :
  else
    return $?
  fi
  if transaction_step stage-provenance update_provenance_at "$STAGING_ROOT"; then
    :
  else
    return $?
  fi
  if ! DRIFT_PROJECTION_ROOT="$(mktemp -d "$REPO_ROOT/.specai-drift-${FEATURE_ID}.XXXXXX")"; then
    return 1
  fi
  if ! transaction_step projection-copy cp -a \
    "$STAGING_ROOT/." "$DRIFT_PROJECTION_ROOT/"; then
    return 1
  fi
  if run_drift_gate "$DRIFT_PROJECTION_ROOT"; then
    :
  else
    status=$?
    return "$status"
  fi
  if transaction_step staged-backlog update_backlog_at "$DRIFT_PROJECTION_ROOT"; then
    :
  else
    return $?
  fi
  if run_backlog_reconcile "$DRIFT_PROJECTION_ROOT"; then
    :
  else
    status=$?
    return "$status"
  fi
}

remove_rollback_target() {
  local target="$1"
  local label="$2"
  local quarantine="$TRANSACTION_BACKUP_DIR/.rollback-$label"
  if rm -rf "$target"; then
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]] && \
    mv "$target" "$quarantine" && rm -rf "$quarantine"; then
    printf 'rollback cleanup fallback removed partial %s: %s\n' "$label" "$target"
  else
    printf 'cannot remove partial %s: %s\n' "$label" "$target"
  fi
  return 1
}

rollback_transaction() {
  local rollback_status=0
  if [[ -e "$ARCHIVE_DIR" || -L "$ARCHIVE_DIR" ]]; then
    if ! remove_rollback_target "$ARCHIVE_DIR" archive-destination; then
      rollback_status=1
    fi
  fi
  if [[ -e "$ACTIVE_DIR" || -L "$ACTIVE_DIR" ]]; then
    if ! remove_rollback_target "$ACTIVE_DIR" active-destination; then
      rollback_status=1
    fi
  fi
  if [[ -d "$TRANSACTION_BACKUP_DIR/docs-specai" ]]; then
    if ! remove_rollback_target "$REPO_ROOT/docs/specai" docs-specai-root; then
      rollback_status=1
    fi
    if ! cp -a "$TRANSACTION_BACKUP_DIR/docs-specai" "$REPO_ROOT/docs/specai"; then
      printf 'cannot restore docs/specai snapshot: %s\n' "$REPO_ROOT/docs/specai"
      rollback_status=1
    fi
  else
    printf 'docs/specai snapshot is missing\n'
    rollback_status=1
  fi
  if [[ -d "$TRANSACTION_BACKUP_DIR/docs-adr" ]]; then
    if ! remove_rollback_target "$REPO_ROOT/docs/adr" docs-adr-root; then
      rollback_status=1
    fi
    if ! cp -a "$TRANSACTION_BACKUP_DIR/docs-adr" "$REPO_ROOT/docs/adr"; then
      printf 'cannot restore docs/adr snapshot: %s\n' "$REPO_ROOT/docs/adr"
      rollback_status=1
    fi
  elif [[ -e "$TRANSACTION_BACKUP_DIR/docs-adr.absent" ]]; then
    if [[ -e "$REPO_ROOT/docs/adr" || -L "$REPO_ROOT/docs/adr" ]] && \
      ! remove_rollback_target "$REPO_ROOT/docs/adr" docs-adr-root; then
      rollback_status=1
    fi
  else
    printf 'docs/adr snapshot is missing\n'
    rollback_status=1
  fi
  if [[ -d "$TRANSACTION_BACKUP_DIR/dot-specai" ]]; then
    if [[ -e "$REPO_ROOT/.specai" || -L "$REPO_ROOT/.specai" ]] && \
      ! remove_rollback_target "$REPO_ROOT/.specai" dot-specai-root; then
      rollback_status=1
    fi
    if ! cp -a "$TRANSACTION_BACKUP_DIR/dot-specai" "$REPO_ROOT/.specai"; then
      printf 'cannot restore .specai snapshot: %s\n' "$REPO_ROOT/.specai"
      rollback_status=1
    fi
  elif [[ -e "$TRANSACTION_BACKUP_DIR/dot-specai.absent" ]]; then
    if [[ -e "$REPO_ROOT/.specai" || -L "$REPO_ROOT/.specai" ]] && \
      ! remove_rollback_target "$REPO_ROOT/.specai" dot-specai-root; then
      rollback_status=1
    fi
  else
    printf '.specai snapshot is missing\n'
    rollback_status=1
  fi
  if [[ -f "$TRANSACTION_BACKUP_DIR/repository.manifest" ]]; then
    local current_manifest
    current_manifest="$(mktemp)"
    if ! write_transaction_manifest "$REPO_ROOT" "$current_manifest" \
      docs/specai docs/adr .specai \
      --transaction-root STAGING_ROOT "$STAGING_ROOT" \
      --transaction-root DRIFT_PROJECTION_ROOT "$DRIFT_PROJECTION_ROOT" \
      --transaction-root TRANSACTION_BACKUP_DIR "$TRANSACTION_BACKUP_DIR"; then
      printf 'cannot create rollback manifest\n'
      rollback_status=1
    elif ! compare_transaction_manifests \
      "$TRANSACTION_BACKUP_DIR/repository.manifest" "$current_manifest"; then
      rollback_status=1
    fi
    rm -f -- "$current_manifest"
  else
    printf 'transaction manifest is missing\n'
    rollback_status=1
  fi
  return "$rollback_status"
}

preflight() {
  validate_archive_parent
  validate_provenance_scopes
  if [[ -L "$ACTIVE_DIR" || -L "$ARCHIVE_DIR" ]]; then
    echo "SPEC_DRIFT: active/archive destinations must not be symlinks" >&2
    return 1
  fi
  if [[ -e "$ACTIVE_DIR" && -e "$ARCHIVE_DIR" ]]; then
    echo "SPEC_DRIFT: collision — active and archive destinations both exist" >&2
    return 1
  fi
  run_drift_gate
  local state
  if ! state="$(readiness)"; then
    return 1
  fi
  if [[ "$state" == "already_archived" ]]; then
    echo "FINISH_PREFLIGHT: already archived — $FEATURE_ID"
    return 0
  fi
  echo "FINISH_PREFLIGHT: PASS — $FEATURE_ID"
  echo "source=$ACTIVE_DIR"
  echo "destination=$ARCHIVE_DIR"
  echo "backlog_status=ready_to_finish"
}

preview() {
  preflight
  echo "FINISH_PREVIEW"
  if [[ -d "$ACTIVE_DIR" ]]; then
    echo "move=$ACTIVE_DIR -> $ARCHIVE_DIR"
    echo "backlog_transition=ready_to_finish -> done"
  else
    echo "move=none (already archived)"
  fi
  echo "GIT_PENDING: commit, push and merge each require explicit user permission"
}

archive() {
  if [[ "$CONFIRM_ARCHIVE" != true ]]; then
    echo "FINISH_BLOCKED: explicit archive consent required via --confirm-archive" >&2
    return 1
  fi

  preflight
  if [[ ! -d "$ACTIVE_DIR" ]]; then
    echo "FINISH: already archived — $FEATURE_ID"
    echo "GIT_PENDING: commit, push and merge each require explicit user permission"
    return 0
  fi

  trap transaction_exit EXIT
  if stage_archive; then
    :
  else
    return $?
  fi

  if ! TRANSACTION_BACKUP_DIR="$(mktemp -d)"; then
    TRANSACTION_DIAGNOSTIC='cannot create transaction snapshot directory'
    return 1
  fi
  if transaction_step snapshot snapshot_transaction_state "$TRANSACTION_BACKUP_DIR"; then
    :
  else
    return $?
  fi
  TRANSACTION_ACTIVE=true

  if transaction_step final-feature-dir mkdir -p "$REPO_ROOT/docs/specai/feature"; then
    :
  else
    return $?
  fi
  if transaction_step final-mv mv "$ACTIVE_DIR" "$ARCHIVE_DIR"; then
    :
  else
    return $?
  fi
  if transaction_step final-rewrite rewrite_archived_feature_links "$ARCHIVE_DIR" forward; then
    :
  else
    return $?
  fi
  if transaction_step final-provenance update_provenance_at "$REPO_ROOT"; then
    :
  else
    return $?
  fi
  if transaction_step final-backlog update_backlog_at "$REPO_ROOT"; then
    :
  else
    return $?
  fi
  if run_backlog_reconcile "$REPO_ROOT"; then
    :
  else
    return $?
  fi
  if transaction_step final-identity compare_transaction_state \
    "$DRIFT_PROJECTION_ROOT" "$REPO_ROOT"; then
    :
  else
    return $?
  fi

  TRANSACTION_ACTIVE=false
  trap - EXIT
  if ! cleanup_transaction; then
    return 1
  fi
  echo "FINISH: archived — $FEATURE_ID"
  echo "GIT_PENDING: commit, push and merge each require explicit user permission"
}

case "$COMMAND" in
  preflight) preflight ;;
  preview) preview ;;
  archive) archive ;;
  *) usage; exit 2 ;;
esac
