#!/usr/bin/env bash
# Capture exact command evidence outside a worktree and bound oversized displays.
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

usage() {
  cat <<'EOF'
Usage:
  personal-tutor-output [options] -- <command> [args...]
  personal-tutor-output --doctor [--repo <worktree>]

Options:
  --repo <path>          Run in this repository/worktree (default: current Git root)
  --label <slug>         Evidence label (default: command basename)
  --kind <standard|security>
                         Classify security output; large output is bounded
  --head <lines>         Successful preview head (default: 20)
  --tail <lines>         Successful preview tail (default: 40)
  --full                 Show successful output in full
  --doctor               Verify the external cache without running a command

The command is executed directly, never through eval or a shell string. Its exact
combined stdout/stderr is retained with mode 0600 outside the worktree. Display
is control-character sanitized and bounded at 32 KiB when oversized, including
failures and security output. Do not use this helper
for commands that may print secrets, credentials, private documents, or source
that should not be persisted. It adds no network access of its own.
EOF
}

repo=""
label=""
kind="standard"
head_lines=20
tail_lines=40
force_full=0
doctor=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo requires a path}"; shift 2 ;;
    --label) label="${2:?--label requires a value}"; shift 2 ;;
    --kind) kind="${2:?--kind requires a value}"; shift 2 ;;
    --head) head_lines="${2:?--head requires a number}"; shift 2 ;;
    --tail) tail_lines="${2:?--tail requires a number}"; shift 2 ;;
    --full) force_full=1; shift ;;
    --doctor) doctor=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "unknown argument: $1"; usage; exit 2 ;;
  esac
done

case "$kind" in standard|security) ;; *) echo "--kind must be standard or security"; exit 2 ;; esac
[[ "$head_lines" =~ ^[0-9]+$ ]] || { echo "--head must be a non-negative integer"; exit 2; }
[[ "$tail_lines" =~ ^[0-9]+$ ]] || { echo "--tail must be a non-negative integer"; exit 2; }

if [ -z "$repo" ]; then
  repo="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$repo" ] || { echo "unable to resolve a Git worktree; pass --repo"; exit 2; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a Git repository: $repo"; exit 2; }
repo="$(git -C "$repo" rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"

cache_base="${PERSONAL_TUTOR_OUTPUT_CACHE_ROOT:-${XDG_CACHE_HOME:-$PERSONAL_TUTOR_USER_HOME/.cache}/personal-dev-tutor/command-output}"
mkdir -p "$cache_base"
chmod 700 "$cache_base"
cache_base="$(cd "$cache_base" && pwd -P)"
case "$cache_base/" in
  "$repo/"*) echo "output cache must be outside the worktree: $cache_base"; exit 2 ;;
esac

repo_id="$(printf '%s' "$repo" | sha256sum | cut -c1-16)"
repo_cache="$cache_base/$repo_id"
[ ! -L "$repo_cache" ] || { echo "refusing symlinked repository cache: $repo_cache"; exit 2; }
mkdir -p "$repo_cache"
chmod 700 "$repo_cache"
repo_cache="$(cd "$repo_cache" && pwd -P)"
case "$repo_cache/" in
  "$repo/"*) echo "repository cache resolves inside the worktree: $repo_cache"; exit 2 ;;
esac

