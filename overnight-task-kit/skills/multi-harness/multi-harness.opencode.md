---
description: |
  Delegate bounded coding-agent work to another local harness such as Pi or OpenCode, choosing profiles by task type, model strength, tool permissions, and risk. Use when the user asks to use multiple harnesses, delegate work to opencode/pi, run GLM-5.2 subscription models, fan out research/review/implementation tasks outside the current agent, compare harness outputs, or keep the current agent as orchestrator while external agents execute scoped jobs.
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
2. If the requested route/profile is unclear, read `references/profiles.md`.
3. If the task can write files or touches sensitive systems, read `references/prompt-contracts.md`.
4. Run diagnostics if availability is uncertain:
   `python3 ~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/scripts/delegate.py --diagnose`
5. Build a bounded delegated task. Include objective, scope, non-goals, permission mode, and expected output.
6. Run the wrapper. Prefer read-only profiles unless the user clearly requested external edits:
   `python3 ~/programming/agent-dev-kit/overnight-task-kit/skills/multi-harness/scripts/delegate.py --profile <profile> --cwd "$PWD" --task "<task>"`
7. For write-capable profiles, require `--allow-write`, then inspect `git status` and diffs afterward before accepting the delegate's work.
8. Synthesize the delegated output. Report the harness/profile used, accepted findings or changes, local verification, and residual risk.
</process>
