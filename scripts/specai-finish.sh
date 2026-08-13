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
ARCHIVE_COMPLETED=false
ARCHIVE_BACKUP_FILE=""
PROVENANCE_BACKUP_DIR=""

run_drift_gate() {
  local output
  if ! output="$(SPECIAI_ROOT="$REPO_ROOT" bash "$DRIFT_SCRIPT" check "$FEATURE_ID" 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
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

update_provenance() {
  python3 - "$REPO_ROOT" "$FEATURE_ID" "$PROVENANCE_BACKUP_DIR" <<'PY'
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
feature_id = sys.argv[2]
backup_root = Path(sys.argv[3])
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
  [[ -n "${PROVENANCE_BACKUP_DIR:-}" && -d "$PROVENANCE_BACKUP_DIR" ]] || return 0
  python3 - "$REPO_ROOT" "$PROVENANCE_BACKUP_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
backup_root = Path(sys.argv[2])
for backup in backup_root.rglob("*.md"):
    relative = backup.relative_to(backup_root)
    destination = repo_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(backup, destination)
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

  ARCHIVE_BACKUP_FILE="$(mktemp)"
  cp "$BACKLOG_FILE" "$ARCHIVE_BACKUP_FILE"
  rollback() {
    if [[ "${ARCHIVE_COMPLETED:-false}" != true ]]; then
      if [[ -d "$ARCHIVE_DIR" && ! -e "$ACTIVE_DIR" ]]; then
        mv "$ARCHIVE_DIR" "$ACTIVE_DIR" || true
      fi
      cp "${ARCHIVE_BACKUP_FILE:-}" "$BACKLOG_FILE" || true
      restore_provenance || true
    fi
    rm -f "${ARCHIVE_BACKUP_FILE:-}"
    rm -rf "${PROVENANCE_BACKUP_DIR:-}"
  }
  trap rollback EXIT

  mkdir -p "$REPO_ROOT/docs/specai/feature"
  PROVENANCE_BACKUP_DIR="$(mktemp -d)"
  mv "$ACTIVE_DIR" "$ARCHIVE_DIR"
  update_provenance
  python3 - "$BACKLOG_FILE" "$FEATURE_ID" <<'PY'
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

  SPECIAI_ROOT="$REPO_ROOT" bash "$BACKLOG_SCRIPT" reconcile >/dev/null
  run_drift_gate
  ARCHIVE_COMPLETED=true
  trap - EXIT
  rm -f "$ARCHIVE_BACKUP_FILE"
  ARCHIVE_BACKUP_FILE=""
  rm -rf "$PROVENANCE_BACKUP_DIR"
  PROVENANCE_BACKUP_DIR=""
  echo "FINISH: archived — $FEATURE_ID"
  echo "GIT_PENDING: commit, push and merge each require explicit user permission"
}

case "$COMMAND" in
  preflight) preflight ;;
  preview) preview ;;
  archive) archive ;;
  *) usage; exit 2 ;;
esac
