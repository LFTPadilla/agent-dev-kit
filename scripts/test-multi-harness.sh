#!/usr/bin/env bash
# Contract-mode smoke tests for the multi-harness delegate (--task-json, roadmap Fase 1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/overnight-task-kit/skills/multi-harness/scripts/delegate.py"

[ -f "$DELEGATE" ] || { echo 'FAIL delegate.py not found'; exit 1; }
python3 -m py_compile "$DELEGATE"

scratch="$(mktemp -d)"
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

fail() { printf 'FAIL %s\n' "$1"; exit 1; }

# --- fixtures ---------------------------------------------------------------
cat > "$scratch/task-ok.json" <<'JSON'
{
  "task_id": "smoke-ok",
  "objective": "Add a --json flag to overnight-runner init printing the run dir",
  "scope": ["overnight-task-kit/scripts/overnight-runner.mjs"],
  "constraints": ["Stdlib node modules only"],
  "acceptance": ["node overnight-task-kit/scripts/overnight-runner.mjs init --slug demo-json --json"],
  "budget": {"timeout_min": 10}
}
JSON
printf '%s' '{"task_id": "smoke-scope", "objective": "Do something meaningful here", "scope": [], "acceptance": ["true"]}' > "$scratch/task-empty-scope.json"
printf '%s' '{"task_id": "smoke-accept", "objective": "Do something meaningful here", "scope": ["a.py"], "acceptance": []}' > "$scratch/task-empty-acceptance.json"
printf '%s' '{"task_id": "bad slug!", "objective": "Do something meaningful here", "scope": ["a.py"], "acceptance": ["true"]}' > "$scratch/task-bad-slug.json"
printf '%s' '{"task_id": "smoke-missing", "scope": ["a.py"], "acceptance": ["true"]}' > "$scratch/task-missing-objective.json"

# --- unit checks (validators, prompt block, events) -------------------------
python3 - "$DELEGATE" "$scratch" <<'PY'
import importlib.util
import json
import pathlib
import sys

spec = importlib.util.spec_from_file_location("delegate", sys.argv[1])
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)

scratch = pathlib.Path(sys.argv[2])
t = d.load_task_contract(scratch / "task-ok.json")
assert t["budget"] == {"timeout_min": 10}
assert d.TASK_ID_RE.fullmatch("smoke-ok\n") is None
block = d.contract_task_block(t)
for marker in ("TASK: Add a --json flag", "SCOPE: overnight-task-kit", "CONSTRAINTS:", "VERIFICATION:", "FORMAT:", "result.json", "smoke-ok"):
    assert marker in block, marker

ok = {"task_id": "smoke-ok", "status": "done", "notes": "fine"}
assert d.validate_result_contract(ok, "smoke-ok") == ("done", "ok")
assert d.validate_result_contract({"task_id": "smoke-ok", "status": "done"}, "smoke-ok")[0] is None  # missing notes
assert d.validate_result_contract({**ok, "task_id": "other"}, "smoke-ok")[0] is None
assert d.validate_result_contract({**ok, "status": "blocked"}, "smoke-ok")[0] is None  # blocker required
assert d.validate_result_contract({**ok, "status": "blocked", "blocker": "need X"}, "smoke-ok")[0] == "blocked"
assert d.validate_result_contract({**ok, "blocker": "why?"}, "smoke-ok")[0] is None  # done => blocker null
assert d.check_worker_result(scratch / "nowhere", "smoke-ok")[0] == "failed"

root = scratch / "orch"
d.append_event(root, "smoke-ok", "dispatch", "pi:gsd", None)
d.append_event(root, "smoke-ok", "result", "pi:gsd", "done")
lines = (root / ".agent-runs/orchestration/events.jsonl").read_text(encoding="utf-8").splitlines()
assert len(lines) == 2
rec = json.loads(lines[-1])
assert set(rec) == {"ts", "task_id", "event", "harness", "status"}
assert rec["event"] == "result" and rec["status"] == "done" and rec["task_id"] == "smoke-ok"

