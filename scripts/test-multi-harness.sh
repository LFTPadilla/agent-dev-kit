#!/usr/bin/env bash
# Contract-mode smoke tests for the multi-harness delegate (--task-json, roadmap Fase 1).
set -euo pipefail
# Unit tests stub Herdr and never dispatch to live panes.
unset HERDR_ENV

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/overnight-task-kit/skills/multi-harness/scripts/delegate.py"
HARNESSES="$ROOT/overnight-task-kit/skills/multi-harness/scripts/harnesses.py"

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
import argparse
import contextlib
import io
import json
import os
import pathlib
import stat
import sys

delegate_path = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(delegate_path.parent))
spec = importlib.util.spec_from_file_location("delegate", delegate_path)
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)

scratch = pathlib.Path(sys.argv[2])
harnesses_path = delegate_path.with_name("harnesses.py")
assert harnesses_path.is_file(), "harnesses.py must be the single argv source"
harnesses_spec = importlib.util.spec_from_file_location("harnesses", harnesses_path)
harnesses = importlib.util.module_from_spec(harnesses_spec)
harnesses_spec.loader.exec_module(harnesses)

cwd = pathlib.Path("/tmp/worktree")
prompt = "task prompt"
assert harnesses.has_flag("--model <name>", "--model")
assert not harnesses.has_flag("--modeling --model-extra", "--model")
assert not harnesses.has_flag("--model", "-m")
assert harnesses.command_for({"harness": "codex", "model": "model-x", "mode": "write"}, cwd, prompt, True, True) == [
    "codex", "exec", "--ephemeral", "-C", str(cwd), "-m", "model-x", "--dangerously-bypass-approvals-and-sandbox", prompt
]
assert harnesses.command_for({"harness": "claude", "model": "model-x", "mode": "read"}, cwd, prompt, False, False) == [
    "claude", "-p", prompt, "--model", "model-x", "--permission-mode", "plan"
]
assert harnesses.command_for({"harness": "claude", "model": "model-x", "mode": "write"}, cwd, prompt, True, True) == [
    "claude", "-p", prompt, "--model", "model-x", "--dangerously-skip-permissions"
]
assert harnesses.command_for({"harness": "opencode", "model": "p/m", "agent": "reviewer", "variant": "high", "mode": "read"}, cwd, prompt, False, True) == [
    "opencode", "run", "--dir", str(cwd), "--model", "p/m", "--agent", "reviewer", "--variant", "high", prompt
]
assert harnesses.command_for({"harness": "opencode", "model": "default", "mode": "write"}, cwd, prompt, True, True) == [
    "opencode", "run", "--dir", str(cwd), "--auto", prompt
]
assert harnesses.command_for({"harness": "codex", "model": "model-x", "mode": "write"}, cwd, prompt, True, False) == [
    "codex", "exec", "--ephemeral", "-C", str(cwd), "-m", "model-x", "--sandbox", "workspace-write", prompt
]
assert harnesses.command_for({"harness": "codex", "model": "model-x", "mode": "read"}, cwd, prompt, False, True) == [
    "codex", "exec", "--ephemeral", "-C", str(cwd), "-m", "model-x", prompt
]
assert harnesses.command_for({"harness": "claude", "model": "model-x", "mode": "write"}, cwd, prompt, True, False) == [
    "claude", "-p", prompt, "--model", "model-x", "--permission-mode", "acceptEdits"
]
assert harnesses.command_for({"harness": "claude", "model": "model-x", "mode": "read"}, cwd, prompt, False, True) == [
    "claude", "-p", prompt, "--model", "model-x", "--permission-mode", "plan"
]
assert harnesses.command_for({"harness": "pi", "model": "default", "mode": "read"}, cwd, prompt, False, True) == [
    "pi", "--print", "--no-session", "--mode", "text", "--tools", "read,grep,find,ls", prompt
]
assert harnesses.command_for({"harness": "pi", "model": "p/m", "thinking": "high", "mode": "read"}, cwd, prompt, False, False) == [
    "pi", "--print", "--no-session", "--mode", "text", "--tools", "read,grep,find,ls", "--model", "p/m", "--thinking", "high", prompt
]
assert harnesses.command_for({"harness": "pi", "pi_profile": "lean", "model": "default", "mode": "read"}, cwd, prompt, False, False) == [
    "pi-profile", "lean", "--", "--print", "--no-session", "--mode", "text", "--tools", "read,grep,find,ls", prompt
]
assert {p["harness"] for p in d.DEFAULT_PROFILES.values()} == {"codex", "claude", "pi", "opencode"}

