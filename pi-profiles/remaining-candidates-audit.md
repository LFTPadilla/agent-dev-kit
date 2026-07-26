# Remaining Pi Capability Audits — 2026-07-23

This document records the batch-3 exact-artifact audits and the disposition of
the highest-ranked remaining candidates. It is not installation guidance. No Pi
package below is enabled by agent-dev-kit or Personal Dev Tutor.

Architecture gate: GSD owns lifecycle state; Hermes owns context, teaching,
routing, and independent verification; Codex is one bounded implementation lane;
Graphify supplies local AST navigation; Context7 supplies current public library
documentation. A Pi package must add unique advisory value without becoming a
second authority.

## Decision summary

| Exact package | Decision | Reason |
| --- | --- | --- |
| `pi-sandbox@0.6.0` + `@carderne/sandbox-runtime@0.0.68` | **Do not enable; adopt a smaller workflow pattern** | Strong OS primitives, but the Pi integration's shipped policy is too permissive for the default profile and its enforcement is incomplete for arbitrary custom tools. |
| `pi-distill@1.1.0` + `pi-extensions-tool-display@1.0.0` | **Reject for this stack** | It changes tool schemas and system context, calls a model with original prompt/tool output, reads result-detail paths, writes group-readable state, and expands into a large Pi/model dependency graph. `personal-tutor-output` provides narrower deterministic value. |
| `@gotgenes/pi-permission-system@20.10.0` | **Do not install; defense-in-depth research only** | The implementation has good fail-closed and path controls, but command-name policy cannot cover interpreter, script, package-manager, function, alias, and wrapper indirection. It is not an OS boundary. |

The implemented addition is `scripts/personal-tutor-sandbox.sh`: a dependency-free
repository script over the separately installed Linux `bwrap` binary. It uses an
empty home, scrubbed environment, private `/tmp`, denied network, read-only
worktree by default, explicit existing relative write paths, read-only Git
metadata, closed inherited descriptors, and a timeout. It contains no copied
third-party source and does not load Pi.

## `pi-sandbox@0.6.0`

Primary sources:

- package: <https://pi.dev/packages/pi-sandbox>
- source: <https://github.com/carderne/pi-sandbox>, tag `v0.6.0`, commit
  `c5335b6cc0cccdac3ea98f3467a30f6d26d7182b`
- runtime source: <https://github.com/carderne/sandbox-runtime>, commit/tag
  `3d86f94b878884c27ab295d53344a40c6836136b` / `v0.0.68`
- package licenses: MIT (`pi-sandbox`) and Apache-2.0 (`sandbox-runtime`)
- npm tarball SHA-256:
  `b1a1ae5382dc9cff2a8fbb9a4f4ee231d619cf0120380f6de0fb41a31a2c96af`
- runtime tarball SHA-256:
  `1970c062ef755aab4b02a8ecc0b20984b5383056086e3b97ad08052fc36e37af`

Both artifacts have npm registry signatures and SLSA provenance attestations.
The 19 published `pi-sandbox` files matched the tag. The runtime publishes
compiled JavaScript, source maps without embedded source, seccomp binaries for
Linux, and Windows executables. Neither top-level package declares an install
script. Runtime production dependencies are `@pondwader/socks5-server`,
`commander`, `node-forge`, and `zod`; the reviewed production graph reported no
known npm audit vulnerability.

The runtime is substantive: Bubblewrap plus namespaces/seccomp on Linux,
Seatbelt on macOS, a Windows helper, filesystem policy, HTTP/SOCKS filtering,
credential masking, and tests for symlinks and platform-specific escape classes.
The projects were highly active at the snapshot (69/608 commits in the local
clones and recent releases on 2026-07-22).

The default Pi policy nevertheless enables browser processes, local binding,
unauthenticated SOCKS, all Unix sockets, and a broad domain list including package
registries, source hosts, search, and model destinations. Interactive approvals
can persist policy changes. The extension wraps Pi's built-in bash/read/write/edit
surfaces; it cannot prove mediation of every third-party custom tool or already
open host resource. The runtime also has deliberately weaker configuration modes
and substantial proxy/credential/native-binary complexity. A sandbox boundary
must not depend on users noticing that a permissive example became active.

