#!/usr/bin/env bash
# Render the Personal Dev Tutor Mermaid and D2 architecture diagrams.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"

command -v d2 >/dev/null || { echo "missing d2"; exit 1; }
command -v mmdc >/dev/null || { echo "missing Mermaid CLI (mmdc)"; exit 1; }

if [ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]; then
  for browser in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$browser" >/dev/null 2>&1; then
      export PUPPETEER_EXECUTABLE_PATH="$(command -v "$browser")"
      break
    fi
  done
fi
[ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ] || {
  echo "no Chrome/Chromium executable found for Mermaid CLI"
  exit 1
}

HOME="$REAL_HOME" d2 \
  "$ROOT/docs/diagrams/personal-dev-tutor-architecture.d2" \
  "$ROOT/docs/diagrams/personal-dev-tutor-architecture.svg"
HOME="$REAL_HOME" mmdc \
  -i "$ROOT/docs/diagrams/personal-dev-tutor-flow.mmd" \
  -o "$ROOT/docs/diagrams/personal-dev-tutor-flow.svg" \
  -b transparent

printf 'Rendered:\n  %s\n  %s\n' \
  "$ROOT/docs/diagrams/personal-dev-tutor-architecture.svg" \
  "$ROOT/docs/diagrams/personal-dev-tutor-flow.svg"
