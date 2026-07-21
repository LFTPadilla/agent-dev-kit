#!/usr/bin/env bash
# tutor-delegate.sh — fill lane-prompt.md template and inject into a tmux Claude pane.
#
# Usage:
#   tutor-delegate <lane_id> \
#     --repo <abs> --branch <name> --worktree <abs> \
#     --goal "<text>" --allowed "<f1>,<f2>" --forbidden "<f3>" \
#     --criteria "<c1>|<c2>|<c3>" \
#     --target "tutor:<n>" \
#     [--context "<text>"] [--skills "<hint1>,<hint2>"]
#
# Writes the rendered prompt to /tmp/lane-<id>-prompt.md, then injects via
# the tmux-safe three-step (load-buffer + paste-buffer + sleep + Enter).
# Bumps lane activity in lanes.json.
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
TEMPLATE="$USER_HOME/.hermes/profiles/$PROFILE/templates/lane-prompt.md"

[ -f "$TEMPLATE" ] || { echo "template missing: $TEMPLATE"; exit 2; }

lane_id=""; repo=""; branch=""; worktree=""; goal=""
allowed=""; forbidden=""; criteria=""; target=""
context=""; skills=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)      repo="$2"; shift 2 ;;
    --branch)    branch="$2"; shift 2 ;;
    --worktree)  worktree="$2"; shift 2 ;;
    --goal)      goal="$2"; shift 2 ;;
    --allowed)   allowed="$2"; shift 2 ;;
    --forbidden) forbidden="$2"; shift 2 ;;
    --criteria)  criteria="$2"; shift 2 ;;
    --target)    target="$2"; shift 2 ;;
    --context)   context="$2"; shift 2 ;;
    --skills)    skills="$2"; shift 2 ;;
    *)           lane_id="$1"; shift ;;
  esac
done

[ -n "$lane_id" ] || { echo "usage: $0 <lane_id> [flags]"; exit 2; }
[ -n "$target" ] || { echo "--target required (e.g. tutor:4)"; exit 2; }
[ -n "$repo" ]   || { echo "--repo required"; exit 2; }
[ -n "$branch" ] || { echo "--branch required"; exit 2; }

mkdir -p /tmp
prompt_file="/tmp/lane-$lane_id-prompt.md"

# Render template
python3 - "$TEMPLATE" "$prompt_file" "$repo" "$branch" "$worktree" \
        "$goal" "$allowed" "$forbidden" "$criteria" "$context" "$skills" <<'PY'
import sys
tpl_path, out_path = sys.argv[1], sys.argv[2]
repo, branch, worktree, goal, allowed, forbidden, criteria, context, skills = sys.argv[3:]

text = open(tpl_path).read()
def bullet(s): return "\n".join(f"- {x.strip()}" for x in s.split(",") if x.strip())
def numbered(s):
    return "\n".join(f"{i+1}. {x.strip()}"
                     for i, x in enumerate(s.split("|")) if x.strip())

repl = {
    "<REPO_ABS_PATH>": repo,
    "<BRANCH_EXPECTED>": branch,
    "<WORKTREE_PATH>": worktree or repo,
    "<GOAL_PARAGRAPH>": goal,
    "<ALLOWED_FILE_1>": "",
    "<ALLOWED_FILE_2>": "",
    "<FORBIDDEN_FILE_1>": "",
    "<SKILL_HINTS>": bullet(skills) if skills else "- (none — use judgment)",
    "<USER_CONTEXT>": context or "(none — operator will provide context per lane)",
}
for k, v in repl.items():
    text = text.replace(k, v)

# Placeholders for allowed/forbidden/criteria bullets
text = text.replace("- <ALLOWED_FILE_1>\n- <ALLOWED_FILE_2>",
                    bullet(allowed) or "- (none specified)")
text = text.replace("- <FORBIDDEN_FILE_1>",
                    (bullet(forbidden).split("\n", 1)[0] if forbidden
                     else "- (none specified)"))
text = text.replace(
    "1. <AC1>\n2. <AC2>\n3. <AC3>",
    numbered(criteria) or "1. (no criteria specified)"
)

open(out_path, "w").write(text)
PY

# Inject via the tmux-safe three-step
tmux load-buffer -t "$target" "$prompt_file"
tmux paste-buffer -t "$target"
sleep 1
tmux send-keys -t "$target" Enter

# Record lane state
lane_script="$USER_HOME/.hermes/profiles/$PROFILE/scripts/tutor-lane-update.sh"
[ -x "$lane_script" ] && \
  "$lane_script" "$lane_id" "$goal" "$target" "$branch" running >/dev/null

printf 'injected lane=%s target=%s prompt=%s\n' "$lane_id" "$target" "$prompt_file"