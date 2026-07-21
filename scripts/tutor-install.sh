#!/usr/bin/env bash
# tutor-install.sh — install the Agent Tutor Orchestrator profile from the
# agent-dev-kit repo into ~/.hermes/profiles/agent-tutor-orchestrator.
#
# Idempotent: re-running upgrades skills and re-asserts config, but does
# NOT delete lanes.json or state/preflight-*.yaml.
#
# Usage:
#   tutor-install                       # install for current user
#   tutor-install --source <repo-dir>   # install from a local checkout
# After install, run: tutor-doctor
set -uo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
# Resolve to an absolute directory so relative invocations (bash scripts/…)
# cannot spin forever on dirname(".") → ".".
HERMES_DIR=""
dir="$(cd "$(dirname "$SELF_PATH")" && pwd)"
while [ "$dir" != "/" ]; do
  if [ "$(basename "$dir")" = ".hermes" ]; then HERMES_DIR="$dir"; break; fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
if [ -n "$HERMES_DIR" ]; then USER_HOME="$(dirname "$HERMES_DIR")"
else USER_HOME="${HOME:-/home/felipe}"; fi
[ -d "$USER_HOME" ] || USER_HOME="${HOME:-/home/felipe}"

PROFILE="agent-tutor-orchestrator"
SESSION="${AGENT_TUTOR_SESSION:-tutor}"
CLONE_FROM="${AGENT_TUTOR_CLONE_FROM:-}"
SOURCE=""
WRAPPER_DEST="$USER_HOME/.local/bin/agent-tutor-orchestrator"
WORKLOG_DIR="${AGENT_TUTOR_WORKLOG_DIR:-$USER_HOME/.hermes/profiles/$PROFILE/worklogs}"

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --clone-from) CLONE_FROM="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default source: this script lives next to the agent-dev-kit repo's profiles/
# and skills/. If --source is given, use that as the repo root.
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$SOURCE" ]; then
  SOURCE="$(cd "$script_dir/.." && pwd)"
fi

[ -f "$SOURCE/profiles/agent-tutor-orchestrator.yml" ] || {
  echo "missing $SOURCE/profiles/agent-tutor-orchestrator.yml"
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
  # Clone only when the operator opts in via AGENT_TUTOR_CLONE_FROM or
  # --clone-from. Otherwise create a blank profile (no employer default).
  if [ -n "$CLONE_FROM" ]; then
    hermes profile create "$PROFILE" --clone-from "$CLONE_FROM" 2>/dev/null \
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
mkdir -p "$PROFILE_SKILLS/software-development/ai-workflow-orchestrator"
cp -f "$SOURCE/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md" \
      "$PROFILE_SKILLS/software-development/ai-workflow-orchestrator/SKILL.md"
if [ -f "$SOURCE/plugins/dev-skills/skills/orchestrate/SKILL.md" ]; then
  mkdir -p "$PROFILE_SKILLS/software-development/orchestrate"
  cp -f "$SOURCE/plugins/dev-skills/skills/orchestrate/SKILL.md" \
        "$PROFILE_SKILLS/software-development/orchestrate/SKILL.md"
fi
cp -f "$SOURCE/profiles/agent-tutor-orchestrator.yml" \
      "$USER_HOME/.hermes/profiles/$PROFILE/agent-tutor-orchestrator.yml"

# Worklog dir lives under the tutor profile by default (override with
# AGENT_TUTOR_WORKLOG_DIR). Worklog skill is repaired by tutor-bootstrap
# from global ~/.hermes/skills when present — no employer profile assumed.
mkdir -p "$WORKLOG_DIR"
echo "  worklog dir: $WORKLOG_DIR"

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
         tutor-delegate tutor-log-suggest tutor-lane-update tutor-bootstrap \
         tutor-doctor tutor-install; do
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
BOOTSTRAP="$USER_HOME/.local/bin/tutor-bootstrap"
[ -x "$BOOTSTRAP" ] || BOOTSTRAP="$PROFILE_SKILLS/../scripts/tutor-bootstrap.sh"
"$BOOTSTRAP" 2>&1 | tail -12

echo
echo "installed. Run doctor:"
echo "  $USER_HOME/.local/bin/tutor-doctor"
echo "  # or: $PROFILE_SKILLS/../scripts/tutor-doctor.sh"