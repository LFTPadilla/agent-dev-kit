# Agent Tutor Orchestrator vs firstmate

This kit ships **Agent Tutor Orchestrator** as its pure orchestrator. It does **not**
adopt [firstmate](https://github.com/kunchenguid/firstmate) as a runtime. firstmate
is tracked as an optional external layer: documented in
[`external-deps.md`](external-deps.md), placed in the layer map in
[`how-it-fits-together.md`](how-it-fits-together.md), and credited in
[`ATTRIBUTION.md`](../ATTRIBUTION.md). No firstmate code lives here.

## Short verdict

| | Agent Tutor Orchestrator (this kit) | firstmate |
| --- | --- | --- |
| Shape | Hermes profile + skills + installer scripts inside a broader agent kit | Standalone agent distro |
| Liaison | Hermes profile `agent-tutor-orchestrator` | First mate session inside the distro |
| Workers | Claude Code TUIs in tmux session `tutor`, or Hermes Kanban | Crewmates in tmux / other backends |
| Mutation | Tutor never edits/tests/commits/opens PRs; workers do | First mate read-only except guarded fleet paths |
| Isolation | Branch-per-delegate worktrees; optional treehouse | treehouse (or backend-specific) by default |
| Scope | One profile among talk/build/flow/ship/overnight layers | The whole product is the crew orchestrator |

## Why keep tutor as a pure orchestrator

Blurring liaison into implementer loses the fleet picture. Contract:

1. **Tutor** — plan, route, monitor, audit, coach.
2. **Workers** — edit, test, commit, push, open PRs (only when delegated).

Enforced in `profiles/agent-tutor-orchestrator.yml` and `orchestrate`.

## Composition, not fork

1. Run Agent Tutor Orchestrator for Hermes-native orchestration and kanban-backed work.
2. Use firstmate-adjacent tools from the day-to-day toolchain (treehouse, no-mistakes, AXI) for isolation and ship quality.
3. Keep org-specific skills in a private overlay ([private-overlays.md](private-overlays.md)).

Do not vendor firstmate into this tree.
