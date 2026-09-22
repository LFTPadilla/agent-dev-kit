---
name: agent-session-monitor
description: "See which coding agent sessions run right now and which harness each one uses, from one Herdr command. Use when the user asks what agents are running, which harnesses are busy, or for a session inventory. Read only: it never starts, stops, or prompts an agent."
---

# agent-session-monitor

Answer one question: which agent sessions run right now, and on which harness?
The single source is `herdr agent list`. Read it, then report. Do not control
any agent.

## Read the sessions

Run the helper script from this skill directory:

```bash
python3 plugins/dev-skills/skills/agent-session-monitor/scripts/agent-sessions.py
```

Sample output:

```text
7 sessions
working  hermes      wN    wN:p6Y    /home/user/project
working  hermes      wN    wN:p71    /home/user/project
idle     hermes      wP    wP:p5R    /home/user/dotfiles
done     hermes      wN    wN:p6X    /home/user/project

harness: hermes 7
state: working 3, idle 3, done 1
```

For machine-readable output, use `--format json`:

```bash
python3 plugins/dev-skills/skills/agent-session-monitor/scripts/agent-sessions.py --format json
```

The JSON holds `summary` (counts by harness and state) and `sessions` (one
object per session with `harness`, `state`, `workspace`, `pane`, `cwd`,
`session`, `focused`).

## Read it without the script

When the script is not at hand, call Herdr directly and parse the JSON:

```bash
herdr agent list
```

The fields that matter:

| Field | Meaning |
|---|---|
| `.result.agents[]` | One object per live agent session |
| `.agent` | Harness name (hermes, claude, codex, pi, opencode) |
| `.agent_status` | `working`, `blocked`, `idle`, `done`, or `unknown` |
| `.workspace_id`, `.pane_id` | Where the session lives |
| `.cwd` | Project the agent works in |
| `.focused` | True when the user looks at this pane now |

Count sessions with `jq` when you need only numbers:

```bash
herdr agent list | jq '{total: (.result.agents | length),
  harnesses: (.result.agents | group_by(.agent) |
    map({(.[0].agent): length}) | add)}'
```

## Interpret the states

- `working`: the agent runs a turn. Report it as active.
- `blocked`: the agent waits for user input or approval. Report it as needs
  attention.
- `idle`: the agent waits for its next prompt.
- `done`: idle after background work; the tab has not been seen yet.
- `unknown`: an agent is present but Herdr cannot classify it. Do not treat it
  as finished.

## Limits

- Herdr sees only panes inside its own server. A harness that runs in a plain
  tmux pane or a bare terminal does not appear here.
- An empty list means no recognized agent runs. It does not prove that Herdr
  is down; `herdr status` checks the server.

## Tests

```bash
python3 plugins/dev-skills/skills/agent-session-monitor/scripts/test-agent-sessions.py
```

The tests run offline. They mock `herdr agent list`; no live server is needed.
