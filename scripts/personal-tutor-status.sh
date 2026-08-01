#!/usr/bin/env bash
# Show Codex workers available to the Personal Dev Tutor.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo|--worktree) repo="${2:?$1 requires a path}"; shift 2 ;;
    *) echo "usage: personal-tutor-status [--repo <repository-or-worktree>]"; exit 2 ;;
  esac
done
requested_repo="$repo"
if ! repo="$(personal_tutor_git_root "$repo")"; then
  if [ -n "$requested_repo" ]; then
    echo "not a Git repository/worktree: $requested_repo"
    exit 2
  fi
  echo "NOT READY: pass --repo from outside a Git worktree"
  exit 1
fi

if ! tmux has-session -t "$PERSONAL_TUTOR_SESSION" 2>/dev/null; then
  echo "NOT READY: tmux session '$PERSONAL_TUTOR_SESSION' does not exist"
  exit 1
fi

printf 'Repository/worktree: %s\n\n' "$repo"
printf '%-12s %-18s %-12s %-5s %s\n' TARGET WINDOW COMMAND DEAD REPOSITORY
printf '%s\n' '--------------------------------------------------------------------------------'
codex_count=0
while IFS='|' read -r pane name command dead repository codex_home; do
  [ "$command" = codex ] && [ "$dead" = 0 ] || continue
  [ "$codex_home" = "$PERSONAL_TUTOR_CODEX_HOME" ] || continue
  personal_tutor_path_is_within "$repository" "$repo" || continue
  printf '%-12s %-18s %-12s %-5s %s\n' "$PERSONAL_TUTOR_SESSION:$pane" "$name" "$command" "$dead" "$repository"
  codex_count=$((codex_count + 1))
done < <(tmux list-panes -s -t "$PERSONAL_TUTOR_SESSION" -F '#{window_index}.#{pane_index}|#{window_name}|#{pane_current_command}|#{pane_dead}|#{pane_current_path}|#{@personal_tutor_codex_home}')

printf '\nRepository-matched isolated Codex workers: %s\n' "$codex_count"
[ "$codex_count" -gt 0 ]
