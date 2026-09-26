# Multi-harness Profiles

Use this reference to choose a profile. Profile definitions live in `scripts/delegate.py`.

Read `harnesses.md` for supported binaries, argument capabilities, and model discovery.

## Built-in Profiles

Profiles with `model: auto` select from the configured harness catalog. Codex and Claude require an explicit catalog or `--model`. Other harnesses use their local configuration. Auto-selection fails when no model is available.

| Profile | Harness | Model | Mode | Description |
|---|---|---|---|---|
| `codex-complex` | Codex | `auto` (flagship) | write | Complex multi-file implementation. |
| `codex-fast` | Codex | `auto` (fast tier) | read-only | Fast exploration and log triage. |
| `codex-review` | Codex | `auto` (reasoning) | read-only | Independent verifier and reviewer. |
| `claude-review` | Claude Code | `auto` (catalog) | read-only | Adversarial code review. |
| `claude-implement` | Claude Code | `auto` (catalog) | write | Scoped implementation. |
| `pi-glm-review` | Pi | `auto` (latest GLM) | read-only | Deep code review and security reasoning. |
| `pi-glm-plan` | Pi | `auto` (latest GLM) | read-only | Task decomposition and planning. |
| `pi-glm-debug` | Pi | `auto` (latest GLM) | read-only | Hypothesis and root-cause analysis. |
| `pi-glm-implement` | Pi | `auto` (latest GLM) | write | Scoped implementation with GLM. |
| `pi-deepseek-review` | Pi | `auto` (latest DeepSeek) | read-only | Deep review with DeepSeek. |
| `pi-minimax-large` | Pi | `auto` (latest MiniMax) | read-only | Broad context sweeps. |
| `pi-lean` | Pi-profile | `default` | read-only | Isolated lightweight Pi runner. |
| `pi-gsd` | Pi-profile | `default` | read-only | GSD-enhanced Pi runner. |
| `pi-search` | Pi-profile | `default` | read-only | Research and web search Pi runner. |
| `opencode-fast` | OpenCode | `default` | read-only | Fast codebase scan. |
| `opencode-review` | OpenCode | `default` | read-only | GSD-style review. |
| `opencode-implement` | OpenCode | `default` | write | OpenCode implementation task. |

## Model Catalog Input

Pass `--model-catalog` for Codex or Claude auto-selection. The file must use this JSON shape:

```json
{"models":[{"id":"model-name"}],"default":"model-name"}
```

`default` is required when a Claude catalog has more than one model. An explicit `--model` skips catalog discovery.

## Access and Isolation

- `--allow-write` permits a write-capable profile to run.
- `--yolo` also requests the selected harness's permission-bypass mode.
- `--worktree <slug>` isolates the task under `.worktrees/<slug>`.
- `--dry-run` prints the planned command and prompt without writing artifacts or creating a worktree.
