#!/usr/bin/env bash
# Render every checked-in diagram source (D2 + Mermaid) to SVG.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"

command -v d2 >/dev/null || { echo "missing d2"; exit 1; }

# Empty globs are fine: d2 and Mermaid are both optional for a given checkout.
shopt -s nullglob
SOURCE_FOUND=0

for src in "$ROOT"/docs/diagrams/*.d2; do
  HOME="$REAL_HOME" d2 "$src" "${src%.d2}.svg"
  SOURCE_FOUND=1
done

# Mermaid needs Chrome; only require it when a .mmd source actually exists.
MERMAID_SOURCES=("$ROOT"/docs/diagrams/*.mmd)
if [ "${#MERMAID_SOURCES[@]}" -gt 0 ]; then
  command -v mmdc >/dev/null || { echo "missing Mermaid CLI (mmdc)"; exit 1; }
  if [ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]; then
    for browser in google-chrome google-chrome-stable chromium chromium-browser; do
      if browser_path="$(command -v "$browser" 2>/dev/null)"; then
        export PUPPETEER_EXECUTABLE_PATH="$browser_path"
        break
      fi
    done
  fi
  [ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ] || {
    echo "no Chrome/Chromium executable found for Mermaid CLI"
    exit 1
  }
  for src in "${MERMAID_SOURCES[@]}"; do
    HOME="$REAL_HOME" mmdc -i "$src" -o "${src%.mmd}.svg" -b transparent
    SOURCE_FOUND=1
  done
fi

if [ "$SOURCE_FOUND" -eq 0 ]; then
  echo "no diagram sources (*.d2, *.mmd) found in docs/diagrams"
  exit 1
fi

# GitHub social preview: checked-in PNG, 1280x640 (upload in repo Settings).
# The source is the editorial HTML export; this script only reports it.

printf 'Rendered:\n'
printf '  %s\n' "$ROOT"/docs/diagrams/*.svg
printf '  %s\n' "$ROOT"/docs/diagrams/social-preview.png
