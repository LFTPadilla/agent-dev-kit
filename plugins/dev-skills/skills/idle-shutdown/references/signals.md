# idle-shutdown — signals, trees, and service units

## Process-tree selection

The watcher reads `/proc` directly. It does not use `pgrep`, so it finds
processes in the same PID namespace only.

Selection runs in two steps:

1. Match a process when its executable name matches the harness list, or when
   the base name of any command-line argument matches the list.
2. Add every descendant of a matched process, up to 40 levels.

The default list covers `herdr`, `herdr-mux`, `zcode`, `zcode-cli`,
`zcode-host-local`, `ZCode`, `dsh`, `dsh-web`, `hermes`, `codex`, `claude`,
`opencode`, `cursor-agent`, and `pi`.

Step 2 matters most. An agent inside Herdr runs as a child of the Herdr server
process, so the agent binary name never has to match. The watcher then removes
the Herdr part of the tree from the CPU sum, and uses Herdr state for those
panes instead. Add `--match REGEX` when a harness uses another executable name.

The watcher excludes its own process. An idle machine reports a stable process
count and a low `cpu_non_herdr`.

## Signal 1 — agent state

The watcher calls `herdr agent list` every sample and reads the `agent_status`
field. Herdr already tracks agent lifecycle, so this signal stays correct while
an agent waits on the model with no CPU use. That wait is the common state in a
long run.

The signal is unavailable when the `herdr` binary is absent, when the Herdr
server is stopped, or when the call fails. The watcher then reports
`agent_states: null` and uses the CPU signal alone.

## Signal 2 — process CPU, Herdr side removed

The watcher sums the `utime` and `stime` fields of every selected process. It
divides the delta by the elapsed time and the clock tick rate. The result is a
percentage of one CPU core, so a busy 8-core host can exceed 100 %.

One correction decides whether this signal works at all. The watcher removes
every process under Herdr from the sum while Herdr answers. Herdr state and
Herdr CPU measure the same agents twice, and the CPU copy is the noisy one.

Measured on a host with ten Herdr panes, all idle or done:

| Group | CPU |
|---|---|
| Two idle Pi panes plus the Herdr server | 16 % of one core |
| ZCode and DSH, no work running | 0.9 % of one core |
| ZCode running a real turn | 38 % to 51 % of one core |

The 16 % is drawing cost, not work. A threshold cannot separate it from a real
run, so the fix is exclusion, not a higher number.

Threshold guidance for the non-Herdr side:

| Host state | Observed CPU |
|---|---|
| All agents idle at prompts | below 1 % |
| One agent running a command | 20 % to 200 % |
| Several agents at once | above 200 % |

A threshold of 3 % separates these cases with margin.

### Idle TUI noise in other harnesses

`pi` is not a CPU root in the default list. An idle Pi TUI held 7 % to 9 % of a
core per pane. Inside Herdr, the state signal covers Pi, so the watcher loses
nothing. A Pi outside Herdr needs `--match pi` and a `--cpu-pct` above its idle
floor, or a state source of its own.

## Sampling and the idle timer

Each sample updates one of two values:

- A busy sample sets `last_active` to the sample time.
- An idle sample leaves `last_active` alone.

The watcher powers off the host when `now - last_active` reaches `--grace-min`.
One busy sample resets the timer to zero. The grace period therefore measures
continuous idle time, not total idle time.

## Relationship to the `herdr` skill

The `herdr` skill governs an agent that controls panes from inside Herdr. This
watcher is different. It is a host-level monitor that runs outside Herdr, reads
`herdr agent list` once per sample, and sends no control command. It never
focuses, starts, or closes a pane. Keep the two separate: use the `herdr` skill
for control, and this skill for host lifecycle only.

## Transient service, without a unit file

```bash
systemd-run --user --unit=idle-shutdown --collect \
  "$PWD/scripts/idle-shutdown" --target root@host --grace-min 15
```

Timeouts and paths belong to the invoking shell. `--collect` removes the unit
after it exits, so no stale unit stays behind.

## Persistent user unit

Use a unit file when the watcher must survive a logout. The unit below has a
generic target. Replace it, and replace `GRACE` and `INTERVAL` with your values.

```ini
[Unit]
Description=Power off the target host when agent work stops
After=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/idle-shutdown --target root@host --grace-min 15
Environment=IDLE_SHUTDOWN_INTERVAL=30
Restart=on-failure
RestartSec=20

[Install]
WantedBy=default.target
```

Install and start it:

```bash
mkdir -p ~/.config/systemd/user
cp idle-shutdown.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now idle-shutdown.service
loginctl enable-linger "$USER"      # required to run after logout
```

Stop the watcher, or hold the shutdown without stopping the watcher:

```bash
systemctl --user stop idle-shutdown.service
idle-shutdown --hold
```

## Files on disk

| Path | Content |
|---|---|
| `<state-dir>/state.json` | Last sample, idle minutes, runtime minutes, and the current note |
| `<state-dir>/watcher.log` | One line per sample. Rotates to `watcher.log.1` above 2 MB |
| `<state-dir>/hold` | Presence blocks the shutdown |
| `<report-dir>/idle-shutdown-<stamp>.md` | One report per shutdown attempt |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Shutdown sent, or `--once`/`--status`/`--hold` finished |
| 1 | Every SSH attempt failed, or the local shutdown command failed |
| 2 | The target resolves to the local host, or the target is missing |
