#!/usr/bin/env python3
"""Validate the goal-level acceptance and recovery contract in a verify file."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CRITERION_HEADER = re.compile(r"^### (C\d+)\b.*$", re.MULTILINE)
TASK_HEADER = re.compile(r"^#{2,3} (?:Task\s+|T)?\d+\b.*$", re.MULTILINE)
FIELD = re.compile(r"^\s*-?\s*\*\*(Goal ID|Goal|Goal completion invariant|Status|Requirement|Criterion type|Invariant|Verification seam|Given|When|Then|Tasks|Verification command|Expected|Evidence|Verifier verdict|Last verified HEAD|Open failures|Corrective loop):\*\*\s*(.+)$", re.MULTILINE)
DIRECT_TASK_FIELD = re.compile(r"^[ \t]*\*\*(Criteria):\*\*[ \t]*(.*)$", re.MULTILINE)

CRITERION_FIELDS = (
    "Requirement",
    "Criterion type",
    "Invariant",
    "Verification seam",
    "Given",
    "When",
    "Then",
    "Tasks",
    "Verification command",
    "Expected",
    "Evidence",
    "Status",
)
VALID_CRITERION_STATUS = {"PENDING", "PASS", "FAIL", "UNVERIFIED"}
VALID_GOAL_STATUS = {"OPEN", "VERIFYING", "BLOCKED", "PASS"}
VALID_CRITERION_TYPES = {"BEHAVIOR", "ARCHITECTURE", "INTEGRATION", "VISUAL", "MECHANICAL", "NONFUNCTIONAL", "SECURITY", "DOCUMENTATION"}


def error(path: Path, message: str) -> str:
    return f"{path}: {message}"


def field_values(text: str) -> dict[str, str]:
    return {name: values[-1].strip() for name, values in field_occurrences(text).items()}


def field_occurrences(text: str) -> dict[str, list[str]]:
    values: dict[str, list[str]] = {}
    for name, value in FIELD.findall(text):
        values.setdefault(name, []).append(value)
    return values


def top_level_section(text: str, title: str) -> str:
    header = re.compile(rf"^## {re.escape(title)}\s*$", re.MULTILINE)
    matches = list(header.finditer(text))
    if len(matches) != 1:
        return ""
    start = matches[0].end()
    next_section = re.search(r"^## (?!#).*$", text[start:], re.MULTILINE)
    end = start + next_section.start() if next_section else len(text)
    return text[start:end]


def criterion_blocks(text: str) -> list[tuple[str, str]]:
    acceptance = top_level_section(text, "Acceptance Criteria")
    headers = list(CRITERION_HEADER.finditer(acceptance))
    return [
        (header.group(1), acceptance[header.end() : headers[index + 1].start() if index + 1 < len(headers) else len(acceptance)])
        for index, header in enumerate(headers)
    ]


def validate_tasks(path: Path) -> tuple[list[str], set[str], dict[str, set[str]]]:
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    task_ids: set[str] = set()
    task_criteria: dict[str, set[str]] = {}
    for index, header in enumerate(TASK_HEADER.finditer(text), start=1):
        task_id_match = re.search(r"\b(T\d+)\b", header.group(0))
        task_id = task_id_match.group(1) if task_id_match else f"T{index}"
        task_ids.add(task_id)
        next_header = re.search(r"^#{2,3} (?:Task\s+|T)?\d+\b.*$", text[header.end() :], re.MULTILINE)
        block_end = header.end() + next_header.start() if next_header else len(text)
        block = text[header.end() : block_end]
        first_heading = re.search(r"^#{1,6} .*$", block, re.MULTILINE)
        metadata = block[: first_heading.start()] if first_heading else block
        matches = list(DIRECT_TASK_FIELD.finditer(metadata))
        criteria = set(re.findall(r"\bC\d+\b", matches[0].group(2))) if len(matches) == 1 else set()
        if not criteria:
            errors.append(error(path, f"{task_id}: missing exact Criteria field mapping"))
        task_criteria[task_id] = criteria
    if not task_ids:
        errors.append(error(path, "no numbered task entries found"))
    return errors, task_ids, task_criteria


def validate(path: Path, tasks_path: Path | None) -> list[str]:
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    acceptance_match = re.search(r"^## Acceptance Criteria\s*$", text, re.MULTILINE)
    fields = field_values(text[:acceptance_match.start()] if acceptance_match else text)
    state_fields = field_values(top_level_section(text, "Verification State"))

    for required in ("Goal ID", "Goal", "Goal completion invariant"):
        if required not in fields:
            errors.append(error(path, f"missing **{required}:**"))

    invariant = fields.get("Goal completion invariant", "")
    if invariant and not all(token in invariant for token in ("GOAL_COMPLETE", "iff", "criterion", "task", "evidence")):
        errors.append(error(path, "Goal completion invariant must define GOAL_COMPLETE as a conjunction of criteria, tasks, and fresh evidence"))

    goal_status = fields.get("Status", "").strip("`").upper()
    if goal_status not in VALID_GOAL_STATUS:
        errors.append(error(path, "Status must be OPEN, VERIFYING, BLOCKED, or PASS"))

    blocks = criterion_blocks(text)
    if not blocks:
        errors.append(error(path, "Acceptance Criteria must contain numbered C1, C2, ... entries"))

    criterion_ids: set[str] = set()
    criterion_tasks: dict[str, set[str]] = {}
    criterion_statuses: dict[str, str] = {}
    for criterion_id, block in blocks:
        if criterion_id in criterion_ids:
            errors.append(error(path, f"{criterion_id}: duplicate criterion block"))
        criterion_ids.add(criterion_id)
        occurrences = field_occurrences(block)
        values = {name: entries[-1].strip() for name, entries in occurrences.items()}
        for required in CRITERION_FIELDS:
            if required not in values or len(occurrences.get(required, [])) != 1:
                errors.append(error(path, f"{criterion_id}: missing **{required}:**"))

        criterion_type = values.get("Criterion type", "").strip("`").upper()
        if criterion_type and criterion_type not in VALID_CRITERION_TYPES:
            errors.append(error(path, f"{criterion_id}: Criterion type must be one of {', '.join(sorted(VALID_CRITERION_TYPES))}"))

        tasks = set(re.findall(r"\bT\d+\b", values.get("Tasks", "")))
        if not tasks:
            errors.append(error(path, f"{criterion_id}: Tasks must name at least one task ID"))
        criterion_tasks[criterion_id] = tasks

        command = values.get("Verification command", "")
        if command and "`" not in command:
            errors.append(error(path, f"{criterion_id}: Verification command must be exact and backticked"))

        status = values.get("Status", "").strip("`").upper()
        if status and status not in VALID_CRITERION_STATUS:
            errors.append(error(path, f"{criterion_id}: Status must be PENDING, PASS, FAIL, or UNVERIFIED"))
        criterion_statuses[criterion_id] = status

    coverage = top_level_section(text, "Coverage Matrix")
    if not coverage:
        errors.append(error(path, "missing ## Coverage Matrix"))
    else:
        for criterion_id in criterion_ids:
            row = re.compile(rf"^\s*\|\s*`?{re.escape(criterion_id)}`?\s*\|", re.MULTILINE)
            if not row.search(coverage):
                errors.append(error(path, f"Coverage Matrix does not include {criterion_id}"))

    for required in ("Verifier verdict", "Last verified HEAD", "Open failures", "Corrective loop"):
        if required not in state_fields:
            errors.append(error(path, f"Verification State is missing **{required}:**"))

    verifier_verdict = state_fields.get("Verifier verdict", "").strip("`").upper()
    if verifier_verdict and verifier_verdict not in {"NOT_RUN", "PASS", "FAIL", "PARTIAL", "UNVERIFIED"}:
        errors.append(error(path, "Verifier verdict is invalid"))

    if goal_status == "PASS":
        if any(status != "PASS" for status in criterion_statuses.values()):
            errors.append(error(path, "Status PASS requires every acceptance criterion to be PASS"))
        if verifier_verdict != "PASS":
            errors.append(error(path, "Status PASS requires Verifier verdict PASS"))
        if state_fields.get("Open failures", "").strip().lower() not in {"none", "`none`"}:
            errors.append(error(path, "Status PASS requires Open failures: none"))
        if state_fields.get("Corrective loop", "").strip().lower() not in {"none", "`none`"}:
            errors.append(error(path, "Status PASS requires Corrective loop: none"))
        if state_fields.get("Last verified HEAD", "").strip().upper() in {"PENDING", "`PENDING`", "NONE", "`NONE`"}:
            errors.append(error(path, "Status PASS requires a concrete Last verified HEAD"))

    if tasks_path:
        task_errors, task_ids, task_criteria = validate_tasks(tasks_path)
        errors.extend(task_errors)
        for criterion_id, mapped_tasks in criterion_tasks.items():
            missing = mapped_tasks - task_ids
            if missing:
                errors.append(error(path, f"{criterion_id}: unknown task IDs: {', '.join(sorted(missing))}"))
        for task_id, mapped_criteria in task_criteria.items():
            unknown = mapped_criteria - criterion_ids
            if unknown:
                errors.append(error(tasks_path, f"{task_id}: unknown criterion IDs: {', '.join(sorted(unknown))}"))
            for criterion_id in mapped_criteria:
                if task_id not in criterion_tasks.get(criterion_id, set()):
                    errors.append(error(tasks_path, f"{task_id}: {criterion_id} does not list this task in the verification contract"))
        mapped_task_ids = set().union(*criterion_tasks.values()) if criterion_tasks else set()
        for task_id in task_ids - mapped_task_ids:
            errors.append(error(tasks_path, f"{task_id}: task is not covered by any verification criterion"))

    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("verify_file", type=Path)
    parser.add_argument("--tasks", type=Path)
    args = parser.parse_args(argv)

    if not args.verify_file.is_file():
        print(error(args.verify_file, "file not found"), file=sys.stderr)
        return 2
    if args.tasks and not args.tasks.is_file():
        print(error(args.tasks, "file not found"), file=sys.stderr)
        return 2

    errors = validate(args.verify_file, args.tasks)
    if errors:
        print("verification contract: FAIL", file=sys.stderr)
        for item in errors:
            print(f"- {item}", file=sys.stderr)
        return 1

    print("verification contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
