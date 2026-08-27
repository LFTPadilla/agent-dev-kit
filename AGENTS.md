# AGENTS.md — how agents use this repo

Instructions for coding agents working in or with **agent-dev-kit**. Humans
read the README; agents follow this file.

## What this repo is

A public, generalist kit for directing coding agents. It ships curated skills,
an adversarial `/pr-review` command, evals, overnight protocol templates, and
the flagship Personal Dev Tutor profile. The strict Agent Tutor Orchestrator
remains available as an alternative. The kit composes with optional
**private org skills overlays** that live *outside* this git tree.

## Layers (do not collapse them)

| Layer | Governs | Where |
|---|---|---|
| caveman | how the agent talks | external plugin |
| ponytail | what the agent builds | external plugin |
| GSD | how work flows (plan → execute → verify) | external (`get-shit-done-cc` for Hermes; optional `pi-gsd` helper) |
| superpowers (guardrails) | how code tasks are executed (TDD, root-cause debug, verification evidence) | external (`obra/superpowers`) |
| dev-skills | discrete capabilities | [`plugins/dev-skills/AGENTS.md`](plugins/dev-skills/AGENTS.md) |
| ship / overnight / orchestration | gates, isolation, long runs, tutoring and pure orchestration | [`overnight-task-kit/AGENTS.md`](overnight-task-kit/AGENTS.md) + Personal Dev Tutor + Agent Tutor Orchestrator |

Full map: [`docs/how-it-fits-together.md`](docs/how-it-fits-together.md).
External installs: [`docs/external-deps.md`](docs/external-deps.md).

## Toolchain preferences

1. Prefer **GSD** for multi-step work (plan → execute → verify).
2. Prefer **treehouse** (or equivalent) for isolated parallel agent worktrees.
3. Prefer **no-mistakes** as a ship gate alongside `/pr-review`.
4. Prefer **gnhf** as the overnight runner; treat `overnight-task-kit/` as
   protocol and templates, not a second ralph-loop.
5. Prefer **AXI** principles for agent contracts; prefer **TOON** for
   agent-facing structured output when the consumer is another agent or a
   token-sensitive channel. Use JSON when the consumer is a strict JSON API,
   a human-facing config file, or an existing schema that already requires JSON.
6. Install extra skills via **vercel-labs/skills** (`npx skills`); reference
   lifecycle packs from **addyosmani/agent-skills** without vendoring them here.
7. Prefer **Personal Dev Tutor** / `personal-development-mentor` as the
   flagship GSD + Codex tutor-orchestrator for personal and learning projects.
   Use **Agent Tutor Orchestrator** / `ai-workflow-orchestrator` when the user
   specifically wants strict pure orchestration through Claude tmux panes or
   Hermes Kanban. See [`docs/personal-dev-tutor.md`](docs/personal-dev-tutor.md).
8. Prefer **Agent-Native Repository Architecture (ANRS-1.0)**: Use lightweight
   Hub-and-Spoke `AGENTS.md`, declarative `REGISTRY.yaml`, and progressive
   disclosure. See [`docs/agent-native-architecture.md`](docs/agent-native-architecture.md)
   and [`REGISTRY.yaml`](REGISTRY.yaml).
9. Prefer **Superpowers execution guardrails** (`test-driven-development`,
   `systematic-debugging`, `verification-before-completion`,
   `receiving-code-review`) during task implementation while keeping GSD
   authoritative for project lifecycle and state.

## Hard rules

1. **Do not invent dependencies.** If a tool is not listed in
   `docs/external-deps.md`, `package.json`, skill frontmatter, or
   `skill-provenance.json`, do not assume it is installed.
2. **Never leak employer or client data.** No private org names, hostnames,
   internal ticket IDs, customer names, private repo paths, or employer-local
   profile names in commits, docs, skill text, examples, or eval fixtures.
   Private context belongs in overlays outside this repo
   ([`docs/private-overlays.md`](docs/private-overlays.md)).
3. **Do not vendor** large third-party skill packs into this tree. Document and
   bootstrap install instead.
4. **Keep public surfaces generic.** Session defaults, clone-from sources, and
   worklog paths must stay configurable via env/flags with generic defaults.
5. **Attribute adaptations.** If you adapt text or ideas from another open
   project, update [`ATTRIBUTION.md`](ATTRIBUTION.md).
6. **Match versions.** When bumping skills or plugin metadata, keep
   `package.json`, `plugins/dev-skills/.claude-plugin/plugin.json`, and
   `plugins/dev-skills/.codex-plugin/plugin.json` aligned.

## Where to look (Semantic Routing Table)

| Need | Path |
|---|---|
| Declarative catalog (ANRS-1.0) | [`REGISTRY.yaml`](REGISTRY.yaml) |
| Dev-Skills Subsystem | [`plugins/dev-skills/AGENTS.md`](plugins/dev-skills/AGENTS.md) |
| Overnight Task Kit Subsystem | [`overnight-task-kit/AGENTS.md`](overnight-task-kit/AGENTS.md) |
| Skill catalog (all 23) | [`docs/skills-catalog.md`](docs/skills-catalog.md) |
| Provenance / license / risk | [`skill-provenance.json`](skill-provenance.json) |
| Curation decisions | [`CURATION.md`](CURATION.md) |
| Design thesis | [`WRITEUP.md`](WRITEUP.md) |
| Going-public checklist | [`docs/going-public.md`](docs/going-public.md) |
| Agent Tutor Orchestrator | [`docs/agent-tutor-orchestrator.md`](docs/agent-tutor-orchestrator.md), [`profiles/agent-tutor-orchestrator.yml`](profiles/agent-tutor-orchestrator.yml) |
| Personal Dev Tutor | [`docs/personal-dev-tutor.md`](docs/personal-dev-tutor.md), [`profiles/personal-dev-tutor.yml`](profiles/personal-dev-tutor.yml) |
| How layers fit | [`docs/how-it-fits-together.md`](docs/how-it-fits-together.md) |
| Profiles / multi-runtime | [`docs/profiles.md`](docs/profiles.md) |

## Git Worktree & Multi-Agent Coordination

1. **Main checkout protection:** The primary repository checkout (`~/programming/agent-dev-kit`) MUST ALWAYS remain on `main`. Never switch branches in place or commit directly on `main`.
2. **Dedicated worktrees in `.worktrees/`:** All task/ticket work must be done in an isolated worktree under `.worktrees/<task-slug>`:
   ```bash
   git worktree add -b <branch-name> .worktrees/<task-slug> origin/main
   ```
   Work, validate, and commit inside `.worktrees/<task-slug>`.
