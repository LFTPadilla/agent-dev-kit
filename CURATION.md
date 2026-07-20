# Skill curation for public release

Source: a private skills registry of 45 `shared/` skills. Not all are
publishable — some are coupled to private infrastructure, some are
client/personal. This file tracks the triage so migration stays honest.

**Rule:** before a skill moves into `plugins/dev-skills/skills/`, read it end to
end and strip: absolute paths, host IPs, account IDs, internal system names
(brokers, gateways, bot names), client names, vendored `node_modules`/`.clawhub`.

## Migrated (public, in repo) — 20 skills

### Agentic core

- [x] orchestrate
- [x] ai-workflow-orchestrator — Agent Tutor Orchestrator playbook; keep employer-free

### Utilities

- [x] git-essentials
- [x] human-writing-style
- [x] pdf
- [x] web-browse
- [x] find-skills
- [x] image-finalize
- [x] excel-xlsx        — scrubbed: absolute paths → relative, creator string → generic
- [x] word-docx         — same scrub as excel
- [x] diagram-render    — scrubbed paths/example hostnames; needs `sharp` (npm install per host)
- [x] tex-render        — scrubbed; needs mathjax/svg2img/sharp (npm install per host)
- [x] knip
- [x] improve           — vendored (shadcn/improve, MIT)
- [x] drawio-skill      — vendored (Agents365-ai/drawio-skill, MIT)
- [x] semgrep
- [x] security-checklist
- [x] playwright-stability
- [x] live-qa
- [x] stagehand

## External toolchain (documented, not vendored)

Adopt as day-to-day companions; do not copy into `plugins/dev-skills/`:

1. **no-mistakes** — ship gate alongside `/pr-review`
2. **treehouse** — worktree isolation for parallel agents
3. **gnhf** — preferred overnight runner (`overnight-task-kit/` = protocol)
4. **AXI / TOON** — contracts + agent-facing structured output
5. **vercel-labs/skills** — skill install CLI
6. **addyosmani/agent-skills** — reference lifecycle packs via skills CLI

**Not adopted as runtime:** firstmate (compare in
[docs/agent-tutor-vs-firstmate.md](docs/agent-tutor-vs-firstmate.md); Agent Tutor Orchestrator stays
the generalist orchestrator in this kit).

## Held back — need a rewrite, not a scrub

These are bound to private platform assumptions (auth flows, gateway cron,
committed WASM), not just decorated with stray paths. Publishing means
re-implementing the capability generically, so they wait.

- ocr-skill            — requires *committed* node_modules (tesseract WASM can't be bundled); doesn't fit a dependency-free repo
- gmail-oauth, google-auth, google-drive, gcalcli-calendar - private-platform Google auth ("connect the user's account", broker token paths)
- reminder             — Discord/Telnyx/cron via the gateway layer
- ssh-exec             — Tailscale-node + clawhub coupling

## Excluded — coupled to private infra (do NOT publish as-is)

acp-triage, agency, agent-constraints, brave-search, broker-browser,
broker-web, firefly, http-stt, http-tts, telnyx-voice-call, vikunja,
discord-admin, discord-channel-factory, discord-csv-handler,
discord-data-showcase, discord-embed-builder, discord-format,
gateway-discord-channel-bind, gateway-user-onboarding

> These reference private brokers, gateways, hosts, or a private platform stack.
> Generalize (remove the coupling) before any could be published.

## Excluded — private / client / redundant

- `SOP-privado-compartido.md`, `COMBAT_REFUSAL.md` — private docs
- tutela-legal — client-specific (legal, Colombia)
- caveman, caveman-commit, caveman-compress, caveman-help, caveman-review —
  already published as the `caveman` plugin; install that instead
- scheduled-reminders — deprecated upstream in favor of `reminder`

## Composition note

Employer-local skills belong in a **private org skills registry** outside this
repo. Compose at install time (symlink / profile overlay). Never name private
orgs or employer paths in this public tree.
