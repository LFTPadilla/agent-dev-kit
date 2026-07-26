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
  mkdir -p "$HERMES_HOME/skills/$name"
  cat > "$HERMES_HOME/skills/$name/SKILL.md" <<EOF
---
name: $name
description: test fixture
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

mkdir -p "$HERMES_HOME/profiles/unmanaged/skills/external/caveman"
if "$ROOT/scripts/install-hermes-workhorse.sh" --profile unmanaged >/dev/null 2>&1; then
  echo "FAIL installer overwrote or accepted an unmanaged caveman directory"
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
