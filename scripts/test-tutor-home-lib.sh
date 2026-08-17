#!/usr/bin/env bash
# Contract test for the shared tutor home-resolution helper (tutor-home-lib.sh)
# and for the two family wrappers built on it.
#
# Hermetic: every fixture lives under a single mktemp -d tree, the real user home
# is never read, written, or asserted against, and each case runs in a child
# `env -i` shell so overrides and PATH stubs cannot leak between cases.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/tutor-home-lib.sh"
TUTOR_LIB="$ROOT/scripts/tutor-lib.sh"
PERSONAL_LIB="$ROOT/scripts/personal-tutor-lib.sh"

for file in "$LIB" "$TUTOR_LIB" "$PERSONAL_LIB"; do
  [ -f "$file" ] || { printf 'FAIL missing %s\n' "$file"; exit 1; }
  bash -n "$file"
done

# pwd -P so every later comparison is against a canonical path, even where the
# temp directory itself sits behind a symlink.
FIXTURE="$(mktemp -d)"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
cleanup() { rm -rf "$FIXTURE"; }
trap cleanup EXIT

fail() { printf 'FAIL %s\n' "$1"; exit 1; }

# PATH variants. Every case states which one it wants, so the passwd branch is
# never left to chance on the host running the test.
stub_bin="$FIXTURE/stub-bin"
nopasswd_bin="$FIXTURE/nopasswd-bin"
passwd_home="$FIXTURE/passwd-home"
mkdir -p "$stub_bin" "$nopasswd_bin" "$passwd_home"
cat > "$stub_bin/getent" <<EOF
#!/usr/bin/env bash
printf 'fixture:x:0:0:fixture:%s:/bin/bash\n' "$passwd_home"
EOF
printf '#!/usr/bin/env bash\nexit 2\n' > "$nopasswd_bin/getent"
chmod +x "$stub_bin/getent" "$nopasswd_bin/getent"
REAL_PASSWD="PATH=$PATH"
STUB_PASSWD="PATH=$stub_bin:$PATH"
NO_PASSWD="PATH=$nopasswd_bin:$PATH"

# resolve <self-path> <override-var-or-empty> <env assignment ...>
resolve() {
  local self_path="$1" override_var="$2"
  shift 2
  env -i "$@" \
    bash -c 'set -uo pipefail; source "$1"; tutor_home_resolve "$2" "$3"' \
    _ "$LIB" "$self_path" "$override_var"
}

override_home="$FIXTURE/override-home"
other_home="$FIXTURE/other-home"
ancestor_home="$FIXTURE/ancestor-home"
installed_scripts="$ancestor_home/.hermes/profiles/personal-dev-tutor/scripts"
mkdir -p "$override_home" "$other_home" "$installed_scripts"

# --- 1. an explicit env override wins over every other signal -----------------
got="$(resolve "$installed_scripts/personal-tutor-lib.sh" PERSONAL_TUTOR_USER_HOME \
  "PERSONAL_TUTOR_USER_HOME=$override_home" "HOME=$FIXTURE/unused" "$REAL_PASSWD")"
[ "$got" = "$override_home" ] || fail "family override lost to the .hermes ancestor: $got"

got="$(resolve "$installed_scripts/tutor-lib.sh" AGENT_TUTOR_USER_HOME \
  "TUTOR_USER_HOME=$override_home" "HOME=$FIXTURE/unused" "$REAL_PASSWD")"
[ "$got" = "$override_home" ] || fail "generic TUTOR_USER_HOME override ignored: $got"

# The family-specific variable is the more specific signal and must win.
got="$(resolve "$installed_scripts/personal-tutor-lib.sh" PERSONAL_TUTOR_USER_HOME \
  "PERSONAL_TUTOR_USER_HOME=$override_home" "TUTOR_USER_HOME=$other_home" \
  "HOME=$FIXTURE/unused" "$REAL_PASSWD")"
[ "$got" = "$override_home" ] || fail "generic override beat the family override: $got"

# An override that is not an existing directory is not a home. Keep resolving.
got="$(resolve "$installed_scripts/personal-tutor-lib.sh" PERSONAL_TUTOR_USER_HOME \
  "PERSONAL_TUTOR_USER_HOME=$FIXTURE/missing-home" "HOME=$FIXTURE/unused" "$REAL_PASSWD")"
[ "$got" = "$ancestor_home" ] || fail "a non-existent override was trusted: $got"

# --- 2. .hermes ancestor detection (installed-profile layout) -----------------
got="$(resolve "$installed_scripts/tutor-status.sh" AGENT_TUTOR_USER_HOME \
  "HOME=$FIXTURE/unused" "$STUB_PASSWD")"
[ "$got" = "$ancestor_home" ] || fail ".hermes ancestor not detected: $got"

