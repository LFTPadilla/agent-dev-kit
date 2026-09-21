---
name: idle-shutdown
description: Power off a host after unattended agent work stops. Monitors Herdr agent states and the CPU of harness process trees, then runs the shutdown command when no agent is active for a grace period. Use when the user leaves long agent runs and wants the machine powered off when they finish. Do not use when the user is present and working, or when the agents must stay reachable.
---

# idle-shutdown — power off a host when agent work stops

Long unattended runs keep a machine busy for hours. The user leaves, and nobody
powers the machine off afterwards. This skill installs one watcher process that
measures whether any agent is still active. It runs the shutdown command only
after a full grace period without activity.

Use it when the user says "leave it running and turn the machine off when it
finishes", "apaga el server cuando terminen los agentes", or "monitorea y apaga
cuando todo quede quieto".

## Safety contract

Read this list before you arm the watcher. Every item is mandatory.

1. **Confirm authorization.** The user must name the target host and authorize
   the power off in this session. Never guess a target from an earlier session.
2. **Run a dry run first.** Start with `--dry-run` and one `--once` sample. Show
   the user the target, the grace period, and the detected agents.
3. **Verify the target is not the local host.** The script refuses a remote
   target that resolves to the local host. Keep that guard. A remote shutdown
   sends the power off command to itself otherwise.
4. **Keep the watcher outside the shutdown path.** Start the watcher as a
   service or a detached process. A foreground watcher dies with its terminal.
5. **State the cancel command.** Tell the user `--hold` cancels the shutdown and
   `--release` re-arms it.

## Activity signals

The watcher combines two signals. One signal alone is wrong for this job.

| Signal | Source | Covers | Misses |
|---|---|---|---|
| Agent state | `herdr agent list` | Herdr panes in `working` state, including model waits at 0 % CPU | Harnesses outside Herdr |
| Process CPU | `/proc` CPU ticks of harness trees that Herdr does not manage | ZCode, DSH, a standalone Hermes gateway, Codex, Claude, OpenCode, Cursor | A turn that waits on the network with no CPU use |

The watcher marks the host busy when either signal fires. It records a sample
every `--interval` seconds and resets the idle timer on every busy sample.

### Why the two sides stay separate

Herdr owns its panes, so its state decides for them. The watcher removes the Herdr
process tree from the CPU sum.

An idle agent TUI keeps drawing, and drawing costs CPU. On a real host, two idle
Pi panes and the Herdr server held 16 % of a core with no work running. The CPU
signal was therefore true forever, the idle timer never reached the grace period,
and the host stayed on for eight hours. After the split, the same host measured
under 1 % of CPU on the side that Herdr does not manage.

Do not add `pi` to the CPU roots for the same reason. Inside Herdr, the state
signal covers Pi.

Herdr reports five states. Only `working` counts as active by default:

- `working` — the agent runs a turn. Active.
- `idle` — the agent waits for input. Inactive.
- `done` — the same idle state after unseen background work. Inactive.
- `blocked` — the agent waits on an approval or a question. Inactive, because it
  does not execute. Add `blocked` to `--active-states` to keep the host on.
- `unknown` — Herdr cannot classify the agent. Inactive, and logged.

## Quick start

Sample the state without arming anything:

```bash
scripts/idle-shutdown --once --target root@host
```

Dry run for a short grace period:

```bash
scripts/idle-shutdown --target root@host --grace-min 5 --interval 30 --dry-run
```

Arm the shutdown. The script returns after it sends the power off command:

```bash
scripts/idle-shutdown --target root@host --grace-min 15 --interval 30 \
  --report-dir .agent-runs/idle-shutdown
```

Run it detached so it survives the terminal. This example uses a transient
systemd user unit:

```bash
systemd-run --user --unit=idle-shutdown --collect \
  "$PWD/scripts/idle-shutdown" --target root@host --grace-min 15
systemctl --user stop idle-shutdown   # cancel the watcher
```

Check the last sample at any time:

```bash
scripts/idle-shutdown --status
```

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--target user@host` | required | Host to power off. Use `--local` instead for this machine. |
| `--local` | off | Run the shutdown command on this machine. |
| `--shutdown-cmd` | `shutdown now` | Command to run on the target. |
| `--grace-min` | `15` | Minutes without activity before the shutdown. |
| `--interval` | `30` | Seconds between samples. |
| `--cpu-pct` | `3.0` | CPU percent of one core that marks a tree busy. |
| `--max-hours` | `0` | Hard runtime limit in hours. `0` disables it. |
| `--active-states` | `working` | Comma-separated Herdr states that count as active. |
| `--match REGEX` | none | Extra process-name regex, repeatable. |
| `--report-dir DIR` | none | Write one markdown report per shutdown. |
| `--state-dir DIR` | `$XDG_STATE_HOME/idle-shutdown` | State, log, and hold file location. |
| `--dry-run` | off | Sample and log, never send the shutdown. |
| `--once` | off | Print one sample as JSON and exit. |
| `--status` | off | Print the last sample written to disk. |
| `--hold` / `--release` | off | Cancel or re-arm the shutdown. |
| `--allow-self-target` | off | Skip the local-host guard. Use only with a deliberate reason. |

Every flag has an `IDLE_SHUTDOWN_*` environment variable. Prefer flags in a
one-off command, and environment variables in a service unit.

## Tune the watcher for the workload

1. Start with `--dry-run` and `--once`. Confirm that the process count is not
   zero. A count of zero means the harness names do not match, and the CPU
   signal is blind.
2. Read `cpu_non_herdr` in the log, not the total. That number covers the
   harnesses the state signal cannot see. Watch it at real idle time. If it
   stays above 0 with no work running, raise `--cpu-pct`.
3. Raise `--grace-min` when a false positive is expensive. A false positive
   powers off a machine that still had work.
4. Set `--max-hours` when the agents can stall forever. The value is a hard
   limit, so pick a number larger than the longest expected run.

## Failure modes

- **Herdr is absent.** The watcher logs one warning and uses CPU only. The CPU
  signal cannot see a model wait, so raise `--grace-min` in that case.
- **SSH fails.** The watcher retries `--ssh-retries` times, then logs a critical
  line and exits with code 1. The host stays on. Nobody is told unless the
  report directory is set.
- **The watcher dies.** The host stays on. This failure is safe. `Restart=on-failure`
  in a service unit recovers it; the grace timer restarts from zero.
- **A `hold` file exists.** The watcher logs and samples, and never powers off.
  `--status` reports `note: hold`.

## References

- [`references/signals.md`](references/signals.md): signal details, process-tree
  selection, and a service unit template.
