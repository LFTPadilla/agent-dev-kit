# Ops rules — orchestrate

Tactical rules carried over from campaigns. They do not change the core
loop; they prevent specific, already-observed failures.

## 1. Mid-task handoff trigger

When a multi-hour task has accumulated enough complex state (PRs, cluster
mutations, blocked deploys, ambiguous errors) that continuing in the current
session would burn context and slow the user down, WRITE A HANDOFF. Do not
keep grinding "to finish it". The handoff is itself a deliverable; the
session that writes it well is succeeding, not giving up.

Signals: the user says "this is taking too long" / "do a handoff" / "switch
sessions"; context window filling past ~60% on a task that still has many
subtasks; "why is it taking so long?" — treat that variant as the same
signal, stop over-auditing or killing the in-flight worker, and report the
current state succinctly.

Pre-emptive kill: if a worker has been running for 2+ windows with no useful
output, kill it and re-scope rather than waiting for the user to complain.

## 2. Parallel-session guard prompt

When the user signals that ANOTHER session is working on the same fleet or
scope in parallel, generate a "guard prompt" the user can paste into the
other session to prevent collision. The guard MUST enumerate:

(a) the exact scope owned by this session,
(b) forbidden paths/keys/gateways/cronjobs,
(c) the operations the other session may run freely (read-only is usually safe),
(d) the communication channel (how either session sees the other's changes).

Do NOT assume the other session will see this session's work — be explicit
about which files/configs/namespaces are the source of truth at any moment.
The guard is a one-page block of text; if it is longer than 30 lines the
user will not paste it.

## 3. Verify the prior claim, not the worker

When a worker reports a finding (e.g. "the manifest contains only ConfigMap
X"), the independent verifier must RE-INSPECT the file or rendered output
with a parser, not just accept the worker's summary. Prior claims have been
partial before: correct about a file, wrong about the production render that
includes it.

The verifier's deliverable states `final_verdict: PRIOR_CLAIM_CORRECT |
PARTIAL | WRONG` and quotes exact line ranges or resource counts as evidence.
Skip this only when the prior claim is a single short fact and the cost of
re-verification exceeds the risk of being wrong.

## 4. Parallel-session PR number collision

When two sessions share a repo and both call `gh pr create`, GitHub assigns
the next number to the FIRST request that lands; the other session gets a
different number back. `gh pr view N` then returns the OTHER session's PR if
you use the number without checking title and state. This caused a near-miss
merge: session A's `gh pr create` returned 457, session B's returned 456 (a
different workstream); A's `gh pr view 456 --json state,mergeCommit,title`
printed B's title with `MERGED`, so A believed its own PR was already merged.

The fix is mechanical. BEFORE every `gh pr view`, `gh pr merge`, or
`gh pr close`, run:

```bash
gh pr view <n> --json state,mergeCommit,title --jq '"\(.state) \(.mergeCommit.oid[0:8]) \(.title)"'
```

and confirm the title matches the branch you just pushed. If it does not,
find YOUR number by branch:

```bash
gh pr list --head <branch> --json number,title --jq '.[] | "\(.number) \(.title)"'
```

Applies symmetrically to `gh pr merge --admin`, `gh pr close`, and
`gh api repos/<owner>/<repo>/pulls/<n>/merge` — the number is authoritative
and the title is the only reliable cross-check when two sessions race.
