#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

HOME="$HOME" bash "$ROOT/sync.sh" >/dev/null

expected=0
for skill in "$ROOT"/plugins/dev-skills/skills/*/; do
  name="$(basename "$skill")"
  target="$HOME/.agents/skills/$name"
  [ -L "$target" ] || { echo "missing Codex skill link: $name"; exit 1; }
  [ "$(readlink -f "$target")" = "$(readlink -f "${skill%/}")" ] || {
    echo "incorrect Codex skill link: $name"
    exit 1
  }
  expected=$((expected + 1))
done

actual="$(find "$HOME/.agents/skills" -mindepth 1 -maxdepth 1 -type l | wc -l)"
[ "$actual" -eq "$expected" ] || { echo "Codex skill count: $actual/$expected"; exit 1; }
[ ! -e "$HOME/.codex/skills" ] || { echo "legacy Codex skill directory was created"; exit 1; }

SKILLS_LOG="$TEST_ROOT/skills.log"
MOCK_SKILLS="$TEST_ROOT/mock-skills"
cat > "$MOCK_SKILLS" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AGENT_DEV_KIT_SKILLS_LOG"
MOCK
chmod +x "$MOCK_SKILLS"

AGENT_DEV_KIT_SKILLS_CLI="$MOCK_SKILLS" \
AGENT_DEV_KIT_SKILLS_LOG="$SKILLS_LOG" \
  bash "$ROOT/scripts/install-codex-workhorse.sh" >/dev/null

cat > "$TEST_ROOT/expected.log" <<'EXPECTED'
add JuliusBrussee/caveman#v1.9.1 --global --agent codex --skill caveman --yes
add DietrichGebert/ponytail#v4.8.4 --global --agent codex --skill ponytail --yes
EXPECTED
cmp "$TEST_ROOT/expected.log" "$SKILLS_LOG"

echo "Codex workhorse tests passed ($actual bundled skills + 2 pinned external packs)"
