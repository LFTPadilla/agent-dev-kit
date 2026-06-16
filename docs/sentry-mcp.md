# Sentry MCP — triage production errors from the editor

If your app reports to Sentry, the official Sentry MCP server lets the agent
pull issue lists, full stack traces, breadcrumbs, releases, and performance
data into context — so it can find the bad commit and write a fix in one loop,
without leaving the terminal.

## Connect (Claude Code)

Remote server, OAuth — no token to paste, no secret to commit.

```bash
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

First use opens a browser for Sentry OAuth. (A Sentry plugin also exists in the
Claude plugin marketplace.) Confirm the exact command against the current
Sentry MCP docs — the hosted URL is `https://mcp.sentry.dev/mcp`.

## Use it

- "What are the top unhandled exceptions in <project> this week?"
- "Read the stack trace for issue <id> and find the commit that introduced it."
- Pair with `/schedule` for a weekly sweep: query slowest endpoints / new
  errors → open a PR with the root-cause fix.

## Notes

- Read-heavy by design — treat issue data as input, never auto-resolve issues
  or push fixes without confirmation.
- It needs *your* Sentry login; it is per-user, not committed to this repo.