catalog = scratch / "models.json"
catalog.write_text(json.dumps({"models": [{"id": "claude-a"}, {"id": "claude-b"}], "default": "claude-b"}), encoding="utf-8")
assert d.available_models("claude", str(catalog)) == {"claude-a", "claude-b"}
assert d.resolve_dynamic_model("claude", None, "auto", str(catalog)) == "claude-b"
claude_args = argparse.Namespace(
    profile="claude-review", task_type=None, model=None, harness=None, timeout=None,
    pi_profile=None, model_catalog=None,
)
try:
    d.resolve_profile(claude_args)
    raise AssertionError("Claude auto-selection must fail without a model catalog")
except SystemExit as exc:
    assert "--model-catalog" in str(exc) and "--model" in str(exc)
claude_args.model = "claude-explicit"
assert d.resolve_profile(claude_args)[1]["model"] == "claude-explicit"
claude_args.model = None
claude_args.model_catalog = str(catalog)
assert d.resolve_profile(claude_args)[1]["model"] == "claude-b"

mcode_args = argparse.Namespace(
    profile="codex-fast", task_type=None, model=None, harness="mcode", timeout=None,
    pi_profile=None, model_catalog=None, mcode_pane_id=None,
)
try:
    d.resolve_profile(mcode_args)
    raise AssertionError("mcode dispatch must require an explicit pane ID")
except SystemExit as exc:
    assert "--mcode-pane-id" in str(exc)
mcode_args.mcode_pane_id = "pane-mcode"
assert d.resolve_profile(mcode_args)[1]["harness"] == "mcode"

codex_catalog = scratch / "codex-models.json"
codex_catalog.write_text(json.dumps({"models": [{"id": "gpt-2"}, {"id": "gpt-10"}]}), encoding="utf-8")
codex_args = argparse.Namespace(
    profile="codex-complex", task_type=None, model=None, harness=None, timeout=None,
    pi_profile=None, model_catalog=str(codex_catalog),
)
assert d.resolve_profile(codex_args)[1]["model"] == "gpt-10"
codex_args.model_catalog = None
try:
    d.resolve_profile(codex_args)
    raise AssertionError("Codex auto-selection must not guess a catalog source")
except SystemExit as exc:
    assert "--model-catalog" in str(exc) and "--model" in str(exc)

diagnose_catalog = scratch / "diagnose-models.json"
diagnose_catalog.write_text(json.dumps({"models": [{"id": "gpt-10"}, {"id": "claude-a"}], "default": "claude-a"}), encoding="utf-8")
original_find_binary = d.find_binary
original_available_models = d.available_models
original_subprocess_run = d.subprocess.run

def fake_find_binary(names):
    return None if names[0] == "pi-profile" else f"/fake-bin/{names[0]}"

def fake_available_models(harness, model_catalog=None):
    if harness in {"codex", "claude"} and model_catalog:
        return d.load_model_catalog(model_catalog)[0]
    return set()

