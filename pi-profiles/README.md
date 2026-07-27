# Pi Package Research Profiles

This directory combines opt-in Pi profile examples with a policy surface for
evaluating Pi packages. Agent-dev-kit does not automatically enable a
third-party package from these files. Pi packages execute with the user's permissions; the
[upstream package documentation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md#install-and-manage)
requires source review before installation.

## Files

| File | Purpose |
| --- | --- |
| `profiles.yaml` | Advisory delegation contracts and profile-scoped activation policy. |
| `package-matrix.md` | Point-in-time candidate decisions and reviewed versions. |
| `context-mode-audit.md` | Source audit of `context-mode@1.0.169`. |
| `remaining-candidates-audit.md` | Exact audits of sandbox, distill, and permission candidates plus top-queue decisions. |
| `pilot-plan.md` | Gates a future one-package, disposable-workspace pilot. |
| `settings.example.json` | Pinned, usable `pi-code-review` and `pi-sre-research` examples. |

`profiles.yaml` is agent-dev-kit metadata, **not** a `.pi/settings.json` schema.
The Pi-shaped `settings.example.json` retains the established review and
research profiles. Copying either profile into active Pi settings is an
explicit opt-in to its pinned extensions; the repository never performs that
activation.

## Authority and safety

- GSD remains the only lifecycle authority.
- Hermes remains the context owner, tutor, and orchestrator.
- Codex remains a bounded implementation/review worker.
- Pi and any Pi package in these examples may return advisory evidence only.
- Do not install or enable a package until the exact version and published
  artifact have passed source, license, dependency, install-hook, data-flow,
  network, filesystem, process, and prompt-mutation review.
- A `--tools` list or a written `sandbox_policy` is not an OS sandbox for
  extension code. Use a disposable workspace and an actual containment boundary.
- Never pass secrets, private source, customer data, production credentials, or
  authenticated browser state to a package pilot.

## Current result

The examples are preserved for compatibility, not endorsed as part of the
default Hermes/Codex stack. `context-mode@1.0.169` remains
**do-not-pilot** for this architecture: its useful output reduction comes
with persistent session capture, context injection, arbitrary subprocesses with
network access, install-time mutation, and substantial overlap with Hermes,
Graphify, and Context7. See [the audit](context-mode-audit.md).

Exact follow-up audits also rejected `pi-distill@1.1.0` for context/model/data
overlap, kept `@gotgenes/pi-permission-system@20.10.0` as non-boundary research,
and declined to enable `pi-sandbox@0.6.0`. The last audit did justify a smaller
local offline `bwrap` verification helper with no Pi activation. See
[the remaining candidate audits](remaining-candidates-audit.md).

A future package addition must pin one exact version and follow
[`pilot-plan.md`](pilot-plan.md). Do not use an unpinned `pi -e npm:<name>` or
bundle multiple packages into one trial.
