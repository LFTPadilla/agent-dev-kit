# Why This Exists

Long-running agent work fails in predictable ways:

- The agent starts executing before it has a falsifiable plan.
- Context gets lost across hours of exploration.
- The user wakes up to a vague summary instead of evidence.
- Risk increases silently: production, secrets, shutdown, or destructive actions
  enter the task without a fresh authorization boundary.

`overnight-task-kit` codifies a safer operating mode:

- plan first
- journal continuously
- checkpoint often
- verify before moving on
- produce a handoff report
- keep private connection details out of the public kit

The kit is generic. Put organization-specific runbooks and endpoints in a
private overlay.
