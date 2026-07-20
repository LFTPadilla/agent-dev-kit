# AGENTS.md — how agents use this repo

Instructions for coding agents working in or with **agent-dev-kit**. Humans
read the README; agents follow this file.

## What this repo is

A public, generalist kit for directing coding agents. It ships curated skills,
an adversarial `/pr-review` command, evals, overnight protocol templates, and an
Agent Tutor Orchestrator profile. It is meant to compose with optional
**private org skills overlays** that live *outside* this git tree.

## Layers (do not collapse them)

| Layer | Governs | Where |
|---|---|---|
| caveman | how the agent talks | external plugin |
| ponytail | what the agent builds | external plugin |
| GSD | how work flows (plan → execute → verify) | external (`pi-gsd`) |
| dev-skills | discrete capabilities | `plugins/dev-skills/` (this repo) |
| ship / overnight / orchestration | gates, isolation, long runs, pure orchestration | external toolchain + `overnight-task-kit/` + Agent Tutor Orchestrator + `orchestrate` / `ai-workflow-orchestrator` skills |

Full map: [docs/how-it-fits-together.md](docs/how-it-fits-together.md).
External installs: [docs/external-deps.md](docs/external-deps.md).

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
7. Use **Agent Tutor Orchestrator** / `ai-workflow-orchestrator` when the user
   wants a pure orchestrator (no direct edits). See
   [docs/agent-tutor-vs-firstmate.md](docs/agent-tutor-vs-firstmate.md).

## Hard rules

1. **Do not invent dependencies.** If a tool is not listed in
   `docs/external-deps.md`, `package.json`, skill frontmatter, or
   `skill-provenance.json`, do not assume it is installed. Suggest install from
   those docs instead of fabricating paths or package names.
2. **Never leak employer or client data.** No private org names, hostnames,
   internal ticket IDs, customer names, private repo paths, or employer-local
   profile names in commits, docs, skill text, examples, or eval fixtures.
   Private context belongs in overlays outside this repo
   ([docs/private-overlays.md](docs/private-overlays.md)).
3. **Do not vendor** large third-party skill packs into this tree. Document and
   bootstrap install instead.
4. **Keep public surfaces generic.** Session defaults, clone-from sources, and
   worklog paths must stay configurable via env/flags with generic defaults
   (e.g. tmux session `tutor`), never employer-named defaults.
5. **Attribute adaptations.** If you adapt text or ideas from another open
   project, update [ATTRIBUTION.md](ATTRIBUTION.md).
6. **Match versions.** When bumping skills or plugin metadata, keep
   `package.json`, `plugins/dev-skills/.claude-plugin/plugin.json`, and
   `plugins/dev-skills/.codex-plugin/plugin.json` aligned.

## Where to look

| Need | Path |
|---|---|
| Skill catalog (all 20) | `docs/skills-catalog.md` |
| Provenance / license / risk | `skill-provenance.json` |
| Curation decisions | `CURATION.md` |
| Design thesis | `WRITEUP.md` |
| Going-public checklist | `docs/going-public.md` |
| Agent Tutor Orchestrator | `docs/agent-tutor-orchestrator.md`, `profiles/agent-tutor-orchestrator.yml` |
| How layers fit | `docs/how-it-fits-together.md` |
| Profiles / multi-runtime | `docs/profiles.md` |

## Adding or changing skills

1. Add `plugins/dev-skills/skills/<name>/SKILL.md` with clear `description`.
2. Scrub private paths and names before commit.
3. Update `skill-provenance.json` and `docs/skills-catalog.md`.
4. Bump plugin versions with `package.json`.
5. Run `npm run validate`.
