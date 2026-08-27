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

# Default Profile Declarations (Dynamic model resolution)
DEFAULT_PROFILES: dict[str, dict[str, Any]] = {
    # Codex CLI (ephemeral workers)
    "codex-complex": {"harness": "codex", "model": "auto", "model_family": "gpt", "mode": "write", "timeout": 2400, "description": "Complex worker via Codex CLI. Requires --allow-write or --yolo."},
    "codex-fast": {"harness": "codex", "model": "auto", "model_family": "luna", "mode": "read", "timeout": 1200, "description": "Fast exploration worker via Codex CLI."},
    "codex-review": {"harness": "codex", "model": "auto", "model_family": "sol", "mode": "read", "timeout": 1800, "description": "Independent verifier/reviewer via Codex CLI."},

    # Claude Code CLI
    "claude-review": {"harness": "claude", "model": "default", "mode": "read", "timeout": 1800, "description": "Adversarial code review via Claude Code CLI."},
    "claude-implement": {"harness": "claude", "model": "default", "mode": "write", "timeout": 2400, "description": "Scoped implementation via Claude Code CLI. Requires --allow-write or --yolo."},

    # DeepSeek Harness (DHS/DSH) — Headless runner (no interactive terminal TUI)
    "dhs-review": {"harness": "dhs", "model": "default", "mode": "read", "timeout": 1800, "description": "Headless read-only review via DeepSeek Harness (DHS/DSH)."},
    "dhs-implement": {"harness": "dhs", "model": "default", "mode": "write", "timeout": 2400, "description": "Headless scoped implementation via DeepSeek Harness (DHS/DSH). Requires --allow-write or --yolo."},
    "dhs-fast": {"harness": "dhs", "model": "default", "mode": "read", "timeout": 1200, "description": "Headless fast scan via DeepSeek Harness (DHS/DSH)."},

    # Pi CLI (dynamic frontier model resolution from local models.json)
    "pi-glm-review": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "xhigh", "mode": "read", "timeout": 1800, "description": "Deep read-only review with latest local GLM frontier model via Pi."},
    "pi-glm-plan": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Read-only planning with latest local GLM model via Pi."},
    "pi-glm-debug": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Read-only debugging with latest local GLM model via Pi."},
    "pi-glm-implement": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "write", "timeout": 2400, "description": "Scoped implementation with latest local GLM model via Pi. Requires --allow-write or --yolo."},
    "pi-deepseek-review": {"harness": "pi", "model": "auto", "model_family": "deepseek", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Deep review with latest local DeepSeek model via Pi."},
    "pi-minimax-large": {"harness": "pi", "model": "auto", "model_family": "minimax", "thinking": "medium", "mode": "read", "timeout": 1800, "description": "Large-context read-only sweep with latest local MiniMax model via Pi."},

    # Pi-Profile Isolated Environments
    "pi-lean": {"harness": "pi", "pi_profile": "lean", "model": "auto", "mode": "read", "timeout": 1800, "description": "Isolated lightweight Pi runner via local pi-profile lean."},
    "pi-gsd": {"harness": "pi", "pi_profile": "gsd", "model": "auto", "mode": "read", "timeout": 1800, "description": "GSD-enhanced Pi runner via local pi-profile gsd."},
    "pi-search": {"harness": "pi", "pi_profile": "search", "model": "auto", "mode": "read", "timeout": 1800, "description": "Research and web search Pi runner via local pi-profile search."},

    # OpenCode
    "opencode-fast": {"harness": "opencode", "model": "default", "mode": "read", "timeout": 1200, "description": "Fast OpenCode scan. Read-only by prompt contract."},
    "opencode-review": {"harness": "opencode", "model": "default", "agent": "gsd-code-reviewer", "mode": "read", "timeout": 1800, "description": "OpenCode/GSD-flavored review. Read-only by prompt contract."},
    "opencode-implement": {"harness": "opencode", "model": "default", "agent": "gsd-executor", "mode": "write", "timeout": 2400, "description": "OpenCode implementation. Requires --allow-write or --yolo."},
}

TASK_TYPE_DEFAULTS = {
    "review": "codex-review",
    "security": "codex-review",
    "plan": "pi-glm-plan",
    "research": "pi-search",
    "debug": "pi-glm-debug",
    "quick": "opencode-fast",
    "implement": "codex-complex",
    "verify": "codex-review",
    "lean": "pi-lean",
}

