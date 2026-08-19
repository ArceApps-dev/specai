#!/usr/bin/env python3
"""Materialize Codex command definitions from the canonical OpenCode source."""

import json
import os
import sys
from pathlib import Path


APPROVED_COMMAND_IDS = frozenset(
    {
        "specai-plan",
        "specai-mini",
        "specai-explore",
        "specai-verify",
        "specai-review",
        "specai-iterate",
        "specai-mode",
        "specai-audit",
        "specai-audit-plan",
        "specai-backlog",
        "specai-init",
        "specai-finish",
        "specai-config",
    }
)


class GeneratorError(Exception):
    """An input or materialized-output contract violation."""


def load_source(source_path):
    try:
        source_text = source_path.read_text(encoding="utf-8")
    except OSError as error:
        raise GeneratorError(f"cannot read {source_path}: {error}") from error

    try:
        source = json.loads(source_text)
    except json.JSONDecodeError as error:
        raise GeneratorError(f"invalid JSON in {source_path}: {error}") from error

    if not isinstance(source, dict):
        raise GeneratorError(".opencode/commands.json must contain an object")

    source_ids = set(source)
    missing_ids = sorted(APPROVED_COMMAND_IDS - source_ids)
    extra_ids = sorted(source_ids - APPROVED_COMMAND_IDS)
    if missing_ids or extra_ids:
        details = []
        if missing_ids:
            details.append(f"missing: {', '.join(missing_ids)}")
        if extra_ids:
            details.append(f"extra: {', '.join(extra_ids)}")
        raise GeneratorError("command IDs do not match the approved set (" + "; ".join(details) + ")")

    for command_id in sorted(APPROVED_COMMAND_IDS):
        entry = source[command_id]
        if not isinstance(entry, dict):
            raise GeneratorError(f"{command_id}: entry must be an object")
        for field in ("description", "template"):
            if not isinstance(entry.get(field), str):
                raise GeneratorError(f"{command_id}: {field} must be a string")

    return source


def render_commands(source):
    rendered = {}
    for command_id in sorted(APPROVED_COMMAND_IDS):
        entry = source[command_id]
        description = json.dumps(entry["description"], ensure_ascii=False)
        rendered[command_id] = (
            f"---\n"
            f"description: {description}\n"
            f"---\n"
            f"{entry['template']}"
        ).encode("utf-8")
    return rendered


def validate_commands_directory(commands_dir, require_files):
    if os.path.lexists(commands_dir) and commands_dir.is_symlink():
        raise GeneratorError(f"output path must not be a symlink: {commands_dir}")
    if not commands_dir.exists():
        if require_files:
            raise GeneratorError(f"missing output directory: {commands_dir}")
        return
    if not commands_dir.is_dir():
        raise GeneratorError(f"output path is not a directory: {commands_dir}")

    expected_names = {f"{command_id}.md" for command_id in APPROVED_COMMAND_IDS}
    try:
        actual_names = {entry.name for entry in commands_dir.iterdir()}
    except OSError as error:
        raise GeneratorError(f"cannot inspect {commands_dir}: {error}") from error

    unexpected_names = sorted(actual_names - expected_names)
    if unexpected_names:
        raise GeneratorError(
            f"unexpected entries in {commands_dir}: {', '.join(unexpected_names)}"
        )

    if require_files:
        missing_names = sorted(expected_names - actual_names)
        if missing_names:
            raise GeneratorError(
                f"missing command definitions in {commands_dir}: {', '.join(missing_names)}"
            )

    for name in actual_names & expected_names:
        output_path = commands_dir / name
        if os.path.lexists(output_path) and output_path.is_symlink():
            raise GeneratorError(f"output entry must not be a symlink: {output_path}")
        if not output_path.is_file():
            raise GeneratorError(f"output entry is not a file: {output_path}")


def write_commands(commands_dir, rendered):
    try:
        commands_dir.mkdir(parents=True, exist_ok=True)
        for command_id, content in rendered.items():
            (commands_dir / f"{command_id}.md").write_bytes(content)
    except OSError as error:
        raise GeneratorError(f"cannot write {commands_dir}: {error}") from error


def check_commands(commands_dir, rendered):
    validate_commands_directory(commands_dir, require_files=True)
    for command_id, expected in rendered.items():
        output_path = commands_dir / f"{command_id}.md"
        try:
            actual = output_path.read_bytes()
        except OSError as error:
            raise GeneratorError(f"cannot read {output_path}: {error}") from error
        if actual != expected:
            raise GeneratorError(f"materialized definition differs: {output_path}")


def main(argv):
    if len(argv) != 2 or argv[1] not in {"--write", "--check"}:
        print("error: expected exactly one of --write or --check", file=sys.stderr)
        return 1

    try:
        source = load_source(Path.cwd() / ".opencode" / "commands.json")
        rendered = render_commands(source)
        commands_dir = Path.cwd() / "commands"
        validate_commands_directory(commands_dir, require_files=False)
        if argv[1] == "--write":
            write_commands(commands_dir, rendered)
        else:
            check_commands(commands_dir, rendered)
    except GeneratorError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
