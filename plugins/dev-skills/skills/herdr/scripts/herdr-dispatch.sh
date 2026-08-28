#!/usr/bin/env bash
# herdr-dispatch.sh - Deterministic dispatcher and lifecycle manager for Herdr.
#
# Part of agent-dev-kit (plugins/dev-skills/skills/herdr/scripts/herdr-dispatch.sh).
# Compatible with felipe.auto-index plugin (strips '^[0-9]+[.] ?' prefix on matching).
#
# Usage:
#   herdr-dispatch.sh list [--format json|toon]
#   herdr-dispatch.sh run --space <space> --tab <tab> --command <cmd> [--cwd <path>] [--dir right|down]
#   herdr-dispatch.sh agent-start --space <space> --tab <tab> --name <name> --kind <kind> [--cwd <path>] [--dir right|down] [--prompt <text>] [--wait]
#   herdr-dispatch.sh status --name <name> [--format json|toon]
#   herdr-dispatch.sh wait --name <name> [--timeout <seconds>]
#
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[herdr-dispatch] %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
require_cmd "$HERDR"
require_cmd jq

# ── Workspace / Tab matching (compatible with auto-index) ────────────────────

strip_index() {
  sed -E 's/^[0-9]+[.] ?//' <<< "$1"
}

ws_id() {
  local target_label="$1"
  "$HERDR" workspace list 2>/dev/null | jq -r --arg l "$target_label" '
    .result.workspaces[]? |
    select((.label | sub("^[0-9]+[.] ?"; "")) == $l or .label == $l) |
    .workspace_id
  ' | head -n1
}

tab_id() {
  local wid="$1" target_label="$2"
  "$HERDR" tab list --workspace "$wid" 2>/dev/null | jq -r --arg l "$target_label" '
    .result.tabs[]? |
    select((.label | sub("^[0-9]+[.] ?"; "")) == $l or .label == $l) |
    .tab_id
  ' | head -n1
}

tab_panes() {
  local wid="$1" tid="$2"
  "$HERDR" pane list --workspace "$wid" 2>/dev/null | jq -r --arg t "$tid" '
    .result.panes[]? | select(.tab_id == $t) | .pane_id
  '
}

pane_is_shell() {
  local pid="$1"
  local pproc
  pproc=$("$HERDR" pane process-info --pane "$pid" 2>/dev/null | jq -r '.result.process_info.foreground_processes[0].name // ""' 2>/dev/null || true)
  [[ "$pproc" == "zsh" || "$pproc" == "bash" || "$pproc" == "sh" || "$pproc" == "" ]]
}

ensure_space() {
  local label="$1" cwd="${2:-$PWD}"
  local wid
  wid=$(ws_id "$label")
  if [[ -n "$wid" ]]; then
    printf '%s' "$wid"
    return 0
  fi
  local out
  out=$("$HERDR" workspace create --label "$label" --cwd "$cwd" 2>/dev/null)
  wid=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty' 2>/dev/null)
  [[ -n "$wid" ]] || wid=$(ws_id "$label")
  [[ -n "$wid" ]] || die "failed to create workspace: $label"
  printf '%s' "$wid"
}

ensure_tab() {
  local wid="$1" label="$2" cwd="${3:-$PWD}"
  local tid
  tid=$(tab_id "$wid" "$label")
  if [[ -n "$tid" ]]; then
    printf '%s' "$tid"
    return 0
  fi
  local out
  out=$("$HERDR" tab create --workspace "$wid" --label "$label" --cwd "$cwd" 2>/dev/null)
  tid=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // .result.tab_id // empty' 2>/dev/null)
  [[ -n "$tid" ]] || tid=$(tab_id "$wid" "$label")
  [[ -n "$tid" ]] || die "failed to create tab: $label in workspace $wid"
  printf '%s' "$tid"
}

