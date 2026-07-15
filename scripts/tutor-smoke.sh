#!/usr/bin/env bash
# tutor-smoke.sh — readiness checks for the Hermes Workflow Tutor profile.
# Run before starting a real session to catch misconfig early.
#
# Exit code: 0 = READY, 1 = one or more checks failed.
#
# IMPORTANT: when invoked from a symlink under ~/.hermes/profiles/<p>/home/,
# Hermes exports HOME to the profile dir. We resolve USER_HOME via the
# parent of /home/felipe/.hermes so we always read the real user home.
set -uo pipefail

# Resolve real user home. We don't trust $HOME because under Hermes-cron or
# profile wrappers, it may point to a profile dir. Use the path of this
# script (or its realpath) to derive the canonical user home.
SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
# SELF_PATH is something like /home/felipe/.hermes/profiles/hermes-tutor/scripts/tutor-smoke.sh
# Walk up until we find a dir named .hermes, then USER_HOME is its parent.
HERMES_DIR=""
dir="$(dirname "$SELF_PATH")"
while [ "$dir" != "/" ]; do
  base="$(basename "$dir")"
  if [ "$base" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  dir="$(dirname "$dir")"
done
if [ -n "$HERMES_DIR" ]; then
  USER_HOME="$(dirname "$HERMES_DIR")"
else
  USER_HOME="/home/felipe"
fi
[ -d "$USER_HOME" ] || USER_HOME="/home/felipe"

PROFILE="${HERMES_TUTOR_PROFILE:-hermes-tutor}"
SESSION="${HERMES_TUTOR_SESSION:-komp}"
WORKLOG_DIR="$USER_HOME/kommit/worklogs"
SKILLS_DIR="$USER_HOME/.hermes/profiles/$PROFILE/skills"
PROFILE_DIR="$USER_HOME/.hermes/profiles/$PROFILE"
CONFIG_YAML="$PROFILE_DIR/config.yaml"
WRAPPER_CANDIDATES=("$USER_HOME/.local/bin/hermes-tutor"
                    "$USER_HOME/.hermes/profiles/kommit/home/.local/bin/hermes-tutor")

pass=0
fail=0
failures=()

check() {
  local label="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    printf '  OK   %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  FAIL %s\n' "$label"
    fail=$((fail + 1))
    failures+=("$label")
  fi
}

# Find SKILL.md for a named skill anywhere under SKILLS_DIR (1 or 2 levels).
find_skill() {
  local name="$1"
  [ -f "$SKILLS_DIR/$name/SKILL.md" ] && return 0
  for d in "$SKILLS_DIR"/*/; do
    [ -f "$d/$name/SKILL.md" ] && return 0
  done
  return 1
}

section() { printf '\n[%s]\n' "$1"; }

section "Profile"
check "hermes binary on PATH" "command -v hermes"
check "$PROFILE profile exists" "hermes --profile $PROFILE profile show $PROFILE"

wrapper=""
for w in "${WRAPPER_CANDIDATES[@]}"; do
  [ -x "$w" ] && wrapper="$w" && break
done
if [ -n "$wrapper" ]; then
  printf '  OK   wrapper %s exists\n' "$wrapper"
  pass=$((pass + 1))
  if grep -qE "hermes.*(--profile|-p)[[:space:]]+$PROFILE" "$wrapper"; then
    printf '  OK   wrapper delegates to %s\n' "$PROFILE"
    pass=$((pass + 1))
  else
    printf '  FAIL wrapper does not delegate to %s\n' "$PROFILE"
    fail=$((fail + 1)); failures+=("wrapper delegate")
  fi
else
  printf '  FAIL no hermes-tutor wrapper found\n'
  fail=$((fail + 1)); failures+=("wrapper")
fi

section "Model"
model_line="$(hermes --profile "$PROFILE" profile show "$PROFILE" 2>/dev/null | grep -m1 '^Model:' || true)"
if [ -n "$model_line" ]; then
  printf '  OK   %s\n' "$model_line"
  pass=$((pass + 1))
  case "$model_line" in
    *MiniMax-M3*|*claude-sonnet*|*claude-haiku*|*claude-opus*) ;;
    *) printf '  FAIL model unexpected: %s\n' "$model_line"
       fail=$((fail + 1)); failures+=("model") ;;
  esac
else
  printf '  FAIL could not read model line\n'
  fail=$((fail + 1)); failures+=("model line")
fi

section "Skills"
if find_skill ai-workflow-orchestrator; then
  printf '  OK   ai-workflow-orchestrator SKILL.md\n'; pass=$((pass+1))
else
  printf '  FAIL ai-workflow-orchestrator SKILL.md\n'; fail=$((fail+1)); failures+=("ai-workflow-orchestrator")
fi
if [ -L "$SKILLS_DIR/worklog" ] || [ -f "$SKILLS_DIR/worklog/SKILL.md" ]; then
  printf '  OK   worklog available\n'; pass=$((pass+1))
else
  printf '  FAIL worklog not found\n'; fail=$((fail+1)); failures+=("worklog")
fi
if find_skill delegating-to-tmux-claude; then
  printf '  OK   delegating-to-tmux-claude SKILL.md\n'; pass=$((pass+1))
else
  printf '  FAIL delegating-to-tmux-claude SKILL.md\n'; fail=$((fail+1)); failures+=("delegating-to-tmux-claude")
fi
if find_skill kanban-orchestrator; then
  printf '  OK   kanban-orchestrator SKILL.md\n'; pass=$((pass+1))
else
  printf '  FAIL kanban-orchestrator SKILL.md\n'; fail=$((fail+1)); failures+=("kanban-orchestrator")
fi
if find_skill kanban-worker; then
  printf '  OK   kanban-worker SKILL.md\n'; pass=$((pass+1))
else
  printf '  FAIL kanban-worker SKILL.md\n'; fail=$((fail+1)); failures+=("kanban-worker")
fi

section "tmux delegate session"
check "tmux server up"           "tmux list-sessions"
check "session '$SESSION' exists" "tmux has-session -t $SESSION"
claude_panes="$(tmux list-windows -t "$SESSION" -F '#{pane_current_command}' 2>/dev/null | grep -c '^claude$' || true)"
if [ "$claude_panes" -gt 0 ]; then
  printf '  OK   %d Claude pane(s) in %s\n' "$claude_panes" "$SESSION"
  pass=$((pass + 1))
else
  printf '  FAIL no Claude panes in %s\n' "$SESSION"
  fail=$((fail + 1)); failures+=("claude panes")
fi

section "Worklog"
check "worklog dir exists"        "test -d $WORKLOG_DIR"
check "daily_log.py present"      "test -f $WORKLOG_DIR/daily_log.py"
check "daily_summary.sh present"  "test -f $WORKLOG_DIR/daily_summary.sh"
# Run daily_summary.sh, capture exit; treat exit 0 as OK, log otherwise
if bash "$WORKLOG_DIR/daily_summary.sh" >/dev/null 2>&1; then
  printf '  OK   daily_summary.sh runs cleanly\n'; pass=$((pass+1))
else
  printf '  FAIL daily_summary.sh exit %s (re-run interactively to see error)\n' "$?"
  fail=$((fail+1)); failures+=("daily_summary.sh")
fi

section "Sandbox"
if grep -qiE "redact_secrets:[[:space:]]*(True|true|yes)" "$CONFIG_YAML"; then
  printf '  OK   security.redact_secrets=true\n'; pass=$((pass+1))
else
  printf '  FAIL security.redact_secrets not True\n'; fail=$((fail+1)); failures+=("redact_secrets")
fi
# approvals.mode can be nested under approvals: or top-level depending on hermes version
if grep -qE "mode:[[:space:]]*smart" "$CONFIG_YAML" || \
   grep -qE "approvals:[[:space:]]*$" "$CONFIG_YAML"; then
  printf '  OK   approvals.mode=smart\n'; pass=$((pass+1))
else
  printf '  FAIL approvals.mode not smart\n'; fail=$((fail+1)); failures+=("approvals.mode")
fi

section "Helpers"
for s in tutor-smoke tutor-status tutor-preflight tutor-audit \
         tutor-delegate tutor-log-suggest tutor-lane-update tutor-install \
         tutor-bootstrap; do
  check "$s installed" "test -x $USER_HOME/.local/bin/$s"
done

# Optional: if --bootstrap was passed, run the skill repair pass too
if [ "${1:-}" = "--bootstrap" ]; then
  section "Bootstrap (auto-repair)"
  if "$USER_HOME/.local/bin/tutor-bootstrap" --json >/tmp/hermes-tutor-bootstrap.$$ 2>&1; then
    broken="$(python3 -c "import json,sys; print(json.load(open('/tmp/hermes-tutor-bootstrap.$$')).get('broken', 0))")"
    if [ "$broken" = "0" ]; then
      printf '  OK   bootstrap repaired, no broken skills\n'
      pass=$((pass + 1))
    else
      printf '  FAIL bootstrap could not repair %s skills\n' "$broken"
      fail=$((fail + 1)); failures+=("bootstrap")
    fi
  else
    printf '  FAIL bootstrap exit code %s\n' "$?"
    fail=$((fail + 1)); failures+=("bootstrap")
  fi
  rm -f /tmp/hermes-tutor-bootstrap.$$
fi

section "Summary"
printf '  %d checks passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf '\nFAIL — fix before starting a real session:\n'
  for f in "${failures[@]}"; do printf '  - %s\n' "$f"; done
  exit 1
fi
printf '\nREADY — hermes-tutor profile is operational.\n'