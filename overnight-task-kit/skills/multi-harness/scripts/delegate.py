#!/usr/bin/env python3
"""Universal Harness Adapter — Delegate bounded tasks across local agent harnesses."""

from __future__ import annotations

import argparse
import datetime as dt
import functools
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import textwrap
import uuid
from pathlib import Path
from typing import Any

from harnesses import CAPABILITY_MATRIX, command_for

# Default Profile Declarations (Dynamic model resolution)
DEFAULT_PROFILES: dict[str, dict[str, Any]] = {
    # Codex CLI (ephemeral workers)
    "codex-complex": {"harness": "codex", "model": "auto", "model_family": "gpt", "mode": "write", "timeout": 2400, "description": "Complex worker via Codex CLI. Requires --allow-write or --yolo."},
    "codex-fast": {"harness": "codex", "model": "auto", "model_family": "luna", "mode": "read", "timeout": 1200, "description": "Fast exploration worker via Codex CLI."},
    "codex-review": {"harness": "codex", "model": "auto", "model_family": "sol", "mode": "read", "timeout": 1800, "description": "Independent verifier/reviewer via Codex CLI."},

    # Claude Code CLI
    "claude-review": {"harness": "claude", "model": "auto", "mode": "read", "timeout": 1800, "description": "Adversarial code review via Claude Code CLI."},
    "claude-implement": {"harness": "claude", "model": "auto", "mode": "write", "timeout": 2400, "description": "Scoped implementation via Claude Code CLI. Requires --allow-write or --yolo."},

    # Pi CLI (dynamic frontier model resolution from local models.json)
    "pi-glm-review": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "xhigh", "mode": "read", "timeout": 1800, "description": "Deep read-only review with latest local GLM frontier model via Pi."},
    "pi-glm-plan": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Read-only planning with latest local GLM model via Pi."},
    "pi-glm-debug": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Read-only debugging with latest local GLM model via Pi."},
    "pi-glm-implement": {"harness": "pi", "model": "auto", "model_family": "glm", "thinking": "high", "mode": "write", "timeout": 2400, "description": "Scoped implementation with latest local GLM model via Pi. Requires --allow-write or --yolo."},
    "pi-deepseek-review": {"harness": "pi", "model": "auto", "model_family": "deepseek", "thinking": "high", "mode": "read", "timeout": 1800, "description": "Deep review with latest local DeepSeek model via Pi."},
    "pi-minimax-large": {"harness": "pi", "model": "auto", "model_family": "minimax", "thinking": "medium", "mode": "read", "timeout": 1800, "description": "Large-context read-only sweep with latest local MiniMax model via Pi."},

    # Pi-Profile Isolated Environments
    "pi-lean": {"harness": "pi", "pi_profile": "lean", "model": "default", "mode": "read", "timeout": 1800, "description": "Isolated lightweight Pi runner via local pi-profile lean."},
    "pi-gsd": {"harness": "pi", "pi_profile": "gsd", "model": "default", "mode": "read", "timeout": 1800, "description": "GSD-enhanced Pi runner via local pi-profile gsd."},
    "pi-search": {"harness": "pi", "pi_profile": "search", "model": "default", "mode": "read", "timeout": 1800, "description": "Research and web search Pi runner via local pi-profile search."},

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

# Worker contract mode (--task-json): task_id doubles as the worktree slug.
TASK_ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")
CONTRACT_STATUSES = ("done", "blocked", "failed")


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


def load_model_catalog(path: str) -> tuple[set[str], str | None]:
    catalog_path = Path(path).expanduser().resolve()
    if not catalog_path.is_file():
        raise SystemExit(f"Model catalog not found: {catalog_path}")
    try:
        data = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"Could not read model catalog {catalog_path}: {exc}")
    if not isinstance(data, dict) or not isinstance(data.get("models"), list):
        raise SystemExit(f"Invalid model catalog {catalog_path}: expected an object with a models array.")

    models = {item["id"] for item in data["models"] if isinstance(item, dict) and isinstance(item.get("id"), str) and item["id"]}
    default = data.get("default")
    if default is not None and (not isinstance(default, str) or default not in models):
        raise SystemExit(f"Invalid model catalog {catalog_path}: default must match a models[].id value.")
    return models, default


