#!/usr/bin/env bash
# Install the pinned caveman + ponytail baseline for Hermes and expose it to profiles.
set -euo pipefail

validate_override_pair() {
  local name="$1" source_override="$2" checksum_override="$3"
  if [ -n "$source_override" ] || [ -n "$checksum_override" ]; then
    if [ -z "$source_override" ] || [ -z "$checksum_override" ]; then
      echo "$name source and SHA-256 overrides must be set together" >&2
      exit 2
    fi
  fi
}

validate_override_pair caveman \
  "${AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE:-}" \
  "${AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256:-}"
validate_override_pair ponytail \
  "${AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE:-}" \
  "${AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256:-}"

HERMES_ROOT="${AGENT_DEV_KIT_HERMES_HOME:-${HERMES_HOME:-${HOME:?HOME is required}/.hermes}}"
CAVEMAN_SOURCE="${AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE:-https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.1/skills/caveman/SKILL.md}"
PONYTAIL_SOURCE="${AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE:-https://raw.githubusercontent.com/DietrichGebert/ponytail/v4.8.4/skills/ponytail/SKILL.md}"
CAVEMAN_SHA256="${AGENT_DEV_KIT_CAVEMAN_HERMES_SHA256:-5e30bb56afbd0b01bd736f2da84180e76f18db4a64de8e124525d5c8dc2e8605}"
PONYTAIL_SHA256="${AGENT_DEV_KIT_PONYTAIL_HERMES_SHA256:-d1ffcddbc486ab787d5797441e8b6e4717da3249c6786b83fc2abd2f12803c29}"

declare -a profiles=()
all_profiles=0

usage() {
  cat <<'EOF'
Usage: install-hermes-workhorse.sh [--profile NAME ...] [--all-profiles]

Installs pinned caveman and ponytail skills under the default Hermes skills
directory, then links them into the external/ category of selected profiles.
With no profile option, all existing profiles are updated.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      profiles+=("${2:?--profile requires a name}")
      shift 2
      ;;
    --all-profiles)
      all_profiles=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v hermes >/dev/null || {
  echo "hermes not on PATH" >&2
  exit 1
}
command -v node >/dev/null || {
  echo "node not on PATH" >&2
  exit 1
}

healthy_skill() {
  local path="$1" name="$2"
  [ -f "$path/SKILL.md" ] || return 1
  grep -q "^name:[[:space:]]*${name}[[:space:]]*$" "$path/SKILL.md"
}

file_sha256() {
  node --input-type=module -e \
    'import { createHash } from "node:crypto"; import { readFileSync } from "node:fs"; process.stdout.write(createHash("sha256").update(readFileSync(process.argv[1])).digest("hex"))' \
    "$1"
}

REFRESH_ACTIVE=0
REFRESH_TARGET_WAS_ABSENT=1
REFRESH_TARGET=""
REFRESH_BACKUP=""
WORKHORSE_LOCK_ACTIVE=0
WORKHORSE_LOCK="$HERMES_ROOT/skills/.agent-dev-kit-workhorse.lock"
EXIT_CLEANUP=0
LINKS_COMMITTED=0
SKILLS_COMMITTED=0
declare -a CREATED_PROFILE_LINKS=()
declare -a CREATED_PROFILE_LINK_SOURCES=()
declare -a UPDATED_SKILL_TARGETS=()
declare -a UPDATED_SKILL_BACKUPS=()
declare -a UPDATED_SKILL_WAS_ABSENT=()

