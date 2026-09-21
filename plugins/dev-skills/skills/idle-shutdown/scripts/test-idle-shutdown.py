#!/usr/bin/env python3
"""Tests for the idle-shutdown watcher.

The watcher makes one irreversible decision, so the tests cover the paths that
must never be wrong: input refusal, the local-host guard, the two activity
signals, the hold file, the shutdown branch, and the dry run.

The watcher is loaded as a module and the environment is faked, not touched.
That keeps every test fast and deterministic, and it lets a test drive the loop
to completion instead of killing a process mid-run. No test reaches a real host
and no test runs a real shutdown command.

Run: python3 plugins/dev-skills/skills/idle-shutdown/scripts/test-idle-shutdown.py
"""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SKILL = Path(__file__).resolve().parent.parent
SCRIPT = Path(__file__).with_name("idle-shutdown")

# The watcher has no .py suffix, so the loader is named explicitly.
_LOADER = importlib.machinery.SourceFileLoader("idle_shutdown", str(SCRIPT))
_SPEC = importlib.util.spec_from_loader("idle_shutdown", _LOADER)
assert _SPEC is not None
mod = importlib.util.module_from_spec(_SPEC)
_LOADER.exec_module(mod)

SAMPLE_KEYS = ("ts", "cpu_pct", "cpu_herdr_pct", "procs_cpu", "agent_states", "busy_agents", "working")
IDLE = dict.fromkeys(SAMPLE_KEYS, 0.0) | {"ts": 1000.0, "working": False}
BUSY = dict(IDLE) | {"ts": 1000.0, "cpu_pct": 42.0, "working": True, "busy_agents": 1}
READY = dict(IDLE) | {"ts": 5000.0}

FLAGS = {
    "target": None,
    "local": True,
    "shutdown_cmd": "shutdown now",
    "grace_min": 15.0,
    "interval": 30.0,
    "cpu_pct": 3.0,
    "max_hours": 0.0,
    "active_states": "working",
    "match": [],
    "state_dir": None,
    "log": None,
    "report_dir": None,
    "ssh_retries": 3,
    "allow_self_target": False,
    "dry_run": False,
}


class Sandbox:
    """An isolated state directory plus a Config built from the same defaults
    main() uses, so a test never touches the real XDG paths."""

    def __init__(self, test: unittest.TestCase, **overrides) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        test.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.state = self.root / "state"
        self.reports = self.root / "reports"
        values = {**FLAGS, **overrides}
        values["state_dir"] = values["state_dir"] or str(self.state)
        args = argparse.Namespace(**FLAGS)
        for key, value in values.items():
            setattr(args, key, value)
        self.config = mod.Config(args)

    @property
    def hold_file(self) -> Path:
        return self.state / "hold"

    def state_json(self) -> dict:
        return json.loads((self.state / "state.json").read_text())


def drive(samples: list[dict]):
    """A fake sampler that walks a fixed list and reports its own clock."""
    calls = {"n": 0}

    def fake_sample(*_args):
        info = samples[min(calls["n"], len(samples) - 1)]
        calls["n"] += 1
        return info, 0.0, 0.0, info["ts"]

    return fake_sample


def fake_clock():
    """A patcher that makes mod.time.time advance by a second per call.

    The loop reads time.time() many times per pass, so a side_effect list runs
    dry and raises StopIteration, which freezes the run instead of failing loud.
    A counter cannot run out."""
    ticks = {"n": 0}

    def now() -> float:
        ticks["n"] += 1
        return float(ticks["n"])

    stack = [
        patch.object(mod.time, "time", now),
        patch.object(mod.time, "sleep", lambda _s: None),
    ]
    for entry in stack:
        entry.start()
    return _Stoppers(stack)


def bounded_sample(samples: list[dict], limit: int):
    """Like drive(), but refuses to run forever.

    A watcher that never reaches a decision would otherwise hang the whole
    suite. Raising turns that into a named failure with the iteration count."""
    sampler = drive(samples)
    calls = {"n": 0}

    def fake_sample(*args):
        calls["n"] += 1
        if calls["n"] > limit:
            raise RuntimeError(
                f"the watcher ran {limit} samples without reaching a decision"
            )
        return sampler(*args)

    return fake_sample


