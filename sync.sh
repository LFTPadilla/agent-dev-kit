#!/usr/bin/env bash
# Sync dev-skills from this registry to all runtimes that share the SKILL.md format.
# Idempotent — safe to re-run after git pull.
#
# Covered: Claude Code (~/.claude/skills, ~/.claude-very/skills),
# Codex (~/.agents/skills), and PI (~/.pi/agent/skills).
# OpenCode commands use a different format and are not linked here.
set -euo pipefail

KIT="$(cd "$(dirname "$0")/plugins/dev-skills/skills" && pwd)"

# All dirs that consume SKILL.md — add more profiles here as needed
RUNTIMES=("$HOME/.agents/skills")
for candidate in \
  "$HOME/.claude/skills" \
  "$HOME/.claude-very/skills" \
  "$HOME/.pi/agent/skills"
do
  [[ -d "$(dirname "$candidate")" ]] && RUNTIMES+=("$candidate")
done

SKILLS=("$KIT"/*/)
SKILL_NAMES=()
for s in "${SKILLS[@]}"; do SKILL_NAMES+=("$(basename "$s")"); done

is_managed_skill_destination() {
  local destination="${1%/}"
  local name

  [[ "$destination" == "$KIT/"* ]] || return 1
  name="${destination#"$KIT/"}"
  [[ -n "$name" && "$name" != */* && "$name" != "." && "$name" != ".." ]]
}

for target in "${RUNTIMES[@]}"; do
  for skill in "${SKILLS[@]}"; do
    name=$(basename "$skill")
    path="$target/$name"
    [[ -e "$path" || -L "$path" ]] || continue

    if [[ ! -L "$path" ]]; then
      echo "error: skill conflict at $path (existing entry is not managed by $KIT)" >&2
      exit 1
    fi

    existing=$(readlink "$path")
    if ! is_managed_skill_destination "$existing"; then
      echo "error: skill conflict at $path (symlink is not managed by $KIT)" >&2
      exit 1
    fi
  done
done

for target in "${RUNTIMES[@]}"; do
  mkdir -p "$target"
  added=0 pruned=0

  # Link current skills
  for skill in "${SKILLS[@]}"; do
    name=$(basename "$skill")
    existing=$(readlink "$target/$name" 2>/dev/null || true)
    if [[ "$existing" != "$skill" ]]; then
      ln -sfn "$skill" "$target/$name"
      added=$((added + 1))
    fi
  done

  # Prune stale symlinks that pointed to this kit but skill no longer exists
  for link in "$target"/*/; do
    [[ -L "${link%/}" ]] || continue
    dest=$(readlink "${link%/}")
    # Only touch links that point into this kit
    is_managed_skill_destination "$dest" || continue
    name=$(basename "$link")
    if [[ ! -d "$KIT/$name" ]]; then
      rm "${link%/}"
      pruned=$((pruned + 1))
    fi
  done

  msg="✓ $target  (${#SKILL_NAMES[@]} skills"
  [[ $added   -gt 0 ]] && msg+=", +$added new/updated"
  [[ $pruned  -gt 0 ]] && msg+=", -$pruned pruned"
  echo "$msg)"
done

echo "Done across ${#RUNTIMES[@]} runtimes."
