#!/usr/bin/env bash
# tutor-preflight.sh — capture the orchestrator pre-flight context as YAML.
#
# Writes ~/.hermes/profiles/<profile>/state/preflight-<timestamp>.yaml and
# prints its path. Re-run anytime; the orchestrator picks the newest file.
#
# Usage:
#   tutor-preflight                      # interactive
#   tutor-preflight --quick <repo> <branch>
#
# IMPORTANT: resolves USER_HOME because under Hermes-cron or when invoked
# via a profile wrapper, HOME points to the profile dir.
set -uo pipefail

SELF_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
# Resolve to absolute dir so relative invocations cannot spin on dirname(".") → ".".
HERMES_DIR=""
dir="$(cd "$(dirname "$SELF_PATH")" && pwd)"
while [ "$dir" != "/" ]; do
  if [ "$(basename "$dir")" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
if [ -n "$HERMES_DIR" ]; then USER_HOME="$(dirname "$HERMES_DIR")"
else USER_HOME="${HOME:-/home/felipe}"; fi
[ -d "$USER_HOME" ] || USER_HOME="${HOME:-/home/felipe}"

PROFILE="${AGENT_TUTOR_PROFILE:-agent-tutor-orchestrator}"
STATE_DIR="$USER_HOME/.hermes/profiles/$PROFILE/state"
mkdir -p "$STATE_DIR"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="$STATE_DIR/preflight-$ts.yaml"

ask() {
  local prompt="$1" default="${2:-}"
  local ans
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " ans || true
    printf '%s' "${ans:-$default}"
  else
    while [ -z "${ans:-}" ]; do
      read -r -p "$prompt: " ans || true
    done
    printf '%s' "$ans"
  fi
}

repo=""
branch=""
strategy="single"
lanes=""
push_ok="no"
force_push_ok="no"
secrets_ok="no"
deploy_ok="no"
expected_runtime_min=""
worklog_entry="yes"
kanban_board=""

quick=0
if [ "${1:-}" = "--quick" ]; then
  quick=1
  shift
  repo="${1:-}"; branch="${2:-}"; strategy="${3:-single}"
fi

if [ "$quick" -eq 1 ]; then
  [ -z "$repo" ]   && { echo "quick mode requires repo"; exit 2; }
  [ -z "$branch" ] && { echo "quick mode requires branch"; exit 2; }
else
  repo="$(ask 'Repo absolute path' "$PWD")"
  branch="$(ask 'Expected branch name' "main")"
  strategy="$(ask 'Worktree strategy (single|per-lane|none)' "per-lane")"
  push_ok="$(ask 'Push allowed? (yes|no)' "no")"
  force_push_ok="$(ask 'Force-push allowed? (yes|no)' "no")"
  secrets_ok="$(ask 'Secrets edit allowed? (yes|no)' "no")"
  deploy_ok="$(ask 'Deploy allowed? (yes|no)' "no")"
  expected_runtime_min="$(ask 'Expected total runtime (minutes)' "60")"
  worklog_entry="$(ask 'Suggest worklog entry per lane? (yes|no)' "yes")"
  kanban_board="$(ask 'Kanban board (blank to skip)' "")"
fi

cat > "$out" <<EOF
# Pre-flight context for agent-tutor-orchestrator
# Generated: $ts
profile: $PROFILE
repo: "$repo"
branch: "$branch"
worktree_strategy: "$strategy"
approvals:
  push: $push_ok
  force_push: $force_push_ok
  secrets_edit: $secrets_ok
  deploy: $deploy_ok
runtime_minutes: ${expected_runtime_min:-60}
worklog_suggest: $worklog_entry
kanban_board: "${kanban_board:-}"
lanes: []
EOF

printf '%s\n' "$out"