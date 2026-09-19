---
name: orchestrate
description: Explicit orchestrator mode. Plans, decomposes, and delegates all execution to bounded native subagents, then independently verifies results on disk. Zero-touch on code; headless by default (use herdr or tmux-delegation for visual panes).
---

# orchestrate — Lean Native Orchestrator

Plan, decompose, delegate, collect, verify, synthesize. Keep the expensive
model on judgment; move bounded execution into workers that return compact
TOON summaries. Never write or edit code in the orchestrator session — the
moment you are about to touch code, stop and spawn a worker.

Activate only on an explicit orchestration, delegation, or workers request.
Do not fan out silently for ordinary tasks. Use only the host's native
subagent tool (Hermes `delegate_task`, Claude Code `Task`, Antigravity
`invoke_subagent`, Codex/OpenCode/Pi native workers). No tmux, no Herdr, no
model routing tables; for visual panes load `herdr` or `tmux-delegation`.

## 1. Dispatch and return contract

### 5-line brief (implementation)
```text
Goal: <Outcome-focused goal>
Scope: <.worktrees/<slug> and allowed files>
Forbidden: <No edits outside scope, no commits to main>
Verification: <Command to prove success, e.g. npm test>
Output: TOON
```

### Read-only brief (research, verification, discovery)
No worktree, no branch. The worker reads code and writes one report.
```text
Goal: <question to answer or claim to verify>
Scope: READ-ONLY <paths the worker may read>. May write ONLY <one report path>.
Forbidden: No edits to any clone. No git branch/worktree/commit/push. No network unless listed.
Verification: <N> citations as file:line, quoted where it matters.
Output: TOON
```
After return: spot-check 3 citations from the TOON against disk before
reporting up.

### TOON return
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

## 2. Execution rules

1. **Worktree isolation**: worker implementation runs in `.worktrees/<task-slug>`; main is protected.
2. **Concurrency**: cap at 3 parallel writers. Parallel for exploration or disjoint files; serial for shared files.
3. **Never fix workers yourself**: feed the error into a new brief and re-delegate.
4. **Zero-trust verification**: re-run the acceptance commands on disk (`git status -s`, `git diff --stat`, tests). Never trust the worker's self-report.
5. **Clean context**: keep prompts self-contained (goal, paths, allowed and forbidden files, constraints, output format). Consume TOON summaries, not raw stdout.
6. **Finisher pattern**: if a worker hits `max_iterations`, the work is usually 80% done. Spawn a narrow finisher worker on the same worktree to verify, commit, push, and open the PR — nothing else. Skeleton: `references/finisher-brief.md`.
7. **Escalate ambiguity** by tightening the brief and rerunning; ask the user only when the ambiguity is truly external.

## 3. Campaign parallelism

- Decompose before dispatching: one worker per track, one worktree and branch per worker.
- Default to parallel unless two workers edit the same file, push the same branch, or one needs the other's output. Anything else is serialization dressed up as caution.
- Cap at 3 concurrent workers; batch extra tracks into a second wave.
- Declare merge order up front, even when dispatch is parallel. Wall-clock is parallelism; correctness is merge order. State both.

## 4. Practices

- **Deterministic gate.** Acceptance is a command, not an opinion: re-run the brief's verification commands inside the worker's worktree and audit `git diff` before accepting a result. A green self-report is not a gate.
- **Cross-model review as a habit.** Work that touches core code or more than 3 files gets one review pass from a different model before merge (any available `*-review` profile or a second harness). Rubric: real bugs, scope violations, duplication — no style rewrites. A habit, not a mandatory pipeline step.
- **Graduated autonomy by task category.** Docs and research: the orchestrator may commit and merge. Code in a worktree with a green gate: the orchestrator commits, a human merges. Core or infra: a human does everything after review.
- **Single KPI: verified merged work** — green gate plus audited diff. Never count tasks dispatched.
- **Budget.** 3 parallel writers (4 only with written justification in the campaign `PLAN.md`); returns of 10 lines or fewer; a campaign that burns more than half the rate-limit window drops to 1 worker next run.

## References

- `references/ops-rules.md` — operational rules from real campaigns: mid-task handoff trigger, parallel-session guard prompts, verify-the-prior-claim, PR-number collision checks.
- `references/finisher-brief.md` — copy-pasteable finisher brief, pre-flight state verification, and recovery when `pr_url` is missing from the TOON.
