#!/usr/bin/env bash
# Contract test for the Personal Dev Tutor profile product.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/profiles/personal-dev-tutor.yml"
SKILL="$ROOT/plugins/dev-skills/skills/personal-development-mentor/SKILL.md"
SOUL="$ROOT/templates/personal-dev-tutor-SOUL.md"
PROMPT="$ROOT/templates/personal-codex-lane-prompt.md"
DOC="$ROOT/docs/personal-dev-tutor.md"
D2="$ROOT/docs/diagrams/personal-dev-tutor-architecture.d2"
GRAPH="$ROOT/scripts/personal-tutor-graph.sh"
OUTPUT="$ROOT/scripts/personal-tutor-output.sh"
SANDBOX="$ROOT/scripts/personal-tutor-sandbox.sh"

required_files=(
  "$PROFILE"
  "$SKILL"
  "$SOUL"
  "$PROMPT"
  "$DOC"
  "$D2"
  "$ROOT/scripts/personal-tutor-install.sh"
  "$ROOT/scripts/personal-tutor-doctor.sh"
  "$ROOT/scripts/personal-tutor-status.sh"
  "$ROOT/scripts/personal-tutor-delegate.sh"
  "$ROOT/scripts/personal-tutor-audit.sh"
  "$GRAPH"
  "$OUTPUT"
  "$SANDBOX"
  "$ROOT/scripts/render-diagrams.sh"
  "$ROOT/docs/diagrams/personal-dev-tutor-flow.mmd"
)

init_test_repo() {
  local repo="$1" name="$2" email="$3"
  git -C "$repo" init -q
  git -C "$repo" config user.name "$name"
  git -C "$repo" config user.email "$email"
}

commit_test_repo() {
  local repo="$1" message="$2"
  shift 2
  git -C "$repo" add "$@"
  git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
    commit --no-gpg-sign -q -m "$message"
}

assert_rejected() {
  local message="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL $message"
    exit 1
  fi
}

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "FAIL missing ${file#$ROOT/}"; exit 1; }
done

grep -q '^profile: personal-dev-tutor$' "$PROFILE"
grep -q 'delegate_session: personal' "$PROFILE"
grep -q 'worker_runtime: codex' "$PROFILE"
grep -q 'workflow: gsd' "$PROFILE"
grep -q 'personal-development-mentor' "$PROFILE"
grep -q 'gsd-new-project' "$PROFILE"
grep -q 'gsd-progress' "$PROFILE"
grep -q 'provider: graphify' "$PROFILE"
grep -q 'provider: context7' "$PROFILE"
grep -q 'default_mode: local-ast-code-only' "$PROFILE"
grep -q '^  - java-development$' "$PROFILE"
python3 - "$PROFILE" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
profile_section = text.split("include_skills:\n", 1)[1].split("codex_worker_skills:\n", 1)[0]
profile_skills = [line.removeprefix("  - ").strip() for line in profile_section.splitlines() if line.startswith("  - ")]
if len(profile_skills) != 19:
    raise SystemExit(f"FAIL Personal Tutor must expose 19 bounded capabilities, found {len(profile_skills)}")
for forbidden in ("orchestrate", "ai-workflow-orchestrator", "find-skills"):
    if forbidden in profile_skills:
        raise SystemExit(f"FAIL Hermes profile contains competing authority: {forbidden}")
worker_section = text.split("codex_worker_skills:\n", 1)[1].split("requires_gsd_skills:\n", 1)[0]
for forbidden in ("personal-development-mentor", "orchestrate", "ai-workflow-orchestrator", "find-skills"):
    if forbidden in worker_section:
        raise SystemExit(f"FAIL Codex worker set contains role-expanding skill: {forbidden}")
if worker_section.count("  - java-development\n") != 1:
    raise SystemExit("FAIL Codex worker set must contain java-development exactly once")
external_section = text.split("external_skills:\n", 1)[1].split("requires_gsd_skills:\n", 1)[0]
external_skills = [line.removeprefix("  - ").strip() for line in external_section.splitlines() if line.startswith("  - ")]
if external_skills != ["graphify", "caveman", "ponytail"]:
    raise SystemExit(f"FAIL external baseline mismatch: {external_skills}")