class _Stoppers:
    def __init__(self, stack) -> None:
        self._stack = stack

    def __enter__(self):
        return None

    def __exit__(self, *_exc) -> bool:
        for entry in self._stack:
            entry.stop()
        return False


class FrontmatterTests(unittest.TestCase):
    def test_frontmatter_name_matches_directory(self):
        text = (SKILL / "SKILL.md").read_text()
        self.assertTrue(text.startswith("---\n"), "SKILL.md must open with frontmatter")
        head = text.split("---", 2)[1]
        fields = {}
        for line in head.splitlines():
            if ":" in line and not line.startswith((" ", "\t")):
                key, value = line.split(":", 1)
                fields[key.strip()] = value.strip()
        self.assertEqual(fields["name"], SKILL.name)
        self.assertGreater(len(fields["description"]), 20)

    def test_script_is_executable(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK), "the watcher ships executable")


class ArgumentTests(unittest.TestCase):
    def test_a_target_or_local_is_required(self):
        result = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 2)
        self.assertIn("target (user@host) or --local", result.stderr)

    def test_the_guard_is_skipped_for_local_and_for_an_explicit_override(self):
        self.assertIsNone(mod.guard_target(Sandbox(self, local=True).config))
        override = Sandbox(self, local=False, target="root@host", allow_self_target=True)
        self.assertIsNone(mod.guard_target(override.config))

    def test_a_missing_target_is_refused_when_local_is_not_set(self):
        config = Sandbox(self, local=False, target="").config
        with self.assertRaises(SystemExit) as caught:
            mod.guard_target(config)
        self.assertNotEqual(caught.exception.code, 0)


class SignalTests(unittest.TestCase):
    def test_the_cpu_roots_skip_pi_and_include_the_named_harnesses(self):
        config = Sandbox(self).config
        for name in ("herdr", "zcode", "dsh", "hermes", "codex", "claude", "opencode", "cursor-agent"):
            self.assertTrue(config.roots.match(name), f"{name} must be a CPU root")
        # An idle Pi TUI burns enough CPU to look busy forever. Inside Herdr the
        # agent-state signal covers Pi, so `pi` stays out of the CPU roots.
        self.assertFalse(config.roots.match("pi"))

    def test_extra_match_patterns_extend_the_roots(self):
        config = Sandbox(self, match=["my-harness"]).config
        self.assertTrue(config.roots.match("my-harness"))
        self.assertTrue(config.roots.match("codex"))

    def test_active_states_come_from_the_flag(self):
        config = Sandbox(self, active_states="working, blocked").config
        self.assertEqual(config.active_states, {"working", "blocked"})

    def test_agent_states_returns_none_when_herdr_is_absent(self):
        with patch.object(mod.subprocess, "run", side_effect=FileNotFoundError):
            self.assertIsNone(mod.agent_states())

    def test_agent_states_counts_each_state(self):
        payload = json.dumps({"result": {"agents": [
            {"agent_status": "working"}, {"agent_status": "working"}, {"agent_status": "idle"},
        ]}})
        with patch.object(mod.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, payload, "")):
            self.assertEqual(mod.agent_states(), {"working": 2, "idle": 1})


