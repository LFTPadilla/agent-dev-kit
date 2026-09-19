# Shutdown Sequence

Shutting a machine down is destructive and irreversible from inside the run.
Two things go wrong: killing the run's own machine, and deciding too early that
the work is finished. Both are avoidable.

## 1. Authorization

Shut down only when the user authorized it in this session, and run the exact
command they gave. Do not substitute your own: `systemctl poweroff` on the wrong
host is not "the same thing".

## 2. Target

- Current host: `hostname -I`. Target host: as named by the user.
- If the run executes *inside* the target (a VM or container on the machine being
  shut down), an immediate shutdown kills the run. Fire at the end of the run, or
  from a detached watcher (`systemd-run --user`) that outlives the session.
- If the run executes *on* the target itself, stop and report. There is no way to
  power off mid-run without killing the run.

## 3. Deciding that everything is finished

Process existence is not work. An idle agent TUI (pi, claude, cursor-agent,
opencode) stays alive for days at a few percent CPU with nothing queued, so a
process census never reaches zero and the shutdown never fires. That was the
v3.0 bug: the watcher was correct and simply waited forever.

Decide from *activity* — two signals, both required:

- **CPU ticks** (`/proc/<pid>/stat`, utime+stime) for the agent processes and
  their descendants (an agent blocked on a build has an idle parent and a busy
  child). Track **per pid** and diff each pid against its own previous value:
  the set of pids changes between samples, and a delta over a changing
  population goes negative. Keep the table in the same shell as the loop:
  do not put the sampler in `$( ... )` because subshells discard the table
  and measure cumulative totals. Run the sampler directly in the loop shell.
- **No process in the tree is in state `R` or `D`** at the sample instant.
  Bursty tool calls average out below any CPU threshold (measured: 148-190 ticks
  per sample, under a 750 limit, while the agent was working); the runnable
  check catches them.

Then require a quiet window (default 15 min) with both signals clean. The tick
threshold is a real knob — a box idles at some fraction of a core no matter
what, so calibrate it from the log instead of guessing: raise it if the watcher
never fires, lower it if it fires while an agent is working.

Log a heartbeat with the numbers. A watcher that silently does nothing is
undebuggable, and the only reason to trust one is its log.

## 4. Firing

1. Re-check the quiet window and the deadline (a hard cap, e.g. 14 h: a watcher
   that fires three days later is a bug, not a feature).
2. Run the user's command verbatim; log it with its exit status.
3. If it fails, log it and stop. Never silently retry a destructive command.
4. Write the log somewhere that survives the shutdown.

## Evidence for the final report

- Authorization (quote):
- Current host / target host:
- Command run:
- Completion signal (what made you sure):
- Result:
