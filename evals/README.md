# Evals — do the review tools actually catch bugs?

A reviewer you can't measure is a vibe. This is a small, honest benchmark: a set
of code samples with **known planted bugs** plus a **clean control**, so every
review tool in this kit can be scored on two axes that actually matter:

- **Recall** — of the planted bugs, how many did it catch?
- **False-positive rate** — did it flag the clean control? (the failure mode
  that makes LLM reviewers untrustworthy)

## The set (`cases/`)

| Case | Planted issue | Category | A deterministic SAST should… |
|---|---|---|---|
| 01 | String-interpolated SQL | security/CRITICAL | catch |
| 02 | No auth on a delete route | security/CRITICAL | often miss (needs intent) |
| 03 | N+1 query in a loop | performance/HIGH | often miss |
| 04 | `useEffect` missing dep | correctness/MEDIUM | miss (semantic) |
| 05 | **clean control** | — | **never flag** |

The mix is deliberate: 01 is easy for static rules; 02–04 need reasoning; 05
exists only to catch over-eager reviewers. A tool that scores 100% recall by
flagging everything also flags 05 — and fails.

## Two layers, two methods

**Deterministic (automated):**
```bash
pipx install semgrep
node evals/run.mjs
```
Scores semgrep against the set. Expect it to nail 01, miss the semantic ones —
that gap is the point: it shows exactly what the LLM layer has to add.

**LLM agents (manual, rigorous):** the `pr-review` and `security-checklist`
skills are scored by [`PROTOCOL.md`](PROTOCOL.md) — run them on the same cases,
record findings, compute recall + false positives. Results go in a table there.

## Why this matters

Most "I use AI to review code" claims are unmeasured. This says: here is the
benchmark, here is the method, here are the numbers — including where the tools
miss. That's the difference between using a reviewer and engineering one.

> Honesty note: 5 cases is a smoke test, not a statistically powerful eval. It
> demonstrates the *method*; scale the set before drawing strong conclusions.
