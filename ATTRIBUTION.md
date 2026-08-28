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

## herdr — herdrdev/herdr (Apache-2.0)

`plugins/dev-skills/skills/herdr/` adapts the agent-facing CLI reference
and terminal multiplexing guidelines from Herdr. All credit to the original
authors.

Source: https://github.com/herdrdev/herdr — Apache License 2.0.


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

## Third-party design skills — pinned, not vendored

These 17 skills are other people's work. They are **not** vendored here: no copy
is tracked in this repo, and `.agents/` — where the skills CLI installs
project-scope skills — is gitignored. `skills-lock.json` pins each one by source
repo, path inside that repo, and `computedHash` (sha256 over the sorted
relative-path + content of the whole skill folder), so a restore is reproducible
and auditable. Restore with the upstream CLI:

```bash
npx skills@1.5.22 experimental_install   # → .agents/skills/<name>
```

| Skill | Source | License |
|---|---|---|
| 3d-web-experience | [sickn33/antigravity-awesome-skills](https://github.com/sickn33/agentic-awesome-skills) | MIT |
| brandkit | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| design-taste-frontend | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| design-taste-frontend-v1 | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| full-output-enforcement | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| gpt-taste | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| hallmark | [nutlope/hallmark](https://github.com/Nutlope/hallmark) | MIT |
| high-end-visual-design | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| image-to-code | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| imagegen-frontend-mobile | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| imagegen-frontend-web | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| impeccable | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Apache-2.0 |
| industrial-brutalist-ui | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| lightweight-3d-effects | [freshtechbro/claudedesignskills](https://github.com/freshtechbro/claudedesignskills) | MIT |
| minimalist-ui | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| redesign-existing-projects | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| stitch-design-taste | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |

Licenses were read from each repo's GitHub-detected license, not inferred. Every
source resolves to a real license, so no entry carries the
`UNLICENSED-UPSTREAM` marker that `skills-lock.json` reserves for sources with
no detectable license. `sickn33/antigravity-awesome-skills` has since been
renamed to `sickn33/agentic-awesome-skills`; the lock keeps the name it was
pinned under and GitHub redirects the clone.

impeccable is Apache-2.0, which attaches notice obligations to *redistribution*.
This repo redistributes none of these skills, so nothing is carried here — a
downstream project that vendors one instead of pinning it inherits those
obligations itself.

## Judgment notes (not attribution of code)

1. **Agent Tutor Orchestrator vs firstmate** — this kit ships Agent Tutor Orchestrator as a generalist
   pure-orchestrator profile. firstmate is not adopted as a runtime; see
   [docs/agent-tutor-vs-firstmate.md](docs/agent-tutor-vs-firstmate.md).
2. **Ship / overnight layer** — ship gates and overnight loops are first-class
   in the architecture (README diagram), with gnhf preferred as the overnight
   engine and local overnight-task-kit as protocol.
