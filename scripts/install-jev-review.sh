#!/usr/bin/env bash
# Wire the Jev Review MCP + skill into local coding harnesses.
# Does not vendor Jev Review. Does not write JEV_API_KEY into any file.
# Docs: docs/jev/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: install-jev-review.sh [options]

Wires NiazMorshed2007/jev-review into Hermes, Codex, and skill directories.
Requires Node 20+, dist/server.js, and JEV_API_KEY in the agent process env.

Options:
  --root PATH          Jev Review checkout (default: $JEV_REVIEW_ROOT or
                       ~/.claude/plugins/marketplaces/NiazMorshed2007-jev-review)
  --hermes-home PATH   Hermes home (default: $HERMES_HOME or ~/.hermes)
  --codex-home PATH    Codex home (default: $CODEX_HOME or ~/.codex)
  --skip-hermes        Do not patch Hermes configs or skills
  --skip-codex         Do not patch Codex config or skills
  --skip-instructions  Do not append the review-loop paragraph
  -h, --help           Show this help
EOF
}

JEV_ROOT="${JEV_REVIEW_ROOT:-}"
HERMES_HOME="${HERMES_HOME:-${HOME:?HOME is required}/.hermes}"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
SKIP_HERMES=0
SKIP_CODEX=0
SKIP_INSTRUCTIONS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      JEV_ROOT="${2:?--root requires a path}"
      shift 2
      ;;
    --hermes-home)
      HERMES_HOME="${2:?--hermes-home requires a path}"
      shift 2
      ;;
    --codex-home)
      CODEX_HOME="${2:?--codex-home requires a path}"
      shift 2
      ;;
    --skip-hermes) SKIP_HERMES=1; shift ;;
    --skip-codex) SKIP_CODEX=1; shift ;;
    --skip-instructions) SKIP_INSTRUCTIONS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$JEV_ROOT" ]; then
  JEV_ROOT="$HOME/.claude/plugins/marketplaces/NiazMorshed2007-jev-review"
fi

SERVER="$JEV_ROOT/dist/server.js"
SKILL_SRC="$JEV_ROOT/skills/jev-review"
[ -f "$SERVER" ] || { echo "missing Jev Review server: $SERVER" >&2; exit 1; }
[ -f "$SKILL_SRC/SKILL.md" ] || { echo "missing Jev Review skill: $SKILL_SRC/SKILL.md" >&2; exit 1; }
command -v node >/dev/null || { echo "node not on PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 not on PATH" >&2; exit 1; }

INSTRUCTION_MARKER="call \`jev_review\` for a baseline"
INSTRUCTION_BLOCK="$(cat <<'EOF'

## Jev Review

For every nontrivial coding task, after a coherent implementation exists: call `jev_review` for a baseline, inspect weak important metrics yourself, make the smallest justified improvement, validate, and rescore with the prior response in `previousEvaluation`. Do not stop after the first call. Scores are evidence, not goals. Skip trivia, formatting-only diffs, and work that does not change code.
EOF
)"

link_skill() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    if [ "$(readlink -f "$dest")" = "$(readlink -f "$SKILL_SRC")" ]; then
      return 0
    fi
    echo "refusing to replace foreign skill link: $dest" >&2
    exit 1
  fi
  if [ -e "$dest" ]; then
    echo "refusing to overwrite existing skill path: $dest" >&2
    exit 1
  fi
  ln -s "$SKILL_SRC" "$dest"
}

append_instruction() {
  local file="$1"
  [ "$SKIP_INSTRUCTIONS" -eq 0 ] || return 0
  [ -f "$file" ] || return 0
  grep -Fq "$INSTRUCTION_MARKER" "$file" && return 0
  printf '%s\n' "$INSTRUCTION_BLOCK" >> "$file"
}

patch_hermes_yaml() {
  local file="$1"
  python3 - "$file" "$SERVER" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
server = sys.argv[2]
text = path.read_text() if path.exists() else ""
if re.search(r"(?m)^  jev-review:\s*$", text):
    raise SystemExit(0)
block = (
    "  jev-review:\n"
    "    command: node\n"
    "    args:\n"
    f"      - {server}\n"
    "    env:\n"
    "      JEV_API_KEY: ${JEV_API_KEY}\n"
    "    timeout: 180\n"
    "    connect_timeout: 30\n"
)
if re.search(r"(?m)^mcp_servers:\s*\{\}\s*$", text):
    text = re.sub(r"(?m)^mcp_servers:\s*\{\}\s*$", "mcp_servers:\n" + block, text, count=1)
elif re.search(r"(?m)^mcp_servers:\s*$", text):
    text = re.sub(r"(?m)^mcp_servers:\s*$", "mcp_servers:\n" + block.rstrip("\n"), text, count=1)
    if not text.endswith("\n"):
        text += "\n"
else:
    if text and not text.endswith("\n"):
        text += "\n"
    if not text.endswith("\n\n") and text:
        text += "\n"
    text += "mcp_servers:\n" + block
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text)
PY
}

patch_codex_toml() {
  local file="$1"
  python3 - "$file" "$SERVER" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
server = sys.argv[2]
text = path.read_text() if path.exists() else ""
if "[mcp_servers.jev-review]" in text:
    raise SystemExit(0)
block = (
    "\n[mcp_servers.jev-review]\n"
    'command = "node"\n'
    f'args = ["{server}"]\n'
    'env_vars = ["JEV_API_KEY"]\n'
)
if text and not text.endswith("\n"):
    text += "\n"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text + block)
PY
}

if [ "$SKIP_HERMES" -eq 0 ]; then
  if [ -d "$HERMES_HOME" ] || [ ! -e "$HERMES_HOME" ]; then
    mkdir -p "$HERMES_HOME/skills"
    patch_hermes_yaml "$HERMES_HOME/config.yaml"
    append_instruction "$HERMES_HOME/SOUL.md"
    link_skill "$HERMES_HOME/skills/jev-review"
    if [ -d "$HERMES_HOME/profiles" ]; then
      for profile_dir in "$HERMES_HOME"/profiles/*/; do
        [ -d "$profile_dir" ] || continue
        [ ! -L "${profile_dir%/}" ] || continue
        patch_hermes_yaml "$profile_dir/config.yaml"
        append_instruction "$profile_dir/SOUL.md"
        mkdir -p "$profile_dir/skills/external"
        link_skill "$profile_dir/skills/external/jev-review"
      done
    fi
  fi
fi

if [ "$SKIP_CODEX" -eq 0 ]; then
  mkdir -p "$HOME/.agents/skills"
  patch_codex_toml "$CODEX_HOME/config.toml"
  append_instruction "$CODEX_HOME/AGENTS.md"
  link_skill "$HOME/.agents/skills/jev-review"
fi

echo "Jev Review wired from $JEV_ROOT"
echo "JEV_API_KEY must be present in the agent process environment; this script does not store it."
echo "See $ROOT/docs/jev/"
