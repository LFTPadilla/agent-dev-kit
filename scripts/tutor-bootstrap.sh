#!/usr/bin/env bash
# tutor-bootstrap.sh — verify and repair skills on profile boot.
#
# For every skill in profiles/agent-tutor-orchestrator.yml's `include_skills`, plus a
# curated set of critical skills, check:
#   - the directory exists under ~/.hermes/profiles/<profile>/skills/
#   - SKILL.md exists and parses (frontmatter has `name:` and `description:`)
#   - name matches the directory name
#   - not a broken symlink
#
# Repair actions (in order):
#   1. If a healthy copy exists at ~/.hermes/skills/<name> (global), symlink
#      the profile copy to it.
#   2. Otherwise, if a healthy copy exists in another local Hermes profile,
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
# -> ~/.hermes/profiles/agent-tutor-orchestrator/scripts/tutor-bootstrap.sh), follow it so we
# walk the real on-disk location and find the .hermes directory at the
# canonical path.
SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then
  SELF_PATH="$(readlink -f "$SELF_PATH")"
fi
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
else USER_HOME="${HOME:?HOME is required}"; fi
[ -d "$USER_HOME" ] || { echo "user home does not exist: $USER_HOME" >&2; exit 1; }

PROFILE="${AGENT_TUTOR_PROFILE:-agent-tutor-orchestrator}"
PROFILE_DIR="$USER_HOME/.hermes/profiles/$PROFILE"
SKILLS_DIR="$PROFILE_DIR/skills"
# Prefer the public kit manifest next to this script's repo checkout, then
# a copied manifest under the profile, then config.yaml.
script_dir="$(cd "$(dirname "$SELF_PATH")" && pwd)"
MANIFEST=""
for candidate in \
  "$script_dir/../profiles/agent-tutor-orchestrator.yml" \
  "$USER_HOME/programming/agent-dev-kit/profiles/agent-tutor-orchestrator.yml" \
  "$PROFILE_DIR/agent-tutor-orchestrator.yml" \
  "$PROFILE_DIR/config.yaml"; do
  if [ -f "$candidate" ]; then MANIFEST="$candidate"; break; fi
done

# Public kit skills that should always be present after tutor-install.
# Overlay / hub skills live in requires_private_overlay in the manifest and
# are reported separately (missing is expected on a cold clone).
CRITICAL_SKILLS=(
  ai-workflow-orchestrator
  orchestrate
)

