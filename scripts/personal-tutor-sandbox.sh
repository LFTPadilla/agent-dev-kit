#!/usr/bin/env bash
# Run offline verification with an empty home and a read-only worktree by default.
set -euo pipefail

# Do not let a caller-controlled PATH substitute host-side boundary tools.
# Preserve the original path only for resolving the requested sandbox command.
ORIGINAL_PATH="${PATH:-}"
export PATH="/usr/local/bin:/usr/bin:/bin:/nix/var/nix/profiles/default/bin"

SELF_PATH="${BASH_SOURCE[0]}"
if [ -L "$SELF_PATH" ]; then SELF_PATH="$(readlink -f "$SELF_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
# shellcheck source=personal-tutor-lib.sh
source "$SCRIPT_DIR/personal-tutor-lib.sh"

usage() {
  cat <<'EOF'
Usage:
  personal-tutor-sandbox [options] -- <command> [args...]
  personal-tutor-sandbox --doctor [--repo <worktree>]

Options:
  --repo <path>       Git worktree to mount at /workspace (default: current root)
  --write <path>      Existing worktree-relative path to make writable; repeatable
  --timeout <seconds> Kill the sandbox after this many seconds (default: 300)
  --doctor            Exercise the local bubblewrap boundary without a command

The sandbox denies network, supplies an empty home and private /tmp, mounts the
worktree read-only by default, and does not inherit credentials or environment
variables. Only explicit existing --write paths become writable; Git metadata
always remains read-only. Commands run at /workspace and must use relative paths.
This Linux/bubblewrap helper is defense in depth, not a container or VM.
EOF
}

repo=""
timeout_seconds=300
doctor=0
writes=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo requires a path}"; shift 2 ;;
    --write) writes+=("${2:?--write requires a path}"); shift 2 ;;
    --timeout) timeout_seconds="${2:?--timeout requires seconds}"; shift 2 ;;
    --doctor) doctor=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "unknown argument: $1"; usage; exit 2 ;;
  esac
done

