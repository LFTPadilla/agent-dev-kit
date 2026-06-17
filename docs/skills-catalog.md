# Skills catalog — what's here and how to use it

## How any of this triggers

- **Skills** activate automatically when your request matches a skill's
  `description` (the agent reads them and picks). You can also just name one:
  "use knip", "run the live-qa skill". Nothing to import.
- **Commands** are typed with a slash: `/pr-review <PR-URL>`.
- **Templates** are files you copy into a project (not auto-applied).
- **External tools** (GSD, caveman, ponytail, MCP servers) install separately —
  see [external-deps.md](external-deps.md).

## Skills (18)

### Documents & media
| Skill | Adds | Triggers on |
|---|---|---|
| `pdf` | Inspect / summarize / split / merge / convert PDFs | "work with this PDF", "summarize the PDF" |
| `excel-xlsx` | Build `.xlsx` from tables/CSV/JSON | "make a spreadsheet", "export to Excel" |
| `word-docx` | Build `.docx` from a title + body | "write a Word doc", "make a .docx" |
| `diagram-render` | Network/infra/flow diagrams → PNG (SVG+sharp) — quick, static | "draw the topology", "render this diagram" |
| `drawio-skill` | NL → editable `.drawio` diagrams (presets, 10k+ shapes, AI/LLM logos, PNG/SVG/PDF export) — when you want an *editable* diagram, not just a PNG. Needs draw.io desktop CLI. Vendored, MIT. | "make an architecture/ER/UML diagram", "diagram I can edit" |
| `tex-render` | LaTeX math → PNG/SVG (MathJax) | "render this equation as an image" |
| `image-finalize` | Two-stage image gen (draft → polish) | "generate an image", "refine this image" |

### Code quality
| Skill | Adds | Triggers on |
|---|---|---|
| `knip` | Find dead code / unused exports / unused deps (TS/JS) | "clean up bloat", "find unused code", before a refactor |
| `improve` | Senior-advisor audit (read-only) → writes prioritized implementation plans for *other* agents to execute. Pairs your most-capable model (audit) with cheaper executors. | "audit this codebase", "where should this project go", "write a plan for X" |
| `git-essentials` | Git command/workflow reference | git workflow questions |

### Security
| Skill | Adds | Triggers on |
|---|---|---|
| `semgrep` | Deterministic SAST scan (rule packs) | "security scan", before an auth/payment PR |
| `security-checklist` | Pattern→severity→fix review at trust boundaries (LLM complement to semgrep) | reviewing auth/payments/input/uploads |

### QA / E2E
| Skill | Adds | Triggers on |
|---|---|---|
| `playwright-stability` | Anti-flaky checklist + real-user storageState auth | flaky tests, hardening a suite, "stop mocking the session" |
| `live-qa` | Drive the running app like a user via Playwright MCP; report console/network/visual issues | "QA this feature live", "walk the flow as a user" |
| `stagehand` | Self-healing natural-language browser steps for volatile flows | selectors keep breaking on a changing UI |

### Search & writing
| Skill | Adds | Triggers on |
|---|---|---|
| `find-skills` | Discover/install skills for a need | "is there a skill for X" |
| `web-browse` | Real-browser navigation/scrape for dynamic sites | "browse to", "extract from this site" |
| `human-writing-style` | Direct, human prose (bans filler/AI-isms) | writing docs/messages |

## Commands

| Command | Adds |
|---|---|
| `/pr-review <PR-URL> [...]` | Multi-lens PR self-review (correctness/security/perf/quality + ponytail advisory) with a pre-report gate, false-positive skip-list, and adversarial verification of every BLOCKER/HIGH/MEDIUM. Read-only. |

## Templates (copy into a project)

| Template | Adds |
|---|---|
| `templates/lefthook.yml` | Fast git gate: secrets+typecheck+lint on commit, knip+semgrep on push. `npx lefthook install`. |
| `templates/playwright/auth.setup.ts` | Login once as a real user → reuse session (storageState). |

## A typical session

1. Build a feature (ponytail keeps it minimal, context7 for current library docs).
2. `/knip` + `/semgrep` (or the lefthook gate) before committing.
3. `/live-qa` to walk the flow like a user on the running app.
4. `/pr-review <url>` before merge.
5. Sentry MCP to triage anything that breaks in prod.
