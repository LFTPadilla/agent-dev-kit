# Skill curation for public release

Source: a private skills registry of 45 `shared/` skills. Not all are
publishable — some are coupled to private infrastructure, some are
client/personal. This file tracks the triage so migration stays honest.

**Rule:** before a skill moves into `plugins/dev-skills/skills/`, read it end to
end and strip: absolute paths, host IPs, account IDs, internal system names
(brokers, gateways, bot names), client names, vendored `node_modules`/`.clawhub`.

## Migrated (public, in repo)

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

## Held back — need a rewrite, not a scrub

These are bound to the OpenClaw platform (auth flows, gateway cron, committed
WASM), not just decorated with stray paths. Publishing means re-implementing
the capability generically, so they wait.

- ocr-skill            — requires *committed* node_modules (tesseract WASM can't be bundled); doesn't fit a dependency-free repo
- gmail-oauth, google-auth, google-drive, gcalcli-calendar — OpenClaw-bound Google auth ("connect the client's account", broker token paths)
- reminder             — Discord/Telnyx/cron via the gateway layer
- ssh-exec             — Tailscale-node + clawhub coupling

## Excluded — coupled to private infra (do NOT publish as-is)

acp-triage, agency, agent-constraints, brave-search, broker-browser,
broker-web, firefly, http-stt, http-tts, telnyx-voice-call, vikunja,
discord-admin, discord-channel-factory, discord-csv-handler,
discord-data-showcase, discord-embed-builder, discord-format,
gateway-discord-channel-bind, gateway-user-onboarding

> These reference private brokers, gateways, hosts, or the OpenClaw stack.
> Generalize (remove the coupling) before any could be published.

## Excluded — private / client / redundant

- `SOP-privado-compartido.md`, `COMBAT_REFUSAL.md` — private docs
- tutela-legal — client-specific (legal, Colombia)
- caveman, caveman-commit, caveman-compress, caveman-help, caveman-review —
  already published as the `caveman` plugin; install that instead
- scheduled-reminders — deprecated upstream in favor of `reminder`
