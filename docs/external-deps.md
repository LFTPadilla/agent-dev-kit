# External dependencies

This kit is two layers. The skills in `plugins/dev-skills/` ship in this repo.
The tools below are maintained elsewhere — install them, don't vendor them.

| Tool | What it does | Install | Source |
|---|---|---|---|
| **GSD** (`pi-gsd`) | Spec-driven workflow system: `/gsd:plan-phase`, `/gsd:execute-phase`, debugging, code review, atomic commits. Per-runtime install; `/gsd:update` keeps it current. | `npm i -g pi-gsd` | npm |
| **caveman** | Ultra-compressed output mode (~75% fewer tokens, full accuracy). Governs *how the agent talks*. | `/plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` | github |
| **ponytail** | Lazy-senior-dev mode: YAGNI, stdlib first, shortest diff. Governs *what the agent builds*. Pairs with caveman (talk vs build). | `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` | github |
| **jean-claude** *(optional)* | Sync Claude Code config across machines + manage multiple account profiles. | `npm i -g jean-claude` | npm |

## Why external, not vendored

These are actively maintained upstream with their own update channels
(`npm`, `/plugin update`). Vendoring them would fork the version and rot.
`bootstrap.sh` installs the npm ones and prints the `/plugin` commands.

## Quality & observability tools

Used by the `knip` / `semgrep` skills and the `templates/lefthook.yml` gate.
Per-project dev tools — install where you use them, not globally.

| Tool | What | Install |
|---|---|---|
| **knip** | Dead code / unused exports / unused deps (JS/TS). Mechanizes "delete what you don't need". | `npx knip` (no install needed) |
| **semgrep** | SAST — known bug/security patterns. Deterministic complement to LLM review. | `pipx install semgrep` |
| **lefthook** | Fast parallel git hooks. Orchestrates secrets+typecheck+lint on commit, knip+semgrep on push. | `npm i -D lefthook && npx lefthook install` |
| **Sentry MCP** | Pull prod issues/stack traces into the agent. See [`sentry-mcp.md`](sentry-mcp.md). | `claude mcp add --transport http sentry https://mcp.sentry.dev/mcp` |
| **Playwright MCP** | Drive a real browser as a tool — powers the `live-qa` skill. | `claude mcp add playwright npx '@playwright/mcp@latest'` |
| **Stagehand** | Self-healing NL browser automation on Playwright (`stagehand` skill). | `npm i @browserbasehq/stagehand` |

## Layering (no overlap)

- **caveman** = communication layer (prose).
- **ponytail** = code layer (what gets written).
- **GSD** = process layer (plan → execute → verify).
- **dev-skills** (this repo) = capability layer (discrete task skills).

All four compose. Run them together.
