# overnight-task-kit

Generic long-running task support for agent-dev-kit.

This kit provides two public-safe skills:

| Skill | Purpose |
| --- | --- |
| `overnight-task` | Unsupervised multi-hour work with planning, checkpoints, journal, report, and optional shutdown handoff. |
| `multi-harness` | Delegate bounded work to secondary local harnesses such as Pi or OpenCode. |

It intentionally does **not** include private hostnames, IPs, customer data,
cluster endpoints, or organization-specific runbooks. Keep that material in a
private overlay.

## Install

```bash
cd ~/programming/agent-dev-kit/overnight-task-kit
./install.sh
```

## Start a Run

```bash
node overnight-task-kit/scripts/overnight-runner.mjs init \
  --title "audit-payment-flow" \
  --root "$PWD"
```

The runner creates:

```text
.agent-runs/overnight/<timestamp>-audit-payment-flow/
├── SPEC.md
├── PLAN.md
├── JOURNAL.md
├── CHECKPOINTS.md
└── REPORT.md
```

The generated files are templates. The agent still owns execution and
verification.

## Public/Private Boundary

Public kit:

- task protocol
- journal/checkpoint/report templates
- generic safety rules
- local runner
- generic harness delegation contract

Private overlay:

- real connection details
- production shutdown procedures
- internal service maps
- incident learnings
- organization-specific acceptance gates
