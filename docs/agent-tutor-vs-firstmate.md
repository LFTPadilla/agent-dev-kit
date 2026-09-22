# Agent Tutor Orchestrator vs firstmate

This kit ships **Agent Tutor Orchestrator** as its pure orchestrator. It does **not**
adopt [firstmate](https://github.com/kunchenguid/firstmate) as a runtime.

## Short verdict

| | Agent Tutor Orchestrator (this kit) | firstmate |
| --- | --- | --- |
| Shape | Hermes profile + skills + installer scripts inside a broader agent kit | Standalone agent distro |
| Liaison | Hermes profile `agent-tutor-orchestrator` | First mate session inside the distro |
| Workers | Claude Code TUIs in tmux session `tutor`, or Hermes Kanban | Crewmates in tmux / other backends |
| Mutation | Tutor never edits/tests/commits/opens PRs; workers do | First mate read-only except guarded fleet paths |
| Isolation | Branch-per-delegate worktrees; optional treehouse | treehouse (or backend-specific) by default |
| Routing | `classifier-policy` skill: task class → harness, model tier, effort, in a versioned policy file | Preference files: task class → model, harness, effort |
| Scope | One profile among talk/build/flow/ship/overnight layers | The whole product is the crew orchestrator |

## Routing is a policy, not a preference

firstmate routes by durable rules in preference files. This kit reaches the same
place from the other side: the [`classifier-policy`](../plugins/dev-skills/skills/classifier-policy/SKILL.md)
skill keeps the same rule table in one versioned file, names cost tiers instead
of vendor models, and ships a checker for it. Use it when a routing decision must
be reproducible on another machine. See
[`skills-catalog.md`](skills-catalog.md).

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