d.find_binary = fake_find_binary
d.available_models = fake_available_models
d.subprocess.run = lambda argv, **kwargs: d.subprocess.CompletedProcess(argv, 0, "fake-version", "")
try:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        d.diagnose()
    no_catalog_diagnostics = output.getvalue()
    assert "Codex and Claude auto profiles need --model-catalog or explicit --model." in no_catalog_diagnostics
    assert next(line for line in no_catalog_diagnostics.splitlines() if "codex-complex" in line).startswith("UNREADY")
    assert next(line for line in no_catalog_diagnostics.splitlines() if "claude-review" in line).startswith("UNREADY")

    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        d.diagnose(str(diagnose_catalog))
    catalog_diagnostics = output.getvalue()
    assert next(line for line in catalog_diagnostics.splitlines() if "codex-complex" in line).startswith("OK")
    assert next(line for line in catalog_diagnostics.splitlines() if "claude-review" in line).startswith("OK")
finally:
    d.find_binary = original_find_binary
    d.available_models = original_available_models
    d.subprocess.run = original_subprocess_run

pi_profiles = scratch / "pi-profiles"
(pi_profiles / "lean").mkdir(parents=True)
(pi_profiles / "search").mkdir()
(pi_profiles / ".hidden").mkdir()
(pi_profiles / "not-a-profile").write_text("", encoding="utf-8")
previous_pi_profile_dir = os.environ.get("PI_PROFILE_DIR")
os.environ["PI_PROFILE_DIR"] = str(pi_profiles)
try:
    assert d.available_pi_profiles() == ["lean", "search"]
finally:
    if previous_pi_profile_dir is None:
        os.environ.pop("PI_PROFILE_DIR", None)
    else:
        os.environ["PI_PROFILE_DIR"] = previous_pi_profile_dir

herdr_cwd = scratch / "herdr-cwd"
herdr_cwd.mkdir()
agents = [{"agent": "codex", "agent_status": "idle", "pane_id": "pane-idle", "cwd": str(herdr_cwd), "foreground_cwd": str(herdr_cwd)}]
panes = []
agent_read_result = {"text": "integrated agent response"}
foreground_processes = [{"name": "mcode", "argv": ["mcode"], "cmdline": "mcode"}]
reported_process_pane_id = "pane-mcode"
mcode_state = {"prompt_path": None, "prompt_text": None, "marker": None}
fail_mcode_wait = False
herdr_calls = []
real_run = d.subprocess.run
real_dispatch = d.dispatch_with_herdr
real_argv = sys.argv

def stub_herdr(argv, **kwargs):
    herdr_calls.append(argv)
    if argv[1:3] == ["agent", "list"]:
        result = {"agents": agents}
    elif argv[1:3] == ["pane", "list"]:
        result = {"panes": panes}
    elif argv[1:3] == ["pane", "process-info"]:
        result = {"process_info": {"pane_id": reported_process_pane_id, "foreground_processes": foreground_processes}}
    elif argv[1:3] == ["pane", "run"]:
        request = argv[4]
        assert len(request.splitlines()) == 1
        assert request.startswith("Read ") and request.endswith(" and execute it.")
        mcode_state["prompt_path"] = pathlib.Path(request[5:-len(" and execute it.")])
        assert stat.S_IMODE(mcode_state["prompt_path"].stat().st_mode) == 0o600
        mcode_state["prompt_text"] = mcode_state["prompt_path"].read_text(encoding="utf-8")
        assert "review task" in mcode_state["prompt_text"]
        result = {"accepted": True}
    elif argv[1:3] == ["pane", "wait-output"]:
        if fail_mcode_wait:
            return d.subprocess.CompletedProcess(argv, 1, "", "sentinel timeout")
        assert argv[3] == "--regex"
        pattern = argv[4]
        assert pattern.startswith("(?m)^") and pattern.endswith("$")
        mcode_state["marker"] = pattern[len("(?m)^"):-1]
        assert mcode_state["prompt_path"].is_file()
        assert mcode_state["marker"] not in mcode_state["prompt_text"]
        assert "MULTI_HARNESS_DONE_" in mcode_state["prompt_text"]
        assert mcode_state["marker"].removeprefix("MULTI_HARNESS_DONE_") in mcode_state["prompt_text"]
        result = {"accepted": True, "matched": True}
    elif argv[1:3] == ["agent", "read"]:
        result = agent_read_result
    elif argv[1:3] == ["pane", "read"]:
        assert mcode_state["prompt_path"].is_file()
        result = {"text": "mcode pane response"}
    else:
        result = {"accepted": True, "status": "idle", "matched": True}
    return d.subprocess.CompletedProcess(argv, 0, json.dumps({"result": result}), "")

