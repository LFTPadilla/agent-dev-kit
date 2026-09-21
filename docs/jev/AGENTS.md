# AGENTS.md — Jev Review (ship score loop)

Load this folder when the task is Jev Review: install, harness wiring,
`jev_review` usage, or how it relates to `/pr-review`.

Humans start at [`README.md`](README.md). Agents follow that file too.

## Invariants

1. This kit does not vendor Jev Review. Upstream is
   [NiazMorshed2007/jev-review](https://github.com/NiazMorshed2007/jev-review).
2. Never write `JEV_API_KEY` into git, docs, or committed config. The key stays
   in the agent process environment.
3. Jev returns scores. The coding agent diagnoses, edits, and validates.
4. `/pr-review` and no-mistakes stay ship gates. Jev does not replace them.
5. Do not invent extra Jev tools. The MCP exposes one tool: `jev_review`.

## Routing

| Need | File |
|---|---|
| Loop, install, harness map, secrets | [`README.md`](README.md) |
| Installer | [`../../scripts/install-jev-review.sh`](../../scripts/install-jev-review.sh) |
| Contract test | [`../../scripts/test-jev-review.sh`](../../scripts/test-jev-review.sh) |
| Dep table row | [`../external-deps.md`](../external-deps.md) |
| Stack map | [`../how-it-fits-together.md`](../how-it-fits-together.md) |
| Adversarial PR review | [`../../plugins/dev-skills/commands/pr-review.md`](../../plugins/dev-skills/commands/pr-review.md) |
