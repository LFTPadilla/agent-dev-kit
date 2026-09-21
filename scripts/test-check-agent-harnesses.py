#!/usr/bin/env python3
"""Tests for scripts/check-agent-harnesses.py."""

from __future__ import annotations

import importlib.util
import io
import json
import subprocess
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "check_agent_harnesses", Path(__file__).with_name("check-agent-harnesses.py")
)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)


def completed(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(
        args=[], returncode=returncode, stdout=stdout, stderr=stderr
    )


class CheckHarnessTests(unittest.TestCase):
    def test_found_returns_ok_with_path_and_version(self):
        with (
            patch.object(mod.shutil, "which", return_value="/usr/bin/pi"),
            patch.object(
                mod.subprocess,
                "run",
                return_value=completed(stdout="\npi 1.2.3\nother\n"),
            ),
        ):
            result = mod.check_harness("pi", ["pi", "--help"])
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["path"], "/usr/bin/pi")
        self.assertEqual(result["version"], "pi 1.2.3")
        self.assertIsNone(result["error"])

    def test_missing_binary_returns_error_without_subprocess(self):
        with (
            patch.object(mod.shutil, "which", return_value=None),
            patch.object(mod.subprocess, "run") as run,
        ):
            result = mod.check_harness("dsh", ["dsh", "-V"])
        run.assert_not_called()
        self.assertEqual(result["status"], "error")
        self.assertIsNone(result["path"])
        self.assertIsNone(result["version"])
        self.assertEqual(result["error"], "not found on PATH")

    def test_nonzero_exit_returns_error(self):
        with (
            patch.object(mod.shutil, "which", return_value="/usr/bin/dsh"),
            patch.object(
                mod.subprocess,
                "run",
                return_value=completed(returncode=2, stderr="boom"),
            ),
        ):
            result = mod.check_harness("dsh", ["dsh", "-V"])
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["path"], "/usr/bin/dsh")
        self.assertEqual(result["error"], "boom")

    def test_timeout_returns_error(self):
        with (
            patch.object(mod.shutil, "which", return_value="/usr/bin/pi"),
            patch.object(
                mod.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired(cmd="pi", timeout=10.0),
            ),
        ):
            result = mod.check_harness("pi", ["pi", "--help"])
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["path"], "/usr/bin/pi")
        self.assertIn("timed out", result["error"])

    def test_all_ok_returns_ok(self):
        def fake_check(name, command, timeout=10.0):
            return {
                "name": name,
                "status": "ok",
                "path": "/x",
                "version": "1",
                "error": None,
            }

        with patch.object(mod, "check_harness", side_effect=fake_check):
            payload = mod.check_all_harnesses()
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(set(payload["harnesses"]), {"pi", "dsh"})

    def test_any_error_propagates_to_overall_status(self):
        def fake_check(name, command, timeout=10.0):
            status = "error" if name == "dsh" else "ok"
            return {
                "name": name,
                "status": status,
                "path": None,
                "version": None,
                "error": "nope" if status == "error" else None,
            }

        with patch.object(mod, "check_harness", side_effect=fake_check):
            payload = mod.check_all_harnesses()
        self.assertEqual(payload["status"], "error")
        self.assertEqual(payload["harnesses"]["dsh"]["status"], "error")

    def test_main_prints_json_and_returns_0(self):
        with patch.object(
            mod, "check_all_harnesses", return_value={"status": "ok", "harnesses": {}}
        ):
            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = mod.main([])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(buf.getvalue()), {"status": "ok", "harnesses": {}})

    def test_main_returns_1_on_error(self):
        with patch.object(
            mod,
            "check_all_harnesses",
            return_value={"status": "error", "harnesses": {}},
        ):
            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = mod.main([])
        self.assertEqual(rc, 1)
        self.assertEqual(json.loads(buf.getvalue())["status"], "error")


if __name__ == "__main__":
    unittest.main()