assert d.herdr_response_text({"text": None, "output": "fallback response"}) == "fallback response"

previous_herdr_env = os.environ.get("HERDR_ENV")
os.environ["HERDR_ENV"] = "1"
d.subprocess.run = stub_herdr
try:
    proc = d.dispatch_with_herdr({"harness": "codex"}, herdr_cwd, "review task", 12)
    assert proc.returncode == 0
    assert proc.stdout == "integrated agent response"
    assert herdr_calls == [
        ["herdr", "agent", "list"],
        ["herdr", "agent", "prompt", "pane-idle", "review task", "--wait", "--timeout", "12000"],
        ["herdr", "agent", "read", "pane-idle", "--source", "recent-unwrapped"],
    ]

    agent_read_result = {"status": "idle", "matched": True}
    proc = d.herdr_read_output(["herdr", "agent", "read", "pane-idle", "--source", "recent-unwrapped"])
    assert proc.returncode == 1 and proc.stdout == "" and "no transcript text" in proc.stderr
    agent_read_result = {"text": "integrated agent response"}

    herdr_calls.clear()
    agents[0]["agent_status"] = "blocked"
    assert d.dispatch_with_herdr({"harness": "codex"}, herdr_cwd, "review task", 12) is None
    assert len(herdr_calls) == 1

    herdr_calls.clear()
    agents[0]["agent_status"] = "working"
    assert d.dispatch_with_herdr({"harness": "codex"}, herdr_cwd, "review task", 12) is None
    assert len(herdr_calls) == 1

    herdr_calls.clear()
    agents[0]["agent_status"] = "idle"
    agents[0]["cwd"] = str(scratch / "other-repo")
    assert d.dispatch_with_herdr({"harness": "codex"}, herdr_cwd, "review task", 12) is None
    assert len(herdr_calls) == 1

    panes[:] = [{"agent": None, "agent_status": "unknown", "pane_id": "pane-mcode", "cwd": str(herdr_cwd), "foreground_cwd": str(herdr_cwd), "terminal_title_stripped": "mcode"}]
    herdr_calls.clear()
    proc = d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode")
    assert proc.returncode == 0
    assert proc.stdout == "mcode pane response"
    assert herdr_calls[0] == ["herdr", "pane", "list"]
    assert herdr_calls[1] == ["herdr", "pane", "process-info", "--pane", "pane-mcode"]
    assert herdr_calls[2][:4] == ["herdr", "pane", "run", "pane-mcode"]
    wait_call = herdr_calls[3]
    assert wait_call[:4] == ["herdr", "pane", "wait-output", "--regex"]
    assert mcode_state["marker"] in wait_call[4] and wait_call[5:] == ["pane-mcode", "--timeout", "12000"]
    assert herdr_calls[4] == ["herdr", "pane", "read", "--source", "recent-unwrapped", "pane-mcode"], herdr_calls
    assert not mcode_state["prompt_path"].exists()

    fail_mcode_wait = True
    herdr_calls.clear()
    proc = d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode")
    assert proc.returncode == 1 and not mcode_state["prompt_path"].exists()
    fail_mcode_wait = False

    reported_process_pane_id = "different-pane"
    herdr_calls.clear()
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode") is None
    assert herdr_calls == [
        ["herdr", "pane", "list"],
        ["herdr", "pane", "process-info", "--pane", "pane-mcode"],
    ]
    reported_process_pane_id = "pane-mcode"

    foreground_processes[:] = [{"name": "bash", "argv": ["bash", "-c", "mcode"], "cmdline": "bash -c mcode"}]
    herdr_calls.clear()
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode") is None
    assert herdr_calls == [
        ["herdr", "pane", "list"],
        ["herdr", "pane", "process-info", "--pane", "pane-mcode"],
    ]
    foreground_processes[:] = [{"name": "mcode", "argv": ["mcode"], "cmdline": "mcode"}]

    herdr_calls.clear()
    panes[0]["agent"] = "claude"
    panes[0]["agent_status"] = "idle"
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode") is None
    assert herdr_calls == [["herdr", "pane", "list"]]
    panes[0]["agent"] = None
    panes[0]["agent_status"] = "unknown"

    herdr_calls.clear()
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "other-pane") is None
    assert herdr_calls == [["herdr", "pane", "list"]]

    panes[0]["agent_status"] = "working"
    herdr_calls.clear()
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode") is None
    assert len(herdr_calls) == 1

    panes[0]["agent_status"] = "blocked"
    herdr_calls.clear()
    assert d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode") is None
    assert len(herdr_calls) == 1

    panes[0]["agent_status"] = "unknown"
    herdr_calls.clear()
    proc = d.dispatch_with_herdr({"harness": "mcode"}, herdr_cwd, "review task", 12, "pane-mcode")
    assert proc.returncode == 0
    assert herdr_calls[2][:4] == ["herdr", "pane", "run", "pane-mcode"]

    agents[0].update(agent_status="idle", cwd=str(herdr_cwd), foreground_cwd=str(herdr_cwd))
    local_calls = []
    def local_cli(argv, **kwargs):
        local_calls.append(argv)
        return d.subprocess.CompletedProcess(argv, 0, "local worker response", "")
    def forbidden_default_herdr(*args, **kwargs):
        raise AssertionError("default dispatch must not use Herdr")

    d.subprocess.run = local_cli
    d.dispatch_with_herdr = forbidden_default_herdr
    sys.argv = ["delegate.py", "--profile", "codex-complex", "--model", "codex-test", "--allow-write", "--yolo", "--cwd", str(herdr_cwd), "--task", "local task", "--no-save"]
    output = io.StringIO()
    errors = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
        assert d.main() == 0
    assert len(local_calls) == 1
    assert local_calls[0][0] == "codex" and ["-m", "codex-test"] == local_calls[0][5:7]
    assert "--dangerously-bypass-approvals-and-sandbox" in local_calls[0]
    assert output.getvalue() == "local worker response"
    assert "No safe idle same-directory Herdr agent matched" not in errors.getvalue()

    local_calls.clear()
    sys.argv = ["delegate.py", "--profile", "codex-review", "--model", "codex-test", "--yolo", "--cwd", str(herdr_cwd), "--task", "review task", "--no-save"]
    output = io.StringIO()
    errors = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
        assert d.main() == 0
    assert "--yolo ignored for read-only profile codex-review" in errors.getvalue()
    assert "--dangerously-bypass-approvals-and-sandbox" not in local_calls[0]
    assert "--sandbox" not in local_calls[0]

    sys.argv = ["delegate.py", "--profile", "codex-review", "--model", "codex-test", "--yolo", "--task-json", str(scratch / "task-ok.json"), "--cwd", str(herdr_cwd), "--no-save"]
    try:
        d.main()
        raise AssertionError("--yolo must not elevate a read-only profile to contract mode")
    except SystemExit as exc:
        assert "write-capable" in str(exc)
    assert len(local_calls) == 1

    d.subprocess.run = stub_herdr
    d.dispatch_with_herdr = real_dispatch
    sys.argv = ["delegate.py", "--profile", "codex-review", "--model", "codex-test", "--herdr", "--cwd", str(herdr_cwd), "--task", "review task", "--no-save"]
    try:
        d.main()
        raise AssertionError("--herdr must reject read-only profiles")
    except SystemExit as exc:
        assert "write-capable" in str(exc)

    herdr_calls.clear()
    sys.argv = ["delegate.py", "--profile", "codex-complex", "--model", "codex-test", "--allow-write", "--herdr", "--cwd", str(herdr_cwd), "--task", "write task", "--no-save"]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        assert d.main() == 0
    assert any(call[:4] == ["herdr", "agent", "prompt", "pane-idle"] and "write task" in call[4] and call[-3:] == ["--wait", "--timeout", "2400000"] for call in herdr_calls)
    assert len(local_calls) == 1

    agents[0]["agent_status"] = "working"
    herdr_calls.clear()
    sys.argv = ["delegate.py", "--profile", "codex-complex", "--model", "codex-test", "--allow-write", "--herdr", "--cwd", str(herdr_cwd), "--task", "fallback task", "--no-save"]
    output = io.StringIO()
    errors = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
        assert d.main() == 0
    assert "No safe idle same-directory Herdr agent matched; using the local subprocess." in errors.getvalue()
    assert herdr_calls[0] == ["herdr", "agent", "list"]
    assert any(call and call[0] == "codex" for call in herdr_calls)

    panes[0]["agent_status"] = "working"
    herdr_calls.clear()
    sys.argv = ["delegate.py", "--profile", "codex-complex", "--allow-write", "--herdr", "--harness", "mcode", "--mcode-pane-id", "pane-mcode", "--cwd", str(herdr_cwd), "--task", "mcode task", "--no-save"]
    output = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
        assert d.main() == 2
    assert herdr_calls == [["herdr", "pane", "list"]]

    def missing_herdr(*args, **kwargs):
        raise FileNotFoundError("herdr")
    d.dispatch_with_herdr = missing_herdr
    errors = io.StringIO()
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
        assert d.main() == 127
    assert "Harness executable 'herdr' not found" in errors.getvalue()
    sys.argv = real_argv
    d.subprocess.run = stub_herdr
    d.dispatch_with_herdr = real_dispatch