ensure_idle_pane() {
  local wid="$1" tid="$2" cwd="${3:-$PWD}" dir="${4:-right}"
  local target_pane=""
  for p in $(tab_panes "$wid" "$tid"); do
    if pane_is_shell "$p"; then
      target_pane="$p"
      break
    fi
  done

  if [[ -z "$target_pane" ]]; then
    local first_pane
    first_pane=$(tab_panes "$wid" "$tid" | head -n1)
    if [[ -n "$first_pane" ]]; then
      local split_out
      split_out=$("$HERDR" pane split --pane "$first_pane" --direction "$dir" 2>/dev/null)
      target_pane=$(printf '%s' "$split_out" | jq -r '.result.pane.pane_id // empty' 2>/dev/null)
    fi
  fi

  [[ -n "$target_pane" ]] || die "unable to find or allocate an idle pane in tab $tid"
  printf '%s' "$target_pane"
}

# ── Subcommand Handlers ──────────────────────────────────────────────────────

cmd_list() {
  local format="json"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      *) die "unknown option for list: $1" ;;
    esac
  done

  local workspaces tabs panes agents
  workspaces=$("$HERDR" workspace list 2>/dev/null)
  tabs=$("$HERDR" tab list 2>/dev/null)
  panes=$("$HERDR" pane list 2>/dev/null)
  agents=$("$HERDR" agent list 2>/dev/null)

  local combined
  combined=$(jq -n \
    --argjson w "$workspaces" \
    --argjson t "$tabs" \
    --argjson p "$panes" \
    --argjson a "$agents" '
    {
      workspaces: [
        $w.result.workspaces[]? | . as $ws | {
          id: $ws.workspace_id,
          label: $ws.label,
          clean_label: ($ws.label | sub("^[0-9]+[.] ?"; "")),
          cwd: $ws.identity_cwd,
          tabs: [
            $t.result.tabs[]? | select(.workspace_id == $ws.workspace_id) | . as $tab | {
              id: $tab.tab_id,
              label: $tab.label,
              clean_label: ($tab.label | sub("^[0-9]+[.] ?"; "")),
              cwd: $tab.cwd,
              panes: [
                $p.result.panes[]? | select(.tab_id == $tab.tab_id) | {
                  id: .pane_id,
                  agent: .agent,
                  agent_status: .agent_status,
                  title: .terminal_title_stripped,
                  cwd: .cwd
                }
              ]
            }
          ]
        }
      ],
      agents: [
        $a.result.agents[]? | {
          pane_id: .pane_id,
          agent: .agent,
          status: .agent_status,
          cwd: .cwd,
          session_id: (.agent_session.value // null)
        }
      ]
    }
  ')

  if [[ "$format" == "toon" ]]; then
    printf 'spaces:\n'
    jq -r '.workspaces[] | "  - space: \(.clean_label) (\(.id))\n" + (.tabs[] | "      tab: \(.clean_label) (\(.id))\n" + (.panes[] | "        pane: \(.id) [agent: \(.agent // "none"), status: \(.agent_status // "none")]\n"))' <<< "$combined"
    printf 'live_agents:\n'
    jq -r '.agents[] | "  - agent: \(.agent) (pane: \(.pane_id), status: \(.status), cwd: \(.cwd))\n"' <<< "$combined"
  else
    printf '%s\n' "$combined"
  fi
}

cmd_run() {
  local space="" tab="" cmd="" cwd="" dir="right"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space) space="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --command) cmd="$2"; shift 2 ;;
      --cwd) cwd="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      *) die "unknown option for run: $1" ;;
    esac
  done

  [[ -n "$space" ]] || die "--space is required"
  [[ -n "$tab" ]] || die "--tab is required"
  [[ -n "$cmd" ]] || die "--command is required"
  cwd="${cwd:-$PWD}"

  local wid tid pid
  wid=$(ensure_space "$space" "$cwd")
  tid=$(ensure_tab "$wid" "$tab" "$cwd")
  pid=$(ensure_idle_pane "$wid" "$tid" "$cwd" "$dir")

  log "running command in pane $pid (space: $space, tab: $tab)"
  "$HERDR" pane run "$pid" "$cmd"
}

