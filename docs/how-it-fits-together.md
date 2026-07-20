# How it fits together

One map of this kit. Install tables live in [`external-deps.md`](external-deps.md).
Orchestrator detail lives in [`agent-tutor-orchestrator.md`](agent-tutor-orchestrator.md).

## Three blocks

```text
direct          ship                 run
────────────    ─────────────────    ──────────────────────────
caveman         /pr-review           agent-tutor-orchestrator
ponytail        no-mistakes          gnhf (+ overnight-task-kit)
GSD             evals                treehouse
(+ dev-skills)
```

1. **direct** — how the agent talks (caveman), what it builds (ponytail), how multi-step work flows (GSD), plus discrete capabilities in this repo (`dev-skills`).
2. **ship** — adversarial `/pr-review`, the no-mistakes gate, and measured evals. Prefer both LLM review and deterministic SAST.
3. **run** — pure orchestrator profile (Agent Tutor Orchestrator), overnight runner (gnhf), and worktree isolation (treehouse).

## Recommended loop

```text
GSD (plan / execute / verify)
  → implement (ponytail + caveman + dev-skills)
  → treehouse when parallel agents would collide
  → /pr-review + no-mistakes before merge
  → gnhf for unsupervised multi-hour work
```

Use **Agent Tutor Orchestrator** when you want a liaison that never edits: it routes to tmux Claude panes or Hermes Kanban and audits the disk. Compare with firstmate in [`agent-tutor-vs-firstmate.md`](agent-tutor-vs-firstmate.md).

## Skill distribution and contracts

1. Extra packs: [vercel-labs/skills](https://github.com/vercel-labs/skills) (`npx skills`). Reference [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills); do not vendor.
2. Agent-facing structured output: prefer [TOON](https://toonformat.dev) when another agent consumes it; keep JSON for strict APIs and human config.
3. GitHub CLI shaped for agents: [gh-axi](https://github.com/kunchenguid/axi).

## Cold-clone tiers

| Tier | What you get | Requires |
| --- | --- | --- |
| **A — Kit only** | `./bootstrap.sh` → plugins → `npm run doctor` / `validate`. Skills, `/pr-review`, evals. | Node/npm; no Hermes |
| **B — Agent Tutor Orchestrator** | `tutor-install.sh` + `tutor-doctor.sh`; public skills `ai-workflow-orchestrator` + `orchestrate`; tmux `tutor`; `AGENT_TUTOR_*` | Hermes Agent |
| **C — Private overlay** | Extra org skills linked from outside this tree | Optional; never assumed on cold clone |

Full steps: [README](../README.md#install--cold-clone-tiers) and
[`agent-tutor-orchestrator.md`](agent-tutor-orchestrator.md). Overlay pattern:
[`private-overlays.md`](private-overlays.md).
