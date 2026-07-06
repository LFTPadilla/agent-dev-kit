# Multi-harness Profiles

Use this reference to choose profiles and maintain the profile table in `scripts/delegate.py`.

## Local diagnostics

- `opencode` is installed and supports `opencode run --model <provider/model> --agent <agent> --dir <cwd> --variant <level>`.
- `pi` is installed and supports `pi -p --model <provider/model> --thinking <level> --tools <allowlist>`.
- Re-run `delegate.py --diagnose` before assuming any specific model is available locally.

## Built-in profiles

| Profile | Harness | Model | Mode | Use |
| --- | --- | --- | --- | --- |
| `pi-glm-review` | Pi | `zai-coding-plan/glm-5.2` | read-only | Deep code review, design critique, bug hunt, security reasoning. |
| `pi-glm-plan` | Pi | `zai-coding-plan/glm-5.2` | read-only | Break down an ambiguous task, compare approaches, produce implementation plan. |
| `pi-glm-debug` | Pi | `zai-coding-plan/glm-5.2` | read-only | Analyze logs, failing tests, stack traces, or hypotheses without changing files. |
| `pi-glm-implement` | Pi | `zai-coding-plan/glm-5.2` | write | Execute a tightly scoped code change. Requires `--allow-write`. |
| `pi-minimax-large` | Pi | `minimax/MiniMax-M3` | read-only | Very large-context source/doc sweeps where breadth matters more than top reasoning. |
| `opencode-fast` | OpenCode | `default` | read-only contract | Fast scan, summarization, or OpenCode-specific workflow. Read-only is prompt-enforced unless the selected OpenCode agent enforces tools. |
| `opencode-review` | OpenCode | `default` | read-only contract | Review with existing OpenCode/GSD agent conventions. |
| `opencode-implement` | OpenCode | `default` | write | OpenCode implementation task. Requires `--allow-write`. |

## Selection heuristics

Prefer Pi when you need hard tool restrictions. Pi's `--tools` allowlist can make review truly read-only.

Prefer OpenCode when the task benefits from configured OpenCode commands/agents, existing GSD agents, or the current OpenCode provider stack.

Prefer GLM 5.2 for high-reasoning analysis, planning, difficult debugging, and adversarial review. Use it deliberately for large jobs because it may consume paid quota.

Prefer MiniMax large-context for broad scans where missing relevant context is more likely than failing a reasoning step.

Prefer implementation profiles only when:

1. The task is sharply scoped.
2. The worktree state is known.
3. The primary agent can inspect and verify the diff afterward.
4. The user has explicitly accepted external-harness edits or the current task clearly requires them.

## Adding or changing profiles

Edit `DEFAULT_PROFILES` in `scripts/delegate.py`. Keep every profile explicit:

- `harness`: `pi` or `opencode`
- `model`: provider/model string accepted by that harness, or `default` to let the harness choose
- `mode`: `read` or `write`
- `timeout`: default seconds
- `description`: short purpose
- Optional: `thinking`, `variant`, `agent`

After editing, run:

```bash
python3 scripts/delegate.py --list-profiles
python3 scripts/delegate.py --diagnose
python3 /home/felipe/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
```
