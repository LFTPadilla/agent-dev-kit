# Designing an agent development system

Notes on how this kit is put together and why. The point isn't the individual
skills — it's the architecture they sit in, and the judgment about what to build,
what to adapt, and what to leave out.

## The problem

Coding agents are capable but undirected. Out of the box they over-build, talk
too much, review their own work with rose-tinted glasses, and break the moment a
UI changes. The fix isn't a bigger prompt — it's a **system** with separated
concerns, measurable quality gates, and honest boundaries.

## The layering thesis

Four orthogonal layers, each governing one thing, composed together:

| Layer | Governs | Mechanism |
|---|---|---|
| **caveman** | how the agent *talks* | output compression (~75% fewer tokens) |
| **ponytail** | what the agent *builds* | YAGNI / stdlib-first / shortest diff |
| **GSD** | how work *flows* | plan → execute → verify |
| **dev-skills** (this repo) | discrete *capabilities* | per-task skills + commands |

They don't overlap, so they don't fight. caveman and ponytail are other people's
plugins (credited); GSD is an npm package. The contribution here is treating them
as a *layered system* and filling the capability layer.

## The piece I'm proudest of: adversarial PR review

Naive LLM code review has one dominant failure mode — confident false positives.
`pr-review` attacks it from both ends:

1. **Prevent** — a pre-report gate (cite the line, name the trigger, read the
   callers, defend the severity) plus a curated false-positive skip-list stop
   most noise before it's written.
2. **Refute** — every BLOCKER/HIGH/MEDIUM finding is then handed to an
   independent panel of verifiers prompted to *disprove* it, defaulting to
   "false positive" unless they can confirm the defect in the real code. Majority
   vote survives.

Prevention is cheap, refutation is expensive — so prevention runs first and the
expensive pass only sees what survived. The skip-list/gate ideas are adapted from
ECC (MIT, credited); the multi-lens + adversarial-verify architecture is mine.

## Live QA as three layers, not one tool

"Stable" and "realistic" pull in opposite directions, so I stopped picking one:

- Deterministic Playwright specs (hardened: role locators, web-first asserts,
  real-user `storageState` auth instead of mocked sessions) — the stable floor.
- A Playwright-MCP agent that *explores* the running app like a user — finds what
  fixed specs can't.
- Stagehand self-healing steps for the parts of the UI that churn.

## Measuring instead of asserting

`evals/` is a small benchmark with planted bugs and a clean control. It scores
every reviewer on recall *and* false-positive rate. It's deliberately honest:
semgrep misses the semantic cases, and that gap is shown, not hidden — it's the
exact value the LLM layer has to add. Five cases is a method demonstration, not a
verdict; the method is the point.

## What I deliberately left out

- ECC ships 60+ per-language reviewers. For a TS/React/Node stack that's
  over-engineering — I took the *ideas* (FP gate, prompt-defense), not the bulk.
- The source registry had ~45 skills; over half were coupled to private infra or
  were redundant with existing plugins. `CURATION.md` records exactly what was
  cut and why. Shipping less, on purpose, is the senior move.

## What this is meant to show

Not "I can install plugins." It's: separating concerns across an agent stack,
designing for the real failure mode (false confidence), measuring quality
instead of claiming it, defending trust boundaries (prompt-injection on
untrusted input), and the discipline to attribute what's borrowed and delete
what doesn't earn its place.
