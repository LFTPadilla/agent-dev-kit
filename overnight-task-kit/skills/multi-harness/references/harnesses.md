# Harness Capabilities

`scripts/harnesses.py` is the source of truth for CLI argv and required help flags. The test suite runs each installed binary's help probe and prints `SKIP` when a binary is absent.

| Harness | Binary | Help probe | Required flags | Model source |
|---|---|---|---|---|
| Codex | `codex` | `exec --help` | `--ephemeral`, `-C`, `-m` | Explicit `--model-catalog` or `--model`. |
| Claude Code | `claude` | `--help` | `-p`, `--model`, `--permission-mode`, `--dangerously-skip-permissions` | Explicit `--model-catalog` or `--model`. |
| OpenCode | `opencode` | `run --help` | `--dir`, `--model`, `--agent`, `--auto` | Local OpenCode configuration. |
| Pi | `pi` | `--help` | `--print`, `--no-session`, `--mode`, `--tools`, `--model` | Local Pi model configuration. |
| Pi-profile | `pi-profile` | `--help` | `--` | Profile directory from `PI_PROFILE_DIR`; binary on `PATH`. |
| mcode | Herdr pane | Not applicable | Idle pane and sentinel wait | Existing same-directory mcode pane. |

The Codex catalog is caller-selected because local catalog precedence is not fixed. Catalog files use `{"models":[{"id":"model-name"}],"default":"model-name"}`. Claude requires a default when its catalog lists multiple models. An explicit model bypasses discovery.

When `HERDR_ENV=1`, detected agents are reusable only when Herdr reports `idle` and both cwd fields match the selected task directory. Blocked, working, unknown, and other-directory agents are skipped. Herdr does not detect mcode, so its pane can have no `agent` value and an `unknown` status. The caller must pass `--harness mcode --mcode-pane-id <id>` to select it explicitly. The adapter checks that pane's directory, rejects any detected non-mcode agent, and verifies `process-info` identifies a foreground mcode process; an idle shell is not enough. It accepts `unknown` only when no agent is detected and the caller selected that exact pane. After either dispatch path completes, the adapter reads `recent-unwrapped` output for the delegated response. CLI-backed harnesses run normally when no idle agent matches.
