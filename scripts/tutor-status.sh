#!/usr/bin/env bash
# tutor-status.sh — show current state of all delegated lanes.
#
# Reads ~/.hermes/profiles/<profile>/state/lanes.json and tmux panes in
# session <SESSION>. Prints a plain-text table (terminal paste-friendly).
set -uo pipefail

SELF_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
HERMES_DIR=""
dir="$(dirname "$SELF_PATH")"
while [ "$dir" != "/" ]; do
  if [ "$(basename "$dir")" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  dir="$(dirname "$dir")"
done
if [ -n "$HERMES_DIR" ]; then USER_HOME="$(dirname "$HERMES_DIR")"
else USER_HOME="/home/felipe"; fi
[ -d "$USER_HOME" ] || USER_HOME="/home/felipe"

PROFILE="${HERMES_TUTOR_PROFILE:-hermes-tutor}"
SESSION="${HERMES_TUTOR_SESSION:-komp}"
STATE_DIR="$USER_HOME/.hermes/profiles/$PROFILE/state"
LANES="$STATE_DIR/lanes.json"

if [ ! -f "$LANES" ]; then
  printf 'no lanes.json yet — first run will create it at %s\n' "$LANES"
  exit 0
fi

# Lightweight JSON parse with python (already a runtime dep for worklog).
python3 - "$LANES" "$SESSION" <<'PY'
import json, subprocess, sys, time
lanes_path, session = sys.argv[1], sys.argv[2]
try:
    with open(lanes_path) as f:
        lanes = json.load(f)
except Exception as e:
    print(f"lanes.json parse error: {e}")
    sys.exit(1)

# Live tmux state
try:
    out = subprocess.check_output(
        ["tmux", "list-windows", "-t", session, "-F",
         "#{window_index}|#{window_name}|#{pane_current_command}|#{pane_dead}"],
        text=True, timeout=5,
    )
    panes = {}
    for line in out.splitlines():
        wid, name, cmd, dead = line.split("|", 3)
        panes[int(wid)] = {"name": name, "cmd": cmd, "dead": dead == "1"}
except subprocess.CalledProcessError:
    panes = {}

now = int(time.time())
rows = []
for lane in lanes:
    target = lane.get("tmux_target", "")
    wid = None
    if target.startswith(f"{session}:"):
        try:
            wid = int(target.split(":", 1)[1])
        except ValueError:
            wid = None
    pane = panes.get(wid, {})
    last_act = lane.get("last_activity_epoch", 0)
    age_s = now - last_act if last_act else None
    rows.append({
        "id": lane.get("id", "?"),
        "title": lane.get("title", ""),
        "target": target,
        "branch": lane.get("branch", ""),
        "state": lane.get("state", "ready"),
        "pane_cmd": pane.get("cmd", ""),
        "pane_dead": pane.get("dead", True),
        "age_s": age_s,
    })

def fmt_age(s):
    if s is None: return "-"
    if s < 60: return f"{s}s"
    if s < 3600: return f"{s // 60}m"
    return f"{s // 3600}h{(s % 3600) // 60}m"

def fmt_pane(r):
    if not r["target"]: return "-"
    if r["pane_dead"]: return "DEAD"
    return r["pane_cmd"][:10] or "-"

print(f"{'ID':<4} {'TARGET':<10} {'STATE':<10} {'BRANCH':<22} {'PANE':<8} {'AGE':<6} TITLE")
print("-" * 90)
for r in rows:
    print(f"{r['id']:<4} {r['target']:<10} {r['state']:<10} {r['branch'][:22]:<22} {fmt_pane(r):<8} {fmt_age(r['age_s']):<6} {r['title']}")
print(f"\nlast refresh: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(now))}")
PY