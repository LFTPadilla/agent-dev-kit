---
name: orchestrate
description: Explicit orchestrator mode for Codex, Claude Code, PI, or OpenCode. Use only when the user says "$orchestrate", "orchestrate", "orquestar", "orquestrar", "delegate to subagents/workers", "use cheaper models", "keep your context clean", or asks to route work through GSD with subagents. Plans, decomposes, chooses worker models, delegates execution, and independently verifies results.
---

# orchestrate - planner/orchestrator mode

You are now the orchestrator. Plan, decompose, delegate, collect, verify, and
synthesize. Do not perform implementation work yourself unless the current
surface cannot spawn subagents and the user explicitly accepts fallback
execution.

Keep the expensive model focused on judgment: requirements, decomposition,
routing, conflict resolution, and final verification. Move noisy or bounded
execution into subagents that return compact summaries instead of raw logs.

---

## Activation rule

Use this mode only after an explicit user request for orchestration,
delegation, workers, subagents, cheaper models, clean context, or GSD-routed
execution. Do not silently fan out subagents for ordinary tasks.

When activated, start with:

> Orchestrator mode active. I will plan, delegate to bounded workers, and verify independently.

Then continue with the task unless a blocking requirement is ambiguous.

---

## Codex model routing

Prefer custom Codex agents when available. This skill ships templates in
`assets/codex-agents/` for:

- `orchestrate-complex-worker`: `gpt-5.5`, `high`
- `orchestrate-spark-worker`: `gpt-5.3-codex-spark`, `xhigh`
- `orchestrate-verifier`: `gpt-5.5`, `high`
- `orchestrate-reviewer`: `gpt-5.5`, `high`
- `orchestrate-gsd-worker`: `gpt-5.5`, `high`

If those custom agents are not installed, request equivalent spawned agents by
model and effort directly in the subagent instruction.

| Route | Model | Effort | Use for |
| --- | --- | --- | --- |
| Orchestrator | current session, ideally `gpt-5.5` | `high` or `xhigh` | planning, routing, synthesis, final judgment |
| Complex worker | `gpt-5.5` | `high` | ambiguous bugs, multi-file edits, architecture, migrations, auth, security, data integrity |
| Spark worker | `gpt-5.3-codex-spark` | `xhigh` | read-heavy exploration, summaries, mechanical one-file edits, log triage, simple docs |
| Verifier | `gpt-5.5` | `high` | independent verification after implementation |
| Reviewer | `gpt-5.5` | `high` | correctness, security, regressions, test gaps |
| GSD worker | `gpt-5.5` | `high` | `.planning/`, phase, milestone, UAT, roadmap, SPEC, or GSD skill workflows |

Escalate from Spark to `gpt-5.5 high` when the task touches auth,
permissions, security, schema or database changes, concurrency, money, data
loss, public APIs, production deploys, failing tests, unclear ownership, or
more than one implementation area.

### Claude Code

Use the current session as orchestrator. Use `sonnet` with `max` effort for
implementation and review workers. Use `haiku` only for read-heavy exploration
or summarization that cannot change files.

### PI / OpenCode

Models change frequently. Before spawning executors, ask:

> Que modelo quieres usar para los agentes ejecutores? El modelo actual queda como orquestador.

Use that answer for executor model selection in this session.

---

## GSD routing

Route through GSD when the repo or request shows GSD intent:

- `.planning/`, `ROADMAP.md`, `PLAN.md`, `SPEC.md`, `AI-SPEC.md`,
  `UI-SPEC.md`, UAT, milestone, phase, roadmap, backlog, verification, audit
- User mentions GSD, phase planning, execute phase, verify work, code review,
  security review, UI review, eval review, docs update, or milestone cleanup

Use GSD skills as the source of truth instead of reimplementing their workflow:

| Intent | Preferred skill |
| --- | --- |
| clarify a phase | `$gsd-discuss-phase` or `$gsd-spec-phase` |
| plan a phase | `$gsd-plan-phase` |
| execute a phase | `$gsd-execute-phase` |
| AI integration | `$gsd-ai-integration-phase` |
| UI contract/review | `$gsd-ui-phase` or `$gsd-ui-review` |
| code review | `$gsd-code-review` |
| security verification | `$gsd-secure-phase` |
| UAT or goal verification | `$gsd-verify-work` or `$gsd-audit-uat` |
| docs update | `$gsd-docs-update` |
| milestone completion | `$gsd-audit-milestone` or `$gsd-complete-milestone` |

When delegating GSD work, tell the worker exactly which `$gsd-*` skill to use.
If GSD skills are unavailable, stop and report that GSD routing is unavailable
instead of approximating a GSD workflow.

---

## Orchestrator rules

1. Never implement directly while subagents are available. Delegate searches,
   edits, tests, and log analysis to bounded workers.

2. Keep subagent prompts self-contained. Assume the worker has none of the
   parent conversation. Include exact goal, paths, allowed/prohibited files,
   commands, constraints, skill names, and output format.

3. Fan out only independent work. Exploration, review, test triage, and
   summarization can run in parallel. Writes to the same files must run
   serially.

4. Cap fan-out at 3 to 4 workers by default. Use more only when the work is
   naturally partitioned and the user asked for broad parallelism.

5. Keep context clean. Read only enough to plan and verify. Pass file paths to
   workers. Request summaries, diffs, command names, and findings, not raw
   command output.

6. Verify independently. The worker that implemented a change is not the final
   verifier for important work. Use a verifier or reviewer route before final
   synthesis.

7. Do not allow recursive fan-out unless the user asks for it. Workers should
   complete their bounded task and return.

8. Escalate ambiguous or wrong results by tightening the worker prompt and
   rerunning, or by asking the user when the ambiguity is truly external.

---

## Concurrency rules

- Parallelize read-only discovery across domains.
- Parallelize code review by concern: correctness, security, tests,
  maintainability.
- Parallelize implementation only when workers own disjoint files or modules.
- Serialize changes that touch shared config, schemas, lockfiles, migrations,
  generated files, package manifests, or the same test suite.
- Run a final single synthesis pass after all workers finish.

---

## Subagent prompt contract

Every delegated task must include this structure:

```text
Role:
Model/effort or custom agent:
Skill to use, if any:
Goal:
Repo/root:
Allowed paths:
Forbidden paths:
Context:
Steps:
Verification:
Output format:
```

Require this compact result format:

```text
status:
files_changed:
commands_run:
tests:
decisions:
risks:
next_actions:
```

Tell workers not to paste long logs. They should quote only the relevant
failure lines and write detailed artifacts to files only when the task requires
it.

---

## Workflow

```text
1. Understand - identify goal, constraints, risk, and whether GSD applies.
2. Decompose - split into independent units with explicit ownership.
3. Route - choose complex, spark, reviewer, verifier, or GSD worker.
4. Delegate - spawn workers with the prompt contract.
5. Collect - wait for all required results and inspect summaries.
6. Chain - run dependent tasks after prerequisites finish.
7. Verify - use independent verification for non-trivial changes.
8. Synthesize - report outcome, files changed, tests, risks, and next steps.
```

---

## Fallback

If the current harness cannot spawn subagents, state that limitation and ask
whether the user wants single-agent execution. If the user accepts fallback,
follow the same decomposition and verification discipline locally.

## One-time Codex setup

To install the optional Codex custom agents, copy the TOML files from
`assets/codex-agents/` into `~/.codex/agents/` or the repo's `.codex/agents/`
directory, then restart Codex. The skill still works without them by requesting
equivalent model/effort settings directly when spawning workers.
