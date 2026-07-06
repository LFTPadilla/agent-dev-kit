#!/usr/bin/env python3
"""Delegate a bounded task to a local agent harness."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any


DEFAULT_PROFILES: dict[str, dict[str, Any]] = {
    "pi-glm-review": {
        "harness": "pi",
        "model": "zai-coding-plan/glm-5.2",
        "thinking": "xhigh",
        "mode": "read",
        "timeout": 1800,
        "description": "Deep read-only review with GLM 5.2.",
    },
    "pi-glm-plan": {
        "harness": "pi",
        "model": "zai-coding-plan/glm-5.2",
        "thinking": "high",
        "mode": "read",
        "timeout": 1800,
        "description": "Read-only planning and decomposition with GLM 5.2.",
    },
    "pi-glm-debug": {
        "harness": "pi",
        "model": "zai-coding-plan/glm-5.2",
        "thinking": "high",
        "mode": "read",
        "timeout": 1800,
        "description": "Read-only debugging analysis with GLM 5.2.",
    },
    "pi-glm-implement": {
        "harness": "pi",
        "model": "zai-coding-plan/glm-5.2",
        "thinking": "high",
        "mode": "write",
        "timeout": 2400,
        "description": "Scoped implementation with GLM 5.2. Requires --allow-write.",
    },
    "pi-minimax-large": {
        "harness": "pi",
        "model": "minimax/MiniMax-M3",
        "thinking": "medium",
        "mode": "read",
        "timeout": 1800,
        "description": "Large-context read-only sweep.",
    },
    "opencode-fast": {
        "harness": "opencode",
        "model": "default",
        "mode": "read",
        "timeout": 1200,
        "description": "Fast OpenCode scan. Read-only by prompt contract.",
    },
    "opencode-review": {
        "harness": "opencode",
        "model": "default",
        "agent": "gsd-code-reviewer",
        "mode": "read",
        "timeout": 1800,
        "description": "OpenCode/GSD-flavored review. Read-only by prompt contract.",
    },
    "opencode-implement": {
        "harness": "opencode",
        "model": "default",
        "agent": "gsd-executor",
        "mode": "write",
        "timeout": 2400,
        "description": "OpenCode implementation. Requires --allow-write.",
    },
}

TASK_TYPE_DEFAULTS = {
    "review": "pi-glm-review",
    "security": "pi-glm-review",
    "plan": "pi-glm-plan",
    "research": "pi-minimax-large",
    "debug": "pi-glm-debug",
    "quick": "opencode-fast",
    "implement": "pi-glm-implement",
    "verify": "opencode-review",
}

READ_ONLY_TOOLS = "read,grep,find,ls"
WRITE_TOOLS = "read,grep,find,ls,bash,edit,write"


def run_quiet(argv: list[str], timeout: int = 20) -> str:
    try:
        proc = subprocess.run(
            argv,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:  # noqa: BLE001 - diagnostics should never crash hard
        return f"<error: {exc}>"
    return proc.stdout.strip()


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def available_pi_models() -> set[str]:
    models_path = Path.home() / ".pi/agent/models.json"
    data = load_json(models_path)
    if not data:
        return set()
    found: set[str] = set()
    for provider, config in data.get("providers", {}).items():
        for model in config.get("models", []):
            model_id = model.get("id")
            if model_id:
                found.add(f"{provider}/{model_id}")
    return found


def available_opencode_models() -> set[str]:
    config_path = Path.home() / ".config/opencode/opencode.json"
    data = load_json(config_path)
    if not data:
        return set()
    found: set[str] = set()
    for provider, config in data.get("provider", {}).items():
        for model_id in config.get("models", {}).keys():
            found.add(f"{provider}/{model_id}")
    return found


def print_profiles() -> None:
    rows = []
    for name, profile in DEFAULT_PROFILES.items():
        rows.append(
            [
                name,
                profile["harness"],
                profile["model"],
                profile["mode"],
                profile.get("description", ""),
            ]
        )
    widths = [max(len(str(row[i])) for row in rows + [["profile", "harness", "model", "mode", "description"]]) for i in range(5)]
    header = ["profile", "harness", "model", "mode", "description"]
    print("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(header)))
    print("  ".join("-" * widths[i] for i in range(5)))
    for row in rows:
        print("  ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def diagnose() -> int:
    print("Harness diagnostics")
    print("===================")
    for binary in ["pi", "opencode"]:
        path = shutil.which(binary)
        print(f"{binary}: {path or '<missing>'}")
        if path:
            print(f"{binary} version: {run_quiet([binary, '--version'])}")
    pi_models = available_pi_models()
    opencode_models = available_opencode_models()
    print()
    print("Pi models:")
    for model in sorted(pi_models) or ["<none found>"]:
        print(f"  - {model}")
    print("OpenCode models:")
    for model in sorted(opencode_models) or ["<none found>"]:
        print(f"  - {model}")
    print()
    missing = []
    for name, profile in DEFAULT_PROFILES.items():
        harness = profile["harness"]
        model = profile["model"]
        available = pi_models if harness == "pi" else opencode_models
        binary = shutil.which(harness)
        ok = bool(binary) and (model == "default" or model in available)
        marker = "OK" if ok else "CHECK"
        print(f"{marker:5} {name}: {harness} {model}")
        if not ok:
            missing.append(name)
    return 1 if missing else 0


def resolve_profile(args: argparse.Namespace) -> tuple[str, dict[str, Any]]:
    if args.profile == "auto":
        if not args.task_type:
            raise SystemExit("--profile auto requires --task-type")
        try:
            profile_name = TASK_TYPE_DEFAULTS[args.task_type]
        except KeyError as exc:
            choices = ", ".join(sorted(TASK_TYPE_DEFAULTS))
            raise SystemExit(f"Unknown task type {args.task_type!r}. Choose one of: {choices}") from exc
    else:
        profile_name = args.profile
    if profile_name not in DEFAULT_PROFILES:
        choices = ", ".join(sorted(DEFAULT_PROFILES))
        raise SystemExit(f"Unknown profile {profile_name!r}. Choose one of: {choices}")
    profile = dict(DEFAULT_PROFILES[profile_name])
    if args.model:
        profile["model"] = args.model
    if args.harness:
        profile["harness"] = args.harness
    if args.timeout:
        profile["timeout"] = args.timeout
    return profile_name, profile


def read_task(args: argparse.Namespace) -> str:
    chunks = []
    if args.task_file:
        chunks.append(Path(args.task_file).read_text(encoding="utf-8"))
    if args.task:
        chunks.append(args.task)
    if not chunks and not sys.stdin.isatty():
        chunks.append(sys.stdin.read())
    task = "\n\n".join(chunk.strip() for chunk in chunks if chunk.strip())
    if not task:
        raise SystemExit("Provide --task, --task-file, or stdin.")
    return task


def build_prompt(profile_name: str, profile: dict[str, Any], cwd: Path, task: str, allow_write: bool) -> str:
    mode = "WRITE_ALLOWED" if profile["mode"] == "write" and allow_write else "READ_ONLY"
    forbidden = [
        "Do not reveal, copy, or print secrets or credential values.",
        "Do not push, commit, deploy, publish, send email, charge money, or modify production systems.",
        "Do not perform cloud, Kubernetes, DNS, database, billing, or account writes.",
        "If blocked, explain the blocker and stop instead of broadening scope.",
    ]
    if mode == "READ_ONLY":
        forbidden.insert(0, "Do not modify files. Do not run commands that mutate the workspace.")
    else:
        forbidden.insert(0, "Keep edits tightly scoped to the requested task and report every changed file.")

    forbidden_text = "\n".join(f"- {line}" for line in forbidden)
    return textwrap.dedent(
        f"""
        You are an external harness delegated by the primary Codex orchestrator.

        Working directory: {cwd}
        Profile: {profile_name}
        Harness: {profile['harness']}
        Model: {profile['model']}
        Permission mode: {mode}

        Task:
        {task.strip()}

        Rules:
        - Read project instructions such as AGENTS.md before acting.
        {forbidden_text}
        - The primary orchestrator will verify your output before accepting it.
        - You do not have the full conversation context unless it is written above.

        Return exactly these sections:
        1. SUMMARY
        2. FINDINGS_OR_CHANGES
        3. FILES_INSPECTED
        4. COMMANDS_RUN
        5. VERIFICATION
        6. RISKS
        """
    ).strip()


def command_for(profile: dict[str, Any], cwd: Path, prompt: str, allow_write: bool) -> list[str]:
    harness = profile["harness"]
    model = profile["model"]
    mode = profile["mode"]
    if mode == "write" and not allow_write:
        raise SystemExit(f"Profile mode is write for {model}. Re-run with --allow-write if this is intentional.")

    if harness == "pi":
        tools = WRITE_TOOLS if mode == "write" else READ_ONLY_TOOLS
        cmd = [
            "pi",
            "--print",
            "--no-session",
            "--mode",
            "text",
            "--model",
            model,
            "--tools",
            tools,
        ]
        if profile.get("thinking"):
            cmd.extend(["--thinking", str(profile["thinking"])])
        cmd.append(prompt)
        return cmd

    if harness == "opencode":
        cmd = ["opencode", "run", "--dir", str(cwd)]
        if model != "default":
            cmd.extend(["--model", model])
        if profile.get("agent"):
            cmd.extend(["--agent", str(profile["agent"])])
        if profile.get("variant"):
            cmd.extend(["--variant", str(profile["variant"])])
        cmd.append(prompt)
        return cmd

    raise SystemExit(f"Unsupported harness: {harness}")


def write_run_artifacts(
    save_dir: Path,
    profile_name: str,
    prompt: str,
    cmd: list[str],
    cwd: Path,
    proc: subprocess.CompletedProcess[str] | None,
    dry_run: bool,
) -> Path:
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = save_dir / f"{timestamp}-{profile_name}"
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "prompt.md").write_text(prompt + "\n", encoding="utf-8")
    display_cmd = [cmd[0], *cmd[1:-1], "<prompt>"] if cmd else []
    meta = {
        "profile": profile_name,
        "cwd": str(cwd),
        "dry_run": dry_run,
        "command": display_cmd,
        "returncode": None if proc is None else proc.returncode,
        "created_at": timestamp,
    }
    (run_dir / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    if proc is not None:
        (run_dir / "stdout.md").write_text(proc.stdout or "", encoding="utf-8")
        (run_dir / "stderr.txt").write_text(proc.stderr or "", encoding="utf-8")
    return run_dir


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="auto", help="Profile name, or auto with --task-type.")
    parser.add_argument("--task-type", choices=sorted(TASK_TYPE_DEFAULTS), help="Routing hint for --profile auto.")
    parser.add_argument("--task", help="Delegated task text.")
    parser.add_argument("--task-file", help="Read delegated task text from file.")
    parser.add_argument("--cwd", default=os.getcwd(), help="Working directory for the delegated harness.")
    parser.add_argument("--timeout", type=int, help="Override timeout in seconds.")
    parser.add_argument("--model", help="Override model for the selected profile.")
    parser.add_argument("--harness", choices=["pi", "opencode"], help="Override harness for the selected profile.")
    parser.add_argument("--allow-write", action="store_true", help="Allow a write-capable profile to run.")
    parser.add_argument("--dry-run", action="store_true", help="Print command metadata and save prompt without executing.")
    parser.add_argument("--no-save", action="store_true", help="Do not write run artifacts.")
    parser.add_argument("--save-dir", default=str(Path.home() / ".cache/multi-harness/runs"))
    parser.add_argument("--list-profiles", action="store_true")
    parser.add_argument("--diagnose", action="store_true")
    args = parser.parse_args()

    if args.list_profiles:
        print_profiles()
        return 0
    if args.diagnose:
        return diagnose()

    profile_name, profile = resolve_profile(args)
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.exists():
        raise SystemExit(f"Working directory does not exist: {cwd}")
    task = read_task(args)
    prompt = build_prompt(profile_name, profile, cwd, task, args.allow_write)
    cmd = command_for(profile, cwd, prompt, args.allow_write)

    run_dir = None
    if args.dry_run:
        if not args.no_save:
            run_dir = write_run_artifacts(Path(args.save_dir).expanduser(), profile_name, prompt, cmd, cwd, None, True)
        print("DRY RUN")
        print("Command:", " ".join(cmd[:-1]), "<prompt>")
        if run_dir:
            print("Run dir:", run_dir)
        return 0

    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=int(profile["timeout"]),
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        print(f"Timed out after {profile['timeout']} seconds: {exc}", file=sys.stderr)
        return 124

    if not args.no_save:
        run_dir = write_run_artifacts(Path(args.save_dir).expanduser(), profile_name, prompt, cmd, cwd, proc, False)

    if run_dir:
        print(f"[multi-harness] run dir: {run_dir}", file=sys.stderr)
    if proc.stderr:
        print(proc.stderr, file=sys.stderr, end="")
    print(proc.stdout, end="")
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
