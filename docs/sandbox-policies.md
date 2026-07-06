# Sandbox Policies

Profiles must declare a sandbox policy from `policies/sandbox-policies.json`.

The policy is not a security boundary by itself. It is a contract for humans,
agents, and wrappers such as Pi/OpenCode delegates. A runner should enforce the
same limits where the harness supports it and print a clear warning where it
cannot.

Default mapping:

- `read-only`: code review, planning, inventory, local analysis.
- `research-network`: current docs/package/API research without file writes.
- `workspace-write`: normal implementation in a dirty-safe local worktree.
- `browser-lab`: Playwright or browser-driven QA with disposable auth state.
- `operator-confirmed`: production/admin work only after explicit same-session authorization.

Hard rules for every policy:

- No secrets in prompts, logs, reports, eval fixtures, or public docs.
- No `git push`, cloud mutation, payment action, email send, or destructive op
  unless the selected policy allows it and the user explicitly asked for it.
- Read-only delegates are advisors; the primary agent verifies evidence before
  reporting.
