# overnight-task-kit

Protocol and templates for long-running agent work. This kit is **not** a
second overnight runner.

| Role | What |
| --- | --- |
| **Preferred runner** | [gnhf](https://github.com/kunchenguid/gnhf) (`npm i -g gnhf`) |
| **This kit** | Spec / plan / journal / checkpoint / report protocol, templates, and optional local helper scripts |

Do not run a parallel ralph-style overnight loop. Use gnhf as the engine;
use this kit for the operating contract.

## Public skills in this kit

| Skill | Purpose |
| --- | --- |
| `overnight-task` | Unsupervised multi-hour work with planning, checkpoints, journal, report, and optional shutdown handoff. |
| `multi-harness` | Delegate bounded work to secondary local harnesses such as Pi or OpenCode. |

It intentionally does **not** include private hostnames, IPs, customer data,
cluster endpoints, or organization-specific runbooks. Keep that material in a
private overlay.

## Install

```bash
cd overnight-task-kit
./install.sh
```

Also install the preferred runner (EXTERNAL, not vendored):

```bash
npm i -g gnhf
```

See [`../docs/external-deps.md`](../docs/external-deps.md) and
[`../docs/how-it-fits-together.md`](../docs/how-it-fits-together.md).

## Start a Run

Prefer driving the overnight session with **gnhf**, using the templates below
as the protocol. For a local scaffold of the artifact tree:

```bash
node overnight-task-kit/scripts/overnight-runner.mjs init \
  --title "audit-payment-flow" \
  --root "$PWD"
```

That creates:

```text
.agent-runs/overnight/<timestamp>-audit-payment-flow/
├── SPEC.md
├── PLAN.md
├── JOURNAL.md
├── CHECKPOINTS.md
└── REPORT.md
```

The generated files are templates. The agent still owns execution and
verification. The runner helper does not replace gnhf.

## Public/Private Boundary

Public kit:

1. task protocol
2. journal/checkpoint/report templates
3. generic safety rules
4. local scaffold helper
5. generic harness delegation contract

Private overlay:

1. real connection details
2. production shutdown procedures
3. internal service maps
4. incident learnings
5. organization-specific acceptance gates
