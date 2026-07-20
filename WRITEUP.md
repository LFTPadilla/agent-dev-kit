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

Orthogonal layers, each governing one thing, composed together:

| Layer | Governs | Mechanism |
|---|---|---|
| **caveman** | how the agent *talks* | output compression (~75% fewer tokens) |
| **ponytail** | what the agent *builds* | YAGNI / stdlib-first / shortest diff |
| **GSD** | how work *flows* | plan → execute → verify |
| **dev-skills** (this repo) | discrete *capabilities* | per-task skills + commands (20 skills) |
| **ship / overnight / orchestration** | gates, isolation, long runs, pure orchestration | no-mistakes, treehouse, gnhf, AXI/TOON, Agent Tutor Orchestrator, `orchestrate` |

They don't overlap, so they don't fight. caveman and ponytail are other people's
plugins (credited); GSD is an npm package; the ship/overnight tools are external
companions. The contribution here is treating them as a *layered system*, filling
the capability layer, and making ship/overnight/orchestration first-class.

Skill distribution is also layered: this marketplace ships the curated 20;
**vercel-labs/skills** installs additional packs; **addyosmani/agent-skills**
is a reference lifecycle pack (not vendored).

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
**no-mistakes** sits beside this as an external ship gate, not a replacement.

## Live QA as three layers, not one tool

"Stable" and "realistic" pull in opposite directions, so I stopped picking one:

1. Deterministic Playwright specs (hardened: role locators, web-first asserts,
   real-user `storageState` auth instead of mocked sessions) — the stable floor.
2. A Playwright-MCP agent that *explores* the running app like a user — finds what
   fixed specs can't.
3. Stagehand self-healing steps for the parts of the UI that churn.

## Orchestration and overnight

1. **`orchestrate`** — explicit planner mode: decompose, route workers, verify.
2. **Agent Tutor Orchestrator / `ai-workflow-orchestrator`** — pure orchestrator: holds the
   picture, delegates to tmux or Kanban, audits on disk. Chosen over adopting
   firstmate as a runtime (see [docs/agent-tutor-vs-firstmate.md](docs/agent-tutor-vs-firstmate.md)).
3. **Overnight** — `overnight-task-kit/` is protocol and templates; **gnhf** is
   the preferred runner. No second ralph-loop.
4. **treehouse** — isolate parallel agents in worktrees so they don't stomp each other.
5. **AXI + TOON** — contracts and token-efficient agent-facing structured output
   (prefer TOON when the consumer is another agent; JSON when the schema demands it).

## Measuring instead of asserting

`evals/` is a small benchmark with planted bugs and a clean control. It scores
every reviewer on recall *and* false-positive rate. It's deliberately honest:
semgrep misses the semantic cases, and that gap is shown, not hidden — it's the
exact value the LLM layer has to add. The method is the point; keep counts and
"not run" notes honest in PROTOCOL.

## What I deliberately left out

1. ECC ships 60+ per-language reviewers. For a TS/React/Node stack that's
   over-engineering — I took the *ideas* (FP gate, prompt-defense), not the bulk.
2. The source registry had ~45 skills; over half were coupled to private infra or
   were redundant with existing plugins. `CURATION.md` records exactly what was
   cut and why. Shipping less, on purpose, is the senior move.
3. firstmate as a runtime — documented comparison only; Agent Tutor Orchestrator remains the
   generalist orchestrator surface here.
4. Vendoring entire third-party skill packs (addyosmani and similar) — install
   via skills CLI instead.

## Composition with private overlays

This repo stays generalist and public-safe. Employer-local skills live in a
private org skills registry *outside* this tree. At install time you compose:
public kit + private overlay. Docs never name the private org.

## What this is meant to show

Not "I can install plugins." It's: separating concerns across an agent stack,
designing for the real failure mode (false confidence), measuring quality
instead of claiming it, defending trust boundaries (prompt-injection on
untrusted input), making ship/overnight/orchestration first-class, and the
discipline to attribute what's borrowed and delete what doesn't earn its place.
