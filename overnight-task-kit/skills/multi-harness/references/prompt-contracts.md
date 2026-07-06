# Delegated Prompt Contracts

External harnesses start with their own context. Treat every prompt as a standalone work order.

## Required structure

Use this shape for delegated prompts:

```text
You are an external harness delegated by the primary orchestrator.

Working directory: <absolute path>
Profile: <profile>
Permission mode: READ_ONLY or WRITE_ALLOWED

Task:
<specific task>

In scope:
- <files, dirs, commands, or behavior>

Out of scope:
- <non-goals and forbidden areas>

Rules:
- Read project instructions such as AGENTS.md before acting.
- Do not reveal or copy secrets.
- Do not change files in READ_ONLY mode.
- Do not run destructive commands.
- Do not push, commit, deploy, send email, charge money, or modify production.
- If blocked, explain the blocker and stop.

Return:
1. SUMMARY
2. FINDINGS or CHANGES
3. FILES_INSPECTED
4. COMMANDS_RUN
5. VERIFICATION
6. RISKS
```

The wrapper injects a version of this contract automatically. Add task-specific constraints in `--task`.

## Read-only jobs

Use read-only jobs for:

- Code review
- Architecture critique
- Debug hypothesis generation
- Test plan generation
- Search-heavy context gathering
- Comparing implementation approaches

Read-only jobs may still run safe inspection commands, but must not edit files.

## Write-capable jobs

Only use write-capable jobs when the delegated harness is expected to modify files. Before running:

1. Check `git status --short`.
2. Note any user changes in files the delegate may touch.
3. Prefer a task that names exact files or plan task IDs.
4. Require the delegate to run relevant checks.
5. Inspect `git diff` afterward before accepting the result.

If the worktree is dirty and the task overlaps with user changes, do not delegate writes unless the user explicitly accepts that risk.

## Forbidden delegations

Do not delegate:

- Raw secrets or credentials.
- Production write operations.
- Kubernetes, cloud, DNS, billing, payment, or account changes.
- `git push`, release publishing, package publishing, deployment, or destructive cleanup.
- Tasks that require the delegate to infer sensitive business context not included in the prompt.

The primary agent can still use external harness output as advice for these areas, but the primary agent must execute and verify the sensitive operation itself after explicit user approval where required.
