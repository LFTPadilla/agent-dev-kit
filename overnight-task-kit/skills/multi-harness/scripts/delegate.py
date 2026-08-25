#!/usr/bin/env python3
"""Universal Harness Adapter — Delegate bounded tasks across local agent harnesses."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any


DEFAULT_PROFILES: dict[str, dict[str, Any]] = {
    # Codex CLI profiles (dynamic model resolution)
    "codex-complex": {
        "harness": "codex",
        "model": "auto",
        "model_family": "gpt",
        "mode": "write",
        "timeout": 2400,
        "description": "Complex worker via Codex CLI. Requires --allow-write or --yolo.",
    },
    "codex-fast": {
        "harness": "codex",
        "model": "auto",
        "model_family": "luna",
        "mode": "read",
        "timeout": 1200,
        "description": "Fast exploration worker via Codex CLI.",
    },
    "codex-review": {
        "harness": "codex",
        "model": "auto",
        "model_family": "sol",
        "mode": "read",
        "timeout": 1800,
        "description": "Independent verifier/reviewer via Codex CLI.",
    },
    # Claude Code CLI profiles
    "claude-review": {
        "harness": "claude",
        "model": "default",
        "mode": "read",
        "timeout": 1800,
        "description": "Adversarial code review via Claude Code CLI.",
    },
    "claude-implement": {
        "harness": "claude",
        "model": "default",
        "mode": "write",
        "timeout": 2400,
        "description": "Scoped implementation via Claude Code CLI. Requires --allow-write or --yolo.",
    },
    # DeepSeek Harness (DHS / DSH) profiles — Headless CLI execution (no TUI)
    "dhs-review": {
        "harness": "dhs",
        "model": "default",
        "mode": "read",
        "timeout": 1800,
        "description": "Headless read-only review via DeepSeek Harness (DHS/DSH).",
    },
    "dhs-implement": {
        "harness": "dhs",
        "model": "default",
        "mode": "write",
        "timeout": 2400,
        "description": "Headless scoped implementation via DeepSeek Harness (DHS/DSH). Requires --allow-write or --yolo.",
    },
    "dhs-fast": {
        "harness": "dhs",
        "model": "default",
        "mode": "read",
        "timeout": 1200,
        "description": "Headless fast scan via DeepSeek Harness (DHS/DSH).",
    },
    # Pi profiles (dynamic frontier model resolution from local models.json)
    "pi-glm-review": {
        "harness": "pi",
        "model": "auto",
        "model_family": "glm",
        "thinking": "xhigh",
        "mode": "read",
        "timeout": 1800,
        "description": "Deep read-only review with latest local GLM frontier model via Pi.",
    },
    "pi-glm-plan": {
        "harness": "pi",
        "model": "auto",
        "model_family": "glm",
        "thinking": "high",
        "mode": "read",
        "timeout": 1800,
        "description": "Read-only planning and decomposition with latest local GLM model via Pi.",
    },
    "pi-glm-debug": {
        "harness": "pi",
        "model": "auto",
        "model_family": "glm",
        "thinking": "high",
        "mode": "read",
        "timeout": 1800,
        "description": "Read-only debugging analysis with latest local GLM model via Pi.",
    },
    "pi-glm-implement": {
        "harness": "pi",
        "model": "auto",
        "model_family": "glm",
        "thinking": "high",
        "mode": "write",
        "timeout": 2400,
        "description": "Scoped implementation with latest local GLM model via Pi. Requires --allow-write or --yolo.",
    },
    "pi-deepseek-review": {
        "harness": "pi",
        "model": "auto",
        "model_family": "deepseek",
        "thinking": "high",
        "mode": "read",
        "timeout": 1800,
        "description": "Deep read-only review with latest local DeepSeek model via Pi.",
    },
    "pi-minimax-large": {
        "harness": "pi",
        "model": "auto",
        "model_family": "minimax",
        "thinking": "medium",
        "mode": "read",
        "timeout": 1800,
        "description": "Large-context read-only sweep with latest local MiniMax model via Pi.",
    },
    # OpenCode profiles
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
        "description": "OpenCode implementation. Requires --allow-write or --yolo.",
    },
}

TASK_TYPE_DEFAULTS = {
    "review": "codex-review",
    "security": "codex-review",
    "plan": "pi-glm-plan",
    "research": "pi-minimax-large",
    "debug": "pi-glm-debug",
    "quick": "opencode-fast",
    "implement": "codex-complex",
    "verify": "codex-review",
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


def available_codex_models() -> set[str]:
    cache_path = Path.home() / ".codex/models_cache.json"
    data = load_json(cache_path)
    if not data:
        return set()
    found: set[str] = set()
    for item in data.get("models", []):
        if isinstance(item, dict) and "id" in item:
            found.add(item["id"])
    return found


def find_harness_binary(harness: str) -> str | None:
    if harness == "dhs":
        for name in ["dhs", "dsh", "deepseek-harness"]:
            path = shutil.which(name)
            if path:
                return path
        return None
    return shutil.which(harness)


def resolve_dynamic_model(harness: str, family: str | None, explicit_model: str | None) -> str:
    """Dynamically resolve to the newest active frontier model in local configurations."""
    if explicit_model and explicit_model != "auto":
        return explicit_model

    def sort_by_version(items: list[str]) -> list[str]:
        def key_func(s: str) -> tuple[float, str]:
            # Look for version numbers like 5.3, 5.2, 4.5, etc.
            matches = re.findall(r"(\d+(?:\.\d+)?)", s)
            version = float(matches[-1]) if matches else 0.0
            return (version, s)
        return sorted(items, key=key_func, reverse=True)

    if harness == "pi":
        available = available_pi_models()
        if not family:
            return "default"
        candidates = [m for m in available if family.lower() in m.lower()]
        if candidates:
            return sort_by_version(candidates)[0]
        return "default"

    if harness == "opencode":
        available = available_opencode_models()
        if not family:
            return "default"
        candidates = [m for m in available if family.lower() in m.lower()]
        if candidates:
            return sort_by_version(candidates)[0]
        return "default"

    if harness == "codex":
        available = available_codex_models()
        if not family:
            return "default"
        candidates = [m for m in available if family.lower() in m.lower()]
        if candidates:
            return sort_by_version(candidates)[0]
        return "default"

    return "default"


def print_profiles() -> None:
    header = ["profile", "harness", "model (dynamic)", "mode", "description"]
    rows = []
    for name, profile in DEFAULT_PROFILES.items():
        harness = profile["harness"]
        family = profile.get("model_family")
        raw_model = profile["model"]
        resolved = resolve_dynamic_model(harness, family, raw_model)
        display_model = f"{raw_model} -> {resolved}" if raw_model == "auto" else raw_model
        rows.append(
            [
                name,
                harness,
                display_model,
                profile["mode"],
                profile.get("description", ""),
            ]
        )
    widths = [max(len(str(row[i])) for row in rows + [header]) for i in range(len(header))]
    print("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(header)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print("  ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def diagnose() -> int:
    print("Universal Harness Adapter — Diagnostics")
    print("========================================")
    harnesses = ["codex", "claude", "dhs", "pi", "opencode"]
    for h in harnesses:
        path = find_harness_binary(h)
        extra = " (headless runner)" if h == "dhs" else ""
        print(f"{h:10}: {path or '<missing>'}{extra}")
        if path:
            print(f"  version : {run_quiet([path, '--version'])}")
    print()
    print("Detected Models per Harness:")
    print("Codex:")
    for model in sorted(available_codex_models()) or ["<none found>"]:
        print(f"  - {model}")
    print("Pi:")
    for model in sorted(available_pi_models()) or ["<none found>"]:
        print(f"  - {model}")
    print("OpenCode:")
    for model in sorted(available_opencode_models()) or ["<none found>"]:
        print(f"  - {model}")
    print()
    missing = []
    for name, profile in DEFAULT_PROFILES.items():
        harness = profile["harness"]
        family = profile.get("model_family")
        raw_model = profile["model"]
        resolved = resolve_dynamic_model(harness, family, raw_model)
        binary = find_harness_binary(harness)
        ok = bool(binary)
        marker = "OK" if ok else "MISSING"
        display_model = f"{raw_model} ({resolved})" if raw_model == "auto" else raw_model
        print(f"{marker:7} {name:20} [{harness}] model={display_model}")
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

    # Resolve dynamic model
    resolved_model = resolve_dynamic_model(profile["harness"], profile.get("model_family"), profile.get("model"))
    profile["model"] = resolved_model
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


def setup_worktree(repo_root: Path, slug: str) -> Path:
    if not re.match(r"^[a-zA-Z0-9_-]+$", slug):
        raise SystemExit(f"Invalid worktree slug {slug!r}. Slugs must contain only alphanumeric characters, dashes, or underscores.")

    worktrees_root = (repo_root / ".worktrees").resolve()
    worktree_dir = (worktrees_root / slug).resolve()

    if not str(worktree_dir).startswith(str(worktrees_root)):
        raise SystemExit(f"Security error: worktree path {worktree_dir} escapes {worktrees_root}")

    if worktree_dir.exists():
        list_proc = subprocess.run(
            ["git", "-C", str(repo_root), "worktree", "list", "--porcelain"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if str(worktree_dir) in list_proc.stdout:
            return worktree_dir
        raise SystemExit(f"Path {worktree_dir} exists but is not a registered Git worktree. Clean it up before proceeding.")

    branch = f"task/{slug}"
    cmd = ["git", "-C", str(repo_root), "worktree", "add", "-b", branch, str(worktree_dir), "HEAD"]
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode != 0:
        cmd_existing = ["git", "-C", str(repo_root), "worktree", "add", str(worktree_dir), branch]
        proc2 = subprocess.run(cmd_existing, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if proc2.returncode != 0:
            raise SystemExit(f"Failed to create worktree at {worktree_dir}: {proc.stderr}\n{proc2.stderr}")
    return worktree_dir


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
        You are a bounded worker delegated by the primary orchestrator.

        Working directory: {cwd}
        Profile: {profile_name}
        Harness: {profile['harness']}
        Model: {profile['model']}
        Permission mode: {mode}

        Task:
        {task.strip()}

        Rules:
        - Read project instructions such as REGISTRY.yaml or AGENTS.md before acting.
        {forbidden_text}
        - The primary orchestrator will verify your output on disk before accepting it.
        - You do not have the full conversation context unless it is written above.

        Return structured output formatted in compact YAML:
        ```yaml
        status: done | blocked | failed
        files_changed:
          - path/to/file
        commands_run:
          - command string
        tests: pass | fail | skipped
        decisions:
          - "Short rationale for key choices"
        risks:
          - "Residual risk or unresolved concern"
        next_actions:
          - "Next suggested step"
        ```
        """
    ).strip()


