---
name: classifier-policy
description: Write, check, or apply a declarative task-class routing policy that maps a task class to a harness, a model tier, and a reasoning effort. Use when a team routes work by hand, when a routing decision must be reproducible on another machine, or when the user asks which model should run a task class.
license: MIT
---

# classifier-policy

A routing decision is a policy, not a preference. This skill keeps the policy in
one versioned file so every machine reads the same rules.

The file is declarative. It does not call a model and it does not need an API
key. A classifier may fill the class field later. The policy stays the source of
truth.

## Hard rules

1. **The policy holds no vendor model names.** A route names a cost tier, for
   example `cheap-tier`. Each machine maps its tiers to real models in a local
   file. A vendor name in the policy pins the policy to one account and one
   date.
2. **Start in `shadow` mode.** Shadow mode records the suggested route and
   changes nothing. Move a class to `enforce` only after the recorded
   suggestions agree with the human choice.
3. **Keep a deterministic default.** `policy.default_route` must route work when
   the classifier fails, times out, or returns low confidence. A routing layer
   must never block a task.
4. **Set `fallback` on every high-consequence class.** A wrong route on a
   security or payment change costs more than a slow route.
5. **Do not put secrets, client names, hostnames, or ticket IDs in the policy.**
   The policy ships in a public tree.

## The policy file

One file, YAML or JSON, at the repository root or in a config directory. The
schema is in [references/policy-schema.md](references/policy-schema.md). Read it
before you write a policy.

Four parts:

1. `version` and `updated` identify the schema and the last edit.
2. `policy` holds the name, the mode, the default route, and the confidence
   thresholds.
3. `classes` holds one entry per task class. The key is the class name.
4. Each class holds `criteria`, `consequence`, `route`, and an optional
   `fallback`.

Two examples ship with this skill:

1. [examples/policy.basic.yml](examples/policy.basic.yml) is the smallest useful
   policy. It has two classes.
2. [examples/policy.json](examples/policy.json) is the same policy in JSON.

## How to write a policy

1. List the task classes your team already names out loud. Five to eight classes
   is enough. More classes than that are hard to keep distinct.
2. Write `criteria` as a test, not as a label. "A small, local change with a
   known shape and an existing test" beats "simple task".
3. Set `consequence` from the cost of a wrong route, not from the size of the
   task. A one-line change to an auth check is high consequence.
4. Set the route per class: harness, model tier, effort.
5. Set `fallback` for each high-consequence class.
6. Set `mode: shadow` and `thresholds`. Use `delegate: 0.85` and `review: 0.6`
   as the first values.
7. Check the file. Fix every failure before you commit.

## How to check a policy

```bash
node scripts/check-classifier-policy.mjs examples/policy.basic.yml
node scripts/check-classifier-policy.mjs --json examples/policy.json
```

Exit code 0 means the policy is valid. Exit code 1 means a rule failed. Exit code
2 means the file could not be read or parsed. The checker needs the `yaml`
package for a YAML file. Run `npm ci` in the kit root once.

The checker reads the policy. It never routes a task and never calls a remote
service.

## How to read a decision at run time

The classifier returns a class and a confidence. The policy turns that pair into
an action:

| Confidence | Mode `shadow` | Mode `enforce` |
|---|---|---|
| At or above `thresholds.delegate` | Log the route. Run the current route. | Run the route. |
| At or above `thresholds.review` | Log the route and the disagreement. Run the current route. | Run the route after a review. |
| Below `thresholds.review` | Log the escalation. Run the current route. | Run `default_route` and ask the human. |
| Classifier failed | Log the failure. Run the current route. | Run `default_route`. |

Log every decision as one JSON line: the class, the confidence, the chosen
route, the applied route, and the mode. The log is the evidence for moving a
class from `shadow` to `enforce`.

## Promote a class from shadow to enforce

1. Collect the logged decisions for the class. Use at least twenty decisions.
2. Compare the suggested route against the route a human chose. Count the
   disagreements.
3. If the disagreements are below one in ten, set `mode: enforce`.
4. Keep the class in `shadow` when the disagreements are at or above one in ten,
   or when the class has `consequence: high`.

Change one class at a time. A single `enforce` flip is easy to revert.

## Install on another machine

The policy is a file, so a copy is enough. Two steps keep it reproducible:

1. Clone the kit and run `./bootstrap.sh`. The bootstrap links every shipped
   skill, including this one, into each detected runtime.
2. Copy your policy file into the new machine, or keep it in a repository you
   already clone. Then map your tiers to real models in a local, uncommitted
   file.

`REGISTRY.yaml` records this skill under `subsystems` and `skills`, so
`npm run inventory` and `npm run validate` see it on any machine.

## What this skill does not do

1. It does not call a classifier. The classifier is a separate, optional
   dependency.
2. It does not replace `orchestrate` or the Agent Tutor Orchestrator. It states
   which harness and model a class of work uses. The orchestrator still decides
   how to decompose the work.
3. It does not enforce a route by itself. A harness reads the policy and applies
   it.
