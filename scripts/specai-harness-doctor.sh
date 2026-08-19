#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
JSON_MODE=false

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=true
elif [[ -n "${1:-}" ]]; then
  printf 'Usage: %s [--json]\n' "$0" >&2
  exit 2
fi

SPECAI_CODEX_CONFIG="${SPECAI_CODEX_CONFIG:-$HOME/.codex/config.toml}"
SPECAI_OPENCODE_CONFIG="${SPECAI_OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
SPECAI_ANTIGRAVITY_AGENT_DIR="${SPECAI_ANTIGRAVITY_AGENT_DIR:-$REPO_ROOT/.antigravity-plugin/agents}"
SPECAI_CODEX_CACHE_ROOT="${SPECAI_CODEX_CACHE_ROOT:-$HOME/.codex/plugins/cache}"
SPECAI_CONFIG_FILE="${SPECAI_CONFIG_FILE:-$HOME/.config/specai/config.json}"
SPECAI_HARNESS_LIFECYCLE_FIXTURE="${SPECAI_HARNESS_LIFECYCLE_FIXTURE:-}"
SPECAI_SOURCE_PLUGIN_MANIFEST="${SPECAI_SOURCE_PLUGIN_MANIFEST:-$REPO_ROOT/.codex-plugin/plugin.json}"
SPECAI_CODEX_MARKETPLACES="${SPECAI_CODEX_MARKETPLACES:-$HOME/.codex/plugins/marketplaces.json}"
SPECAI_PERMISSION_TARGETS="${SPECAI_PERMISSION_TARGETS:-$SPECAI_CODEX_CONFIG}"
SPECAI_CODEX_CLI_PATH="${SPECAI_CODEX_CLI_PATH:-}"
SPECAI_CODEX_CLI_HELP="${SPECAI_CODEX_CLI_HELP:-}"

args=(
  "$REPO_ROOT"
  "$SPECAI_CODEX_CONFIG"
  "$SPECAI_OPENCODE_CONFIG"
  "$SPECAI_ANTIGRAVITY_AGENT_DIR"
  "$SPECAI_CODEX_CACHE_ROOT"
  "$SPECAI_CONFIG_FILE"
  "$SPECAI_HARNESS_LIFECYCLE_FIXTURE"
  "$SPECAI_SOURCE_PLUGIN_MANIFEST"
  "$SPECAI_CODEX_MARKETPLACES"
  "$SPECAI_PERMISSION_TARGETS"
  "$SPECAI_CODEX_CLI_PATH"
  "$SPECAI_CODEX_CLI_HELP"
)
if "$JSON_MODE"; then
  args+=(--json)
fi

python3 - "${args[@]}" <<'PY'
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None

(
    repo_root,
    codex_config,
    opencode_config,
    antigravity_dir,
    cache_root,
    specai_config,
    lifecycle_fixture,
    source_manifest_path,
    marketplaces_path,
    permission_targets,
    codex_cli_path,
    codex_cli_help,
    *flags,
) = sys.argv[1:]
json_mode = flags == ["--json"]
repo = Path(repo_root)
expected_roles = {
    "implementer",
    "build-fixer",
    "code-reviewer",
    "verifier",
    "spec-compliance-reviewer",
    "specai-command",
    "specai-documentation",
}


def check(identifier: str, status: str, detail: str, action: str = "") -> dict[str, str]:
    return {"id": identifier, "status": status, "detail": detail, "action": action}


