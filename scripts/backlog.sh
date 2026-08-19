#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
REPO_ROOT="${SPECIAI_ROOT:-$REPO_ROOT}"
BACKLOG_FILE="${SPECIAI_BACKLOG_FILE:-$REPO_ROOT/.specai/backlog.json}"
JQ="$(command -v jq)"

ensure_backlog_file() {
    mkdir -p "$(dirname "$BACKLOG_FILE")"
    if [ ! -f "$BACKLOG_FILE" ]; then
        echo '[]' > "$BACKLOG_FILE"
    fi
}

sync_backlog() {
    local mode="${1:-sync}"
    python3 - "$BACKLOG_FILE" "$REPO_ROOT" "$mode" <<'PY'
import json
import os
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path

backlog_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2]).resolve()
mode = sys.argv[3]
feature_pattern = re.compile(r"^(\d{8})-([a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?)$")
required_suffixes = ("prd", "spec", "designs", "plan", "tasks", "verify")
status_map = {
    "backlog": "backlog",
    "in-progress": "in_progress",
    "in_progress": "in_progress",
    "verifying": "verifying",
    "ready-to-finish": "ready_to_finish",
    "ready_to_finish": "ready_to_finish",
    "done": "done",
}

def fail(message):
    raise SystemExit(f"backlog sync: {message}")


def authorized(path):
    try:
        path.resolve(strict=False).relative_to(repo_root)
    except (OSError, ValueError):
        return False
    return True


def path_exists(path):
    return path.exists() or path.is_symlink()


def validate_feature_artifacts(feature_path, feature_id, legacy):
    if not authorized(feature_path):
        fail(f"feature directory resolves outside repo for {feature_id}")
    if not feature_path.is_dir():
        fail(f"feature directory is not a directory for {feature_id}")
    try:
        children = list(feature_path.iterdir())
    except OSError as exc:
        fail(f"cannot inspect feature directory for {feature_id}: {exc}")

    for path in children:
        if not authorized(path):
            fail(f"artifact resolves outside repo for {feature_id}: {path.name}")

    if legacy:
        if not any(path.is_file() for path in children):
            fail(f"legacy feature directory is empty: {feature_id}")
        return

    expected = {f"{feature_id}-{suffix}.md" for suffix in required_suffixes}
    actual = {path.name for path in children}
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        fail(f"missing artifacts for {feature_id}: {', '.join(missing)}")
    if extra:
        fail(f"partial or invalid artifacts for {feature_id}: {', '.join(extra)}")
    for path in children:
        if not authorized(path):
            fail(f"artifact resolves outside repo for {feature_id}: {path.name}")
        if not path.is_file():
            fail(f"artifact is not a regular file for {feature_id}: {path.name}")

if not authorized(backlog_path):
    fail(f"backlog path resolves outside repo: {backlog_path}")

