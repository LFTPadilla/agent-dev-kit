---
name: overnight-task
tags: [overnight, autonomous, long-running, planning, checkpoints, report]
description: |
  Operate as an unsupervised, long-running task with no user questions after the
  user explicitly invokes that mode. Run a mandatory Plan + Research phase before
  execution, keep a journal and checkpoints, produce a final report, and only run
  shutdown or production steps when explicitly authorized in the same session.
created: '2026-06-17'
updated: '2026-06-30'
status: canonical
version: '3.0'
---

# overnight-task

Use this skill when the user explicitly says they are leaving a task running for
hours, overnight, or unattended and asks the agent not to stop for clarifying
questions.

## Invocation Signals

- "tienes toda la noche"
- "no me hagas más preguntas"
- "no voy a estar disponible"
- "deja esto funcionando"
- "apenas termines puedes apagar..."
- "necesito un reporte completo para mañana"
- "audita todo lo que encuentres"

Do not invoke for short, interactive, or low-risk tasks where the user is present.

## Operating Contract

1. No questions after activation. Make conservative decisions and document them.
2. Plan before execution.
3. Keep a journal of material actions and decisions.
4. Checkpoint every 2-3 tasks or before risk increases.
5. Verify each completed task.
6. Do not commit, push, deploy, mutate production, touch secrets, or shut down
   machines unless the user explicitly authorizes that action in the same session.
7. Produce a final report with what changed, what was verified, what remains open,
   and what the next session should review.

## Recommended Runner

Initialize the run directory:

```bash
node overnight-task-kit/scripts/overnight-runner.mjs init --title "<short-title>"
```

Then use the generated files:

- `SPEC.md`: falsifiable scope and ambiguity assessment.
- `PLAN.md`: vertical slices with acceptance criteria and verification commands.
- `JOURNAL.md`: chronological record.
- `CHECKPOINTS.md`: stop/continue gates.
- `REPORT.md`: final handoff.

## Mandatory Flow

1. **Research:** inspect local docs, code, backlog, and relevant external docs if
   the task depends on current APIs or packages.
2. **SPEC:** write requirements, non-goals, risks, assumptions, and ambiguity
   score.
3. **PLAN:** split into small independently verifiable tasks.
4. **Execute:** complete one task at a time; update plan status as work lands.
5. **Verify:** run tests, linters, smoke checks, or manual checks appropriate to
   the task.
6. **Report:** fill `REPORT.md` and include plan deviations.
7. **Shutdown handoff:** if shutdown was authorized, follow the private overlay's
   shutdown procedure. If none exists, stop and report that shutdown was skipped.

## Output Contract

The final report must include:

- Executive summary.
- Files changed.
- Decisions made autonomously.
- Findings and risks.
- Verification results.
- Plan deviations.
- Open questions or blocked items.
- Next-session checklist.

## Private Overlays

This public skill intentionally omits concrete SSH hosts, IP addresses, cluster
names, customer names, and production commands. Put those in a private overlay
and reference it from the project that owns that context.
