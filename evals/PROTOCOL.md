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
| semgrep `p/owasp+js+ts+nodejs` | ✗ | ✗ | ✗ | ✗ | — | **0/4** | 0 |
| LLM single-pass review (Claude, manual) | ✓ | ✓ | ✓ | ✓ | — | **4/4** | 0 |

### Deterministic Semgrep full-suite rerun — 2026-07-22

Command: `npm run eval:semgrep` with public packs `p/owasp-top-ten`,
`p/javascript`, `p/typescript`, and `p/nodejs`.

| Tool | Planted caught | Recall | Clean FP | FP rate |
|---|---|---|---|---|
| Semgrep public packs | 1 / 12 (case 10, overbroad credentialed CORS) | **8%** | 0 / 3 | **0** |

The previously documented `p/nodejs-scan` registry name returned HTTP 404 and
was replaced with `p/nodejs`. The runner now exits with status 2 on scan/config
failure instead of silently turning a failed scan into a zero-finding score.

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

### Live `/pr-review` against a real GitHub PR — 2026-08-17

**Label: first live run, closed PR.** Method: an agent followed
`plugins/dev-skills/commands/pr-review.md` against the live PR — `gh` scout
(`pr view` metadata, file list, `pr diff`), then the five lenses (correctness,
security, performance, quality + ponytail advisory) with the pre-report gate,
then adversarial verification of every BLOCKER/HIGH/MEDIUM finding by
attempting to disprove each one against the real code (default refute). Not
executed as the literal Workflow fan-out and not CI: the agent ran the lenses +
verify pass directly.

- **PR:** LFTPadilla/agent-dev-kit#3 "chore: unvendor third-party agent skills,
  make skills-lock.json the source of truth". Closed; never merged via the PR —
  its content reached `main` as squash `92bdc61`, with stacked #4/#5 on top.
- **Diff measured: 10 files, +249/−4 — not the ~300-file deletion the brief
  expected.** The 286-file / ~95k-line `.agents` deletion (commit `00bc0840`)
  is in the branch history but not in GitHub's computed PR diff (the branch
  diverged/rebased; the same deletion reached `main` via the squash). Reviewed
  target: docs + `skills-lock.json` + one new validator — `.gitignore`,
  `ATTRIBUTION.md`, `CURATION.md`, `README.md`, `bootstrap.sh`,
  `docs/README.md`, `docs/external-deps.md`, `docs/skills-catalog.md`,
  `scripts/agent-dev-kit.mjs`, `skills-lock.json`.
- **Verdict: BLOCKER 0 · HIGH 0 · MEDIUM 2 · LOW 3 — no blocking issues found.**

Surviving findings:

| Severity | Finding | Evidence |
|---|---|---|
| MEDIUM | Restore is unpinned and hash-soft: no lock entry records a git `ref`, so restore follows each source's default branch, and the CLI *rewrites* `computedHash` on reinstall instead of failing — changed/compromised upstream content installs silently, with manual lock-diff review as the only guard. Author documents it as accepted risk. | `skills-lock.json` (17 entries, no `ref`); `docs/external-deps.md:77-79`; CLI `skills@1.5.22` source (`addSkillToLocalLock` wholesale-replaces the entry) |
| MEDIUM | New `validateSkillsLock` has no automated test; its two failure modes were exercised manually only (PR body). No validator in this repo has tests (no harness exists), so this is a repo-wide gap, not new to this PR. | `scripts/agent-dev-kit.mjs:242-255` (validator), `:442` (registration); `package.json` has no `test:validate` |
| LOW | `validateSkillsLock` checks `license` presence only, not SPDX validity — a hand-edited wrong value passes validate. Deliberate (guards the CLI dropping the field on reinstall), but a bad license edit goes green. | `scripts/agent-dev-kit.mjs:253` |
| LOW | Stray blank line added in `.gitignore` (between `private-overlays/` and `.agent-runs/`) and a double blank line after the new table. | PR diff, `.gitignore` hunk 2; `docs/skills-catalog.md:83-84` |
| LOW | `docs/skills-catalog.md` mixes install syntaxes in one table: bare-repo rows (`npx skills add Leonxlnx/taste-skill`, `…pbakaus/impeccable`) vs `@skill` rows (`…@3d-web-experience`); ambiguous what a bare-repo add installs for multi-skill repos. | `docs/skills-catalog.md:78-82` |

Refuted / dropped by the adversarial pass (false positives caught):

- "`validateSkillsLock` fail-opens (`warn`) when git is missing" — deliberate
  and documented; the bad outcome is vacuous (no git ⇒ nothing can be tracked).
- "docs' `computedHash` claim is wrong (whole-folder sha256)" — confirmed
  accurate against CLI `skills@1.5.22` source and an exact Node replication.
- "hallmark's lock hash is stale/wrong" — initial mismatch vs hallmark HEAD
  looked like a defect; the lock hash exactly matches the deleted pinned copy at
  `7f9fc4d` (`8a8ecafd…`), and the HEAD mismatch is upstream drift (hallmark
  moved 2026-08-06) — the documented drift signal. Most instructive FP.
- "README/docs advertise a dead website" — `agent-dev-kit.devpipe.net`
  returned HTTP 200; claims true.
- "upstream licenses misrecorded" — `gh api …/license` for all five sources
  matches the lock (16 MIT + Apache-2.0).
- "renamed `sickn33/antigravity-awesome-skills` breaks the lock" — still
  resolves (GitHub redirect), MIT verified, rename documented.
- "PR risk note overstates the license drop" — confirmed: `addSkillToLocalLock`
  replaces entries wholesale, so a reinstall does drop `license`.

Ponytail advisory (advisory only — never blocks, never counted): the stray
blank lines above are trims; `README.md:11,14` point at the same URL twice
(badge + prose); "pinned, not vendored" + the restore command are re-explained
in four places (`ATTRIBUTION.md`, `CURATION.md`, `README.md`,
`docs/external-deps.md`) where cross-references would do.

**Caveats:** run by an agent following the command spec, not the literal
Workflow fan-out and not the CI Workflow; the PR is closed and its content is on
`main` (squash), so this scores the reviewer against the PR's current diff, not
a merge decision; the diff is small and mostly additive, so lens coverage
(especially performance — zero findings, thin by construction) is limited; only
`hallmark`'s `computedHash` was independently recomputed, not all 17; the run
was read-only — the 17 skills were never installed.

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
