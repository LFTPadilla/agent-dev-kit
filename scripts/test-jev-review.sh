#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

JEV_ROOT="$FIXTURE/jev-review"
mkdir -p "$JEV_ROOT/dist" "$JEV_ROOT/skills/jev-review"
printf 'console.log("ok")\n' > "$JEV_ROOT/dist/server.js"
cat > "$JEV_ROOT/skills/jev-review/SKILL.md" <<'EOF'
---
name: jev-review
description: test fixture
---
EOF

HOME="$FIXTURE/home"
HERMES_HOME="$HOME/.hermes"
CODEX_HOME="$HOME/.codex"
mkdir -p "$HERMES_HOME/profiles/alpha" "$HERMES_HOME/profiles/beta" \
  "$CODEX_HOME"

cat > "$HERMES_HOME/config.yaml" <<'EOF'
model:
  default: chat-smart
mcp_servers:
  context7:
    url: https://example.invalid
EOF

cat > "$HERMES_HOME/profiles/alpha/config.yaml" <<'EOF'
mcp_servers: {}
EOF

cat > "$HERMES_HOME/profiles/beta/SOUL.md" <<'EOF'
You are a test profile.
EOF

printf 'personality = "pragmatic"\n\n[mcp_servers.other]\ncommand = "true"\n' \
  > "$CODEX_HOME/config.toml"
printf '# Codex user-level instructions\n' > "$CODEX_HOME/AGENTS.md"
printf 'You are Hermes.\n' > "$HERMES_HOME/SOUL.md"

run_install() {
  HOME="$HOME" \
    bash "$ROOT/scripts/install-jev-review.sh" \
      --root "$JEV_ROOT" \
      --hermes-home "$HERMES_HOME" \
      --codex-home "$CODEX_HOME"
}

run_install >/dev/null
run_install >/dev/null

assert_contains() {
  local file="$1" needle="$2"
  grep -Fq "$needle" "$file" || { echo "missing in $file: $needle"; exit 1; }
}

assert_count() {
  local file="$1" needle="$2" expected="$3"
  local actual
  actual="$(grep -F -c "$needle" "$file" || true)"
  [ "$actual" -eq "$expected" ] || {
    echo "count mismatch in $file for $needle: $actual != $expected"
    exit 1
  }
}

assert_contains "$HERMES_HOME/config.yaml" "jev-review:"
assert_contains "$HERMES_HOME/config.yaml" "context7:"
assert_contains "$HERMES_HOME/profiles/alpha/config.yaml" "jev-review:"
assert_contains "$HERMES_HOME/profiles/beta/config.yaml" "jev-review:"
assert_contains "$CODEX_HOME/config.toml" "[mcp_servers.jev-review]"
assert_contains "$CODEX_HOME/config.toml" "[mcp_servers.other]"
assert_contains "$HERMES_HOME/SOUL.md" 'call `jev_review` for a baseline'
assert_contains "$CODEX_HOME/AGENTS.md" 'call `jev_review` for a baseline'
assert_count "$HERMES_HOME/SOUL.md" 'call `jev_review` for a baseline' 1
assert_count "$CODEX_HOME/config.toml" "[mcp_servers.jev-review]" 1

[ -L "$HERMES_HOME/skills/jev-review" ] || { echo "missing hermes skill link"; exit 1; }
[ "$(readlink -f "$HERMES_HOME/skills/jev-review")" = "$(readlink -f "$JEV_ROOT/skills/jev-review")" ] || {
  echo "hermes skill link points at the wrong tree"
  exit 1
}
[ -L "$HERMES_HOME/profiles/alpha/skills/external/jev-review" ] || {
  echo "missing alpha skill link"
  exit 1
}
[ -L "$HOME/.agents/skills/jev-review" ] || { echo "missing Codex skill link"; exit 1; }

grep -q 'install-jev-review.sh' "$ROOT/bootstrap.sh" || {
  echo "bootstrap.sh does not mention install-jev-review.sh"
  exit 1
}
grep -q 'jev-review' "$ROOT/docs/external-deps.md" || {
  echo "external-deps.md does not mention jev-review"
  exit 1
}
[ -f "$ROOT/docs/jev/README.md" ] && [ -f "$ROOT/docs/jev/AGENTS.md" ] || {
  echo "missing docs/jev section"
  exit 1
}
grep -q 'jev_review' "$ROOT/docs/jev/README.md" || {
  echo "docs/jev/README.md does not describe jev_review"
  exit 1
}

echo "install-jev-review contract ok"
