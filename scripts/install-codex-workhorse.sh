#!/usr/bin/env bash
# Install the external talk/build layers used by the workhorse into Codex's
# global user skill directory. Sources are pinned for reproducible bootstrap.
set -euo pipefail

CAVEMAN_SOURCE="${AGENT_DEV_KIT_CAVEMAN_SOURCE:-JuliusBrussee/caveman#v1.9.1}"
PONYTAIL_SOURCE="${AGENT_DEV_KIT_PONYTAIL_SOURCE:-DietrichGebert/ponytail#v4.8.4}"

if [ -n "${AGENT_DEV_KIT_SKILLS_CLI:-}" ]; then
  SKILLS_COMMAND=("$AGENT_DEV_KIT_SKILLS_CLI")
else
  command -v npx >/dev/null || { echo "error: npx required (install Node.js first)"; exit 1; }
  SKILLS_COMMAND=(npx -y skills@1.5.20)
fi

install_skill() {
  local source="$1" name="$2"
  "${SKILLS_COMMAND[@]}" add "$source" \
    --global --agent codex --skill "$name" --yes
}

install_skill "$CAVEMAN_SOURCE" caveman
install_skill "$PONYTAIL_SOURCE" ponytail

echo "Codex workhorse ready: caveman + ponytail"
