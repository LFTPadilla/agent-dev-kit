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

"${SKILLS_COMMAND[@]}" add "$CAVEMAN_SOURCE" \
  --global --agent codex --skill caveman --yes
"${SKILLS_COMMAND[@]}" add "$PONYTAIL_SOURCE" \
  --global --agent codex --skill ponytail --yes

echo "Codex workhorse ready: caveman + ponytail"
