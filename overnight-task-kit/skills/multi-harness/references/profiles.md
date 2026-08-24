# Multi-harness Profiles (Universal Harness Adapter)

Use this reference to choose profiles and maintain the profile table in `scripts/delegate.py`.

## Supported Local Harnesses

- `codex`: Runs `codex exec --ephemeral -C <cwd> [-m <model>] [--yolo]`.
- `claude`: Runs `claude -p "<prompt>" [--dangerously-skip-permissions]`.
- `dhs`: Runs `dhs exec --dir <cwd> [--model <model>] [--yolo]`.
- `pi`: Runs `pi --print --mode text --model <provider/model> --tools <allowlist>`.
- `opencode`: Runs `opencode run --dir <cwd> [--model <provider/model>] [--agent <agent>]`.

Run `delegate.py --diagnose` before assuming any specific harness or model is available locally.

## Built-in Profiles

| Profile | Harness | Model | Mode | Description |
|---|---|---|---|---|
| `codex-complex` | Codex | `gpt-5.6` | write | Complex multi-file implementation via Codex CLI. |
| `codex-fast` | Codex | `gpt-5.6-luna` | read-only | Fast mechanical exploration and log triage via Codex CLI. |
| `codex-review` | Codex | `gpt-5.6-sol` | read-only | Independent verifier and security/correctness reviewer. |
| `claude-review` | Claude Code | `default` | read-only | Adversarial multi-lens code review via Claude Code CLI. |
| `claude-implement` | Claude Code | `default` | write | Scoped implementation via Claude Code CLI. |
| `dhs-review` | DHS | `default` | read-only | Read-only analysis and review via DHS runner. |
| `dhs-implement` | DHS | `default` | write | Scoped implementation via DHS runner. |
| `dhs-fast` | DHS | `default` | read-only | Fast scanning and triage via DHS runner. |
| `pi-glm-review` | Pi | `zai-coding-plan/glm-5.2` | read-only | Deep code review, design critique, and security reasoning. |
| `pi-glm-plan` | Pi | `zai-coding-plan/glm-5.2` | read-only | Task decomposition and implementation planning. |
| `pi-glm-debug` | Pi | `zai-coding-plan/glm-5.2` | read-only | Hypothesis and root-cause analysis without editing files. |
| `pi-glm-implement` | Pi | `zai-coding-plan/glm-5.2` | write | Scoped implementation with GLM 5.2. |
| `pi-minimax-large` | Pi | `minimax/MiniMax-M3` | read-only | Broad context sweeps across large repositories. |
| `opencode-fast` | OpenCode | `default` | read-only | Fast codebase scan via OpenCode. |
| `opencode-review` | OpenCode | `default` | read-only | GSD-style review via OpenCode reviewer agent. |
| `opencode-implement` | OpenCode | `default` | write | OpenCode implementation task. |

## Permission Bypass Modes

For write-capable profiles, use any of:
- `--allow-write`: Grants write permissions.
- `--yolo` / `--dangerously-skip-permissions`: Automatically bypasses interactive confirmations across all harnesses (`--yolo` for Codex/DHS, `--dangerously-skip-permissions` for Claude Code, full tool allowlist for Pi).

## Worktree Auto-Isolation

Pass `--worktree <slug>` to automatically isolate the delegated run inside `.worktrees/<slug>` on branch `task/<slug>`, keeping the main checkout clean.
