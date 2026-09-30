#!/usr/bin/env python3
"""Tests for the workspace profile in scripts/audit-agent-native.py."""

from __future__ import annotations

import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "audit_agent_native", Path(__file__).with_name("audit-agent-native.py")
)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

FILES = ["PROJECT.md", "STATUS.md", "DECISIONS.md"]
DIRS = ["inbox", "areas", "work/queued", "work/active", "work/completed", "resources", "outputs", "archive"]


def make_root(tmp: str, files=(), dirs=()) -> Path:
    root = Path(tmp)
    (root / "AGENTS.md").write_text("| Catalog | [`REGISTRY.yaml`](REGISTRY.yaml) |\n")
    (root / "REGISTRY.yaml").write_text('version: "1.0"\n')
    for name in files:
        (root / name).write_text("# x\n")
    for name in dirs:
        (root / name).mkdir(parents=True)
    return root


def audit(root: Path, *extra: str):
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = mod.main(["--repo-root", str(root), "--json", *extra])
    return rc, json.loads(buf.getvalue())


class WorkspaceProfileTests(unittest.TestCase):
    def test_plain_repo_and_single_marker_have_no_profile(self):
        for dirs in (["src", "tests"], ["work"]):
            with tempfile.TemporaryDirectory() as tmp:
                rc, out = audit(make_root(tmp, dirs=dirs))
            self.assertEqual(rc, 0)
            self.assertNotIn("profile", out)
            self.assertEqual(set(out["checks"]), {"agents_md", "registry_yaml", "directory_depth"})

    def test_detected_profile_warns_but_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            rc, out = audit(make_root(tmp, files=["STATUS.md"], dirs=["inbox"]))
        self.assertEqual(rc, 0)
        self.assertEqual(out["status"], "PASS")
        self.assertEqual(out["profile"], "workspace")
        warnings = out["checks"]["workspace_profile"]["warnings"]
        self.assertIn("Missing foundation file: PROJECT.md", warnings)
        self.assertIn("Missing foundation folder: work/active/", warnings)
        self.assertNotIn("Missing foundation file: STATUS.md", warnings)
        self.assertNotIn("Missing foundation folder: inbox/", warnings)

    def test_profile_flag_and_complete_foundation(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, forced = audit(make_root(tmp), "--profile", "workspace")
            self.assertEqual(forced["checks"]["workspace_profile"]["warning_count"], len(FILES) + len(DIRS))
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, files=FILES, dirs=DIRS)
            _, auto = audit(root)
            self.assertEqual(auto["checks"]["workspace_profile"]["warning_count"], 0)
            _, off = audit(root, "--profile", "none")
            self.assertNotIn("profile", off)


if __name__ == "__main__":
    unittest.main()