PY

grep -q '^name: personal-development-mentor$' "$SKILL"
grep -qi 'teach-back' "$SKILL"
grep -qi 'cognitive debt' "$SKILL"
grep -qi 'Mermaid' "$SKILL"
grep -qi 'D2' "$SKILL"
grep -qi 'Graphify' "$SKILL"
grep -qi 'Context7' "$SKILL"
grep -q 'personal:\*' "$SOUL"
grep -q 'Never directly edit product source code' "$SOUL"
grep -q 'personal-tutor-graph refresh' "$SOUL"
grep -q 'Normal development runs directly on the trusted workstation' "$SOUL"
grep -q 'Its absence or incompatibility must never' "$SOUL"
grep -q 'Context7' "$PROMPT"
grep -q 'Graphify' "$PROMPT"
grep -q 'personal-tutor-output' "$PROMPT"
grep -q 'Default to direct execution on the trusted workstation' "$PROMPT"
grep -q 'continue through the trusted workstation path' "$PROMPT"
grep -q 'Codex' "$PROMPT"
grep -q 'Learning checkpoint' "$PROMPT"

grep -q '```mermaid' "$DOC"
grep -q 'personal-dev-tutor-architecture.d2' "$DOC"
grep -q '^flowchart TB$' "$ROOT/docs/diagrams/personal-dev-tutor-flow.mmd"
grep -q 'Graphify local AST cache' "$ROOT/docs/diagrams/personal-dev-tutor-flow.mmd"
grep -q 'Context7 upstream library docs' "$ROOT/docs/diagrams/personal-dev-tutor-flow.mmd"
grep -q 'graphify install --platform hermes' "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'install --platform codex' "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'install-hermes-workhorse.sh.*--profile.*PROFILE' "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'PERSONAL_TUTOR_BASELINE_SKILLS' "$ROOT/scripts/personal-tutor-lib.sh"
grep -q 'baseline skill available:.*baseline_skill' "$ROOT/scripts/personal-tutor-doctor.sh"
grep -q 'graphifyy==\$PERSONAL_TUTOR_GRAPHIFY_VERSION' "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'mcp_servers.context7.url' "$ROOT/scripts/personal-tutor-install.sh"
grep -q 'PERSONAL_TUTOR_GRAPH_CACHE_ROOT' "$GRAPH"
grep -q -- '--code-only' "$GRAPH"
grep -q 'GRAPHIFY_OUT=' "$GRAPH"
grep -q 'XDG_CACHE_HOME' "$GRAPH"
grep -q 'provider: bounded-command-evidence' "$PROFILE"
grep -q 'context_mode_package: not-installed' "$PROFILE"
grep -q 'provider: bubblewrap-offline-verification' "$PROFILE"
grep -q '^sandbox_policy: trusted-development$' "$PROFILE"
grep -q 'default_execution: trusted-host' "$PROFILE"
grep -q 'trusted_workstation_network: allowed' "$PROFILE"
grep -q 'PERSONAL_TUTOR_OUTPUT_CACHE_ROOT' "$OUTPUT"
grep -q 'kind" = security' "$OUTPUT"
grep -q 'bounded-critical-preview' "$OUTPUT"
grep -q 'for helper in doctor status delegate audit graph output sandbox install' "$ROOT/scripts/personal-tutor-install.sh"
if grep -q '^for command in .*bwrap' "$ROOT/scripts/personal-tutor-install.sh"; then
  echo "FAIL optional Bubblewrap is still an installer prerequisite"
  exit 1
fi
grep -q 'optional offline sandbox unavailable; normal trusted-host development is unaffected' \
  "$ROOT/scripts/personal-tutor-doctor.sh"

for script in "$ROOT"/scripts/personal-tutor-*.sh; do
  bash -n "$script"
done

branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
contract_lane_cache="$(mktemp -d)"
delegate_output="$(PERSONAL_TUTOR_LANE_CACHE_ROOT="$contract_lane_cache" \
  $ROOT/scripts/personal-tutor-delegate.sh contract-smoke \
  --repo "$ROOT" \
  --branch "$branch" \
  --concept "bounded delegation" \
  --goal "Render a safe Codex learning unit." \
  --allowed "README.md" \
  --criteria "Prompt renders|No tmux input is sent|Placeholders are replaced" \
  --verification "npm run validate" \
  --dry-run)"
prompt_path="${delegate_output#*prompt=}"
prompt_path="${prompt_path%% concept=*}"
[[ -f "$prompt_path" ]] || { echo "FAIL delegation dry-run did not render a prompt"; exit 1; }
if grep -qE '<(REPO_ABS_PATH|WORKTREE_SHELL_PATH|BRANCH_EXPECTED|GOAL_PARAGRAPH|AC1|ALLOWED_PATHS)>' "$prompt_path"; then
  echo "FAIL rendered prompt contains unresolved placeholders"
  exit 1
fi
python3 - "$prompt_path" <<'PY'
from pathlib import Path
import stat
import sys

mode = stat.S_IMODE(Path(sys.argv[1]).stat().st_mode)
if mode != 0o600:
    raise SystemExit(f"FAIL rendered prompt permissions are {mode:o}, expected 600")
PY

fixture="$(mktemp -d)"
failure_root="$(mktemp -d)"
cleanup() { rm -f "$prompt_path"; rm -rf "$fixture" "$failure_root" "$contract_lane_cache"; }
trap cleanup EXIT
init_test_repo "$fixture" "Personal Tutor Test" "personal-tutor-test@example.invalid"
printf 'baseline\n' > "$fixture/example.txt"
commit_test_repo "$fixture" baseline example.txt
fixture_branch="$(git -C "$fixture" rev-parse --abbrev-ref HEAD)"
fixture_head="$(git -C "$fixture" rev-parse HEAD)"

output_cache="$failure_root/output-cache"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --doctor --repo "$fixture" >/dev/null

success_preview="$failure_root/success-preview.txt"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label noisy-success --head 5 --tail 5 -- \
  python3 -c 'for i in range(1, 301): print(f"fixture-line-{i:03d}")' \
  > "$success_preview"