cmd_agent_start() {
  local space="" tab="" name="" kind="" cwd="" dir="right" prompt="" wait_flag=0 timeout=120
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space) space="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --kind) kind="$2"; shift 2 ;;
      --cwd) cwd="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --wait) wait_flag=1; shift ;;
      --timeout) timeout="$2"; shift 2 ;;
      *) die "unknown option for agent-start: $1" ;;
    esac
  done

  [[ -n "$space" ]] || die "--space is required"
  [[ -n "$tab" ]] || die "--tab is required"
  [[ -n "$name" ]] || die "--name is required"
  [[ -n "$kind" ]] || die "--kind is required"
  cwd="${cwd:-$PWD}"

  local wid tid pid
  wid=$(ensure_space "$space" "$cwd")
  tid=$(ensure_tab "$wid" "$tab" "$cwd")
  pid=$(ensure_idle_pane "$wid" "$tid" "$cwd" "$dir")

  log "starting agent $name ($kind) in pane $pid"
  "$HERDR" agent start "$name" --kind "$kind" --pane "$pid"

  if [[ -n "$prompt" ]]; then
    log "submitting prompt to agent $name"
    "$HERDR" agent prompt "$name" "$prompt"
  fi

  if [[ "$wait_flag" -eq 1 ]]; then
    cmd_wait --name "$name" --timeout "$timeout"
  fi
}

cmd_status() {
  local name="" format="json"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) die "unknown option for status: $1" ;;
    esac
  done
  [[ -n "$name" ]] || die "--name is required"

  local info
  info=$("$HERDR" agent get "$name" 2>/dev/null || true)
  [[ -n "$info" ]] || die "agent '$name' not found"

  if [[ "$format" == "toon" ]]; then
    jq -r '.result.agent | "agent: \(.agent)\nstatus: \(.agent_status)\npane: \(.pane_id)\ncwd: \(.cwd)\n"' <<< "$info"
  else
    printf '%s\n' "$info"
  fi
}

cmd_wait() {
  local name="" timeout=180
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      *) die "unknown option for wait: $1" ;;
    esac
  done
  [[ -n "$name" ]] || die "--name is required"

  log "waiting for agent '$name' to reach idle/done (timeout: ${timeout}s)..."
  local elapsed=0
  while [[ "$elapsed" -lt "$timeout" ]]; do
    local state
    state=$("$HERDR" agent get "$name" 2>/dev/null | jq -r '.result.agent.agent_status // empty' 2>/dev/null || true)
    if [[ "$state" == "idle" || "$state" == "done" ]]; then
      log "agent '$name' reached state: $state"
      return 0
    elif [[ "$state" == "blocked" ]]; then
      log "agent '$name' is blocked waiting for user interaction"
      return 2
    elif [[ -z "$state" ]]; then
      die "agent '$name' disappeared or exited"
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  die "timed out after ${timeout}s waiting for agent '$name'"
}

# ── Main Entrypoint ──────────────────────────────────────────────────────────

case "${1:-}" in
  list) shift; cmd_list "$@" ;;
  run) shift; cmd_run "$@" ;;
  agent-start) shift; cmd_agent_start "$@" ;;
  status) shift; cmd_status "$@" ;;
  wait) shift; cmd_wait "$@" ;;
  --help|-h|"")
    cat <<'EOF'
Usage: herdr-dispatch.sh <command> [options]

Commands:
  list         List workspaces, tabs, panes, and running agents
  run          Run a terminal command inside a space/tab (auto-allocates pane)
  agent-start  Start a supported agent (claude, codex, hermes, opencode, pi, etc.)
  status       Inspect current agent status
  wait         Wait for agent to reach idle or done

Options:
  --space <name>      Workspace name (matched stripped of index prefix)
  --tab <name>        Tab name (matched stripped of index prefix)
  --name <name>       Unique agent identifier [a-z][a-z0-9_-]*
  --kind <kind>       Agent kind (claude, codex, hermes, opencode, pi, agy, etc.)
  --command <cmd>     Command to run
  --prompt <text>     Initial prompt to submit to agent
  --format <fmt>      Output format: json | toon (default: json)
  --dir <direction>   Split direction: right | down (default: right)
  --wait              Block until agent reaches idle/done
  --timeout <sec>     Timeout in seconds for waiting (default: 180)
EOF
    exit 0
    ;;
  *) die "unknown command: $1 (run with --help for usage)" ;;
esac
