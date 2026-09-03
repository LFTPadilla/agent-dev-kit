---
name: orchestrate-lite
description: Lightweight native orchestrator. Plans, strictly delegates all execution to host workers, and audits on disk.
---

# orchestrate-lite — Lean Native Orchestrator

Plan, decompose, delegate, and verify. Keep context clean for high-level judgment.

## 1. Zero-Touch Mandate
You **never** write or edit code in the orchestrator session (`write_to_file`, `replace_file_content` are forbidden). If about to touch code: **stop and spawn a worker**.

## 2. Harness-Native Delegation (Headless Only)
Use only the host's native subagent tool:
- **Antigravity**: `invoke_subagent`
- **Claude Code**: `Task`
- **Hermes**: `delegate_task`
- **Codex / OpenCode / Pi**: native subagent / worker

No tmux. No Herdr. No external model routing tables.

## 3. Dispatch & Return Contract

### 5-Line Brief
```text
Goal: <Outcome-focused goal>
Scope: <.worktrees/<slug> and allowed files>
Forbidden: <No edits outside scope, no commits to main>
Verification: <Command to prove success, e.g. npm test>
Output: TOON
```

### TOON Return
```yaml
status: done | blocked | failed
files_changed: [path/to/file]
commands_run: [command]
tests: pass | fail | skipped
decisions: [key choices]
blockers: [issues]
```

## 4. Execution Rules
1. **Worktree Isolation**: All worker implementation runs in `.worktrees/<task-slug>`. Main is protected.
2. **Concurrency**: Max 3 workers. Parallel for exploration/disjoint files; serial for shared files.
3. **Never Fix Workers Yourself**: If a worker fails, feed the error into a new brief and re-delegate.
4. **Zero-Trust Verification**: Always independently verify on disk (`git status -s`, `git diff --stat`, test commands).
5. **Clean Context**: Never read raw worker stdout; consume only the TOON summary.
