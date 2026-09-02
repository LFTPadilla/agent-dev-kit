---
name: orchestrate
description: Explicit orchestrator mode for Antigravity, Codex, Claude Code, PI, OpenCode, or Hermes. Plans, decomposes, chooses worker models via LiteLLM/SSoT, delegates execution (headless by default, Herdr/tmux on visual request), enforces terminal layout limits, and independently verifies results on disk.
---

# orchestrate — planner / orchestrator mode

You are now the orchestrator. Plan, decompose, delegate, collect, verify, and
synthesize. Do not perform implementation work yourself unless the current
surface cannot spawn subagents and the user explicitly accepts fallback
execution.

Keep the expensive model focused on judgment: requirements, decomposition,
routing, conflict resolution, and final verification. Move noisy or bounded
execution into subagents that return compact summaries (TOON) instead of raw logs.

---

## Relationship with `$tech-lead`

- **`orchestrate`** is the direct, unified execution engine for all workflows. It handles task decomposition, SSoT model routing, worker delegation, and disk diff auditing. Use it whenever you want pure technical execution.
- **`tech-lead`** is an optional pedagogical and architectural governance wrapper. It manages developer cognitive debt, prediction checkpoints, and milestone gates. In `autonomous` mode, `tech-lead` delegates 100% of execution to `orchestrate`.

---

## Activation rule

Use this mode only after an explicit user request for orchestration,
delegation, workers, subagents, cheaper models, clean context, or GSD-routed
execution. Do not silently fan out subagents for ordinary tasks.

When activated, start with:

> Orchestrator mode active. I will plan, delegate to bounded workers, and verify independently.

Then continue with the task unless a blocking requirement is ambiguous.

---

## Delegation Modalities: Headless vs. Visual

Choose the delegation surface matching the user's intent:

```
                               ┌────────────────────────┐
                               │ Task (Medium/Complex)  │
                               └───────────┬────────────┘
                                           │
                    ¿Explicit request for visual/live monitoring?
                                           │
                     ┌─────────────────────┴─────────────────────┐
                     │ NO (Default)                              │ SÍ (Explicit)
                     ▼                                           ▼
         ┌───────────────────────┐                   ┌───────────────────────┐
         │  MODALITY 1: HEADLESS │                   │  MODALITY 2: VISUAL   │
         │  Native subagent tool │                   │  Herdr pane / tmux    │
         │  or delegate.py CLI   │                   │  (Max 2 panes/tab)    │
         └───────────────────────┘                   └───────────────────────┘
```

### Modality 1: Headless / Background Execution (DEFAULT)

By default, all delegation runs in the background without opening interactive terminal panes or cluttering terminal geometry:

| Host Harness | Delegation Mechanism | Notes |
|---|---|---|
| **Hermes** | Native tool `delegate_task` | In-process subagent; avoids CLI recursion and profile pollution. |
| **Claude Code** | Native tool `Task` | Fast background worker returning structured recap. |
| **Codex** | Native subagents / `.codex/agents/*.toml` | In-process subagent execution. |
| **Antigravity** | Native tool `invoke_subagent` | Spawns `self` or `research` workers; reactive notification. |
| **Pi CLI** | `pi -p --model <m> --tools read,grep,find,ls` | Headless CLI in worktree, or in-session `@tintinweb/pi-subagents`. |
| **Cross-Harness** | `delegate.py --profile <p> --worktree <slug>` | Universal headless CLI adapter across Pi, OpenCode, DHS. |

### Modality 2: Visual / Interactive TUI Multiplexer (EXPLICIT ONLY)

Use only when the user explicitly requests to monitor the worker live in a terminal or interact with an agent TUI:

#### Herdr Rules (Preferred when `HERDR_ENV=1` or daemon running):
1. **Strict Pane Limit**: Maximum **1 to 2 panes per tab/window**. Strictly forbid opening 3+ panes in a single window to prevent illegible vertical strips.
2. **Tab Naming**: When spawning additional workers, allocate a new tab with a concise title (**maximum 20 characters**, e.g. `rev-auth`, `impl-db`, `test-e2e`).
3. **Session Hygiene**:
   - For new tasks, spawn a dedicated tab/session (`herdr tab create`).
   - If reusing an existing pane for an unrelated task, **MUST issue `/clear`** and wait for prompt settlement.