restore_workhorse_signal_traps() {
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

rollback_managed_skill() {
  local target="$1" backup="$2" was_absent="$3" remove_error="$4"
  local absent_error="${5:-$remove_error}"
  if [ -n "$backup" ] && [ -e "$backup" ]; then
    if ! rm -rf "$target"; then
      echo "$remove_error: $target" >&2
      return 1
    fi
    if ! mv "$backup" "$target"; then
      echo "CRITICAL: unable to restore managed skill backup: $backup" >&2
      return 1
    fi
  elif [ "$was_absent" -eq 1 ] && ! rm -rf "$target"; then
    echo "$absent_error: $target" >&2
    return 1
  fi
}

reset_managed_skill_refresh() {
  REFRESH_ACTIVE=0
  REFRESH_TARGET_WAS_ABSENT=1
  REFRESH_TARGET=""
  REFRESH_BACKUP=""
}

clear_managed_skill_history() {
  UPDATED_SKILL_TARGETS=()
  UPDATED_SKILL_BACKUPS=()
  UPDATED_SKILL_WAS_ABSENT=()
}

cleanup_managed_skill_refresh() {
  local status="${1:-0}" index target backup was_absent
  trap '' HUP INT TERM
  if [ "$REFRESH_ACTIVE" -eq 1 ]; then
    rollback_managed_skill "$REFRESH_TARGET" "$REFRESH_BACKUP" \
      "$REFRESH_TARGET_WAS_ABSENT" "CRITICAL: unable to remove partial managed skill" || status=1
  fi
  if [ "$SKILLS_COMMITTED" -eq 0 ]; then
    for ((index=${#UPDATED_SKILL_TARGETS[@]} - 1; index >= 0; index--)); do
      target="${UPDATED_SKILL_TARGETS[$index]}"
      backup="${UPDATED_SKILL_BACKUPS[$index]}"
      was_absent="${UPDATED_SKILL_WAS_ABSENT[$index]}"
      rollback_managed_skill "$target" "$backup" "$was_absent" \
        "CRITICAL: unable to remove updated managed skill" \
        "CRITICAL: unable to roll back newly installed skill" || status=1
    done
  fi
  reset_managed_skill_refresh
  clear_managed_skill_history
  if [ "$EXIT_CLEANUP" -eq 0 ] && [ "$WORKHORSE_LOCK_ACTIVE" -eq 1 ]; then
    restore_workhorse_signal_traps
  fi
  return "$status"
}

finish_managed_skill_refresh() {
  local changed="$1"
  trap '' HUP INT TERM
  if [ "$changed" -eq 1 ]; then
    UPDATED_SKILL_TARGETS+=("$REFRESH_TARGET")
    UPDATED_SKILL_BACKUPS+=("$REFRESH_BACKUP")
    UPDATED_SKILL_WAS_ABSENT+=("$REFRESH_TARGET_WAS_ABSENT")
  fi
  reset_managed_skill_refresh
  restore_workhorse_signal_traps
}

commit_managed_skill_refreshes() {
  local status=0 backup
  SKILLS_COMMITTED=1
  for backup in "${UPDATED_SKILL_BACKUPS[@]}"; do
    if [ -n "$backup" ] && ! rm -rf "$backup"; then
      echo "unable to remove committed skill backup: $backup" >&2
      status=1
    fi
  done
  clear_managed_skill_history
  return "$status"
}

cleanup_workhorse_lock() {
  local status="${1:-0}"
  if [ -L "$WORKHORSE_LOCK" ] && [ "$(readlink "$WORKHORSE_LOCK")" = "$$" ]; then
    if ! rm -f "$WORKHORSE_LOCK"; then
      echo "unable to remove workhorse installer lock: $WORKHORSE_LOCK" >&2
      status=1
    fi
    WORKHORSE_LOCK_ACTIVE=0
  elif [ "$WORKHORSE_LOCK_ACTIVE" -eq 1 ]; then
    echo "workhorse installer lock ownership changed unexpectedly: $WORKHORSE_LOCK" >&2
    status=1
  fi
  return "$status"
}

cleanup_profile_links() {
  local status="${1:-0}" index link source
  trap '' HUP INT TERM
  if [ "$LINKS_COMMITTED" -eq 0 ]; then
    for ((index=${#CREATED_PROFILE_LINKS[@]} - 1; index >= 0; index--)); do
      link="${CREATED_PROFILE_LINKS[$index]}"
      source="${CREATED_PROFILE_LINK_SOURCES[$index]}"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$source" ]; then
        if ! rm -f "$link"; then
          echo "unable to roll back profile skill link: $link" >&2
          status=1
        fi
      elif [ -e "$link" ] || [ -L "$link" ]; then
        echo "profile skill link changed during rollback: $link" >&2
        status=1
      fi
    done
  fi
  CREATED_PROFILE_LINKS=()
  CREATED_PROFILE_LINK_SOURCES=()
  if [ "$EXIT_CLEANUP" -eq 0 ] && [ "$WORKHORSE_LOCK_ACTIVE" -eq 1 ]; then
    restore_workhorse_signal_traps
  fi
  return "$status"
}

workhorse_install_exit() {
  local status=$?
  EXIT_CLEANUP=1
  trap - EXIT
  trap '' HUP INT TERM
  cleanup_profile_links "$status" || status=$?
  cleanup_managed_skill_refresh "$status" || status=$?
  cleanup_workhorse_lock "$status" || status=$?
  trap - HUP INT TERM
  exit "$status"
}

acquire_workhorse_lock() {
  if [ -L "$HERMES_ROOT/skills" ]; then
    echo "refusing symlinked Hermes global skills path: $HERMES_ROOT/skills" >&2
    exit 1
  fi
  mkdir -p "$HERMES_ROOT/skills"
  trap 'workhorse_install_exit' EXIT
  restore_workhorse_signal_traps
  if ! ln -s "$$" "$WORKHORSE_LOCK" 2>/dev/null; then
    trap - EXIT HUP INT TERM
    echo "refusing concurrent workhorse install; lock exists: $WORKHORSE_LOCK" >&2
    exit 1
  fi
  WORKHORSE_LOCK_ACTIVE=1
}

install_global_skill() {
  local name="$1" source="$2" expected_checksum="$3"
  local target="$HERMES_ROOT/skills/$name"
  local marker="$target/.agent-dev-kit-source"
  local checksum_marker="$target/.agent-dev-kit-sha256"
  local backup=""
  local skill_checksum=""

  [[ "$expected_checksum" =~ ^[0-9a-f]{64}$ ]] || {
    echo "invalid expected SHA-256 for $name" >&2
    exit 2
  }

  REFRESH_ACTIVE=1
  REFRESH_TARGET="$target"
  REFRESH_BACKUP=""
  REFRESH_TARGET_WAS_ABSENT=1

  if healthy_skill "$target" "$name" && [ -f "$marker" ] && [ ! -L "$marker" ] && \
     [ "$(cat "$marker")" = "$source" ] && [ -f "$checksum_marker" ] && \
     [ ! -L "$checksum_marker" ]; then
    skill_checksum="$(file_sha256 "$target/SKILL.md")"
    if [ "$(cat "$checksum_marker")" = "$skill_checksum" ] &&
       [ "$skill_checksum" = "$expected_checksum" ]; then
      finish_managed_skill_refresh 0
      return 0
    fi
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    REFRESH_TARGET_WAS_ABSENT=0
    [ ! -L "$target" ] || {
      echo "refusing to replace symlinked global skill: $target" >&2
      exit 1
    }
    [ -f "$marker" ] && [ ! -L "$marker" ] || {
      echo "refusing to overwrite unmanaged global skill: $target" >&2
      exit 1
    }
    backup="$(mktemp -d "$HERMES_ROOT/skills/.${name}.backup.XXXXXX")"
    rmdir "$backup"
    REFRESH_BACKUP="$backup"
    mv "$target" "$backup"
  fi

  # Hermes may have a sticky active profile. Explicitly selecting `default`
  # keeps the canonical copy under HERMES_ROOT/skills instead of that profile.
  if ! HERMES_HOME="$HERMES_ROOT" hermes --profile default skills install "$source" --yes; then
    echo "Hermes failed to install $name from its pinned source" >&2
    exit 1
  fi
  if ! healthy_skill "$target" "$name"; then
    echo "Hermes installed an invalid or missing $name skill at $target" >&2
    exit 1
  fi
  skill_checksum="$(file_sha256 "$target/SKILL.md")"
  if [ "$skill_checksum" != "$expected_checksum" ]; then
    echo "SHA-256 mismatch for $name from its pinned source" >&2
    exit 1
  fi
  if ! printf '%s\n' "$source" > "$marker" ||
     ! printf '%s\n' "$skill_checksum" > "$checksum_marker"; then
    echo "unable to record managed metadata for $name" >&2
    exit 1
  fi
  finish_managed_skill_refresh 1
}

link_profile_skill() {
  local profile="$1" name="$2"
  local source="$HERMES_ROOT/skills/$name"
  local target_dir="$HERMES_ROOT/profiles/$profile/skills/external"
  local target="$target_dir/$name"

  [[ "$profile" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    echo "invalid Hermes profile name: $profile" >&2
    exit 2
  }
  [ -d "$HERMES_ROOT/profiles/$profile" ] && [ ! -L "$HERMES_ROOT/profiles/$profile" ] || {
    echo "Hermes profile does not exist: $profile" >&2
    exit 1
  }

  [ ! -L "$HERMES_ROOT/profiles" ] && [ ! -L "$HERMES_ROOT/profiles/$profile/skills" ] &&
    [ ! -L "$target_dir" ] || {
    echo "refusing symlinked Hermes profile path: $target_dir" >&2
    exit 1
  }
  mkdir -p "$target_dir"
  if [ -L "$target" ]; then
    if [ "$(readlink -f "$target" 2>/dev/null || true)" = "$(readlink -f "$source")" ]; then
      return
    fi
    echo "refusing to replace foreign skill link: $target" >&2
    exit 1
  fi
  if [ -e "$target" ]; then
    echo "refusing to overwrite unmanaged skill directory: $target" >&2
    exit 1
  fi
  trap '' HUP INT TERM
  if ! ln -s "$source" "$target"; then
    restore_workhorse_signal_traps
    echo "unable to create profile skill link: $target" >&2
    exit 1
  fi
  CREATED_PROFILE_LINKS+=("$target")
  CREATED_PROFILE_LINK_SOURCES+=("$source")
  restore_workhorse_signal_traps
}

acquire_workhorse_lock
install_global_skill caveman "$CAVEMAN_SOURCE" "$CAVEMAN_SHA256"
install_global_skill ponytail "$PONYTAIL_SOURCE" "$PONYTAIL_SHA256"

if [ "$all_profiles" -eq 1 ] || [ "${#profiles[@]}" -eq 0 ]; then
  if [ -d "$HERMES_ROOT/profiles" ]; then
    for profile_dir in "$HERMES_ROOT"/profiles/*/; do
      [ -d "$profile_dir" ] || continue
      [ ! -L "${profile_dir%/}" ] || {
        echo "refusing symlinked Hermes profile: ${profile_dir%/}" >&2
        exit 1
      }
      profiles+=("$(basename "$profile_dir")")
    done
  fi
fi

declare -a linked_profiles=()
for profile in "${profiles[@]}"; do
  case " ${linked_profiles[*]} " in
    *" $profile "*) continue ;;
  esac
  for skill in caveman ponytail; do
    link_profile_skill "$profile" "$skill"
  done
  linked_profiles+=("$profile")
done

trap '' HUP INT TERM
LINKS_COMMITTED=1
commit_managed_skill_refreshes
cleanup_workhorse_lock 0
trap - EXIT HUP INT TERM
printf 'Hermes workhorse ready: caveman + ponytail (%d profiles)\n' "${#linked_profiles[@]}"
