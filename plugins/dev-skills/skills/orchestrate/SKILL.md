---
name: orchestrate
description: Explicit orchestrator mode for Antigravity, Codex, Claude Code, PI, or OpenCode. Use only when the user says "$orchestrate", "orchestrate", "orquestar", "orquestrar", "delegate to subagents/workers", "use cheaper models", "keep your context clean", or asks to route work through GSD with subagents. Plans, decomposes, chooses worker models, delegates execution, and independently verifies results.
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

## Dynamic Model Routing per Harness

Subagents are routed dynamically based on task risk and harness capabilities:

### Codex / OpenAI
| Route | Dynamic Model Tier | Effort | Purpose |
| --- | --- | --- | --- |
| Orchestrator | `gpt-5.6-sol` / session flagship | `high` or `xhigh` | Planning, routing, decomposition, final judgment, direct execution of simple/trivial tasks |
| Complex worker | `gpt-5.6` / flagship | `high` | Multi-file edits, architecture, migrations, auth, security |
| Fast worker | `gpt-5.6-luna` / fast tier | `medium` | Read-heavy exploration, summaries, single-file edits, log triage |
| Verifier / Reviewer | `gpt-5.6-sol` / flagship | `high` | Independent post-implementation verification |
| GSD worker | `gpt-5.6` / flagship | `high` | `.planning/`, phase, milestone, roadmap, SPEC workflows |

### Claude Code / Anthropic
- **Orchestrator**: Active session flagship (e.g. `opus` tier) with maximum reasoning effort.
- **Implementation & Review**: Flagship or complex executor (`opus` / `sonnet` frontier tier).
- **Fast exploration / summaries**: Fast frontier tier for read-only sweeps and triage.

### Antigravity / Gemini
- **Orchestrator**: `gemini-3.7-flash (high)` / flagship frontier tier with maximum reasoning effort.
- **Implementation & Review**: `gemini-3.7-flash (high)` / frontier reasoning tier.
- **Fast exploration**: `gemini-3.7-flash (medium / low)` (fast read-only sweeps).

### PI / OpenCode
Models and profiles are dynamic. Always resolve to the latest active frontier models configured locally. Before spawning executors when model choice is ambiguous, ask:
> Which model would you like to use for the executor agents? The current session will remain as the orchestrator.

---

## The Dynamic Frontier-First Principle

1. **No Stale Anchoring**: Always resolve worker and reviewer tiers to the host runtime's current active frontier models.
2. **Judgment Tier**: Reserve the highest-capability frontier tier for orchestrator planning, architectural choices, and independent diff verification.
3. **Bounded Tier**: Use high-speed tiers only for read-only sweeps, search, or mechanical tasks.
4. **User Override**: If the user specifies an explicit model (e.g. via flags, prompts, or profiles), always honor that choice directly.

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

1. Complexity-based delegation: Only delegate medium to complex tasks.
   - **Simple tasks:** Handle directly in the orchestrator session. Do NOT spawn delegates for routine single-command executions, basic file inspections, quick searches, or trivial 1-line edits. Spawning workers for trivial work wastes tokens and creates process latency.
   - **Medium to complex tasks:** Delegate to bounded workers (Claude, Cursor, Codex, worktree panes). This includes multi-file implementations, non-trivial refactors, deep architectural investigations, complex bug triage, and multi-lens reviews.

2. Agent-Native navigation (ANRS-1.0): Guide subagents to inspect `REGISTRY.yaml`
   and hub `AGENTS.md` to map dependencies and subsystem boundaries before broad sweeps.

3. Keep subagent prompts self-contained. Assume the worker has none of the
   parent conversation. Include exact goal, paths, allowed/prohibited files,
   commands, constraints, skill names, and output format.

4. Fan out only independent work. Exploration, review, test triage, and
   summarization can run in parallel. Writes to the same files must run
   serially.

5. Cap fan-out at 3 to 4 workers by default. Use more only when the work is
   naturally partitioned and the user asked for broad parallelism.

6. Keep context clean. Read only enough to plan and verify. Pass file paths to
   workers. Request summaries, diffs, command names, and findings, not raw
   command output.

7. Verify independently. The worker that implemented a change is not the final
   verifier for important work. Use a verifier or reviewer route before final
   synthesis.

8. Do not allow recursive fan-out unless the user asks for it. Workers should
   complete their bounded task and return.

9. Escalate ambiguous or wrong results by tightening the worker prompt and
   rerunning, or by asking the user when the ambiguity is truly external.

10. Isolated implementation: All task and feature implementation work by coding
    workers must happen in dedicated worktrees under `.worktrees/<task-slug>` to
    protect the main checkout from in-place edits.

11. Clean delegate context: When dispatching a new task to an external worker
    (Claude Code, Cursor, Herdr pane, or tmux session):
    - Do NOT dump unrelated tasks into a dirty session where previous context acts as noise.
    - **Preferred:** Spawn or target a new window/tab/session so past transcripts remain readable for reference.
    - **Fallback:** If reusing an existing session/pane for an unrelated task, issue `/clear` before dispatching.
    - Only reuse a dirty session without `/clear` when directly continuing the exact same task from the previous turn.

12. Background notification hygiene: When background tasks finish after their results
    were already collected or audited, do not treat the delayed exit notification as an
    actionable new turn or persist meta-logs to long-term memory. Acknowledge minimally
    without conversational churn or memory pollution.

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

Require this compact structured result format (TOON / YAML):

```yaml
status: done | blocked | failed
files_changed:
  - path/to/file.ts
commands_run:
  - npm test -- --grep "feature"
tests: pass | fail | skipped
decisions:
  - "Key rationale for architectural choice"
risks:
  - "Potential edge case or residual risk"
next_actions:
  - "Suggested follow-up step"
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
