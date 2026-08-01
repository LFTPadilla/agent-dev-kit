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
# shellcheck source=tutor-lib.sh
source "$(cd "$(dirname "$SELF_PATH")" && pwd)/tutor-lib.sh"
tutor_set_user_home "$SELF_PATH" || exit 1

PROFILE="${AGENT_TUTOR_PROFILE:-agent-tutor-orchestrator}"
STATE_DIR="$USER_HOME/.hermes/profiles/$PROFILE/state"
LANES="$STATE_DIR/lanes.json"
mkdir -p "$STATE_DIR"
[ -f "$LANES" ] || echo '[]' > "$LANES"

mode="update"
id="${1:-}"; title="${2:-}"; target="${3:-}"; branch="${4:-}"; state="${5:-ready}"
if [ "$id" = "--bump" ]; then
  mode="bump"
  id="${2:-}"
  if [ -z "$id" ]; then echo "usage: $0 --bump <id>"; exit 2; fi
elif [ -z "$id" ] || [ -z "$title" ]; then
  echo "usage: $0 <id> <title> <tmux_target> <branch> <state>"
  exit 2
fi

python3 - "$LANES" "$id" "$mode" "$title" "$target" "$branch" "$state" <<'PY'
import json, sys, time
p, lane_id, mode, title, target, branch, state = sys.argv[1:]
lanes = json.load(open(p))
now = int(time.time())
lane_fields = {"title": title, "tmux_target": target, "branch": branch, "state": state}
for lane in lanes:
    if lane.get("id") == lane_id:
        if mode == "bump":
            lane["last_activity_epoch"] = now
        else:
            lane.update({**lane_fields, "last_activity_epoch": now})
        break
else:
    if mode == "bump":
        lanes.append({"id": lane_id, "last_activity_epoch": now})
    else:
        lanes.append({"id": lane_id, **lane_fields,
                      "created_epoch": now, "last_activity_epoch": now})
json.dump(lanes, open(p, "w"), indent=2)
PY
python_status=$?
[ "$mode" = "bump" ] && exit 0
exit "$python_status"
