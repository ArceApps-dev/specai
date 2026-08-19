#!/usr/bin/env python3
"""Materialize Codex command definitions from the canonical OpenCode source."""

import json
import os
import secrets
import stat
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


class DuplicateJSONKeyError(ValueError):
    """A JSON object contains a key more than once."""


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def authorized(path):
    try:
        path.resolve(strict=False).relative_to(Path.cwd().resolve())
    except (OSError, ValueError):
        return False
    return True


def _open_flags(directory=False, write=False):
    try:
        flags = os.O_WRONLY if write else os.O_RDONLY
        flags |= os.O_CLOEXEC | os.O_NOFOLLOW
        if directory:
            flags |= os.O_DIRECTORY
    except AttributeError as error:
        raise GeneratorError("secure descriptor flags are unavailable") from error
    return flags


def _open_directory_at(name, dir_fd=None):
    fd = os.open(name, _open_flags(directory=True), dir_fd=dir_fd)
    try:
        if not stat.S_ISDIR(os.fstat(fd).st_mode):
            raise OSError(f"not a directory: {name}")
    except BaseException:
        os.close(fd)
        raise
    return fd


def _relative_parts(path):
    relative = Path(os.path.relpath(os.fspath(path), os.getcwd()))
    if relative == Path(".") or any(part == ".." for part in relative.parts):
        raise GeneratorError(f"path is outside the authorized tree: {path}")
    return relative.parts


def _open_parent_directory(path):
    parts = _relative_parts(path)
    parent_fd = _open_directory_at(".")
    try:
        for part in parts[:-1]:
            next_fd = _open_directory_at(part, dir_fd=parent_fd)
            os.close(parent_fd)
            parent_fd = next_fd
    except BaseException:
        os.close(parent_fd)
        raise
    return parent_fd, parts[-1]


def _read_descriptor(fd):
    chunks = []
    while True:
        chunk = os.read(fd, 1024 * 1024)
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)


def _open_regular_file_at(name, dir_fd, write=False, mode=0o644):
    flags = _open_flags(write=write)
    if write:
        flags |= os.O_CREAT | os.O_EXCL
    fd = os.open(name, flags, mode, dir_fd=dir_fd)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError(f"not a regular file: {name}")
    except BaseException:
        os.close(fd)
        raise
    return fd


def load_source(source_path):
    if not authorized(source_path):
        raise GeneratorError(f"source path resolves outside the authorized tree: {source_path}")
    parent_fd = None
    source_fd = None
    try:
        parent_fd, source_name = _open_parent_directory(source_path)
        source_fd = _open_regular_file_at(source_name, parent_fd)
        source_text = _read_descriptor(source_fd).decode("utf-8")
    except (GeneratorError, OSError, UnicodeError) as error:
        raise GeneratorError(f"cannot read {source_path}: {error}") from error
    finally:
        if source_fd is not None:
            os.close(source_fd)
        if parent_fd is not None:
            os.close(parent_fd)

    try:
        source = json.loads(source_text, object_pairs_hook=reject_duplicate_keys)
    except (DuplicateJSONKeyError, json.JSONDecodeError) as error:
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


def validate_commands_directory_fd(commands_fd, commands_dir, require_files):
    expected_names = {f"{command_id}.md" for command_id in APPROVED_COMMAND_IDS}
    try:
        actual_names = set(os.listdir(commands_fd))
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
        try:
            output_stat = os.stat(name, dir_fd=commands_fd, follow_symlinks=False)
        except OSError as error:
            raise GeneratorError(f"cannot inspect {output_path}: {error}") from error
        if stat.S_ISLNK(output_stat.st_mode):
            raise GeneratorError(f"output entry must not be a symlink: {output_path}")
        if not stat.S_ISREG(output_stat.st_mode):
            raise GeneratorError(f"output entry is not a file: {output_path}")


def open_commands_directory(commands_dir, create):
    if not authorized(commands_dir):
        raise GeneratorError(f"output path resolves outside the authorized tree: {commands_dir}")
    parent_fd = None
    try:
        parent_fd, commands_name = _open_parent_directory(commands_dir)
        try:
            return _open_directory_at(commands_name, dir_fd=parent_fd), True
        except FileNotFoundError:
            if not create:
                raise GeneratorError(f"missing output directory: {commands_dir}")
            try:
                os.mkdir(commands_name, 0o755, dir_fd=parent_fd)
                created = True
            except FileExistsError:
                created = False
            return _open_directory_at(commands_name, dir_fd=parent_fd), not created
    except GeneratorError:
        raise
    except OSError as error:
        raise GeneratorError(f"cannot open output directory {commands_dir}: {error}") from error
    finally:
        if parent_fd is not None:
            os.close(parent_fd)


