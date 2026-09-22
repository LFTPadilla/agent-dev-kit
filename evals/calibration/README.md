# Calibration bench: which cheap model still gets the case right?

[`../PROTOCOL.md`](../PROTOCOL.md) answers "how good is a reviewer?".
This bench answers a different question:

> For each class of task, which is the cheapest model that still passes the case?

That answer is the input to a routing policy. Without it, a cheap model enters a
critical path on price alone. The bench produces a **class to model** table from
your own runs, not from a vendor claim.

## What this bench does not do

1. **It never calls a model.** No API key, no network, no token spend.
2. **It never invents a result.** It reads run files that a harness wrote.
3. **It is not a routing policy.** It measures. You decide what to route.

A harness (any harness: a script, an agent, a manual review) runs the cases and
writes a run file. The bench joins the run files with the taxonomy and writes the
report.

## Task classes (`taxonomy.json`)

Every case in [`../cases.json`](../cases.json) carries exactly one class label.
`npm run validate` fails when a new case has no label.

| Class | What the reviewer must do | Cases |
|---|---|---|
| `pattern-scan` | Read one function, apply a well-known pattern | 01, 03, 10, 12 |
| `taint-trace` | Follow untrusted input to a sink across a boundary | 06, 07, 13 |
| `semantic-intent` | Infer what the code should enforce (auth, tenant, rate) | 02, 08, 14 |
| `state-reasoning` | Model ordering, lifecycle, or concurrency | 04, 09 |
| `fp-discipline` | Stay silent on a clean control | 05, 11, 15 |

Each label also carries a `difficulty` and a one-line `why`. The `why` states
where the reasoning load sits, so the label is reviewable.

Class sizes are small on purpose. 15 cases is a smoke test. A single miss is a
signal, not a verdict. See [Honest limits](#honest-limits).

## Run the bench

```bash
node evals/calibration/run.mjs                          # read runs/*.json
node evals/calibration/run.mjs --runs my-run.json       # read one run file
node evals/calibration/run.mjs --runs-dir /tmp/runs     # read another folder
node evals/calibration/run.mjs --min-pass 0.9           # relax the pass bar
node evals/calibration/run.mjs --stdout                 # print the report only
node evals/calibration/run.mjs --template               # print an empty run file
```

Output: `evals/calibration/report.json` and `evals/calibration/report.md`.
Change the target with `--out-dir`.

The **pass bar** is strict by default: a model must pass **every** case of a
class to become its recommendation. Lower `--min-pass` to trade recall for cost,
and say so when you quote the result. A model that never attempts the whole class
is never ranked on cost.

## Run file format (`adk-eval-run/1`)

A run file is one harness run of the 15 cases against one or more models. Copy
the skeleton from `--template`, fill it, and drop it in `runs/`.

```json
{
  "format": "adk-eval-run/1",
  "label": "pr-review-sonnet-2026-09",
  "synthetic": false,
  "source": "agent-dev-kit /pr-review lenses, one file per call",
  "created": "2026-09-22",
  "models": [
    { "id": "vendor/model-small", "price_in_per_mtok": 0.2, "price_out_per_mtok": 0.8 }
  ],
  "results": [
    { "model": "vendor/model-small", "case": "01-sql-injection.ts", "finding": true,
      "tokens_in": 900, "tokens_out": 200, "cost_usd": 0.00034,
      "notes": "reported the interpolated query" }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `format` | yes | Must be `adk-eval-run/1`. The bench refuses any other value. |
| `label` | yes | Short name for this run. It appears in the report. |
| `synthetic` | no | `true` marks made-up data. The report then carries a banner. |
| `source` | no | What produced the run. Say the harness and the method. |
| `created` | no | ISO date. |
| `models[].id` | yes | Model identifier. Use the same string in `results[].model`. |
| `models[].price_in_per_mtok` | no | USD per million input tokens. |
| `models[].price_out_per_mtok` | no | USD per million output tokens. |
| `results[].model` | yes | Must match a declared model id. |
| `results[].case` | yes | File name from `cases.json`. |
| `results[].finding` | yes | `true` if the model reported a finding on this file. |
| `results[].tokens_in` | no | Input tokens for this case. |
| `results[].tokens_out` | no | Output tokens for this case. |
| `results[].cost_usd` | no | Cost for this case. It wins over the token estimate. |
| `results[].notes` | no | Free text. Use it to record what the model said. |

### Scoring rule

One rule, and it is the rule of the case set:

1. A **planted bug** passes when `finding` is `true`.
2. A **clean control** passes when `finding` is `false`.

A model that flags everything fails every control. A model that flags nothing
fails every planted case. Recall and false positives both count.

### Cost rule

Cost per case comes from `cost_usd` when present. Otherwise the bench estimates
it from `tokens_in`, `tokens_out`, and the model prices. When neither exists, the
model is **unpriced**: the bench still reports a passing model, but it marks the
confidence `cost-unknown` and does not claim it is the cheapest.

### Validation

The bench rejects a run file and exits with status 2 when:

1. `format` is not `adk-eval-run/1`.
2. `label`, `models`, or `results` is missing or empty.
3. A result names a model that `models` does not declare.
4. A result names a case that `cases.json` does not have.
5. Two results cover the same model and case.
6. A `finding` is not `true` or `false` (an unfilled template).

## Report

`report.md` holds the recommendation table, the pass-rate matrix, and the
warnings. `report.json` holds the same data for a script.

```text
| Task class      | Cases | Cheapest passing model | Mean cost per case (USD) | Confidence |
| pattern-scan    | 4     | example/cheap-model    | 0.000057                 | priced     |
| taint-trace     | 3     | example/frontier-model | 0.007380                 | priced     |
```

`confidence` values:

1. `priced`: a model passed every case of the class, and the run recorded cost.
   The pick is the cheapest such model.
2. `cost-unknown`: a model passed every case, but no run recorded cost. The pick
   is the first passing model in name order, not the cheapest.
3. `partial`: no model attempted the whole class. The pick passed what it
   attempted. The report claims no cost ranking. Treat the class as unmeasured.
4. `none`: no model passed the class. **Do not route this class by cost.**

Cost is ranked per class, from the cases of that class only. A model that is
cheap on `pattern-scan` is not assumed cheap on `state-reasoning`.

## Synthetic data

`runs/example-synthetic.json` is a hand-written fixture. No model was called. It
exists to prove the bench works, and every report built from it carries a
`SYNTHETIC DATA` banner.

**Replace it before you quote any number.** Delete the file, or keep it in a
separate folder and pass `--runs-dir` for the real runs.

## Honest limits

1. **15 cases, 5 classes.** The smallest class holds 2 cases. One miss moves a
   class by 50%. Scale the case set before you trust a class table.
2. **The bench measures the harness, not only the model.** A run inherits the
   prompt, the number of passes, and the review lens of whatever produced it.
   Two runs are comparable only when their `source` fields match.
3. **Cost is per case, not per shipped change.** It excludes retries, human
   review, and the cost of a wrong answer. A cheap miss costs more than an
   expensive pass.
4. **A class label is a judgement.** The labels in `taxonomy.json` are reasoned,
   not measured. Argue with them and change them; `validate` keeps them complete.

## Contract test

```bash
npm run test:evals-calibration
```

It checks the taxonomy coverage, the empty report, the synthetic fixture picks,
the pass bar, the cost fallback, every rejection path, and the `validate` gate.
