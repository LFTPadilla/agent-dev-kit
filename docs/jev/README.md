# Jev Review

Scalar software-quality loop for coding agents. Powered by
[Jev](https://typesafe.ai/) through the local MCP server in
[NiazMorshed2007/jev-review](https://github.com/NiazMorshed2007/jev-review).

This folder is the single source of truth for Jev in this kit. Other docs
point here.

## What it is

`jev_review` scores a focused implementation on independent dimensions
(correctness, complexity, changeability, coupling, tests, security, and
others). It does not edit files. It does not write a root-cause essay.

The coding agent still owns diagnosis, the patch, tests, and the stop
decision. Scores are evidence, not goals.

## What it is not

1. Not a replacement for [`/pr-review`](../../plugins/dev-skills/commands/pr-review.md).
2. Not a replacement for [no-mistakes](https://github.com/kunchenguid/no-mistakes).
3. Not a hosted backend in this kit. The only remote call is the Jev API from
   your machine, with your key.

Use `/pr-review` for adversarial PR findings. Use Jev while you implement, and
again before you call the work done.

## Operating loop

```text
implement → validate → score → inspect → hypothesis → improve → validate → rescore
```

For every nontrivial coding task:

1. Implement a coherent slice and run the relevant checks.
2. Call `jev_review` with `task` and the current `diff` to set a baseline.
3. Inspect the weakest important metrics yourself.
4. Make the smallest justified change that addresses that hypothesis.
5. Validate again.
6. Call `jev_review` with the new diff and the prior response in
   `previousEvaluation`.
7. Repeat while an important weak metric remains and another evidence-based
   change is available.

Do not stop after the first call. If a targeted score does not move,
reconsider the diagnosis. Do not make cosmetic edits to chase a number.

Send surrounding files only when needed to judge the change. Use
`repositoryContext` for conventions, invariants, and test results. Never send
secrets, `.env` files, vendored trees, or the whole repository.

## When to skip

1. Trivia, formatting-only diffs, and work that does not change code.
2. Search, planning, and orchestration that never writes an implementation.
3. Context too thin to judge.

Stop the loop when requirements hold, validation passes, targeted metrics
improved without a meaningful regression, and no justified change remains.

Never raise a score by adding speculative architecture, extra files, empty
tests, or comments that do not change behavior.

## Install

Requirements: Node 20+, a Jev API key from the
[TypeSafe console](https://console.typesafe.ai/).

```bash
export JEV_API_KEY=...          # process env only; never commit
./scripts/install-jev-review.sh
```

The script links the upstream skill and patches Hermes `mcp_servers` plus
Codex `config.toml`. It never writes the key into a file.

Override the checkout with `--root` or `JEV_REVIEW_ROOT`. Default lookup is
the Claude Code marketplace clone
`$HOME/.claude/plugins/marketplaces/NiazMorshed2007-jev-review`.

Claude Code can also install the plugin:

```bash
npx plugins add NiazMorshed2007/jev-review --target claude-code
```

Restart each harness after install so it loads the MCP server.

Contract test:

```bash
npm run test:jev-review
```

## Harnesses this kit wires

| Harness | What the installer does |
|---|---|
| Hermes | MCP entry in default config and every profile; skill link under `skills/` and `skills/external/`; loop paragraph in `SOUL.md` |
| Codex | MCP entry in `config.toml`; skill link under `~/.agents/skills`; loop paragraph in `AGENTS.md` |
| Claude Code | Plugin install (not this script). Same `dist/server.js`. |

Pi and other stdio MCP clients use the same server. Add a `jev-review` entry
that runs `node <checkout>/dist/server.js` and passes `JEV_API_KEY` from the
process environment.

Skip flags: `--skip-hermes`, `--skip-codex`, `--skip-instructions`.

## Secrets

`JEV_API_KEY` must exist in the environment of the process that starts the
agent. GUI launches and profile launchers do not inherit a login shell by
default. Put the key in that harness env file if you need it there. Keep the
file mode `0600`. Do not paste the key into this repo.

## Ship placement

In [`how-it-fits-together.md`](../how-it-fits-together.md) Jev sits in the
**ship** column with `/pr-review`, no-mistakes, and evals.

Recommended order on a finished change:

1. Jev loop on the implementation diff (this folder).
2. `/pr-review` on the PR.
3. no-mistakes before merge.
