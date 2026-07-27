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
    mkdir -p "$target"
    printf '%s\n' 'partial failed install' > "$target/SKILL.md"
    exit 9
  fi
  if [ -n "${HERMES_TEST_SIGNAL_SOURCE:-}" ] && [ "${3:-}" = "$HERMES_TEST_SIGNAL_SOURCE" ]; then
    mkdir -p "$target"
    printf '%s\n' 'partial interrupted install' > "$target/SKILL.md"
    kill -TERM "$PPID"
    sleep 0.2
    exit 0
  fi
  if [ -n "${HERMES_TEST_BLOCK_SOURCE:-}" ] && [ "${3:-}" = "$HERMES_TEST_BLOCK_SOURCE" ]; then
    : "${HERMES_TEST_BLOCK_STARTED:?}"
    : "${HERMES_TEST_BLOCK_RELEASE:?}"
    : > "$HERMES_TEST_BLOCK_STARTED"
    while [ ! -e "$HERMES_TEST_BLOCK_RELEASE" ]; do sleep 0.05; done
  fi
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

write_fake_ln() {
  if [ -z "${HERMES_TEST_REAL_LN:-}" ]; then
    export HERMES_TEST_REAL_LN="$(command -v ln)"
  fi
  cat > "$FAKE_BIN/ln" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
target="${!#}"
"$HERMES_TEST_REAL_LN" "$@"
if [ -n "${HERMES_TEST_SIGNAL_PROFILE_LINK:-}" ] &&
   [[ "$target" == */profiles/*/skills/external/* ]]; then
  sig="${HERMES_TEST_SIGNAL_PROFILE_LINK}"
  case "$sig" in
    HUP|INT|TERM) kill -"$sig" "$PPID" ;;
    *) echo "unknown signal: $sig" >&2; exit 2 ;;
  esac
  sleep 0.2
fi
SH
  chmod +x "$FAKE_BIN/ln"
}

write_fake_ln

export HERMES_TEST_LOG="$FIXTURE/hermes.log"
export AGENT_DEV_KIT_HERMES_HOME="$HERMES_HOME"
export PATH="$FAKE_BIN:$PATH"

fixture_skill_sha() {
  local name="$1" source="$2"
  printf '%s\n' '---' "name: $name" 'description: test fixture' \
    "source: $source" '---' | sha256sum | cut -d' ' -f1
}

default_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.1/skills/caveman/SKILL.md"
default_ponytail_source="https://raw.githubusercontent.com/DietrichGebert/ponytail/v4.8.4/skills/ponytail/SKILL.md"
default_caveman_sha="$(fixture_skill_sha caveman "$default_caveman_source")"
default_ponytail_sha="$(fixture_skill_sha ponytail "$default_ponytail_source")"
export AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$default_caveman_source"
export AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$default_ponytail_source"
export AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$default_caveman_sha"
export AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$default_ponytail_sha"

"$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null

for name in caveman ponytail; do
  test -f "$HERMES_HOME/skills/$name/SKILL.md"
  grep -q "^name: $name$" "$HERMES_HOME/skills/$name/SKILL.md"
  test -f "$HERMES_HOME/skills/$name/.agent-dev-kit-source"
  test -f "$HERMES_HOME/skills/$name/.agent-dev-kit-sha256"
  test "$(cat "$HERMES_HOME/skills/$name/.agent-dev-kit-sha256")" = \
    "$(sha256sum "$HERMES_HOME/skills/$name/SKILL.md" | cut -d' ' -f1)"
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

override_error="$FIXTURE/override-error"
assert_override_pair() {
  local skill="$1" present_var="$2" missing_var="$3" expected_kind="$4"
  local source_var sha_var other_source_var other_sha_var other_source other_sha
  case "$skill" in
    caveman)
      source_var=AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE
      sha_var=AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256
      other_source_var=AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE
      other_sha_var=AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256
      other_source="$default_ponytail_source"
      other_sha="$default_ponytail_sha"
      ;;
    ponytail)
      source_var=AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE
      sha_var=AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256
      other_source_var=AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE
      other_sha_var=AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256
      other_source="$default_caveman_source"
      other_sha="$default_caveman_sha"
      ;;
    *) echo "unknown skill: $skill" >&2; exit 2 ;;
  esac
  if env -u "$missing_var" \
      "$other_source_var"="$other_source" "$other_sha_var"="$other_sha" \
      "$present_var"="$(eval "printf '%s' \"\$$present_var\"")" \
      "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>"$override_error"; then
      echo "FAIL installer accepted a $expected_kind-only $skill override"
      exit 1
    fi
  if ! grep -q 'source and SHA-256 overrides must be set together' "$override_error"; then
    echo "FAIL installer did not reject partial $expected_kind-only $skill override with the expected error"
    printf 'override_error: %s\n' "$(cat "$override_error")" >&2
    exit 1
  fi
}
for skill in caveman ponytail; do
  assert_override_pair "$skill" \
    "AGENT_DEV_KIT_${skill^^}_HERMES_SOURCE" \
    "AGENT_DEV_KIT_${skill^^}_HERMES_SHA256" "source"
  assert_override_pair "$skill" \
    "AGENT_DEV_KIT_${skill^^}_HERMES_SHA256" \
    "AGENT_DEV_KIT_${skill^^}_HERMES_SOURCE" "SHA-256"
done

printf '\nmanaged drift\n' >> "$HERMES_HOME/skills/caveman/SKILL.md"
drifted_install_count="$(wc -l < "$HERMES_TEST_LOG")"
"$ROOT/scripts/install-hermes-workhorse.sh" --all-profiles >/dev/null
test "$(wc -l < "$HERMES_TEST_LOG")" -eq "$((drifted_install_count + 1))"
grep -q '^description: test fixture$' "$HERMES_HOME/skills/caveman/SKILL.md"
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-sha256")" = \
  "$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"

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

outside_profile="$FIXTURE/outside-profile"
mkdir -p "$outside_profile"
ln -s "$outside_profile" "$HERMES_HOME/profiles/escaped"
if "$ROOT/scripts/install-hermes-workhorse.sh" --profile escaped >/dev/null 2>&1; then
  echo "FAIL installer accepted a symlinked Hermes profile"
  exit 1
fi
test ! -e "$outside_profile/skills"

symlinked_root="$FIXTURE/symlinked-hermes-root"
outside_skills="$FIXTURE/outside-skills"
mkdir -p "$symlinked_root/profiles/alpha" "$outside_skills"
ln -s "$outside_skills" "$symlinked_root/skills"
if AGENT_DEV_KIT_HERMES_HOME="$symlinked_root" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  echo "FAIL installer accepted a symlinked Hermes global skills path"
  exit 1
fi
test -z "$(find "$outside_skills" -mindepth 1 -print -quit)"

mkdir -p "$HERMES_HOME/profiles/beta/skills" \
  "$HERMES_HOME/profiles/link-collision/skills/external/ponytail"
if "$ROOT/scripts/install-hermes-workhorse.sh" --profile beta \
  --profile link-collision >/dev/null 2>&1; then
  echo "FAIL installer accepted a partial profile-link transaction"
  exit 1
fi
test ! -e "$HERMES_HOME/profiles/beta/skills/external/caveman"
test ! -e "$HERMES_HOME/profiles/beta/skills/external/ponytail"
test ! -e "$HERMES_HOME/profiles/link-collision/skills/external/caveman"
test -d "$HERMES_HOME/profiles/link-collision/skills/external/ponytail"

for sig in TERM HUP INT; do
  rm -rf "$HERMES_HOME/profiles/signal-$sig"
  mkdir -p "$HERMES_HOME/profiles/signal-$sig/skills"
  HERMES_TEST_SIGNAL_PROFILE_LINK="$sig" \
    "$ROOT/scripts/install-hermes-workhorse.sh" --profile "signal-$sig" >/dev/null
  test -L "$HERMES_HOME/profiles/signal-$sig/skills/external/caveman"
  test -L "$HERMES_HOME/profiles/signal-$sig/skills/external/ponytail"
done
{ test ! -e "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" &&
  test ! -L "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock"; } || {
  echo "FAIL signal-mid-install left a workhorse lock behind"
  exit 1
}

mkdir -p "$HERMES_HOME/profiles/ln-failure/skills"
cat > "$FAKE_BIN/ln" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
target="${!#}"
if [[ "$target" == */profiles/*/skills/external/* ]]; then
  echo "fake ln forced failure" >&2
  exit 1
fi
exec "$HERMES_TEST_REAL_LN" "$@"
SH
chmod +x "$FAKE_BIN/ln"
ln_failure_log="$FIXTURE/ln-failure.log"
if "$ROOT/scripts/install-hermes-workhorse.sh" --profile ln-failure \
    >/dev/null 2>"$ln_failure_log"; then
  echo "FAIL installer accepted an ln failure"
  exit 1
fi
grep -q 'unable to create profile skill link' "$ln_failure_log"
test ! -e "$HERMES_HOME/profiles/ln-failure/skills/external/caveman"
test ! -e "$HERMES_HOME/profiles/ln-failure/skills/external/ponytail"
{ test ! -e "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" &&
  test ! -L "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock"; } || {
  echo "FAIL ln failure left a workhorse lock behind"
  exit 1
}
write_fake_ln

updated_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.2/skills/caveman/SKILL.md"
AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$updated_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$updated_caveman_source")" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$updated_caveman_source"
grep -q "^source: $updated_caveman_source$" "$HERMES_HOME/skills/caveman/SKILL.md"
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-sha256")" = \
  "$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"

mismatched_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.2-tampered/skills/caveman/SKILL.md"
before_mismatch_sha="$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"
if AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$mismatched_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(printf '0%.0s' {1..64})" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  echo "FAIL installer accepted content that missed its pinned SHA-256"
  exit 1
fi
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$updated_caveman_source"
test "$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)" = \
  "$before_mismatch_sha"

transaction_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.2-bundle/skills/caveman/SKILL.md"
transaction_ponytail_source="https://raw.githubusercontent.com/DietrichGebert/ponytail/v4.8.4-bundle/skills/ponytail/SKILL.md"
before_transaction_caveman_source="$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")"
before_transaction_ponytail_source="$(cat "$HERMES_HOME/skills/ponytail/.agent-dev-kit-source")"
if AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$transaction_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$transaction_caveman_source")" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$transaction_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$(printf '0%.0s' {1..64})" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  echo "FAIL installer accepted a partially valid workhorse bundle"
  exit 1
fi
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = \
  "$before_transaction_caveman_source"
test "$(cat "$HERMES_HOME/skills/ponytail/.agent-dev-kit-source")" = \
  "$before_transaction_ponytail_source"
if compgen -G "$HERMES_HOME/skills/.*.backup.*" >/dev/null; then
  echo "FAIL failed bundle transaction left a skill backup behind"
  exit 1
fi

failed_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.3/skills/caveman/SKILL.md"
before_failed_refresh_sha="$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"
if HERMES_TEST_FAIL_SOURCE="$failed_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$failed_caveman_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$default_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$default_ponytail_sha" \
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
{ test ! -e "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" &&
  test ! -L "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock"; } || {
  echo "FAIL failed refresh left a workhorse lock behind"
  exit 1
}

signal_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.4/skills/caveman/SKILL.md"
before_signal_refresh_sha="$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)"
set +e
HERMES_TEST_SIGNAL_SOURCE="$signal_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$signal_caveman_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$default_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$default_ponytail_sha" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1
signal_refresh_status=$?
set -e
if [ "$signal_refresh_status" -ne 143 ]; then
  echo "FAIL interrupted refresh returned $signal_refresh_status, expected 143"
  exit 1
fi
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$updated_caveman_source"
test "$(sha256sum "$HERMES_HOME/skills/caveman/SKILL.md" | cut -d' ' -f1)" = \
  "$before_signal_refresh_sha"
{ test ! -e "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" &&
  test ! -L "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock"; } || {
  echo "FAIL interrupted refresh left a workhorse lock behind"
  exit 1
}

concurrent_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.5/skills/caveman/SKILL.md"
block_started="$FIXTURE/concurrent-refresh-started"
block_release="$FIXTURE/concurrent-refresh-release"
before_concurrent_count="$(wc -l < "$HERMES_TEST_LOG")"
HERMES_TEST_BLOCK_SOURCE="$concurrent_caveman_source" \
  HERMES_TEST_BLOCK_STARTED="$block_started" \
  HERMES_TEST_BLOCK_RELEASE="$block_release" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$concurrent_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$concurrent_caveman_source")" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$default_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$default_ponytail_sha" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1 &
concurrent_pid=$!
for _ in $(seq 1 200); do
  [ -e "$block_started" ] && break
  sleep 0.05
done
if [ ! -e "$block_started" ]; then
  kill "$concurrent_pid" 2>/dev/null || true
  wait "$concurrent_pid" 2>/dev/null || true
  echo "FAIL concurrent refresh fixture did not reach the critical section"
  exit 1
fi
if AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$concurrent_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$concurrent_caveman_source")" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$default_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$default_ponytail_sha" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  : > "$block_release"
  wait "$concurrent_pid" 2>/dev/null || true
  echo "FAIL installer allowed concurrent managed skill refreshes"
  exit 1
fi
: > "$block_release"
wait "$concurrent_pid"
test "$(wc -l < "$HERMES_TEST_LOG")" -eq "$((before_concurrent_count + 1))"
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$concurrent_caveman_source"
grep -q "^source: $concurrent_caveman_source$" "$HERMES_HOME/skills/caveman/SKILL.md"
if compgen -G "$HERMES_HOME/skills/.caveman.agent-dev-kit.lock" >/dev/null; then
  echo "FAIL successful refresh left a managed-skill lock behind"
  exit 1
fi

bundle_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.6/skills/caveman/SKILL.md"
competing_caveman_source="https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.7/skills/caveman/SKILL.md"
bundle_ponytail_source="https://raw.githubusercontent.com/DietrichGebert/ponytail/v4.8.5/skills/ponytail/SKILL.md"
bundle_started="$FIXTURE/bundle-refresh-started"
bundle_release="$FIXTURE/bundle-refresh-release"
before_bundle_count="$(wc -l < "$HERMES_TEST_LOG")"
HERMES_TEST_BLOCK_SOURCE="$bundle_ponytail_source" \
  HERMES_TEST_BLOCK_STARTED="$bundle_started" \
  HERMES_TEST_BLOCK_RELEASE="$bundle_release" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$bundle_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$bundle_caveman_source")" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$bundle_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$(fixture_skill_sha ponytail "$bundle_ponytail_source")" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1 &
bundle_pid=$!
for _ in $(seq 1 200); do
  [ -e "$bundle_started" ] && break
  sleep 0.05
done
if [ ! -e "$bundle_started" ]; then
  kill "$bundle_pid" 2>/dev/null || true
  wait "$bundle_pid" 2>/dev/null || true
  echo "FAIL bundle refresh fixture did not reach the second skill"
  exit 1
fi
if AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE="$competing_caveman_source" \
  AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256="$(fixture_skill_sha caveman "$competing_caveman_source")" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE="$bundle_ponytail_source" \
  AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256="$(fixture_skill_sha ponytail "$bundle_ponytail_source")" \
  "$ROOT/scripts/install-hermes-workhorse.sh" --profile alpha >/dev/null 2>&1; then
  : > "$bundle_release"
  wait "$bundle_pid" 2>/dev/null || true
  echo "FAIL installer allowed a competing workhorse bundle refresh"
  exit 1
fi
: > "$bundle_release"
wait "$bundle_pid"
test "$(wc -l < "$HERMES_TEST_LOG")" -eq "$((before_bundle_count + 2))"
test "$(cat "$HERMES_HOME/skills/caveman/.agent-dev-kit-source")" = "$bundle_caveman_source"
test "$(cat "$HERMES_HOME/skills/ponytail/.agent-dev-kit-source")" = "$bundle_ponytail_source"
if [ -e "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" ] ||
   [ -L "$HERMES_HOME/skills/.agent-dev-kit-workhorse.lock" ]; then
  echo "FAIL successful bundle refresh left a workhorse lock behind"
  exit 1
fi

grep -q 'AGENT_DEV_KIT_HERMES_HOME="\$PERSONAL_TUTOR_USER_HOME/.hermes"' \
  "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'install-hermes-workhorse.sh.*--profile.*PROFILE' \
  "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'AGENT_DEV_KIT_HERMES_HOME="\$USER_HOME/.hermes"' \
  "$ROOT/scripts/tutor-install.sh"
grep -q 'install-hermes-workhorse.sh.*--profile.*PROFILE' \
  "$ROOT/scripts/tutor-install.sh"
grep -q 'Hermes baseline skill:.*baseline_skill' "$ROOT/scripts/tutor-smoke.sh"
grep -q 'install-hermes-workhorse.sh.*--all-profiles' "$ROOT/bootstrap.sh"
node -e 'const p=require(process.argv[1]); if (!p.scripts["test:hermes-workhorse"]) process.exit(1)' \
  "$ROOT/package.json"
grep -q 'install-hermes-workhorse.sh --all-profiles' "$ROOT/docs/external-deps.md"

echo "Hermes workhorse tests passed"