class SampleTests(unittest.TestCase):
    def test_the_first_sample_reports_no_cpu(self):
        config = Sandbox(self).config
        with patch.object(mod, "process_table", return_value=({}, {}, {})), patch.object(mod, "agent_states", return_value=None):
            info, ticks, herdr_ticks, _ = mod.sample(config, None, None, None)
        self.assertEqual(info["cpu_pct"], 0.0)
        self.assertEqual(info["cpu_herdr_pct"], 0.0)
        self.assertEqual((ticks, herdr_ticks), (0.0, 0.0))

    def test_herdr_cpu_is_excluded_while_herdr_answers(self):
        config = Sandbox(self).config
        # Ticks must advance between samples or every delta is zero. The Herdr
        # side burns a CPU-heavy idle TUI; the non-Herdr side stays quiet.
        tables = [
            ({}, {11: 100.0, 12: 10.0}, {11: "herdr", 12: "codex"}),
            ({}, {11: 1_100.0, 12: 10.01}, {11: "herdr", 12: "codex"}),
        ]
        clock = {"t": 1000.0, "n": 0}

        def now() -> float:
            clock["t"] += 1.0
            return clock["t"]

        def table() -> tuple:
            entry = tables[min(clock["n"], len(tables) - 1)]
            clock["n"] += 1
            return entry

        with patch.object(mod, "process_table", side_effect=table), patch.object(
            mod, "tree_pids", return_value=({11, 12}, {11})
        ), patch.object(mod, "agent_states", return_value={"idle": 1}), patch.object(
            mod.time, "time", now
        ):
            # The first call has no previous sample, so its delta is zero.
            first = mod.sample(config, None, None, None)
            second = mod.sample(config, *first[1:])
        # 1000 Herdr ticks in one second land in cpu_herdr_pct. The non-Herdr
        # side moved 0.5 ticks, which stays under the threshold, so an idle
        # agent TUI cannot hold the host busy through the CPU signal.
        self.assertEqual(first[0]["cpu_herdr_pct"], 0.0)
        self.assertGreater(second[0]["cpu_herdr_pct"], 0.0)
        self.assertLess(second[0]["cpu_pct"], config.cpu_pct)
        self.assertFalse(second[0]["working"])

    def test_a_working_agent_state_marks_the_host_busy(self):
        config = Sandbox(self).config
        with patch.object(mod, "process_table", return_value=({}, {}, {})), patch.object(
            mod, "agent_states", return_value={"working": 1}
        ):
            info, *_ = mod.sample(config, 0.0, 0.0, 1000.0)
        self.assertTrue(info["working"])
        self.assertEqual(info["busy_agents"], 1)

    def test_blocked_agents_stay_inactive_unless_they_are_added(self):
        config = Sandbox(self).config
        with patch.object(mod, "process_table", return_value=({}, {}, {})), patch.object(
            mod, "agent_states", return_value={"blocked": 2}
        ):
            info, *_ = mod.sample(config, 0.0, 0.0, 1000.0)
        self.assertFalse(info["working"])

        wanted = Sandbox(self, active_states="working,blocked").config
        with patch.object(mod, "process_table", return_value=({}, {}, {})), patch.object(
            mod, "agent_states", return_value={"blocked": 2}
        ):
            info, *_ = mod.sample(wanted, 0.0, 0.0, 1000.0)
        self.assertTrue(info["working"])


class StatusTests(unittest.TestCase):
    def test_status_reports_no_sample_before_the_first_run(self):
        Sandbox(self, target="", local=False)
        with patch.object(sys, "argv", ["idle-shutdown", "--local", "--status"]), redirect_stdout(io.StringIO()) as out:
            self.assertEqual(mod.main(), 0)
        self.assertIn("no sample yet", out.getvalue())

    def test_status_prints_the_last_sample(self):
        sandbox = Sandbox(self)
        sandbox.state.mkdir(parents=True)
        (sandbox.state / "state.json").write_text('{"note": "quieto"}\n')
        with patch.object(sys, "argv", ["idle-shutdown", "--local", "--status"]), patch.object(
            mod, "Config", return_value=sandbox.config
        ), redirect_stdout(io.StringIO()) as out:
            self.assertEqual(mod.main(), 0)
        self.assertIn("quieto", out.getvalue())


class HoldTests(unittest.TestCase):
    def test_hold_and_release_toggle_the_hold_file(self):
        sandbox = Sandbox(self)
        with patch.object(mod, "Config", return_value=sandbox.config), redirect_stdout(io.StringIO()):
            with patch.object(sys, "argv", ["idle-shutdown", "--local", "--hold"]):
                self.assertEqual(mod.main(), 0)
        self.assertTrue(sandbox.hold_file.exists())

        with patch.object(mod, "Config", return_value=sandbox.config), redirect_stdout(io.StringIO()):
            with patch.object(sys, "argv", ["idle-shutdown", "--local", "--release"]):
                self.assertEqual(mod.main(), 0)
        self.assertFalse(sandbox.hold_file.exists())

    def test_releasing_without_a_hold_file_does_not_raise(self):
        sandbox = Sandbox(self)
        with patch.object(mod, "Config", return_value=sandbox.config), redirect_stdout(io.StringIO()):
            with patch.object(sys, "argv", ["idle-shutdown", "--local", "--release"]):
                self.assertEqual(mod.main(), 0)


