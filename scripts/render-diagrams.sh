#!/usr/bin/env bash
# Render every checked-in diagram source (D2 + Mermaid) to SVG.
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

for src in "$ROOT"/docs/diagrams/*.d2; do
  HOME="$REAL_HOME" d2 "$src" "${src%.d2}.svg"
done

for src in "$ROOT"/docs/diagrams/*.mmd; do
  HOME="$REAL_HOME" mmdc -i "$src" -o "${src%.mmd}.svg" -b transparent
done

# GitHub social preview: hand-authored SVG -> 1280x640 PNG (upload in repo Settings)
node -e '
const sharp = require("sharp"), fs = require("fs");
const src = process.argv[1];
sharp(fs.readFileSync(src)).resize(1280, 640).png().toFile(src.replace(/\.svg$/, ".png"));
' "$ROOT/docs/diagrams/social-preview.svg"

printf 'Rendered:\n'
printf '  %s\n' "$ROOT"/docs/diagrams/*.svg "$ROOT"/docs/diagrams/social-preview.png
