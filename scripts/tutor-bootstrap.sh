#!/usr/bin/env bash
# tutor-bootstrap.sh — verify and repair skills on profile boot.
#
# For every skill in profiles/hermes-tutor.yml's `include_skills`, plus a
# curated set of critical skills, check:
#   - the directory exists under ~/.hermes/profiles/<profile>/skills/
#   - SKILL.md exists and parses (frontmatter has `name:` and `description:`)
#   - name matches the directory name
#   - not a broken symlink
#
# Repair actions (in order):
#   1. If a healthy copy exists at ~/.hermes/skills/<name> (global), symlink
#      the profile copy to it.
#   2. Otherwise, if a healthy copy exists in another profile (kommit, local),
#      copy from the most-recently-modified version.
#   3. Otherwise, fall back to `hermes skills install <name>` for hub skills.
#
# Usage:
#   tutor-bootstrap                  # check + auto-repair
#   tutor-bootstrap --check          # check only, no writes
#   tutor-bootstrap --json           # machine-readable output
#
# Exit codes:
#   0 = READY (or all repaired)
#   1 = some skills still broken after repair attempts
set -uo pipefail

# USER_HOME resolution (no $HOME trust). SELF_PATH must be the resolved
# real path: if BASH_SOURCE is itself a symlink (e.g. ~/.local/bin/tutor-bootstrap
# -> ~/.hermes/profiles/hermes-tutor/scripts/tutor-bootstrap.sh), follow it so we
# walk the real on-disk location and find the .hermes directory at the
# canonical path.
SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then
  SELF_PATH="$(readlink -f "$SELF_PATH")"
