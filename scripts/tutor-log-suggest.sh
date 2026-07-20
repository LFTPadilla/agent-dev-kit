#!/usr/bin/env bash
# tutor-log-suggest.sh — propose a worklog entry after a successful audit.
#
# Usage:
#   tutor-log-suggest <lane_id> [--description "text"] [--duration "1:30"]
#
# Without --description / --duration, prompts interactively. With both flags,
# prints the proposed line and asks for confirmation. Does NOT call daily_log.py
# without explicit "yes" — the user owns the worklog.
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

PROFILE="${AGENT_TUTOR_PROFILE:-agent-tutor-orchestrator}"
WORKLOG_DIR="${AGENT_TUTOR_WORKLOG_DIR:-$USER_HOME/.hermes/profiles/$PROFILE/worklogs}"

lane_id="${1:-}"; shift || true
description=""
duration=""

while [ $# -gt 0 ]; do
  case "$1" in
    --description) description="$2"; shift 2 ;;
    --duration)    duration="$2";    shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$lane_id" ] || { echo "usage: $0 <lane_id> [--description ...] [--duration H:MM]"; exit 2; }

# Read title from lanes.json
STATE_DIR="$USER_HOME/.hermes/profiles/$PROFILE/state"
LANES="$STATE_DIR/lanes.json"
title="$(python3 - "$LANES" "$lane_id" <<'PY'
import json, sys
try:
    lanes = json.load(open(sys.argv[1]))
except Exception:
    print(""); sys.exit(0)
for l in lanes:
    if l.get("id") == sys.argv[2]:
        print(l.get("title", "")); break
PY
)"
[ -z "$title" ] && title="(no title in lanes.json)"

today="$(date +%Y-%m-%d)"

if [ -z "$description" ]; then
  read -r -p "Description (English, no semicolons): " description || true
  while [ -z "$description" ]; do read -r -p "Description: " description || true; done
fi
if [ -z "$duration" ]; then
  read -r -p "Duration (H:MM, e.g. 1:30): " duration || true
  while [ -z "$duration" ]; do read -r -p "Duration: " duration || true; done
fi

# Sanity: reject inner semicolons
if echo "$description" | grep -q ';'; then
  echo "ERROR: description contains ';'. Rewrite with commas/colons/dashes before logging."
  exit 1
fi

proposed="$description; $duration; $today"

echo
echo "Proposed worklog line for $today:"
echo "  $proposed"
echo
echo "Context: lane=$lane_id title=$title"
echo "File:    $WORKLOG_DIR/worklog-$today.txt"
echo
read -r -p "Append? (yes/no) " ans || true
if [ "$ans" != "yes" ]; then
  echo "cancelled"
  exit 0
fi

python3 "$WORKLOG_DIR/daily_log.py" "$description" "$duration"

# Post-write validation
echo
echo "post-write validation:"
awk -F';' '{printf "  line %d: %d campos\n", NR, NF}' \
  "$WORKLOG_DIR/worklog-$today.txt"