READ_ONLY_TOOLS = "read,grep,find,ls"
WRITE_TOOLS = "read,grep,find,ls,bash,edit,write"


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def find_binary(names: list[str]) -> str | None:
    for name in names:
        path = shutil.which(name)
        if path:
            return path
        p = Path(name).expanduser()
        if p.is_file() and os.access(p, os.X_OK):
            return str(p.resolve())
    return None


def available_models(harness: str) -> set[str]:
    """Extract registered model IDs from local harness config files."""
    home = Path.home()
    if harness == "pi":
        data = load_json(home / ".pi/agent/models.json")
        return {
            f"{p}/{m['id']}"
            for p, cfg in data.get("providers", {}).items()
            for m in cfg.get("models", [])
            if isinstance(m, dict) and "id" in m
        }
    if harness == "opencode":
        data = load_json(home / ".config/opencode/opencode.json")
        return {
            f"{p}/{m}"
            for p, cfg in data.get("provider", {}).items()
            for m in cfg.get("models", {}).keys()
        }
    if harness == "codex":
        data = load_json(home / ".codex/models_cache.json")
        return {m["id"] for m in data.get("models", []) if isinstance(m, dict) and "id" in m}
    return set()


def available_pi_profiles() -> list[str]:
    """Detect isolated profiles configured in ~/pi-lab/profiles or ~/programming/pi-lab/profiles."""
    for base in [Path.home() / "pi-lab/profiles", Path.home() / "programming/pi-lab/profiles"]:
        if base.is_dir():
            return sorted(d.name for d in base.iterdir() if d.is_dir() and not d.name.startswith("."))
    return []


def resolve_dynamic_model(harness: str, family: str | None, explicit_model: str | None) -> str:
    """Dynamically resolve to the newest active frontier model in local configurations."""
    if explicit_model and explicit_model != "auto":
        return explicit_model
    if not family:
        return "default"

    models = [m for m in available_models(harness) if family.lower() in m.lower()]
    if not models:
        return "default"

    # ponytail: sort by extracted floating-point version descending to pick newest frontier
    def version_key(s: str) -> tuple[float, str]:
        matches = re.findall(r"(\d+(?:\.\d+)?)", s)
        return (float(matches[-1]) if matches else 0.0, s)

    return sorted(models, key=version_key, reverse=True)[0]


def setup_worktree(repo_root: Path, slug: str) -> Path:
    """Safely create or attach to an isolated git worktree under .worktrees/<slug>."""
    if not re.match(r"^[a-zA-Z0-9_-]+$", slug):
        raise SystemExit(f"Invalid worktree slug {slug!r}. Alphanumeric, dashes, and underscores only.")

    worktrees_root = (repo_root / ".worktrees").resolve()
    worktree_dir = (worktrees_root / slug).resolve()
    if not str(worktree_dir).startswith(str(worktrees_root)):
        raise SystemExit(f"Security error: worktree path {worktree_dir} escapes {worktrees_root}")

    if worktree_dir.exists():
        proc = subprocess.run(["git", "-C", str(repo_root), "worktree", "list", "--porcelain"], capture_output=True, text=True, check=False)
        if str(worktree_dir) in proc.stdout:
            return worktree_dir
        raise SystemExit(f"Path {worktree_dir} exists but is not a registered Git worktree. Clean it up first.")

    branch = f"task/{slug}"
    cmd = ["git", "-C", str(repo_root), "worktree", "add", "-b", branch, str(worktree_dir), "HEAD"]
    if subprocess.run(cmd, capture_output=True, text=True, check=False).returncode != 0:
        # Retry attaching to existing branch
        if subprocess.run(["git", "-C", str(repo_root), "worktree", "add", str(worktree_dir), branch], capture_output=True, text=True, check=False).returncode != 0:
            raise SystemExit(f"Failed to create worktree at {worktree_dir}")
    return worktree_dir


def build_prompt(profile_name: str, profile: dict[str, Any], cwd: Path, task: str, allow_write: bool) -> str:
    mode = "WRITE_ALLOWED" if profile["mode"] == "write" and allow_write else "READ_ONLY"
    mode_rule = "- Do not modify files or mutate the workspace." if mode == "READ_ONLY" else "- Keep edits tightly scoped to the task and report every changed file."

    return textwrap.dedent(f"""
        You are a bounded worker delegated by the primary orchestrator.

        Working directory: {cwd}
        Profile: {profile_name}
        Harness: {profile['harness']}
        Model: {profile['model']}
        Permission mode: {mode}

        Task:
        {task.strip()}

        Rules:
        - Read project instructions (REGISTRY.yaml / AGENTS.md) before acting.
        {mode_rule}
        - Do not reveal secrets, push commits, deploy, or modify cloud/production systems.
        - If blocked, explain the blocker and stop instead of broadening scope.

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
    """).strip()


