#!/usr/bin/env bash
# Install or refresh the Personal Dev Tutor Hermes profile and Codex integration.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

SOURCE=""
SESSION="$PERSONAL_TUTOR_SESSION"
PROFILE="$PERSONAL_TUTOR_PROFILE"
MODEL="${PERSONAL_TUTOR_MODEL:-gpt-5.6-sol}"
PROVIDER="${PERSONAL_TUTOR_PROVIDER:-openai-codex}"

usage() {
  cat <<'EOF'
Usage: personal-tutor-install.sh [--source <agent-dev-kit>] [--session <tmux-session>] [--profile <name>] [--provider <name> --model <name>]

Creates a blank Hermes profile, installs the Personal Tutor capability set into
Hermes, installs a filtered implementation/review skill set into an isolated
Codex home, installs the pinned upstream Graphify skill for both runtimes, configures
Context7, and applies safe defaults.
It never clones another profile or copies credentials. The orchestrator defaults
to openai-codex/gpt-5.6-sol; both values are configurable with flags or env vars.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:?--source requires a path}"; shift 2 ;;
    --session) SESSION="${2:?--session requires a value}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile requires a value}"; shift 2 ;;
    --model) MODEL="${2:?--model requires a value}"; shift 2 ;;
    --provider) PROVIDER="${2:?--provider requires a value}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1"; usage; exit 2 ;;
  esac