if [ "$doctor" -eq 1 ]; then
  [ $# -eq 0 ] || { echo "--doctor does not accept a command"; exit 2; }
  cache_mode="$(stat -c '%a' "$repo_cache")"
  [ "$cache_mode" = 700 ] || { echo "output cache permissions are $cache_mode, expected 700"; exit 1; }
  printf 'OK output evidence cache is external and private: %s\n' "$repo_cache"
  exit 0
fi

[ $# -gt 0 ] || { echo "missing command after --"; usage; exit 2; }
if [ -z "$label" ]; then label="$(basename "$1")"; fi
[[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  echo "label may contain only letters, numbers, dot, underscore, and dash"
  exit 2
}
command_name="$(basename "$1")"
case "$command_name" in
  bandit|bearer|brakeman|codeql|gosec|grype|semgrep|snyk|trivy)
    [ "$kind" = security ] || {
      echo "security scanner '$command_name' requires --kind security so its output remains full"
      exit 2
    }
    ;;
esac

umask 077
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
transcript="$(mktemp "$repo_cache/${timestamp}-${label}.XXXXXX.log")"
chmod 600 "$transcript"

if (cd "$repo" && "$@") >"$transcript" 2>&1; then
  status=0
else
  status=$?
fi
sha="$(sha256sum "$transcript" | cut -d' ' -f1)"
lines="$(wc -l < "$transcript" | tr -d ' ')"
bytes="$(wc -c < "$transcript" | tr -d ' ')"

printf 'COMMAND_EVIDENCE\n'
printf 'label: %s\n' "$label"
printf 'status: %s\n' "$status"
printf 'transcript: %s\n' "$transcript"
printf 'sha256: %s\n' "$sha"
printf 'lines: %s\n' "$lines"
printf 'bytes: %s\n' "$bytes"
printf 'retention: manual-unredacted\n'
printf 'retention_warning: delete the transcript when evidence is no longer needed\n'

preview_limit=$((head_lines + tail_lines))
preview_byte_limit=32768
safe_stream() {
  python3 -c 'import sys, unicodedata
data = sys.stdin.buffer.read()
text = data.decode("utf-8", errors="surrogateescape")
out = []
for char in text:
    value = ord(char)
    if char in ("\t", "\n") or not unicodedata.category(char).startswith("C"):
        out.append(char)
    elif 0xDC80 <= value <= 0xDCFF:
        out.append(f"\\x{value - 0xDC00:02x}")
    elif value <= 0xFF:
        out.append(f"\\x{value:02x}")
    elif value <= 0xFFFF:
        out.append(f"\\u{value:04x}")
    else:
        out.append(f"\\U{value:08x}")
sys.stdout.write("".join(out))'
}

print_sanitized_full() {
  printf 'display: sanitized-full\n--- sanitized display; transcript remains exact ---\n'
  safe_stream < "$transcript"
}

print_sanitized_lines() {
  local command="$1" count="$2"
  [ "$count" -gt 0 ] || return 0
  "$command" -n "$count" "$transcript" | safe_stream
}

print_sanitized_bytes() {
  local omission_message="$1"
  local head_bytes=$((preview_byte_limit / 2))
  local tail_bytes=$((preview_byte_limit - head_bytes))
  printf '%s\n' '--- sanitized leading bytes ---'
  head -c "$head_bytes" "$transcript" | safe_stream
  printf '\n%s\n' "$omission_message"
  printf '%s\n' '--- sanitized trailing bytes ---'
  tail -c "$tail_bytes" "$transcript" | safe_stream
  printf '\n'
}

is_critical_output() {
  [ "$kind" = security ] || [ "$status" -ne 0 ]
}

if [ "$force_full" -eq 1 ]; then
  print_sanitized_full
elif is_critical_output && [ "$bytes" -gt "$preview_byte_limit" ]; then
  omitted=$((bytes - preview_byte_limit))
  printf 'display: bounded-critical-preview\n'
  printf 'omitted_bytes: %s\n' "$omitted"
  print_sanitized_bytes "--- $omitted exact bytes omitted; inspect the mode-0600 transcript locally ---"
elif is_critical_output ||
  { [ "$lines" -le "$preview_limit" ] && [ "$bytes" -le "$preview_byte_limit" ]; }; then
  print_sanitized_full
else
  printf 'display: bounded-success-preview\n'
  line_preview_bytes="$({
    if [ "$head_lines" -gt 0 ]; then head -n "$head_lines" "$transcript"; fi
    if [ "$tail_lines" -gt 0 ]; then tail -n "$tail_lines" "$transcript"; fi
  } | wc -c | tr -d ' ')"
  if [ "$lines" -gt "$preview_limit" ] && [ "$line_preview_bytes" -le "$preview_byte_limit" ]; then
    omitted=$((lines - preview_limit))
    printf 'preview_basis: lines\n'
    printf 'omitted_lines: %s\n' "$omitted"
    printf '%s\n' '--- sanitized head ---'
    print_sanitized_lines head "$head_lines"
    printf '%s\n' "--- $omitted exact lines omitted; inspect transcript before diagnosis ---"
    printf '%s\n' '--- sanitized tail ---'
    print_sanitized_lines tail "$tail_lines"
  else
    omitted=$((bytes - preview_byte_limit))
    [ "$omitted" -lt 0 ] && omitted=0
    printf 'preview_basis: bytes\n'
    printf 'omitted_bytes: %s\n' "$omitted"
    print_sanitized_bytes "--- $omitted exact bytes omitted; inspect transcript before diagnosis ---"
  fi
fi

exit "$status"