def command_for(profile: dict[str, Any], cwd: Path, prompt: str, allow_write: bool, skip_permissions: bool) -> list[str]:
    harness, model, mode = profile["harness"], profile["model"], profile["mode"]
    effective_write = mode == "write" and (allow_write or skip_permissions)
    if mode == "write" and not effective_write:
        raise SystemExit(f"Profile requires write access. Run with --allow-write or --yolo.")

    if harness == "pi":
        tools = WRITE_TOOLS if effective_write else READ_ONLY_TOOLS
        pi_bin = find_binary(["pi-profile", str(Path.home() / "pi-lab/bin/pi-profile")]) if profile.get("pi_profile") else None
        cmd = [pi_bin, profile["pi_profile"], "--"] if pi_bin else ["pi"]
        cmd.extend(["--print", "--no-session", "--mode", "text", "--tools", tools])
        if model != "default":
            cmd.extend(["--model", model])
        if profile.get("thinking"):
            cmd.extend(["--thinking", str(profile["thinking"])])
        return [*cmd, prompt]

    if harness == "opencode":
        cmd = ["opencode", "run", "--dir", str(cwd)]
        if model != "default":
            cmd.extend(["--model", model])
        if profile.get("agent"):
            cmd.extend(["--agent", str(profile["agent"])])
        if profile.get("variant"):
            cmd.extend(["--variant", str(profile["variant"])])
        if skip_permissions:
            cmd.append("--auto")
        return [*cmd, prompt]

    if harness == "codex":
        cmd = ["codex", "exec", "--ephemeral", "-C", str(cwd)]
        if model != "default":
            cmd.extend(["-m", model])
        if skip_permissions:
            cmd.append("--yolo")
        return [*cmd, prompt]

    if harness == "claude":
        cmd = ["claude", "-p", prompt]
        if mode == "read":
            cmd.extend(["--permission-mode", "plan"])
        elif skip_permissions:
            cmd.append("--dangerously-skip-permissions")
        return cmd

    if harness == "dhs":
        dhs_bin = find_binary(["dhs", "dsh", "deepseek-harness"]) or "dhs"
        cmd = [dhs_bin, "exec", "--dir", str(cwd)]
        if model != "default":
            cmd.extend(["--model", model])
        if skip_permissions:
            cmd.append("--yolo")
        return [*cmd, prompt]

    raise SystemExit(f"Unsupported harness: {harness}")