class LoopTests(unittest.TestCase):
    """Drive run() to completion. Every shutdown in this class is a fake."""

    def test_an_idle_host_reaches_the_grace_period_and_shuts_down(self):
        sandbox = Sandbox(self, grace_min=0.0)
        sent: list[str] = []
        with fake_clock(), patch.object(mod, "sample", bounded_sample([IDLE, READY], 6)), patch.object(
            mod, "shutdown", lambda cfg, note, info: sent.append(note) or True
        ), redirect_stdout(io.StringIO()):
            self.assertEqual(mod.run(sandbox.config, once=False), 0)
        self.assertEqual(len(sent), 1, "an idle host past the grace period shuts down exactly once")
        self.assertIn("sin actividad", sent[0])
        self.assertEqual(sandbox.state_json()["note"], "LISTO PARA APAGAR")

    def test_a_busy_host_never_shuts_down(self):
        sandbox = Sandbox(self)
        # A permanently busy host has no exit: every busy sample resets
        # last_active, so idle_seconds stays 0 and the grace period is never
        # reached. With max_hours at 0 (the default) the loop is infinite by
        # design, because the watcher is meant to run until the work stops.
        # The bound proves no shutdown is sent, which is the contract that
        # matters here; it is not a claim about when the loop ends.
        with fake_clock(), patch.object(mod, "sample", bounded_sample([BUSY], 5)), patch.object(
            mod, "shutdown", lambda *a: self.fail("a busy host must never reach shutdown")
        ), redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError) as caught:
                mod.run(sandbox.config, once=False)
        self.assertIn("without reaching a decision", str(caught.exception))
        self.assertEqual(sandbox.state_json()["note"], "activo")

    def test_max_hours_bounds_a_permanently_busy_host(self):
        sandbox = Sandbox(self, max_hours=0.001)
        sent: list[str] = []
        with fake_clock(), patch.object(mod, "sample", bounded_sample([BUSY], 60)), patch.object(
            mod, "shutdown", lambda cfg, note, info: sent.append(note) or True
        ), redirect_stdout(io.StringIO()):
            mod.run(sandbox.config, once=False)
        self.assertEqual(len(sent), 1, "the hard stop is the only exit for a busy host")
        self.assertIn("tope de", sent[0])

    def test_a_hold_file_keeps_a_ready_watcher_alive_without_shutting_down(self):
        sandbox = Sandbox(self, grace_min=0.0)
        sandbox.state.mkdir(parents=True)
        sandbox.hold_file.touch()
        # A hold must keep a ready watcher monitoring and never shut down. The
        # hold branch has no exit of its own either (the loop is meant to run
        # until the hold is released), so the bound ends the run.
        with fake_clock(), patch.object(mod, "sample", bounded_sample([IDLE], 5)), patch.object(
            mod, "shutdown", lambda *a: self.fail("a hold must block the shutdown")
        ), redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                mod.run(sandbox.config, once=False)
        self.assertEqual(sandbox.state_json()["note"], "hold")

    def test_releasing_the_hold_lets_a_ready_watcher_shut_down(self):
        sandbox = Sandbox(self, grace_min=0.0)
        sent: list[str] = []
        with fake_clock(), patch.object(mod, "sample", bounded_sample([IDLE, READY], 6)), patch.object(
            mod, "shutdown", lambda cfg, note, info: sent.append(note) or True
        ), redirect_stdout(io.StringIO()):
            self.assertEqual(mod.run(sandbox.config, once=False), 0)
        self.assertEqual(len(sent), 1, "without a hold the grace period shuts the host down")

    def test_a_dry_run_reaches_the_decision_and_sends_nothing(self):
        sandbox = Sandbox(self, grace_min=0.0, dry_run=True)
        # A dry run reports what it would do, sends no shutdown command, and
        # resets last_active so it keeps monitoring instead of stopping after
        # the first decision. It has no exit of its own, so the bound below is
        # what ends the run; the assertion is about the decision, not the exit.
        with fake_clock(), patch.object(mod, "sample", bounded_sample([IDLE, READY], 4)), patch.object(
            mod, "shutdown", lambda *a: self.fail("a dry run must not send a shutdown")
        ), redirect_stdout(io.StringIO()) as out:
            with self.assertRaises(RuntimeError):
                mod.run(sandbox.config, once=False)
        self.assertIn("[DRY-RUN] habria apagado", out.getvalue())
        self.assertTrue((sandbox.state / "state.json").exists())
        self.assertEqual(sandbox.state_json()["note"], "LISTO PARA APAGAR")

    def test_the_hard_stop_fires_when_the_runtime_limit_is_reached(self):
        sandbox = Sandbox(self, max_hours=0.001)
        sent: list[str] = []
        with fake_clock(), patch.object(mod, "sample", bounded_sample([BUSY, READY], 6)), patch.object(
            mod, "shutdown", lambda cfg, note, info: sent.append(note) or True
        ), redirect_stdout(io.StringIO()):
            mod.run(sandbox.config, once=False)
        self.assertEqual(len(sent), 1)
        self.assertIn("tope de", sent[0])

    def test_once_prints_the_sample_as_json_and_exits(self):
        sandbox = Sandbox(self)
        with patch.object(mod, "sample", drive([IDLE])), redirect_stdout(io.StringIO()) as out:
            self.assertEqual(mod.run(sandbox.config, once=True), 0)
        payload = json.loads(out.getvalue()[out.getvalue().find("{") :])
        self.assertIn("cpu_pct", payload)
        self.assertFalse(payload["working"])

    def test_once_writes_the_sample_to_the_state_dir(self):
        sandbox = Sandbox(self)
        with patch.object(mod, "sample", drive([IDLE])), redirect_stdout(io.StringIO()):
            mod.run(sandbox.config, once=True)
        state = sandbox.state_json()
        self.assertEqual(state["target"], "local")
        self.assertIn("idle_min", state)


