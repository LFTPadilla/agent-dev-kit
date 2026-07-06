# Planning Protocol

Use this protocol before any long-running autonomous execution.

## Phase 0.1: Research

Inspect the repository, docs, backlog, and relevant current references. If the
task benefits from secondary agents, delegate read-only research with a narrow
prompt and structured output.

## Phase 0.2: Synthesis

Write down:

- what is clear
- what is ambiguous
- what is risky
- what is out of scope

## Phase 0.3: SPEC

Create `SPEC.md` with objective, in-scope work, out-of-scope work, assumptions,
risks, and ambiguity score.

## Phase 0.4: PLAN

Create `PLAN.md` with small vertical tasks. Every task needs acceptance criteria
and verification.

## Phase 0.5: Pre-Execution Gate

Do not execute until:

- each task is independently verifiable
- no task is unbounded
- sensitive actions are explicitly excluded or authorized
- rollback/reporting is clear

## Phase 1+: Execute

Work one task at a time, update the plan, journal material actions, and stop at
checkpoints if evidence contradicts the plan.