[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || { echo "--timeout must be a positive integer"; exit 2; }
for required in bwrap python3 git find readlink; do
  command -v "$required" >/dev/null 2>&1 || { echo "required command missing: $required"; exit 1; }
done
BWRAP_BIN="$(readlink -f "$(command -v bwrap)")"
PYTHON_BIN="$(readlink -f "$(command -v python3)")"
for trusted_tool in "$BWRAP_BIN" "$PYTHON_BIN"; do
  case "$trusted_tool" in /usr/*|/nix/store/*) ;; *) echo "untrusted host tool path: $trusted_tool"; exit 1 ;; esac
done

requested_repo="$repo"
if ! repo="$(personal_tutor_git_root "$repo")"; then
  if [ -n "$requested_repo" ]; then
    echo "not a Git repository: $requested_repo"
  else
    echo "unable to resolve a Git worktree; pass --repo"
  fi
  exit 2
fi

git_entry="$repo/.git"
[ -e "$git_entry" ] || { echo "Git metadata entry is missing: $git_entry"; exit 2; }
git_dir="$(git -C "$repo" rev-parse --absolute-git-dir)"
git_dir="$(readlink -f "$git_dir")"
git_common_dir="$(git -C "$repo" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$repo/$git_common_dir" ;;
esac
git_common_dir="$(readlink -f "$git_common_dir")"

path_is_within() {
  local path="$1" root="$2"
  case "$path" in
    "$root"|"$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

mounts=(
  --die-with-parent
  --new-session
  --unshare-pid
  --unshare-net
  --unshare-ipc
  --unshare-uts
  --unshare-cgroup-try
  --clearenv
  --setenv HOME /home/tutor
  --setenv TMPDIR /tmp
  --setenv CI true
  --setenv NO_COLOR 1
  --setenv LANG C.UTF-8
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --dir /home
  --dir /home/tutor
  --dir /workspace
  --ro-bind "$repo" /workspace
)

if [ -f "$git_entry" ]; then
  [ ! -L "$git_entry" ] || { echo "refusing symlinked Git metadata: $git_entry"; exit 2; }
  [ -d "$git_dir" ] || { echo "linked-worktree Git directory is missing: $git_dir"; exit 2; }
  [ -d "$git_common_dir" ] || { echo "linked-worktree common Git directory is missing: $git_common_dir"; exit 2; }
  path_is_within "$git_common_dir" "$repo" || \
    mounts+=(--ro-bind "$git_common_dir" "$git_common_dir")
  path_is_within "$git_dir" "$repo" || path_is_within "$git_dir" "$git_common_dir" || \
    mounts+=(--ro-bind "$git_dir" "$git_dir")
fi

# Mount only runtime/toolchain trees, not the real home. /bin and /lib are
# normally usr-merge symlinks, so recreate those links inside the empty root.
[ -d /usr ] && mounts+=(--ro-bind /usr /usr)
if [ -d /nix/store ]; then
  mounts+=(--dir /nix --ro-bind /nix/store /nix/store)
fi
mounts+=(--symlink usr/bin /bin)
[ -d /usr/lib ] && mounts+=(--symlink usr/lib /lib)
[ -d /usr/lib64 ] && mounts+=(--symlink usr/lib64 /lib64)
mounts+=(--dir /etc)
for system_path in /etc/passwd /etc/group /etc/nsswitch.conf /etc/hosts /etc/localtime; do
  [ -e "$system_path" ] && mounts+=(--ro-bind "$system_path" "$system_path")
done
if [ -d /etc/ssl ]; then
  mounts+=(--dir /etc/ssl)
  [ -d /etc/ssl/certs ] && mounts+=(--ro-bind /etc/ssl/certs /etc/ssl/certs)
  [ -f /etc/ssl/openssl.cnf ] && mounts+=(--ro-bind /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf)
fi

for requested in "${writes[@]}"; do
  [ -n "$requested" ] || { echo "--write path must be non-empty"; exit 2; }
  case "$requested" in
    /*) echo "--write must be worktree-relative: $requested"; exit 2 ;;
    .) ;;
    *//*|*/|*/.|./*|*/./*|*/..|../*|*/../*)
      echo "--write path must not contain empty, dot, or parent components: $requested"
      exit 2
      ;;
  esac
  current="$repo"
  IFS=/ read -r -a components <<< "$requested"
  for component in "${components[@]}"; do
    [ "$component" != .git ] || { echo "Git metadata may not be writable: $requested"; exit 2; }
    current="$current/$component"
    [ ! -L "$current" ] || { echo "refusing symlinked --write path component: $requested"; exit 2; }
  done
  write_source="$repo/$requested"
  [ -e "$write_source" ] || { echo "--write path must already exist: $requested"; exit 2; }
  write_source="$(readlink -f "$write_source")"
  path_is_within "$write_source" "$repo" || {
    echo "--write resolves outside the worktree: $requested"
    exit 2
  }
  relative="${write_source#$repo}"
  mounts+=(--bind "$write_source" "/workspace$relative")
done

# A broad write path must not expose root or nested repository metadata. Refuse
# symlinked .git entries rather than following them to an unmounted/outside path.
git_list="$(mktemp)"
socket_list="$(mktemp)"
trap 'rm -f "$git_list" "$socket_list"' EXIT
if ! find "$repo" -type s -print0 -quit > "$socket_list"; then
  echo "unable to inspect worktree for host Unix sockets"
  exit 1
fi
if [ -s "$socket_list" ]; then
  echo "refusing worktree containing a live Unix socket"
  exit 2
fi
if ! find "$repo" -name .git -print0 -prune > "$git_list"; then
  echo "unable to enumerate Git metadata entries"
  exit 1
fi
git_count=0
while IFS= read -r -d '' entry; do
  [ ! -L "$entry" ] || { echo "refusing repository with symlinked Git metadata: $entry"; exit 2; }
  mounts+=(--ro-bind "$entry" "/workspace${entry#$repo}")
  git_count=$((git_count + 1))
done < "$git_list"
[ "$git_count" -gt 0 ] || { echo "no Git metadata entry found under worktree"; exit 2; }
rm -f "$git_list" "$socket_list"
trap - EXIT

build_path() {
  local result="/usr/local/bin:/usr/bin:/bin" entry resolved suffix
  local -a host_entries
  IFS=: read -r -a host_entries <<< "$ORIGINAL_PATH"
  for entry in "${host_entries[@]}"; do
    [ -d "$entry" ] || continue
    resolved="$(readlink -f "$entry" 2>/dev/null || true)"
    case "$resolved" in
      /nix/store/*|/usr/*|/bin) result="$result:$resolved" ;;
      "$repo"/*)
        suffix="${resolved#$repo}"
        result="$result:/workspace$suffix"
        ;;
    esac
  done
  printf '%s\n' "$result"
}
sandbox_path="$(build_path)"
mounts+=(--setenv PATH "$sandbox_path" --chdir /workspace)

resolve_command() {
  local requested="$1" found="" resolved suffix entry
  local -a host_entries
  if [[ "$requested" == */* ]]; then
    if [[ "$requested" = /* ]]; then found="$requested"; else found="$repo/$requested"; fi
  else
    IFS=: read -r -a host_entries <<< "$ORIGINAL_PATH"
    for entry in "${host_entries[@]}"; do
      [ -n "$entry" ] || entry=.
      if [ -f "$entry/$requested" ] && [ -x "$entry/$requested" ]; then
        found="$entry/$requested"
        break
      fi
    done
  fi
  [ -n "$found" ] && [ -f "$found" ] || return 1
  resolved="$(readlink -f "$found")"
  case "$resolved" in
    "$repo"/*)
      suffix="${resolved#$repo}"
      printf '/workspace%s\n' "$suffix"
      ;;
    /nix/store/*|/usr/*)
      printf '%s\n' "$resolved"
      ;;
    *) return 1 ;;
  esac
}

# Bash arrays are clearer and safer than reconstructing the bwrap boundary in a
# shell string. The Python launcher closes every descriptor above stderr, then
# receives a mount-count so bwrap options cannot be confused with command argv.
launch() {
  local executable="$1"; shift
  "$PYTHON_BIN" -c '
import os
import sys

bwrap_bin = sys.argv[1]
timeout_seconds = float(sys.argv[2])
mount_count = int(sys.argv[3])
mounts = sys.argv[4:4 + mount_count]
command = sys.argv[4 + mount_count:]
try:
    maximum = os.sysconf("SC_OPEN_MAX")
except (ValueError, OSError):
    maximum = 65536
import subprocess
try:
    process = subprocess.Popen([bwrap_bin, *mounts, "--", *command], close_fds=True)
    raise SystemExit(process.wait(timeout=timeout_seconds))
except subprocess.TimeoutExpired:
    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    raise SystemExit(124)
' "$BWRAP_BIN" "$timeout_seconds" "${#mounts[@]}" \
    "${mounts[@]}" "$executable" "$@"
}

if [ "$doctor" -eq 1 ]; then
  [ $# -eq 0 ] || { echo "--doctor does not accept a command"; exit 2; }
  [ "${#writes[@]}" -eq 0 ] || { echo "--doctor does not accept --write"; exit 2; }
  doctor_python="$(resolve_command python3)" || { echo "python3 is outside permitted toolchain roots"; exit 1; }
  launch "$doctor_python" -c 'import os, socket
assert os.getcwd() == "/workspace"
assert os.environ["HOME"] == "/home/tutor"
assert not os.path.exists("/home/tutor/.ssh")
assert not os.path.exists("/nix/var/nix/daemon-socket/socket")
s = socket.socket()
s.settimeout(0.2)
try:
    s.connect(("1.1.1.1", 53))
except OSError:
    pass
else:
    raise SystemExit("network unexpectedly available")
print("OK sandbox is offline with empty home and read-only worktree default")'
  exit $?
fi

[ $# -gt 0 ] || { echo "missing command after --"; usage; exit 2; }
executable="$(resolve_command "$1")" || {
  echo "command must resolve inside the worktree, /usr, or /nix/store: $1"
  exit 2
}
shift
launch "$executable" "$@"