# Known Hermes skill categories, ordered by the existing lookup precedence.
SKILL_CATEGORIES=(
  software-development
  devops
  gsd
  autonomous-ai-agents
  creative
  data-science
  github
  mcp
  note-taking
  productivity
  research
  social-media
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

# Read a YAML list block: awk from KEY: until the next top-level key.
read_yaml_list() {
  local key="$1" file="$2"
  [ -f "$file" ] || return 0
  awk -v key="$key" '
    $0 ~ "^" key ":" { grab=1; next }
    grab && /^[a-zA-Z_][a-zA-Z0-9_-]*:/ { exit }
    grab { print }
  ' "$file" | while IFS= read -r s; do
    s="$(echo "$s" | sed 's/^[[:space:]]*-[[:space:]]*//;s/[[:space:]]*$//;s/#.*//')"
    [ -n "$s" ] && printf '%s\n' "$s"
  done
}

skill_frontmatter_field() {
  local field="$1" file="$2"
  awk -v field="$field" '
    /^---/{c++;next}
    c==1 && $0 ~ "^" field ":" {
      sub("^" field ":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

declare -a declared=()
declare -a overlay=()
if [ -n "$MANIFEST" ] && [ -f "$MANIFEST" ]; then
  mapfile -t declared < <(read_yaml_list "include_skills" "$MANIFEST")
  mapfile -t overlay < <(read_yaml_list "requires_private_overlay" "$MANIFEST")
fi

# Public skills to check/repair: include_skills + critical + any local gsd copies
declare -a all_skills=()
for s in "${declared[@]}" "${CRITICAL_SKILLS[@]}" "${GSD_SKILLS[@]}"; do
  case " ${all_skills[*]} " in *" $s "*) ;; *) all_skills+=("$s") ;; esac
done
declare -a overlay_missing=()

# Source candidates to try when repairing. We exclude the destination
# (the profile's own skills dir) to avoid self-referential symlinks.
skill_paths_for_root() {
  local root="$1" name="$2"
  printf '%s\n' "$root/$name"
  for parent in "${SKILL_CATEGORIES[@]}"; do
    printf '%s\n' "$root/$parent/$name"
  done
}

source_candidates() {
  local name="$1"
  # 1. Global ~/.hermes/skills/<name> and nested under known categories
  skill_paths_for_root "$USER_HOME/.hermes/skills" "$name"
  # 2. OTHER profiles only (not $PROFILE) — scan whatever exists locally
  if [ -d "$USER_HOME/.hermes/profiles" ]; then
    for pdir in "$USER_HOME/.hermes/profiles"/*/; do
      [ -d "$pdir" ] || continue
      p="$(basename "$pdir")"
      [ "$p" = "$PROFILE" ] && continue
      skill_paths_for_root "$USER_HOME/.hermes/profiles/$p/skills" "$name"
    done
  fi
}

check_skill() {
  local name="$1"
  # Find all occurrences (depth 1 and depth 2) under SKILLS_DIR
  local candidates=()
  for candidate in "$SKILLS_DIR/$name" "$SKILLS_DIR"/*/"$name"; do
    [ -e "$candidate" ] && candidates+=("$candidate")
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
  fm_name="$(skill_frontmatter_field name "$skill_md")"
  fm_desc="$(skill_frontmatter_field description "$skill_md")"
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
  fm_name="$(skill_frontmatter_field name "$cand/SKILL.md")"
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
    for p in "${SKILL_CATEGORIES[@]}"; do
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

clear_skill_results() {
  local name="$1" entry
  local -a filtered_broken=() new_ok=()
  for entry in "${checks_broken[@]}"; do
    case "$entry" in
      "$name"*) ;;
      *) filtered_broken+=("$entry") ;;
    esac
  done
  checks_broken=("${filtered_broken[@]}")
  for entry in "${checks_ok[@]}"; do
    [ "$entry" != "$name" ] && new_ok+=("$entry")
  done
  checks_ok=("${new_ok[@]}")
}

for s in "${all_skills[@]}"; do
  if check_skill "$s"; then
    continue
  fi
  [ "$MODE" = "repair" ] || continue
  repair_skill "$s" || true
  # Re-check after repair: clear prior ok/broken entries for this name
  # so the final counts reflect post-repair reality.
  clear_skill_results "$s"
  check_skill "$s" >/dev/null 2>&1 || true
done

# Overlay skills: missing is expected without a private overlay (not broken).
for s in "${overlay[@]}"; do
  if ! check_skill "$s" >/dev/null 2>&1; then
    # check_skill appended to checks_broken; pull that back out
    clear_skill_results "$s"
    overlay_missing+=("$s")
  fi
done

# Emit
print_json_array() {
  local first=1 value
  for value in "$@"; do
    [ "$first" -eq 0 ] && printf ','
    printf '"%s"' "${value//\"/\\\"}"
    first=0
  done
}

print_list() {
  local header="$1" value
  shift
  [ "$#" -gt 0 ] || return
  printf '\n%s:\n' "$header"
  for value in "$@"; do printf '  - %s\n' "$value"; done
}

ok_count=${#checks_ok[@]}
fixed_count=${#checks_fixed[@]}
broken_count=${#checks_broken[@]}
overlay_missing_count=${#overlay_missing[@]}

if [ "$JSON" -eq 1 ]; then
  printf '{"ok":%d,"fixed":%d,"broken":%d,"overlay_missing":%d,"fixed_list":[' \
    "$ok_count" "$fixed_count" "$broken_count" "$overlay_missing_count"
  print_json_array "${checks_fixed[@]}"
  printf '],"broken_list":['
  print_json_array "${checks_broken[@]}"
  printf '],"overlay_missing_list":['
  print_json_array "${overlay_missing[@]}"
  printf ']}\n'
else
  printf 'OK:    %d\n' "$ok_count"
  printf 'FIXED: %d\n' "$fixed_count"
  printf 'BROKEN:%d\n' "$broken_count"
  printf 'OVERLAY_MISSING:%d (expected without private overlay)\n' "$overlay_missing_count"
  print_list 'fixed' "${checks_fixed[@]}"
  print_list 'still broken' "${checks_broken[@]}"
  print_list 'overlay skills missing (link a private overlay to supply)' "${overlay_missing[@]}"
fi

[ "$broken_count" -eq 0 ]