finally:
    sys.argv = real_argv
    d.dispatch_with_herdr = real_dispatch
    d.subprocess.run = real_run
    if previous_herdr_env is None:
        os.environ.pop("HERDR_ENV", None)
    else:
        os.environ["HERDR_ENV"] = previous_herdr_env

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

print("unit checks: OK")
PY

# --- end-to-end dry run on a disposable repo --------------------------------
repo="$scratch/repo"
git init -q "$repo"
git -C "$repo" -c user.email=test@local -c user.name=test commit -q --allow-empty -m init

run_dir="$scratch/runs"
(cd "$repo" && python3 "$DELEGATE" --profile codex-complex --allow-write \
  --model codex-test --task-json "$scratch/task-ok.json" --dry-run --save-dir "$run_dir") \
  > "$scratch/dry.out" 2> "$scratch/dry.err" || fail "valid task.json --dry-run should exit 0"
for marker in "TASK: Add a --json flag" "SCOPE: overnight-task-kit" "VERIFICATION: .*init --slug demo-json --json" "result.json"; do
  grep -q "$marker" "$scratch/dry.out" || fail "dry-run output missing marker: $marker"
done
grep -q '.worktrees/smoke-ok' "$scratch/dry.out" || fail "dry run should target the task_id worktree"
[ ! -e "$run_dir" ] || fail "dry run must not write run artifacts"
[ ! -e "$repo/.worktrees" ] || fail "dry run must not create a worktree"
[ ! -e "$repo/.worktrees/smoke-ok" ] || fail "dry run must not create a worktree"
[ ! -f "$repo/.agent-runs/orchestration/events.jsonl" ] || fail "dry run must not append events"

