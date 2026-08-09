#!/usr/bin/env bash
# Shared runtime helpers for the Agent Tutor Orchestrator scripts.

# Resolve this library's own real location before sourcing the shared home
# helper: these scripts are copied into ~/.hermes/profiles/<profile>/scripts/
# and reached through symlinks in ~/.local/bin, so a relative source path is
# only reliable once the symlink chain has been followed.
TUTOR_LIB_PATH="${BASH_SOURCE[0]}"
if [ -L "$TUTOR_LIB_PATH" ]; then TUTOR_LIB_PATH="$(readlink -f "$TUTOR_LIB_PATH")"; fi
TUTOR_LIB_DIR="$(cd "$(dirname "$TUTOR_LIB_PATH")" && pwd)"
# shellcheck source=tutor-home-lib.sh
source "$TUTOR_LIB_DIR/tutor-home-lib.sh"

# Sets USER_HOME to the real user home for the given script path. See
# tutor_home_resolve in tutor-home-lib.sh for the resolution precedence, which
# is shared with the Personal Dev Tutor scripts.
tutor_set_user_home() {
  USER_HOME="$(tutor_home_resolve "$1" AGENT_TUTOR_USER_HOME)" || return 1
  [ -d "$USER_HOME" ] || {
    echo "user home does not exist: $USER_HOME" >&2
    return 1
  }
}
