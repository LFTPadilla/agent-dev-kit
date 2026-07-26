# `context-mode@1.0.169` Source Audit

Audit date: **2026-07-22**  
Decision: **do not install, enable, or pilot in agent-dev-kit**

## Reviewed identity

- Pi catalog: <https://pi.dev/packages/context-mode>
- npm: <https://www.npmjs.com/package/context-mode/v/1.0.169>
- source: <https://github.com/mksglu/context-mode>
- release: [`v1.0.169`](https://github.com/mksglu/context-mode/releases/tag/v1.0.169)
- reviewed source commit: [`589d8214d56740a28b5f7bf63167743d586b0b40`](https://github.com/mksglu/context-mode/commit/589d8214d56740a28b5f7bf63167743d586b0b40)
- npm publication: `2026-06-29T18:18:27.670Z`
- published tarball SHA-512:
  `f78248685b8b8c5f523b606c193adb1adc93e382bde7ef4e0bc05d6da2ff513efac4e91a9c92df511e42ce6370f8610b5d942a1f89c1aca83dc230674859159d`
- registry integrity:
  `sha512-94JIaFuLjF9SO2BsGTrbGtyT44K95+9OC8BdbaL/UT76xOkanJLfUR5CzmNw+GELXZQqH4nBrKg9wjBnSFkVnQ==`
- license: Elastic License 2.0, a source-available license with managed-service,
  license-key, and notice restrictions; it is not an OSI-approved open-source
  license.

The repository was active and unarchived at review time. The latest npm release
was 23 days old; the default branch's latest human source commit was the release
commit, while a `next` branch had human changes through 2026-07-19. GitHub
reported 19,198 stars, 1,350 forks, and 100 open issues. These are activity
signals, not security evidence.

## Purpose and architecture

The package attempts to keep large tool outputs out of model context by:

- executing analysis in subprocesses and returning only printed summaries;
- indexing content and command output in a local SQLite FTS5 store;
- fetching URLs into that store and searching it with BM25;
- recording session events, building compaction resume snapshots, and injecting
  selected active memory on later turns;
- routing raw HTTP-oriented Bash usage toward its own tools.

For Pi, the extension starts an MCP stdio child and registers the package's tools
inside Pi because Pi does not natively expose the package's MCP server. See the
[Pi bridge bootstrap](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L430-L463)
and [MCP bridge](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/mcp-bridge.ts).

## Package and install surface

Runtime requirement: Node `>=22.5.0` (or Bun for the Linux path). Direct runtime
dependencies at the reviewed version:

- `@clack/prompts ^1.0.1`
- `@mixmark-io/domino ^2.2.0`
- `@modelcontextprotocol/sdk ^1.26.0`
- `better-sqlite3 ^12.6.2`
- `picocolors ^1.1.1`
- `turndown ^7.2.0`
- `turndown-plugin-gfm ^1.0.2`
- `zod ^3.25.0`

The package has a `postinstall` script. It hard-fails unsupported Linux/Node
combinations, heals native SQLite bindings, can inspect and mutate Claude plugin
registries/settings/cache paths, create symlinks or Windows junctions, rewrite
shims, and normalize hooks. Some mutation is global-install-gated, but the stale
registry symlink repair is not. Evidence:
[`scripts/postinstall.mjs`](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/scripts/postinstall.mjs#L22-L337).
Therefore Pi's “temporary” `-e` install is not assumed side-effect-free.

The npm tarball had 354 files and a registry signature. It did not expose npm
provenance attestations in the reviewed metadata. `package.json` and
`hooks/platform-bridge.mjs` matched the release tag byte-for-byte, but the
published `server.bundle.mjs` and `cli.bundle.mjs` did not, and the published Pi
build artifact was generated during publication rather than present at the tag.
That weakens source-to-artifact reproducibility even though prepublication builds
can explain the difference.

## Process and permission behavior

The important tools are not read-only advisory helpers:

- `ctx_execute`: arbitrary JavaScript/TypeScript/Python/shell/Ruby/Go/Rust/PHP/
  Perl/R/Elixir/C# subprocess execution, full network access, optional working
  directory, and optional background detachment. The package labels it
  destructive/open-world in its own annotations. Evidence:
  [`src/server.ts` lines 1647-1751](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/server.ts#L1647-L1751).
- `ctx_execute_file`: executes supplied code over a file. A project-boundary
  guard was added after a documented outside-workspace read class.
- `ctx_batch_execute`: runs arbitrary shell command batches, with network, up to
  eight-way concurrency, and indexes all output. Evidence:
  [`src/server.ts` lines 3678-3832](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/server.ts#L3678-L3832).
- `ctx_index`: reads content/files/directories and writes the persistent FTS5
  store; `ctx_search` reads that store.
- `ctx_fetch_and_index`: fetches external URLs and persists the result.
- diagnostics, statistics, insight, upgrade, and purge surfaces add further
  filesystem/process/browser/configuration behavior.

Execution uses a deny-only firewall derived primarily from host permission
configuration. Several defensive paths are explicitly best-effort or fail-open,
including Pi routing failure and server-side security-check failure. A Pi tool
allowlist constrains model-visible built-ins but does not sandbox extension code
or its child process.

## Context and prompt behavior

The Pi extension does more than compress output:

1. It intercepts Bash tool calls and blocks many inline HTTP clients, redirecting
   the model toward context-mode tools; exceptions fail open. Evidence:
   [`extension.ts` lines 480-528](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L480-L528).
2. It records tool names, inputs, normalized results/errors, and generic unknown
   tool parameters. Evidence:
   [`extension.ts` lines 530-603](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L530-L603).
3. It extracts events from user prompts, injects a routing hierarchy, adds up to
   roughly 500 tokens of active memory on every turn, and consumes resume
   snapshots. Evidence:
   [`extension.ts` lines 605-729](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L605-L729).
4. It appends that material as a user-role message at the end of context rather
   than changing the system prompt. Evidence:
   [`extension.ts` lines 736-753](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L736-L753).
5. It records provider/model/latency/token metadata, per-turn usage and cost,
   compaction snapshots, and cleanup events. Evidence:
   [`extension.ts` lines 755-868](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/src/adapters/pi/extension.ts#L755-L868).

This is a competing context and memory policy, not a transparent compressor.
Injected historical material can influence a bounded worker beyond the task
contract even when the package is functioning as designed.

## Filesystem, retention, network, and privacy

- Session SQLite data is project-scoped and cleaned after seven days by the Pi
  extension. Content/index databases and stale sources are cleaned after 14
  days. Cleanup is best-effort.
- Storage defaults under platform configuration roots in `context-mode` folders;
  `CONTEXT_MODE_DATA_DIR` can relocate package-owned storage. Stats JSON and
  event/retrieval sidecars are also written.
- Local records include prompt-derived events, tool input/result metadata,
  decisions/tasks/errors, provider usage/cost, resume snapshots, fetched/indexed
  content, and command output. This can include source, paths, URLs, log data,
  and secrets missed by upstream extraction or redaction.
- The server checks npm for new versions at startup. User-invoked fetch and
  execution tools can access the network; execution tools explicitly have full
  network access.
- If a valid `platform.json` exists under the context-mode configuration path,
  session events are POSTed to the configured `${platform_url}/events`. The
  forwarder normalizes home paths, applies a finite list of regex redactions,
  truncates fields, and includes a canonical project identity that can derive
  from the Git remote. Redaction is not a proof that arbitrary sensitive data is
  safe. Evidence:
  [`platform-bridge.mjs`](https://github.com/mksglu/context-mode/blob/589d8214d56740a28b5f7bf63167743d586b0b40/hooks/platform-bridge.mjs#L1-L319).

No implicit event upload occurs when that configuration is absent, but version
checks and user-directed open-world tools remain network-capable. In a real-home
profile, an extension can discover its own configuration independently of the
agent's instruction not to read secrets.

## Maintenance, tests, and security posture

Positive evidence:

- extensive unit/integration tests, including Pi extension/bridge cases,
  project-boundary regression tests, and environment scrubbing;
- CI on Linux, macOS, and Windows with typecheck, build, bundle assertions, and
  tests;
- a separate real-host E2E smoke workflow for Pi/Claude/OpenCode;
- explicit MCP safety annotations and several fixes for prior traversal,
  orphan-process, environment-leak, and routing issues.

Limitations:

- the audited repository had no `SECURITY.md`, CODEOWNERS, or Dependabot config;
- CI used `npm install`, and no CodeQL/Semgrep or dependency-audit gate was found;
- the real-host workflow installed latest Pi rather than a pinned version;
- multiple checks are best-effort/fail-open;
- the large cross-platform/install/self-heal surface raises regression risk;
- the package is maintained primarily by one author despite community
  contributions.

Tests were inspected but not executed because that would require installing the
unaudited dependency tree and running install hooks. No package was installed or
enabled during this audit.

## Fit with agent-dev-kit

| Existing owner | Overlap/conflict |
| --- | --- |
| GSD | Session task/decision/resume state risks becoming a second durable workflow narrative. GSD must remain authoritative. |
| Hermes Personal Dev Tutor | Per-turn memory/routing injection competes with Hermes's bounded task and teaching context. |
| Graphify | File/directory indexing and code-oriented execution duplicate parts of local cross-file navigation, with a broader process surface. |
| Context7 | URL fetch/index/search duplicates public library-document retrieval while expanding arbitrary-network and retention scope. |
| Codex bounded worker | Background processes, open-world execution, stored history, and injected prior context violate the narrow worker contract. |
| Existing verification | It does not replace tests, deterministic analysis, Semgrep, or independent diff review. |

## Decision

The package is active and technically sophisticated, and its output-reduction
idea is valuable. It is nevertheless a poor fit for the default architecture.
The unique benefit does not justify installing a second context/memory layer with
arbitrary execution, persistent sensitive state, install-time mutation, optional
telemetry, and substantial retrieval/navigation overlap.

**Do not install or enable `context-mode` in Personal Dev Tutor, Hermes, Codex,
or Pi delegation profiles.** A future reconsideration would require a narrower
upstream mode that has no execution tools, no prompt/session capture, no remote
forwarding, no install-time home mutation, an explicit external cache with
verified purge, reproducible published artifacts, and measurable benefit over
Graphify + Context7 + the existing Hermes context controls.

## Exercised safer substitute

The package itself was not smoke-tested because its source audit failed the
pre-install safety gate; running its postinstall or Pi bridge merely to validate
README claims would violate the gate. Instead, Personal Dev Tutor implements and
exercises the narrow useful behavior as `personal-tutor-output`:

- it executes only the explicit argument vector supplied by the caller and does
  not add tools, model routing, prompt injection, memory, indexing, network
  access, background processes, or install hooks;
- it captures exact combined output in a mode-0600 cache outside the worktree,
  reports its path and SHA-256, and preserves the command exit status;
- it bounds successful noisy output by lines or bytes; failed commands and
  security output display in full up to 32 KiB and use a bounded leading/trailing
  preview above that threshold, while their exact transcripts remain retained;
- it refuses a cache located inside the worktree and has no automatic upload or
  retention cleanup.

Transcripts are deliberately labeled unredacted/manual-retention. The helper is
not a secret detector: commands that might emit sensitive content are a hard
skip, and retained evidence should be deleted when no longer needed. Known
security-scanner executables are rejected unless security mode is explicit;
task-runner wrappers still require correct caller classification.

The disposable-fixture contract covers a 300-line success, a 100,001-byte
single-line success, exit status 7 with 300 lines of exact failure evidence,
small security output, oversized failure bounding, known-scanner classification, transcript hash and cache
permissions, failed permission setup, canonical top-level handling, and rejection
of direct, nested-path, or symlinked in-worktree caches. A separate
5,000-line measurement retained a 290,000-byte exact transcript while emitting
a 1,708-byte preview (99.411% fewer bytes; 169.79× smaller), with 4,980 lines
explicitly marked omitted. This is a deterministic fixture measurement, not a
claim about model-token savings or production workloads.

Proactive use is limited to expected non-interactive build/test/lint output over
roughly 200 lines or 32 KiB. Skip conditions include short/focused output,
interactive commands, source inspection, ambiguous failures or security findings,
diagnostics, and any command that may print secrets or private content. The exact
transcript must be inspected before diagnosing omitted material, and neither the
preview nor its cache is lifecycle or verification authority.