fi
HERMES_DIR=""
dir="$(dirname "$SELF_PATH")"
while [ "$dir" != "/" ]; do
  if [ "$(basename "$dir")" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  dir="$(dirname "$dir")"
done
if [ -n "$HERMES_DIR" ]; then USER_HOME="$(dirname "$HERMES_DIR")"
else USER_HOME="/home/felipe"; fi
[ -d "$USER_HOME" ] || USER_HOME="/home/felipe"

PROFILE="${HERMES_TUTOR_PROFILE:-hermes-tutor}"
PROFILE_DIR="$USER_HOME/.hermes/profiles/$PROFILE"
SKILLS_DIR="$PROFILE_DIR/skills"
MANIFEST="$USER_HOME/programming/agent-dev-kit/profiles/hermes-tutor.yml"
[ ! -f "$MANIFEST" ] && MANIFEST="$PROFILE_DIR/config.yaml"  # fallback if user hasn't cloned the repo

# Curated critical skills beyond what the manifest declares — these are
# pulled in by other skills or by the user directly during a session.
CRITICAL_SKILLS=(
  ai-workflow-orchestrator
  worklog
  delegating-to-tmux-claude
  kanban-orchestrator
  kanban-worker
  plan
  writing-plans
  subagent-driven-development
  requesting-code-review
  developer-audit
  dogfood
  test-driven-development
)

# All GSD skills (these often get out of sync because there are 67 of them)
GSD_SKILLS=()
for d in "$SKILLS_DIR/gsd"/*/; do
  [ -d "$d" ] || continue
  GSD_SKILLS+=("$(basename "$d")")
done

MODE="repair"
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --json)  JSON=1; shift ;;
    *) shift ;;
  esac
done

declare -a checks_ok=()
declare -a checks_fixed=()
declare -a checks_broken=()

# Read manifest include_skills
declare -a declared=()
if [ -f "$MANIFEST" ]; then
  while IFS= read -r s; do
    s="$(echo "$s" | sed 's/^[[:space:]]*-[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$s" ] && [[ ! "$s" =~ ^# ]] && declared+=("$s")
  done < <(awk '/^include_skills:/,/^[a-z]/{ if (!/^include_skills:/) { if (/^[a-zA-Z_-]+:/) exit; print } }' "$MANIFEST")
fi

# All skill names to check: declared + critical + gsd
declare -a all_skills=()
for s in "${declared[@]}" "${CRITICAL_SKILLS[@]}" "${GSD_SKILLS[@]}"; do
  # de-dupe
  case " ${all_skills[*]} " in *" $s "*) ;; *) all_skills+=("$s") ;; esac
done

# Source candidates to try when repairing. We exclude the destination
# (the profile's own skills dir) to avoid self-referential symlinks.
source_candidates() {
  local name="$1"
  local cand=()
  # 1. Global ~/.hermes/skills/<name> and nested under known categories
  cand+=("$USER_HOME/.hermes/skills/$name")
  for parent in software-development devops gsd autonomous-ai-agents creative \
                data-science github mcp note-taking productivity research \
                social-media; do
    cand+=("$USER_HOME/.hermes/skills/$parent/$name")
  done
  # 2. OTHER profiles only (not $PROFILE)
  for p in local kommit hermes-agent; do
    [ "$p" = "$PROFILE" ] && continue
    cand+=("$USER_HOME/.hermes/profiles/$p/skills/$name")
    for parent in software-development devops gsd autonomous-ai-agents creative \
                  data-science github mcp note-taking productivity research \
                  social-media; do
      cand+=("$USER_HOME/.hermes/profiles/$p/skills/$parent/$name")
    done
  done
  printf '%s\n' "${cand[@]}"
}

check_skill() {
  local name="$1"
  # Find all occurrences (depth 1 and depth 2) under SKILLS_DIR
  local candidates=()
  [ -e "$SKILLS_DIR/$name" ] && candidates+=("$SKILLS_DIR/$name")
  for d in "$SKILLS_DIR"/*/; do
    [ -e "$d/$name" ] && candidates+=("$d/$name")
  done
  if [ ${#candidates[@]} -eq 0 ]; then
    checks_broken+=("$name: directory missing")
    return 1
  fi
  if [ ${#candidates[@]} -gt 1 ]; then
    checks_broken+=("$name: ${#candidates[@]} duplicates (${candidates[*]})")
    return 1
  fi
  local path="${candidates[0]}"

  # Broken symlink?
  if [ -L "$path" ] && [ ! -e "$path" ]; then
    checks_broken+=("$name: broken symlink at $path")
    return 1
  fi

  # SKILL.md exists?
  local skill_md="$path/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    checks_broken+=("$name: SKILL.md missing at $path")
    return 1
  fi

  # Parse frontmatter
  local fm_name fm_desc
  fm_name="$(awk '/^---/{c++;next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$skill_md")"
  fm_desc="$(awk '/^---/{c++;next} c==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$skill_md")"
  if [ -z "$fm_name" ]; then
    checks_broken+=("$name: frontmatter 'name:' missing or empty")
    return 1
  fi
  if [ -z "$fm_desc" ]; then
    checks_broken+=("$name: frontmatter 'description:' missing or empty")
    return 1
  fi
  if [ "$fm_name" != "$name" ]; then
    checks_broken+=("$name: name in frontmatter is '$fm_name', expected '$name'")
    return 1
  fi

  checks_ok+=("$name")
  return 0
}

# Validate a candidate as a healthy source: must be a directory with a
# SKILL.md that has `name:` and `description:` frontmatter fields, and the
# `name:` must match the directory name.
is_healthy_source() {
  local cand="$1" name="$2"
  [ -d "$cand" ] || return 1
  [ -f "$cand/SKILL.md" ] || return 1
  local fm_name
  fm_name="$(awk '/^---/{c++;next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$cand/SKILL.md")"
  [ "$fm_name" = "$name" ] || return 1
  return 0
}

repair_skill() {
  local name="$1"
  # Determine target dir
  local target="$SKILLS_DIR/$name"
  local parent=""
  if [ ! -d "$target" ]; then
    # try depth-2 (parent categories)
    for p in software-development devops gsd autonomous-ai-agents creative \
             data-science github mcp note-taking productivity research \
             social-media software-development devops devops; do
      if [ -d "$SKILLS_DIR/$p/$name" ]; then
        target="$SKILLS_DIR/$p/$name"
        parent="$p"
        break
      fi
    done
    # If still not found and we have prior knowledge of where the source lived,
    # place it there
    if [ ! -d "$target" ]; then
      for p in gsd software-development devops autonomous-ai-agents; do
        if [ -d "$USER_HOME/.hermes/skills/$p/$name" ]; then
          parent="$p"; mkdir -p "$SKILLS_DIR/$parent"
          target="$SKILLS_DIR/$parent/$name"
          break
        fi
      done
    fi
  fi

  # Find the best source: latest mtime, must be healthy (name matches),
  # must not be the same inode as the target.
  local best=""
  local best_mtime=0
  local target_inode=""
  [ -d "$target" ] && target_inode="$(stat -c %i "$target" 2>/dev/null || echo "")"
  while IFS= read -r cand; do
    [ -d "$cand" ] || continue
    is_healthy_source "$cand" "$name" || continue
    local cand_inode; cand_inode="$(stat -c %i "$cand" 2>/dev/null || echo "")"
    [ -n "$target_inode" ] && [ "$cand_inode" = "$target_inode" ] && continue
    local mtime; mtime="$(stat -c %Y "$cand/SKILL.md" 2>/dev/null || echo 0)"
    if [ "$mtime" -gt "$best_mtime" ]; then
      best_mtime="$mtime"; best="$cand"
    fi
  done < <(source_candidates "$name")

  if [ -z "$best" ]; then
    return 1
  fi

  rm -rf "$target"
  ln -s "$best" "$target"
  checks_fixed+=("$name: -> $best")
  return 0
}

if [ "$MODE" = "repair" ]; then
  for s in "${all_skills[@]}"; do
    if ! check_skill "$s"; then
      repair_skill "$s" || true
      # Re-check after repair: clear prior ok/broken entries for this name
      # so the final counts reflect post-repair reality.
      declare -a new_ok=()
      for entry in "${checks_ok[@]}"; do [ "$entry" != "$s" ] && new_ok+=("$entry"); done
      checks_ok=("${new_ok[@]}")
      declare -a filtered_broken=()
      for entry in "${checks_broken[@]}"; do
        case "$entry" in
          "$s"*) ;;
          *) filtered_broken+=("$entry") ;;
        esac
      done
      checks_broken=("${filtered_broken[@]}")
      check_skill "$s" >/dev/null 2>&1 || true
    fi
  done
