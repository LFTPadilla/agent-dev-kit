# classifier-policy schema, version 1.0

One file describes one routing policy. The file is declarative: it names task
classes, a route per class, and the thresholds a classifier uses. Nothing in the
file calls a model.

`scripts/check-classifier-policy.mjs` is the reference reader. It accepts YAML
or JSON and prints one line per check.

## Top level

| Key | Type | Required | Meaning |
|---|---|---|---|
| `version` | string | yes | Schema version. Use `"1.0"`. |
| `updated` | string | yes | Date of the last edit, `YYYY-MM-DD`. |
| `policy` | mapping | yes | Policy metadata and the global defaults. |
| `classes` | mapping | yes | One entry per task class. The key is the class name. |

Unknown keys fail the check. A typo in a key name is a silent routing defect
otherwise.

## `policy`

| Key | Type | Required | Meaning |
|---|---|---|---|
| `name` | string | yes | Policy name. Use the same string on every machine. |
| `mode` | `shadow` or `enforce` | yes | `shadow` records a suggestion only. `enforce` applies the route. |
| `default_route` | route | yes | The route to use when no class matches, or when the classifier fails. |
| `thresholds` | mapping | yes | Confidence bands. See below. |

### `policy.thresholds`

| Key | Type | Meaning |
|---|---|---|
| `delegate` | number, greater than 0, at most 1 | At or above this confidence, delegate to the route. |
| `review` | number, greater than 0, below `delegate` | At or above this confidence, hold the route for a review. Below it, escalate to the human. |

`review` must be below `delegate`. A review band that sits above the delegate
band would make the delegate band unreachable.

## `classes.<name>`

The class name matches `^[a-z][a-z0-9-]*$`. Keep the name short and stable: it
appears in logs.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `criteria` | string, 20 characters or more | yes | The text the classifier compares against. Write it as a test, not as a label. |
| `consequence` | `low`, `medium`, or `high` | yes | The cost of a wrong route. `high` also requires `fallback`. |
| `route` | route | yes | The harness, model tier, and effort for this class. |
| `fallback` | route | for `consequence: high` | The safe route when confidence is low. |
| `notes` | string | no | A short human note. The checker does not read it. |

## route

| Key | Type | Required | Meaning |
|---|---|---|---|
| `harness` | `claude`, `codex`, `pi`, `opencode`, `hermes`, or `any` | yes | The runtime that runs the task. |
| `model` | tier token | yes | A cost tier, not a vendor model name. Example: `cheap-tier`. |
| `effort` | `low`, `medium`, or `high` | yes | The reasoning effort the harness applies. |

### Why the model field holds a tier, not a model name

The policy stays portable when it names a tier. Each machine maps its own tiers
to real models in a local, uncommitted file. A vendor model name in the policy
would pin the policy to one account and one date.

A tier token matches `^[a-z0-9][a-z0-9._-]*$`. A value with a `/` is a vendor
model path and fails the check.

## Minimal valid policy

```yaml
version: "1.0"
updated: "2026-09-22"
policy:
  name: example-policy
  mode: shadow
  default_route:
    harness: any
    model: standard-tier
    effort: medium
  thresholds:
    delegate: 0.85
    review: 0.6
classes:
  mechanical-fix:
    criteria: A small, local change with a known shape and a passing test.
    consequence: low
    route:
      harness: any
      model: cheap-tier
      effort: low
```

## Check a policy

```bash
node scripts/check-classifier-policy.mjs policy.yml
node scripts/check-classifier-policy.mjs --json policy.yml
```

Exit code 0 is valid, 1 is invalid, 2 is unreadable. `--json` prints the failures
as a list for another tool to read.
