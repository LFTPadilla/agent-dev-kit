#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

HERMES_HOME="$FIXTURE/.hermes"
FAKE_BIN="$FIXTURE/bin"
mkdir -p "$FAKE_BIN" "$HERMES_HOME/profiles/alpha/skills" \
  "$HERMES_HOME/profiles/personal-dev-tutor/skills"

cat > "$FAKE_BIN/hermes" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$HERMES_TEST_LOG"
if [ "${1:-}" = --profile ] && [ "${2:-}" = default ]; then
  shift 2
fi
if [ "${1:-}" = skills ] && [ "${2:-}" = install ]; then
  case "${3:-}" in
    */caveman/*) name=caveman ;;
    */ponytail/*) name=ponytail ;;
    *) echo "unexpected skill URL: ${3:-}" >&2; exit 2 ;;
  esac
  target="$HERMES_HOME/skills/$name"
  if [ -n "${HERMES_TEST_FAIL_SOURCE:-}" ] && [ "${3:-}" = "$HERMES_TEST_FAIL_SOURCE" ]; then
    exit 9
  fi
  # Match Hermes' existing-install behavior: a successful invocation may be a
  # no-op unless the caller first establishes a safe managed refresh path.
  [ ! -f "$target/SKILL.md" ] || exit 0
  mkdir -p "$target"
  cat > "$target/SKILL.md" <<EOF
---
name: $name
description: test fixture
source: ${3:-}
---
EOF
  exit 0
fi
echo "unexpected hermes command: $*" >&2
exit 2
SH
chmod +x "$FAKE_BIN/hermes"

export HERMES_TEST_LOG="$FIXTURE/hermes.log"
export AGENT_DEV_KIT_HERMES_HOME="$HERMES_HOME"
export PATH="$FAKE_BIN:$PATH"

"$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null

for name in caveman ponytail; do
  test -f "$HERMES_HOME/skills/$name/SKILL.md"
  grep -q "^name: $name$" "$HERMES_HOME/skills/$name/SKILL.md"
  test -f "$HERMES_HOME/skills/$name/.agent-dev-kit-source"
  for profile in alpha personal-dev-tutor; do
    target="$HERMES_HOME/profiles/$profile/skills/external/$name"
    test -L "$target"
    test "$(readlink -f "$target")" = "$(readlink -f "$HERMES_HOME/skills/$name")"
  done
done

grep -q 'JuliusBrussee/caveman/v1.9.1/skills/caveman/SKILL.md' "$HERMES_TEST_LOG"
grep -q 'DietrichGebert/ponytail/v4.8.4/skills/ponytail/SKILL.md' "$HERMES_TEST_LOG"
grep -q '^--profile default skills install ' "$HERMES_TEST_LOG"

first_install_count="$(wc -l < "$HERMES_TEST_LOG")"
"$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null
test "$(wc -l < "$HERMES_TEST_LOG")" -eq "$first_install_count"

managed_caveman="$HERMES_HOME/skills/caveman.managed-test-backup"
mv "$HERMES_HOME/skills/caveman" "$managed_caveman"
mkdir -p "$HERMES_HOME/skills/caveman"
cat > "$HERMES_HOME/skills/caveman/SKILL.md" <<'EOF'
---
name: caveman
description: unmanaged user fixture
---
EOF
before_unmanaged_count="$(wc -l < "$HERMES_TEST_LOG")"
if "$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null 2>&1; then
  echo "FAIL installer adopted an unmanaged global caveman skill"
  exit 1
fi
test "$(wc -l < "$HERMES_TEST_LOG")" -eq "$before_unmanaged_count"
grep -q '^description: unmanaged user fixture$' "$HERMES_HOME/skills/caveman/SKILL.md"
test ! -e "$HERMES_HOME/skills/caveman/.agent-dev-kit-source"
printf '%s\n' \
  'https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.1/skills/caveman/SKILL.md' \
  > "$FIXTURE/foreign-source-marker"
ln -s "$FIXTURE/foreign-source-marker" \
  "$HERMES_HOME/skills/caveman/.agent-dev-kit-source"
if "$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null 2>&1; then
  echo "FAIL installer trusted a symlinked global-skill ownership marker"
  exit 1
fi
grep -q '^description: unmanaged user fixture$' "$HERMES_HOME/skills/caveman/SKILL.md"
rm -rf "$HERMES_HOME/skills/caveman"
mv "$managed_caveman" "$HERMES_HOME/skills/caveman"

mkdir -p "$HERMES_HOME/profiles/unmanaged/skills/external/caveman"
if "$ROOT/scripts/install-hermes-workhorse.sh" --profile unmanaged >/dev/null 2>&1; then
  echo "FAIL installer overwrote or accepted an unmanaged caveman directory"
  exit 1
fi

updated_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.2/skills/caveman/SKILL.md"
AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$updated_caveman_source" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$updated_caveman_source"
grep -q "^source: $updated_caveman_source$" "$HERMES_HOME/skills/caveman/SKILL.md"

failed_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.3/skills/caveman/SKILL.md"
before_failed_refresh_sha="$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"
if HERMES_TEST_FAIL_SOURCE="$failed_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$failed_caveman_source" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  echo "FAIL installer accepted a failed managed skill refresh"
  exit 1
fi
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$updated_caveman_source"
test "$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)" = \
  "$before_failed_refresh_sha"
if compgen -G "$HERMES_HOME/skills/.caveman.backup.*" >/dev/null; then
  echo "FAIL failed refresh left a managed-skill backup behind"
  exit 1
fi

grep -q 'install-hermes-workhorse.sh.*--profile.*PROFILE' \
  "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'install-hermes-workhorse.sh.*--profile.*PROFILE' \
  "$ROOT/scripts/tutor-install.sh"
grep -q 'Hermes baseline skill:.*baseline_skill' "$ROOT/scripts/tutor-smoke.sh"
grep -q 'install-hermes-workhorse.sh.*--all-profiles' "$ROOT/bootstrap.sh"
node -e 'const p=require(process.argv[1]); if (!p.scripts["test:hermes-workhorse"]) process.exit(1)' \
  "$ROOT/package.json"
grep -q 'install-hermes-workhorse.sh --all-profiles' "$ROOT/docs/external-deps.md"

echo "Hermes workhorse tests passed"
