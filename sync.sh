#!/usr/bin/env bash
# Sync dev-skills from this registry to all runtimes that share the SKILL.md format.
# Idempotent — safe to re-run after git pull.
#
# Covered:   Claude Code (~/.claude/skills, ~/.claude-very/skills)  · PI (~/.pi/agent/skills)
# Not covered: OpenCode + Codex need different file formats (see docs/profiles.md)
set -euo pipefail

KIT="$(cd "$(dirname "$0")/plugins/dev-skills/skills" && pwd)"

# All dirs that consume SKILL.md — add more profiles here as needed
RUNTIMES=()
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
    [[ "$dest" != "$KIT/"* ]] && continue
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
