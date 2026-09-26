# Harness Capabilities

`scripts/harnesses.py` is the source of truth for CLI argv and required help flags. The test suite runs each installed binary's help probe and prints `SKIP` when a binary is absent.

| Harness | Binary | Help probe | Required flags | Model source |
|---|---|---|---|---|
| Codex | `codex` | `exec --help` | `--ephemeral`, `-C`, `-m`, `--sandbox`, `--dangerously-bypass-approvals-and-sandbox` | Explicit `--model-catalog` or `--model`. |
| Claude Code | `claude` | `--help` | `-p`, `--model`, `--permission-mode`, `--dangerously-skip-permissions` | Explicit `--model-catalog` or `--model`. |
| OpenCode | `opencode` | `run --help` | `--dir`, `--model`, `--agent`, `--variant`, `--auto` | Local OpenCode configuration. |
| Pi | `pi` | `--help` | `--print`, `--no-session`, `--mode`, `--tools`, `--model`, `--thinking` | Local Pi model configuration. |
| Pi-profile | `pi-profile` | `--help` | `--` | Profile directory from `PI_PROFILE_DIR`; binary on `PATH`. |
| mcode | Herdr pane | Not applicable | Idle pane and sentinel wait | Existing same-directory mcode pane. |

The Codex catalog is caller-selected because local catalog precedence is not fixed. Catalog files use `{"models":[{"id":"model-name"}],"default":"model-name"}`. Claude requires a default when its catalog lists multiple models. An explicit model bypasses discovery.

The adapter uses a fresh local subprocess unless the caller passes `--herdr`. Herdr reuse requires a write-capable profile, write permission, and `HERDR_ENV=1`. Reuse only detected agents with status `idle` and exact cwd/foreground-cwd matches. If no safe agent matches, CLI-backed harnesses use the local subprocess.

`--herdr` reuses the live agent's model, tools, and conversation. Profile model, Pi-profile, and thinking settings do not override that session.

Herdr does not detect mcode, so its pane can have no `agent` value and an `unknown` status. The caller must pass `--herdr --harness mcode --mcode-pane-id <id>`. The adapter checks the pane's directory and foreground process, writes the full prompt to a mode-0600 temporary file, then sends one file-read instruction line. It waits for a whole-line completion regex built from a random suffix not echoed in the prompt and reads the recent-unwrapped response. It rejects panes assigned to another detected agent or foreground process.
