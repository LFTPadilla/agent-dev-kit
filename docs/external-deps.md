# External dependencies

Skills in `plugins/dev-skills/` ship here. Everything below is upstream — install,
don't vendor. Flow map: [`how-it-fits-together.md`](how-it-fits-together.md).

## Core layers

| Tool | What it does | Install |
|---|---|---|
| **GSD** (`pi-gsd`) | Spec-driven plan → execute → verify | `npm i -g pi-gsd` |
| **caveman** | Compressed agent talk | `/plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` |
| **ponytail** | Minimal diffs / YAGNI build mode | `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` |
| **hypa** (`@hypabolic/hypa`) | Token-efficient shell + MCP proxy | `npm i -g @hypabolic/hypa && hypa init --agent claude && hypa init --agent codex` |
| **jean-claude** *(optional)* | Multi-machine / multi-account Claude sync | `npm i -g jean-claude` |

## Ship / run toolchain

| Tool | What it does | Install |
|---|---|---|
| **no-mistakes** | Ship-gate before merge (complements `/pr-review`) | Curl installer from [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) |
| **treehouse** | Multi-agent worktree isolation | Curl installer from [kunchenguid/treehouse](https://github.com/kunchenguid/treehouse) |
| **gnhf** | Overnight / long-running runner (pair with `overnight-task-kit/`) | `npm i -g gnhf` |
| **gh-axi** | Agent-shaped GitHub CLI output | `npm i -g gh-axi` |
| **skills CLI** | Install skill packs across harnesses | `npx skills` ([vercel-labs/skills](https://github.com/vercel-labs/skills)) |
| **TOON** | Token-efficient agent-facing structured output | [toonformat.dev](https://toonformat.dev) |
| **addyosmani/agent-skills** | Lifecycle reference pack (install via skills CLI; do not copy) | `npx skills` against [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) |

## Quality & observability

Per-project usually; install where you use them.

| Tool | What | Install |
|---|---|---|
| **knip** | Dead code / unused exports | `npx knip` |
| **semgrep** | Deterministic SAST | `pipx install semgrep` |
| **lefthook** | Parallel git hooks | `npm i -D lefthook && npx lefthook install` |
| **gitleaks** | Secret scanning | `brew install gitleaks` or [releases](https://github.com/gitleaks/gitleaks) |
| **pip-audit** | Python dependency CVEs | `pipx install pip-audit` |
| **Sentry MCP** | Prod errors into the agent | see [`sentry-mcp.md`](sentry-mcp.md) |
| **Playwright MCP** | Browser tools for `live-qa` | `claude mcp add playwright npx '@playwright/mcp@latest'` |
| **Stagehand** | Self-healing NL browser steps | `npm i @browserbasehq/stagehand` |
| **draw.io desktop CLI** | Export for `drawio-skill` | `brew install drawio` (+ optional `graphviz`) |

`bootstrap.sh` installs the npm core it can and prints copy-paste blocks for the rest.
