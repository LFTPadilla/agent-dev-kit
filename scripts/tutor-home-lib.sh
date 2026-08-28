#!/usr/bin/env bash
# Shared real-user-home resolution for both tutor script families.
#
# The Agent Tutor Orchestrator (tutor-*.sh) installs into
# <real home>/.hermes/profiles/<profile>/, reads credentials and writes
# state relative to that home. This file is the single home resolution library.
#
# This file is a library: source it, do not execute it.

# tutor_home_resolve <self-path> [override-var-name ...]
#
# Prints the resolved real user home on stdout and returns 0, or prints a
# diagnostic on stderr and returns 1.
#
# Precedence (single documented order for both families):
#   1. An explicit environment override pointing at an existing directory.
#      The family-specific variables named by the caller are consulted first
#      (most specific wins, so PERSONAL_TUTOR_USER_HOME keeps behaving exactly
#      as it always has), then the generic TUTOR_USER_HOME. The value is
#      canonicalized with `pwd -P`, matching the historical override path.
#   2. The `.hermes` ancestor of <self-path>: its parent is the real home. This
#      is the installed-profile layout,
#      <home>/.hermes/profiles/<profile>/scripts/<script>.sh, and it is what
#      keeps resolution correct when a runtime re-points $HOME at a profile dir.
#   3. `getent passwd $(id -u)` field 6, when it is an existing directory.
#      In the installed layout this agrees with step 2 by construction, because
#      the installers only ever create profiles under the home they resolved.
#   4. $HOME. Unset or non-existent is a hard error — never guess.
#
# Steps 2-4 deliberately do not trust $HOME first: Hermes exports HOME as the
# profile directory when it runs a profile's scripts.
tutor_home_resolve() {
  local self_path="${1-}"
  if [ $# -gt 0 ]; then shift; fi
  local var value dir parent hermes_dir="" passwd_home

  # 1. explicit environment override (family-specific first, then generic)
  for var in "$@" TUTOR_USER_HOME; do
    [ -n "$var" ] || continue
    value="${!var-}"
    if [ -n "$value" ] && [ -d "$value" ]; then
      (cd "$value" && pwd -P)
      return 0
    fi
  done

  # 2. `.hermes` ancestor of the calling script's real path
  if [ -n "$self_path" ]; then
    dir="$(cd "$(dirname "$self_path")" 2>/dev/null && pwd)" || dir=""
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
      if [ "$(basename "$dir")" = ".hermes" ]; then
        hermes_dir="$dir"
        break
      fi
      parent="$(dirname "$dir")"
      [ "$parent" = "$dir" ] && break
      dir="$parent"
    done
    if [ -n "$hermes_dir" ]; then
      value="$(dirname "$hermes_dir")"
      if [ -d "$value" ]; then
        printf '%s\n' "$value"
        return 0
      fi
    fi
  fi

  # 3. the account's passwd entry
  passwd_home="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)"
  if [ -n "$passwd_home" ] && [ -d "$passwd_home" ]; then
    printf '%s\n' "$passwd_home"
    return 0
  fi

  # 4. $HOME, or fail closed
  if [ -z "${HOME-}" ]; then
    echo "unable to resolve the real user home: HOME is unset" >&2
    return 1
  fi
  if [ ! -d "$HOME" ]; then
    echo "unable to resolve the real user home: HOME does not exist: $HOME" >&2
    return 1
  fi
  printf '%s\n' "$HOME"
}

# tutor_home_resolve_path <path>
#
# Canonicalize <path> without requiring it to exist, so callers can validate a
# cache or state location before creating it. `readlink -m` is the direct
# equivalent of Python's `Path(...).resolve(strict=False)`; plain `readlink -f`
# is not, because it fails when a parent component is missing (which is the
# normal case for a first-run cache root).
tutor_home_resolve_path() {
  readlink -m "$1"
}
