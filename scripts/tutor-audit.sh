#!/usr/bin/env bash
# tutor-audit.sh — verify a delegated lane against its allowlist and contract.
#
# Usage:
#   tutor-audit <lane_id> --repo <abs> --branch <expected> --allowed "<f1>,<f2>"
#
# Reads the lane record from lanes.json and the rendered prompt at
# /tmp/lane-<id>-prompt.md to extract acceptance criteria. Prints a verdict.
#
# Exit codes:
#   0 = APTO PARA REVIEW
#   1 = NECESITA CORRECCIONES (verdict failure, details printed)
#   2 = setup error (missing args, bad lane id)
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
LANES="$STATE_DIR/lanes.json"
prompt_file="/tmp/lane-${1:-}-prompt.md"

lane_id="${1:-}"; shift || true
repo=""; branch=""; allowed=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    repo="$2"; shift 2 ;;
    --branch)  branch="$2"; shift 2 ;;
    --allowed) allowed="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$lane_id" ] || { echo "usage: $0 <lane_id> [--repo R] [--branch B] [--allowed f1,f2]"; exit 2; }
[ -n "$repo" ]   || { echo "--repo required"; exit 2; }
[ -n "$branch" ] || { echo "--branch required"; exit 2; }

cd "$repo" || { echo "cannot cd to $repo"; exit 2; }

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
echo "[1/4] branch check"
if [ "$current_branch" = "$branch" ]; then
  echo "  OK   branch=$current_branch matches expected=$branch"
else
  echo "  FAIL branch=$current_branch does not match expected=$branch"
fi

echo "[2/4] worktree cleanliness (no stray changes outside allowlist)"
status_out="$(git status --short 2>/dev/null)"
if [ -z "$status_out" ]; then
  echo "  OK   working tree clean"
else
  echo "  changed files:"
  echo "$status_out" | sed 's/^/    /'
fi

echo "[3/4] allowlist enforcement"
allowed_set="$(printf '%s' "$allowed" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u)"
violations="$(echo "$status_out" | awk '{print $2}' | sort -u | while read -r f; do
  [ -z "$f" ] && continue
  case ",$allowed," in *,"$f",*) ;; *) printf '%s\n' "$f" ;; esac
done)"

if [ -z "$violations" ]; then
  echo "  OK   all changes inside allowlist"
else
  echo "  FAIL files outside allowlist:"
  echo "$violations" | sed 's/^/    /'
fi

echo "[4/4] diff stats"
git diff --stat 2>/dev/null | sed 's/^/    /'

echo
echo "VERDICT:"
if [ "$current_branch" != "$branch" ]; then
  echo "  NECESITA CORRECCIONES: branch mismatch"
  exit 1
fi
if [ -n "$violations" ]; then
  echo "  NECESITA CORRECCIONES: files outside allowlist"
  exit 1
fi
echo "  APTO PARA REVIEW"
# Update lane state
lane_script="$USER_HOME/.hermes/profiles/$PROFILE/scripts/tutor-lane-update.sh"
[ -x "$lane_script" ] && \
  "$lane_script" "$lane_id" "" "" "" awaiting_review >/dev/null
exit 0