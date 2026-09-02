#!/usr/bin/env bash
# Sync dev-skills from this registry to all runtimes that share the SKILL.md format.
# Idempotent — safe to re-run after git pull.
#
# Covered harnesses & profiles:
#   - Codex (~/.agents/skills)
#   - Claude Code (~/.claude/skills, ~/.claude-very/skills)
#   - Pi (~/.pi/agent/skills, ~/.pi/skills)
#   - Hermes (~/.hermes/skills, ~/.hermes/profiles/*/skills)
#   - Antigravity / AGY (~/.gemini/skills, ~/.gemini/antigravity/skills, ~/.gemini/antigravity-cli/skills, ~/.gemini/antigravity-ide/skills)
# OpenCode commands use a different format and are not linked here.
set -euo pipefail

FORCE=0
for arg in "$@"; do
  case "$arg" in
    -f|--force)
      FORCE=1
      ;;
  esac
done

KIT="$(cd "$(dirname "$0")/plugins/dev-skills/skills" && pwd)"

# Collect all dirs that consume SKILL.md
RUNTIMES=()

# 1. Codex
[[ -d "$HOME/.agents" || -d "$HOME/.agents/skills" ]] && RUNTIMES+=("$HOME/.agents/skills")

# 2. Claude Code & profiles
for candidate in \
  "$HOME/.claude/skills" \
  "$HOME/.claude-very/skills"
do
  [[ -d "$(dirname "$candidate")" ]] && RUNTIMES+=("$candidate")
done

# 3. Pi (agent and global)
for candidate in \
  "$HOME/.pi/agent/skills" \
  "$HOME/.pi/skills"
do
  [[ -d "$(dirname "$candidate")" ]] && RUNTIMES+=("$candidate")
done

# 4. Hermes (global and profiles)
[[ -d "$HOME/.hermes" ]] && RUNTIMES+=("$HOME/.hermes/skills")
if [[ -d "$HOME/.hermes/profiles" ]]; then
  for pdir in "$HOME/.hermes/profiles"/*; do
    [[ -d "$pdir" ]] && RUNTIMES+=("$pdir/skills")
  done
fi

# 5. Antigravity / Gemini
for candidate in \
  "$HOME/.gemini/skills" \
  "$HOME/.gemini/antigravity/skills" \
  "$HOME/.gemini/antigravity-cli/skills" \
  "$HOME/.gemini/antigravity-ide/skills"
do
  [[ -d "$(dirname "$candidate")" ]] && RUNTIMES+=("$candidate")
done

# Deduplicate RUNTIMES
declare -a DEDUPED_RUNTIMES=()
for r in "${RUNTIMES[@]}"; do
  r_clean="${r%/}"
  already=0
  for d in "${DEDUPED_RUNTIMES[@]}"; do
    if [[ "$d" == "$r_clean" ]]; then
      already=1
      break
    fi
  done
  if [[ $already -eq 0 ]]; then
    DEDUPED_RUNTIMES+=("$r_clean")
  fi
done
RUNTIMES=("${DEDUPED_RUNTIMES[@]}")

SKILLS=("$KIT"/*/)

is_managed_skill_destination() {
  local destination="${1%/}"
  local name

  [[ "$destination" == "$KIT/"* || "$destination" == "agent-native-scaffold" || "$destination" == "$KIT/agent-native-scaffold" ]] || return 1
  name="${destination#"$KIT/"}"
  [[ -n "$name" && "$name" != */* && "$name" != "." && "$name" != ".." ]]
}

# Preflight conflict check
for target in "${RUNTIMES[@]}"; do
  for skill in "${SKILLS[@]}"; do
    name=$(basename "$skill")
    path="$target/$name"
    [[ -e "$path" || -L "$path" ]] || continue

    if [[ ! -L "$path" ]]; then
      if [[ $FORCE -eq 1 ]]; then
        continue
      fi
      echo "error: skill conflict at $path (existing entry is not a symlink managed by $KIT; pass --force to overwrite)" >&2
      exit 1
    fi

    existing=$(readlink "$path")
    if ! is_managed_skill_destination "$existing"; then
      if [[ $FORCE -eq 1 ]]; then
        continue
      fi
      echo "error: skill conflict at $path (symlink is not managed by $KIT: $existing; pass --force to overwrite)" >&2
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
    path="$target/$name"

    if [[ -e "$path" || -L "$path" ]]; then
      if [[ ! -L "$path" && $FORCE -eq 1 ]]; then
        rm -rf "$path"
      fi
    fi

    existing=$(readlink "$target/$name" 2>/dev/null || true)
    if [[ "$existing" != "$skill" ]]; then
      ln -sfn "$skill" "$target/$name"
      added=$((added + 1))
    fi
  done

  # Link alias: agent-native -> agent-native-scaffold
  if [[ -e "$target/agent-native-scaffold" || -L "$target/agent-native-scaffold" ]]; then
    ln -sfn "$KIT/agent-native-scaffold" "$target/agent-native"
  fi

  # Prune stale symlinks that pointed to this kit but skill no longer exists
  for link in "$target"/*/; do
    [[ -L "${link%/}" ]] || continue
    dest=$(readlink "${link%/}")
    # Only touch links that point into this kit
    is_managed_skill_destination "$dest" || continue
    name=$(basename "$link")
    if [[ "$name" == "agent-native" ]]; then
      continue
    fi
    if [[ ! -d "$KIT/$name" ]]; then
      rm "${link%/}"
      pruned=$((pruned + 1))
    fi
  done

  msg="✓ $target  (${#SKILLS[@]} skills"
  [[ $added   -gt 0 ]] && msg+=", +$added new/updated"
  [[ $pruned  -gt 0 ]] && msg+=", -$pruned pruned"
  echo "$msg)"
done

echo "Done across ${#RUNTIMES[@]} runtimes."
