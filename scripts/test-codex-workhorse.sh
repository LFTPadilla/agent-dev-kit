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

HOME="$HOME" bash "$ROOT/sync.sh" >/dev/null

for managed_skill_source in "$ROOT"/plugins/dev-skills/skills/*/; do
  MANAGED_SKILL_SOURCE="${managed_skill_source%/}"
  CONFLICT_SKILL="$(basename "$managed_skill_source")"
  break
done

STALE_LINK="$HOME/.agents/skills/retired-agent-dev-kit-skill"
ln -s "$MANAGED_SKILL_SOURCE" "$STALE_LINK"
HOME="$HOME" bash "$ROOT/sync.sh" >/dev/null
[ ! -L "$STALE_LINK" ] || { echo "managed stale skill link was not pruned"; exit 1; }

assert_sync_conflict() {
  local conflict_home="$1"
  local conflict_target="$2"
  local expected_destination="${3:-}"
  local output status

  set +e
  output="$(HOME="$conflict_home" bash "$ROOT/sync.sh" 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || { echo "sync unexpectedly accepted conflict: $conflict_target"; exit 1; }
  case "$output" in
    *"$conflict_target"*) ;;
    *) echo "sync conflict did not report skill path: $conflict_target"; exit 1 ;;
  esac
  if [ -n "$expected_destination" ]; then
    [ -L "$conflict_target" ] || { echo "conflicting symlink was replaced: $conflict_target"; exit 1; }
    [ "$(readlink "$conflict_target")" = "$expected_destination" ] || {
      echo "conflicting symlink destination changed: $conflict_target"
      exit 1
    }
  fi
}

DIRECTORY_HOME="$TEST_ROOT/directory-conflict-home"
DIRECTORY_TARGET="$DIRECTORY_HOME/.agents/skills/$CONFLICT_SKILL"
mkdir -p "$DIRECTORY_TARGET"
printf 'preserve me\n' > "$DIRECTORY_TARGET/unmanaged.txt"
assert_sync_conflict "$DIRECTORY_HOME" "$DIRECTORY_TARGET"
[ "$(cat "$DIRECTORY_TARGET/unmanaged.txt")" = "preserve me" ] || {
  echo "conflicting directory content changed: $DIRECTORY_TARGET"
  exit 1
}
[ "$(find "$DIRECTORY_TARGET" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] || {
  echo "sync nested content in conflicting directory: $DIRECTORY_TARGET"
  exit 1
}

SYMLINK_HOME="$TEST_ROOT/symlink-conflict-home"
SYMLINK_TARGET="$SYMLINK_HOME/.agents/skills/$CONFLICT_SKILL"
FOREIGN_SKILL="$TEST_ROOT/unmanaged-skill"
mkdir -p "$(dirname "$SYMLINK_TARGET")" "$FOREIGN_SKILL"
ln -s "$FOREIGN_SKILL" "$SYMLINK_TARGET"
assert_sync_conflict "$SYMLINK_HOME" "$SYMLINK_TARGET" "$FOREIGN_SKILL"

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