@functools.lru_cache(maxsize=16)
def available_models(harness: str, model_catalog: str | None = None) -> set[str]:
    """Extract registered model IDs from local harness config files."""
    if harness in {"codex", "claude"}:
        return load_model_catalog(model_catalog)[0] if model_catalog else set()

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
    return set()


def available_pi_profiles() -> list[str]:
    """Detect profiles under the caller-configured Pi profile directory."""
    base = Path(os.environ["PI_PROFILE_DIR"]).expanduser() if os.environ.get("PI_PROFILE_DIR") else None
    if base is None or not base.is_dir():
        return []
    return sorted(d.name for d in base.iterdir() if d.is_dir() and not d.name.startswith("."))


def resolve_dynamic_model(
    harness: str,
    family: str | None,
    explicit_model: str | None,
    model_catalog: str | None = None,
) -> str:
    """Dynamically resolve to the newest active frontier model in local configurations."""
    if explicit_model and explicit_model != "auto":
        return explicit_model

    catalog_default = None
    if harness in {"codex", "claude"} and model_catalog:
        models, catalog_default = load_model_catalog(model_catalog)
    else:
        models = available_models(harness, model_catalog)
    if not family:
        if catalog_default in models:
            return catalog_default
        if len(models) == 1:
            return next(iter(models))
        return "default"

    matching = [m for m in models if family.lower() in m.lower()]
    if not matching:
        return "default"

    # ponytail: sort by extracted floating-point version descending to pick newest frontier
    def version_key(s: str) -> tuple[float, str]:
        matches = re.findall(r"(\d+(?:\.\d+)?)", s)
        return (float(matches[-1]) if matches else 0.0, s)

    return sorted(matching, key=version_key, reverse=True)[0]


