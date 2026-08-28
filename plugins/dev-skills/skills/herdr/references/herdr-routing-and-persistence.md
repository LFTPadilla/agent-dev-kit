# Herdr Routing, Topology & Persistence Reference

This reference documents the deterministic topology model, dispatcher CLI patterns, and crash-recovery persistence contracts for **Herdr** within `agent-dev-kit`.

---

## 1. Topology Model & Identifiers

Herdr organizes terminal multiplexing into four distinct hierarchical layers:

```
Session (Daemon)
 └── Workspace / Space (`wM`, `wN`, `wP`)
      └── Tab (`wM:tC`, `wP:tW`)
           └── Pane (`wM:pF`, `wP:p1K`)
                └── Process / Agent (Claude, Codex, Hermes, OpenCode, etc.)
```

### Identifier Format
- **Workspace ID (`wid`):** Opaque alphanumeric handle (e.g. `wM`, `w1`).
- **Tab ID (`tid`):** Workspace-qualified handle (e.g. `wM:tC`).
- **Pane ID (`pid`):** Workspace-qualified handle (e.g. `wM:pF`).
- **Agent Name (`name`):** Unique user/orchestrator string matching `[a-z][a-z0-9_-]{0,31}` assigned to a live agent session in a pane.

### Auto-Indexing Transparency
When the `felipe.auto-index` plugin is enabled, workspace and tab labels are prefixed with numeric positions (e.g. `1. athena`, `4. superpowers`).
The dispatcher (`herdr-dispatch.sh`) automatically normalizes labels using the regex `^[0-9]+[.] ?` so that:
- `--space athena` matches `1. athena` or `athena`.
- `--tab superpowers` matches `4. superpowers` or `superpowers`.

---

## 2. Dispatcher CLI (`herdr-dispatch.sh`)

Located at `plugins/dev-skills/skills/herdr/scripts/herdr-dispatch.sh`.

### Commands

#### `list`
Inspects all active workspaces, tabs, panes, and registered agents.
```bash
# Human / Agent TOON outline format
herdr-dispatch.sh list --format toon

# Strict JSON format
herdr-dispatch.sh list --format json
```

#### `run`
Executes an arbitrary shell command in a specified space and tab, allocating an idle pane (or splitting an existing pane if all are busy):
```bash
herdr-dispatch.sh run \
  --space personal \
  --tab tests \
  --command "npm test" \
  --cwd "/home/user/programming/agent-dev-kit" \
  --dir right
```

#### `agent-start`
Launches an interactive agent in an available shell pane, optionally submitting an initial prompt and waiting for completion:
```bash
herdr-dispatch.sh agent-start \
  --space athena \
  --tab review \
  --name code-reviewer \
  --kind claude \
  --prompt "Review PR #12 and output findings" \
  --wait
```

#### `status` & `wait`
Monitors agent lifecycle states:
```bash
# Query agent status
herdr-dispatch.sh status --name code-reviewer --format toon

# Block until the agent reaches idle or done
herdr-dispatch.sh wait --name code-reviewer --timeout 180
```

---

## 3. Agent Lifecycle States

Herdr dynamically monitors terminal prompt boxes and status lines to report agent state:

| State | Meaning | Orchestrator Action |
|---|---|---|
| `idle` | Agent is waiting for user input and has been seen in UI. | Safe to submit next prompt or read final response. |
| `done` | Agent finished background task; waiting for input (unseen). | Mark seen by reading/focusing; safe to collect output. |
| `working` | Agent is actively generating tokens, running tools, or executing commands. | Continue polling or waiting; do not send keyboard input. |
| `blocked` | Agent encountered an interactive prompt (approval, confirmation). | Requires user or orchestrator resolution via keys/prompt. |
| `unknown` | Process detected but lifecycle could not be confidently determined. | Fall back to pattern-matching output or timer. |

---

## 4. Crash Recovery & Persistence Architecture

Across machine reboots or unexpected system freezes, state is preserved at two distinct levels:

### 1. Workspace & Pane State (`~/.config/herdr/session.json`)
Herdr continuously saves its entire topology (`persist.save` events) to disk. On reboot:
- All spaces, tabs, and split panes are automatically reconstructed.
- Working directories (`cwd`) for each pane are preserved.
- Panes spawn default interactive shells (`zsh`).

### 2. AI Session Auto-Resume
- **Herdr Startup Hook (`resume-agents.sh`):**
  Registered in `~/.dotfiles/system/herdr/plugins/auto-index/herdr-plugin.toml`. On startup, it queries panes that had an active `agent_session` before the crash and re-invokes the agent with its resume flag (`claude --dangerously-skip-permissions --resume`, `codex resume <uuid>`, `hermes -c`, `opencode --resume`).
- **Workspace Rebuilding (`herdr-mux`):**
  Tab definitions use fallback resume commands (`claude ... --resume || claude`, `hermes -c || hermes`), guaranteeing that manual workspace rebuilds never discard ongoing conversation lineage.
