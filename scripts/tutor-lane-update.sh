#!/usr/bin/env bash
# tutor-lane-update.sh — add or update a lane entry in lanes.json
#
# Usage:
#   tutor-lane-update <id> <title> <tmux_target> <branch> <state>
#   tutor-lane-update --bump <id>        # only update last_activity_epoch
#
# States: ready | running | awaiting_review | done | blocked | cancelled
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
STATE_DIR="$USER_HOME/.hermes/profiles/$PROFILE/state"
LANES="$STATE_DIR/lanes.json"
mkdir -p "$STATE_DIR"
[ -f "$LANES" ] || echo '[]' > "$LANES"

if [ "${1:-}" = "--bump" ]; then
  id="${2:-}"
  if [ -z "$id" ]; then echo "usage: $0 --bump <id>"; exit 2; fi
  python3 - "$LANES" "$id" <<'PY'
import json, sys, time
p, lane_id = sys.argv[1], sys.argv[2]
lanes = json.load(open(p))
for l in lanes:
    if l.get("id") == lane_id:
        l["last_activity_epoch"] = int(time.time())
        break
else:
    lanes.append({"id": lane_id, "last_activity_epoch": int(time.time())})
json.dump(lanes, open(p, "w"), indent=2)
PY
  exit 0
fi

id="${1:-}"; title="${2:-}"; target="${3:-}"; branch="${4:-}"; state="${5:-ready}"
if [ -z "$id" ] || [ -z "$title" ]; then
  echo "usage: $0 <id> <title> <tmux_target> <branch> <state>"
  exit 2
fi

python3 - "$LANES" "$id" "$title" "$target" "$branch" "$state" <<'PY'
import json, sys, time
p, lid, title, target, branch, state = sys.argv[1:]
lanes = json.load(open(p))
now = int(time.time())
for l in lanes:
    if l.get("id") == lid:
        l.update({"title": title, "tmux_target": target, "branch": branch,
                  "state": state, "last_activity_epoch": now})
        break
else:
    lanes.append({"id": lid, "title": title, "tmux_target": target,
                  "branch": branch, "state": state,
                  "created_epoch": now, "last_activity_epoch": now})
json.dump(lanes, open(p, "w"), indent=2)
PY