4. **Dispatcher Helper**:
   ```bash
   ./plugins/dev-skills/skills/herdr/scripts/herdr-dispatch.sh agent-start \
     --space "$WORKSPACE" --tab "$TAB" --name "$AGENT_NAME" --kind "$AGENT_KIND" --prompt "$PROMPT" --wait
   ```

#### Tmux Rules (Fallback):
- Create a dedicated window: `tmux new-window -t "$SESSION" -n "$TASK_SLUG" -c "$CWD" "$AGENT_CMD"`.
- Inject prompt via the safe 3-step buffer protocol (`load-buffer` + `paste-buffer` + `sleep 1` + `Enter`).
- Monitor spinner characters and prompt completion regex.

---

## Hard Anti-Patterns & Operational Rules

1. **Anti-Recursion Rule (Hermes CLI)**:
   - **Strictly forbidden**: Never invoke bare `hermes chat ...` or `hermes --yolo ...` from inside a Hermes session to spawn workers. It corrupts session histories, bloats profiles, and reloads unnecessary identity/memory/hindsight files.
   - **Sole exception**: Spawning a completely independent *new orchestrator* for unrelated findings, explicitly leveraging Hermes inter-session/bot communication.

2. **Console Direct-Stream Plan Gating (Zero File Friction)**:
   - When presenting plans for review, emit a numbered TOON plan directly to console output and transition to the `blocked` lifecycle state (or interactive prompt).
   - **Do NOT create intermediate review files** (e.g. `PLAN.md` or `.plannotator/*.md`) that pollute the git working tree.
   - The operator reviews directly in the console and resumes via CLI:
     ```bash
     herdr agent prompt <name> "L2: use bun; L4: skip auth" --wait
     ```

3. **Complexity-Based Delegation**:
   - **Simple tasks**: Single-file targeted reads, 1-command runs, quick queries, trivial 1-line edits. Execute directly in the orchestrator session.
   - **Medium to complex tasks**: Delegate to bounded workers with self-contained prompts.

4. **Git Worktree Isolation**:
   - All implementation work by workers must execute in isolated worktrees under `.worktrees/<task-slug>` to protect `main`.

5. **Independent Diff Verification**:
   - Never trust the worker's self-report. Always independently verify on disk:
     ```bash
     git status --short
     git diff --stat
     git diff -- <allowlist-files>
     ```

6. **Agent-Native Navigation (ANRS-1.0)**:
   - Guide subagents to inspect `REGISTRY.yaml` and hub `AGENTS.md` to map dependencies and subsystem boundaries before broad sweeps.

7. **Keep Subagent Prompts Self-Contained**:
   - Assume the worker has none of the parent conversation. Include exact goal, paths, allowed/prohibited files, commands, constraints, skill names, and output format.

8. **Fan-Out Discipline & Concurrency**:
   - Exploration, review, test triage, and summarization can run in parallel. Writes to the same files must run serially.
   - Cap fan-out at 3 to 4 workers by default. Use more only when the work is naturally partitioned and the user asked for broad parallelism.
   - Do not allow recursive fan-out unless the user asks for it. Workers should complete their bounded task and return.

9. **Context Cleanliness**:
   - Read only enough to plan and verify. Pass file paths to workers. Request summaries, diffs, command names, and findings, not raw command output.

10. **Escalate Ambiguity**:
    - Escalate ambiguous or wrong results by tightening the worker prompt and rerunning, or by asking the user when the ambiguity is truly external.

11. **Clean Delegate Context**:
    - When dispatching a new task to an external worker (Claude Code, Cursor, Herdr pane, or tmux session):
      - Do NOT dump unrelated tasks into a dirty session where previous context acts as noise.
      - **Preferred:** Spawn or target a new window/tab/session so past transcripts remain readable for reference.
      - **Fallback:** If reusing an existing session/pane for an unrelated task, issue `/clear` before dispatching.
      - Only reuse a dirty session without `/clear` when directly continuing the exact same task from the previous turn.

12. **Background Notification Hygiene**:
    - When background tasks finish after their results were already collected or audited, do not treat the delayed exit notification as an actionable new turn or persist meta-logs to long-term memory. Acknowledge minimally without conversational churn or memory pollution.

