#!/usr/bin/env python3
"""Tests for agent-sessions.py. No live Herdr server is required."""

from __future__ import annotations

import importlib.util
import io
import json
import subprocess
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "agent_sessions", Path(__file__).with_name("agent-sessions.py")
)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

LISTING = {
    "id": "cli:agent:list",
    "result": {
        "type": "agent_list",
        "agents": [
            {
                "agent": "hermes",
                "agent_session": {"agent": "hermes", "kind": "id", "value": "20260101_000000_aaaaaa"},
                "agent_status": "idle",
                "cwd": "/home/example/project",
                "focused": True,
                "pane_id": "w1:p1",
                "workspace_id": "w1",
            },
            {
                "agent": "codex",
                "agent_session": {"agent": "codex", "kind": "id", "value": "bbbbbb"},
                "agent_status": "working",
                "cwd": "/home/example/other",
                "focused": False,
                "pane_id": "w2:p7",
                "workspace_id": "w2",
            },
        ],
    },
}


def completed(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


class FetchAgentsTests(unittest.TestCase):
    def test_returns_the_agent_list(self):
        with patch.object(mod.subprocess, "run", return_value=completed(stdout=json.dumps(LISTING))):
            agents = mod.fetch_agents("herdr")
        self.assertEqual([a["agent"] for a in agents], ["hermes", "codex"])

    def test_failed_command_raises_with_stderr(self):
        with patch.object(
            mod.subprocess, "run", return_value=completed(returncode=1, stderr="no server")
        ):
            with self.assertRaises(RuntimeError) as caught:
                mod.fetch_agents("herdr")
        self.assertIn("no server", str(caught.exception))

    def test_unexpected_json_raises(self):
        with patch.object(mod.subprocess, "run", return_value=completed(stdout='{"result":{}}')):
            with self.assertRaises(RuntimeError):
                mod.fetch_agents("herdr")

    def test_missing_binary_raises_oserror(self):
        with patch.object(mod.subprocess, "run", side_effect=FileNotFoundError("herdr")):
            with self.assertRaises(OSError):
                mod.fetch_agents("herdr")


class RowTests(unittest.TestCase):
    def test_keeps_harness_state_and_location(self):
        item = mod.row(LISTING["result"]["agents"][0])
        self.assertEqual(item["harness"], "hermes")
        self.assertEqual(item["state"], "idle")
        self.assertEqual(item["workspace"], "w1")
        self.assertEqual(item["pane"], "w1:p1")
        self.assertEqual(item["cwd"], "/home/example/project")
        self.assertEqual(item["session"], "20260101_000000_aaaaaa")
        self.assertTrue(item["focused"])

    def test_survives_missing_fields(self):
        item = mod.row({})
        self.assertEqual(item["harness"], "unknown")
        self.assertEqual(item["state"], "unknown")
        self.assertEqual(item["cwd"], "")
        self.assertFalse(item["focused"])


class SummaryTests(unittest.TestCase):
    def test_counts_by_harness_and_state(self):
        rows = [mod.row(agent) for agent in LISTING["result"]["agents"]]
        summary = mod.summarize(rows)
        self.assertEqual(summary["total"], 2)
        self.assertEqual(summary["by_harness"], {"codex": 1, "hermes": 1})
        self.assertEqual(summary["by_state"], {"idle": 1, "working": 1})

    def test_empty_without_sessions(self):
        summary = mod.summarize([])
        self.assertEqual(summary["total"], 0)
        self.assertEqual(summary["by_harness"], {})
        self.assertEqual(summary["by_state"], {})

    def test_orders_states_by_activity(self):
        rows = [mod.row({"agent": "hermes", "agent_status": state}) for state in ("idle", "working")]
        summary = mod.summarize(rows)
        self.assertEqual(list(summary["by_state"]), ["working", "idle"])


class TableTests(unittest.TestCase):
    def test_lists_state_harness_and_cwd(self):
        rows = [mod.row(agent) for agent in LISTING["result"]["agents"]]
        table = mod.format_table(rows)
        self.assertTrue(table.startswith("2 sessions"))
        self.assertIn("hermes", table)
        self.assertIn("/home/example/project", table)
        self.assertIn("harness: codex 1, hermes 1", table)
        self.assertIn("state: working 1, idle 1", table)

    def test_reports_zero_sessions(self):
        self.assertEqual(mod.format_table([]), "0 sessions")

    def test_working_row_comes_first(self):
        rows = [mod.row(agent) for agent in LISTING["result"]["agents"]]
        body = mod.format_table(rows).splitlines()[1]
        self.assertTrue(body.startswith("working"))


class MainTests(unittest.TestCase):
    def test_prints_json_and_exits_zero(self):
        stdout = io.StringIO()
        with (
            patch.object(mod.subprocess, "run", return_value=completed(stdout=json.dumps(LISTING))),
            redirect_stdout(stdout),
        ):
            code = mod.main(["--format", "json", "--herdr", "herdr"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout.getvalue())["summary"]["total"], 2)

    def test_reports_a_missing_herdr(self):
        stderr = io.StringIO()
        with (
            patch.object(mod.subprocess, "run", side_effect=FileNotFoundError("herdr")),
            redirect_stderr(stderr),
        ):
            code = mod.main(["--herdr", "herdr"])
        self.assertEqual(code, 1)
        self.assertIn("cannot read herdr agent list", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