def validate_commands_directory(commands_dir, require_files):
    commands_fd = None
    try:
        commands_fd, _ = open_commands_directory(commands_dir, create=False)
        validate_commands_directory_fd(commands_fd, commands_dir, require_files)
    except GeneratorError as error:
        if not require_files and str(error).startswith("missing output directory:"):
            return
        raise
    finally:
        if commands_fd is not None:
            os.close(commands_fd)


def _write_atomic(commands_fd, name, content):
    temporary_name = None
    temporary_fd = None
    try:
        for _ in range(10):
            candidate = f".{name}.tmp-{os.getpid()}-{secrets.token_hex(8)}"
            try:
                temporary_fd = _open_regular_file_at(
                    candidate,
                    commands_fd,
                    write=True,
                    mode=0o600,
                )
                temporary_name = candidate
                break
            except FileExistsError:
                continue
        if temporary_fd is None or temporary_name is None:
            raise OSError(f"cannot allocate temporary output for {name}")

        view = memoryview(content)
        while view:
            written = os.write(temporary_fd, view)
            view = view[written:]
        os.fsync(temporary_fd)
        os.close(temporary_fd)
        temporary_fd = None
        os.replace(
            temporary_name,
            name,
            src_dir_fd=commands_fd,
            dst_dir_fd=commands_fd,
        )
        temporary_name = None
    finally:
        if temporary_fd is not None:
            os.close(temporary_fd)
        if temporary_name is not None:
            try:
                os.unlink(temporary_name, dir_fd=commands_fd)
            except FileNotFoundError:
                pass


def write_commands(commands_dir, rendered, commands_fd=None):
    owns_fd = commands_fd is None
    if owns_fd:
        commands_fd = None
    try:
        if owns_fd:
            commands_fd, _ = open_commands_directory(commands_dir, create=True)
        for command_id, content in rendered.items():
            _write_atomic(commands_fd, f"{command_id}.md", content)
        os.fsync(commands_fd)
    except OSError as error:
        raise GeneratorError(f"cannot write {commands_dir}: {error}") from error
    finally:
        if owns_fd and commands_fd is not None:
            os.close(commands_fd)


def check_commands(commands_dir, rendered, commands_fd=None):
    owns_fd = commands_fd is None
    try:
        if owns_fd:
            commands_fd, _ = open_commands_directory(commands_dir, create=False)
            validate_commands_directory_fd(commands_fd, commands_dir, require_files=True)
        for command_id, expected in rendered.items():
            output_path = commands_dir / f"{command_id}.md"
            output_fd = None
            try:
                output_fd = _open_regular_file_at(output_path.name, commands_fd)
                actual = _read_descriptor(output_fd)
            except (OSError, GeneratorError) as error:
                raise GeneratorError(f"cannot read {output_path}: {error}") from error
            finally:
                if output_fd is not None:
                    os.close(output_fd)
            if actual != expected:
                raise GeneratorError(f"materialized definition differs: {output_path}")
    finally:
        if owns_fd and commands_fd is not None:
            os.close(commands_fd)


def main(argv):
    if len(argv) != 2 or argv[1] not in {"--write", "--check"}:
        print("error: expected exactly one of --write or --check", file=sys.stderr)
        return 1

    try:
        source = load_source(Path.cwd() / ".opencode" / "commands.json")
        rendered = render_commands(source)
        commands_dir = Path.cwd() / "commands"
        commands_fd, output_exists = open_commands_directory(
            commands_dir,
            create=argv[1] == "--write",
        )
        try:
            validate_commands_directory_fd(
                commands_fd,
                commands_dir,
                require_files=argv[1] == "--check" or output_exists,
            )
            if argv[1] == "--write":
                write_commands(commands_dir, rendered, commands_fd)
            else:
                check_commands(commands_dir, rendered, commands_fd)
        finally:
            os.close(commands_fd)
    except GeneratorError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