**Decision:** do not install or enable the Pi package in the default profile.
Extract only the narrow offline-verification pattern. The local helper denies
network instead of filtering domains, mounts no real home, forwards no
credentials, has no interactive approval persistence, and defaults the entire
worktree to read-only. This is still documented as defense in depth rather than
a VM or container assurance.

Durable evidence:

`~/.cache/personal-dev-tutor/overnight-2026-07-22/audits/pi-sandbox-0.6.0/`

## `pi-distill@1.1.0`

Primary sources:

- package: <https://pi.dev/packages/pi-distill>
- source: <https://github.com/maplezzk/pi-extensions>, tag
  `pi-distill-v1.1.0`, commit
  `1d75c04fb3c24acadfdec82718afdbe3aa106858`
- dependency tag `pi-extensions-tool-display-v1.0.0`, commit
  `d171088e7fb901848e2334659c3334fdfe94a94c`
- MIT license; published 2026-07-23; repository created 2026-07-19 and very active,
  but operational history was only four days at audit time
- tarball SHA-256:
  `3ddff182f6ab0d56f7478ddf2ab4fa93097b3e93b2a37cb3721b7970dfd1c937`
- display dependency SHA-256:
  `337d9c79c7f7ff3721be59bdbd50f3c7d9d237bef713dbd6eaf4819a3357a29a`

Both artifacts had registry signatures, SLSA provenance, and byte-matched their
source tags. No package-level install script exists. However, a disposable exact
install resolved 268 production package entries, 38 optional entries, and six
packages marked with install scripts in the complete Pi/model peer graph.
Signature verification reported 232 verified packages and 45 attestations.

The offline disposable harness showed that the extension registers six session/
tool lifecycle hooks, mutates extensible tool schemas to require `outputRequest`,
and appends an output contract to the system prompt. Its display dependency
intercepts registration for seven built-in tools and adds message/context hooks.
A requested summary sends both original user prompt and tool output to the
selected model. It can read a file path supplied in tool-result details and put
that content in the model prompt. Oversized summaries and config were written
mode `0664` in the fixture. On model failure it returned the original output but
hid the failure from agent-visible content. The fixture observed no Internet
socket syscall under denied networking; network use arises through the selected
model/provider rather than a dedicated telemetry endpoint.

A 9,189-character fixture compressed to 36 characters, but the existing
`personal-tutor-output` control keeps exact mode-0600 evidence, performs no model
call, changes no tool schema or prompt, and bounds noisy success. Failure and
security evidence displays in full through 32 KiB and is bounded above that
threshold while the exact transcript remains retained. Distill's incremental
value does not justify
its context authority, provider disclosure, retention, permissions, and
dependency surface.

**Decision:** reject for Personal Dev Tutor and do not extract another pattern;
batch 2 already implemented the narrower deterministic one.

Disposable evidence remains at `/tmp/pi-distill-audit/` for this run.

## `@gotgenes/pi-permission-system@20.10.0`

Primary sources:

- package: <https://pi.dev/packages/@gotgenes/pi-permission-system>
- source: <https://github.com/gotgenes/pi-packages>, tag
  `pi-permission-system-v20.10.0`, commit
  `1a904d234b769f51f4872b8e2b692a371cb02d69`
- MIT license; published 2026-07-21; 575 package-path commits in the preceding
  month in the local source query
- tarball SHA-256:
  `298d899f22028e66a5ccd1e4c53ca50e200ad9629b38db460ed9cc7a89e58f47`

The npm artifact has registry signature and SLSA provenance. Published source
matched the tagged source tree; excluded tests/docs/build scripts explain the
remaining packaging differences. It depends on `tree-sitter-bash@0.25.1`,
`web-tree-sitter` (resolved `0.26.11`), and `zod@4.4.3`. The first dependency has
a native `node-gyp-build` install hook, although the audited runtime uses its
WASM grammar. An ignore-scripts disposable graph reported no known npm audit
vulnerability and valid/missing-free package signatures.