def command_for(profile: dict[str, Any], cwd: Path, prompt: str, allow_write: bool, skip_permissions: bool) -> list[str]:
    harness = profile["harness"]
    model = profile["model"]
    mode = profile["mode"]
    effective_write = allow_write or skip_permissions

    if mode == "write" and not effective_write:
        raise SystemExit(
            f"Profile mode is write for {model}. Re-run with --allow-write, --yolo, or --dangerously-skip-permissions."
        )

    if harness == "pi":
        tools = WRITE_TOOLS if effective_write else READ_ONLY_TOOLS
        cmd = [
            "pi",
            "--print",
            "--no-session",
            "--mode",
            "text",
            "--tools",
            tools,
        ]
        if model != "default":
            cmd.extend(["--model", model])
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

    if harness == "codex":
        cmd = ["codex", "exec", "--ephemeral", "-C", str(cwd)]
        if model != "default":
            cmd.extend(["-m", model])
        if skip_permissions:
            cmd.append("--yolo")
        cmd.append(prompt)
        return cmd

    if harness == "claude":
        cmd = ["claude", "-p", prompt]
        if skip_permissions:
            cmd.append("--dangerously-skip-permissions")
        return cmd

    if harness == "dhs":
        binary = find_harness_binary("dhs") or "dhs"
        cmd = [binary, "exec", "--dir", str(cwd)]
        if model != "default":
            cmd.extend(["--model", model])
        if skip_permissions:
            cmd.append("--yolo")
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
    display_cmd = [arg if arg != prompt else "<prompt>" for arg in cmd]
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
    parser.add_argument("--worktree", help="Isolate task in a dedicated git worktree under .worktrees/<slug>.")
    parser.add_argument("--timeout", type=int, help="Override timeout in seconds.")
    parser.add_argument("--model", help="Override model for the selected profile.")
    parser.add_argument("--harness", choices=["pi", "opencode", "codex", "claude", "dhs"], help="Override harness.")
    parser.add_argument("--allow-write", action="store_true", help="Allow a write-capable profile to run.")
    parser.add_argument("--yolo", action="store_true", help="Bypass confirmation prompts and skip permissions.")
    parser.add_argument("--dangerously-skip-permissions", action="store_true", help="Alias for --yolo.")
    parser.add_argument("--dry-run", action="store_true", help="Print command metadata without executing.")
    parser.add_argument("--no-save", action="store_true", help="Do not write run artifacts.")
    parser.add_argument("--save-dir", default=str(Path.home() / ".cache/multi-harness/runs"))
    parser.add_argument("--list-profiles", action="store_true", help="List configured profiles.")
    parser.add_argument("--diagnose", action="store_true", help="Run harness and model diagnostics.")
    args = parser.parse_args()

    if args.list_profiles:
        print_profiles()
        return 0
    if args.diagnose:
        return diagnose()

    skip_permissions = args.yolo or args.dangerously_skip_permissions
    allow_write = args.allow_write or skip_permissions

    profile_name, profile = resolve_profile(args)
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.exists():
        raise SystemExit(f"Working directory does not exist: {cwd}")

    if args.worktree:
        cwd = setup_worktree(cwd, args.worktree)

    task = read_task(args)
    prompt = build_prompt(profile_name, profile, cwd, task, allow_write)
    cmd = command_for(profile, cwd, prompt, allow_write, skip_permissions)

    display_cmd = [arg if arg != prompt else "<prompt>" for arg in cmd]
    run_dir = None
    if args.dry_run:
        if not args.no_save:
            run_dir = write_run_artifacts(Path(args.save_dir).expanduser(), profile_name, prompt, cmd, cwd, None, True)
        print("DRY RUN")
        print("Command:", " ".join(display_cmd))
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
