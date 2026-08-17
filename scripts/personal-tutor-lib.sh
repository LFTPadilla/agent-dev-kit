#!/usr/bin/env bash
# Shared runtime helpers for the Personal Dev Tutor profile.

# Resolve this library's own real location first: it is copied into
# ~/.hermes/profiles/<profile>/scripts/ and reached through symlinks in
# ~/.local/bin, so both the shared home helper below and the profile inference
# further down need the followed path rather than the invocation path.
PERSONAL_TUTOR_LIB_PATH="${BASH_SOURCE[0]}"
if [ -L "$PERSONAL_TUTOR_LIB_PATH" ]; then PERSONAL_TUTOR_LIB_PATH="$(readlink -f "$PERSONAL_TUTOR_LIB_PATH")"; fi
PERSONAL_TUTOR_LIB_DIR="$(cd "$(dirname "$PERSONAL_TUTOR_LIB_PATH")" && pwd)"
# shellcheck source=tutor-home-lib.sh
source "$PERSONAL_TUTOR_LIB_DIR/tutor-home-lib.sh"

# Echoes the real user home. See tutor_home_resolve in tutor-home-lib.sh for the
# resolution precedence, which is shared with the Agent Tutor Orchestrator
# scripts. PERSONAL_TUTOR_USER_HOME remains the highest-priority override.
personal_tutor_real_home() {
  tutor_home_resolve "$PERSONAL_TUTOR_LIB_PATH" PERSONAL_TUTOR_USER_HOME
}

personal_tutor_git_root() {
  local requested="${1:-}" root

  if [ -z "$requested" ]; then
    root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$root" ] || return 1
  else
    root="$requested"
  fi

  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 2
  root="$(git -C "$root" rev-parse --show-toplevel)" || return 2
  (cd "$root" && pwd -P)
}

personal_tutor_path_is_within() {
  local path="$1" root="$2"
  case "$path" in
    "$root"|"$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

personal_tutor_paths_match() {
  [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]
}

personal_tutor_resolve_path() {
  tutor_home_resolve_path "$1"
}

personal_tutor_path_key() {
  printf '%s' "$1" | sha256sum | cut -c1-16
}

personal_tutor_prepare_tmux() {
  local uid runtime
  uid="$(id -u)"
  runtime="${XDG_RUNTIME_DIR:-/run/user/$uid}"
  if [ -S "$runtime/tmux-$uid/default" ]; then
    export TMUX_TMPDIR="$runtime"
  fi
}

personal_tutor_graphify() {
  local runtime_dir
  runtime_dir="$PERSONAL_TUTOR_USER_HOME/.cache/personal-dev-tutor/graphify-runtime"
  umask 077
  mkdir -p "$runtime_dir"
  chmod 700 "$runtime_dir"
  (
    cd "$runtime_dir"
    HOME="$PERSONAL_TUTOR_USER_HOME" command graphify "$@"
  )
}

personal_tutor_array_contains() {
  local needle="$1" value
  shift
  for value in "$@"; do
    [ "$value" = "$needle" ] && return 0
  done
  return 1
}

personal_tutor_is_live_codex_pane() {
  local command="$1" dead="$2" codex_home="$3"
  [ "$command" = codex ] && [ "$dead" = 0 ] && [ "$codex_home" = "$PERSONAL_TUTOR_CODEX_HOME" ]
}

PERSONAL_TUTOR_USER_HOME="$(personal_tutor_real_home)"
PERSONAL_TUTOR_INFERRED_PROFILE=""
case "$PERSONAL_TUTOR_LIB_PATH" in
  "$PERSONAL_TUTOR_USER_HOME"/.hermes/profiles/*/scripts/*)
    PERSONAL_TUTOR_INFERRED_PROFILE="${PERSONAL_TUTOR_LIB_PATH#"$PERSONAL_TUTOR_USER_HOME/.hermes/profiles/"}"
    PERSONAL_TUTOR_INFERRED_PROFILE="${PERSONAL_TUTOR_INFERRED_PROFILE%%/*}"
    ;;
esac
PERSONAL_TUTOR_PROFILE="${PERSONAL_TUTOR_PROFILE:-${PERSONAL_TUTOR_INFERRED_PROFILE:-personal-dev-tutor}}"
PERSONAL_TUTOR_PROFILE_DIR="$PERSONAL_TUTOR_USER_HOME/.hermes/profiles/$PERSONAL_TUTOR_PROFILE"
PERSONAL_TUTOR_CODEX_USER_HOME="$PERSONAL_TUTOR_PROFILE_DIR/codex-user"
PERSONAL_TUTOR_CODEX_HOME="$PERSONAL_TUTOR_CODEX_USER_HOME/.codex"
PERSONAL_TUTOR_MANIFEST="$PERSONAL_TUTOR_PROFILE_DIR/personal-dev-tutor.yml"
PERSONAL_TUTOR_MANIFEST_SESSION=""
if [ -f "$PERSONAL_TUTOR_MANIFEST" ]; then
  PERSONAL_TUTOR_MANIFEST_SESSION="$(awk '/delegate_session:/ {print $2; exit}' "$PERSONAL_TUTOR_MANIFEST")"
fi
PERSONAL_TUTOR_SESSION="${PERSONAL_TUTOR_SESSION:-${PERSONAL_TUTOR_MANIFEST_SESSION:-personal}}"
PERSONAL_TUTOR_GRAPHIFY_VERSION="0.9.25"
PERSONAL_TUTOR_CONTEXT7_URL="https://mcp.context7.com/mcp"
PERSONAL_TUTOR_BASELINE_SKILLS=(caveman ponytail)

PERSONAL_TUTOR_GSD_SKILLS=(
  gsd-new-project gsd-discuss-phase gsd-plan-phase
  gsd-execute-phase gsd-verify-work gsd-progress
)

# Worker capabilities only. Tutor/orchestrator and skill-discovery skills remain
# exclusive to Hermes so Codex cannot silently expand or redefine its role.
PERSONAL_TUTOR_CODEX_SKILLS=(
  diagram-render drawio-skill excel-xlsx git-essentials human-writing-style
  image-finalize improve java-development knip live-qa pdf playwright-stability
  security-checklist semgrep stagehand tex-render web-browse word-docx
)

# The flagship profile intentionally excludes the two alternative orchestrators
# and dynamic skill discovery. GSD is the only lifecycle authority here.
PERSONAL_TUTOR_HERMES_SKILLS=(personal-development-mentor "${PERSONAL_TUTOR_CODEX_SKILLS[@]}")

export PATH="$PERSONAL_TUTOR_USER_HOME/.nix-profile/bin:$PERSONAL_TUTOR_USER_HOME/.local/bin:$PATH"
personal_tutor_prepare_tmux
