#!/usr/bin/env python3
"""List running coding agent sessions and their harness from Herdr.

The script reads one Herdr command, `herdr agent list`, and prints one line for
each live agent session. It never starts, stops, or controls an agent.

Usage:
    agent-sessions.py [--format table|json] [--herdr PATH]
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys

# The order in which states are reported. Work that runs or waits comes first.
STATE_ORDER = ("working", "blocked", "idle", "done", "unknown")


def fetch_agents(herdr: str, timeout: float = 10.0) -> list[dict]:
    """Run `herdr agent list` and return the agent objects."""
    result = subprocess.run(
        [herdr, "agent", "list"],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"exit code {result.returncode}")
    payload = json.loads(result.stdout)
    agents = payload.get("result", {}).get("agents")
    if not isinstance(agents, list):
        raise RuntimeError("unexpected JSON: result.agents is not a list")
    return agents


def row(agent: dict) -> dict:
    """Reduce one Herdr agent object to the fields a monitor needs."""
    session = agent.get("agent_session") or {}
    return {
        "harness": agent.get("agent") or "unknown",
        "state": agent.get("agent_status") or "unknown",
        "workspace": agent.get("workspace_id") or "",
        "pane": agent.get("pane_id") or "",
        "cwd": agent.get("cwd") or "",
        "session": session.get("value") or "",
        "focused": bool(agent.get("focused")),
    }


def sort_key(item: dict) -> tuple:
    state = item["state"]
    rank = STATE_ORDER.index(state) if state in STATE_ORDER else len(STATE_ORDER)
    return (item["harness"], rank, item["workspace"], item["pane"])


def summarize(rows: list[dict]) -> dict:
    """Count sessions by harness and by state."""
    by_harness: dict[str, int] = {}
    by_state: dict[str, int] = {}
    for item in rows:
        by_harness[item["harness"]] = by_harness.get(item["harness"], 0) + 1
        by_state[item["state"]] = by_state.get(item["state"], 0) + 1
    ordered_states = {
        state: by_state[state] for state in STATE_ORDER if state in by_state
    }
    for state, count in by_state.items():
        if state not in ordered_states:
            ordered_states[state] = count
    return {
        "total": len(rows),
        "by_harness": dict(sorted(by_harness.items())),
        "by_state": ordered_states,
    }


def counts(counts_by_key: dict[str, int]) -> str:
    return ", ".join(f"{key} {value}" for key, value in counts_by_key.items())


def format_table(rows: list[dict]) -> str:
    ordered = sorted(rows, key=sort_key)
    summary = summarize(ordered)
    lines = [f"{summary['total']} sessions"]
    if ordered:
        width = max(5, max(len(item["state"]) for item in ordered))
        for item in ordered:
            lines.append(
                f"{item['state']:<{width}}  {item['harness']:<10}  "
                f"{item['workspace']:<4}  {item['pane']:<8}  {item['cwd']}"
            )
        lines.append("")
        lines.append(f"harness: {counts(summary['by_harness'])}")
        lines.append(f"state: {counts(summary['by_state'])}")
    return "\n".join(lines)


def format_json(rows: list[dict]) -> str:
    ordered = sorted(rows, key=sort_key)
    payload = {"summary": summarize(ordered), "sessions": ordered}
    return json.dumps(payload, indent=2, sort_keys=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="List running coding agent sessions.")
    parser.add_argument(
        "--format",
        choices=("table", "json"),
        default="table",
        help="output format (default: table)",
    )
    parser.add_argument(
        "--herdr",
        default=None,
        help="herdr binary to run (default: herdr on PATH)",
    )
    args = parser.parse_args(argv)

    herdr = args.herdr or shutil.which("herdr") or "herdr"
    try:
        agents = fetch_agents(herdr)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
        print(f"error: cannot read herdr agent list: {exc}", file=sys.stderr)
        return 1

    rows = [row(agent) for agent in agents]
    if args.format == "json":
        print(format_json(rows))
    else:
        print(format_table(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
