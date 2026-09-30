#!/usr/bin/env python3
"""Audit a repository against the Agent-Native Repository Specification (ANRS-1.0).

Verifies:
1. Root AGENTS.md exists and respects the token budget (<= 150 lines).
2. Root AGENTS.md contains a valid Semantic Routing Table with reachable links.
3. Root REGISTRY.yaml exists and contains basic schema keys.
4. Directory tree depth does not exceed recommended ergonomic limits (<= 4).
5. Workspace profile only: foundation files and folders exist (warnings, never failures).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

IGNORED_DIRS = {
    ".git",
    ".github",
    ".venv",
    "venv",
    "node_modules",
    ".worktrees",
    ".ruff_cache",
    ".pytest_cache",
    ".cache",
    "dist",
    "build",
    "_build",
    "deps",
    "graphify-out",
}

# Workspace profile: active when 2+ markers exist, or when forced with --profile workspace.
WORKSPACE_MARKERS = ("PROJECT.md", "STATUS.md", "inbox", "areas", "work")
WORKSPACE_FILES = ("PROJECT.md", "STATUS.md", "DECISIONS.md")
WORKSPACE_DIRS = (
    "inbox",
    "areas",
    "work/queued",
    "work/active",
    "work/completed",
    "resources",
    "outputs",
    "archive",
)


def check_root_agents_md(root: Path, max_lines: int) -> list[str]:
    errors = []
    agents_md = root / "AGENTS.md"
    if not agents_md.exists():
        return [f"Missing root AGENTS.md at {agents_md}"]

    try:
        lines = agents_md.read_text(encoding="utf-8").splitlines()
    except Exception as exc:
        return [f"Failed to read AGENTS.md: {exc}"]

    line_count = len(lines)
    if line_count > max_lines:
        errors.append(
            f"AGENTS.md exceeds token budget: {line_count} lines (recommended max: {max_lines} lines)"
        )

    # Check for Semantic Routing Table links
    content = "\n".join(lines)
    link_pattern = re.compile(r"\[.*?\]\((.*?\.md|.*?\.yaml|.*?\.yml)\)")
    found_links = link_pattern.findall(content)

    if not found_links:
        errors.append("AGENTS.md does not contain a Semantic Routing Table with markdown file links.")
    else:
        for link in found_links:
            # Clean anchors and file schemes
            clean_link = link.split("#")[0].replace("file://", "").strip()
            if clean_link.startswith("/") or clean_link.startswith("http"):
                continue
            target = (root / clean_link).resolve()
            if not target.exists():
                errors.append(f"Broken link in AGENTS.md routing table: {link} -> {target}")

    return errors


def check_registry_yaml(root: Path) -> list[str]:
    errors = []
    registry = root / "REGISTRY.yaml"
    if not registry.exists():
        registry_alt = root / "REGISTRY.yml"
        if registry_alt.exists():
            registry = registry_alt
        else:
            return ["Missing declarative catalog: REGISTRY.yaml at repository root"]

    try:
        content = registry.read_text(encoding="utf-8")
        if "version:" not in content:
            errors.append("REGISTRY.yaml is missing required 'version' field.")
    except Exception as exc:
        errors.append(f"Failed to parse REGISTRY.yaml: {exc}")

    return errors


def workspace_profile_active(root: Path, mode: str) -> bool:
    if mode != "auto":
        return mode == "workspace"
    return sum((root / marker).exists() for marker in WORKSPACE_MARKERS) >= 2


def check_workspace_profile(root: Path) -> list[str]:
    warnings = [f"Missing foundation file: {name}" for name in WORKSPACE_FILES if not (root / name).is_file()]
    warnings += [f"Missing foundation folder: {name}/" for name in WORKSPACE_DIRS if not (root / name).is_dir()]
    return warnings


def check_directory_depth(root: Path, max_depth: int) -> list[str]:
    warnings = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Filter ignored directories in-place
        dirnames[:] = [d for d in dirnames if d not in IGNORED_DIRS and not d.startswith(".")]

        rel_path = Path(dirpath).relative_to(root)
        if rel_path == Path("."):
            continue

        depth = len(rel_path.parts)
        if depth > max_depth:
            warnings.append(
                f"Directory path exceeds ergonomic depth ({depth} > {max_depth}): {rel_path}"
            )

    return warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".", help="Target repository root path (default: current dir)")
    parser.add_argument("--max-lines", type=int, default=150, help="Max line count for root AGENTS.md (default: 150)")
    parser.add_argument("--max-depth", type=int, default=4, help="Max directory depth threshold (default: 4)")
    parser.add_argument("--strict-depth", action="store_true", help="Treat directory depth warnings as hard failures")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format")
    parser.add_argument(
        "--profile",
        choices=["auto", "workspace", "none"],
        default="auto",
        help="Workspace profile: auto-detect (default), force on, or force off",
    )
    args = parser.parse_args(argv)

    root = Path(args.repo_root).resolve()
    if not root.is_dir():
        print(f"Error: {root} is not a directory", file=sys.stderr)
        return 2

    agents_errors = check_root_agents_md(root, args.max_lines)
    registry_errors = check_registry_yaml(root)
    depth_warnings = check_directory_depth(root, args.max_depth)
    workspace = workspace_profile_active(root, args.profile)
    workspace_warnings = check_workspace_profile(root) if workspace else []

    hard_errors = agents_errors + registry_errors
    if args.strict_depth:
        hard_errors += depth_warnings

    passed = len(hard_errors) == 0

    if args.json:
        result = {
            "root": str(root),
            "status": "PASS" if passed else "FAIL",
            "hard_error_count": len(hard_errors),
            "depth_warning_count": len(depth_warnings),
            "checks": {
                "agents_md": {"passed": len(agents_errors) == 0, "errors": agents_errors},
                "registry_yaml": {"passed": len(registry_errors) == 0, "errors": registry_errors},
                "directory_depth": {"warning_count": len(depth_warnings), "warnings": depth_warnings[:10]},
            },
        }
        if workspace:
            result["profile"] = "workspace"
            result["checks"]["workspace_profile"] = {
                "warning_count": len(workspace_warnings),
                "warnings": workspace_warnings,
            }
        print(json.dumps(result, indent=2))
    else:
        print(f"--- Agent-Native Repository Audit (ANRS-1.0) ---")
        print(f"Target Root: {root}")
        print(f"Status: {'✅ PASS' if passed else '❌ FAIL'} ({len(hard_errors)} error(s), {len(depth_warnings)} depth warning(s))\n")

        if agents_errors:
            print("❌ Root AGENTS.md Issues:")
            for err in agents_errors:
                print(f"  - {err}")
        else:
            print("✅ Root AGENTS.md: Budget and Routing Table OK")

        if registry_errors:
            print("\n❌ REGISTRY.yaml Issues:")
            for err in registry_errors:
                print(f"  - {err}")
        else:
            print("✅ REGISTRY.yaml: Present and Formatted")

        if depth_warnings:
            print(f"\n⚠️ Directory Depth Warnings ({len(depth_warnings)} paths > depth {args.max_depth}):")
            for err in depth_warnings[:10]:
                print(f"  - {err}")
            if len(depth_warnings) > 10:
                print(f"  ... and {len(depth_warnings) - 10} more")
        else:
            print(f"✅ Directory Hierarchy: Shallow (<= {args.max_depth} depth)")

        if workspace and workspace_warnings:
            print(f"\n⚠️ Workspace Profile Warnings ({len(workspace_warnings)}):")
            for warn in workspace_warnings:
                print(f"  - {warn}")
        elif workspace:
            print("✅ Workspace Profile: Foundation complete")

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
