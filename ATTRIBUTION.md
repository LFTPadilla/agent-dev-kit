# Attribution

This kit adapts ideas and text from other open-source projects, with thanks.

## ECC — affaan-m/ECC (MIT)

The following are adapted (condensed and reworded) from ECC's reviewer agents:

- `plugins/dev-skills/commands/pr-review.md` — the pre-report gate and the
  "common false positives — skip these" list.
- `docs/prompt-defense.md` — the prompt-injection defense baseline.
- `plugins/dev-skills/skills/security-checklist/SKILL.md` — the
  pattern → severity → fix table and security false-positive list.

Source: https://github.com/affaan-m/ECC — MIT License.

## drawio-skill — Agents365-ai/drawio-skill (MIT)

`plugins/dev-skills/skills/drawio-skill/` is vendored largely verbatim (its own
`LICENSE` is kept in that directory). Only change: the frontmatter `metadata`
block was trimmed of platform-specific install hints. All
credit to the original author.

Source: https://github.com/Agents365-ai/drawio-skill — MIT, Copyright (c) 2026 Agents365-ai.

## improve — shadcn/improve (MIT)

`plugins/dev-skills/skills/improve/` is vendored verbatim (its `LICENSE.md` is
kept in that directory). A read-only "senior advisor" skill: audits a codebase
and writes execution plans for other agents.

Source: https://github.com/shadcn/improve — MIT, Copyright (c) 2026 shadcn.

## Day-to-day toolchain (external, not vendored)

These are recommended companions. This repo documents and bootstraps them; it
does not vendor their binaries or full skill trees.

| Project | Role in this kit | Source |
|---|---|---|
| [no-mistakes](https://github.com/kunchenguid/no-mistakes) | Ship gate / mistake catcher; complements `/pr-review` | kunchenguid/no-mistakes |
| [treehouse](https://github.com/kunchenguid/treehouse) | Multi-agent worktree isolation / pools | kunchenguid/treehouse |
| [gnhf](https://github.com/kunchenguid/gnhf) | Preferred overnight runner; `overnight-task-kit/` is protocol + templates | kunchenguid/gnhf |
| [axi](https://github.com/kunchenguid/axi) (+ gh-axi) | Agent contract principles / AXIs | kunchenguid/axi |
| [TOON](https://toonformat.dev) | Token-efficient structured output for agent-facing channels | toonformat.dev |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | Modern skill install CLI (`npx skills`) | vercel-labs/skills |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Reference lifecycle skill packs (install via skills CLI; not copied into this tree) | addyosmani/agent-skills |

Layer plugins already called out in README / external-deps (caveman, ponytail,
GSD/pi-gsd, hypa) remain external with their own licenses and update channels.

## Judgment notes (not attribution of code)

1. **Agent Tutor Orchestrator vs firstmate** — this kit ships Agent Tutor Orchestrator as a generalist
   pure-orchestrator profile. firstmate is not adopted as a runtime; see
   [docs/agent-tutor-vs-firstmate.md](docs/agent-tutor-vs-firstmate.md).
2. **Ship / overnight layer** — ship gates and overnight loops are first-class
   in the architecture (README diagram), with gnhf preferred as the overnight
   engine and local overnight-task-kit as protocol.