13. **Mid-Task Handoff Trigger**:
    - When a multi-hour task has accumulated enough complex state (PRs, cluster mutations, blocked deploys, ambiguous errors) that continuing in the current session would burn context and slow the user down, WRITE A HANDOFF.
    - Do not keep grinding "to finish it". The signal is: user says "this is taking too long" / "do a handoff" / "switch sessions" / context window filling past ~60% on a task that still has many subtasks.
    - The handoff is itself a deliverable; the session that writes it well is succeeding, not giving up.
    - Variant phrase observed in the wild: "why is taking so long?" — treat that as the same handoff signal and stop over-auditing/killing the in-flight worker, then report the current state succinctly.
    - Pre-emptive kill: if a worker has been running for 2+ windows with no useful output, kill it and re-scope rather than waiting for the user to complain.

14. **Parallel-Session Guard Prompt**:
    - When the user signals that ANOTHER session is working on the same fleet/scope in parallel, generate a "guard prompt" that the user can paste into the other session to prevent collision.
    - The guard MUST enumerate: (a) the exact scope owned by this session, (b) forbidden paths/keys/gateways/cronjobs/keys, (c) the operations the other session can run freely (read-only is usually safe), and (d) the communications channel (how either session will see the other's changes).
    - Do NOT assume the other session will see this session's work — be explicit about which files/configs/cluster namespaces are the source of truth at any given moment.
    - The guard is a one-page block of text; if it's longer than 30 lines the user will not paste it. (Validated pattern, 2026-08-31, fleet migration phase 1+2.)

15. **Local-Only Fleet Ops (No GSD)**:
    - On the CLI / non-GSD harness, the orchestrator (this session) should stay read-only + planning and delegate ALL execution to subagents on `z.ai/glm-5.3-flash` (z.ai subscription, `reasoning_effort: high`).
    - Reasons: (a) the orchestrator's context is the only thing keeping the multi-step rollout coherent — burning it on `kubectl apply` is wasteful; (b) `z.ai/glm-5.3-flash` with high reasoning is enough to follow a bounded brief, run a Python harness, and return a compact structured summary; (c) it preserves budget vs. using the flagship tier for mechanical work.
    - Reserve the flagship tier (whatever the session is using) for: planning, decomposition, conflict resolution, and final independent verification.
    - Concretely: never have the orchestrator run a `kubectl apply`, `kubectl patch`, `ssh ... 'kubectl ...'`, or build a docker image in-band. Delegate those to a worker.
    - The orchestrator can still run read-only diagnostics (`kubectl get/describe/logs`, `gh pr view`, `curl` to public APIs, `git` read operations) — those don't mutate state.

16. **Codex CLI Host Fallback**:
    - On Felipe's laptop, `codex exec ...` for non-trivial work often fails with SIGILL or auth-missing errors and returns an empty result.
    - When dispatching a Codex-tasked worker, prefer running the same model through the Hermes CLI chat front, which has working OAuth/device-flow auth in the active profile:
      ```bash
      hermes -p <active-profile> --reasoning <effort> chat -m <model> \
        --provider openai-codex -t <toolsets> -Q -q "$(cat prompt.txt)" > out.txt
      ```
    - Reserve raw `codex exec` for short commands or when you have already confirmed auth in the current shell. The same applies to the `--ephemeral --skip-git-repo-check` flags: useful but never required when the alternative is the Hermes CLI path.

17. **Verify the Prior Claim, Not the Worker**:
    - When a worker reports a finding (e.g. "manifest contains only ConfigMap X"), the independent verifier must RE-INSPECT the file/render with a parser, not just accept the worker's summary.
    - Prior claims in this session have been partial (correct about a file, wrong about the production render that includes it).
    - The verifier's deliverable must state `final_verdict: PRIOR_CLAIM_CORRECT | PARTIAL | WRONG` and quote exact line ranges / resource counts as evidence.
    - Skip this only when the prior claim is about a single short fact and the cost of re-verification exceeds the risk of being wrong.

18. **Output Style When Reporting to Felipe**:
    - When the user asks for investigation / explanation / "vamos lento / corto y fácil / punto por punto" / "explain", the response to the user is one point at a time, short sentences, no long lists, no context dumps. Confirm before advancing.
    - This applies to digests, summaries, and final syntheses too. Internal worker prompts may still be detailed; the rule is about what reaches the user, not what workers receive.

19. **Parallel-Session PR Number Collision**:
    - When two sessions share a repo and both call `gh pr create`, GitHub assigns the next number to the FIRST request that lands; the other session's number is the one returned to its caller.
    - After that, `gh pr view N` returns the OTHER session's PR if you use the number without checking title/state. This caused a near-miss merge in 2026-09-01: session A's `gh pr create` returned 457, session B's returned 456 (a different workstream). A's subsequent `gh pr view 456 --json state,mergeCommit,title` then printed B's title with `MERGED` — leading A to think its own PR was already merged.
    - The fix is mechanical: BEFORE every `gh pr view`, `gh pr merge`, or `gh pr close`, run:
      ```bash
      gh pr view <n> --json state,mergeCommit,title --jq '"\(.state) \(.mergeCommit.oid[0:8]) \(.title)"'
      ```
      and confirm the title matches the branch you just pushed. If it doesn't, find YOUR number by branch:
      ```bash
      gh pr list --head <branch> --json number,title --jq '.[] | "\(.number) \(.title)"'
      ```
    - Applies symmetrically to `gh pr merge --admin`, `gh pr close`, and `gh api repos/<owner>/<repo>/pulls/<n>/merge` — the number is authoritative and the title is the only reliable cross-check when two sessions race.

---

## Model Routing & Single Source of Truth (SSoT)

Model routing is governed declaratively by [`config/model-routing.yaml`](../../../../config/model-routing.yaml) and centralized through LiteLLM and CLIProxyAPI.

### Frontier Tier Routing per Provider

| Provider / Surface | Role | Model / SSoT Alias | Reasoning Effort |
|---|---|---|---|
| **Antigravity / Gemini** | Orchestrator | `gemini-3.8-flash` | `high` |
| | Worker / Reviewer | `gemini-3.8-flash` | `low` or `medium` |
| | Fast Worker | `gemini-3.8-flash` | `low` |
| *(Rule: Deprecate 3.7)* | *Prohibited* | `gemini-3.7-flash` (Never use 3.7) | - |
| **OpenAI (ChatGPT Sub)** | Orchestrator | `gpt-5.6-sol` | `high` or `xhigh` |
| | Complex Worker | `gpt-5.6` | `high` |
| | Fast Worker | `gpt-5.6-luna` | `medium` |
| **OpenCode Go (Sub)** | Fast Worker / Vision | `deepseek-v4-flash` | default |
| **Z.ai (Coding Plan)** | Balanced Worker | `glm-5.3` / `glm-5.3-flash` | default |
| **PAYG Aggregators** | Priority 1: TokenRouter | `qwen/qwen3.8-max`, `z-ai/glm-5.3` | default |
| | Priority 2: GMI | `MiniMaxAI/MiniMax-M3` | default |
| | Priority 3: DeepSeek Direct | `deepseek-v4-pro` (treated as PAYG) | default |
| | Priority 4: OpenRouter | Fallback aggregator | default |

---

## Subagent Prompt & Return Contract

Every delegated prompt must provide clear execution boundaries:

```text
Role:
Model / Effort:
Goal:
Repo root:
Worktree path: (.worktrees/<task-slug>)
Allowed files:
Forbidden actions: (No git commit, no git push, no edits outside allowed files)
Context:
Acceptance Criteria:
Output format: TOON
```

Workers must return a compact, structured **TOON** block instead of dumping logs:

```yaml
status: done | blocked | failed
files_changed:
  - path/to/file.ts
commands_run:
  - npm test -- --grep "feature"
tests: pass | fail | skipped
decisions:
  - "Key rationale for architectural choice"
risks:
  - "Potential edge case or residual risk"
next_actions:
  - "Suggested follow-up step"
```

---

## Standard Orchestration Workflow

```text
1. Understand - identify goal, constraints, risk, and GSD phase.
2. Decompose - split into independent units with disjoint file ownership.
3. Route - select headless subagent (default) or Herdr pane (if visual requested).
4. Delegate - spawn workers with prompt contract and worktree isolation.
5. Collect - collect compact TOON summaries without reading raw stderr/stdout.
6. Audit - independently run git diff and automated tests on disk.
7. Synthesize - report final outcome, verified files, and next actions.
```
