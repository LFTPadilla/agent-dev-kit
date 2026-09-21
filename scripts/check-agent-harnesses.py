#!/usr/bin/env python3
"""Check that expected agent harness CLIs are installed and answer."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

HARNESSES: dict[str, list[str]] = {
    "pi": ["pi", "-v"],
    "dsh": ["dsh", "-V"],
}


def check_harness(name: str, command: list[str], timeout: float = 10.0) -> dict:
    path = shutil.which(name)
    if path is None:
        return {
            "name": name,
            "status": "error",
            "path": None,
            "version": None,
            "error": "not found on PATH",
        }

    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {
            "name": name,
            "status": "error",
            "path": path,
            "version": None,
            "error": str(exc),
        }

    version = next(
        (line.strip() for line in result.stdout.splitlines() if line.strip()), None
    )
    if result.returncode != 0:
        return {
            "name": name,
            "status": "error",
            "path": path,
            "version": version,
            "error": result.stderr.strip() or f"exit code {result.returncode}",
        }

    return {
        "name": name,
        "status": "ok",
        "path": path,
        "version": version,
        "error": None,
    }


def check_all_harnesses(timeout: float = 10.0) -> dict:
    results = {
        name: check_harness(name, command, timeout=timeout)
        for name, command in HARNESSES.items()
    }
    status = "error" if any(r["status"] == "error" for r in results.values()) else "ok"
    return {"status": status, "harnesses": results}


def main(argv: list[str] | None = None) -> int:
    payload = check_all_harnesses()
    print(json.dumps(payload, indent=2))
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
