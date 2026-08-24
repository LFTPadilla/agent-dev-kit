---
name: multi-harness
description: Universal Harness Adapter — Delegate bounded coding-agent work across local agent harnesses (Pi, OpenCode, Codex CLI, Claude Code CLI). Use for explicit cross-harness requests, model comparisons, external-only runtimes, or named models requiring a CLI fallback. Do not use for generic requests to spawn subagents already exposed by the current session.
---

# Multi Harness (Universal Harness Adapter)

Coordinate local agent harnesses without losing control of scope, safety, or verification.

Use this skill as the primary agent. You remain the orchestrator: decide what to delegate, run the external harness, inspect its output and any file changes, then synthesize the result for the user.

## Routing Gate

Apply this gate before diagnostics, profile selection, or running `delegate.py`:

1. Default to the current harness's native subagents when they expose the requested model. Requests for generic subagents, workers, parallelism, or orchestration are not external-harness requests.
2. Use this skill only with an explicit external signal: Pi, OpenCode, Codex CLI, Claude CLI, another/external/cross harness, multiple distinct harnesses, harness comparison, or an external-only runtime the user has asked to use.
3. When the user explicitly requests an external runtime or specific CLI model, use the Universal Harness Adapter (`delegate.py`).
4. If this skill was auto-triggered without an external signal or an unavailable explicitly named model, do not run diagnostics or delegation scripts. Continue using the current harness's native subagent tools.
5. If the requested harness or model is not available locally, report the limitation. Do not silently switch models or harnesses without user confirmation.

Examples:
- "Spawn three Codex subagents" -> native Codex subagents when exposed; otherwise use the Codex CLI profile in this skill.
- "Parallelize the review with subagents" -> native subagents; do not use `multi-harness`.
- "Delegate this review to Pi with GLM-5.2" -> use `multi-harness`.
- "Compare the output between Codex and OpenCode" -> use `multi-harness`.

## Universal CLI Harness Execution

The adapter supports running bounded tasks across:
- **Codex CLI**: `codex exec --ephemeral [-m <model>] [-C <dir>]`
- **Claude Code CLI**: `claude -p "<prompt>"`
- **Pi**: `pi --print --mode text --model <model> --tools <tools>`
- **OpenCode**: `opencode run --dir <dir> [--model <model>]`

For delegated implementation with worktree auto-isolation:
Pass `--worktree <slug>` to `delegate.py`. It will:
1. Automatically create an isolated git worktree at `.worktrees/<slug>`.
2. Execute the delegated task inside the isolated worktree.
3. Enforce the structured YAML/TOON contract.
4. Capture output and diffs cleanly without touching the main checkout.

## Quick Start

Run diagnostics to check installed harnesses and local models:

```bash
python3 <skill_dir>/scripts/delegate.py --diagnose
python3 <skill_dir>/scripts/delegate.py --list-profiles
```

Delegate a read-only review to Pi with GLM 5.2:

```bash
python3 <skill_dir>/scripts/delegate.py \
  --profile pi-glm-review \
  --cwd "$PWD" \
  --task "Review the changed files for correctness bugs. Return only actionable findings."
```

Delegate a write-capable implementation only when the user explicitly wants another harness to edit files:

```bash
python3 <skill_dir>/scripts/delegate.py \
  --profile pi-glm-implement \
  --allow-write \
  --cwd "$PWD" \
  --task "Implement the scoped change described in PLAN.md task 2. Keep edits minimal and run tests."
```

Use `--dry-run` before any unfamiliar profile.

## Routing

Read `references/profiles.md` when choosing a profile or adding a new one.

Default choices:

- Research, planning, deep review, debugging: `pi-glm-*` profiles, especially `pi-glm-review` or `pi-glm-plan`.
- Large context sweeps: `pi-minimax-large`.
- Fast mechanical scan or OpenCode-specific command behavior: `opencode-fast`.
- Implementation by another harness: only a `*-implement` profile with `--allow-write`.

If GLM 5.2 is requested, prefer Pi profile `zai-coding-plan/glm-5.2` unless OpenCode is also configured with that model locally. Do not assume OpenCode can use GLM 5.2 just because Pi can.

## Delegation Workflow

1. Define the task boundary in one paragraph: objective, files/dirs, non-goals, and expected output.
2. Choose the lowest-risk profile that can do the job.
3. For read-only delegation, use profiles that enforce read-only tools where possible. Pi can enforce this with `--tools read,grep,find,ls`; OpenCode read-only depends on prompt contract or a configured read-only agent.
4. Run `delegate.py`. The script writes prompt/output metadata under `~/.cache/multi-harness/runs/`.
5. Read the returned output. Do not paste it blindly into the final answer.
6. If the harness was allowed to write, inspect `git status` and relevant diffs before accepting any change.
7. Verify with local tests/checks in the primary harness.
8. Report what was delegated, what came back, what you accepted, and what you rejected.

## Prompt Contract

Read `references/prompt-contracts.md` before delegating anything that can write files, touch secrets, call external services, or operate on production systems.

Every delegated prompt must include:

- The exact working directory.
- The task type and profile.
- Permission mode: read-only or write-allowed.
- Explicit forbidden actions.
- Expected output sections.
- A reminder that the external harness has no reliable access to this conversation unless you include the context.

## Guardrails

- Do not delegate secrets, credentials, private keys, raw `.env` values, or production tokens.
- Do not let another harness perform destructive operations, cloud changes, Kubernetes changes, database writes, payments, email sending, or git pushes without a separate explicit user request.
- Do not run write-capable profiles on a dirty worktree unless you have inspected the existing changes and can distinguish user changes from delegated changes.
- Do not accept a delegated result without checking evidence. External harnesses are advisors/executors, not authorities.
- Do not use shell string interpolation for untrusted task text. Use `delegate.py` so prompts are passed as subprocess arguments.
- Stop and ask the user before delegating to a paid/quota-sensitive model for a large or open-ended job unless the user already requested it.

## Output Contract

When reporting back to the user, include:

- Harness/profile used.
- Whether it was read-only or write-capable.
- Key findings or changes accepted.
- Verification you ran locally.
- Any residual risk or rejected delegate suggestion.

Keep raw delegate logs in the run directory; summarize instead of dumping them.
