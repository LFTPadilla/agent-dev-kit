#!/usr/bin/env bash
# Bootstrap the agent dev kit on a fresh machine. Idempotent — safe to re-run.
#
# Two layers:
#   1. External tools (this script installs the npm ones).
#   2. Claude Code marketplaces + plugins (printed — run them inside Claude Code).
#
# ponytail: no installer framework. A shell script + printed instructions covers it.
set -euo pipefail

command -v npm >/dev/null || { echo "error: npm required (install Node.js first)"; exit 1; }

echo "==> npm tools"
npm i -g pi-gsd          # GSD — spec-driven workflow system (/gsd:*)
# npm i -g jean-claude   # optional: multi-profile Claude config sync. Uncomment if you use multiple accounts.

# Optional quality tools (per-project usually; uncomment to install globally):
# command -v pipx >/dev/null && pipx install semgrep   # SAST (semgrep skill)
# knip + lefthook are run via npx per-project — no global install needed.

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
echo "Done. See docs/external-deps.md for what each tool does and why."
