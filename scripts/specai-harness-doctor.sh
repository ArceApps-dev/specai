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

args=(
  "$REPO_ROOT"
  "$SPECAI_CODEX_CONFIG"
  "$SPECAI_OPENCODE_CONFIG"
  "$SPECAI_ANTIGRAVITY_AGENT_DIR"
  "$SPECAI_CODEX_CACHE_ROOT"
  "$SPECAI_CONFIG_FILE"
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

repo_root, codex_config, opencode_config, antigravity_dir, cache_root, specai_config, *flags = sys.argv[1:]
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
    result = {"id": identifier, "status": status, "detail": detail}
    if action:
        result["action"] = action
    return result


def read_json(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None
    return data if isinstance(data, dict) else None


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
    return {entry.stem for entry in path.glob("*.md") if entry.is_file()}


checks: list[dict[str, str]] = []
manifest = read_json(repo / ".codex-plugin" / "plugin.json")
if manifest is None:
    checks.append(check("source.plugin", "FAIL", "source plugin manifest is missing or invalid", "repair the source checkout"))
else:
    version = manifest.get("version", "unknown")
    skills = list((repo / "skills").glob("*/SKILL.md"))
    checks.append(check("source.plugin", "OK", f"version {version}, {len(skills)} skills"))

codex_features = read_codex_features(Path(codex_config))
if codex_features.get("multi_agent") is True:
    checks.append(check("codex.multi_agent", "OK", "multi_agent=true"))
else:
    checks.append(check(
        "codex.multi_agent",
        "FAIL",
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

if shutil.which("codex"):
    checks.append(check("codex.cli", "OK", "codex CLI available"))
else:
    checks.append(check("codex.cli", "WARN", "codex CLI not found", "install or expose codex in PATH"))

if shutil.which("opencode"):
    checks.append(check("opencode.cli", "OK", "opencode CLI available"))
else:
    checks.append(check("opencode.cli", "WARN", "opencode CLI not found", "install or expose opencode in PATH"))

if shutil.which("agy"):
    checks.append(check("antigravity.cli", "OK", "agy CLI available"))
else:
    checks.append(check("antigravity.cli", "WARN", "agy CLI not found", "install or expose agy in PATH"))

source_version = manifest.get("version") if manifest else None
cached_versions: set[str] = set()
cache_path = Path(cache_root)
if cache_path.is_dir():
    manifest_paths = set(cache_path.glob("*/*/plugin.json"))
    manifest_paths.update(cache_path.rglob(".codex-plugin/plugin.json"))
    for plugin_manifest in sorted(manifest_paths):
        cached = read_json(plugin_manifest)
        if cached and cached.get("name") == "specai" and cached.get("version"):
            cached_versions.add(str(cached["version"]))
if not cached_versions:
    checks.append(check("codex.cache", "WARN", "specai cache not found", "refresh the configured Codex marketplace"))
elif source_version not in cached_versions:
    checks.append(check(
        "codex.cache",
        "WARN",
        f"source version {source_version}; cached versions {sorted(cached_versions)}",
        "refresh the configured Codex marketplace and reinstall specai",
    ))
else:
    checks.append(check("codex.cache", "OK", f"version {source_version} present"))

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

if any(item["status"] == "FAIL" for item in checks):
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
