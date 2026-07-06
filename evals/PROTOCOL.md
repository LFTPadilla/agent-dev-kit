# LLM-agent eval protocol

How to score the reasoning-based reviewers (`pr-review`, `security-checklist`)
on the `cases/` set. Manual, but repeatable and honest.

## Run

1. For each case file, give the agent only that file and ask it to review
   (or open a throwaway PR containing all cases and run `/pr-review <url>`).
2. Record, per case: did it report a finding? right category? right severity?
   Did it report anything on the clean controls?
3. Tally:
   - **Recall** = planted bugs caught / planted case count
   - **False positives** = findings on clean controls (target: 0)
   - **Severity accuracy** = correct severity / caught

## Results

Run 2026-06-18 covered the original 5-case smoke set. Re-run this table after
changes to the reviewers or eval set. ✓ = caught, ✗ = missed, — = correctly
silent on the control.

| Tool | 01 sql | 02 auth | 03 n+1 | 04 deps | 05 clean | Recall | FP |
|---|---|---|---|---|---|---|---|
| semgrep `p/owasp+js+ts+nodejs-scan` | ✗ | ✗ | ✗ | ✗ | — | **0/4** | 0 |
| LLM single-pass review (Claude, manual) | ✓ | ✓ | ✓ | ✓ | — | **4/4** | 0 |
| `/pr-review` (+ adversarial verify) | — | — | — | — | — | not run | — |

**Reading it honestly:**

- **semgrep 0/4 is real, and the reason is the lesson.** 547 rules loaded, 79 ran
  on the TS files, zero findings. The cases use a project-specific `db.query`
  sink — generic SAST taint rules key off *known library* sinks (pg, knex,
  sequelize), so they miss injection through a custom wrapper. This is a true,
  common limitation: deterministic SAST is brittle to bespoke abstractions and
  needs codebase-tuned rules (or `semgrep login` for more) to do better here.
- **LLM single-pass 4/4, 0 FP** — the reasoning layer reads intent, not just
  patterns, so the custom sink, the missing auth, the N+1, and the stale closure
  all register; the clean control stays clean.
- **Caveat:** these 4 bugs are classic and obvious — a smoke test of the method,
  not proof on hard cases. The `/pr-review` + adversarial-verify row needs a real
  PR run to fill; the value it adds shows on *ambiguous* findings, which this set
  doesn't yet contain. Add subtler cases (TOCTOU, cross-tenant leak) to stress it.

The headline isn't "LLM beats semgrep" — it's that they fail differently, so the
kit runs both: semgrep as a deterministic floor, the LLM layer for intent.

## Extending

Add cases under `cases/`, append a row to `cases.json`. Good additions: a
TOCTOU race, a cross-tenant data leak, a logically-correct-but-slow algorithm,
and more clean controls (controls should be ~30% of the set to keep FP honest).
