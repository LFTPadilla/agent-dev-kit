#!/usr/bin/env bash
# tutor-install.sh — install the Hermes Workflow Tutor profile from the
# agent-dev-kit repo into ~/.hermes/profiles/hermes-tutor.
#
# Idempotent: re-running upgrades skills and re-asserts config, but does
# NOT delete lanes.json or state/preflight-*.yaml.
#
# Usage:
#   tutor-install                       # install for current user
#   tutor-install --source <repo-dir>   # install from a local checkout
set -uo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
HERMES_DIR=""
dir="$(dirname "$SELF_PATH")"
while [ "$dir" != "/" ]; do
  if [ "$(basename "$dir")" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  dir="$(dirname "$dir")"
done
if [ -n "$HERMES_DIR" ]; then USER_HOME="$(dirname "$HERMES_DIR")"
else USER_HOME="/home/felipe"; fi
[ -d "$USER_HOME" ] || USER_HOME="/home/felipe"

PROFILE="hermes-tutor"
SESSION="${HERMES_TUTOR_SESSION:-komp}"
SOURCE=""
WRAPPER_DEST="$USER_HOME/.local/bin/hermes-tutor"

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default source: this script lives next to the agent-dev-kit repo's profiles/
# and skills/. If --source is given, use that as the repo root.
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$SOURCE" ]; then
  SOURCE="$(cd "$script_dir/.." && pwd)"
fi

[ -f "$SOURCE/profiles/hermes-tutor.yml" ] || {
  echo "missing $SOURCE/profiles/hermes-tutor.yml"
  exit 1
}
[ -f "$SOURCE/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md" ] || {
  echo "missing $SOURCE/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md"
  exit 1
}

echo "[1/6] hermes binary"
command -v hermes >/dev/null || {
  echo "hermes not on PATH. Install from https://hermes-agent.nousresearch.com/docs/"
  exit 1
}

echo "[2/6] profile '$PROFILE'"
if ! hermes profile show "$PROFILE" >/dev/null 2>&1; then
  # Try cloning from a sensible source profile. Default tries the installer's
  # 'kommit' profile (the convention on a typical Hermes install), then
  # 'default', then creates a blank one.
  if hermes profile show kommit >/dev/null 2>&1; then
    hermes profile create "$PROFILE" --clone-from kommit 2>/dev/null \
      || hermes profile create "$PROFILE"
  elif hermes profile show default >/dev/null 2>&1; then
    hermes profile create "$PROFILE" --clone-from default 2>/dev/null \
      || hermes profile create "$PROFILE"
  else
    hermes profile create "$PROFILE"
  fi
fi

echo "[3/6] model config (MiniMax-M3, anthropic-compatible)"
hermes --profile "$PROFILE" config set model.default      MiniMax-M3
hermes --profile "$PROFILE" config set model.provider    minimax
hermes --profile "$PROFILE" config set model.base_url    https://api.minimax.io/anthropic
hermes --profile "$PROFILE" config set model.api_mode    anthropic_messages
hermes --profile "$PROFILE" config set fallback_providers '[]'

# Sandbox hardening (#6)
echo "[4/6] sandbox hardening"
hermes --profile "$PROFILE" config set security.redact_secrets true
hermes --profile "$PROFILE" config set approvals.mode smart

# Symlink skills
echo "[5/6] skills"
PROFILE_SKILLS="$USER_HOME/.hermes/profiles/$PROFILE/skills"
mkdir -p "$PROFILE_SKILLS"

# Orchestrator skill (copy so updates via tutor-update refresh it)
mkdir -p "$PROFILE_SKILLS/software-development"
cp -f "$SOURCE/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md" \
      "$PROFILE_SKILLS/software-development/ai-workflow-orchestrator/SKILL.md"

# Worklog: symlink to kommit if it exists, otherwise copy
if [ -d "$USER_HOME/.hermes/profiles/kommit/skills/worklog" ]; then
  [ -L "$PROFILE_SKILLS/worklog" ] || [ -e "$PROFILE_SKILLS/worklog" ] && \
    rm -rf "$PROFILE_SKILLS/worklog"
  ln -s "$USER_HOME/.hermes/profiles/kommit/skills/worklog" "$PROFILE_SKILLS/worklog"
  echo "  worklog -> kommit/skills/worklog (symlink)"
fi

# Runtime scripts and template (always copy — they are runtime-owned)
echo "[6/6] runtime helpers"
mkdir -p "$PROFILE_SKILLS/../scripts" "$PROFILE_SKILLS/../templates" \
         "$PROFILE_SKILLS/../state"
[ -d "$SOURCE/scripts" ] && \
  cp -rn "$SOURCE/scripts/tutor-"*.sh "$PROFILE_SKILLS/../scripts/" 2>/dev/null || true
[ -f "$SOURCE/templates/lane-prompt.md" ] && \
  cp -f "$SOURCE/templates/lane-prompt.md" "$PROFILE_SKILLS/../templates/"

# Wrapper
mkdir -p "$(dirname "$WRAPPER_DEST")"
cat > "$WRAPPER_DEST" <<EOF
#!/usr/bin/env bash
exec hermes --profile $PROFILE "\$@"
EOF
chmod +x "$WRAPPER_DEST"

# Symlinks for the other helpers into ~/.local/bin
for s in tutor-smoke tutor-status tutor-preflight tutor-audit \
         tutor-delegate tutor-log-suggest tutor-lane-update tutor-bootstrap; do
  src="$PROFILE_SKILLS/../scripts/$s.sh"
  dest="$USER_HOME/.local/bin/$s"
  if [ -f "$src" ]; then
    ln -sf "$src" "$dest"
    chmod +x "$src"
  fi
done

# Final: bootstrap (verify + auto-repair skills) so the profile is ready
echo
echo "[7/7] bootstrap skills"
"$dest" tutor-bootstrap 2>&1 | tail -8

echo
echo "installed. Run smoke check:"
echo "  $WRAPPER_DEST tutor-smoke"