profile = dict(d.DEFAULT_PROFILES["codex-complex"])
legacy = d.build_prompt("codex-complex", profile, pathlib.Path("/tmp/wt"), "free text", True, contract=None)
assert "Return structured output formatted in compact YAML" in legacy
contract = d.build_prompt("codex-complex", profile, pathlib.Path("/tmp/wt"), block, True, contract=t)
assert "```yaml" not in contract and "FORMAT:" in contract

# verify stale result.json removal
stale_wt = scratch / "stale-wt"
stale_wt.mkdir(parents=True, exist_ok=True)
stale_file = stale_wt / "result.json"
stale_file.write_text("{}", encoding="utf-8")
assert stale_file.is_file()
try:
    stale_file.unlink()
except FileNotFoundError:
    pass
assert not stale_file.is_file()

print("unit checks: OK")
PY

# --- end-to-end dry run on a disposable repo --------------------------------
repo="$scratch/repo"
git init -q "$repo"
git -C "$repo" -c user.email=test@local -c user.name=test commit -q --allow-empty -m init

run_dir="$scratch/runs"
(cd "$repo" && python3 "$DELEGATE" --profile codex-complex --allow-write \
  --task-json "$scratch/task-ok.json" --dry-run --save-dir "$run_dir") \
  > "$scratch/dry.out" 2> "$scratch/dry.err" || fail "valid task.json --dry-run should exit 0"
prompt_md="$run_dir"/*/prompt.md
for marker in "TASK: Add a --json flag" "SCOPE: overnight-task-kit" "VERIFICATION: .*init --slug demo-json --json" "result.json"; do
  grep -q "$marker" $prompt_md || fail "prompt missing marker: $marker"
done
grep -q '.worktrees/smoke-ok' "$run_dir"/*/meta.json || fail "dry run should target the task_id worktree"
[ -d "$repo/.worktrees/smoke-ok" ] || fail "worktree .worktrees/smoke-ok was not created"
[ ! -f "$repo/.agent-runs/orchestration/events.jsonl" ] || fail "dry run must not append events"

# --- invalid contracts are rejected naming the field ------------------------
for fx in task-empty-scope task-empty-acceptance task-bad-slug task-missing-objective; do
  err="$scratch/$fx.err"
  if python3 "$DELEGATE" --profile codex-complex --allow-write --task-json "$scratch/$fx.json" --dry-run --no-save \
    > /dev/null 2> "$err"; then
    fail "$fx.json should be rejected"
  fi
  case "$fx" in
    task-empty-scope) pattern="'scope'" ;;
    task-empty-acceptance) pattern="'acceptance'" ;;
    task-bad-slug) pattern="'task_id'" ;;
    task-missing-objective) pattern="'objective'" ;;
  esac
  grep -q "$pattern" "$err" || fail "$fx error must name $pattern"
done

# --- flag guards ------------------------------------------------------------
if python3 "$DELEGATE" --task-json "$scratch/task-ok.json" --task "free text" --dry-run --no-save \
  > /dev/null 2>&1; then
  fail "--task-json combined with --task must fail"
fi
if (cd "$repo" && python3 "$DELEGATE" --profile codex-complex --allow-write \
  --task-json "$scratch/task-ok.json" --worktree other-slug --dry-run --no-save) > /dev/null 2>&1; then
  fail "--worktree not matching task_id must fail"
fi
if python3 "$DELEGATE" --profile codex-review --allow-write --task-json "$scratch/task-ok.json" --dry-run --no-save \
  > /dev/null 2>&1; then
  fail "contract mode with a read-only profile must fail"
fi

# --- legacy --task keeps working --------------------------------------------
python3 "$DELEGATE" --task-type review --task "free text legacy task" --dry-run --no-save \
  > "$scratch/legacy.out" 2>&1 || fail "legacy --task dry run broke"
grep -q "DRY RUN" "$scratch/legacy.out" || fail "legacy dry run output changed"

echo "test-multi-harness: OK"