def read_json(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None
    return data if isinstance(data, dict) else None


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except (FileNotFoundError, OSError, UnicodeDecodeError):
        return None


def read_codex_features(path: Path) -> dict:
    try:
        raw = path.read_bytes()
    except OSError:
        return {}
    if tomllib is not None:
        try:
            data = tomllib.loads(raw.decode("utf-8"))
            features = data.get("features", {})
            return features if isinstance(features, dict) else {}
        except (tomllib.TOMLDecodeError, UnicodeDecodeError):
            return {}
    match = re.search(r"(?m)^\s*multi_agent\s*=\s*(true|false)\s*$", raw.decode("utf-8", "ignore"))
    return {"multi_agent": match.group(1) == "true"} if match else {}


def load_roles_from_agents(path: Path) -> set[str]:
    if not path.is_dir():
        return set()

    roles = set()
    for entry in path.glob("*.md"):
        if not entry.is_file():
            continue
        try:
            content = entry.read_text(encoding="utf-8")
        except OSError:
            continue
        frontmatter = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", content, re.DOTALL)
        if frontmatter and re.search(r"(?m)^subagent:\s*true\s*$", frontmatter.group(1)):
            roles.add(entry.stem)
    return roles


def lifecycle_checks(path: Path) -> list[dict[str, str]]:
    if not path:
        return []

    fixture = read_json(path)
    contract = read_json(repo / "scripts" / "agent-harness-contract.json")
    if fixture is None or contract is None:
        return [check("lifecycle", "PARTIAL", "lifecycle fixture or contract is missing or invalid")]

    policy = contract.get("policy", {})
    max_runtime = policy.get("maxRuntimeSeconds")
    if not isinstance(max_runtime, int):
        return [check("lifecycle", "PARTIAL", "lifecycle contract has no valid runtime deadline")]

    kind = fixture.get("kind")
    if kind == "missing_capability":
        if (
            fixture.get("available") is False
            and fixture.get("handoff") is False
            and fixture.get("inline_fallback") is False
        ):
            return [
                check(
                    "lifecycle",
                    "TASK_BLOCKED",
                    f"capability {fixture.get('capability', 'unknown')} unavailable; handoff not executed",
                )
            ]
        return [check("lifecycle", "PARTIAL", "missing capability fixture is not blocked before handoff")]

    if kind == "timed_out_poll":
        handle = fixture.get("handle")
        events = fixture.get("events")
        if not isinstance(handle, str) or not handle or not isinstance(events, list):
            return [check("lifecycle", "PARTIAL", "timed out fixture has no stable handle and event list")]

        checks: list[dict[str, str]] = []
        for event in events:
            if not isinstance(event, dict) or event.get("type") != "timed_out":
                checks.append(check("lifecycle", "PARTIAL", "unexpected lifecycle event in timed out fixture"))
                continue
            elapsed = event.get("elapsedSeconds")
            if not isinstance(elapsed, int) or elapsed < 0:
                checks.append(check("lifecycle", "PARTIAL", f"invalid elapsed time for handle {handle}"))
            elif elapsed < max_runtime:
                checks.append(
                    check(
                        "lifecycle.poll",
                        "POLLING",
                        f"timed_out at {elapsed}s; retaining handle {handle}",
                    )
                )
            elif elapsed == max_runtime:
                checks.append(
                    check(
                        "lifecycle.deadline",
                        "DEADLINE_EXCEEDED",
                        f"deadline reached at {elapsed}s; terminal handle {handle}",
                    )
                )
            else:
                checks.append(
                    check(
                        "lifecycle",
                        "PARTIAL",
                        f"deadline exceeded without terminal transition at {elapsed}s",
                    )
                )
        return checks or [check("lifecycle", "PARTIAL", "timed out fixture has no events")]

    return [check("lifecycle", "PARTIAL", f"unsupported lifecycle fixture kind: {kind}")]


def package_root(manifest_path: Path) -> Path:
    return manifest_path.parent.parent if manifest_path.parent.name == ".codex-plugin" else manifest_path.parent


def content_snapshot(manifest: dict, root: Path) -> dict[str, dict[str, str]]:
    inline = manifest.get("contents")
    if isinstance(inline, dict):
        return {
            kind: value if isinstance(value, dict) else {}
            for kind, value in (("commands", inline.get("commands")), ("skills", inline.get("skills")))
        }

    snapshot: dict[str, dict[str, str]] = {}
    for kind in ("commands", "skills"):
        files: dict[str, str] = {}
        root_path = root / kind
        if root_path.is_dir():
            for entry in sorted(root_path.rglob("*")):
                if entry.is_file():
                    content = read_text(entry)
                    if content is not None:
                        files[str(entry.relative_to(root_path))] = content
        snapshot[kind] = files
    return snapshot


def manifest_without_contents(manifest: dict) -> dict:
    return {key: value for key, value in manifest.items() if key != "contents"}


def cache_manifests(path: Path) -> list[tuple[Path, dict]]:
    if not path.is_dir():
        return []

    manifests: list[tuple[Path, dict]] = []
    for manifest_path in sorted(path.rglob("plugin.json")):
        cached = read_json(manifest_path)
        if cached and cached.get("name") == "specai":
            manifests.append((manifest_path, cached))
    return manifests


def cache_checks(source: dict | None, source_path: Path, path: Path) -> list[dict[str, str]]:
    cached = cache_manifests(path)
    action = "refresh the configured Codex marketplace and reinstall specai"
    if not cached:
        detail = "specai cache not found"
        return [
            check("codex.cache.version", "WARN", detail, action),
            check("codex.cache.manifest", "WARN", detail, action),
            check("codex.cache.commands", "WARN", detail, action),
            check("codex.cache.skills", "WARN", detail, action),
            check("codex.cache", "WARN", detail, action),
        ]

    source_version = source.get("version") if source else None
    versions = sorted({str(manifest.get("version")) for _, manifest in cached if manifest.get("version")})
    if source_version is not None and str(source_version) in versions:
        version_check = check("codex.cache.version", "OK", f"version {source_version} present")
    else:
        version_check = check(
            "codex.cache.version",
            "WARN",
            f"source version {source_version}; cached versions {versions}",
            action,
        )

    if source is None:
        manifest_check = check("codex.cache.manifest", "PARTIAL", "source plugin manifest is missing or invalid")
        commands_check = check("codex.cache.commands", "PARTIAL", "source plugin manifest is missing or invalid")
        skills_check = check("codex.cache.skills", "PARTIAL", "source plugin manifest is missing or invalid")
    else:
        matching = [
            (manifest_path, manifest)
            for manifest_path, manifest in cached
            if str(manifest.get("version")) == str(source_version)
        ]
        if not matching:
            detail = f"no cached specai manifest for source version {source_version}; cached versions {versions}"
            manifest_check = check("codex.cache.manifest", "WARN", detail, action)
            commands_check = check("codex.cache.commands", "WARN", detail, action)
            skills_check = check("codex.cache.skills", "WARN", detail, action)
        else:
            source_contents = content_snapshot(source, package_root(source_path))
            manifest_drifts: list[str] = []
            command_drifts: list[str] = []
            skill_drifts: list[str] = []
            for manifest_path, cached_manifest in matching:
                manifest_label = str(manifest_path)
                if manifest_without_contents(source) != manifest_without_contents(cached_manifest):
                    manifest_drifts.append(manifest_label)
                cached_contents = content_snapshot(cached_manifest, package_root(manifest_path))
                if source_contents["commands"] != cached_contents["commands"]:
                    command_drifts.append(manifest_label)
                if source_contents["skills"] != cached_contents["skills"]:
                    skill_drifts.append(manifest_label)

            if manifest_drifts:
                manifest_check = check(
                    "codex.cache.manifest",
                    "WARN",
                    f"cached plugin manifest differs from the source in: {', '.join(manifest_drifts)}",
                    action,
                )
            else:
                manifest_check = check("codex.cache.manifest", "OK", "all cached plugin manifests match the source manifest")
            if command_drifts:
                commands_check = check(
                    "codex.cache.commands",
                    "WARN",
                    f"cached commands content differs from the source in: {', '.join(command_drifts)}",
                    action,
                )
            else:
                commands_check = check("codex.cache.commands", "OK", "all cached commands content matches the source")
            if skill_drifts:
                skills_check = check(
                    "codex.cache.skills",
                    "WARN",
                    f"cached skills content differs from the source in: {', '.join(skill_drifts)}",
                    action,
                )
            else:
                skills_check = check("codex.cache.skills", "OK", "all cached skills content matches the source")

    child_checks = [manifest_check, commands_check, skills_check]
    if any(item["status"] == "PARTIAL" for item in child_checks):
        aggregate_status = "PARTIAL"
    elif any(item["status"] == "WARN" for item in [version_check, *child_checks]):
        aggregate_status = "WARN"
    else:
        aggregate_status = "OK"
    aggregate_detail = "cache version, manifest, commands, and skills checks passed"
    if aggregate_status != "OK":
        aggregate_detail = "one or more cache checks require attention"
    return [version_check, manifest_check, commands_check, skills_check, check("codex.cache", aggregate_status, aggregate_detail, action)]


def marketplace_plugins(data: dict) -> list[tuple[dict, dict]]:
    marketplaces = data.get("marketplaces", [])
    if isinstance(marketplaces, dict):
        marketplaces = list(marketplaces.values())
    if not isinstance(marketplaces, list):
        return []

    found: list[tuple[dict, dict]] = []
    for marketplace in marketplaces:
        if not isinstance(marketplace, dict):
            continue
        plugins = marketplace.get("plugins", [])
        if isinstance(plugins, dict):
            plugins = list(plugins.values())
        if not isinstance(plugins, list):
            continue
        for plugin in plugins:
            if isinstance(plugin, dict) and plugin.get("name") == "specai":
                found.append((marketplace, plugin))
    return found


def projection_values(projection: dict, kind: str) -> list[str] | None:
    value = projection.get(kind)
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        return None
    return value


def marketplace_checks(source: dict | None, source_path: Path, path: Path, repo: Path) -> list[dict[str, str]]:
    data = read_json(path)
    action = "associate the installed specai projection with this source checkout"
    if data is None:
        return [
            check("codex.marketplace.association", "WARN", "Codex marketplace association not found", action),
            check("codex.marketplace.projection", "WARN", "Codex marketplace projection not found", action),
        ]

    plugins = marketplace_plugins(data)
    if not plugins:
        return [
            check("codex.marketplace.association", "WARN", "specai is not associated with a Codex marketplace", action),
            check("codex.marketplace.projection", "WARN", "specai projection is not registered in a Codex marketplace", action),
        ]

    marketplace_path = path.parent
    source_root = package_root(source_path).resolve()
    _, plugin = plugins[0]
    source_ref = plugin.get("source", {})
    local_path = source_ref.get("path") if isinstance(source_ref, dict) else None
    associated_path = (marketplace_path / local_path).resolve() if isinstance(local_path, str) else None
    if associated_path == source_root:
        association = check(
            "codex.marketplace.association",
            "OK",
            f"specai marketplace association points to {source_root}",
        )
    else:
        association = check(
            "codex.marketplace.association",
            "WARN",
            f"specai marketplace association is detached: {associated_path or 'no local source'}",
            action,
        )

    projection = plugin.get("projection")
    if not isinstance(projection, dict):
        return [association, check("codex.marketplace.projection", "WARN", "Codex marketplace projection is missing", action)]

    if source is None:
        expected = {"commands": [], "skills": []}
    else:
        contents = content_snapshot(source, package_root(source_path))
        expected = {
            "commands": [Path(name).stem for name in contents["commands"]],
            "skills": [Path(name).parts[0] for name in contents["skills"]],
        }
    actual = {kind: projection_values(projection, kind) for kind in ("commands", "skills")}
    invalid = [kind for kind in ("commands", "skills") if actual[kind] is None]
    mismatches = [
        kind
        for kind in ("commands", "skills")
        if kind not in invalid and sorted(expected[kind]) != sorted(actual[kind] or [])
    ]
    if invalid:
        projection_check = check(
            "codex.marketplace.projection",
            "WARN",
            f"invalid projection shape for: {', '.join(invalid)}; expected lists of strings",
            action,
        )
    elif mismatches:
        projection_check = check(
            "codex.marketplace.projection",
            "WARN",
            f"projection differs for: {', '.join(mismatches)}",
            action,
        )
    else:
        projection_check = check("codex.marketplace.projection", "OK", "Codex marketplace projection matches the source")
    return [association, projection_check]


def permission_checks(targets: str) -> list[dict[str, str]]:
    paths = [Path(value) for value in targets.split(":") if value]
    readonly: list[str] = []
    missing: list[str] = []
    for path in paths:
        try:
            mode = path.stat().st_mode
        except OSError:
            missing.append(str(path))
            continue
        if mode & 0o222 == 0:
            readonly.append(str(path))
    if readonly:
        return [
            check(
                "permissions",
                "WARN",
                f"read-only path(s): {', '.join(readonly)}; doctor made no changes",
                "review permissions manually; doctor is read-only",
            )
        ]
    if missing:
        return [check("permissions", "WARN", f"permission target(s) not found: {', '.join(missing)}", "review configured paths")]
    return [check("permissions", "OK", "configured permission targets are readable")]


def cli_checks(path: str, help_path: str) -> list[dict[str, str]]:
    cli = Path(path) if path else None
    if cli is None:
        found = shutil.which("codex")
        cli = Path(found) if found else None
    if cli is None:
        cli_check = check("codex.cli", "WARN", "codex CLI not found", "install or expose codex in PATH")
        form_check = check("cli.form", "WARN", "codex CLI form cannot be inspected without an executable", "provide codex --help output")
        alias_check = check("path.alias", "WARN", "PATH alias cannot be reported without codex in PATH", "expose codex in PATH")
        return [cli_check, form_check, alias_check]

    if not cli.is_file() or cli.stat().st_mode & 0o111 == 0:
        if not cli.exists():
            reason = "does not exist"
        elif not cli.is_file():
            reason = "is not a regular file"
        else:
            reason = "is not executable"
        action = "configure an existing executable codex CLI path"
        detail = f"configured codex CLI path {cli} {reason}"
        return [
            check("codex.cli", "WARN", detail, action),
            check("cli.form", "WARN", f"cannot inspect CLI form: {detail}", "provide help output from an executable codex CLI"),
            check("path.alias", "WARN", f"PATH alias cannot be resolved: {detail}", action),
        ]

    cli_check = check("codex.cli", "OK", f"codex CLI available at {cli}")
    help_text = read_text(Path(help_path)) if help_path else None
    if help_text is None:
        form_check = check(
            "cli.form",
            "WARN",
            "codex CLI is present but its --help form was not inspected",
            "capture codex --help output for form validation",
        )
    elif re.search(r"(?m)^\s*(?:Usage:\s*)?codex\s+plugin\s+marketplace\s+add(?:\s|$)", help_text):
        form_check = check("cli.form", "OK", "codex CLI help exposes `codex plugin marketplace add`")
    else:
        form_check = check(
            "cli.form",
            "WARN",
            "unsupported codex CLI form: help does not expose plugin marketplace commands",
            "use a Codex CLI with plugin marketplace support",
        )

    resolved = cli.resolve()
    if cli.is_symlink() or cli.name != "codex":
        alias_check = check("path.alias", "OK", f"PATH alias: {cli.name} -> {resolved}")
    else:
        alias_check = check("path.alias", "OK", f"PATH alias: none; codex resolves to {resolved}")
    return [cli_check, form_check, alias_check]


checks: list[dict[str, str]] = []
source_manifest = Path(source_manifest_path)
manifest = read_json(source_manifest)
if manifest is None:
    checks.append(check("source.plugin", "FAIL", "source plugin manifest is missing or invalid", "repair the source checkout"))
else:
    version = manifest.get("version", "unknown")
    skills = list((package_root(source_manifest) / "skills").glob("*/SKILL.md"))
    checks.append(check("source.plugin", "OK", f"version {version}, {len(skills)} skills"))

codex_features = read_codex_features(Path(codex_config))
if codex_features.get("multi_agent") is True:
    checks.append(check("codex.multi_agent", "OK", "multi_agent=true"))
else:
    checks.append(check(
        "codex.multi_agent",
        "TASK_BLOCKED",
        "multi_agent is not enabled",
        "add [features] multi_agent = true to the Codex configuration and restart Codex",
    ))

opencode = read_json(Path(opencode_config))
opencode_roles = set(opencode.get("agent", {})) if opencode else set()
if opencode_roles == expected_roles:
    checks.append(check("opencode.roles", "OK", "seven canonical roles registered"))
else:
    checks.append(check(
        "opencode.roles",
        "FAIL",
        f"registered roles: {len(opencode_roles)}, expected: {len(expected_roles)}",
        "run bash scripts/setup-agents.sh",
    ))

antigravity_roles = load_roles_from_agents(Path(antigravity_dir))
if antigravity_roles == expected_roles:
    checks.append(check("antigravity.roles", "OK", "seven canonical roles available"))
else:
    checks.append(check(
        "antigravity.roles",
        "FAIL",
        f"available roles: {len(antigravity_roles)}, expected: {len(expected_roles)}",
        "run ./specai install or sync the Antigravity plugin",
    ))

checks.extend(cli_checks(codex_cli_path, codex_cli_help))

if shutil.which("opencode"):
    checks.append(check("opencode.cli", "OK", "opencode CLI available"))
else:
    checks.append(check("opencode.cli", "WARN", "opencode CLI not found", "install or expose opencode in PATH"))

if shutil.which("agy"):
    checks.append(check("antigravity.cli", "OK", "agy CLI available"))
else:
    checks.append(check("antigravity.cli", "WARN", "agy CLI not found", "install or expose agy in PATH"))

checks.extend(cache_checks(manifest, source_manifest, Path(cache_root)))
checks.extend(marketplace_checks(manifest, source_manifest, Path(marketplaces_path), repo))
checks.extend(permission_checks(permission_targets))

spec_config = read_json(Path(specai_config))
roster = read_json(repo / "scripts" / "agent-roster.json") or {}
defaults = {agent.get("name"): agent.get("defaultModel") for agent in roster.get("agents", [])}
configured = spec_config.get("agentModels", {}) if spec_config else {}
override_count = sum(1 for name, model in configured.items() if name in defaults and model != defaults[name])
unknown_count = sum(1 for name in configured if name not in defaults)
if override_count or unknown_count:
    checks.append(check(
        "models.drift",
        "WARN",
        f"{override_count} roster override(s), {unknown_count} unknown role override(s)",
        "review ~/.config/specai/config.json against scripts/agent-roster.json",
    ))
else:
    checks.append(check("models.drift", "OK", "configured models match the canonical roster"))

if lifecycle_fixture:
    checks.extend(lifecycle_checks(Path(lifecycle_fixture)))

if any(item["status"] in {"FAIL", "TASK_BLOCKED", "PARTIAL"} for item in checks):
    overall = "FAIL"
elif any(item["status"] == "WARN" for item in checks):
    overall = "WARN"
else:
    overall = "OK"

payload = {"overall": overall, "checks": checks}
if json_mode:
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
else:
    print(f"SPECAI_HARNESS_STATUS: {overall}")
    for item in checks:
        print(f"SPECAI_HARNESS_{item['status']}: {item['id']} — {item['detail']}")
        if item.get("action"):
            print(f"  Action: {item['action']}")

raise SystemExit({"OK": 0, "WARN": 1, "FAIL": 2}[overall])
PY