done
[ -n "$MODEL" ] && [ -n "$PROVIDER" ] || { echo "model and provider must both be non-empty"; exit 2; }
[[ "$PROFILE" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "invalid profile name: $PROFILE"; exit 2; }
[[ "$SESSION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "invalid tmux session name: $SESSION"; exit 2; }

if [ -z "$SOURCE" ]; then
  if [ -f "$SCRIPT_DIR/../profiles/personal-dev-tutor.yml" ]; then
    SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
  elif [ -f "$PERSONAL_TUTOR_PROFILE_DIR/state/source-root" ]; then
    SOURCE="$(cat "$PERSONAL_TUTOR_PROFILE_DIR/state/source-root")"
  else
    echo "unable to locate agent-dev-kit; pass --source <path>"
    exit 2
  fi
fi
SOURCE="$(cd "$SOURCE" && pwd)"
PROFILE_DIR="$PERSONAL_TUTOR_USER_HOME/.hermes/profiles/$PROFILE"
PROFILE_SKILLS="$PROFILE_DIR/skills/agent-dev-kit"
CODEX_USER_HOME="$PROFILE_DIR/codex-user"
CODEX_HOME="$CODEX_USER_HOME/.codex"
CODEX_SKILLS="$CODEX_HOME/skills"

for command in hermes git tmux python3 codex sort d2 mmdc gsd-sdk; do
  command -v "$command" >/dev/null || { echo "missing required command: $command"; exit 1; }
done
for file in \
  "$SOURCE/profiles/personal-dev-tutor.yml" \
  "$SOURCE/templates/personal-dev-tutor-SOUL.md" \
  "$SOURCE/templates/personal-codex-lane-prompt.md" \
  "$SOURCE/plugins/dev-skills/skills/personal-development-mentor/SKILL.md" \
  "$SOURCE/scripts/install-hermes-workhorse.sh"; do
  [ -f "$file" ] || { echo "missing source artifact: $file"; exit 1; }
done
GSD_SKILLS="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/gsd"
GSD_RUNTIME="$PERSONAL_TUTOR_USER_HOME/.hermes/get-shit-done"
if [ ! -d "$GSD_SKILLS" ] || [ ! -d "$GSD_RUNTIME" ]; then
  echo "GSD for Hermes is not installed in the real user home."
  echo "Install it first: npm i -g get-shit-done-cc && HOME=$PERSONAL_TUTOR_USER_HOME get-shit-done-cc --hermes --global"
  exit 1
fi
for gsd_skill in "${PERSONAL_TUTOR_GSD_SKILLS[@]}"; do
  [ -f "$GSD_SKILLS/$gsd_skill/SKILL.md" ] || { echo "missing GSD core skill: $gsd_skill"; exit 1; }
done
if ! command -v graphify >/dev/null 2>&1; then
  command -v uv >/dev/null || {
    echo "missing graphify and uv; install uv, then run: uv tool install graphifyy==$PERSONAL_TUTOR_GRAPHIFY_VERSION"
    exit 1
  }
  printf 'Installing pinned Graphify %s from the upstream graphifyy package\n' "$PERSONAL_TUTOR_GRAPHIFY_VERSION"
  HOME="$PERSONAL_TUTOR_USER_HOME" uv tool install "graphifyy==$PERSONAL_TUTOR_GRAPHIFY_VERSION"
fi
graphify_version="$(personal_tutor_graphify --version 2>/dev/null | awk '{print $2; exit}')"
if [ "$graphify_version" != "$PERSONAL_TUTOR_GRAPHIFY_VERSION" ]; then
  echo "Graphify $PERSONAL_TUTOR_GRAPHIFY_VERSION is required (found: ${graphify_version:-unknown})."
  echo "Install the reviewed release with: HOME=$PERSONAL_TUTOR_USER_HOME uv tool install graphifyy==$PERSONAL_TUTOR_GRAPHIFY_VERSION --force"
  exit 1
fi

printf '[1/8] Hermes profile: %s\n' "$PROFILE"
if hermes profile show "$PROFILE" >/dev/null 2>&1; then
  if [ ! -f "$PROFILE_DIR/state/source-root" ]; then
    echo "refusing to overwrite an unmanaged existing profile: $PROFILE"
    exit 1
  fi
  managed_source="$(cat "$PROFILE_DIR/state/source-root")"
  if [ ! -d "$managed_source" ] || [ "$(cd "$managed_source" && pwd)" != "$SOURCE" ]; then
    echo "refusing to refresh profile managed by another source: $PROFILE"
    exit 1
  fi
else
  hermes profile create "$PROFILE" \
    --no-skills \
    --description "GSD-led personal development tutor that delegates implementation to Codex and verifies understanding." \
    >/dev/null
fi
mkdir -p "$PROFILE_DIR/state"
printf '%s\n' "$SOURCE" > "$PROFILE_DIR/state/source-root"
hermes --profile "$PROFILE" skills opt-out --remove --yes >/dev/null
for category in "$PROFILE_DIR/skills"/*; do
  [ -d "$category" ] && rmdir "$category" 2>/dev/null || true
done

printf '[2/8] Safe profile configuration and Context7\n'
hermes --profile "$PROFILE" config set terminal.home_mode real >/dev/null
hermes --profile "$PROFILE" config set approvals.mode smart >/dev/null
hermes --profile "$PROFILE" config set security.redact_secrets true >/dev/null
hermes --profile "$PROFILE" config set security.tirith_enabled true >/dev/null
hermes --profile "$PROFILE" config set checkpoints.enabled true >/dev/null
hermes --profile "$PROFILE" config set display.language en >/dev/null
hermes --profile "$PROFILE" config set display.personality teacher >/dev/null
for toolset in terminal file skills todo session_search delegation clarify web browser; do
  hermes --profile "$PROFILE" tools enable "$toolset" >/dev/null 2>&1 || \
    printf '  warning: could not enable toolset %s automatically\n' "$toolset"
done

hermes --profile "$PROFILE" config set model.default "$MODEL" >/dev/null
hermes --profile "$PROFILE" config set model.provider "$PROVIDER" >/dev/null
hermes --profile "$PROFILE" config set mcp_servers.context7.url "$PERSONAL_TUTOR_CONTEXT7_URL" >/dev/null
hermes --profile "$PROFILE" config set mcp_servers.context7.connect_timeout 60 >/dev/null
hermes --profile "$PROFILE" config set mcp_servers.context7.enabled true >/dev/null

mkdir -p "$CODEX_HOME"
chmod 700 "$CODEX_USER_HOME" "$CODEX_HOME"
if codex_context7="$(CODEX_HOME="$CODEX_HOME" codex mcp get context7 2>/dev/null)"; then
  codex_context7_url="$(printf '%s\n' "$codex_context7" | awk '/^[[:space:]]*url:/ {print $2; exit}')"
  [ "$codex_context7_url" = "$PERSONAL_TUTOR_CONTEXT7_URL" ] || {
    echo "refusing to overwrite the isolated Codex Context7 endpoint"
    exit 1
  }
else
  # `codex mcp add` starts an interactive OAuth flow. Write only the public,
  # profile-owned endpoint so installation is non-interactive and secret-free.
  [ ! -f "$CODEX_HOME/config.toml" ] || {
    echo "isolated Codex config exists without Context7; refusing to overwrite it"
    exit 1
  }
  cat > "$CODEX_HOME/config.toml" <<EOF
[mcp_servers.context7]
url = "$PERSONAL_TUTOR_CONTEXT7_URL"
EOF
  chmod 600 "$CODEX_HOME/config.toml"
  printf '  Context7 registered in the isolated Codex home. Authenticate later with: personal-tutor-codex mcp login context7\n'
fi

printf '[3/8] Profile contract and persona\n'
mkdir -p "$PROFILE_DIR/templates" "$PROFILE_DIR/scripts"
cp -f "$SOURCE/templates/personal-dev-tutor-SOUL.md" "$PROFILE_DIR/SOUL.md"
cp -f "$SOURCE/templates/personal-codex-lane-prompt.md" "$PROFILE_DIR/templates/"
cp -f "$SOURCE/profiles/personal-dev-tutor.yml" "$PROFILE_DIR/personal-dev-tutor.yml"
python3 - "$PROFILE_DIR/personal-dev-tutor.yml" "$PROFILE" "$SESSION" "$PERSONAL_TUTOR_USER_HOME" <<'PY'
from pathlib import Path
import sys

path, profile, session, home = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
text = path.read_text()
text = text.replace("profile: personal-dev-tutor", f"profile: {profile}", 1)
text = text.replace("~/.hermes/profiles/personal-dev-tutor/skills", f"{home}/.hermes/profiles/{profile}/skills", 1)
text = text.replace("delegate_session: personal", f"delegate_session: {session}", 1)
path.write_text(text)
PY
python3 - "$PROFILE_DIR/SOUL.md" "$SESSION" <<'PY'
from pathlib import Path
import sys

path, session = Path(sys.argv[1]), sys.argv[2]
path.write_text(path.read_text().replace("personal:*", f"{session}:*"))
PY

link_skill() {
  local source="$1" target="$2"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf '  preserve unmanaged skill directory: %s\n' "$target"
    return
  fi
  ln -sfn "$source" "$target"
}

managed_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

remove_source_link() {
  local target="$1" source_root="$2" resolved
  if [ -L "$target" ]; then
    resolved="$(readlink -f "$target")"
    case "$resolved" in "$source_root"/*) rm "$target" ;; esac
  fi
}

remove_symlink_entries() {
  local directory="$1" prefix="${2:-}" entry
  for entry in "$directory"/"$prefix"*; do
    [ -L "$entry" ] && rm "$entry"
  done
}

remove_managed_source_links() {
  local state_file="$1" source_root="$2" label="$3" name target_root
  shift 3
  [ -f "$state_file" ] || return 0
  while IFS= read -r name; do
    managed_name "$name" || { echo "invalid managed $label state entry"; exit 1; }
    for target_root in "$@"; do
      remove_source_link "$target_root/$name" "$source_root"
    done
  done < "$state_file"
}

printf '[4/8] Personal Tutor and GSD skills\n'
mkdir -p "$PROFILE_SKILLS" "$CODEX_SKILLS"
remove_symlink_entries "$PROFILE_SKILLS"

CODEX_MANAGED_STATE="$PROFILE_DIR/state/codex-skill-links"
if [ -f "$CODEX_MANAGED_STATE" ]; then
  # Migrate links made by the earlier global-home installer only if the link
  # still resolves into this exact source tree.
  remove_managed_source_links "$CODEX_MANAGED_STATE" \
    "$SOURCE/plugins/dev-skills/skills" "Codex skill" \
    "$PERSONAL_TUTOR_USER_HOME/.codex/skills" "$CODEX_SKILLS"
else
  # Migration from the first installer release: remove only links that resolve
  # into this source tree, then rebuild the filtered worker set.
  for skill in "$SOURCE"/plugins/dev-skills/skills/*/; do
    remove_source_link "$PERSONAL_TUTOR_USER_HOME/.codex/skills/$(basename "$skill")" \
      "$SOURCE/plugins/dev-skills/skills"
  done
fi
: > "$CODEX_MANAGED_STATE"

for skill in "$SOURCE"/plugins/dev-skills/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  if personal_tutor_array_contains "$name" "${PERSONAL_TUTOR_HERMES_SKILLS[@]}"; then
    link_skill "${skill%/}" "$PROFILE_SKILLS/$name"
  fi
  if personal_tutor_array_contains "$name" "${PERSONAL_TUTOR_CODEX_SKILLS[@]}"; then
    link_skill "${skill%/}" "$CODEX_SKILLS/$name"
    printf '%s\n' "$name" >> "$CODEX_MANAGED_STATE"
  fi
done

GSD_PROFILE_SKILLS="$PROFILE_DIR/skills/gsd"
if [ -L "$GSD_PROFILE_SKILLS" ]; then rm "$GSD_PROFILE_SKILLS"; fi
mkdir -p "$GSD_PROFILE_SKILLS"
remove_symlink_entries "$GSD_PROFILE_SKILLS" gsd-
for gsd_skill in "${PERSONAL_TUTOR_GSD_SKILLS[@]}"; do
  link_skill "$GSD_SKILLS/$gsd_skill" "$GSD_PROFILE_SKILLS/$gsd_skill"
done

printf '[5/8] External Graphify skill\n'
personal_tutor_graphify install --platform hermes >/dev/null
(cd "$CODEX_USER_HOME" && HOME="$CODEX_USER_HOME" command graphify install --platform codex >/dev/null)
GRAPHIFY_HERMES_SKILL="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/graphify"
GRAPHIFY_CODEX_SKILL="$CODEX_SKILLS/graphify"
[ -f "$GRAPHIFY_HERMES_SKILL/SKILL.md" ] || { echo "Graphify Hermes skill installation failed"; exit 1; }
[ -f "$GRAPHIFY_CODEX_SKILL/SKILL.md" ] || { echo "Graphify Codex skill installation failed"; exit 1; }
GRAPHIFY_PROFILE_SKILLS="$PROFILE_DIR/skills/external"
mkdir -p "$GRAPHIFY_PROFILE_SKILLS"
remove_symlink_entries "$GRAPHIFY_PROFILE_SKILLS"
link_skill "$GRAPHIFY_HERMES_SKILL" "$GRAPHIFY_PROFILE_SKILLS/graphify"
AGENT_DEV_KIT_HERMES_HOME="$PERSONAL_TUTOR_USER_HOME/.hermes" \
  "$SOURCE/scripts/install-hermes-workhorse.sh" --profile "$PROFILE"

printf '[6/8] Isolated Codex worker home\n'
CODEX_AGENT_STATE="$PROFILE_DIR/state/codex-agent-links"
remove_managed_source_links "$CODEX_AGENT_STATE" \
  "$SOURCE/plugins/dev-skills/skills/orchestrate/assets/codex-agents" "Codex agent" \
  "$PERSONAL_TUTOR_USER_HOME/.codex/agents"
rm -f "$CODEX_AGENT_STATE"
printf '  Codex home: %s\n' "$CODEX_HOME"

printf '[7/8] Runtime helpers and launchers\n'
rm -f "$PROFILE_DIR/scripts/render-diagrams.sh"
cp -f "$SOURCE"/scripts/personal-tutor-*.sh "$PROFILE_DIR/scripts/"
chmod +x "$PROFILE_DIR/scripts/"*.sh
mkdir -p "$PERSONAL_TUTOR_USER_HOME/.local/bin"
write_runtime_launcher() {
  local path="$1" runtime="$2"
  python3 - "$path" "$PERSONAL_TUTOR_USER_HOME" "$PROFILE" "$SESSION" "$CODEX_HOME" "$runtime" <<'PY'
from pathlib import Path
import shlex
import sys

path, home, profile, session, codex_home, runtime = Path(sys.argv[1]), *sys.argv[2:]
lines = [
    "#!/usr/bin/env bash",
    f'export PATH={shlex.quote(home + "/.nix-profile/bin:" + home + "/.local/bin:")}"$PATH"',
]
if runtime == "hermes":
    lines.extend([
        '[ -S "/run/user/$(id -u)/tmux-$(id -u)/default" ] && export TMUX_TMPDIR="/run/user/$(id -u)"',
        f"export PERSONAL_TUTOR_PROFILE={shlex.quote(profile)}",
        f"export PERSONAL_TUTOR_SESSION={shlex.quote(session)}",
        f'exec hermes --profile {shlex.quote(profile)} "$@"',
    ])
elif runtime == "codex":
    lines.extend([
        f"export CODEX_HOME={shlex.quote(codex_home)}",
        f"export PERSONAL_TUTOR_PROFILE={shlex.quote(profile)}",
        f"export PERSONAL_TUTOR_SESSION={shlex.quote(session)}",
        'if [ -n "${TMUX_PANE:-}" ]; then',
        '  tmux set-option -p -t "$TMUX_PANE" @personal_tutor_codex_home "$CODEX_HOME"',
        "fi",
        'exec codex "$@"',
    ])
else:
    raise SystemExit(f"unsupported launcher runtime: {runtime}")
path.write_text("\n".join(lines) + "\n")
PY
  chmod +x "$path"
}

write_runtime_launcher "$PERSONAL_TUTOR_USER_HOME/.local/bin/$PROFILE" hermes
write_runtime_launcher "$PERSONAL_TUTOR_USER_HOME/.local/bin/personal-tutor-codex" codex
for helper in doctor status delegate audit graph output sandbox install; do
  helper_target="$PERSONAL_TUTOR_USER_HOME/.local/bin/personal-tutor-$helper"
  if [ -e "$helper_target" ] || [ -L "$helper_target" ]; then
    if [ ! -L "$helper_target" ]; then
      echo "refusing to overwrite unmanaged command: $helper_target"
      exit 1
    fi
    helper_resolved="$(readlink -f "$helper_target" 2>/dev/null || true)"
    case "$helper_resolved" in
      "$PROFILE_DIR"/scripts/personal-tutor-*.sh) ;;
      *) echo "refusing to replace foreign command link: $helper_target"; exit 1 ;;
    esac
  fi
  ln -sfn "$PROFILE_DIR/scripts/personal-tutor-$helper.sh" "$helper_target"
done

printf '[8/8] Readiness check\n'
PERSONAL_TUTOR_PROFILE="$PROFILE" PERSONAL_TUTOR_SESSION="$SESSION" \
  "$PROFILE_DIR/scripts/personal-tutor-doctor.sh" --source "$SOURCE" --repo "$SOURCE"