grep -q '^status: 0$' "$success_preview"
grep -q '^display: bounded-success-preview$' "$success_preview"
grep -q '^omitted_lines: 290$' "$success_preview"
success_transcript="$(awk '/^transcript: / {sub(/^transcript: /, ""); print; exit}' "$success_preview")"
[[ "$success_transcript" = "$output_cache"/* ]] || { echo "FAIL output transcript is not in external cache"; exit 1; }
[ "$(stat -c '%a' "$success_transcript")" = 600 ] || { echo "FAIL output transcript is not mode 600"; exit 1; }
[ "$(wc -l < "$success_transcript" | tr -d ' ')" = 300 ] || { echo "FAIL exact transcript lost lines"; exit 1; }
reported_sha="$(awk '/^sha256: / {print $2; exit}' "$success_preview")"
[ "$reported_sha" = "$(sha256sum "$success_transcript" | cut -d' ' -f1)" ] || { echo "FAIL transcript hash is incorrect"; exit 1; }
[ "$(wc -c < "$success_preview" | tr -d ' ')" -lt "$(wc -c < "$success_transcript" | tr -d ' ')" ] || {
  echo "FAIL bounded preview did not reduce successful output"
  exit 1
}

huge_line_preview="$failure_root/huge-line-preview.txt"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label huge-line -- \
  python3 -c 'print("x" * 100000)' > "$huge_line_preview"
grep -q '^display: bounded-success-preview$' "$huge_line_preview"
grep -q '^preview_basis: bytes$' "$huge_line_preview"
grep -q '^omitted_bytes: 67233$' "$huge_line_preview"

failure_preview="$failure_root/failure-preview.txt"
set +e
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label expected-failure -- \
  python3 -c '[(print(f"EXACT_FAILURE_EVIDENCE_{i:03d}")) for i in range(1, 301)]; raise SystemExit(7)' \
  > "$failure_preview"
failure_status=$?
set -e
[ "$failure_status" -eq 7 ] || { echo "FAIL output helper did not preserve failure status"; exit 1; }
grep -q '^display: sanitized-full$' "$failure_preview"
grep -q '^EXACT_FAILURE_EVIDENCE_150$' "$failure_preview"

security_preview="$failure_root/security-preview.txt"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label security-evidence --kind security -- \
  python3 -c 'for i in range(1, 101): print(f"SECURITY_FINDING_{i:03d}")' \
  > "$security_preview"
grep -q '^display: sanitized-full$' "$security_preview"
grep -q '^SECURITY_FINDING_050$' "$security_preview"

scanner_stub="$failure_root/semgrep"
printf '#!/usr/bin/env sh\npython3 -c '\''[print(f"SCANNER_FINDING_{i:03d}") for i in range(1, 301)]'\''\n' > "$scanner_stub"
chmod +x "$scanner_stub"
if PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label scanner-misclassified -- \
  "$scanner_stub" >/dev/null 2>&1; then
  echo "FAIL known security scanner ran without --kind security"
  exit 1
fi
scanner_preview="$failure_root/scanner-preview.txt"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label scanner-full --kind security -- \
  "$scanner_stub" > "$scanner_preview"
grep -q '^display: sanitized-full$' "$scanner_preview"
grep -q '^SCANNER_FINDING_150$' "$scanner_preview"

malicious_preview="$failure_root/malicious-preview.txt"
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label control-output -- \
  python3 -c 'import sys; sys.stdout.buffer.write(b"SAFE\x1b]2;SPOOF\x07END\x00 RAW_C1\x9b UTF8_C1\xc2\x9b BIDI\xe2\x80\xae UNICODE_\xc3\xa9\n")' \
  > "$malicious_preview"
python3 - "$malicious_preview" <<'PY'
from pathlib import Path
import sys
data = Path(sys.argv[1]).read_bytes()
assert b"\x1b" not in data and b"\x07" not in data and b"\x00" not in data and b"\x9b" not in data
assert b"\xc2\x9b" not in data and b"\xe2\x80\xae" not in data
assert b"\\x1b" in data and b"\\x07" in data and b"\\x00" in data
assert data.count(b"\\x9b") == 2 and b"\\u202e" in data
assert b"UNICODE_\xc3\xa9" in data
PY

large_failure_preview="$failure_root/large-failure-preview.txt"
set +e
PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$output_cache" \
  "$OUTPUT" --repo "$fixture" --label large-failure -- \
  python3 -c 'import sys; sys.stdout.write("F" * 2000000); raise SystemExit(9)' \
  > "$large_failure_preview"
large_failure_status=$?
set -e
[ "$large_failure_status" -eq 9 ] || { echo "FAIL large failure status changed"; exit 1; }
grep -q '^display: bounded-critical-preview$' "$large_failure_preview"
[ "$(wc -c < "$large_failure_preview" | tr -d ' ')" -lt 40000 ] || {
  echo "FAIL oversized failure flooded the display"
  exit 1
}

if PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$fixture/unsafe-cache" \
  "$OUTPUT" --doctor --repo "$fixture" >/dev/null 2>&1; then
  echo "FAIL output helper accepted a cache inside the worktree"
  exit 1
fi
mkdir -p "$fixture/nested"
if PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$fixture/nested-cache" \
  "$OUTPUT" --doctor --repo "$fixture/nested" >/dev/null 2>&1; then
  echo "FAIL nested --repo bypassed the worktree cache boundary"
  exit 1
fi

symlink_cache="$failure_root/symlink-cache"
mkdir -p "$symlink_cache" "$fixture/symlink-target"
fixture_id="$(printf '%s' "$fixture" | sha256sum | cut -c1-16)"
ln -s "$fixture/symlink-target" "$symlink_cache/$fixture_id"
if PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$symlink_cache" \
  "$OUTPUT" --doctor --repo "$fixture" >/dev/null 2>&1; then
  echo "FAIL output helper followed a symlinked repository cache"
  exit 1
fi

chmod_failure_bin="$failure_root/chmod-failure-bin"
mkdir -p "$chmod_failure_bin"
printf '#!/usr/bin/env sh\nexit 1\n' > "$chmod_failure_bin/chmod"
chmod +x "$chmod_failure_bin/chmod"
if PERSONAL_TUTOR_OUTPUT_CACHE_ROOT="$failure_root/chmod-failure-cache" \
  PATH="$chmod_failure_bin:$PATH" "$OUTPUT" --doctor --repo "$fixture" >/dev/null 2>&1; then
  echo "FAIL output helper ignored private-cache permission failure"
  exit 1
fi

graph_repo="$failure_root/graph-repo"
graph_bin="$failure_root/graph-bin"
graph_cache="$failure_root/graph-cache"
mkdir -p "$graph_repo" "$graph_bin"
init_test_repo "$graph_repo" "Graph Contract Test" "graph-test@example.invalid"
printf 'class GraphFixture {}\n' > "$graph_repo/GraphFixture.java"
commit_test_repo "$graph_repo" baseline GraphFixture.java
cat > "$graph_bin/graphify" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --version ]; then printf 'graphify 0.9.25\n'; exit 0; fi
if [ "${1:-}" = extract ]; then
  shift
  out=""
  while [ $# -gt 0 ]; do
    if [ "$1" = --out ]; then out="$2"; shift 2; else shift; fi
  done
  mkdir -p "$out/graphify-out"
  printf '{}\n' > "$out/graphify-out/graph.json"
  exit 0
fi
printf 'stub-result\n'
SH
chmod +x "$graph_bin/graphify"
PATH="$graph_bin:$PATH" PERSONAL_TUTOR_GRAPH_CACHE_ROOT="$graph_cache" \
  "$GRAPH" refresh --repo "$graph_repo" >/dev/null
PATH="$graph_bin:$PATH" PERSONAL_TUTOR_GRAPH_CACHE_ROOT="$graph_cache" \
  "$GRAPH" status --repo "$graph_repo" | grep -q '^status=fresh$'
rm "$graph_repo/GraphFixture.java"
PATH="$graph_bin:$PATH" PERSONAL_TUTOR_GRAPH_CACHE_ROOT="$graph_cache" \
  "$GRAPH" status --repo "$graph_repo" | grep -q '^status=stale$'
if PATH="$graph_bin:$PATH" PERSONAL_TUTOR_GRAPH_CACHE_ROOT="$graph_repo/.graph-cache" \
  "$GRAPH" refresh --repo "$graph_repo" >/dev/null 2>&1; then
  echo "FAIL graph helper accepted a cache inside the worktree"
  exit 1
fi
[ ! -e "$graph_repo/.graph-cache" ] || { echo "FAIL graph helper polluted worktree"; exit 1; }

sandbox_fixture="$failure_root/sandbox-fixture"
mkdir -p "$sandbox_fixture/writable"
init_test_repo "$sandbox_fixture" "Sandbox Contract Test" "sandbox-test@example.invalid"
printf 'read-only-baseline\n' > "$sandbox_fixture/tracked.txt"
printf 'writable-baseline\n' > "$sandbox_fixture/writable/result.txt"
commit_test_repo "$sandbox_fixture" baseline .
if ! command -v bwrap >/dev/null 2>&1; then
  sandbox_available=0
  echo "SKIP optional Bubblewrap sandbox is not installed"
elif timeout 10 bwrap --die-with-parent --unshare-user --unshare-pid --unshare-net \
  --ro-bind / / --proc /proc --dev /dev -- /bin/true >/dev/null 2>&1; then
  sandbox_available=1
else
  sandbox_available=0
  echo "SKIP optional Bubblewrap sandbox is not operable on this host"
fi

if [ "$sandbox_available" -eq 1 ]; then
"$SANDBOX" --doctor --repo "$sandbox_fixture" >/dev/null
fake_boundary_bin="$failure_root/fake-boundary-bin"
mkdir -p "$fake_boundary_bin"
printf '#!/usr/bin/env sh\nprintf fake-bwrap-ran > "%s"\nexit 0\n' \
  "$failure_root/fake-bwrap-ran" > "$fake_boundary_bin/bwrap"
chmod +x "$fake_boundary_bin/bwrap"
PATH="$fake_boundary_bin:$PATH" "$SANDBOX" --doctor --repo "$sandbox_fixture" >/dev/null
[ ! -e "$failure_root/fake-bwrap-ran" ] || {
  echo "FAIL sandbox doctor used a caller-controlled bwrap"
  exit 1
}
if "$SANDBOX" --repo "$sandbox_fixture" -- python3 -c \
  'open("tracked.txt", "w").write("sandbox escaped")' >/dev/null 2>&1; then
  echo "FAIL sandbox default allowed a worktree write"
  exit 1
fi
grep -q '^read-only-baseline$' "$sandbox_fixture/tracked.txt"
"$SANDBOX" --repo "$sandbox_fixture" --write writable -- python3 -c \
  'open("writable/result.txt", "w").write("explicit-write-pass\n")'
grep -q '^explicit-write-pass$' "$sandbox_fixture/writable/result.txt"
if "$SANDBOX" --repo "$sandbox_fixture" --write . -- python3 -c \
  'open(".git/HEAD", "w").write("sandbox escaped")' >/dev/null 2>&1; then
  echo "FAIL sandbox broad write made Git metadata writable"
  exit 1
fi
git -C "$sandbox_fixture" fsck --no-dangling >/dev/null
mkdir -p "$sandbox_fixture/nested/.git"
printf 'nested-metadata\n' > "$sandbox_fixture/nested/.git/HEAD"
if "$SANDBOX" --repo "$sandbox_fixture" --write . -- python3 -c \
  'open("nested/.git/HEAD", "w").write("sandbox escaped")' >/dev/null 2>&1; then
  echo "FAIL sandbox broad write made nested Git metadata writable"
  exit 1
fi
grep -q '^nested-metadata$' "$sandbox_fixture/nested/.git/HEAD"
linked_sandbox_fixture="$failure_root/sandbox-linked-worktree"
git -C "$sandbox_fixture" worktree add --detach -q "$linked_sandbox_fixture" HEAD
"$SANDBOX" --repo "$linked_sandbox_fixture" -- git rev-parse --is-inside-work-tree |
  grep -q '^true$'
if "$SANDBOX" --repo "$linked_sandbox_fixture" -- \
  git config personal-tutor-sandbox.write-test enabled >/dev/null 2>&1; then
  echo "FAIL linked-worktree Git metadata was writable"
  exit 1
fi
test -z "$(git -C "$sandbox_fixture" config --get personal-tutor-sandbox.write-test || true)"
PERSONAL_TUTOR_SANDBOX_SECRET_SENTINEL=must-not-cross \
  "$SANDBOX" --repo "$sandbox_fixture" -- python3 -c \
  'import os; assert "PERSONAL_TUTOR_SANDBOX_SECRET_SENTINEL" not in os.environ'
printf 'CALLER_INPUT' | "$SANDBOX" --repo "$sandbox_fixture" -- python3 -c \
  'import sys; assert sys.stdin.read() == "CALLER_INPUT"'
set +e
"$SANDBOX" --repo "$sandbox_fixture" --timeout 1 -- python3 -c \
  'import time; time.sleep(10)' >/dev/null 2>&1
sandbox_timeout_status=$?
set -e
[ "$sandbox_timeout_status" -eq 124 ] || {
  echo "FAIL sandbox timeout returned $sandbox_timeout_status, expected 124"
  exit 1
}
timeout_started="$(date +%s)"
set +e
"$SANDBOX" --repo "$sandbox_fixture" --timeout 1 -- python3 -c \
  'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)' \
  >/dev/null 2>&1
stubborn_timeout_status=$?
set -e
timeout_elapsed=$(( $(date +%s) - timeout_started ))
[ "$stubborn_timeout_status" -eq 124 ] && [ "$timeout_elapsed" -lt 8 ] || {
  echo "FAIL sandbox did not kill a SIGTERM-ignoring command: status=$stubborn_timeout_status elapsed=$timeout_elapsed"
  exit 1
}
ln -s /tmp "$sandbox_fixture/writable-link"
if "$SANDBOX" --repo "$sandbox_fixture" --write writable-link -- true >/dev/null 2>&1; then
  echo "FAIL sandbox accepted a symlinked write path"
  exit 1
fi
mkdir -p "$sandbox_fixture/real-target/subdir" "$sandbox_fixture/symlink-parent"
ln -s ../real-target "$sandbox_fixture/symlink-parent/link"
if "$SANDBOX" --repo "$sandbox_fixture" --write symlink-parent/link/subdir -- true >/dev/null 2>&1; then
  echo "FAIL sandbox accepted an intermediate symlink in a write path"
  exit 1
fi
if "$SANDBOX" --repo "$sandbox_fixture" --write /tmp -- true >/dev/null 2>&1; then
  echo "FAIL sandbox accepted an absolute write path"
  exit 1
fi
if "$SANDBOX" --repo "$sandbox_fixture" --write .git/../writable -- true >/dev/null 2>&1; then
  echo "FAIL sandbox accepted Git metadata traversal in a write path"
  exit 1
fi
fi

failing_bin="$failure_root/failing-bin"
failure_tmp="$failure_root/failure-tmp"
failure_home="$failure_root/failure-home"
mkdir -p "$failing_bin" "$failure_tmp" "$failure_home"
printf '#!/usr/bin/env sh\nexit 1\n' > "$failing_bin/python3"
chmod +x "$failing_bin/python3"
if PERSONAL_TUTOR_USER_HOME="$failure_home" PATH="$failing_bin:$PATH" TMPDIR="$failure_tmp" \
  "$ROOT/scripts/personal-tutor-delegate.sh" render-failure \
  --repo "$ROOT" --branch "$branch" --concept "temporary-file safety" \
  --goal "Rendering must fail and clean up." --allowed "README.md" \
  --criteria "No temporary prompt remains" --verification "test -f README.md" \
  --dry-run >/dev/null 2>&1; then
  echo "FAIL delegation unexpectedly survived renderer failure"
  exit 1
fi
if compgen -G "$failure_tmp/personal-dev-tutor-render-failure.*.md" >/dev/null; then
  echo "FAIL renderer failure left a temporary prompt"
  exit 1
fi

if "$ROOT/scripts/personal-tutor-delegate.sh" wrong-worktree \
  --repo "$ROOT" --worktree "$fixture" --branch "$fixture_branch" \
  --concept "worktree isolation" --goal "This must not delegate." \
  --allowed "example.txt" --criteria "Delegation is rejected" \
  --verification "test -s example.txt" --dry-run >/dev/null 2>&1; then
  echo "FAIL delegation accepted a worktree from another repository"
  exit 1
fi

audit_delegate_output="$(PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" \
  "$ROOT/scripts/personal-tutor-delegate.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --concept "baseline attribution" \
  --goal "Change the fixture after a baseline is recorded." --allowed "example.txt" \
  --criteria "The file changes|Verification passes" \
  --verification "test -s example.txt" --dry-run)"
audit_prompt_path="${audit_delegate_output#*prompt=}"
audit_prompt_path="${audit_prompt_path%% concept=*}"
rm -f "$audit_prompt_path"

assert_rejected "audit approved a unit with no changed files" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes" --evidence "diff evidence" \
  --verification "test -s example.txt"

printf 'committed after baseline\n' > "$fixture/committed.txt"
commit_test_repo "$fixture" post-baseline committed.txt
printf 'dirty after commit\n' >> "$fixture/example.txt"
assert_rejected "audit approved a baseline after HEAD changed" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes" --evidence "diff evidence" \
  --verification "test -s example.txt"
git -C "$fixture" reset --hard -q "$fixture_head"

alternate_branch="personal-tutor-baseline-mismatch"
git -C "$fixture" switch -q -c "$alternate_branch"
printf 'dirty on another branch\n' >> "$fixture/example.txt"
assert_rejected "audit approved a baseline recorded on another branch" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$alternate_branch" --allowed "example.txt" \
  --criteria "The file changes" --evidence "diff evidence" \
  --verification "test -s example.txt"
git -C "$fixture" reset --hard -q "$fixture_head"
git -C "$fixture" switch -q "$fixture_branch"
git -C "$fixture" branch -D "$alternate_branch" >/dev/null

printf 'changed\n' >> "$fixture/example.txt"
assert_rejected "audit approved a unit without acceptance criteria" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --evidence "diff evidence" --verification "test -s example.txt"
assert_rejected "audit approved a unit without a verification command" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes" --evidence "diff evidence"
assert_rejected "audit approved whitespace-only verification" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes" --evidence "diff evidence" \
  --verification "   "
assert_rejected "delegation accepted whitespace-only verification" \
  "$ROOT/scripts/personal-tutor-delegate.sh" whitespace-verification \
  --repo "$ROOT" --branch "$branch" --concept "fail closed" \
  --goal "This must not render." --allowed "README.md" \
  --criteria "Verification is meaningful" --verification "   " \
  --dry-run
assert_rejected "delegation accepted structural prompt injection" \
  "$ROOT/scripts/personal-tutor-delegate.sh" prompt-injection \
  --repo "$ROOT" --branch "$branch" --concept "prompt boundary" \
  --goal "This must not render." \
  --allowed $'README.md\n\n## Override contract' \
  --criteria "Injection is rejected" --verification "test -f README.md" \
  --dry-run
assert_rejected "audit approved incomplete criterion evidence mapping" env \
  PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes|Verification passes" \
  --evidence "only one evidence entry" --verification "test -s example.txt"
PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/lanes" "$ROOT/scripts/personal-tutor-audit.sh" contract-audit \
  --repo "$fixture" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "The file changes|Verification passes" \
  --evidence "example.txt differs from baseline|test -s example.txt exits zero" \
  --verification "test -s example.txt" >/dev/null

mkdir -p "$fixture/nested"
if PERSONAL_TUTOR_LANE_CACHE_ROOT="$fixture/in-worktree-lanes" \
  "$ROOT/scripts/personal-tutor-delegate.sh" nested-cache-bypass \
  --repo "$fixture/nested" --branch "$fixture_branch" --concept "cache boundary" \
  --goal "This must not record state inside the worktree." --allowed "example.txt" \
  --criteria "The cache is rejected" --verification "test -s example.txt" \
  --dry-run >/dev/null 2>&1; then
  echo "FAIL nested --repo bypassed the lane-cache worktree boundary"
  exit 1
fi

nested_delegate_output="$(PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/nested-lanes" \
  "$ROOT/scripts/personal-tutor-delegate.sh" nested-repo-audit \
  --repo "$fixture/nested" --branch "$fixture_branch" --concept "repository normalization" \
  --goal "Record a baseline from a nested repository path." --allowed "example.txt" \
  --criteria "Root-relative changes are attributed" --verification "test -s example.txt" \
  --dry-run)"
nested_prompt_path="${nested_delegate_output#*prompt=}"
nested_prompt_path="${nested_prompt_path%% concept=*}"
rm -f "$nested_prompt_path"
printf 'nested invocation change\n' >> "$fixture/example.txt"
PERSONAL_TUTOR_LANE_CACHE_ROOT="$failure_root/nested-lanes" \
  "$ROOT/scripts/personal-tutor-audit.sh" nested-repo-audit \
  --repo "$fixture/nested" --branch "$fixture_branch" --allowed "example.txt" \
  --criteria "Root-relative changes are attributed" \
  --evidence "example.txt differs from the nested-path baseline" \
  --verification "test -s example.txt" >/dev/null

# Public examples must remain neutral. Repository-specific deny patterns belong
# in external CI policy rather than being encoded, even obfuscated, in this kit.
grep -q -- '--session team-tutor' "$ROOT/docs/agent-tutor-orchestrator.md"
if grep -RniE 'delegate_session:[[:space:]]*(company|internal|private-org)([[:space:]]|$)' \
  "$ROOT/docs" "$ROOT/profiles" "$ROOT/templates" "$ROOT/scripts"; then
  echo "FAIL personal tutor product contains private organization coupling"
  exit 1
fi

echo "PASS personal-dev-tutor product contract"