try:
    entries = json.loads(backlog_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    fail(f"cannot read {backlog_path}: {exc}")
if not isinstance(entries, list):
    fail("backlog root must be a JSON array")

seen = set()
normalized = []
for entry in entries:
    if not isinstance(entry, dict):
        fail("every backlog entry must be an object")
    feature_id = entry.get("feature_id")
    if not feature_id:
        if not entry.get("date") or not entry.get("name") or not entry.get("plan_dir"):
            fail("legacy entry requires date, name and plan_dir before it can be migrated")
        date = str(entry.get("date", ""))
        name = str(entry.get("name", ""))
        feature_id = f"{date.replace('-', '')}-{name}"
    elif not entry.get("feature_dir") or not entry.get("plan_dir"):
        fail(f"entry requires feature_dir and plan_dir: {feature_id}")
    match = feature_pattern.fullmatch(feature_id)
    if not match:
        fail(f"invalid Feature ID: {feature_id}")
    try:
        datetime.strptime(match.group(1), "%Y%m%d")
    except ValueError:
        fail(f"invalid date in Feature ID: {feature_id}")
    if feature_id in seen:
        fail(f"duplicate Feature ID: {feature_id}")
    seen.add(feature_id)

    legacy = entry.get("legacy", False)
    if not isinstance(legacy, bool):
        fail(f"legacy marker must be boolean for {feature_id}")

    active = repo_root / "docs" / "specai" / feature_id
    archive = repo_root / "docs" / "specai" / "feature" / feature_id
    active_exists = path_exists(active)
    archive_exists = path_exists(archive)
    if active_exists and not authorized(active):
        fail(f"active destination resolves outside repo for {feature_id}")
    if archive_exists and not authorized(archive):
        fail(f"archive destination resolves outside repo for {feature_id}")
    if active_exists and archive_exists:
        fail(f"active and archive directories both exist for {feature_id}")
    if active_exists and not active.is_dir():
        fail(f"active destination is not a directory for {feature_id}")
    if archive_exists and not archive.is_dir():
        fail(f"archive destination is not a directory for {feature_id}")
    if active.is_dir():
        feature_dir = Path("docs/specai") / feature_id
        is_archived = False
        feature_path = active
    elif archive.is_dir():
        feature_dir = Path("docs/specai/feature") / feature_id
        is_archived = True
        feature_path = archive
    else:
        fail(f"feature directory not found for {feature_id}")

    validate_feature_artifacts(feature_path, feature_id, legacy)

    status = status_map.get(str(entry.get("status", "backlog")))
    if status is None:
        fail(f"invalid status for {feature_id}: {entry.get('status')}")
    if is_archived and status != "done":
        fail(f"archived feature must be done: {feature_id}")
    if not is_archived and status == "done":
        fail(f"done feature must be archived: {feature_id}")

    expected_feature_dir = feature_dir.as_posix()
    expected_plan_dir = (feature_dir / f"{feature_id}-plan.md").as_posix()
    active_feature_dir = (Path("docs/specai") / feature_id).as_posix()
    active_plan_dir = (Path("docs/specai") / feature_id / f"{feature_id}-plan.md").as_posix()
    declared_feature_id = entry.get("feature_id")
    if declared_feature_id and declared_feature_id != feature_id:
        fail(f"Feature ID conflicts with derived identity: {declared_feature_id} vs {feature_id}")
    declared_date = entry.get("date")
    canonical_date = f"{match.group(1)[:4]}-{match.group(1)[4:6]}-{match.group(1)[6:]}"
    if declared_date and declared_date != canonical_date:
        fail(f"date conflicts with Feature ID {feature_id}: {declared_date}")
    archive_transition = (
        is_archived and status == "done" and
        entry.get("feature_dir") == active_feature_dir and
        entry.get("plan_dir") == active_plan_dir
    )
    if entry.get("feature_dir") and entry["feature_dir"] != expected_feature_dir and not archive_transition:
        fail(f"feature_dir conflicts with Feature ID {feature_id}: {entry['feature_dir']}")
    legacy_directory_plan = (
        not declared_feature_id and
        not entry.get("feature_dir") and
        entry.get("plan_dir") == expected_feature_dir
    )
    if entry.get("plan_dir") and entry["plan_dir"] != expected_plan_dir and not legacy_directory_plan and not archive_transition:
        fail(f"plan_dir conflicts with Feature ID {feature_id}: {entry['plan_dir']}")

    updated = dict(entry)
    updated["feature_id"] = feature_id
    updated["status"] = status
    updated["feature_dir"] = expected_feature_dir
    updated["plan_dir"] = expected_plan_dir
    updated["date"] = canonical_date
    if legacy:
        updated["legacy"] = True
    if status == "backlog":
        updated["branch"] = ""
    normalized.append(updated)

discovered = set()
for parent in (repo_root / "docs" / "specai", repo_root / "docs" / "specai" / "feature"):
    if not parent.is_dir():
        continue
    for child in parent.iterdir():
        if not feature_pattern.fullmatch(child.name):
            continue
        if not authorized(child):
            fail(f"feature directory resolves outside repo for {child.name}")
        if not child.is_dir():
            fail(f"feature directory is not a directory for {child.name}")
        if child.name not in seen:
            fail(f"unindexed feature directory: {child.name}")
        discovered.add(child.name)
unindexed = sorted(discovered - seen)
if unindexed:
    fail(f"unindexed feature directories: {', '.join(unindexed)}")

payload = json.dumps(normalized, ensure_ascii=False, indent=2) + "\n"
if mode == "reconcile":
    current = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
    if current != payload:
        fail("reconciliation required; run sync after reviewing the proposed normalization")
    print(f"backlog reconciliation: PASS ({len(normalized)} entr{'y' if len(normalized) == 1 else 'ies'})")
    raise SystemExit(0)
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=backlog_path.parent,
                                 prefix=f".{backlog_path.name}.", delete=False) as temp:
    temp.write(payload)
    temp_path = temp.name
os.replace(temp_path, backlog_path)
print(f"backlog synchronized: {len(normalized)} entr{'y' if len(normalized) == 1 else 'ies'}")
PY
}

cmd="${1:-}"

case "$cmd" in
list)
    if [ -f "$BACKLOG_FILE" ]; then
        "$JQ" '.' "$BACKLOG_FILE"
    else
        echo '[]'
    fi
    ;;

