#!/usr/bin/env bash
# tutor-doctor.sh — front-door readiness check for Agent Tutor Orchestrator.
# Wraps smoke + status (+ optional bootstrap --check). Other tutor-* scripts
# are internal helpers; advertise install + doctor only.
#
# Exit: 0 if smoke passes, else smoke's exit code.
set -uo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"

echo "==> Agent Tutor Orchestrator doctor"
echo

run_optional_check() {
  local script="$1" label="$2"
  shift 2
  if [ -x "$SCRIPT_DIR/$script" ]; then
    echo "-- $label --"
    "$SCRIPT_DIR/$script" "$@" || true
    echo
  fi
}

run_optional_check tutor-status status
run_optional_check tutor-bootstrap "bootstrap --check" --check

echo "-- smoke --"
exec "$SCRIPT_DIR/tutor-smoke.sh"
