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

### Read-Only Brief (research, verification, discovery)
No worktree. No branch. Use when the worker only reads code and writes one report.
```text
Goal: <question to answer or claim to verify>
Scope: READ-ONLY <paths the worker may read>. May write ONLY <one report path>.
Forbidden: No edits to any clone. No git branch/worktree/commit/push. No network unless listed.
Verification: <N> citations as file:line, quoted where it matters.
Output: TOON
```
Orchestrator check after return: spot-check 3 citations from the TOON against disk before reporting up.

### TOON Return
```yaml
status: done | blocked | failed
files_changed: [path/to/file]
commands_run: [command]
tests: pass | fail | skipped
decisions: [key choices]
diagram: |            # required when the task maps a flow, model, or bug path
  <ASCII or mermaid, max 25 lines>
blockers: [issues]
```
`diagram:` is forwarded to the user as-is. Structure first, prose second.

## 4. Execution Rules
1. **Worktree Isolation**: All worker implementation runs in `.worktrees/<task-slug>`. Main is protected.
2. **Concurrency**: Max 3 workers. Parallel for exploration/disjoint files; serial for shared files.
3. **Never Fix Workers Yourself**: If a worker fails, feed the error into a new brief and re-delegate.
4. **Zero-Trust Verification**: Always independently verify on disk (`git status -s`, `git diff --stat`, test commands).
5. **Clean Context**: Never read raw worker stdout; consume only the TOON summary.

## 5. Worker Tooling Pitfalls (verified 2026-09-03)

### Avoid `terminal` heredocs and `python3 -c` in worker briefs
**Workers run inside the same command-approval regime as the orchestrator.** A brief that says "run this Python" plus a heredoc or `-c` flag gets denied with `Command approval denied` and the worker aborts mid-task, leaving the worktree dirty and the PR unopened. Two PRs were delayed this way in one session.

**Mandate for worker briefs** (write it into the Scope line so the worker reads it):
- Use `execute_code` for any Python, YAML parsing, JSON inspection, or multi-line logic.
- Use `read_file` for reading files.
- Reserve `terminal` for single-line commands: `git`, `gh`, `kubectl get`, `pytest <file>`, `gh workflow run`.
- Never `cat <<EOF`, `python3 -c '...'`, or inline `python3 - <<PY` in worker briefs.

### Finisher pattern when a worker hits max_iterations
If a worker reports `TRUNCATED: hit max_iterations`, the on-disk state is usually 80%+ done. Spawn a **finisher** worker on the SAME worktree with a narrow brief:

```text
Goal: Finalizar PR <branch>: (1) validar YAML con execute_code y correr los tests
      de guards actualizados, (2) git diff --check, (3) commitear, (4) push a
      origin, (5) gh pr create contra master SIN mergear.
Scope: .worktrees/<existing-slug> ya preparado; <archivo1>, <archivo2> ya modificados.
Forbidden: NO reabrir trabajo de implementación, NO aplicar cambios en infraestructura, NO secrets.
Output: TOON con pr_url y tests pass/fail.
```

The finisher should NOT redo the work — just verify, commit, push, PR. Pre-load the finisher brief with explicit references to the files the prior worker already modified (gathered via `git diff --stat` from the orchestrator).

### Brief size vs. worker iteration budget
A worker that needs >150 tool calls almost always hits `max_iterations` mid-task. Split it: a **builder** worker (≤100 calls: edit, validate locally) + a **finisher** worker (≤50 calls: commit, push, PR, report). Orchestrator triggers the finisher only after verifying the builder's worktree state.

## 6. Campaign-level parallelism (multi-track changes)

When the user asks for several independent tracks at once — "do X, Y, and Z"
or "audit the cluster, fix service A, and swap the tiers" — **fan out in parallel
by default**. Serializing them "to be safe" is the wrong default. The correction the
user gave on 2026-09-03 was:

> "por que en cola, puedes levantar multiples workers al mismo tiempo para
> hacer todo"

Concrete rules:

1. **Decompose before dispatching.** If the user names ≥2 tracks, list them
   aloud in the plan (one line each: track name, files/worktree, blocking
   dependencies) and spawn one worker per track in a SINGLE `delegate_task`
   call. The runtime runs them concurrently.
2. **Default to parallel unless there is a real conflict.** Real conflicts
   are: (a) two workers editing the same file, (b) two workers pushing to
   the same branch, (c) one worker needs the other's output to start.
   Anything else is a false economy to serialize.
3. **Cap at 3 concurrent workers** (rule 4.2 still holds). If the campaign
   has more than 3 tracks, batch the dispatch: first wave 3, second wave
   fires when a slot frees.
4. **Declare the merge order up front, even if parallel.** Many
   infrastructure changes have a strict merge dependency: a config change
   must merge before the code that propagates it, and the propagation must
   merge before the per-target fixes that depend on it. Surface this order in the first user-facing message of
   the campaign so the user can override before any worker spends an hour.
5. **Single-track worktree hygiene.** Even with parallel dispatch, every
   worker uses its OWN `.worktrees/<task-slug>` and its OWN branch. The
   orchestrator never has two workers touching the same branch; that's the
   conflict pattern that actually blocks parallelism.
6. **Don't conflate "parallel" with "merge in any order".** Parallel
   dispatch is about wall-clock; merge order is about correctness. Always
   state both.

Anti-pattern: "let me run audit first, then fix, then tiers" — this is
serialization dressed up as caution. If the audit and the fix touch
different files in different worktrees, run them together. The audit may
even surface a different fix; that's information the parallel dispatch
already captured.

## 7. References

- `references/finisher-brief.md` — copy-pasteable finisher brief skeleton,
  pre-flight state verification, anti-patterns, and post-finisher recovery
  when `pr_url` is missing from the TOON.
