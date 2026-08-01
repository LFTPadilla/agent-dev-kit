#!/usr/bin/env bash
# Shared runtime helpers for the Agent Tutor Orchestrator scripts.

tutor_set_user_home() {
  local self_path="$1" hermes_dir="" dir parent
  dir="$(cd "$(dirname "$self_path")" && pwd)"
  while [ "$dir" != "/" ]; do
    if [ "$(basename "$dir")" = ".hermes" ]; then
      hermes_dir="$dir"
      break
    fi
    parent="$(dirname "$dir")"
    [ "$parent" = "$dir" ] && break
    dir="$parent"
  done

  if [ -n "$hermes_dir" ]; then
    USER_HOME="$(dirname "$hermes_dir")"
  else
    USER_HOME="${HOME:?HOME is required}"
  fi
  [ -d "$USER_HOME" ] || {
    echo "user home does not exist: $USER_HOME" >&2
    return 1
  }
}
