#!/usr/bin/env bash
# Readiness check for the Personal Dev Tutor profile product.
set -uo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

SOURCE=""
REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --repo|--worktree) REPO="$2"; shift 2 ;;
    *) echo "unknown argument: $1"; exit 2 ;;
  esac
done
if [ -z "$SOURCE" ] && [ -f "$PERSONAL_TUTOR_PROFILE_DIR/state/source-root" ]; then
  SOURCE="$(cat "$PERSONAL_TUTOR_PROFILE_DIR/state/source-root")"
fi
if [ -z "$REPO" ]; then
  REPO="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -n "$REPO" ]; then REPO="$(cd "$REPO" && pwd)"; fi

pass=0 fail=0 warn=0
ok() { printf 'OK   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
warning() { printf 'WARN %s\n' "$1"; warn=$((warn + 1)); }
array_contains() {
  local needle="$1" value
  shift
  for value in "$@"; do
    [ "$value" = "$needle" ] && return 0
  done
  return 1
}

printf 'Personal Dev Tutor doctor\nProfile: %s\nSession: %s\nHome:    %s\n\n' \
  "$PERSONAL_TUTOR_PROFILE" "$PERSONAL_TUTOR_SESSION" "$PERSONAL_TUTOR_USER_HOME"
[ -n "$REPO" ] && printf 'Repository/worktree: %s\n\n' "$REPO"

for command in hermes codex tmux git python3 gsd-sdk d2 mmdc graphify sha256sum; do
  if command -v "$command" >/dev/null 2>&1; then ok "command available: $command"
  else bad "required command missing: $command"; fi
done
if command -v bwrap >/dev/null 2>&1; then
  ok "optional offline sandbox command available: bwrap"
else
  warn "optional offline sandbox unavailable; normal trusted-host development is unaffected"
fi

if hermes profile show "$PERSONAL_TUTOR_PROFILE" >/dev/null 2>&1; then
  ok "Hermes profile exists"
else
  bad "Hermes profile does not exist"
fi

CONFIG="$PERSONAL_TUTOR_PROFILE_DIR/config.yaml"
MANIFEST="$PERSONAL_TUTOR_PROFILE_DIR/personal-dev-tutor.yml"
SOUL="$PERSONAL_TUTOR_PROFILE_DIR/SOUL.md"
[ -f "$CONFIG" ] && ok "config.yaml present" || bad "config.yaml missing"
[ -f "$MANIFEST" ] && ok "installed profile manifest present" || bad "installed profile manifest missing"
[ -f "$SOUL" ] && ok "English tutor persona present" || bad "SOUL.md missing"
[ -f "$PERSONAL_TUTOR_PROFILE_DIR/.no-bundled-skills" ] && \
  ok "bundled skill seeding disabled" || bad "bundled skill seeding is not disabled"

if [ -f "$CONFIG" ] && grep -qiE 'home_mode:[[:space:]]*real' "$CONFIG"; then
  ok "terminal.home_mode is real"
else
  bad "terminal.home_mode must be real"
fi
if [ -f "$CONFIG" ] && grep -qiE 'redact_secrets:[[:space:]]*(true|yes)' "$CONFIG"; then
  ok "secret redaction enabled"
else
  bad "secret redaction is not enabled"
fi
context7_config="$(hermes --profile "$PERSONAL_TUTOR_PROFILE" config get mcp_servers.context7 2>/dev/null || true)"
if printf '%s\n' "$context7_config" | grep -Fq "url: $PERSONAL_TUTOR_CONTEXT7_URL" && \
   printf '%s\n' "$context7_config" | grep -qiE 'enabled:[[:space:]]*(true|yes)'; then
  ok "Context7 enabled for Hermes"
else
  bad "Context7 is not enabled at the expected Hermes endpoint"
fi
context7_test=""
for context7_attempt in 1 2; do
  context7_test="$(hermes --profile "$PERSONAL_TUTOR_PROFILE" mcp test context7 2>&1 || true)"
  if printf '%s\n' "$context7_test" | grep -q 'Tools discovered: 2'; then break; fi
  [ "$context7_attempt" -eq 1 ] && sleep 1
done
if printf '%s\n' "$context7_test" | grep -q 'Tools discovered: 2'; then
  ok "Hermes Context7 live discovery passes"
else
  bad "Hermes Context7 live discovery fails after 2 attempts"
fi
codex_context7="$(CODEX_HOME="$PERSONAL_TUTOR_CODEX_HOME" codex mcp get context7 2>/dev/null || true)"
if printf '%s\n' "$codex_context7" | grep -Fq "url: $PERSONAL_TUTOR_CONTEXT7_URL" && \
   printf '%s\n' "$codex_context7" | grep -qiE 'enabled:[[:space:]]*(true|yes)'; then
  ok "Context7 configured in the isolated Codex home"
else
  bad "Context7 is not configured at the expected isolated Codex endpoint"
fi
model_name="$(hermes --profile "$PERSONAL_TUTOR_PROFILE" config get model.default 2>/dev/null || true)"
model_provider="$(hermes --profile "$PERSONAL_TUTOR_PROFILE" config get model.provider 2>/dev/null || true)"
if [ -n "$model_name" ] && [ -n "$model_provider" ]; then
  ok "model routing configured: $model_provider/$model_name"
else
  bad "model routing is not configured"
fi
if [ -f "$SOUL" ] && grep -q "Codex workers implement in tmux windows under \`$PERSONAL_TUTOR_SESSION:\*\`" "$SOUL"; then
  ok "persona uses Codex workers"
else
  bad "persona does not declare Codex worker contract"
fi

if [ -x "$SCRIPT_DIR/personal-tutor-output.sh" ] && [ -n "$REPO" ] && \
   "$SCRIPT_DIR/personal-tutor-output.sh" --doctor --repo "$REPO" >/dev/null 2>&1; then
  ok "bounded command-evidence cache is external and private"
else
  bad "bounded command-evidence helper is unavailable or unsafe"
fi
if command -v bwrap >/dev/null 2>&1 && [ -x "$SCRIPT_DIR/personal-tutor-sandbox.sh" ] && [ -n "$REPO" ]; then
  if "$SCRIPT_DIR/personal-tutor-sandbox.sh" --doctor --repo "$REPO" >/dev/null 2>&1; then
    ok "optional offline verification sandbox boundary passes"
  else
    warn "optional offline sandbox smoke failed; use trusted-host development and diagnose separately"
  fi
fi
context_mode_entries=0
for candidate in \
  "$PERSONAL_TUTOR_PROFILE_DIR/skills/context-mode" \
  "$PERSONAL_TUTOR_PROFILE_DIR/skills"/*/context-mode; do
  [ -e "$candidate" ] && context_mode_entries=$((context_mode_entries + 1))
done
if [ -f "$MANIFEST" ] && grep -q 'provider: bounded-command-evidence' "$MANIFEST" && \
   grep -q 'context_mode_package: not-installed' "$MANIFEST" && \
   [ "$context_mode_entries" -eq 0 ]; then
  ok "profile uses bounded output policy with no context-mode skill activation"
else
  bad "profile context policy or skill isolation permits an unapproved package"
fi

if [ -n "$SOURCE" ] && [ -d "$SOURCE/plugins/dev-skills/skills" ]; then
  expected=0 linked=0 codex_expected=0 codex_linked=0
  for skill in "$SOURCE"/plugins/dev-skills/skills/*/; do
    [ -f "$skill/SKILL.md" ] || continue
    name="$(basename "$skill")"
    profile_target="$PERSONAL_TUTOR_PROFILE_DIR/skills/agent-dev-kit/$name"
    codex_target="$PERSONAL_TUTOR_CODEX_HOME/skills/$name"
    if array_contains "$name" "${PERSONAL_TUTOR_HERMES_SKILLS[@]}"; then
      expected=$((expected + 1))
      [ -e "$profile_target" ] && [ "$(readlink -f "$profile_target")" = "$(readlink -f "${skill%/}")" ] && linked=$((linked + 1))
    fi
    if array_contains "$name" "${PERSONAL_TUTOR_CODEX_SKILLS[@]}"; then
      codex_expected=$((codex_expected + 1))
      [ -e "$codex_target" ] && [ "$(readlink -f "$codex_target")" = "$(readlink -f "${skill%/}")" ] && codex_linked=$((codex_linked + 1))
    fi
  done
  [ "$linked" -eq "$expected" ] && ok "all $expected public skills linked into Hermes" || bad "Hermes skill links: $linked/$expected"
  [ "$codex_linked" -eq "$codex_expected" ] && ok "all $codex_expected worker skills linked into Codex" || bad "Codex worker skill links: $codex_linked/$codex_expected"
  unexpected_codex=0
  for installed in "$PERSONAL_TUTOR_CODEX_HOME/skills"/*; do
    [ -e "$installed" ] || continue
    name="$(basename "$installed")"
    [ "$name" = graphify ] && continue
    if ! array_contains "$name" "${PERSONAL_TUTOR_CODEX_SKILLS[@]}"; then
      printf '  unexpected isolated Codex skill: %s\n' "$name"
      unexpected_codex=$((unexpected_codex + 1))
    fi
  done
  [ "$unexpected_codex" -eq 0 ] && ok "isolated Codex role boundary is clean" || bad "$unexpected_codex unexpected isolated Codex skills"

  unexpected=0
  for category in "$PERSONAL_TUTOR_PROFILE_DIR/skills"/*; do
    [ -e "$category" ] || continue
    if [ -f "$category/SKILL.md" ]; then
      printf '  unexpected direct-layout profile skill: %s\n' "$(basename "$category")"
      unexpected=$((unexpected + 1))
      continue
    fi
    case "$(basename "$category")" in
      agent-dev-kit|gsd|external) ;;
      *)
        for installed in "$category"/*; do
          if [ -f "$installed/SKILL.md" ]; then
            printf '  unexpected profile skill: %s/%s\n' "$(basename "$category")" "$(basename "$installed")"
            unexpected=$((unexpected + 1))
          fi
        done
        ;;
    esac
  done
  for installed in "$PERSONAL_TUTOR_PROFILE_DIR/skills/agent-dev-kit"/*; do
    [ -e "$installed" ] || continue
    [ -f "$SOURCE/plugins/dev-skills/skills/$(basename "$installed")/SKILL.md" ] || {
      printf '  unexpected profile skill: %s\n' "$(basename "$installed")"
      unexpected=$((unexpected + 1))
    }
  done
  for installed in "$PERSONAL_TUTOR_PROFILE_DIR/skills/external"/*; do
    [ -e "$installed" ] || continue
    external_name="$(basename "$installed")"
    case "$external_name" in
      graphify|caveman|ponytail)
        expected_external="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/$external_name"
        ;;
      *)
        expected_external=""
        ;;
    esac
    if [ -z "$expected_external" ] || \
       [ "$(readlink -f "$installed")" != "$(readlink -f "$expected_external")" ]; then
      printf '  unexpected external profile skill: %s\n' "$(basename "$installed")"
      unexpected=$((unexpected + 1))
    fi
  done
  [ "$unexpected" -eq 0 ] && ok "profile skill isolation is clean" || bad "$unexpected unexpected profile skill entries"
else
  bad "agent-dev-kit source unavailable; pass --source"
fi

for baseline_skill in "${PERSONAL_TUTOR_BASELINE_SKILLS[@]}"; do
  baseline_global="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/$baseline_skill"
  baseline_profile="$PERSONAL_TUTOR_PROFILE_DIR/skills/external/$baseline_skill"
  if [ -f "$baseline_global/SKILL.md" ] && \
     grep -q "^name:[[:space:]]*${baseline_skill}[[:space:]]*$" "$baseline_global/SKILL.md" && \
     [ -L "$baseline_profile" ] && \
     [ "$(readlink -f "$baseline_profile")" = "$(readlink -f "$baseline_global")" ]; then
    ok "baseline skill available: $baseline_skill"
  else
    bad "baseline skill missing or unmanaged: $baseline_skill"
  fi
done

gsd_unexpected=0
for gsd_skill in gsd-new-project gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work gsd-progress; do
  candidate="$PERSONAL_TUTOR_PROFILE_DIR/skills/gsd/$gsd_skill"
  expected_gsd="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/gsd/$gsd_skill"
  if [ -f "$candidate/SKILL.md" ] && [ "$(readlink -f "$candidate")" = "$(readlink -f "$expected_gsd")" ]; then
    ok "GSD core skill available: $gsd_skill"
  else
    bad "GSD core skill missing or unmanaged: $gsd_skill"
  fi
  direct="$PERSONAL_TUTOR_PROFILE_DIR/skills/$gsd_skill"
  if [ -f "$direct/SKILL.md" ]; then
    printf '  unexpected direct-layout GSD skill: %s\n' "$gsd_skill"
    gsd_unexpected=$((gsd_unexpected + 1))
  fi
done
for installed in "$PERSONAL_TUTOR_PROFILE_DIR/skills/gsd"/*; do
  [ -e "$installed" ] || continue
  case "$(basename "$installed")" in
    gsd-new-project|gsd-discuss-phase|gsd-plan-phase|gsd-execute-phase|gsd-verify-work|gsd-progress) ;;
    *) printf '  unexpected GSD skill: %s\n' "$(basename "$installed")"; gsd_unexpected=$((gsd_unexpected + 1)) ;;
  esac
done
[ "$gsd_unexpected" -eq 0 ] && ok "GSD skill isolation is clean" || bad "$gsd_unexpected unexpected GSD skills"

graphify_version="$(personal_tutor_graphify --version 2>/dev/null | awk '{print $2; exit}')"
if [ "$graphify_version" = "$PERSONAL_TUTOR_GRAPHIFY_VERSION" ]; then
  ok "Graphify reviewed version active: $graphify_version"
else
  bad "Graphify $PERSONAL_TUTOR_GRAPHIFY_VERSION required: ${graphify_version:-missing}"
fi
graphify_hermes="$PERSONAL_TUTOR_USER_HOME/.hermes/skills/graphify"
graphify_codex="$PERSONAL_TUTOR_CODEX_HOME/skills/graphify"
graphify_profile="$PERSONAL_TUTOR_PROFILE_DIR/skills/external/graphify"
if [ -f "$graphify_hermes/SKILL.md" ] && [ -f "$graphify_hermes/.graphify_version" ] && \
   [ "$(cat "$graphify_hermes/.graphify_version")" = "$graphify_version" ]; then
  ok "Graphify Hermes skill matches the installed CLI"
else
  bad "Graphify Hermes skill missing or stale"
fi
if [ -f "$graphify_codex/SKILL.md" ] && [ -f "$graphify_codex/.graphify_version" ] && \
   [ "$(cat "$graphify_codex/.graphify_version")" = "$graphify_version" ]; then
  ok "Graphify Codex skill matches the installed CLI"
else
  bad "Graphify Codex skill missing or stale"
fi
if [ -f "$graphify_profile/SKILL.md" ] && \
   [ "$(readlink -f "$graphify_profile")" = "$(readlink -f "$graphify_hermes")" ]; then
  ok "Graphify linked into the isolated tutor profile"
else
  bad "Graphify is not linked into the isolated tutor profile"
fi

if CODEX_HOME="$PERSONAL_TUTOR_CODEX_HOME" codex login status >/dev/null 2>&1; then
  ok "Codex CLI authenticated in the isolated worker home"
else
  warning "Codex worker home is not authenticated; run personal-tutor-codex login"
fi

if tmux has-session -t "$PERSONAL_TUTOR_SESSION" 2>/dev/null; then
  ok "tmux session exists: $PERSONAL_TUTOR_SESSION"
  codex_count=0
  if [ -n "$REPO" ] && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS='|' read -r command dead path codex_home; do
      [ "$command" = codex ] && [ "$dead" = 0 ] || continue
      [ "$codex_home" = "$PERSONAL_TUTOR_CODEX_HOME" ] || continue
      case "$path" in "$REPO"|"$REPO"/*) codex_count=$((codex_count + 1)) ;; esac
    done < <(tmux list-panes -s -t "$PERSONAL_TUTOR_SESSION" -F '#{pane_current_command}|#{pane_dead}|#{pane_current_path}|#{@personal_tutor_codex_home}' 2>/dev/null)
    [ "$codex_count" -gt 0 ] && ok "repository-matched isolated Codex workers available: $codex_count" || warning "no isolated Codex worker pane for $REPO in $PERSONAL_TUTOR_SESSION; start one with personal-tutor-codex"
  else
    bad "repository/worktree unavailable; run from a Git worktree or pass --repo"
  fi
else
  warning "tmux session missing: $PERSONAL_TUTOR_SESSION"
fi

if [ -n "$SOURCE" ] && [ -x "$SOURCE/scripts/test-personal-dev-tutor.sh" ]; then
  if "$SOURCE/scripts/test-personal-dev-tutor.sh" >/dev/null; then ok "profile product contract test passes"
  else bad "profile product contract test fails"; fi
else
  warning "product contract test unavailable"
fi

printf '\nResult: %d passed, %d failed, %d warnings\n' "$pass" "$fail" "$warn"
[ "$fail" -eq 0 ]