else
  for s in "${all_skills[@]}"; do
    check_skill "$s" || true
  done
fi

# Emit
ok_count=${#checks_ok[@]}
fixed_count=${#checks_fixed[@]}
broken_count=${#checks_broken[@]}

if [ "$JSON" -eq 1 ]; then
  printf '{"ok":%d,"fixed":%d,"broken":%d,"fixed_list":[' "$ok_count" "$fixed_count" "$broken_count"
  first=1
  for f in "${checks_fixed[@]}"; do
    [ $first -eq 0 ] && printf ','
    printf '"%s"' "${f//\"/\\\"}"
    first=0
  done
  printf '],"broken_list":['
  first=1
  for b in "${checks_broken[@]}"; do
    [ $first -eq 0 ] && printf ','
    printf '"%s"' "${b//\"/\\\"}"
    first=0
  done
  printf ']}\n'
else
  printf 'OK:    %d\n' "$ok_count"
  printf 'FIXED: %d\n' "$fixed_count"
  printf 'BROKEN:%d\n' "$broken_count"
  if [ "$fixed_count" -gt 0 ]; then
    printf '\nfixed:\n'
    for f in "${checks_fixed[@]}"; do printf '  - %s\n' "$f"; done
  fi
  if [ "$broken_count" -gt 0 ]; then
    printf '\nstill broken:\n'
    for b in "${checks_broken[@]}"; do printf '  - %s\n' "$b"; done
  fi
fi

[ "$broken_count" -eq 0 ]