add)
    if [ $# -lt 5 ]; then
        echo "Usage: $0 add <name> <date> <priority> <plan_dir>" >&2
        exit 1
    fi
    name="$2"
    date="$3"
    priority="$4"
    ensure_backlog_file
    requested_path="$5"
    requested_base="$(basename "$requested_path")"
    if [[ "$requested_base" == *-plan.md ]]; then
        feature_id="${requested_base%-plan.md}"
        feature_dir="$(dirname "$requested_path")"
    else
        feature_dir="$requested_path"
        feature_id="$requested_base"
    fi
    if [[ "$feature_dir" = "$REPO_ROOT"/* ]]; then
        feature_dir="${feature_dir#"$REPO_ROOT"/}"
    fi
    plan_dir="$feature_dir/$feature_id-plan.md"
    [[ -d "$REPO_ROOT/$feature_dir" ]] || { echo "Feature directory not found: $feature_dir" >&2; exit 1; }
    [[ -f "$REPO_ROOT/$plan_dir" ]] || { echo "Plan file not found: $plan_dir" >&2; exit 1; }
    max_id=$("$JQ" 'map(.id) | if length == 0 then 0 else max end' "$BACKLOG_FILE")
    new_id=$((max_id + 1))
    tmpfile=$(mktemp)
    "$JQ" --argjson id "$new_id" --arg name "$name" --arg date "$date" \
          --arg priority "$priority" --arg plan_dir "$plan_dir" \
          --arg feature_id "$feature_id" --arg feature_dir "$feature_dir" \
          '. += [{"id": $id, "name": $name, "date": $date, "feature_id": $feature_id, "status": "backlog", "branch": "", "priority": $priority, "feature_dir": $feature_dir, "plan_dir": $plan_dir}]' \
          "$BACKLOG_FILE" > "$tmpfile"
    mv "$tmpfile" "$BACKLOG_FILE"
    echo "$new_id"
    ;;

update-status)
    if [ $# -lt 3 ]; then
        echo "Usage: $0 update-status <id> <status>" >&2
        exit 1
    fi
    ensure_backlog_file
    id="$2"
    status="$3"
    case "$status" in
        in-progress) status="in_progress" ;;
        ready-to-finish) status="ready_to_finish" ;;
        backlog|in_progress|verifying|ready_to_finish|done) ;;
        *) echo "Invalid status: $status" >&2; exit 1 ;;
    esac
    if [[ "$status" == done ]]; then
        current_status=$("$JQ" -r --argjson id "$id" '.[] | select(.id == $id) | .status // empty' "$BACKLOG_FILE")
        feature_id=$("$JQ" -r --argjson id "$id" '.[] | select(.id == $id) | .feature_id // empty' "$BACKLOG_FILE")
        current_feature_dir=$("$JQ" -r --argjson id "$id" '.[] | select(.id == $id) | .feature_dir // empty' "$BACKLOG_FILE")
        [[ -n "$feature_id" ]] || { echo "Feature ID required before marking done" >&2; exit 1; }
        if [[ "$current_status" != done ]]; then
            [[ "$current_status" == ready_to_finish ]] || { echo "Feature must be ready_to_finish before marking done: $feature_id" >&2; exit 1; }
            [[ "$current_feature_dir" == "docs/specai/$feature_id" ]] || { echo "Feature must transition to done from its active path: $feature_id" >&2; exit 1; }
        fi
        active="$REPO_ROOT/docs/specai/$feature_id"
        archive="$REPO_ROOT/docs/specai/feature/$feature_id"
        if [[ "$current_status" != done ]]; then
            [[ -d "$archive" && ! -e "$active" ]] || { echo "Feature must be archived before marking done: $feature_id" >&2; exit 1; }
        fi
    fi
    tmpfile=$(mktemp)
    "$JQ" --argjson id "$id" --arg status "$status" \
        'map(if .id == $id then .status = $status else . end)' \
        "$BACKLOG_FILE" > "$tmpfile"
    mv "$tmpfile" "$BACKLOG_FILE"
    ;;

update-branch)
    if [ $# -lt 3 ]; then
        echo "Usage: $0 update-branch <id> <branch>" >&2
        exit 1
    fi
    ensure_backlog_file
    id="$2"
    branch="$3"
    tmpfile=$(mktemp)
    "$JQ" --argjson id "$id" --arg branch "$branch" \
        'map(if .id == $id then .branch = $branch else . end)' \
        "$BACKLOG_FILE" > "$tmpfile"
    mv "$tmpfile" "$BACKLOG_FILE"
    ;;

get)
    if [ $# -lt 2 ]; then
        echo "Usage: $0 get <id>" >&2
        exit 1
    fi
    id="$2"
    if [ -f "$BACKLOG_FILE" ]; then
        "$JQ" --argjson id "$id" '.[] | select(.id == $id)' "$BACKLOG_FILE"
    fi
    ;;

sync|reconcile)
    sync_backlog "$cmd"
    ;;

*)
    echo "Usage: $0 {list|add|update-status|update-branch|get|sync|reconcile} [args...]" >&2
    exit 1
    ;;
esac
