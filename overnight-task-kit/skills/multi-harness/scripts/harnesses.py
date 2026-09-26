"""Command builders and help contracts for supported local harnesses."""

from __future__ import annotations

from pathlib import Path
from typing import Any


CAPABILITY_MATRIX: dict[str, dict[str, Any]] = {
    "codex": {
        "binary": "codex",
        "help_args": ["exec", "--help"],
        "required_flags": ["--ephemeral", "-C", "-m"],
    },
    "claude": {
        "binary": "claude",
        "help_args": ["--help"],
        "required_flags": ["-p", "--model", "--permission-mode", "--dangerously-skip-permissions"],
    },
    "opencode": {
        "binary": "opencode",
        "help_args": ["run", "--help"],
        "required_flags": ["--dir", "--model", "--agent", "--auto"],
    },
    "pi": {
        "binary": "pi",
        "help_args": ["--help"],
        "required_flags": ["--print", "--no-session", "--mode", "--tools", "--model"],
    },
    "pi-profile": {
        "binary": "pi-profile",
        "help_args": ["--help"],
        "required_flags": ["--"],
    },
}


def command_for(
    profile: dict[str, Any],
    cwd: Path,
    prompt: str,
    allow_write: bool,
    skip_permissions: bool,
) -> list[str]:
    """Build argv for one local CLI. Herdr-only targets do not use this module."""
    harness, model, mode = profile["harness"], profile["model"], profile["mode"]
    effective_write = mode == "write" and (allow_write or skip_permissions)
    if mode == "write" and not effective_write:
        raise SystemExit("Profile requires write access. Run with --allow-write or --yolo.")

    if harness == "pi":
        if profile.get("pi_profile"):
            cmd = ["pi-profile", str(profile["pi_profile"]), "--"]
        else:
            cmd = ["pi"]
        tools = "read,grep,find,ls,bash,edit,write" if effective_write else "read,grep,find,ls"
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
        if model != "default":
            cmd.extend(["--model", model])
        if mode == "read":
            cmd.extend(["--permission-mode", "plan"])
        elif skip_permissions:
            cmd.append("--dangerously-skip-permissions")
        return cmd

    raise SystemExit(f"Unsupported harness: {harness}")