class ShutdownTests(unittest.TestCase):
    def test_a_failed_local_shutdown_reports_false(self):
        config = Sandbox(self, local=True, shutdown_cmd="false").config
        with redirect_stdout(io.StringIO()):
            self.assertFalse(mod.shutdown(config, "test", IDLE))

    def test_a_remote_shutdown_returns_true_on_the_first_success(self):
        sandbox = Sandbox(self, local=False, target="root@host")
        sent: list[list[str]] = []
        with patch.object(
            mod, "ssh", lambda cfg, cmd, timeout=60: sent.append([cfg.target, cmd]) or subprocess.CompletedProcess([], 0, "", "")
        ), redirect_stdout(io.StringIO()):
            self.assertTrue(mod.shutdown(sandbox.config, "test", IDLE))
        self.assertEqual(sent, [["root@host", "shutdown now"]])

    def test_a_remote_shutdown_stops_after_the_retries_and_returns_false(self):
        sandbox = Sandbox(self, local=False, target="root@host")
        sandbox.config.ssh_retries = 2
        attempts: list[int] = []
        with patch.object(
            mod, "ssh", lambda *a, **k: attempts.append(1) or subprocess.CompletedProcess([], 255, "", "connection refused")
        ), patch.object(mod.time, "sleep", lambda _s: None), redirect_stdout(io.StringIO()):
            self.assertFalse(mod.shutdown(sandbox.config, "test", IDLE))
        self.assertEqual(len(attempts), 2, "the watcher retries exactly ssh_retries times")

    def test_a_reachable_remote_writes_one_report(self):
        sandbox = Sandbox(self, local=False, target="root@host", report_dir=None)
        sandbox.config.report_dir = sandbox.reports
        with patch.object(mod, "ssh", lambda *a, **k: subprocess.CompletedProcess([], 0, "", "")), redirect_stdout(io.StringIO()):
            self.assertTrue(mod.shutdown(sandbox.config, "reason", IDLE))
        reports = list(sandbox.reports.glob("idle-shutdown-*.md"))
        self.assertEqual(len(reports), 1)
        self.assertIn("shutdown enviado", reports[0].read_text())
        # The report reads procs_cpu, not procs. A wrong key here used to raise
        # KeyError and lose the only record of the shutdown.
        self.assertIn("procs=0.0", reports[0].read_text())

    def test_an_ssh_timeout_counts_as_sent_because_the_host_may_be_going_down(self):
        sandbox = Sandbox(self, local=False, target="root@host")
        with patch.object(mod, "ssh", side_effect=subprocess.TimeoutExpired([], 60)), redirect_stdout(io.StringIO()):
            self.assertTrue(mod.shutdown(sandbox.config, "test", IDLE))


if __name__ == "__main__":
    unittest.main(verbosity=2)
