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
import os
import re
import sys
from datetime import datetime
from pathlib import Path

feature_id, raw_root = sys.argv[1:]
repo_root = Path(raw_root).resolve()
errors: list[str] = []
archive_staging = os.environ.get("SPECAI_ARCHIVE_STAGING") == "1"
feature_pattern = re.compile(r"^\d{8}-[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?$")
required_suffixes = ("prd", "spec", "designs", "plan", "tasks", "verify")
link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
requirement_pattern = re.compile(r"\bREQ-[A-Z0-9][A-Z0-9_-]*\b")
declared_id_pattern = re.compile(
    r"(?im)^[ \t]*(?:[-*][ \t]*)?(?:\*\*Feature ID:\*\*|Feature ID:)[ \t]*(?:`([^`\n]+)`|([^\s*`]+))[ \t]*$"
)


def drift(message: str) -> None:
    errors.append(message)


def path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def authorized(path: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(repo_root)
    except ValueError:
        return False
    return True


def declared_feature_ids(text: str) -> list[str]:
    return [backticked or plain for backticked, plain in declared_id_pattern.findall(text)]


def check_adr_provenance(feature_dir: Path | None) -> None:
    if feature_dir is None:
        return
    adr_root = repo_root / "docs" / "adr"
    if not adr_root.is_dir():
        return

    feature_line = re.compile(
        r"(?im)^\*\*Feature de origen:\*\*\s+`?([^`\s]+)`?\s*$"
    )
    provenance_fields = {
        "destination": re.compile(
            r"(?m)^\*\*Ruta de feature:\*\*\s+[^\n]*\(([^)]+)\)"
        ),
        "prd": re.compile(
            r"(?m)^\*\*PRD relacionada:\*\*\s+[^\n]*\(([^)]+)\)"
        ),
        "spec": re.compile(
            r"(?m)^\*\*Spec normativa:\*\*\s+[^\n]*\(([^)]+)\)"
        ),
        "designs": re.compile(
            r"(?m)^\*\*Diseño relacionado:\*\*\s+[^\n]*\(([^)]+)\)"
        ),
    }
    expected = {
        "destination": feature_dir.resolve(),
        "prd": (feature_dir / f"{feature_id}-prd.md").resolve(),
        "spec": (feature_dir / f"{feature_id}-spec.md").resolve(),
        "designs": (feature_dir / f"{feature_id}-designs.md").resolve(),
    }

    for adr_path in sorted(adr_root.glob("ADR-*.md")):
        if adr_path.is_symlink() or not adr_path.is_file():
            continue
        try:
            text = adr_path.read_text(encoding="utf-8")
        except OSError as exc:
            drift(f"cannot read ADR provenance {adr_path.name}: {exc}")
            continue

        declared = feature_line.search(text)
        destination_match = provenance_fields["destination"].search(text)
        related = declared is not None and declared.group(1) == feature_id
        if not related and destination_match:
            destination = (adr_path.parent / destination_match.group(1).strip()).resolve()
            related = destination == expected["destination"]
        if not related:
            continue

        if declared is None:
            drift(f"ADR provenance missing Feature ID in {adr_path.name}")
        elif declared.group(1) != feature_id:
            drift(
                f"ADR provenance Feature ID mismatch in {adr_path.name}: "
                f"{declared.group(1)}"
            )

        for field, pattern in provenance_fields.items():
            match = pattern.search(text)
            if not match:
                drift(f"ADR provenance missing {field} in {adr_path.name}")
                continue
            link = match.group(1).strip()
            resolved = (adr_path.parent / link).resolve()
            if resolved != expected[field]:
                drift(
                    f"ADR provenance mismatch in {adr_path.name}: "
                    f"{field} {link} -> {resolved}"
                )
            if not resolved.exists():
                drift(
                    f"broken ADR provenance in {adr_path.name}: "
                    f"{field} {link}"
                )


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

if active_exists and not authorized(active_dir):
    drift("active destination resolves outside repo")
if archive_exists and not authorized(archive_dir):
    drift("archive destination resolves outside repo")

if active_exists and archive_exists:
    drift("active and archive destinations both exist")
elif active_exists and not active_dir.is_dir():
    drift("active destination is not a directory")
elif archive_exists and not archive_dir.is_dir():
    drift("archive destination is not a directory")

feature_dir: Path | None = None
if active_dir.is_dir() and not archive_exists and authorized(active_dir):
    feature_dir = active_dir
elif archive_dir.is_dir() and not active_exists and authorized(archive_dir):
    feature_dir = archive_dir
elif not active_exists and not archive_exists:
    drift("feature directory not found")

check_adr_provenance(feature_dir)

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
    if not authorized(feature_dir):
        drift("feature directory resolves outside repo")
    else:
        expected = {f"{feature_id}-{suffix}.md" for suffix in required_suffixes}
        try:
            children = list(feature_dir.iterdir())
        except OSError as exc:
            drift(f"cannot inspect feature directory: {exc}")
            children = []
        actual = {path.name for path in children}
        for missing in sorted(expected - actual):
            drift(f"missing artifact: {missing}")
        for extra in sorted(actual - expected):
            drift(f"artifact does not use Feature ID prefix: {extra}")

        files = [feature_dir / name for name in sorted(expected)]
        for path in files:
            if not path_exists(path):
                continue
            if path.is_symlink():
                if not authorized(path):
                    drift(f"artifact resolves outside repo: {path.name}")
                else:
                    suffix = path.name[len(feature_id) + 1:-3]
                    drift(f"{suffix} artifact must not be a symlink")
                continue
            if not authorized(path):
                drift(f"artifact resolves outside repo: {path.name}")
                continue
            if not path.is_file():
                drift(f"artifact is not a regular file: {path.name}")
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except OSError as exc:
                drift(f"cannot read artifact {path.name}: {exc}")
                continue

            declared_ids = declared_feature_ids(text)
            if not declared_ids:
                drift(f"missing Feature ID in {path.name}")
            elif len(declared_ids) > 1:
                drift(f"duplicate Feature ID in {path.name}")
            for declared_id in declared_ids:
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

            if path.name == f"{feature_id}-spec.md":
                spec_text = text
            elif path.name == f"{feature_id}-verify.md":
                verify_text = text

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
                    if not archive_staging and entry.get("feature_dir") != expected_dir:
                        drift(f"backlog feature_dir mismatch: {entry.get('feature_dir')}")
                    if not archive_staging and entry.get("plan_dir") != expected_plan:
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
                    if not archive_staging and feature_dir == archive_dir and status != "done":
                        drift("archived feature is not done in backlog")
                    if not archive_staging and feature_dir == active_dir and status == "done":
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
