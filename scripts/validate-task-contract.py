#!/usr/bin/env python3
"""Validate that generated task entries contain an executable change contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path


TASK_HEADER = re.compile(r"^#{2,3} (?:Task\s+|T)?\d+\b.*$", re.MULTILINE)
SECTION_HEADER = re.compile(r"^#{1,6} .*$", re.MULTILINE)
DIRECT_FIELD = re.compile(r"^[ \t]*\*\*([A-Za-z][A-Za-z ]*):\*\*[ \t]*(.*)$", re.MULTILINE)
FIELD = re.compile(r"^[ \t]*-[ \t]*\*\*(Target|Location|Current|Change|Assertion):\*\*[ \t]*(.+)$", re.MULTILINE)
FILE_ENTRY = re.compile(r"^\s*-\s+(?:Create|Modify|Delete|Test):\s+`([^`]+)`\s*$", re.MULTILINE)


def fail(path: Path, task_number: int, message: str) -> str:
    return f"{path}: task {task_number}: {message}"


def section(block: str, title: str) -> str:
    matches = [match for match in DIRECT_FIELD.finditer(block) if match.group(1) == title]
    if len(matches) != 1:
        return ""
    start = matches[0].end()
    boundaries = [match.start() for match in DIRECT_FIELD.finditer(block, start)]
    heading = SECTION_HEADER.search(block, start)
    if heading:
        boundaries.append(heading.start())
    end = min(boundaries, default=len(block))
    return block[start:end]


def direct_field_matches(block: str, title: str) -> list[re.Match[str]]:
    return [match for match in DIRECT_FIELD.finditer(block) if match.group(1) == title]


def validate(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    headers = list(TASK_HEADER.finditer(text))
    if not headers:
        return [f"{path}: no numbered task entries found"]

    errors: list[str] = []
    for index, header in enumerate(headers, start=1):
        end = headers[index].start() if index < len(headers) else len(text)
        block = text[header.end() : end]

        files = FILE_ENTRY.findall(section(block, "Files"))
        if not files:
            errors.append(fail(path, index, "Files must list exact backticked paths"))

        first_heading = SECTION_HEADER.search(block)
        metadata = block[: first_heading.start()] if first_heading else block
        criteria_matches = [match for match in direct_field_matches(metadata, "Criteria")]
        if len(criteria_matches) != 1 or not re.findall(r"\bC\d+\b", criteria_matches[0].group(2) if criteria_matches else ""):
            errors.append(fail(path, index, "Criteria must be an exact field in the task block and map to one or more verification IDs such as C1"))

        contract = section(block, "Implementation Contract")
        if not contract:
            errors.append(
                fail(
                    path,
                    index,
                    "missing Implementation Contract with Target, Location, Current, Change, and Assertion",
                )
            )
            continue

        field_matches = FIELD.findall(contract)
        fields = {name: value.strip() for name, value in field_matches}
        for name in ("Target", "Location", "Current", "Change", "Assertion"):
            if name not in fields or sum(field_name == name for field_name, _ in field_matches) != 1:
                errors.append(fail(path, index, f"Implementation Contract is missing {name}"))

        for name in ("Target", "Location"):
            value = fields.get(name, "")
            if value and ("`" not in value or "..." in value or "<" in value or "[" in value):
                errors.append(fail(path, index, f"{name} must identify an exact symbol, selector, or method in backticks"))

        current = fields.get("Current", "")
        if current and not ("`" in current or current.startswith("N/A —")):
            errors.append(fail(path, index, "Current must contain the literal current value or an explicit N/A reason"))

        change = fields.get("Change", "")
        verification_only = change.startswith("N/A —") and "verification-only" in change.lower()
        if change and not verification_only and not re.search(r"`[^`]+`\s*(?:->|→)\s*`[^`]+`", change):
            errors.append(fail(path, index, "Change must show an exact `before` -> `after` value or mark the task verification-only"))

        assertion = fields.get("Assertion", "")
        if assertion and ("`" not in assertion or "..." in assertion or "<" in assertion):
            errors.append(fail(path, index, "Assertion must name the observable assertion or output in backticks"))

        steps = section(block, "Steps")
        if not re.search(r"^\s*-?\s*(?:Run|Ejecutar):\s*.+", steps, re.MULTILINE):
            errors.append(fail(path, index, "Steps must include an exact Run command"))
        if not re.search(r"^\s*-?\s*Expected:\s*.+", steps, re.MULTILINE):
            errors.append(fail(path, index, "Steps must include a concrete Expected result"))

    return errors


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: validate-task-contract.py TASKS.md [TASKS.md ...]", file=sys.stderr)
        return 2

    errors: list[str] = []
    for argument in argv:
        path = Path(argument)
        if not path.is_file():
            errors.append(f"{path}: file not found")
            continue
        errors.extend(validate(path))

    if errors:
        print("task contract: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("task contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
