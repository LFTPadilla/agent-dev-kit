# External dependencies

Skills in `plugins/dev-skills/` ship here. Everything below is upstream — install,
don't vendor. Flow map: [`how-it-fits-together.md`](how-it-fits-together.md).

## Core layers

| Tool | What it does | Install |
|---|---|---|
| **GSD** (`get-shit-done-cc`) | Spec-driven plan → execute → verify; installs the Hermes skill pack and `gsd-sdk` | `npm i -g get-shit-done-cc && get-shit-done-cc --hermes --global` |
| **Graphify** (`graphifyy`) | Local AST code graph for architecture, call paths, and impact analysis; Personal Dev Tutor uses the reviewed code-only release | `uv tool install graphifyy==0.9.25` (the profile installer installs platform skills) |
| **pi-gsd** | Optional Pi-native GSD helper/runtime | `npm i -g pi-gsd` |
| **caveman** | Compressed agent talk | Codex: `./scripts/install-codex-workhorse.sh`; Claude: `/plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman`; Hermes: `./scripts/install-hermes-workhorse.sh --all-profiles` |
| **ponytail** | Minimal diffs / YAGNI build mode | Codex: `./scripts/install-codex-workhorse.sh`; Claude: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail`; Hermes: `./scripts/install-hermes-workhorse.sh --all-profiles` |
| **Superpowers** (`obra/superpowers`) | Execution discipline (TDD, systematic debugging, verification evidence, review reception) | Antigravity: `agy plugin install https://github.com/obra/superpowers`; Codex: `/plugins` → search `superpowers`; Hermes: `hermes plugins install obra/superpowers --enable`; Claude: `/plugin marketplace add obra/superpowers-marketplace && /plugin install superpowers@superpowers-marketplace` (or `/plugin install superpowers@claude-plugins-official`) |
| **hypa** (`@hypabolic/hypa`) | Token-efficient shell + MCP proxy | `npm i -g @hypabolic/hypa && hypa init --agent claude && hypa init --agent codex` |
| **jean-claude** *(optional)* | Multi-machine / multi-account Claude sync | `npm i -g jean-claude` |

## Ship / run toolchain

| Tool | What it does | Install |
|---|---|---|
| **no-mistakes** | Ship-gate before merge (complements `/pr-review`) | Curl installer from [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) |
| **treehouse** | Multi-agent worktree isolation | Curl installer from [kunchenguid/treehouse](https://github.com/kunchenguid/treehouse) |
| **gnhf** | Overnight / long-running runner (pair with `overnight-task-kit/`) | `npm i -g gnhf` |
| **gh-axi** | Agent-shaped GitHub CLI output | `npm i -g gh-axi` |
| **skills CLI** | Install skill packs across harnesses; restores this repo's pinned third-party skills | `npx skills` ([vercel-labs/skills](https://github.com/vercel-labs/skills)) |
| **TOON** | Token-efficient agent-facing structured output | [toonformat.dev](https://toonformat.dev) |
| **addyosmani/agent-skills** | Lifecycle reference pack (install via skills CLI; do not copy) | `npx skills` against [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) |

## Quality & observability

Per-project usually; install where you use them.

| Tool | What | Install |
|---|---|---|
| **knip** | Dead code / unused exports | `npx knip` |
| **semgrep** | Deterministic SAST | `pipx install semgrep` |
| **bubblewrap** (`bwrap`, Linux) | Offline, empty-home verification boundary used by Personal Dev Tutor | distro package, e.g. `apt install bubblewrap`; requires unprivileged user namespaces |
| **lefthook** | Parallel git hooks | `npm i -D lefthook && npx lefthook install` |
| **gitleaks** | Secret scanning | `brew install gitleaks` or [releases](https://github.com/gitleaks/gitleaks) |
| **pip-audit** | Python dependency CVEs | `pipx install pip-audit` |
| **Sentry MCP** | Prod errors into the agent | see [`sentry-mcp.md`](sentry-mcp.md) |
| **Context7 MCP** | Current upstream library documentation for Hermes and Codex | endpoint `https://mcp.context7.com/mcp`; Codex: `codex mcp add context7 --url https://mcp.context7.com/mcp && codex mcp login context7` |
| **Playwright MCP** | Browser tools for `live-qa` | `claude mcp add playwright npx '@playwright/mcp@latest'` |
| **Stagehand** | Self-healing NL browser steps | `npm i @browserbasehq/stagehand` |
| **draw.io desktop CLI** | Export for `drawio-skill` | `brew install drawio` (+ optional `graphviz`) |
| **D2** | Polished, presentation-ready architecture diagrams | [d2lang.com](https://d2lang.com/tour/install) |
| **Mermaid CLI** (`mmdc`) | Render maintainable Mermaid sources to SVG/PNG | `npm i -g @mermaid-js/mermaid-cli` |

`bootstrap.sh` links this kit's skills into Codex's documented global user
directory (`~/.agents/skills`) and installs the pinned caveman and ponytail
releases there through `npx skills`, selecting only each pack's core skill. The
installer script owns the pinned CLI and release versions. Bootstrap also
installs the npm core it can and prints copy-paste blocks for the remaining
optional tools.

When Hermes is present, bootstrap additionally installs the pinned caveman and
ponytail skills and links them into every existing Hermes profile. Each managed
Hermes profile installer repeats that step for profiles created later.

Graphify is an Apache-2.0 upstream dependency and is not vendored. Personal Dev
Tutor requires the reviewed version 0.9.25 and runs `--code-only` by default. Semantic
LLM extraction and document/media/URL ingestion remain opt-in because they can
cross a provider boundary. Context7 requests should contain library questions,
not project source, secrets, or private documents.

## Pinned third-party skills (restored, never vendored)

`skills-lock.json` pins 17 third-party design skills by source repo, path, and a
sha256 of the skill folder. No copy is tracked in this repo. Restore them on a
host that wants them:

```bash
npx skills@1.5.22 experimental_install   # → .agents/skills/ (gitignored)
```

The lock records no git ref, so a restore follows each source's default branch;
when upstream has moved, the CLI rewrites that skill's `computedHash`, so treat a
`skills-lock.json` diff as the drift signal and review it before committing. Per
skill, source and license: [`ATTRIBUTION.md`](../ATTRIBUTION.md). Why these are
pinned instead of curated in: [`CURATION.md`](../CURATION.md).
