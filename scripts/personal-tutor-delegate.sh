#!/usr/bin/env bash
# Render a bounded learning-unit prompt and inject it into a Codex tmux pane.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

lane_id="" repo="" branch="" worktree="" goal="" allowed="" criteria=""
target="" concept="" learning_context="" skills="" verification=""
dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --branch) branch="${2:?}"; shift 2 ;;
    --worktree) worktree="${2:?}"; shift 2 ;;
    --goal) goal="${2:?}"; shift 2 ;;
    --allowed) allowed="${2:?}"; shift 2 ;;
    --criteria) criteria="${2:?}"; shift 2 ;;
    --target) target="${2:?}"; shift 2 ;;
    --concept) concept="${2:?}"; shift 2 ;;
    --learning-context) learning_context="${2:?}"; shift 2 ;;
    --skills) skills="${2:?}"; shift 2 ;;
    --verification) verification="${2:?}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -*) echo "unknown option: $1"; exit 2 ;;
    *) [ -z "$lane_id" ] || { echo "unexpected argument: $1"; exit 2; }; lane_id="$1"; shift ;;
  esac
done

[ -n "$lane_id" ] || { echo "usage: personal-tutor-delegate <lane-id> --repo ... --branch ... --goal ... --allowed ... --criteria ... --concept ... --verification ..."; exit 2; }
[[ "$lane_id" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "lane id may contain only letters, numbers, dot, underscore, and dash"; exit 2; }
for value in repo branch goal allowed criteria concept verification; do
  [ -n "${!value}" ] || { echo "--${value//_/-} required"; exit 2; }
done
printf '%s' "$criteria" | grep -q '[^|[:space:]]' || { echo "--criteria must contain at least one criterion"; exit 2; }
printf '%s' "$verification" | grep -q '[^[:space:]]' || { echo "--verification must contain a command"; exit 2; }
requested_repo="$repo"
repo="$(personal_tutor_git_root "$repo")" || {
  echo "not a git repository: $requested_repo"
  exit 2
}
worktree="${worktree:-$repo}"
requested_worktree="$worktree"
worktree="$(personal_tutor_git_root "$worktree")" || {
  echo "not a git worktree: $requested_worktree"
  exit 2
}
repo_common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)"
worktree_common="$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)"
[ "$(readlink -f "$repo_common")" = "$(readlink -f "$worktree_common")" ] || {
  echo "worktree does not belong to repository: $worktree"
  exit 2
}
actual_branch="$(git -C "$worktree" rev-parse --abbrev-ref HEAD)"
[ "$actual_branch" = "$branch" ] || { echo "branch mismatch before delegation: actual=$actual_branch expected=$branch"; exit 1; }
git check-ref-format --branch "$branch" >/dev/null 2>&1 || { echo "invalid branch name"; exit 2; }
python3 - "$goal" "$allowed" "$criteria" "$concept" "$learning_context" "$skills" "$verification" <<'PY'
import re
import sys

labels = ("goal", "allowed", "criteria", "concept", "learning context", "skills", "verification")
for label, value in zip(labels, sys.argv[1:]):
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in value):
        raise SystemExit(f"{label} must be a single control-free line")
    if "```" in value or re.search(r"(^|\s)#{1,6}\s", value):
        raise SystemExit(f"{label} contains Markdown control syntax")
for item in (part.strip() for part in sys.argv[2].split(",")):
    if not item or item.startswith("/") or item == ".." or item.startswith("../") or "/../" in item:
        raise SystemExit("allowed paths must be non-empty worktree-relative patterns without parent traversal")
PY

template="$PERSONAL_TUTOR_PROFILE_DIR/templates/personal-codex-lane-prompt.md"
if [ ! -f "$template" ]; then
  if [ -f "$SCRIPT_DIR/../templates/personal-codex-lane-prompt.md" ]; then
    template="$SCRIPT_DIR/../templates/personal-codex-lane-prompt.md"
  else
    source_root="$(cat "$PERSONAL_TUTOR_PROFILE_DIR/state/source-root" 2>/dev/null || true)"
    template="$source_root/templates/personal-codex-lane-prompt.md"
  fi
fi
[ -f "$template" ] || { echo "Codex lane template not found"; exit 2; }

# Record the exact pre-delegation dirty state outside the repository. The audit
# later compares content hashes so pre-existing allowed changes cannot be
# misattributed to this lane.
umask 077
lane_state_root="${PERSONAL_TUTOR_LANE_CACHE_ROOT:-$PERSONAL_TUTOR_USER_HOME/.cache/personal-dev-tutor/lanes}"
lane_state_root="$(personal_tutor_resolve_path "$lane_state_root")"
if personal_tutor_path_is_within "$lane_state_root" "$worktree"; then
  echo "lane state cache must be outside the worktree"
  exit 2
fi
mkdir -p "$lane_state_root"
chmod 700 "$lane_state_root"
worktree_key="$(personal_tutor_path_key "$worktree")"
lane_state="$lane_state_root/$worktree_key-$lane_id.json"
python3 - "$worktree" "$branch" "$lane_state" <<'PY'
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

repo, branch, output = sys.argv[1:]

def git(*args):
    return subprocess.check_output(["git", "-C", repo, *args])

