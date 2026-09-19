---
name: finisher-brief
description: Reusable brief template + recovery checklist when a delegated worker hits max_iterations mid-task on an already-prepared worktree.
---

# Finisher Brief — Recovery Pattern for Truncated Workers

When a subagent returns `TRUNCATED: hit max_iterations`, the on-disk worktree
is usually 80%+ done. The fastest recovery is a SECOND, much smaller worker
that just verifies + commits + pushes + opens the PR on the same worktree.

## 1. Verify state on disk BEFORE spawning the finisher

```bash
WT=$HOME/programming/<repo>/.worktrees/<slug>
git -C "$WT" status --short --branch
git -C "$WT" diff origin/master --stat
git -C "$WT" log --oneline -3   # may be empty if changes uncommitted
```

Capture for the finisher brief:
- exact files modified (`git diff --stat` output)
- whether changes are already committed (branch tip on origin? ahead of master?)
- what the truncated worker's last successful action was (read the tail of the
  harness delegation log for that worker)

## 2. Finisher brief (copy-paste skeleton)

```text
Goal: Finalizar PR <branch-name>: (1) validar YAML con execute_code y correr los
      tests de guards actualizados, (2) git diff --check, (3) commitear si hay
      cambios sin commit, (4) push a origin, (5) gh pr create contra master
      SIN mergear.
Scope: .worktrees/<existing-slug> ya preparado; <archivo1>, <archivo2> ya
       modificados por worker previo.
Forbidden: NO reabrir trabajo de implementación, NO aplicar cambios en
           infraestructura, NO escribir secretos ni commitear tokens.
Output: TOON con pr_url y tests pass/fail.
```

Always restate the same tool restrictions that govern any worker:

- Use `execute_code` for any Python / YAML parsing / multi-line logic.
- Use `read_file` for files.
- Reserve `terminal` for single-line commands: `git`, `gh`, `pytest <file>`.
- Never `cat <<EOF`, `python3 -c '...'`, or inline heredoc Python in briefs.

## 3. Anti-patterns to avoid

- **Re-dispatching the same goal** — the truncated worker already had the
  right brief; just re-dispatching it the same way usually hits the same
  limit. The finisher is a SMALLER, narrower brief.
- **Orchestrator doing the work directly** — violates the zero-touch mandate.
  Always delegate.
- **Skipping state verification** — the truncated worker may have ALREADY
  committed but failed to push. Run `git status -s` first; if clean and the
  branch tip is `origin/<branch>`, the finisher only needs to open the PR.

## 4. After the finisher returns

- Read the live transcript once to confirm `gh pr create` succeeded (search
  for `pull/<n>/head` or `github.com/.../pull/<n>`).
- If `pr_url` is empty in the TOON but the transcript shows a successful
  `gh pr create`, recover the URL from the log (don't re-dispatch).
- Update the orchestrator's mental model of which PRs are open; never
  rely solely on `delegate_task` TOON summaries for pr_url.
