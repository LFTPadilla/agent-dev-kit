# Docs index

Start with the [stack diagram](diagrams/stack.svg) in the
[root README](../README.md), then pick a lane.

## Start here

| Doc | Read it when |
|---|---|
| [how-it-fits-together.md](how-it-fits-together.md) | You want the one map: runtimes → behavior → orchestration → gates |
| [skills-catalog.md](skills-catalog.md) | You want to know what the 22 skills do and what triggers them |
| [external-deps.md](external-deps.md) | You want install commands for everything not vendored here |

## Orchestrators

| Doc | Read it when |
|---|---|
| [personal-dev-tutor.md](personal-dev-tutor.md) | **Flagship.** GSD + bounded Codex lanes + learning gates |
| [agent-tutor-orchestrator.md](agent-tutor-orchestrator.md) | You need a strict liaison that never edits |
| [agent-tutor-vs-firstmate.md](agent-tutor-vs-firstmate.md) | You are choosing between the strict profile and firstmate |

## Configuration

| Doc | Read it when |
|---|---|
| [profiles.md](profiles.md) | You are wiring a runtime manifest in `profiles/` |
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

Sources live in [`diagrams/`](diagrams) — `.d2` and `.mmd`. Rebuild every SVG:

```bash
npm run render:diagrams
```

| Source | Renders |
|---|---|
| [`stack.d2`](diagrams/stack.d2) | Hero: the whole tool stack |
| [`personal-dev-tutor-architecture.d2`](diagrams/personal-dev-tutor-architecture.d2) | Flagship orchestrator internals |
| [`personal-dev-tutor-flow.mmd`](diagrams/personal-dev-tutor-flow.mmd) | Flagship request → verification flow |
| [`social-preview.svg`](diagrams/social-preview.svg) | `social-preview.png` (1280×640) |

**Social preview is the one manual step.** GitHub has no API for it: after
`npm run render:diagrams`, upload `diagrams/social-preview.png` under
*repo → Settings → General → Social preview*. That image is what renders when
the repo link is pasted into Slack, X, or LinkedIn.

## Demo

[`demo/`](demo) holds a **real captured terminal session**
([`session.txt`](demo/session.txt)) and the GIF built from it. Nothing is
staged — recapture by rerunning the commands in the transcript, then:

```bash
npm run render:demo   # needs ffmpeg; SVG frames -> sharp -> GIF, no recorder dependency
```

The renderer fails loudly if the transcript stops showing the results the
README quotes.
