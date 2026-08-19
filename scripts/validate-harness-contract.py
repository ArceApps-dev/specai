#!/usr/bin/env python3
"""Validate the canonical native-subagent harness contract."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


EXPECTED_ROLES = {
    "implementer",
    "build-fixer",
    "code-reviewer",
    "verifier",
    "spec-compliance-reviewer",
    "specai-command",
    "specai-documentation",
}
EXPECTED_HARNESSES = {"opencode", "codex", "antigravity"}
REQUIRED_CAPABILITIES = {"fresh_session", "isolated_context", "terminal_state"}
OBSERVABLE_STATES = [
    "TASK_BLOCKED",
    "POLLING",
    "DEADLINE_EXCEEDED",
    "PARTIAL",
]
EXPECTED_LIFECYCLE = {
    "timed_out": {
        "state": "POLLING",
        "terminal": False,
        "retain_handle": True,
    },
    "deadline": {
        "state": "DEADLINE_EXCEEDED",
        "terminal": True,
        "at_seconds": 900,
    },
    "missing_capability": {
        "state": "TASK_BLOCKED",
        "handoff": False,
        "inline_fallback": False,
    },
}


def load_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"missing JSON file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {path}: {exc.msg}") from exc


def validate_contract(contract: dict) -> None:
    if contract.get("version") != 1:
        raise ValueError("contract version must be 1")

    policy = contract.get("policy")
    expected_policy = {
        "maxRuntimeSeconds": 900,
        "pollIntervalSeconds": 15,
        "heartbeatIntervalSeconds": 30,
    }
    if policy != expected_policy:
        raise ValueError(f"policy must equal {expected_policy}")

    if contract.get("forbid_inline") is not True:
        raise ValueError("forbid_inline must be true")
    if contract.get("observableStates") != OBSERVABLE_STATES:
        raise ValueError(f"observableStates must equal {OBSERVABLE_STATES}")
    if contract.get("lifecycle") != EXPECTED_LIFECYCLE:
        raise ValueError(f"lifecycle must equal {EXPECTED_LIFECYCLE}")

    capabilities = set(contract.get("requiredCapabilities", []))
    if capabilities != REQUIRED_CAPABILITIES:
        raise ValueError("requiredCapabilities must contain the three lifecycle capabilities")

    harnesses = contract.get("harnesses")
    if not isinstance(harnesses, dict) or set(harnesses) != EXPECTED_HARNESSES:
        raise ValueError("harnesses must contain exactly opencode, codex and antigravity")

    for name in EXPECTED_HARNESSES:
        declared = set(harnesses[name].get("capabilities", []))
        if not REQUIRED_CAPABILITIES.issubset(declared):
            raise ValueError(f"{name} is missing a required lifecycle capability")

    if harnesses["opencode"].get("dispatch") != "delegate":
        raise ValueError("opencode dispatch must be delegate")

    codex = harnesses["codex"]
    if {
        codex.get("dispatch"),
        codex.get("poll"),
        codex.get("close"),
    } != {"spawn_agent", "wait_agent", "close_agent"}:
        raise ValueError("codex must declare spawn_agent, wait_agent and close_agent")
    if "multi_agent" not in codex.get("capabilities", []):
        raise ValueError("codex must require multi_agent")

    antigravity = harnesses["antigravity"]
    if antigravity.get("dispatch") != "invoke_subagent":
        raise ValueError("antigravity dispatch must be invoke_subagent")
    if antigravity.get("agentDirectory") != ".antigravity-plugin/agents":
        raise ValueError("antigravity agentDirectory must be .antigravity-plugin/agents")


def validate_roster(roster: dict) -> None:
    agents = roster.get("agents")
    if not isinstance(agents, list):
        raise ValueError("roster must contain an agents array")
    names = [agent.get("name") for agent in agents]
    if set(names) != EXPECTED_ROLES or len(names) != len(EXPECTED_ROLES):
        raise ValueError("roster must contain exactly the seven canonical roles")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("contract", type=Path)
    parser.add_argument("--roster", type=Path)
    args = parser.parse_args(argv)

    try:
        contract = load_json(args.contract)
        if not isinstance(contract, dict):
            raise ValueError("contract root must be an object")
        validate_contract(contract)
        if args.roster:
            roster = load_json(args.roster)
            if not isinstance(roster, dict):
                raise ValueError("roster root must be an object")
            validate_roster(roster)
    except ValueError as exc:
        print(f"harness contract: FAIL: {exc}", file=sys.stderr)
        return 1

    print("HARNESS_CONTRACT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
