---
description: |
  Operate as an unsupervised, long-running task with no user questions. Pre-fills
  common connection details, runs a mandatory Plan + Research phase before
  any execution (research subagents generate clarifying questions, agent
  produces SPEC.md + PLAN.md), and ends with a deterministic shutdown sequence
  for the Proxmox hypervisor (pve-main) when the user has left tasks overnight.
  Use when the user says "tienes toda la noche", "no me hagas preguntas", "deja
  esto funcionando y apaga el PC".
argument-hint: "[<brief from the user>]"
argument-instructions: |
  If $ARGUMENTS is provided, treat it as the user's overnight brief; extract the
  task, the shutdown target (if named), and the explicit no-questions mode.
  If $ARGUMENTS is empty, ask for it ONCE only if the user is present; otherwise
  default to "no brief — interpret session context as the task".
tools:
  read: true
  write: true
  edit: true
  bash: true
  glob: true
  grep: true
  agent: true
  question: false                  # HARD: never ask the user; decide autonomously
  mcp__context7__resolve-library-id: true
  mcp__context7__query-docs: true
---

<objective>
Apply the overnight-task operating mode for the rest of the session. This means:
  1. NO questions to the user. Decide autonomously; document decisions.
  2. Take as much time as needed. No implicit deadline.
  3. Pre-filled connection details (no asking for SSH hosts, Tailscale IPs, etc.).
  4. Subagent-driven deep reads (don't fill your own context).
  5. **MANDATORY Plan + Research phase** before execution (NEW in v2.0):
     - Spawn 3 parallel research subagents (context, patterns, ambiguities)
     - Synthesize, write SPEC.md, write PLAN.md
     - Pre-execution self-test before any task starts
  6. End with a deterministic shutdown sequence if the user named a shutdown target.
  7. Produce a final report at Ops/reports/<date>-<topic>.md with a Plan Deviations section.
</objective>

<execution_context>
Canonical skill lives at: ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/SKILL.md
Read the SKILL.md and all references/ before starting work. Treat the SKILL.md
content as binding operating instructions.

Required reads (in this order):
  1. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/SKILL.md
  2. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/connections.md
  3. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/shutdown-sequence.md
  4. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/planning-protocol.md
  5. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/spec-template.md
  6. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/plan-template.md
  7. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/learnings-template.md
  8. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/agent-quickref.md
  9. (If a shutdown target was named) ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/2026-06-17-session-learnings.md — the session that birthed v2.0
  10. ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/planning-and-task-breakdown-canonical.md — addyosmani source (canonical reference for the planning pattern)
</execution_context>

<context>
$ARGUMENTS (the user's overnight brief, if provided; otherwise interpret session context as the task)
</context>

<process>
1. State the operating mode explicitly in your first response (one short paragraph),
   calling out the mandatory Plan + Research phase.

2. Read all 8 references in ~/programming/agent-dev-kit/overnight-task-kit/skills/overnight-task/references/.

3. If the user named a shutdown target (e.g., "apaga pve-main", "apaga el PC"), check
   `hostname` and `ip -4 addr show` to determine whether the agent is running on that
   target. If YES, abort the shutdown and flag; the agent would kill its own session.

4. **Phase 0 — Plan + Research** (NEW in v2.0, MANDATORY):
   a. Spawn 3 parallel research subagents (per references/planning-protocol.md §"Phase 0.1"):
      - Subagent A (explore): context scout (codebase + vault scan)
      - Subagent B (explore): pattern + convention scout
      - Subagent C (general): ambiguity + risk scout + clarifying questions
   b. Synthesize the 3 reports (per planning-protocol.md §"Phase 0.2")
   c. Write SPEC.md at Ops/plans/<YYYY-MM-DD>-<topic>/SPEC.md (per spec-template.md)
   d. Write PLAN.md at Ops/plans/<YYYY-MM-DD>-<topic>/PLAN.md (per plan-template.md)
   e. Run the pre-execution self-test (PLAN.md §11). If anything fails, fix the plan first.
   f. Commit plan to vault (NOT to git).

5. **Phase 1 — Execute the PLAN** (not the original brief):
   For each task in PLAN.md:
     a. Read the task's acceptance criteria + verification
     b. Do the work
     c. Run the verification command
     d. Mark the task done in the plan
     e. Self-test the change (kustomize validate, YAML parse, etc.)
     f. Move to the next task
   At each checkpoint, run all verification commands and note any deviations.

6. **Phase 2 — Final report** (per references/learnings-template.md):
   - Save to Ops/reports/<YYYY-MM-DD>-<topic>.md
   - Always include a Plan Deviations section (what actually happened vs PLAN.md)
   - Include the pre-execution self-test results

7. **Phase 3 — Shutdown** (per references/shutdown-sequence.md):
   - Only if the target is NOT the agent's host
   - Graceful VM shutdown first
   - wall broadcast
   - shutdown -h now
   - Report the result in the final report

8. Final one-paragraph summary to the user linking to the report.
</process>
