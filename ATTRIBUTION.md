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
block was trimmed of platform-specific (openclaw/hermes) install hints. All
credit to the original author.

Source: https://github.com/Agents365-ai/drawio-skill — MIT, Copyright (c) 2026 Agents365-ai.

## improve — shadcn/improve (MIT)

`plugins/dev-skills/skills/improve/` is vendored verbatim (its `LICENSE.md` is
kept in that directory). A read-only "senior advisor" skill: audits a codebase
and writes execution plans for other agents.

Source: https://github.com/shadcn/improve — MIT, Copyright (c) 2026 shadcn.
