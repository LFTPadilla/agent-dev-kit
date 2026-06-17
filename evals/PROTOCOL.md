# LLM-agent eval protocol

How to score the reasoning-based reviewers (`pr-review`, `security-checklist`)
on the `cases/` set. Manual, but repeatable and honest.

## Run

1. For each case file, give the agent only that file and ask it to review
   (or open a throwaway PR containing all five and run `/pr-review <url>`).
2. Record, per case: did it report a finding? right category? right severity?
   Did it report anything on the clean control (05)?
3. Tally:
   - **Recall** = planted bugs caught / 4
   - **False positives** = findings on case 05 (target: 0)
   - **Severity accuracy** = correct severity / caught

## Results (fill in when run)

| Tool | 01 sql | 02 auth | 03 n+1 | 04 deps | 05 clean | Recall | FP |
|---|---|---|---|---|---|---|---|
| semgrep (`run.mjs`) | | | | | | | |
| `security-checklist` | | | | | | | |
| `/pr-review` (single pass) | | | | | | | |
| `/pr-review` (+ adversarial verify) | | | | | | | |

The interesting comparison is the last two rows: the adversarial verify layer
should hold recall while driving false positives toward zero. That is the whole
thesis of `pr-review` — measure it, don't assert it.

## Extending

Add cases under `cases/`, append a row to `cases.json`. Good additions: a
TOCTOU race, a cross-tenant data leak, a logically-correct-but-slow algorithm,
and more clean controls (controls should be ~30% of the set to keep FP honest).
