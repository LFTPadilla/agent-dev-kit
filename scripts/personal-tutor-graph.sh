#!/usr/bin/env bash
# Build and query a local Graphify AST graph without dirtying the project worktree.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

usage() {
  cat <<'EOF'
Usage: personal-tutor-graph <status|refresh|query|affected|path> [options]

Options:
  --repo <path>       Git worktree to map (default: current worktree)

Actions:
  status              Print graph location and content-hash freshness
  refresh             Build or incrementally refresh a local AST-only graph
  query <question>    Query relationships in the current graph
  affected <symbol>   Find symbols affected by a node
  path <from> <to>    Find the shortest path between two nodes

Graphs are stored in a private user cache outside the worktree. Refresh uses the
reviewed Graphify release in --code-only mode: local AST extraction, no API key,
semantic document ingestion, hooks, or source upload.
EOF
}

[ $# -gt 0 ] || { usage; exit 2; }
action="$1"
shift
repo=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo requires a path}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "unknown option: $1"; usage; exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

command -v graphify >/dev/null 2>&1 || {
  echo "graphify is required; run: uv tool install graphifyy==$PERSONAL_TUTOR_GRAPHIFY_VERSION"
  exit 1
}
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required"; exit 1; }

graphify_version="$(personal_tutor_graphify --version 2>/dev/null | awk '{print $2; exit}')"
[ "$graphify_version" = "$PERSONAL_TUTOR_GRAPHIFY_VERSION" ] || {
  echo "Graphify $PERSONAL_TUTOR_GRAPHIFY_VERSION is required; found ${graphify_version:-unknown}"
  exit 1
}

if [ -z "$repo" ]; then
  repo="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$repo" ] && git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "repository/worktree unavailable; run from a Git worktree or pass --repo"
  exit 2
}
repo="$(git -C "$repo" rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"

umask 077
cache_root="${PERSONAL_TUTOR_GRAPH_CACHE_ROOT:-${XDG_CACHE_HOME:-$PERSONAL_TUTOR_USER_HOME/.cache}/personal-dev-tutor/graphify}"
[ ! -L "$cache_root" ] || { echo "refusing symlinked graph cache root: $cache_root"; exit 2; }
cache_candidate="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve(strict=False))' "$cache_root")"
case "$cache_candidate/" in
  "$repo/"*) echo "graph cache must be outside the worktree: $cache_candidate"; exit 2 ;;
esac
mkdir -p "$cache_root"
chmod 700 "$cache_root"
cache_root="$(cd "$cache_root" && pwd -P)"
case "$cache_root/" in
  "$repo/"*) echo "graph cache must be outside the worktree: $cache_root"; exit 2 ;;
esac
repo_key="$(printf '%s' "$repo" | sha256sum | cut -c1-16)"
cache_dir="$cache_root/$(basename "$repo")-$repo_key"
[ ! -L "$cache_dir" ] || { echo "refusing symlinked repository graph cache: $cache_dir"; exit 2; }
mkdir -p "$cache_dir"
chmod 700 "$cache_dir"
cache_dir="$(cd "$cache_dir" && pwd -P)"
case "$cache_dir/" in
  "$repo/"*) echo "repository graph cache resolves inside the worktree: $cache_dir"; exit 2 ;;
esac
graph="$cache_dir/graphify-out/graph.json"
source_state="$cache_dir/source-state.sha256"

source_digest() {
  python3 - "$repo" <<'PY'
from pathlib import Path
import hashlib
import os
import subprocess
import sys

repo = sys.argv[1]
extensions = {".py", ".pyi", ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx",
              ".java", ".groovy", ".c", ".h", ".cc", ".cpp", ".cxx", ".hpp",
              ".rb", ".cs", ".kt", ".kts", ".scala", ".php", ".swift", ".rs",
              ".go", ".lua", ".jl", ".ex", ".exs", ".sh", ".bash", ".zsh",
              ".ps1", ".psm1", ".f", ".f90", ".f95", ".for", ".zig", ".vue",
              ".svelte", ".m", ".mm", ".json", ".toml", ".yaml", ".yml"}
raw = subprocess.check_output(["git", "-C", repo, "ls-files", "-co", "--exclude-standard", "-z"])
paths = sorted(p.decode("utf-8", "surrogateescape") for p in raw.split(b"\0") if p)
h = hashlib.sha256()
for relative in paths:
    path = Path(repo, relative)
    if path.suffix.lower() not in extensions or (not path.is_file() and not path.is_symlink()):
        continue
    encoded = os.fsencode(relative)
    h.update(len(encoded).to_bytes(8, "big")); h.update(encoded)
    if path.is_symlink():
        content = os.fsencode(os.readlink(path))
    else:
        content = path.read_bytes()
    h.update(len(content).to_bytes(8, "big")); h.update(content)
print(h.hexdigest())
PY
}

require_graph() {
  [ -f "$graph" ] && [ -f "$source_state" ] || {
    echo "graph unavailable for $repo; run: personal-tutor-graph refresh --repo '$repo'"
    exit 1
  }
  [ "$(stat -c '%a' "$source_state")" = 600 ] || { echo "graph state file is not private"; exit 1; }
}

graph_freshness() {
  local current recorded
  current="$(source_digest)"
  recorded="$(cat "$source_state" 2>/dev/null || true)"
  if [ -n "$recorded" ] && [ "$current" = "$recorded" ]; then printf 'fresh\n'; else printf 'stale\n'; fi
}

warn_if_graph_stale() {
  [ "$(graph_freshness)" = fresh ] || printf 'warning: graph is stale; refresh before relying on it\n' >&2
}

run_graph_action() {
  local action="$1"
  shift
  require_graph
  warn_if_graph_stale
  personal_tutor_graphify "$action" "$@" --graph "$graph"
}

case "$action" in
  refresh)
    [ "${#args[@]}" -eq 0 ] || { usage; exit 2; }
    printf '%s\n' "$repo" > "$cache_dir/source-root"
    chmod 600 "$cache_dir/source-root"
    GRAPHIFY_OUT="$cache_dir/graphify-out" \
      personal_tutor_graphify extract "$repo" --out "$cache_dir" --code-only
    [ -f "$graph" ] || { echo "graphify did not create $graph"; exit 1; }
    source_digest > "$source_state"
    chmod 600 "$source_state"
    printf 'graph=%s\nstatus=%s\n' "$graph" "$(graph_freshness)"
    ;;
  status)
    [ "${#args[@]}" -eq 0 ] || { usage; exit 2; }
    printf 'repository=%s\ncache=%s\n' "$repo" "$cache_dir"
    require_graph
    printf 'graph=%s\nstatus=%s\n' "$graph" "$(graph_freshness)"
    ;;
  query)
    [ "${#args[@]}" -eq 1 ] || { usage; exit 2; }
    run_graph_action query "${args[0]}"
    ;;
  affected)
    [ "${#args[@]}" -eq 1 ] || { usage; exit 2; }
    run_graph_action affected "${args[0]}"
    ;;
  path)
    [ "${#args[@]}" -eq 2 ] || { usage; exit 2; }
    run_graph_action path "${args[0]}" "${args[1]}"
    ;;
  *) echo "unknown action: $action"; usage; exit 2 ;;
esac
