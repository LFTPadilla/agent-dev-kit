#!/usr/bin/env bash
# Independently audit a Codex learning unit against its recorded baseline.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

lane_id="${1:-}"
[ -n "$lane_id" ] && shift || true
repo="" branch="" allowed="" verification="" concept="" criteria="" evidence=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --branch) branch="${2:?}"; shift 2 ;;
    --allowed) allowed="${2:?}"; shift 2 ;;
    --criteria) criteria="${2:?}"; shift 2 ;;
    --evidence) evidence="${2:?}"; shift 2 ;;
    --verification) verification="${2:?}"; shift 2 ;;
    --concept) concept="${2:?}"; shift 2 ;;
    *) echo "unknown argument: $1"; exit 2 ;;
  esac
done
for value in lane_id repo branch allowed criteria evidence verification; do
  [ -n "${!value}" ] || { echo "missing required value: $value"; exit 2; }
done
[[ "$lane_id" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "invalid lane id"; exit 2; }
for value in allowed criteria evidence verification; do
  printf '%s' "${!value}" | grep -q '[^|[:space:]]' || { echo "$value must contain a non-empty value"; exit 2; }
done
requested_repo="$repo"
repo="$(personal_tutor_git_root "$repo")" || {
  echo "not a git repository: $requested_repo"
  exit 2
}
actual_branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
branch_ok=1
[ "$actual_branch" = "$branch" ] || branch_ok=0

umask 077
lane_state_root="${PERSONAL_TUTOR_LANE_CACHE_ROOT:-$PERSONAL_TUTOR_USER_HOME/.cache/personal-dev-tutor/lanes}"
lane_state_root="$(personal_tutor_resolve_path "$lane_state_root")"
if personal_tutor_path_is_within "$lane_state_root" "$repo"; then
  echo "lane state cache must be outside the worktree"
  exit 2
fi
worktree_key="$(personal_tutor_path_key "$repo")"
lane_state="$lane_state_root/$worktree_key-$lane_id.json"
[ -f "$lane_state" ] || { echo "missing pre-delegation baseline for lane: $lane_id"; exit 1; }
changed_file="$(mktemp)"
violations_file="$(mktemp)"
cleanup() { rm -f "$changed_file" "$violations_file"; }
trap cleanup EXIT

python3 - "$lane_state" "$repo" "$allowed" "$changed_file" "$violations_file" <<'PY'
from pathlib import Path
import fnmatch
import hashlib
import json
import os
import subprocess
import sys

state_path, repo, allowed, changed_path, violations_path = sys.argv[1:]
state = json.loads(Path(state_path).read_text())
repo = str(Path(repo).resolve())

def git(*args):
    return subprocess.check_output(["git", "-C", repo, *args])

if state.get("schema") != 1 or state.get("worktree") != repo:
    raise SystemExit("baseline does not belong to this worktree")
current_branch = git("rev-parse", "--abbrev-ref", "HEAD").decode().strip()
current_head = git("rev-parse", "HEAD").decode().strip()
if state.get("branch") != current_branch:
    raise SystemExit(
        f"baseline branch changed: recorded={state.get('branch')} current={current_branch}"
    )
if state.get("head") != current_head:
    raise SystemExit(
        f"baseline HEAD changed: recorded={state.get('head')} current={current_head}"
    )

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

initial = state.get("initial", {})
current_paths = paths_now()
changed = [path for path in sorted(set(initial) | current_paths)
           if initial.get(path, "clean") != (digest(path) if path in current_paths else "clean")]
patterns = [item.strip() for item in allowed.split(",") if item.strip()]
violations = [path for path in changed if not any(fnmatch.fnmatch(path, pattern) for pattern in patterns)]
Path(changed_path).write_bytes(b"".join(os.fsencode(path) + b"\0" for path in changed))
Path(violations_path).write_bytes(b"".join(os.fsencode(path) + b"\0" for path in violations))
PY

changed=()
mapfile -d '' changed < "$changed_file"
violations=()
mapfile -d '' violations < "$violations_file"

mapping_ok=1
criteria_mapping="$(python3 - "$criteria" "$evidence" <<'PY'
import sys
criteria = [item.strip() for item in sys.argv[1].split("|") if item.strip()]
evidence = [item.strip() for item in sys.argv[2].split("|") if item.strip()]
if len(criteria) != len(evidence):
    raise SystemExit(f"acceptance criteria/evidence count mismatch: {len(criteria)} criteria, {len(evidence)} evidence entries")
for index, (criterion, proof) in enumerate(zip(criteria, evidence), 1):
    print(f"  {index}. {criterion}\n     evidence: {proof}")
PY
)" || mapping_ok=0

printf '[1/5] Branch and baseline\n'
[ "$branch_ok" -eq 1 ] && printf 'OK   %s\n' "$actual_branch" || printf 'FAIL actual=%s expected=%s\n' "$actual_branch" "$branch"
printf 'OK   baseline=%s\n' "$lane_state"

changed_ok=1
printf '\n[2/5] Lane-attributable changed files\n'
if [ "${#changed[@]}" -eq 0 ]; then
  printf 'FAIL no changes since delegation baseline\n'
  changed_ok=0
else
  printf '  %s\n' "${changed[@]}"
fi

printf '\n[3/5] Allowlist\n'
if [ "${#violations[@]}" -eq 0 ]; then
  printf 'OK   every lane-attributable file is allowed\n'
else
  printf 'FAIL files outside allowlist:\n  %s\n' "${violations[@]}"
fi

printf '\n[4/5] Acceptance criteria evidence map\n'
if [ "$mapping_ok" -eq 1 ]; then
  printf '%s\n' "$criteria_mapping"
else
  printf 'FAIL criteria require exactly one non-empty evidence entry each\n'
fi

verification_ok=1
printf '\n[5/5] Independent verification\n'
printf 'RUN  %s\n' "$verification"
if (cd "$repo" && bash --noprofile --norc -c "$verification"); then
  printf 'OK   verification passed\n'
else
  printf 'FAIL verification failed\n'
  verification_ok=0
fi

printf '\nDiff summary (current worktree; lane paths listed above)\n'
git -C "$repo" diff --stat -- "${changed[@]}" || true
git -C "$repo" diff --cached --stat -- "${changed[@]}" || true

if [ "$branch_ok" -eq 1 ] && [ "$changed_ok" -eq 1 ] && \
   [ "${#violations[@]}" -eq 0 ] && [ "$mapping_ok" -eq 1 ] && \
   [ "$verification_ok" -eq 1 ]; then
  printf '\nVERDICT: READY_FOR_TEACH_BACK\n'
  printf 'Learning checkpoint: explain "%s" using the changed code, then name one alternative and one failure mode.\n' "${concept:-the implemented concept}"
  exit 0
fi
printf '\nVERDICT: NEEDS_CORRECTION\n'
exit 1