Positive findings include Zod config validation, most-restrictive-wins
resolution, canonicalized path checks, explicit unknown-tool behavior, decision
logs, and a fail-closed tool-call boundary. Fixtures confirmed parser failure
blocks the call, invalid config reports issues, and a `.env` path can be denied.
The parser decomposed chains, substitutions, subshells, pipelines, background
commands, and malformed partial trees conservatively. Opaque known wrappers were
raised to `ask`.

The boundary remains command-policy defense in depth. With a permissive catch-all
fixture, direct or indirect execution via `command`, `exec`, shell scripts,
`source`, Python/Node interpreters, package scripts, Make recipes, Git shell
aliases, functions, conditionals, loops, variable command names, aliases, and
quoted/escaped spellings resolved to allow. Redirection-only syntax was asked,
but a redirection target did not affect command-surface resolution by itself.
These are not necessarily implementation bugs—the package also has path/tool
surfaces and configurable wrapper policy—but they prove that a deny rule such as
`git push*` is not a complete process or filesystem boundary. It also persists
review/debug logs and supports cross-session permission forwarding through
filesystem polling, adding state and authority that the default Hermes/Codex
architecture does not need.

**Decision:** do not install. Written allowlists and post-work diff audits remain
mandatory; use an OS boundary for offline verification. A future Pi-only pilot
could consider this package as a second layer only after a policy corpus covers
all available process tools and default-deny interpreter/wrapper behavior.

Disposable evidence remains at `/tmp/pi-permission-system-audit/` for this run.

## Other top-ranked candidates

These candidates were explicitly closed from the priority queue based on the
batch-1 inventory plus architecture gate; package count is not a goal:

- `pi-lens@3.8.71`: reject for default use—LSP/lint/typecheck value overlaps
  Graphify and existing verification, while analyzer startup, optional tool
  installation, autofix/mutation, and its install/dependency surface exceed a
  read-only advisory role.
- `pi-readseek@0.8.5`: defer until a measured edit-integrity defect exists—hash
  anchors are useful, but it replaces read/edit semantics and overlaps Graphify
  plus Codex's existing edit contract.
- `pi-shazam@0.30.0` and
  `@mrclrchtr/supi-code-intelligence@2.5.0`: reject absent a benchmarked Graphify
  gap—the tree-sitter/LSP/MCP/process/index surface adds no demonstrated unique
  value.
- `pi-simplify@0.2.3`: reject—changed-code review is already covered by
  `improve`, ponytail, GSD verification, and `/pr-review`, and the extension is
  not constrained to read-only recommendations.
- `@zephyrdeng/pi-review@0.11.0`, `pi-pr-review@1.11.3`, and
  `@vigolium/piolium@0.0.13`: reject for the default stack—each adds model routing,
  subagents, publication, durable coordination, or review orchestration already
  owned by Hermes/GSD and the existing adversarial review path.
- `pi-landstrip@0.17.34` and all subagent/swarm candidates: reject—combining
  permission prompts with recursive delegation conflicts with the single
  implementation lane and makes the security boundary harder to reason about.
- all memory, task, goal, workflow, observability, and Context7/web-search
  candidates remain rejected for authority duplication or external data flow as
  recorded in [`package-matrix.md`](package-matrix.md).

## Verification contract for the extracted pattern

The repository contract exercises a disposable Git fixture and proves:

- the default worktree mount refuses writes;
- one explicit existing directory becomes writable;
- `.git` remains read-only even under `--write .`;
- a host sentinel environment variable is absent;
- network denial and empty home pass the doctor's real boundary smoke;
- timeout preserves status 124;
- symlinked and absolute write paths are rejected;
- package-manager and Node commands can resolve through mounted `/nix/store`
  paths on the supported host.

The helper intentionally does not support macOS/Windows, host daemons, Docker,
interactive approval persistence, network allowlists, implicit write discovery,
or transparent absolute worktree paths. Fail closed and use a separately reviewed
execution path when those constraints do not fit.
