# Docs index

Start with the [kit architecture diagram](../docs/diagrams/agent-dev-kit-architecture.svg)
in the [root README](../README.md), then pick a lane.

## Start here

| Doc | Read it when |
|---|---|
| [https://agent-dev-kit.devpipe.net/](https://agent-dev-kit.devpipe.net/) | **Live Web Platform.** Interactive showcase, terminal simulator & 22-skills explorer (source: `agent-dev-kit-web`, a separate repo) |
| [how-it-fits-together.md](how-it-fits-together.md) | You want the one map: runtimes → behavior → orchestration → gates |
| [skills-catalog.md](skills-catalog.md) | You want to know what the 22 skills do and what triggers them |
| [external-deps.md](external-deps.md) | You want install commands for everything not vendored here |

## Orchestrators

| Doc | Read it when |
|---|---|
| [agent-tutor-orchestrator.md](agent-tutor-orchestrator.md) | You need a strict liaison that never edits |
| [agent-tutor-vs-firstmate.md](agent-tutor-vs-firstmate.md) | You are choosing between the strict profile and firstmate |

## Configuration

| Doc | Read it when |
|---|---|
| [profiles.md](profiles.md) | You are wiring a runtime manifest in `profiles/` |
| [agent-native-architecture.md](agent-native-architecture.md) | **Architecture Standard.** ANRS-1.0 Context Engineering, Hub-and-Spoke AGENTS.md & O(1) REGISTRY.yaml |
| [private-overlays.md](private-overlays.md) | Employer/org skills must stay out of this tree |
| [sandbox-policies.md](sandbox-policies.md) | You are changing what a worker is allowed to touch |

## Safety & observability

| Doc | Read it when |
|---|---|
| [prompt-defense.md](prompt-defense.md) | An agent reads untrusted input (diffs, web pages, issues) |
| [sentry-mcp.md](sentry-mcp.md) | You want prod errors inside the agent loop |

## Meta

| Doc | Read it when |
|---|---|
| [going-public.md](going-public.md) | You are publishing a change to this repo |
| [../evals/README.md](../evals/README.md) | You want the benchmark, not the claim |
| [../evals/PROTOCOL.md](../evals/PROTOCOL.md) | You want the scored runs and their caveats |
| [../ATTRIBUTION.md](../ATTRIBUTION.md) · [../CURATION.md](../CURATION.md) | What is borrowed, what was deliberately left out |

## Diagrams

Two source styles live in [`diagrams/`](diagrams):

- **D2 / Mermaid** — rebuild every SVG with `npm run render:diagrams`.
- **Editorial (diagram-design)** — `*.html` is the source of truth; SVG/PNG
  exports are produced from it (see `references/export.md` in the skill).

| Source | Renders |
|---|---|
| [`stack.d2`](diagrams/stack.d2) | Hero: the whole tool stack |
| [`agent-dev-kit-architecture.html`](diagrams/agent-dev-kit-architecture.html) | README hero — the kit, on one screen (diagram-design) |
| [`agent-dev-kit-architecture.html`](diagrams/agent-dev-kit-architecture.html) | `social-preview.png` (1200×640) — the manual upload |

**Social preview is the one manual step.** GitHub has no API for it: export
`social-preview.png` from `agent-dev-kit-architecture.html` (diagram-only
render), then upload it under *repo → Settings → General → Social preview*.
That image is what renders when the repo link is pasted into Slack, X, or
LinkedIn.

## Demo

[`demo/`](demo) holds a **real captured terminal session**
([`session.txt`](demo/session.txt)) and the GIF built from it. Nothing is
staged — recapture by rerunning the commands in the transcript, then:

```bash
npm run render:demo   # needs ffmpeg; SVG frames -> sharp -> GIF, no recorder dependency
```

The renderer fails loudly if the transcript stops showing the results the
README quotes.
