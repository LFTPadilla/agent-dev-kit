"""Command builders and help contracts for supported local harnesses."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

CAPABILITY_MATRIX: dict[str, dict[str, Any]] = {
    "codex": {
        "binary": "codex",
        "help_args": ["exec", "--help"],
        "required_flags": ["--ephemeral", "-C", "-m", "--sandbox", "--dangerously-bypass-approvals-and-sandbox"],
    },
    "claude": {
        "binary": "claude",
        "help_args": ["--help"],
        "required_flags": ["-p", "--model", "--permission-mode", "--dangerously-skip-permissions"],
    },
    "opencode": {
        "binary": "opencode",
        "help_args": ["run", "--help"],
        "required_flags": ["--dir", "--model", "--agent", "--variant", "--auto"],
    },
    "pi": {
        "binary": "pi",
        "help_args": ["--help"],
        "required_flags": ["--print", "--no-session", "--mode", "--tools", "--model", "--thinking"],
    },
    "pi-profile": {
        "binary": "pi-profile",
        "help_args": ["--help"],
        "required_flags": ["--"],
    },
}


def has_flag(help_text: str, flag: str) -> bool:
    pattern = rf"(?<![A-Za-z0-9_-]){re.escape(flag)}(?![A-Za-z0-9_-])"
    return re.search(pattern, help_text) is not None


def command_for(
    profile: dict[str, Any],
    cwd: Path,
    prompt: str,
    allow_write: bool,
    skip_permissions: bool,
) -> list[str]:
    """Build argv for one local CLI. Herdr-only targets do not use this module."""
    harness, model, mode = profile["harness"], profile["model"], profile["mode"]
    yolo = mode == "write" and skip_permissions
    effective_write = mode == "write" and (allow_write or yolo)
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
        if yolo:
            cmd.append("--auto")
        return [*cmd, prompt]

    if harness == "codex":
        cmd = ["codex", "exec", "--ephemeral", "-C", str(cwd)]
        if model != "default":
            cmd.extend(["-m", model])
        if yolo:
            cmd.append("--dangerously-bypass-approvals-and-sandbox")
        elif effective_write:
            cmd.extend(["--sandbox", "workspace-write"])
        return [*cmd, prompt]

    if harness == "claude":
        cmd = ["claude", "-p", prompt]
        if model != "default":
            cmd.extend(["--model", model])
        if mode == "read":
            cmd.extend(["--permission-mode", "plan"])
        elif yolo:
            cmd.append("--dangerously-skip-permissions")
        else:
            cmd.extend(["--permission-mode", "acceptEdits"])
        return cmd

    raise SystemExit(f"Unsupported harness: {harness}")
