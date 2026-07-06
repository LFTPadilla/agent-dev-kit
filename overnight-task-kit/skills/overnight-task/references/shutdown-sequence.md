# Shutdown Sequence Template

This public file is a safety checklist, not a production runbook.

## Rules

1. Only shut down a machine if the user explicitly authorized that shutdown in
   the same session.
2. Identify the host the agent is running on.
3. Identify the target host.
4. If they are the same host, stop and report instead of shutting down.
5. If they differ, use the private overlay's procedure.
6. Record the decision and outcome in the final report.

## Required Evidence

- Current host:
- Target host:
- Authorization quote or summary:
- Private procedure used:
- Result:
