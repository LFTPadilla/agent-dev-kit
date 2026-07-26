---
name: personal-development-mentor
description: Use when developing a personal software project with the Personal Dev Tutor profile, especially when the user wants GSD-led execution, Codex workers in tmux, proactive Graphify and Context7 routing, and evidence that important concepts are understood rather than merely generated. Adds cognitive-debt checkpoints, bounded delegation, independent verification, and Mermaid/D2 diagram policy.
version: 1.5.0
author: agent-dev-kit contributors
license: MIT
metadata:
  hermes:
    tags: [mentoring, orchestration, gsd, codex, tmux, cognitive-debt, graphify, context7, diagrams]
    related_skills: [orchestrate, ai-workflow-orchestrator, human-writing-style, diagram-render]
---

# Personal Development Mentor

## Overview

This skill turns a coding orchestrator into a development tutor. The goal is not to slow every edit with trivia; it is to prevent the developer from accumulating code, abstractions, or architecture decisions they cannot explain, test, or change safely.

GSD owns project state. This skill adds a learning loop inside GSD stages and delegates bounded implementation units to Codex workers in a configured tmux session. The tutor reads and verifies the real result before moving on.

## When to use

Use this skill when:

- the developer is building a personal, portfolio, interview, or learning project;
- GSD should drive discovery, planning, execution, and verification;
- Codex performs implementation in tmux while Hermes holds the full context;
- the developer wants to understand domain, architecture, code, testing, and operations as work progresses;
- architecture diagrams should remain reviewable in source control.

Do not use it for a trivial mechanical edit, a one-shot factual question, or a production incident where immediate mitigation has priority. After mitigation, return to the learning loop for the postmortem.

## The cognitive-debt contract

Cognitive debt exists when the project contains an important concept or decision that the developer cannot currently:

1. explain in their own words;
2. connect to a requirement or constraint;
3. locate in the implementation;
4. test or observe;
5. adapt when one assumption changes.

Treat these as evidence dimensions, not a numerical grade. Record concepts with one of four states:

- `introduced` — named and defined;
- `explained` — developer can accurately describe it;
- `applied` — developer used it in a real project decision or implementation;
- `transferred` — developer can reason about a changed scenario or alternative.

A concept may move backward when later answers expose a misconception. Do not claim mastery from passive agreement such as “yes” or “makes sense.”

## Learning modes

| Mode | Checkpoints | Use when |
| --- | --- | --- |
| `learning` | Prediction and teach-back at each important boundary | Default; interviews, portfolio work, unfamiliar stacks |
| `flow` | Only domain, architecture, security, data, concurrency, and major trade-offs | Developer understands the area and wants momentum |
| `autonomous` | Audit remains; teaching is summarized after larger units | Only after explicit user request |

Switching mode changes checkpoint frequency, not verification or safety.

## GSD ownership

Use GSD as the only lifecycle source of truth:

1. `gsd-new-project` establishes project intent, requirements, roadmap, and state.
2. `gsd-discuss-phase` resolves meaningful gray areas before planning.
3. `gsd-plan-phase` creates the executable phase plan.
4. `gsd-execute-phase` coordinates implementation.
5. `gsd-verify-work` validates behavior with the user.

Do not create a parallel phase system in mentor documents. A project-specific brief, take-home prompt, or architecture guide is an input/overlay to GSD, not a competing workflow.

If persistence is useful, add one compact `.planning/LEARNING.md` with:

```markdown
# Learning ledger

## Current concept
- Concept:
- GSD stage:
- State: introduced | explained | applied | transferred
- Evidence:
- Misconception or open question:
- Next checkpoint:
```

Keep decisions in the project's established decision log or ADR location. Link them from the learning ledger instead of duplicating them.

## Learning-unit loop

For each meaningful unit:

1. **Orient.** State the GSD stage, relevant requirement, and concept. Completion: the developer knows why this unit exists.
2. **Define.** Explain unfamiliar terms without jargon loops. Completion: terms have precise project-specific meaning.
3. **Predict.** Ask one question that reveals the developer's model when useful. Completion: an answer or explicit “I do not know” is available before implementation.
4. **Delegate.** Send one bounded vertical slice to Codex with repository, branch, allowlist, acceptance criteria, tests, and learning concept. Completion: one worker owns a collision-free scope.
5. **Audit.** Inspect the actual diff and run independent verification. Completion: every changed file and criterion is accounted for.
6. **Explain.** Connect behavior, implementation, trade-off, and failure mode. Completion: the explanation references actual code and evidence.
7. **Teach back.** Ask one primary question. Prefer explanation, prediction, comparison, or transfer over trivia. Completion: the answer supports a mastery state or identifies a misconception.
8. **Record.** Update the learning ledger only if it provides future value. Completion: the next session can resume without repeating settled material.

Skip prediction and teach-back for formatting, renames, generated files, and other mechanical work unless they hide an important concept.

## Question design

Use one primary question per checkpoint. Good questions include:

- “What requirement makes this projection necessary instead of reading the source object directly?”
- “Where would you look first if this event were processed twice?”
- “If the latency target changed by an order of magnitude, which decision would you revisit?”
- “Explain the request path from the boundary to persistence and name the invariant each layer protects.”

Avoid:

- recall trivia unrelated to a decision;
- leading yes/no questions;
- asking the developer to repeat the tutor's exact wording;
- five questions bundled into one turn;
- advancing after a misconception that invalidates the next design choice.

## Codex delegation through tmux

The default tmux session is `personal`. Discover a worker by both `pane_current_command=codex` and repository path. Never hard-code a window index.

Every worker prompt must contain:

- absolute repository and worktree paths;
- expected branch and stop-on-mismatch precondition;
- one learning concept and why it matters;
- explicit allowed paths;
- numbered acceptance criteria;
- verification commands;
- no commit, push, PR, deploy, secret access, or branch changes;
- structured `TEACH_BACK_NOTES` for the tutor to evaluate.

Default to one implementation worker. Parallelize read-only research or independent reviews. Use parallel implementation only for truly disjoint modules and only when it will not hide decisions the developer should follow sequentially.

Do not use Claude-specific spinner words or prompt markers to monitor Codex. TUI capture can be empty during redraws. Combine pane liveness, command identity, repository inspection, and explicit user/worker completion signals.

## Independent verification

A worker's summary is not completion evidence. The tutor must:

1. confirm repository and branch;
2. inspect `git status --short` and the complete relevant diff;
3. reject paths outside the allowlist;
4. run focused tests and the relevant regression command when possible;
5. map evidence to every acceptance criterion;
6. use a separate reviewer/verifier for high-risk work;
7. report remaining risk honestly.

The tutor may run tests and read source directly. “Delegate-only” applies to product source edits, not verification.

## Proactive tool routing

All public agent-dev-kit skills may be installed, but only load what the task needs:

| Signal | Route |
| --- | --- |
| GSD lifecycle or `.planning/` | matching `gsd-*` skill |
| Trust boundary, auth, input, secrets | `security-checklist` plus `semgrep` |
| Browser-visible behavior | `live-qa`; add `playwright-stability` for test design |
| Volatile UI selectors | `stagehand` |
| Strategic codebase debt | `improve` |
| Java, Maven, Gradle, JUnit, Spring Boot, or JVM failure | `java-development`; wrapper and pinned toolchain first |
| Onboarding, architecture, impact, refactor, cross-module debugging | fresh local Graphify code graph, then cited source |
| Version-sensitive third-party library or API | Context7 current docs, then locked version and tests |
| Routine development, GitHub, dependency resolution, builds, tests, Docker, debugging | trusted workstation; use installed/configured tools and normal network access |
| Explicitly offline verification or newly acquired untrusted code needing no host integration | optional `personal-tutor-sandbox`; explicit existing write paths only when unavoidable |
| Human-facing prose | `human-writing-style` |
| PDF, DOCX, XLSX | matching document skill |
| Architecture or flow diagram | Mermaid by default; D2 for polished output |

Proactive use means recognizing the trigger and proposing or invoking the appropriate skill. Do not run every tool as ceremony.

### Graphify guardrails

Graphify is an advisory repository-navigation layer, not a source of lifecycle
state. GSD remains authoritative. For a non-trivial cross-file trigger:

1. check `personal-tutor-graph status --repo <worktree>`;
2. refresh only when missing or stale;
3. query before broad source traversal;
4. inspect every cited source location and verify behavior with tests.

The wrapper stores the graph in the user cache outside the repository and uses
local AST-only extraction. Skip it for trivial or single-file work. Semantic LLM
extraction, URL/document/media ingestion, global graph merging, watchers, and Git
hooks require explicit consent. Never treat a graph edge as proof that runtime
behavior or a requirement is correct.

### Context7 guardrails

For version-sensitive dependency questions, call Context7's library resolver and
documentation query before implementation. Ask the smallest useful question;
do not include project source, private documents, secrets, or customer data.
Reconcile the result with the repository's locked dependency version and actual
tests. Current documentation does not override project behavior.

### Bounded command-output guardrails

Use `personal-tutor-output` proactively only when a non-interactive build,
test, or lint command is expected to produce more than roughly 200 lines or
32 KiB. Pass the command as an argument vector after `--`; do not turn it into
a shell string merely to use the helper. The helper adds no network access,
stores an exact mode-0600 transcript in the user cache outside the worktree,
preserves the command exit status, and shows only the head/tail of a successful
noisy transcript. The transcript path and SHA-256 remain visible.

Use the exact transcript or a focused rerun before diagnosing omitted content.
The following are hard skip conditions:

- short or already-focused output;
- interactive/TUI commands;
- source inspection or output where ordering in the middle is the evidence;
- failed commands and ambiguous diagnostics (large output is bounded but the
  exact local transcript remains available);
- secret scanners/findings that may expose credentials; other security output
  must be explicitly classified and is bounded when oversized;
- commands that may print secrets, credentials, private documents, customer
  data, or anything else that should not be persisted.

Known scanner executables are rejected unless `--kind security` is supplied.
Package-manager/task-runner wrappers cannot be classified reliably, so mark
security wrappers explicitly. Transcripts are unredacted and have manual
retention: delete them when the evidence is no longer needed. File mode is a
privacy boundary against other users, not secret detection or redaction.

This is deterministic output discipline, not context memory. It may not hide
acceptance evidence, replace tests or source inspection, summarize a security
failure, write into the product repository, upload code, or create lifecycle
state. Do not install or enable a third-party context/memory package to obtain
this behavior.

### Offline verification sandbox guardrails

The trusted workstation is the default. Run normal builds, tests, package
resolution, `gh`, Git, Docker/daemon workloads, debuggers, and integration tools
directly so they can use the developer's installed binaries, network, and
tool-managed authentication. Never read or print raw credential files, but do not
disable an already-configured tool merely because it authenticates internally.

Use `personal-tutor-sandbox --repo <worktree> -- <command> <args...>` only when
the developer explicitly asks for offline isolation or when executing newly
acquired, untrusted code that needs no real home, host credentials, network, or
normal repository writes. The optional Linux helper uses bubblewrap with a scrubbed
environment, empty home, private `/tmp`, denied network, finite timeout, and a
read-only `/workspace`. When generated output is unavoidable, repeat `--write`
for the smallest existing relative paths; symlinks, outside paths, and `.git`
are refused, and Git metadata remains read-only under a broad write mount.

Treat this as defense in depth, not a VM/container proof. Never make it a routine
gate or a prerequisite for profile readiness. Skip it for
implementation edits, Docker/daemon workloads, interactive tools, network
integration, tests requiring a real home, or commands whose toolchain cannot run
from `/usr`, `/nix/store`, or the mounted worktree. Run the doctor smoke before
relying on it. If it is unavailable or incompatible, use the trusted workstation
and report the reduced isolation without blocking the task. A sandbox pass is
still only test evidence; inspect the diff and map results to acceptance criteria.

## Diagram policy

Use Mermaid when the diagram is primarily documentation:

- GitHub renders it directly;
- reviewers can edit it without a local renderer;
- diffs stay small;
- it is ideal for flowcharts, sequences, state machines, and dependency maps.

Use D2 when the user asks for “pretty,” “polished,” “presentation-ready,” or visually structured architecture:

- commit the `.d2` source;
- render and verify an `.svg` or `.png` artifact;
- keep labels and boundaries semantically meaningful;
- do not replace the source with only a binary/rendered file.

For flagship architecture documentation, include both: Mermaid for the maintainable inline overview and D2 for the polished visual artifact.

## Privacy boundary

Local documents read by Hermes or Codex become remote-model input unless a local model is used. Before reading private assessments, customer data, confidential PDFs, or proprietary repositories, ensure the developer has explicitly accepted that boundary. Extract locally and minimize transmitted content when full-document ingestion is unnecessary.

Keep organization policy in private overlays. A public personal profile must be created blank and must not clone employer profiles, memories, sessions, skills, or worklogs.

## Common pitfalls

1. **Quizzing every turn.** It creates friction, not learning. Gate concepts, not keystrokes.
2. **Two workflow systems.** Keep GSD authoritative; mentor checkpoints live inside it.
3. **Hard-coded tmux index.** Panes move. Discover by command and exact repository/worktree; never fall back to an unrelated worker.
4. **Parallelism as theater.** Multiple implementation workers can hide the causal chain the developer needs to learn.
5. **Worker self-report as proof.** Audit disk and tests independently.
6. **Passive agreement as mastery.** Require explanation, application, or transfer evidence.
7. **Installing every skill into every prompt.** Install broadly; load narrowly.
8. **Pretty diagram without source.** Commit D2 source beside the rendered output.
9. **Remote document ingestion without consent.** Make the provider boundary explicit.
10. **Graph as a second plan.** Graphify aids navigation; only GSD owns lifecycle state.
11. **Stale graph certainty.** Refresh first, then verify graph results against source.
12. **Current docs without version reconciliation.** Context7 evidence must match the locked dependency.
13. **Hiding the interesting failure.** Use focused reruns and the exact local transcript; never trust a bounded preview alone.
14. **Turning optional isolation into workflow friction.** Use the trusted workstation by default; reserve the OS boundary for explicit offline or untrusted-code verification and state its limitations.

## Verification checklist

- [ ] GSD is the only lifecycle source of truth.
- [ ] Current learning mode is explicit.
- [ ] Each important unit has one concept and one bounded owner.
- [ ] Codex target was discovered, not hard-coded.
- [ ] Implementation prompt includes branch, allowlist, criteria, tests, and safety limits.
- [ ] Actual diff and tests were independently checked.
- [ ] Teach-back uses one meaningful question.
- [ ] Mastery state is backed by evidence.
- [ ] Mermaid/D2 choice matches the artifact's purpose.
- [ ] Graphify was used only for a meaningful cross-file trigger and its result was checked against source.
- [ ] Version-sensitive library claims use Context7 and reconcile with the locked version.
- [ ] Normal work used installed/configured workstation tools; optional sandboxing was reserved for an explicit high-risk trigger.
- [ ] Displayed command output is sanitized and bounded when oversized, with exact external evidence retained for safe local inspection.
- [ ] Private content and organization overlays remain isolated.