def setup_worktree(repo_root: Path, slug: str, create: bool = True) -> Path:
    """Safely create or attach to an isolated git worktree under .worktrees/<slug>."""
    if not re.match(r"^[a-zA-Z0-9_-]+$", slug):
        raise SystemExit(f"Invalid worktree slug {slug!r}. Alphanumeric, dashes, and underscores only.")

    git_root_proc = subprocess.run(["git", "-C", str(repo_root), "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if git_root_proc.returncode == 0 and git_root_proc.stdout.strip():
        repo_root = Path(git_root_proc.stdout.strip()).resolve()

    worktrees_root = (repo_root / ".worktrees").resolve()
    worktree_dir = (worktrees_root / slug).resolve()
    if not str(worktree_dir).startswith(str(worktrees_root)):
        raise SystemExit(f"Security error: worktree path {worktree_dir} escapes {worktrees_root}")

    if not create:
        return worktree_dir

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


def build_prompt(profile_name: str, profile: dict[str, Any], cwd: Path, task: str, allow_write: bool, contract: dict[str, Any] | None = None) -> str:
    mode = "WRITE_ALLOWED" if profile["mode"] == "write" and allow_write else "READ_ONLY"
    mode_rule = "- Do not modify files or mutate the workspace." if mode == "READ_ONLY" else "- Keep edits tightly scoped to the task and report every changed file."

    # Contract mode: the return format (result.json) already ships inside the task block.
    if contract:
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
        """).strip()

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


def load_task_contract(path: Path) -> dict[str, Any]:
    """Load and validate a task.json worker contract (stdlib only)."""
    if not path.is_file():
        raise SystemExit(f"Task contract not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid task contract {path}: not valid JSON (line {exc.lineno}, column {exc.colno}).")

    def fail(msg: str) -> None:
        raise SystemExit(f"Invalid task contract {path}: {msg}")

    if not isinstance(data, dict):
        fail("top-level value must be a JSON object.")
    for field in ("task_id", "objective", "scope", "acceptance"):
        if field not in data:
            fail(f"missing required field {field!r}.")
    if not isinstance(data["task_id"], str) or not TASK_ID_RE.fullmatch(data["task_id"]):
        fail("field 'task_id' must be a string matching ^[A-Za-z0-9_-]+$ (it doubles as the worktree slug).")
    if not isinstance(data["objective"], str) or not data["objective"].strip():
        fail("field 'objective' must be a non-empty string.")
    for field in ("scope", "acceptance"):
        value = data[field]
        if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
            fail(f"field {field!r} must be a non-empty array of non-empty strings.")
    constraints = data.get("constraints") or []
    if not isinstance(constraints, list) or not all(isinstance(item, str) and item.strip() for item in constraints):
        fail("field 'constraints' must be an array of non-empty strings.")
    budget = data.get("budget") or {}
    if not isinstance(budget, dict):
        fail("field 'budget' must be an object.")
    timeout_min = budget.get("timeout_min", 15)
    if isinstance(timeout_min, bool) or not isinstance(timeout_min, int) or timeout_min < 1:
        fail("field 'budget.timeout_min' must be an integer >= 1.")
    feedback = data.get("feedback")
    if feedback is not None and not isinstance(feedback, str):
        fail("field 'feedback' must be a string or null.")
    return {**data, "constraints": constraints, "budget": {"timeout_min": timeout_min}}


def contract_task_block(t: dict[str, Any]) -> str:
    """Render the fixed worker prompt from a validated task.json."""
    constraints = "; ".join(t["constraints"])
    constraint_line = f"{constraints}; " if constraints else ""
    feedback = f"\n\nFEEDBACK from previous attempt:\n{t['feedback'].strip()}" if t.get("feedback") else ""
    return textwrap.dedent(f"""
        TASK: {t['objective'].strip()}
        SCOPE: {', '.join(t['scope'])}
        CONSTRAINTS: {constraint_line}do not git commit or push; do not leave the worktree.
        VERIFICATION: run from worktree root and ensure exit 0: {' && '.join(t['acceptance'])}
        FORMAT: write `result.json` at worktree root with {{"task_id": "{t['task_id']}", "status": "done|blocked|failed", "notes": "<summary <=5 lines>", "blocker": "<required if status != done>"}} and end with a summary of <=10 lines.{feedback}
    """).strip()


def validate_result_contract(data: Any, task_id: str) -> tuple[str | None, str]:
    """Validate the worker's result.json. Returns (status, detail); status is None when invalid."""
    if not isinstance(data, dict):
        return None, "result.json is not a JSON object."
    for field in ("task_id", "status", "notes"):
        if field not in data:
            return None, f"result.json is missing required field {field!r}."
    status = data.get("status")
    if status not in CONTRACT_STATUSES:
        return None, f"result.json field 'status' must be one of {', '.join(CONTRACT_STATUSES)} (got {status!r})."
    if data.get("task_id") != task_id:
        return None, f"result.json field 'task_id' is {data.get('task_id')!r}, expected {task_id!r}."
    notes = data.get("notes")
    if not isinstance(notes, str):
        return None, "result.json field 'notes' must be a string."
    blocker = data.get("blocker")
    if status != "done" and (not isinstance(blocker, str) or not blocker.strip()):
        return None, f"result.json field 'blocker' must be a non-empty string when status is {status!r}."
    if status == "done" and blocker is not None:
        return None, "result.json field 'blocker' must be null when status is 'done'."
    return status, "ok"


def check_worker_result(worktree: Path, task_id: str) -> tuple[str | None, str]:
    """Read and validate result.json at the root of the target worktree."""
    result_path = worktree / "result.json"
    if not result_path.is_file():
        return "failed", f"worker did not write {result_path}."
    try:
        data = json.loads(result_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return "failed", f"result.json is not valid JSON ({exc})."
    return validate_result_contract(data, task_id)


def append_event(root: Path, task_id: str, event: str, harness: str, status: str | None) -> None:
    """Append one JSON line to the orchestrator-side log .agent-runs/orchestration/events.jsonl (gitignored)."""
    record = {
        "ts": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "task_id": task_id,
        "event": event,
        "harness": harness,
        "status": status,
    }
    path = root / ".agent-runs/orchestration/events.jsonl"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
    except OSError as exc:
        print(f"[multi-harness] warning: could not append {event!r} event to {path}: {exc}", file=sys.stderr)


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


def diagnose(model_catalog: str | None = None) -> int:
    print("Universal Harness Adapter — Diagnostics\n========================================")
    if not model_catalog:
        print("Codex and Claude auto profiles need --model-catalog or explicit --model.")
    for h in ("codex", "claude", "pi", "opencode"):
        path = find_binary([CAPABILITY_MATRIX[h]["binary"]])
        ver = subprocess.run([path, "--version"], capture_output=True, text=True, check=False).stdout.strip() if path else ""
        print(f"{h:10}: {path or '<missing>'}" + (f"\n  version : {ver}" if ver else ""))

    pi_prof_bin = find_binary(["pi-profile"])
    pi_profs = available_pi_profiles() if pi_prof_bin else []
    print(f"{'pi-profile':10}: {pi_prof_bin or '<missing>'}")
    if pi_prof_bin:
        print(f"  profiles: {', '.join(pi_profs) or '<none found>'}")

    print("\nDetected Models per Harness:")
    for h in ["codex", "claude", "pi", "opencode"]:
        print(f"{h.capitalize()}:")
        catalog = model_catalog if h in {"codex", "claude"} else None
        mods = sorted(available_models(h, catalog))
        for m in (mods or ["<none found>"]):
            print(f"  - {m}")
    print()

    missing = []
    for name, p in DEFAULT_PROFILES.items():
        h = p["harness"]
        bins = ["pi-profile"] if p.get("pi_profile") else [h]
        prof_ok = (p["pi_profile"] in pi_profs) if p.get("pi_profile") else True
        bin_ok = bool(find_binary(bins)) and prof_ok
        catalog = model_catalog if h in {"codex", "claude"} else None
        resolved = resolve_dynamic_model(h, p.get("model_family"), p["model"], catalog)
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
        if args.harness != profile["harness"]:
            profile.pop("model_family", None)
        profile["harness"] = args.harness
        if args.harness == "mcode":
            if args.model:
                raise SystemExit("mcode uses the model already selected in its Herdr pane; do not pass --model.")
            if not getattr(args, "mcode_pane_id", None):
                raise SystemExit("mcode requires an explicit --mcode-pane-id.")
            profile["model"] = "default"
    if args.timeout:
        profile["timeout"] = args.timeout
    if args.pi_profile:
        profile["pi_profile"] = args.pi_profile

    model_catalog = getattr(args, "model_catalog", None)
    if model_catalog and profile["harness"] not in {"codex", "claude"}:
        raise SystemExit("--model-catalog is supported only for Codex and Claude profiles.")
    model = resolve_dynamic_model(profile["harness"], profile.get("model_family"), profile.get("model"), model_catalog)
    if profile.get("model") == "auto" and model == "default" and not profile.get("pi_profile"):
        if profile["harness"] in {"codex", "claude"}:
            source = "a valid --model-catalog or explicit --model"
        else:
            source = "a matching configured model or explicit --model"
        raise SystemExit(f"No model discovered for profile {profile_name!r} ({profile['harness']}); provide {source}.")
    profile["model"] = model
    return profile_name, profile


def herdr_json(args: list[str]) -> dict[str, Any] | None:
    try:
        proc = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    result = payload.get("result") if isinstance(payload, dict) else None
    return result if isinstance(result, dict) else None


def same_herdr_directory(row: dict[str, Any], cwd: Path) -> bool:
    def matches(path: Any) -> bool:
        if not isinstance(path, str) or not path:
            return False
        try:
            return Path(path).expanduser().resolve() == cwd.resolve()
        except OSError:
            return False

    return matches(row.get("cwd")) and matches(row.get("foreground_cwd"))


def foreground_is_mcode(process_info: dict[str, Any], pane_id: str) -> bool:
    if process_info.get("pane_id") != pane_id:
        return False
    processes = process_info.get("foreground_processes")
    if not isinstance(processes, list):
        return False

    runtimes = {"node", "nodejs", "bun", "deno", "python", "python3", "npm", "npx"}
    for process in processes:
        if not isinstance(process, dict):
            continue
        argv = process.get("argv") if isinstance(process.get("argv"), list) else []
        cmdline = process.get("cmdline")
        try:
            cmdline_argv = shlex.split(cmdline) if isinstance(cmdline, str) else []
        except ValueError:
            cmdline_argv = []
        candidates = [process.get("name")]
        if argv:
            candidates.extend(argv[:2] if Path(str(argv[0])).name.casefold() in runtimes else argv[:1])
        if cmdline_argv:
            candidates.extend(cmdline_argv[:2] if Path(cmdline_argv[0]).name.casefold() in runtimes else cmdline_argv[:1])
        if any(isinstance(value, str) and Path(value).name.casefold() in {"mcode", "mcode.exe"} for value in candidates):
            return True
    return False


def herdr_dispatch_result(args: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    except OSError as exc:
        return subprocess.CompletedProcess(args, 127, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else exc.stdout or ""
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else exc.stderr or ""
        return subprocess.CompletedProcess(args, 124, stdout, stderr or f"Herdr dispatch timed out after {timeout}s.")


def herdr_response_text(value: Any) -> str | None:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = [herdr_response_text(item) for item in value]
        return "\n".join(part for part in parts if part is not None)
    if isinstance(value, dict):
        for key in ("text", "output", "content", "transcript", "recent_unwrapped", "recent-unwrapped"):
            if key in value:
                text = herdr_response_text(value[key])
                if text is not None:
                    return text
        for key in ("result", "data", "snapshot"):
            if key in value:
                text = herdr_response_text(value[key])
                if text is not None:
                    return text
    return None


def herdr_read_output(args: list[str], timeout: int = 15) -> subprocess.CompletedProcess[str]:
    proc = herdr_dispatch_result(args, timeout)
    if proc.returncode != 0:
        return proc
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return proc
    result = payload.get("result") if isinstance(payload, dict) else payload
    text = herdr_response_text(result)
    if text is None:
        return subprocess.CompletedProcess(args, 1, "", "Herdr read returned no transcript text.")
    return subprocess.CompletedProcess(args, proc.returncode, text, proc.stderr)


def dispatch_with_herdr(
    profile: dict[str, Any], cwd: Path, prompt: str, timeout: int, mcode_pane_id: str | None = None
) -> subprocess.CompletedProcess[str] | None:
    """Reuse a same-directory idle agent or an explicitly selected mcode pane."""
    if os.environ.get("HERDR_ENV") != "1":
        return None
    timeout_ms = max(1, int(timeout * 1000))
    harness = profile["harness"]

    if harness == "mcode":
        if not mcode_pane_id:
            return None
        listing = herdr_json(["pane", "list"])
        panes = listing.get("panes", []) if listing else []
        for pane in panes:
            if not isinstance(pane, dict) or pane.get("pane_id") != mcode_pane_id:
                continue
            agent = pane.get("agent")
            status = pane.get("agent_status")
            if status in {"working", "blocked"} or not same_herdr_directory(pane, cwd):
                continue
            if agent:
                if str(agent).casefold() != "mcode" or status != "idle":
                    continue
            elif status != "unknown":
                continue
            details = herdr_json(["pane", "process-info", "--pane", mcode_pane_id])
            process_info = details.get("process_info", {}) if details else {}
            if not isinstance(process_info, dict) or not foreground_is_mcode(process_info, mcode_pane_id):
                continue

            sentinel = f"MULTI_HARNESS_DONE_{uuid.uuid4().hex}"
            task = f"{prompt}\n\nWhen finished, print exactly {sentinel} on a line by itself."
            run_args = ["herdr", "pane", "run", mcode_pane_id, task]
            sent = herdr_dispatch_result(run_args, 15)
            if sent.returncode != 0:
                return sent
            settled = herdr_dispatch_result(
                ["herdr", "pane", "wait-output", "--match", sentinel, mcode_pane_id, "--timeout", str(timeout_ms)],
                timeout + 5,
            )
            if settled.returncode != 0:
                return settled
            response = herdr_read_output(
                ["herdr", "pane", "read", "--source", "recent-unwrapped", mcode_pane_id]
            )
            if response.returncode == 0:
                response.stdout = "\n".join(line for line in response.stdout.splitlines() if line.strip() != sentinel)
            return response
        return None

    listing = herdr_json(["agent", "list"])
    agents = listing.get("agents", []) if listing else []
    for agent in agents:
        if not isinstance(agent, dict) or agent.get("agent_status") != "idle" or not same_herdr_directory(agent, cwd):
            continue
        if str(agent.get("agent", "")).casefold() != harness.casefold():
            continue
        target = agent.get("pane_id")
        if isinstance(target, str) and target:
            dispatched = herdr_dispatch_result(
                ["herdr", "agent", "prompt", target, prompt, "--wait", "--timeout", str(timeout_ms)],
                timeout + 5,
            )
            if dispatched.returncode != 0:
                return dispatched
            return herdr_read_output(["herdr", "agent", "read", target, "--source", "recent-unwrapped"])
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="auto", help="Profile name, or auto with --task-type.")
    parser.add_argument("--task-type", choices=sorted(TASK_TYPE_DEFAULTS), help="Routing hint for --profile auto.")
    parser.add_argument("--task", help="Delegated task text.")
    parser.add_argument("--task-file", help="Read delegated task text from file.")
    parser.add_argument("--task-json", help="Load a validated task.json worker contract (contract mode) instead of free text.")
    parser.add_argument("--cwd", default=os.getcwd(), help="Working directory for the delegated harness.")
    parser.add_argument("--worktree", help="Isolate task in a dedicated git worktree under .worktrees/<slug>.")
    parser.add_argument("--timeout", type=int, help="Override timeout in seconds.")
    parser.add_argument("--model", help="Override model for the selected profile.")
    parser.add_argument("--model-catalog", help="Explicit JSON model catalog for Codex or Claude auto-selection.")
    parser.add_argument("--mcode-pane-id", help="Explicit Herdr pane ID for an mcode dispatch.")
    parser.add_argument("--pi-profile", help="Run within an isolated local Pi profile (e.g. lean, gsd, search).")
    parser.add_argument("--harness", choices=["pi", "opencode", "codex", "claude", "mcode"], help="Override harness.")
    parser.add_argument("--allow-write", action="store_true", help="Allow a write-capable profile to run.")
    parser.add_argument("--yolo", action="store_true", help="Bypass confirmation prompts and skip permissions.")
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
        return diagnose(args.model_catalog)

    skip_perms = args.yolo
    allow_write = args.allow_write or skip_perms
    profile_name, profile = resolve_profile(args)
    if args.mcode_pane_id and profile["harness"] != "mcode":
        raise SystemExit("--mcode-pane-id requires --harness mcode.")

    contract: dict[str, Any] | None = None
    if args.task_json:
        if args.task or args.task_file:
            raise SystemExit("--task-json cannot be combined with --task or --task-file.")
        if not allow_write or profile["mode"] != "write":
            raise SystemExit("Contract mode requires a write-capable profile with --allow-write: the worker must write result.json in the worktree.")
        contract = load_task_contract(Path(args.task_json).expanduser().resolve())
        if args.worktree and args.worktree != contract["task_id"]:
            raise SystemExit(f"--worktree {args.worktree!r} does not match task_id {contract['task_id']!r} from the task contract.")
        if not args.timeout:
            profile["timeout"] = contract["budget"]["timeout_min"] * 60
    harness_label = f"{profile['harness']}:{profile.get('pi_profile', profile_name)}"

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.exists():
        raise SystemExit(f"Working directory does not exist: {cwd}")
    orchestrator_root = cwd
    if args.worktree or contract:
        cwd = setup_worktree(cwd, args.worktree or contract["task_id"], create=not args.dry_run)

    # Read task
    if contract:
        task = contract_task_block(contract)
    else:
        task = args.task or (Path(args.task_file).read_text(encoding="utf-8") if args.task_file else None) or (sys.stdin.read() if not sys.stdin.isatty() else None)
        if not task or not task.strip():
            raise SystemExit("Provide --task, --task-file, or stdin.")

    prompt = build_prompt(profile_name, profile, cwd, task, allow_write, contract=contract)
    if profile["harness"] == "mcode":
        if profile["mode"] == "write" and not allow_write:
            raise SystemExit("Profile requires write access. Run with --allow-write or --yolo.")
        cmd = []
        display_cmd = ["Herdr mcode pane", "<idle same-directory target>", "<prompt>", "<completion sentinel>"]
    else:
        cmd = command_for(profile, cwd, prompt, allow_write, skip_perms)
        display_cmd = [arg if arg != prompt else "<prompt>" for arg in cmd]
    save_path = Path(args.save_dir).expanduser() / f"{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{profile_name}" if not args.no_save else None

    if args.dry_run:
        print("DRY RUN\nCommand:", " ".join(display_cmd))
        if contract:
            print("\nPrompt:\n" + prompt)
        return 0

    if contract:
        result_path = cwd / "result.json"
        try:
            result_path.unlink()
        except FileNotFoundError:
            pass
        append_event(orchestrator_root, contract["task_id"], "dispatch", harness_label, None)

    try:
        proc = dispatch_with_herdr(profile, cwd, prompt, int(profile["timeout"]), args.mcode_pane_id)
        if proc is None and profile["harness"] == "mcode":
            if contract:
                append_event(orchestrator_root, contract["task_id"], "result", harness_label, "failed")
            print("Error: mcode requires HERDR_ENV=1 and an idle mcode pane in the task directory.", file=sys.stderr)
            return 2
        if proc is None:
            proc = subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, timeout=int(profile["timeout"]), check=False)
    except FileNotFoundError:
        if contract:
            append_event(orchestrator_root, contract["task_id"], "result", harness_label, "failed")
        print(f"Error: Harness executable '{cmd[0]}' not found. Run --diagnose to check installed harnesses.", file=sys.stderr)
        return 127
    except subprocess.TimeoutExpired as exc:
        if contract:
            append_event(orchestrator_root, contract["task_id"], "result", harness_label, "failed")
        print(f"Timed out after {profile['timeout']}s: {exc}", file=sys.stderr)
        return 124

    # Contract mode: validate result.json at the worktree root and log the outcome.
    result_status: str | None = None
    result_detail = ""
    if contract:
        result_status, result_detail = check_worker_result(cwd, contract["task_id"])
        append_event(orchestrator_root, contract["task_id"], "result", harness_label, result_status or "failed")

    if save_path:
        save_path.mkdir(parents=True, exist_ok=True)
        (save_path / "prompt.md").write_text(prompt + "\n", encoding="utf-8")
        (save_path / "stdout.md").write_text(proc.stdout or "", encoding="utf-8")
        (save_path / "stderr.txt").write_text(proc.stderr or "", encoding="utf-8")
        meta: dict[str, Any] = {"profile": profile_name, "cwd": str(cwd), "command": display_cmd, "returncode": proc.returncode}
        if contract:
            meta["task_id"] = contract["task_id"]
            meta["status"] = result_status or "failed"
        (save_path / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"[multi-harness] run dir: {save_path}", file=sys.stderr)

    if proc.stderr:
        print(proc.stderr, file=sys.stderr, end="")
    print(proc.stdout, end="")

    if contract and result_status != "done":
        print(f"[multi-harness] contract check failed: {result_detail}", file=sys.stderr)
        return proc.returncode or 1
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
