---
description: |
  Delegate bounded coding-agent work to a different local harness such as Pi or OpenCode. Use only when the user explicitly requests Pi, OpenCode, another/external/cross harness, comparison between distinct harnesses, or a model/runtime available only through an external harness. Do not use for generic requests to spawn, delegate, fan out, orchestrate, or parallelize subagents inside the current harness, or for a native model or role; use the current harness's native subagent capability instead.
argument-hint: "[--profile <name>|--task-type <type>] <delegated task>"
argument-instructions: |
  Treat $ARGUMENTS as the delegated task and optional routing flags. If no profile is provided, use --profile auto with a task type inferred from the request. Do not ask unless the task is too risky to route safely.
tools:
  read: true
  write: true
  edit: true
  bash: true
  glob: true
  grep: true
  agent: true
  question: true
  mcp__context7__resolve-library-id: true
  mcp__context7__query-docs: true
---

<objective>
Operate as the orchestrator for multi-harness delegation. Use the canonical skill and `delegate.py` wrapper to route bounded work to Pi or OpenCode while preserving safety, traceability, and local verification.
</objective>

<execution_context>
Canonical skill:
~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/SKILL.md

Required references when routing is non-trivial:
~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/references/profiles.md
~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/references/prompt-contracts.md
</execution_context>

<context>
$ARGUMENTS
</context>

<process>
1. Read the canonical SKILL.md before acting.
2. Apply its routing gate. If the request has no explicit external-harness signal, stop this workflow and use OpenCode's native agents instead.
3. If the requested external route/profile is unclear, read `references/profiles.md`.
4. If the task can write files or touches sensitive systems, read `references/prompt-contracts.md`.
5. Run diagnostics if external-harness availability is uncertain:
   `python3 ~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/scripts/delegate.py --diagnose`
6. Build a bounded delegated task. Include objective, scope, non-goals, permission mode, and expected output.
7. Run the wrapper. Prefer read-only profiles unless the user clearly requested external edits:
   `python3 ~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/scripts/delegate.py --profile <profile> --cwd "$PWD" --task "<task>"`
8. For write-capable profiles, require `--allow-write`, then inspect `git status` and diffs afterward before accepting the delegate's work.
9. Synthesize the delegated output. Report the harness/profile used, accepted findings or changes, local verification, and residual risk.
</process>