# --- real stale-result cleanup through a stub harness ------------------------
printf '%s' '{"task_id":"smoke-b9","objective":"Test stale result cleanup","scope":["test.py"],"acceptance":["true"],"budget":{"timeout_min":1}}' > "$scratch/task-b9.json"
git -C "$repo" worktree add -q -b task/smoke-b9 "$repo/.worktrees/smoke-b9" HEAD
printf '%s\n' '{"task_id":"smoke-b9","status":"failed","notes":"stale","blocker":"stale"}' > "$repo/.worktrees/smoke-b9/result.json"
mkdir -p "$scratch/bin"
cat > "$scratch/bin/codex" <<'SH'
#!/usr/bin/env sh
if [ -e result.json ]; then
  echo 'stale result was not removed' >&2
  exit 71
fi
printf '%s\n' '{"task_id":"smoke-b9","status":"done","notes":"fresh result","blocker":null}' > result.json
SH
chmod +x "$scratch/bin/codex"
PATH="$scratch/bin:$PATH" python3 "$DELEGATE" --profile codex-complex --allow-write \
  --model codex-test --task-json "$scratch/task-b9.json" --worktree smoke-b9 --cwd "$repo" --no-save \
  > "$scratch/b9.out" 2> "$scratch/b9.err" || fail "stub worker did not complete real result cleanup test"

