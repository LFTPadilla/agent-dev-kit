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

if [ -x "$SCRIPT_DIR/tutor-status.sh" ]; then
  echo "-- status --"
  "$SCRIPT_DIR/tutor-status.sh" || true
  echo
fi

if [ -x "$SCRIPT_DIR/tutor-bootstrap.sh" ]; then
  echo "-- bootstrap --check --"
  "$SCRIPT_DIR/tutor-bootstrap.sh" --check || true
  echo
fi

echo "-- smoke --"
exec "$SCRIPT_DIR/tutor-smoke.sh"
