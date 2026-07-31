#!/usr/bin/env bash
# lab-bridge — expose in-cluster services to local agent harnesses (Claude Code,
# Codex, Pi) as plain localhost ports.
#
# ponytail: kubectl port-forward, not a service mesh / ingress / advertised
# subnet route — nothing changes in the cluster and nothing new is exposed off
# the machine. Upgrade to a Tailscale-advertised service CIDR only if you get
# tired of running `up`.
#
# Service list is machine-local config, never committed here (private hostnames,
# namespaces and service names stay out of this public tree — see
# docs/private-overlays.md).
set -euo pipefail

CONFIG="${AGENT_LAB_CONFIG:-$HOME/.config/agent-dev-kit/lab-services.conf}"
STATE="${AGENT_LAB_STATE:-${XDG_RUNTIME_DIR:-/tmp}/agent-lab-bridge}"

kube=(kubectl)
[ -n "${AGENT_LAB_KUBE_CONTEXT:-}" ] && kube+=(--context "$AGENT_LAB_KUBE_CONTEXT")

entries() {
  if [ ! -f "$CONFIG" ]; then
    echo "lab-bridge: missing config $CONFIG" >&2
    echo "lab-bridge: one line per service: <name> <local_port> <namespace> <service> <remote_port>" >&2
    exit 1
  fi
  grep -vE '^[[:space:]]*(#|$)' "$CONFIG"
}

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

status() {
  local rc=0 name lport ns svc rport
  while read -r name lport ns svc rport; do
    if listening "$lport"; then
      printf 'up    %-14s http://127.0.0.1:%-6s %s/%s:%s\n' "$name" "$lport" "$ns" "$svc" "$rport"
    else
      printf 'DOWN  %-14s %s/%s:%s (log: %s)\n' "$name" "$ns" "$svc" "$rport" "$STATE/$name.log"
      rc=1
    fi
  done < <(entries)
  return $rc
}

up() {
  mkdir -p "$STATE"
  local name lport ns svc rport
  while read -r name lport ns svc rport; do
    listening "$lport" && continue
    nohup "${kube[@]}" port-forward -n "$ns" "svc/$svc" "$lport:$rport" \
      >"$STATE/$name.log" 2>&1 &
    echo $! >"$STATE/$name.pid"
  done < <(entries)
  sleep 3
  status
}

down() {
  local f
  for f in "$STATE"/*.pid; do
    [ -e "$f" ] || continue
    kill "$(cat "$f")" 2>/dev/null || true
    rm -f "$f"
  done
  echo "lab-bridge: down"
}

case "${1:-status}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *) echo "usage: ${0##*/} {up|down|status}" >&2; exit 2 ;;
esac