deep="$ancestor_home/.hermes/profiles/agent-tutor-orchestrator/scripts/nested"
mkdir -p "$deep"
got="$(resolve "$deep/tutor-audit.sh" AGENT_TUTOR_USER_HOME \
  "HOME=$FIXTURE/unused" "$STUB_PASSWD")"
[ "$got" = "$ancestor_home" ] || fail ".hermes ancestor walk stopped too early: $got"

# --- 3. the passwd entry outranks $HOME --------------------------------------
checkout="$FIXTURE/checkout/scripts"
home_only="$FIXTURE/home-only"
mkdir -p "$checkout" "$home_only"
got="$(resolve "$checkout/personal-tutor-lib.sh" PERSONAL_TUTOR_USER_HOME \
  "HOME=$home_only" "$STUB_PASSWD")"
[ "$got" = "$passwd_home" ] || fail "passwd entry did not outrank \$HOME: $got"

# --- 4. fallback to $HOME, and fail closed when even that is unusable --------
got="$(resolve "$checkout/personal-tutor-lib.sh" PERSONAL_TUTOR_USER_HOME \
  "HOME=$home_only" "$NO_PASSWD")"
[ "$got" = "$home_only" ] || fail "did not fall back to \$HOME: $got"

if resolve "$checkout/personal-tutor-lib.sh" '' "$NO_PASSWD" >/dev/null 2>&1; then
  fail "resolution succeeded with no override, no .hermes ancestor, and no HOME"
fi
if resolve "$checkout/personal-tutor-lib.sh" '' \
  "HOME=$FIXTURE/no-such-home" "$NO_PASSWD" >/dev/null 2>&1; then
  fail "resolution accepted a non-existent HOME"
fi

# --- 5. both family wrappers keep their existing calling conventions ---------
# tutor_set_user_home "$0" still assigns USER_HOME.
got="$(env -i "$REAL_PASSWD" "HOME=$FIXTURE/unused" bash -c \
  'set -uo pipefail; source "$1"; tutor_set_user_home "$2" || exit 1; printf "%s\n" "$USER_HOME"' \
  _ "$TUTOR_LIB" "$installed_scripts/tutor-status.sh")"
[ "$got" = "$ancestor_home" ] || fail "tutor_set_user_home did not set USER_HOME: $got"

# personal_tutor_real_home still echoes the home on stdout.
got="$(env -i "$REAL_PASSWD" "PERSONAL_TUTOR_USER_HOME=$override_home" \
  "HOME=$FIXTURE/unused" bash -c \
  'set -uo pipefail; source "$1"; personal_tutor_real_home' _ "$PERSONAL_LIB")"
[ "$got" = "$override_home" ] || fail "personal_tutor_real_home lost its contract: $got"

# --- 6. resolve_path on existing and non-existent paths ----------------------
existing="$FIXTURE/resolve/existing"
missing="$FIXTURE/resolve/absent/deeper/leaf"
mkdir -p "$existing"
# shellcheck source=tutor-home-lib.sh
source "$LIB"

got="$(tutor_home_resolve_path "$existing/..//existing/")"
[ "$got" = "$existing" ] || fail "resolve_path mangled an existing path: $got"

got="$(tutor_home_resolve_path "$missing")"
[ "$got" = "$missing" ] || fail "resolve_path failed on a non-existent path: $got"

# Symlinks are followed, matching the Path.resolve(strict=False) it replaced.
ln -s "$existing" "$FIXTURE/resolve/link"
got="$(tutor_home_resolve_path "$FIXTURE/resolve/link/inner")"
[ "$got" = "$existing/inner" ] || fail "resolve_path did not follow a symlink: $got"

# The Personal Dev Tutor wrapper keeps the same contract, without python3.
got="$(env -i "$REAL_PASSWD" "PERSONAL_TUTOR_USER_HOME=$override_home" bash -c \
  'set -uo pipefail; source "$1"; personal_tutor_resolve_path "$2"' \
  _ "$PERSONAL_LIB" "$missing")"
[ "$got" = "$missing" ] || fail "personal_tutor_resolve_path changed contract: $got"
if grep -q 'python3' "$PERSONAL_LIB"; then
  fail "personal-tutor-lib.sh still depends on python3"
fi

# --- 7. the installers must ship the shared library into the profile ---------
grep -q 'scripts/tutor-home-lib.sh' "$ROOT/scripts/personal-tutor-install.sh" \
  || fail "personal-tutor-install.sh does not copy tutor-home-lib.sh into the profile"
grep -q 'tutor-home-lib.sh' "$ROOT/scripts/tutor-install.sh" \
  || fail "tutor-install.sh does not assert tutor-home-lib.sh is present"

echo "PASS shared tutor home-resolution contract"
