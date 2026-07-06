# Evals — do the review tools actually catch bugs?

A reviewer you can't measure is a vibe. This is a small, honest benchmark: a set
of code samples with **known planted bugs** plus **clean controls**, so every
review tool in this kit can be scored on two axes that actually matter:

- **Recall** — of the planted bugs, how many did it catch?
- **False-positive rate** — did it flag the clean controls? (the failure mode
  that makes LLM reviewers untrustworthy)

## The set (`cases/`)

| Case | Planted issue | Category | Notes |
|---|---|---|---|
| 01 | String-interpolated SQL (custom `db.query` sink) | security/CRITICAL | generic SAST misses it — sink isn't a known library |
| 02 | No auth on a delete route | security/CRITICAL | needs intent — SAST misses |
| 03 | N+1 query in a loop | performance/HIGH | SAST misses |
| 04 | `useEffect` missing dep | correctness/MEDIUM | semantic — SAST misses |
| 05 | **clean control** | — | **never flag** |
| 06 | SSRF via arbitrary `fetch` URL | security/HIGH | user-controlled outbound request |
| 07 | Path traversal | security/HIGH | untrusted filename joined into server path |
| 08 | Missing tenant filter | security/CRITICAL | semantic authorization boundary |
| 09 | Check-then-write race | correctness/HIGH | needs transaction/constraint |
| 10 | Overbroad credentialed CORS | security/MEDIUM | reflects arbitrary origin |
| 11 | **clean React control** | — | dependency handling is correct |
| 12 | Secret logging | security/HIGH | sensitive header logged |
| 13 | Prompt-injection-to-tool | AI safety/HIGH | untrusted page text drives privileged tool |
| 14 | Missing rate limit | abuse/MEDIUM | unauthenticated expensive endpoint |
| 15 | **clean permission control** | — | org + role checks are correct |

The mix is deliberate: 02–04 need reasoning, and 01 shows that even a "classic"
vuln slips past generic rules when the sink is a project-specific wrapper. 05
exists only to catch over-eager reviewers — a tool that scores 100% recall by
flagging everything also flags 05 and fails.

**Latest run (see [PROTOCOL.md](PROTOCOL.md) for the table + honest reading):**
semgrep `0/4`, LLM single-pass `4/4`, both `0` false positives. They fail
differently — which is exactly why the kit runs both.

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

> Honesty note: 15 cases is still a smoke test, not a statistically powerful eval. It
> demonstrates the *method*; scale the set before drawing strong conclusions.
