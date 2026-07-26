# Pi Package Pilot Plan

Goal: decide whether one exact Pi package can add advisory value without
creating a second lifecycle, context, memory, or orchestration authority.

## Gate 0: architecture fit

Reject before installation when the package:

- owns planning, execution, verification, tasks, goals, or workflow state that
  belongs to GSD;
- becomes a context/memory authority alongside Hermes;
- recursively delegates or gives workers shared write access;
- duplicates Graphify or Context7 without a measured gap;
- requires private source upload, implicit telemetry, or credentials for the
  proposed use;
- cannot be constrained to evidence that the primary agent independently checks.

## Gate 1: exact artifact audit

For one version only, record:

- Pi catalog page, npm metadata, source repository, exact tag/commit, publication
  timestamp, integrity digest, license, and maintainer/activity signals;
- direct, optional, peer, native, and install-time dependencies;
- install/postinstall behavior and every filesystem, subprocess, network,
  telemetry, retention, deletion, and prompt/context hook;
- declared and effective tool permissions, fail-open paths, and behavior when
  the package is disabled or fails;
- differences between the published artifact and the source tag.

Reading a README or package description is not an audit. Do not run install
scripts during this gate.

## Gate 2: disposable offline fixture

Only after Gate 1 passes:

1. Use a throwaway OS account/container and disposable fixture repository.
2. Deny network by default and provide no credentials or real home directory.
3. Pin the exact package version; never use `latest`.
4. Load only the reviewed resource paths; start with no write tools.
5. Capture filesystem, process, and attempted-network effects.
6. Confirm uninstall/deletion removes all package-owned state.

Pass criteria:

- no access outside the fixture and dedicated cache;
- no unexpected process, network, install-hook, or configuration mutation;
- no context/lifecycle override;
- deterministic, evidence-linked output;
- clean failure and timeout behavior.

## Gate 3: measured advisory evaluation

Run clean controls and planted cases. Compare against the existing stack, not
against doing nothing:

- GSD + Hermes baseline;
- Graphify for cross-file code relationships;
- Context7 for current public library documentation;
- existing deterministic tests, Semgrep, and `/pr-review`.

Measure true findings, false positives, task time, tokens/context, retained data,
and operator effort. A package must demonstrate unique value rather than a new
way to perform an existing capability.

## Gate 4: explicit opt-in proposal

A successful fixture evaluation still does not enable the package. Any proposal
must include:

- exact pin and source evidence;
- one bounded profile and one output contract;
- actual OS containment and least-privilege tool set;
- network destinations and data classification;
- retention/deletion and rollback instructions;
- tests proving default absence, no recursive delegation, no lifecycle
  authority, and independent verification.

The default remains no package. There is no approved Pi pilot as of the
2026-07-23 audits: `context-mode@1.0.169`, `pi-distill@1.1.0`,
`pi-sandbox@0.6.0`, and `@gotgenes/pi-permission-system@20.10.0` were not
approved for activation. The sandbox audit produced a smaller local,
bubblewrap-only offline verification pattern; that is not a Pi package pilot.
