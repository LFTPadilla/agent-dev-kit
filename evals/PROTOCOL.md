# LLM-agent eval protocol

How to score the reasoning-based reviewers (`pr-review`, `security-checklist`)
on the `cases/` set. Manual, but repeatable and honest.

## The set

The current eval set is **15 cases** (see `cases.json`):

- **12 planted bugs** (01–04, 06–10, 12–14)
- **3 clean controls** (05, 11, 15) — flagging any of these is a false positive

Controls are ~20% of the set. Prefer ~30% when adding more cases so FP
scoring stays honest.

## Run

1. For each case file, give the agent only that file and ask it to review
   (or open a throwaway PR containing all cases and run `/pr-review <url>`).
2. Record, per case: did it report a finding? right category? right severity?
   Did it report anything on the clean controls?
3. Tally:
   - **Recall** = planted bugs caught / planted case count (target denom: **12**)
   - **False positives** = findings on clean controls (target: **0** of 3)
   - **Severity accuracy** = correct severity / caught

### Full `/pr-review` against a GitHub PR

Requires an agent runtime that can run the Workflow in
`plugins/dev-skills/commands/pr-review.md` (multi-lens + adversarial verify)
with `gh` auth against a real PR. Non-interactive CI cannot invoke that
Workflow today.

Reproducible path:

```bash
# 1) Push evals/cases as a throwaway branch / draft PR in a fork
# 2) In Claude Code (or equivalent) with the plugin loaded:
 /pr-review https://github.com/<owner>/<repo>/pull/<n>
# 3) Score each planted file vs control; update the table below
```

Until that full live-PR Workflow exists, publish only labeled protocol runs
(below): Cursor/agent applying the same lenses + adversarial verify per file.

## Results

### Historical smoke (cases 01–05) — 2026-06-18

Original 5-case smoke. Expanded cases 06–15 were not in this table.

✓ = caught, ✗ = missed, — = correctly silent on the control.

| Tool | 01 sql | 02 auth | 03 n+1 | 04 deps | 05 clean | Recall | FP |
|---|---|---|---|---|---|---|---|
| semgrep `p/owasp+js+ts+nodejs-scan` | ✗ | ✗ | ✗ | ✗ | — | **0/4** | 0 |
| LLM single-pass review (Claude, manual) | ✓ | ✓ | ✓ | ✓ | — | **4/4** | 0 |

### `/pr-review` protocol smoke (cases 01–05) — 2026-07-20

**Label: smoke, not full suite.** Method: Cursor agent applied the `/pr-review`
lenses (correctness, security, performance, quality + ponytail advisory) and the
adversarial-verify gate from `plugins/dev-skills/commands/pr-review.md` to each
file in isolation. **Not** a live GitHub Workflow against a PR (blocked without
an interactive agent + `gh` PR). Do not treat as full 15-case recall.

| Tool | 01 sql | 02 auth | 03 n+1 | 04 deps | 05 clean | Recall | FP |
|---|---|---|---|---|---|---|---|
| `/pr-review` protocol smoke (lenses + adversarial verify, per-file) | ✓ | ✓ | ✓ | ✓ | — | **4/4** | 0 |

Findings that survived adversarial verify (summary):

| Case | Surviving finding | Severity after verify |
|---|---|---|
| 01 | string-interpolated SQL via `req.query.id` into `db.query` | BLOCKER |
| 02 | `deleteAccount` mutates without auth/ownership check | BLOCKER |
| 03 | query-per-iteration N+1 in `withPosts` | HIGH |
| 04 | `useEffect` missing `userId` dep → stale fetch | MEDIUM |
| 05 | none (control) | — |

### `/pr-review` protocol batch (cases 06–15) — 2026-07-20

**Label: fuller protocol batch, still not a live PR Workflow.** Same method as
the 01–05 smoke: per-file lenses + adversarial verify (pre-report gate; majority
refute; default-to-refuted). Ponytail advisory ignored for scoring.

| Tool | 06 ssrf | 07 path | 08 tenant | 09 race | 10 cors | 11 clean | 12 secret | 13 inject | 14 rate | 15 clean | Recall | FP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `/pr-review` protocol batch (lenses + adversarial verify, per-file) | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | **8/8** | 0 |

Findings that survived adversarial verify (summary):

| Case | Surviving finding | Severity after verify |
|---|---|---|
| 06 | `fetch(req.body.url)` with no allowlist / private-IP block (SSRF) | HIGH |
| 07 | `path.join(base, filename)` then `readFile` — untrusted `filename` escapes base | HIGH |
| 08 | `findUnique({ id })` returns invoice; `user.tenantId` unused (cross-tenant IDOR) | BLOCKER |
| 09 | `countActive` then `createSession` without transaction/lock (TOCTOU) | HIGH |
| 10 | reflects `Origin` with `Access-Control-Allow-Credentials: true` | MEDIUM |
| 11 | none (control — correct `useEffect` deps + cancel flag) | — |
| 12 | logs `authorization` header via `logger.info` | HIGH |
| 13 | untrusted page text containing `RUN_DIAGNOSTIC` drives `tool.run(...)` | HIGH |
| 14 | unauthenticated `ai.complete(req.body.prompt)` with no rate limit | MEDIUM |
| 15 | none (control — org match + owner/admin role check) | — |

### Combined `/pr-review` protocol (cases 01–15) — 2026-07-20

Sum of the smoke (01–05) and batch (06–15) above. Same method; still **not** a
live `/pr-review <PR-URL>` Workflow.

| Tool | Planted caught | Recall | Clean FP | FP rate |
|---|---|---|---|---|
| `/pr-review` protocol (per-file lenses + adversarial verify) | 12 / 12 | **12/12** | 0 / 3 | **0** |

**Still not scored:** a live `/pr-review <PR-URL>` Workflow against a real GitHub
PR (multi-file diff, `gh` scout, full Workflow pipeline). That row stays empty
until measured.

**Reading it honestly:**

- **semgrep 0/4 is real** on the classic five. Custom `db.query` sink misses
  generic taint rules.
- **LLM single-pass and `/pr-review` protocol** both caught all planted cases
  scored so far, with **0 FP** on all three controls (05, 11, 15).
- **Caveat:** these are per-file protocol runs, not the interactive GitHub
  Workflow. Severity labels track `cases.json` intent (CRITICAL → BLOCKER in
  the `/pr-review` enum). Cases 06–14 are clearer than some production bugs;
  scale the set before strong claims.

The headline isn't "LLM beats semgrep" — it's that they fail differently, so the
kit runs both: semgrep as a deterministic floor, the LLM layer for intent.

## Extending

Add cases under `cases/`, append a row to `cases.json`. Good additions: more
clean controls (aim ~30% of the set), subtler correctness bugs, and anything
that stresses adversarial verify on ambiguous findings.