def print_profiles() -> None:
    rows = []
    header = ["profile", "harness", "target / model (dynamic)", "mode", "description"]
    for name, p in DEFAULT_PROFILES.items():
        if p.get("pi_profile"):
            target = f"pi-profile:{p['pi_profile']}"
        else:
            resolved = resolve_dynamic_model(p["harness"], p.get("model_family"), p["model"])
            if p["model"] == "auto":
                target = f"auto -> {resolved}" if resolved != "default" else "auto (none discovered)"
            else:
                target = p["model"]
        rows.append([name, p["harness"], target, p["mode"], p.get("description", "")])

    widths = [max(len(str(r[i])) for r in [header, *rows]) for i in range(len(header))]
    print("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(header)))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        print("  ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def diagnose() -> int:
    print("Universal Harness Adapter — Diagnostics\n========================================")
    for h, binaries in [("codex", ["codex"]), ("claude", ["claude"]), ("dhs", ["dhs", "dsh", "deepseek-harness"]), ("pi", ["pi"]), ("opencode", ["opencode"])]:
        path = find_binary(binaries)
        extra = " (headless runner)" if h == "dhs" else ""
        ver = subprocess.run([path, "--version"], capture_output=True, text=True, check=False).stdout.strip() if path else ""
        print(f"{h:10}: {path or '<missing>'}{extra}" + (f"\n  version : {ver}" if ver else ""))

    pi_prof_bin = find_binary(["pi-profile", str(Path.home() / "pi-lab/bin/pi-profile")])
    pi_profs = available_pi_profiles() if pi_prof_bin else []
    print(f"{'pi-profile':10}: {pi_prof_bin or '<missing>'}")
    if pi_prof_bin:
        print(f"  profiles: {', '.join(pi_profs) or '<none found>'}")

    print("\nDetected Models per Harness:")
    for h in ["codex", "pi", "opencode"]:
        print(f"{h.capitalize()}:")
        mods = sorted(available_models(h))
        for m in (mods or ["<none found>"]):
            print(f"  - {m}")
    print()

    missing = []
    for name, p in DEFAULT_PROFILES.items():
        h = p["harness"]
        bins = ["dhs", "dsh", "deepseek-harness"] if h == "dhs" else [h]
        prof_ok = (p["pi_profile"] in pi_profs) if p.get("pi_profile") else True
        bin_ok = bool(find_binary(bins)) and prof_ok
        resolved = resolve_dynamic_model(h, p.get("model_family"), p["model"])
        model_found = (resolved != "default") if (p["model"] == "auto" and not p.get("pi_profile")) else True

        if not bin_ok:
            status = "MISSING"
            missing.append(name)
        elif not model_found:
            status = "UNREADY"
            missing.append(name)
        else:
            status = "OK"

        if p.get("pi_profile"):
            target = f"pi-profile:{p['pi_profile']}"
        elif p["model"] == "auto":
            target = f"auto ({resolved if model_found else 'none discovered'})"
        else:
            target = p["model"]

        print(f"{status:7} {name:20} [{h}] target={target}")
    return 1 if missing else 0


def resolve_profile(args: argparse.Namespace) -> tuple[str, dict[str, Any]]:
    if args.profile == "auto":
        if not args.task_type:
            raise SystemExit("--profile auto requires --task-type")
        profile_name = TASK_TYPE_DEFAULTS.get(args.task_type)
        if not profile_name:
            raise SystemExit(f"Unknown task type {args.task_type!r}.")
    else:
        profile_name = args.profile

    if profile_name not in DEFAULT_PROFILES:
        raise SystemExit(f"Unknown profile {profile_name!r}.")

    profile = dict(DEFAULT_PROFILES[profile_name])
    if args.model:
        profile["model"] = args.model
    if args.harness:
        profile["harness"] = args.harness
    if args.timeout:
        profile["timeout"] = args.timeout
    if args.pi_profile:
        profile["pi_profile"] = args.pi_profile

    profile["model"] = resolve_dynamic_model(profile["harness"], profile.get("model_family"), profile.get("model"))
    return profile_name, profile


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
    parser.add_argument("--pi-profile", help="Run within an isolated local Pi profile (e.g. lean, gsd, search).")
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

    skip_perms = args.yolo or args.dangerously_skip_permissions
    allow_write = args.allow_write or skip_perms
    profile_name, profile = resolve_profile(args)

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.exists():
        raise SystemExit(f"Working directory does not exist: {cwd}")
    if args.worktree:
        cwd = setup_worktree(cwd, args.worktree)

    # Read task
    task = args.task or (Path(args.task_file).read_text(encoding="utf-8") if args.task_file else None) or (sys.stdin.read() if not sys.stdin.isatty() else None)
    if not task or not task.strip():
        raise SystemExit("Provide --task, --task-file, or stdin.")

    prompt = build_prompt(profile_name, profile, cwd, task, allow_write)
    cmd = command_for(profile, cwd, prompt, allow_write, skip_perms)

    display_cmd = [arg if arg != prompt else "<prompt>" for arg in cmd]
    save_path = Path(args.save_dir).expanduser() / f"{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{profile_name}" if not args.no_save else None

    if args.dry_run:
        print("DRY RUN\nCommand:", " ".join(display_cmd))
        if save_path:
            save_path.mkdir(parents=True, exist_ok=True)
            (save_path / "prompt.md").write_text(prompt + "\n", encoding="utf-8")
            (save_path / "meta.json").write_text(json.dumps({"profile": profile_name, "cwd": str(cwd), "command": display_cmd, "dry_run": True}, indent=2) + "\n", encoding="utf-8")
            print("Run dir:", save_path)
        return 0

    try:
        proc = subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, timeout=int(profile["timeout"]), check=False)
    except subprocess.TimeoutExpired as exc:
        print(f"Timed out after {profile['timeout']}s: {exc}", file=sys.stderr)
        return 124

    if save_path:
        save_path.mkdir(parents=True, exist_ok=True)
        (save_path / "prompt.md").write_text(prompt + "\n", encoding="utf-8")
        (save_path / "stdout.md").write_text(proc.stdout or "", encoding="utf-8")
        (save_path / "stderr.txt").write_text(proc.stderr or "", encoding="utf-8")
        (save_path / "meta.json").write_text(json.dumps({"profile": profile_name, "cwd": str(cwd), "command": display_cmd, "returncode": proc.returncode}, indent=2) + "\n", encoding="utf-8")
        print(f"[multi-harness] run dir: {save_path}", file=sys.stderr)

    if proc.stderr:
        print(proc.stderr, file=sys.stderr, end="")
    print(proc.stdout, end="")
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
