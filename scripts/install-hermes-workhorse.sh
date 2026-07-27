#!/usr/bin/env bash
# Install the pinned caveman + ponytail baseline for Hermes and expose it to profiles.
set -euo pipefail

HERMES_ROOT="${AGENT_DEV_KIT_HERMES_HOME:-${HERMES_HOME:-${HOME:?HOME is required}/.hermes}}"
CAVEMAN_SOURCE="${AGENT_DEV_KIT_CAVEMAN_HERMES_SOURCE:-https://raw.githubusercontent.com/JuliusBrussee/caveman/v1.9.1/skills/caveman/SKILL.md}"
PONYTAIL_SOURCE="${AGENT_DEV_KIT_PONYTAIL_HERMES_SOURCE:-https://raw.githubusercontent.com/DietrichGebert/ponytail/v4.8.4/skills/ponytail/SKILL.md}"

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

healthy_skill() {
  local path="$1" name="$2"
  [ -f "$path/SKILL.md" ] || return 1
  grep -q "^name:[[:space:]]*$name[[:space:]]*$" "$path/SKILL.md"
}

install_global_skill() {
  local name="$1" source="$2"
  local target="$HERMES_ROOT/skills/$name"
  local marker="$target/.agent-dev-kit-source"
  local backup=""

  if healthy_skill "$target" "$name" && [ -f "$marker" ] && [ ! -L "$marker" ] && \
     [ "$(cat "$marker")" = "$source" ]; then
    return
  fi

  mkdir -p "$HERMES_ROOT/skills"
  if [ -e "$target" ] || [ -L "$target" ]; then
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
    mv "$target" "$backup"
  fi

  # Hermes may have a sticky active profile. Explicitly selecting `default`
  # keeps the canonical copy under HERMES_ROOT/skills instead of that profile.
  if ! HERMES_HOME="$HERMES_ROOT" hermes --profile default skills install "$source" --yes; then
    rm -rf "$target"
    [ -z "$backup" ] || mv "$backup" "$target"
    echo "Hermes failed to install $name from its pinned source" >&2
    exit 1
  fi
  if ! healthy_skill "$target" "$name"; then
    rm -rf "$target"
    [ -z "$backup" ] || mv "$backup" "$target"
    echo "Hermes installed an invalid or missing $name skill at $target" >&2
    exit 1
  fi
  if ! printf '%s\n' "$source" > "$marker"; then
    rm -rf "$target"
    [ -z "$backup" ] || mv "$backup" "$target"
    echo "unable to record managed source for $name" >&2
    exit 1
  fi
  [ -z "$backup" ] || rm -rf "$backup"
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
  [ -d "$HERMES_ROOT/profiles/$profile" ] || {
    echo "Hermes profile does not exist: $profile" >&2
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
  ln -s "$source" "$target"
}

install_global_skill caveman "$CAVEMAN_SOURCE"
install_global_skill ponytail "$PONYTAIL_SOURCE"

if [ "$all_profiles" -eq 1 ] || [ "${#profiles[@]}" -eq 0 ]; then
  if [ -d "$HERMES_ROOT/profiles" ]; then
    for profile_dir in "$HERMES_ROOT"/profiles/*/; do
      [ -d "$profile_dir" ] || continue
      profiles+=("$(basename "$profile_dir")")
    done
  fi
fi

declare -a linked_profiles=()
for profile in "${profiles[@]}"; do
  case " ${linked_profiles[*]} " in
    *" $profile "*) continue ;;
  esac
  link_profile_skill "$profile" caveman
  link_profile_skill "$profile" ponytail
  linked_profiles+=("$profile")
done

printf 'Hermes workhorse ready: caveman + ponytail (%d profiles)\n' "${#linked_profiles[@]}"