# --- invalid contracts are rejected naming the field ------------------------
for fx in task-empty-scope task-empty-acceptance task-bad-slug task-missing-objective; do
  err="$scratch/$fx.err"
  if python3 "$DELEGATE" --profile codex-complex --allow-write --model codex-test --task-json "$scratch/$fx.json" --dry-run --no-save \
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
if python3 "$DELEGATE" --task-json "$scratch/task-ok.json" --task "free text" --model codex-test --dry-run --no-save \
  > /dev/null 2>&1; then
  fail "--task-json combined with --task must fail"
fi
if (cd "$repo" && python3 "$DELEGATE" --profile codex-complex --allow-write \
  --model codex-test --task-json "$scratch/task-ok.json" --worktree other-slug --dry-run --no-save) > /dev/null 2>&1; then
  fail "--worktree not matching task_id must fail"
fi
if python3 "$DELEGATE" --profile codex-review --allow-write --model codex-test --task-json "$scratch/task-ok.json" --dry-run --no-save \
  > /dev/null 2>&1; then
  fail "contract mode with a read-only profile must fail"
fi

# --- legacy --task keeps working --------------------------------------------
python3 "$DELEGATE" --task-type review --model codex-test --task "free text legacy task" --dry-run --no-save \
  > "$scratch/legacy.out" 2>&1 || fail "legacy --task dry run broke"
grep -q "DRY RUN" "$scratch/legacy.out" || fail "legacy dry run output changed"

# --- actual binary flag conformance ------------------------------------------
python3 - "$HARNESSES" <<'PY'
import importlib.util
import shutil
import subprocess
import sys

spec = importlib.util.spec_from_file_location("harnesses", sys.argv[1])
harnesses = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harnesses)
for name, capability in harnesses.CAPABILITY_MATRIX.items():
    binary = shutil.which(capability["binary"])
    if not binary:
        print(f"SKIP {name}: {capability['binary']} not found")
        continue
    proc = subprocess.run([binary, *capability["help_args"]], capture_output=True, text=True, check=False)
    help_text = proc.stdout + proc.stderr
    missing = [flag for flag in capability["required_flags"] if not harnesses.has_flag(help_text, flag)]
    if proc.returncode or missing:
        raise SystemExit(f"FAIL {name} help conformance: exit={proc.returncode}, missing={missing}")
    print(f"OK {name} help conformance")
PY

grep -Fq '| `multi-harness` | Cross-Harness Delegation | Delegate bounded subtasks to local harnesses (Pi, OpenCode, Codex CLI, Claude Code CLI, or mcode via Herdr) with prompt isolation and output contracts. | cross-harness requests, comparing harnesses, external-only runtimes |' \
  "$ROOT/docs/skills-catalog.md" || fail "skills catalog still lists a removed harness"

echo "test-multi-harness: OK"
