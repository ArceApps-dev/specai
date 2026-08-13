#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/specai-drift.sh check YYYYMMDD-slug [repo-root]
EOF
}

command_name="${1:-}"
feature_id="${2:-}"
repo_root="${3:-${SPECIAI_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"

if [[ "$command_name" != "check" || -z "$feature_id" ]]; then
  usage
  exit 2
fi

python3 - "$feature_id" "$repo_root" <<'PY'
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

feature_id, raw_root = sys.argv[1:]
repo_root = Path(raw_root).resolve()
errors: list[str] = []
feature_pattern = re.compile(r"^\d{8}-[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?$")
required_suffixes = ("prd", "spec", "designs", "plan", "tasks", "verify")
link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
requirement_pattern = re.compile(r"\bREQ-[A-Z0-9][A-Z0-9_-]*\b")
declared_id_pattern = re.compile(
    r"(?im)^\s*(?:\*\*)?Feature ID\s*:\s*(?:\*\*)?\s*`?([^`\s*]+)"
)


def drift(message: str) -> None:
    errors.append(message)


def path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


if not feature_pattern.fullmatch(feature_id):
    drift(f"invalid Feature ID: {feature_id}")
else:
    try:
        datetime.strptime(feature_id[:8], "%Y%m%d")
    except ValueError:
        drift(f"invalid date in Feature ID: {feature_id}")

active_dir = repo_root / "docs" / "specai" / feature_id
archive_dir = repo_root / "docs" / "specai" / "feature" / feature_id
active_exists = path_exists(active_dir)
archive_exists = path_exists(archive_dir)

if active_exists and archive_exists:
    drift("active and archive destinations both exist")
elif active_exists and not active_dir.is_dir():
    drift("active destination is not a directory")
elif archive_exists and not archive_dir.is_dir():
    drift("archive destination is not a directory")

feature_dir: Path | None = None
if active_dir.is_dir() and not archive_exists:
    feature_dir = active_dir
elif archive_dir.is_dir() and not active_exists:
    feature_dir = archive_dir
elif not active_exists and not archive_exists:
    drift("feature directory not found")

project_specs_dir = repo_root / "docs" / "specai" / "project"
if not project_specs_dir.is_dir():
    drift("project specs directory not found: docs/specai/project")
else:
    try:
        project_specs_dir.resolve().relative_to(repo_root)
    except ValueError:
        drift("project specs directory resolves outside repo")

spec_text = ""
verify_text = ""
if feature_dir is not None:
    try:
        feature_dir.resolve().relative_to(repo_root)
    except ValueError:
        drift("feature directory resolves outside repo")

    expected = {f"{feature_id}-{suffix}.md" for suffix in required_suffixes}
    actual = {path.name for path in feature_dir.iterdir() if path.is_file() and path.suffix == ".md"}
    for missing in sorted(expected - actual):
        drift(f"missing artifact: {missing}")
    for extra in sorted(actual - expected):
        drift(f"artifact does not use Feature ID prefix: {extra}")

    files = [feature_dir / name for name in sorted(expected)]
    for path in files:
        if not path.is_file():
            continue
        try:
            path.resolve().relative_to(repo_root)
        except ValueError:
            drift(f"artifact resolves outside repo: {path.name}")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            drift(f"cannot read artifact {path.name}: {exc}")
            continue

        for declared_id in declared_id_pattern.findall(text):
            if declared_id != feature_id:
                drift(f"Feature ID mismatch in {path.name}: {declared_id}")

        for raw_link in link_pattern.findall(text):
            link = raw_link.strip().split()[0].strip("<>")
            if not link or link.startswith(("#", "http://", "https://", "mailto:")):
                continue
            target = link.split("#", 1)[0].split("?", 1)[0]
            if not target:
                continue
            resolved = (path.parent / target).resolve()
            try:
                resolved.relative_to(repo_root)
            except ValueError:
                drift(f"broken reference outside repo in {path.name}: {link}")
                continue
            if not resolved.exists():
                drift(f"broken reference in {path.name}: {link}")

    spec_path = feature_dir / f"{feature_id}-spec.md"
    verify_path = feature_dir / f"{feature_id}-verify.md"
    if spec_path.is_file():
        spec_text = spec_path.read_text(encoding="utf-8")
    if verify_path.is_file():
        verify_text = verify_path.read_text(encoding="utf-8")
    for requirement in sorted(set(requirement_pattern.findall(spec_text))):
        if requirement not in verify_text:
            drift(f"requirement not reflected in verify: {requirement}")

backlog_path = repo_root / ".specai" / "backlog.json"
if backlog_path.is_file():
    try:
        backlog_path.resolve().relative_to(repo_root)
    except ValueError:
        drift("backlog resolves outside repo")
    else:
        try:
            backlog = json.loads(backlog_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            drift(f"cannot read backlog: {exc}")
        else:
            if not isinstance(backlog, list):
                drift("backlog root must be an array")
            else:
                entries = [entry for entry in backlog
                           if isinstance(entry, dict) and entry.get("feature_id") == feature_id]
                if not entries:
                    drift(f"feature missing from backlog: {feature_id}")
                if len(entries) > 1:
                    drift(f"duplicate backlog entries for Feature ID: {feature_id}")
                for entry in entries:
                    expected_dir = (
                        Path("docs/specai/feature") / feature_id
                        if feature_dir == archive_dir
                        else Path("docs/specai") / feature_id
                    ).as_posix()
                    expected_plan = f"{expected_dir}/{feature_id}-plan.md"
                    if entry.get("feature_dir") != expected_dir:
                        drift(f"backlog feature_dir mismatch: {entry.get('feature_dir')}")
                    if entry.get("plan_dir") != expected_plan:
                        drift(f"backlog plan_dir mismatch: {entry.get('plan_dir')}")
                    status = entry.get("status")
                    valid_statuses = {
                        "backlog", "in-progress", "in_progress", "verifying",
                        "ready-to-finish", "ready_to_finish", "done",
                    }
                    if status not in valid_statuses:
                        drift(f"invalid backlog status: {status}")
                    canonical_date = (
                        f"{feature_id[:4]}-{feature_id[4:6]}-{feature_id[6:8]}"
                    )
                    if entry.get("date") != canonical_date:
                        drift(f"backlog date mismatch: {entry.get('date')}")
                    if feature_dir == archive_dir and status != "done":
                        drift("archived feature is not done in backlog")
                    if feature_dir == active_dir and status == "done":
                        drift("active feature is marked done in backlog")

for forbidden in ("specs", "inbox", "inprogress", "in-progress"):
    candidate = repo_root / "docs" / "specai" / forbidden
    if candidate.is_dir():
        drift(f"forbidden parallel documentation directory: docs/specai/{forbidden}")

if errors:
    print("SPEC_DRIFT")
    for error in errors:
        print(f"- {error}")
    print("Resolution required: reconcile the affected sources, review the delta, and rerun this gate.")
    raise SystemExit(1)

print(f"SPEC_DRIFT: PASS — {feature_id}")
PY
