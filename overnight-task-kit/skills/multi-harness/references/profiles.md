# Multi-harness Profiles (Universal Harness Adapter)

Use this reference to choose profiles and maintain the profile table in `scripts/delegate.py`.

## Supported Local Harnesses

- `codex`: Runs `codex exec --ephemeral -C <cwd> [-m <model>] [--yolo]`.
- `claude`: Runs `claude -p "<prompt>" [--dangerously-skip-permissions]`.
- `dhs` (alias `dsh`): Runs `dsh exec --dir <cwd> [--model <model>] [--yolo]` *(Headless execution engine; no interactive terminal TUI)*.
- `pi`: Runs `pi --print --mode text [--model <provider/model>] --tools <allowlist>`.
- `opencode`: Runs `opencode run --dir <cwd> [--model <provider/model>] [--agent <agent>]`.

Run `delegate.py --diagnose` before assuming any specific harness or model is available locally.

## Built-in Profiles (Dynamic Frontier Models)

Profiles with `model: auto` dynamically discover and select the highest active version in your local configuration (e.g. `glm-5.3+`, latest `deepseek-v4+`, `gpt-5.x`), or accept explicit overrides via `--model <name>`.

| Profile | Harness | Model | Mode | Description |
|---|---|---|---|---|
| `codex-complex` | Codex | `auto` (flagship) | write | Complex multi-file implementation via Codex CLI. |
| `codex-fast` | Codex | `auto` (fast tier) | read-only | Fast mechanical exploration and log triage via Codex CLI. |
| `codex-review` | Codex | `auto` (reasoning) | read-only | Independent verifier and security/correctness reviewer. |
| `claude-review` | Claude Code | `default` | read-only | Adversarial multi-lens code review via Claude Code CLI. |
| `claude-implement` | Claude Code | `default` | write | Scoped implementation via Claude Code CLI. |
| `dhs-review` | DHS / DSH | `default` | read-only | Headless review via DeepSeek Harness. |
| `dhs-implement` | DHS / DSH | `default` | write | Headless scoped implementation via DeepSeek Harness. |
| `dhs-fast` | DHS / DSH | `default` | read-only | Headless fast triage via DeepSeek Harness. |
| `pi-glm-review` | Pi | `auto` (latest GLM) | read-only | Deep code review, design critique, and security reasoning. |
| `pi-glm-plan` | Pi | `auto` (latest GLM) | read-only | Task decomposition and implementation planning. |
| `pi-glm-debug` | Pi | `auto` (latest GLM) | read-only | Hypothesis and root-cause analysis without editing files. |
| `pi-glm-implement` | Pi | `auto` (latest GLM) | write | Scoped implementation with latest active GLM model. |
| `pi-deepseek-review` | Pi | `auto` (latest DeepSeek) | read-only | Deep review with latest active DeepSeek model. |
| `pi-minimax-large` | Pi | `auto` (latest MiniMax) | read-only | Broad context sweeps across large repositories. |
| `pi-lean` | Pi | `pi-profile:lean` | read-only | Isolated lightweight Pi runner via local pi-profile lean. |
| `pi-gsd` | Pi | `pi-profile:gsd` | read-only | GSD-enhanced Pi runner via local pi-profile gsd. |
| `pi-search` | Pi | `pi-profile:search` | read-only | Research and web search Pi runner via local pi-profile search. |
| `opencode-fast` | OpenCode | `default` | read-only | Fast codebase scan via OpenCode. |
| `opencode-review` | OpenCode | `default` | read-only | GSD-style review via OpenCode reviewer agent. |
| `opencode-implement` | OpenCode | `default` | write | OpenCode implementation task. |

## Permission Bypass Modes

For write-capable profiles, use any of:
- `--allow-write`: Grants write permissions.
- `--yolo` / `--dangerously-skip-permissions`: Automatically bypasses interactive confirmations across all harnesses (`--yolo` for Codex/DHS, `--dangerously-skip-permissions` for Claude Code, full tool allowlist for Pi).

## Worktree Auto-Isolation

Pass `--worktree <slug>` to automatically isolate the delegated run inside `.worktrees/<slug>` on branch `task/<slug>`, keeping the main checkout clean. Slugs are validated for safe directory names.