def paths_now():
    paths = set()
    for args in (("diff", "--name-only", "-z"),
                 ("diff", "--cached", "--name-only", "-z"),
                 ("ls-files", "--others", "--exclude-standard", "-z")):
        paths.update(p.decode("utf-8", "surrogateescape") for p in git(*args).split(b"\0") if p)
    return paths

def digest(relative):
    path = Path(repo, relative)
    if path.is_symlink():
        return "symlink:" + os.readlink(path)
    if not path.is_file():
        return "missing"
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

record = {
    "schema": 1,
    "worktree": str(Path(repo).resolve()),
    "branch": branch,
    "head": git("rev-parse", "HEAD").decode().strip(),
    "initial": {path: digest(path) for path in sorted(paths_now())},
}
Path(output).write_text(json.dumps(record, sort_keys=True) + "\n")
os.chmod(output, 0o600)
PY

if [ "$dry_run" -eq 0 ]; then
  if [ -z "$target" ]; then
    while IFS='|' read -r pane command path dead codex_home; do
      personal_tutor_is_live_codex_pane "$command" "$dead" "$codex_home" || continue
      personal_tutor_path_is_within "$path" "$worktree" || continue
      target="$PERSONAL_TUTOR_SESSION:$pane"
      break
    done < <(tmux list-panes -s -t "$PERSONAL_TUTOR_SESSION" -F '#{window_index}.#{pane_index}|#{pane_current_command}|#{pane_current_path}|#{pane_dead}|#{@personal_tutor_codex_home}')
  fi
  [ -n "$target" ] || { echo "no live Codex pane found for worktree '$worktree' in tmux session '$PERSONAL_TUTOR_SESSION'"; exit 1; }
  case "$target" in "$PERSONAL_TUTOR_SESSION":*) ;; *) echo "target must belong to $PERSONAL_TUTOR_SESSION"; exit 2 ;; esac
  pane_command="$(tmux display-message -p -t "$target" '#{pane_current_command}')"
  pane_dead="$(tmux display-message -p -t "$target" '#{pane_dead}')"
  pane_path="$(tmux display-message -p -t "$target" '#{pane_current_path}')"
  pane_codex_home="$(tmux display-message -p -t "$target" '#{@personal_tutor_codex_home}')"
  [ "$pane_command" = codex ] && [ "$pane_dead" = 0 ] || { echo "target is not a live Codex pane: $target command=$pane_command dead=$pane_dead"; exit 1; }
  [ "$pane_codex_home" = "$PERSONAL_TUTOR_CODEX_HOME" ] || { echo "target is not an isolated Personal Tutor Codex pane: $target"; exit 1; }
  personal_tutor_path_is_within "$pane_path" "$worktree" || {
    echo "target is not attached to worktree: $target path=$pane_path expected=$worktree"
    exit 1
  }
fi

prompt_file="$(mktemp "${TMPDIR:-/tmp}/personal-dev-tutor-${lane_id}.XXXXXX.md")"
retain_prompt=0
cleanup_prompt() { [ "$retain_prompt" -eq 1 ] || rm -f "$prompt_file"; }
trap cleanup_prompt EXIT
python3 - "$template" "$prompt_file" "$repo" "$branch" "$worktree" "$goal" \
  "$allowed" "$criteria" "$concept" "$learning_context" "$skills" "$verification" <<'PY'
from pathlib import Path
import shlex
import sys

(template, output, repo, branch, worktree, goal, allowed, criteria,
 concept, learning_context, skills, verification) = sys.argv[1:]
text = Path(template).read_text()

def bullets(raw):
    return "\n".join(f"- {item.strip()}" for item in raw.split(",") if item.strip())

def numbered(raw):
    return "\n".join(f"{index}. {item.strip()}" for index, item in enumerate(raw.split("|"), 1) if item.strip())

replacements = {
    "<REPO_ABS_PATH>": repo,
    "<BRANCH_EXPECTED>": branch,
    "<WORKTREE_PATH>": worktree,
    "<WORKTREE_SHELL_PATH>": shlex.quote(worktree),
    "<LEARNING_CONCEPT>": concept,
    "<LEARNING_CONTEXT>": learning_context or "This concept is required by the current GSD plan.",
    "<GOAL_PARAGRAPH>": goal,
    "- <ALLOWED_PATHS>": bullets(allowed),
    "1. <AC1>\n2. <AC2>\n3. <AC3>": numbered(criteria),
    "<SKILL_HINTS>": bullets(skills) if skills else "- Use repository instructions and the narrowest relevant skill.",
    "<VERIFICATION_COMMANDS>": verification or "Run the focused test first, then the relevant regression suite.",
}
for old, new in replacements.items():
    text = text.replace(old, new)
Path(output).write_text(text)
PY

if [ "$dry_run" -eq 1 ]; then
  # Dry-run explicitly retains the mode-0600 artifact so the caller can inspect it.
  retain_prompt=1
  printf 'RENDERED lane=%s prompt=%s concept=%s\n' "$lane_id" "$prompt_file" "$concept"
  exit 0
fi

buffer="personal-dev-tutor-$lane_id"
tmux load-buffer -b "$buffer" "$prompt_file"
tmux paste-buffer -b "$buffer" -d -t "$target"
sleep 1
tmux send-keys -t "$target" Enter
printf 'DELEGATED lane=%s target=%s prompt=transient-deleted concept=%s\n' "$lane_id" "$target" "$concept"
