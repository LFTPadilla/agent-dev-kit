#!/usr/bin/env bash
# Bootstrap the agent dev kit on a fresh machine. Idempotent — safe to re-run.
#
# Two layers:
#   1. External tools (this script installs the npm core).
#   2. Global Codex skills plus Claude Code marketplaces/plugins.
#
# Optional day-to-day toolchain (gnhf, gh-axi, no-mistakes, treehouse, skills CLI)
# is EXTERNAL — this script prints a copy-paste block; it does not prompt y/N.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v npm >/dev/null || { echo "error: npm required (install Node.js first)"; exit 1; }

echo "==> Repository dependencies"
npm ci --prefix "$ROOT"

echo "==> npm tools"
npm i -g pi-gsd                  # GSD — spec-driven workflow system (/gsd:*)
npm i -g @hypabolic/hypa         # Hypa — command rewriting + MCP proxy for Claude/Codex
# npm i -g jean-claude   # optional: multi-profile Claude config sync

echo
echo "==> Optional toolchain (copy-paste when ready — not installed automatically)"
cat <<'EOF'
  npm i -g gnhf          # preferred overnight runner (pairs with overnight-task-kit)
  npm i -g gh-axi        # GitHub AXI (agent-shaped CLI output)
  # optional: npm i -g chrome-devtools-axi

  no-mistakes + treehouse: curl installers from upstream docs
    https://github.com/kunchenguid/no-mistakes
    https://github.com/kunchenguid/treehouse

  Skill packs:
    npx skills
    # install reference lifecycle pack from addyosmani/agent-skills via the CLI
    # do not copy that pack into this repo tree

  TOON (agent-facing structured output): https://toonformat.dev
  Graphify (Personal Dev Tutor installs this automatically when uv is available):
    uv tool install graphifyy==0.9.25
    graphify install --platform hermes
    graphify install --platform codex

  Context7 for Codex (OAuth is interactive and credentials remain user-owned):
    codex mcp add context7 --url https://mcp.context7.com/mcp
    codex mcp login context7

  Flow map: docs/how-it-fits-together.md
  Dep table:  docs/external-deps.md
EOF

echo
echo "==> Run these inside Claude Code (interactive — cannot be scripted from bash):"
cat <<'EOF'
  /plugin marketplace add JuliusBrussee/caveman
  /plugin marketplace add DietrichGebert/ponytail
  /plugin marketplace add LFTPadilla/agent-dev-kit
  /plugin install caveman@caveman
  /plugin install ponytail@ponytail
  /plugin install dev-skills@agent-dev-kit

  Then initialize GSD in a project:  /gsd:help

  Optional — connect Sentry to triage prod errors (see docs/sentry-mcp.md):
    claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
EOF

echo
echo "==> Installing Hypa hooks into Claude Code and Codex"
hypa init --agent claude
hypa init --agent codex

echo
echo "==> Linking dev-skills to Claude Code + Codex + PI"
bash "$ROOT/sync.sh"

if command -v hermes >/dev/null 2>&1; then
  echo
  echo "==> Installing caveman + ponytail for all Hermes profiles"
  bash "$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles
fi

echo
echo "==> Installing pinned caveman + ponytail skills for Codex"
bash "$(dirname "$0")/scripts/install-codex-workhorse.sh"

echo
echo "==> Running public kit validation"
node "$ROOT/scripts/agent-dev-kit.mjs" validate

echo
echo "Done. See docs/how-it-fits-together.md and docs/external-deps.md."
echo "Re-run sync.sh after 'git pull' to pick up new skills."
echo "Optional: compose with a private org skills overlay outside this repo."
echo "Personal Dev Tutor (recommended): install uv, then run 'npm i -g get-shit-done-cc && get-shit-done-cc --hermes --global', then ./scripts/personal-tutor-install.sh"
echo "Agent Tutor Orchestrator: ./scripts/tutor-install.sh then ./scripts/tutor-doctor.sh"
