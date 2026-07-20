# Agent Tutor Orchestrator — product and implementation design

Status: **implemented core** — generalist pure orchestrator; compose with
private org skills overlays outside this repo (see
[private-overlays.md](private-overlays.md)). Compare with firstmate in
[agent-tutor-vs-firstmate.md](agent-tutor-vs-firstmate.md).

## Cold-clone tiers (minimum viable path)

A fresh clone of this repo does **not** assume Hermes or any private overlay.
Use the tier that matches what you need:

| Tier | Goal | Path | Hermes? | Overlay? |
| --- | --- | --- | --- | --- |
| **A — Kit only** | Skills + `/pr-review` + evals | `clone` → `./bootstrap.sh` → Claude plugin install → `npm run doctor` / `npm run validate` | No | No |
| **B — Agent Tutor Orchestrator** | Pure orchestrator profile | Tier A optional; then `./scripts/tutor-install.sh` + `./scripts/tutor-doctor.sh` | **Required** | No (public skills only) |
| **C — Private overlay** | Org-specific skills | After Tier B, link skills from a registry **outside** this tree | Yes | Optional; cold clone must not claim these exist |

### Tier A — Kit only (no Hermes)

1. `git clone` this repo and `cd` into it.
2. `./bootstrap.sh` (npm core, skill link, validate; prints plugin install lines).
3. Inside Claude Code: install marketplace plugins as printed.
4. `npm run doctor` and `npm run validate`.

Tutor scripts under `scripts/tutor-*.sh` may already be present; they are unused
until Tier B. Agent Tutor Orchestrator is optional on this path.

### Tier B — Agent Tutor Orchestrator (this profile)

Requires [Hermes Agent](https://github.com/NousResearch/hermes-agent) on `PATH`.

```bash
./scripts/tutor-install.sh
./scripts/tutor-doctor.sh
hermes --profile agent-tutor-orchestrator
```

Public skills only (cold-clone ready):

1. `ai-workflow-orchestrator`
2. `orchestrate`

Defaults:

1. tmux session name: `tutor` (`AGENT_TUTOR_SESSION`)
2. profile: `agent-tutor-orchestrator` (`AGENT_TUTOR_PROFILE`)
3. optional clone source: `AGENT_TUTOR_CLONE_FROM` / `--clone-from` (no org default)
4. worklogs: under the tutor profile, or `AGENT_TUTOR_WORKLOG_DIR`

Canonical list: `profiles/agent-tutor-orchestrator.yml` → `include_skills`.

### Tier C — Private overlay (optional)

Skills listed under `requires_private_overlay` in the profile are **not** in this
repo. Missing them on a cold clone is expected. Compose later:

[private-overlays.md](private-overlays.md)

## What ships today

| Piece | Location | Tier |
| --- | --- | --- |
| Profile manifest | `profiles/agent-tutor-orchestrator.yml` | B |
| Public orchestrator skills | `ai-workflow-orchestrator`, `orchestrate` | B |
| Install / doctor (front door) | `scripts/tutor-install.sh`, `scripts/tutor-doctor.sh` | B |
| Internal helpers | `scripts/tutor-{smoke,status,bootstrap,delegate,audit,…}.sh` | B |
| Default tmux session | `tutor` (override with `AGENT_TUTOR_SESSION`) | B |
| Optional profile clone | `AGENT_TUTOR_CLONE_FROM` / `--clone-from` (no org default) | B |
| Worklogs | under the tutor profile, or `AGENT_TUTOR_WORKLOG_DIR` | B |
| Private overlay skills | outside this tree only | C |

Still open / optional: one-command remote installer polish, opt-in safe
auto-updater, and any org-specific overlay (lives outside this tree).

## 1. Goal

### 1.1 Role: pure orchestrator

The Agent Tutor Orchestrator is a **generalist pure orchestrator**, not an
implementer. It does not edit code, run tests, commit, push, or open PRs. Its
value is in:

- **holding the picture** — knowing what every subagent is doing right now
- **decomposing** work into lanes
- **routing** every concrete task to a subagent (tmux delegation to a Claude Code
  TUI in the `tutor` session, or a kanban card for restart-safe work)
- **monitoring** — `tmux capture-pane`, kanban tails, status reads
- **verifying by audit** — disk-level diff and contract check, never "I read the
  agent's summary and it sounded good"

The user can monitor each Claude Code TUI pane in tmux directly. The tutor's job
is to keep their mental model accurate and ensure no lane is silently dropped.

### 1.2 Lifecycle

The Hermes profile acts as a proactive AI development orchestrator and process coach.

It guides a developer through the full development lifecycle:

1. issue discovery
2. acceptance-criteria mapping
3. planning before code
4. delegation (the tutor never implements — subagents do)
5. monitor and verify (audit on disk)
6. adversarial review delegated to a reviewer subagent
7. PR validation delegated
8. staging QA evidence delegated
9. worktree/session cleanup

It should also answer questions about the workflow itself, recommend the next safe action, and keep the local setup current.

The important distinction:

- not just a static document
- not just a skill
- not just a prompt

The deliverable is an installable, self-updating Hermes profile made of:

- a Hermes profile
- one or more skills
- project templates
- an installer
- a safe updater
- dependency checks
- optional scheduled maintenance

## 2. Design principles

### 2.1 Proactive, but not reckless

The tutor must never auto-mutate anything in the user's repo. Mutations are owned
by subagents delegated to. The tutor's actions are limited to:

- tmux delegation (load-buffer + paste-buffer + Enter to a Claude TUI in `tutor:*`)
- kanban dispatch (`kanban_create`, `kanban_complete`, `kanban_block`)
- read-only verification (`git status`, `git diff`, `git log`, `gh pr view`)
- copy-paste handoffs of destructive commands to the user

The tutor should nudge the developer before mistakes happen:

- “This issue has no ACs; update it before planning.”
- “This touches auth; human review will be required.”
- “You are about to paste logs; redact secrets first.”
- “You implemented code without a plan; go back to Phase 2.”
- “QA evidence is missing before delivery can close.”

But it must not auto-mutate risky things:

- no production changes without explicit same-session approval
- no git push without explicit instruction
- no secret reading/printing
- no destructive cleanup without confirmation
- no blind auto-update that breaks a profile mid-work

### 2.2 Subagents live in the `tutor` tmux session

The orchestrator delegates to **Claude Code TUIs attached to tmux windows in a
named session** (default `tutor`). Each window is an independent worker:

- `tutor:<n>` is a window index inside the `tutor` tmux session
- the pane in that window runs `claude --dangerously-skip-permissions`
- the user can `tmux attach -t tutor` and watch live
- the orchestrator sends prompts via the tmux-safe three-step
  (load-buffer + paste-buffer + sleep + send-keys Enter)
- the orchestrator watches for spinner verbs and completion
- the orchestrator audits the diff on disk before reporting back

Branch-per-delegate is the default: each lane gets its own worktree, its own
tmux window, and its own branch. Merges happen later via a synthesis lane.

For multi-step, restart-safe work, the orchestrator uses **Hermes Kanban**
instead of tmux delegation. Kanban cards survive Hermes restarts, can run in
parallel, and keep a permanent audit trail.

### 2.3 Public core, private org overlay, project overlay

The public tutor includes generic reusable machinery:

1. workflow phases
2. safety policies
3. prompts and skill definitions
4. installation / bootstrap scripts
5. templates
6. optional update mechanism

Organization-specific details belong in a **private org skills registry outside
this repo** (never named or path-pinned in public docs):

1. internal repo names and hostnames
2. staging/prod URLs
3. GitHub org policies
4. QA ownership rules
5. customer data constraints
6. approved model/provider policy
7. internal examples

Repository-specific details belong in each project repo:

1. repo `CLAUDE.md` / `AGENTS.md`
2. repo-local skills, agents, hooks
3. repo-specific test/build/deploy commands
4. domain vocabulary and architecture notes

Full composition pattern: [private-overlays.md](private-overlays.md).

| Layer | Location | Contents | Update owner |
| --- | --- | --- | --- |
| Public workflow tutor | this open-source repo | generic phases, safety rules, installer, templates | public maintainers |
| Organization overlay | private skills registry (outside this tree) | policies, approved tools/models, QA rules, internal examples | organization |
| Project overlay | each project repo | project instructions, local skills/agents/hooks, domain context | project team |

This separation prevents context bleed: the public tutor teaches the method, the
org overlay adds policy, and the project overlay adds only local facts.

### 2.3 One command to install

Target user experience:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/agent-dev-kit/main/install-agent-tutor-orchestrator.sh | bash
```

or, if bundled into the existing agent-dev-kit CLI:

```bash
npx agent-dev-kit tutor install
```

Expected result:

- Hermes is installed or verified.
- A Hermes profile is created: `agent-tutor-orchestrator`.
- Required toolsets are enabled.
- Tutor skills are installed or symlinked.
- Templates are copied into an accessible directory.
- Optional updater cron is configured.
- A launch alias is created, e.g. `agent-tutor-orchestrator`.

### 2.4 Safe auto-update

The tutor should keep itself current, but updates must be reversible.

Recommended updater behavior:

1. Check latest version from the source repo.
2. If unchanged, do nothing.
3. If changed, download into a staging directory.
4. Run validation.
5. Backup the current profile/skills.
6. Apply update only if validation passes.
7. Write a changelog summary.
8. Notify the developer on next launch.

Auto-update should be opt-in during install:

```text
Enable automatic safe updates? [Y/n]
```

Default can be yes for non-invasive skill/template updates, but no for provider/model/config changes.

## 3. Repository layout (shipped core)

```text
agent-dev-kit/
├── docs/
│   ├── agent-tutor-orchestrator.md
│   ├── agent-tutor-vs-firstmate.md
│   └── private-overlays.md
├── profiles/
│   └── agent-tutor-orchestrator.yml
├── plugins/dev-skills/skills/
│   ├── ai-workflow-orchestrator/
│   │   └── SKILL.md
│   └── orchestrate/
│       └── SKILL.md
└── scripts/
    ├── tutor-install.sh
    ├── tutor-doctor.sh
    ├── tutor-bootstrap.sh
    ├── tutor-preflight.sh
    ├── tutor-status.sh
    ├── tutor-delegate.sh
    ├── tutor-audit.sh
    ├── tutor-smoke.sh
    ├── tutor-log-suggest.sh
    └── tutor-lane-update.sh
```

Optional later: split into a standalone `agent-tutor-orchestrator` package if the
surface grows beyond this kit.

## 4. Hermes profile contract

Profile name:

```text
agent-tutor-orchestrator
```

Launch commands:

```bash
hermes --profile agent-tutor-orchestrator
agent-tutor-orchestrator
```

Shipped profile contract (matches `profiles/agent-tutor-orchestrator.yml`):

```yaml
profile: agent-tutor-orchestrator
runtime: hermes
target: ~/.hermes/profiles/agent-tutor-orchestrator/skills
sandbox_policy: workspace-write
role: orchestrator
tmux:
  delegate_session: tutor
# Tier B — public skills only (cold-clone ready)
include_skills:
  - ai-workflow-orchestrator
  - orchestrate
# Tier C — not in this repo; missing on cold clone is expected
requires_private_overlay:
  - delegating-to-tmux-claude
  - kanban-orchestrator
  - kanban-worker
  - plan
  - writing-plans
  - subagent-driven-development
  - requesting-code-review
  - developer-audit
  - dogfood
  - test-driven-development
capabilities:
  - process-coaching
  - decompose-and-route
  - tmux-delegation
  - kanban-dispatch
  - post-delegation-audit
limits:
  production: explicit-only
  secrets: never-read-or-print
  git_push: explicit-only
  destructive_ops: explicit-only
  direct_code_edit: never
  direct_test_run: never
  direct_commit: never
  direct_pr_open: never
notes:
  - Pure orchestrator: plans and routes, never implements.
  - Link a private org skills overlay separately if present (Tier C).
```

Canonical source of truth: `profiles/agent-tutor-orchestrator.yml`.

## 5. Skill design

### 5.1 Main skill: `ai-workflow-orchestrator`

Trigger description:

```yaml
name: ai-workflow-orchestrator
description: Use when guiding a developer through an AI-assisted software development workflow as a pure orchestrator. Holds the picture, decomposes work into lanes, and delegates every concrete task to a Claude Code subagent attached to a tmux window in a named session (default `tutor`) or to a Hermes Kanban card. Does not edit, test, build, commit, or push itself. Trusts but verifies via disk-level audit.
```

Behavioral contract:

- Always identify the current phase.
- Ask for or locate the issue/ACs before implementation.
- Produce a phase checklist.
- Recommend the next safe action.
- Detect missing prerequisites.
- Flag risk escalation.
- Coach without taking irreversible actions by default.
- Keep a running phase summary when the task spans many turns.

### 5.2 Supporting skill: `ai-review-contract`

Purpose:

- define multi-lens review
- define severity rules
- define pre-report gate
- reduce false positives
- map findings to ACs

This can eventually replace or complement `/pr-review` for teams that want a general Hermes-native review process.

### 5.3 Optional private overlay skill

Private overlay skills live in an employer-local skills registry **outside this
public repo**. Placeholder name only:

```text
org-workflow-overlay
```

Typical contents (generic categories, not real org assets):

1. org-specific QA evidence rules
2. internal repo examples
3. review-bot policy
4. staging handoff details
5. team GitHub templates
6. approved model/provider policy

Compose at install time; see [private-overlays.md](private-overlays.md).

## 6. Installer behavior

The installer should be idempotent.

### 6.1 Preflight

Check:

```bash
command -v hermes
command -v git
command -v node
command -v npm
```

If Hermes is missing, offer to install using the official install command:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

Then run:

```bash
hermes doctor
```

### 6.2 Create profile

Preferred Hermes-native commands:

```bash
hermes profile create agent-tutor-orchestrator --clone-all
hermes profile alias agent-tutor-orchestrator agent-tutor-orchestrator
```

If cloning all existing configuration is too broad, use:

```bash
hermes profile create agent-tutor-orchestrator
hermes profile alias agent-tutor-orchestrator agent-tutor-orchestrator
```

Then configure minimal safety settings:

```bash
hermes --profile agent-tutor-orchestrator tools enable file
hermes --profile agent-tutor-orchestrator tools enable terminal
hermes --profile agent-tutor-orchestrator tools enable skills
hermes --profile agent-tutor-orchestrator tools enable todo
hermes --profile agent-tutor-orchestrator tools enable session_search
hermes --profile agent-tutor-orchestrator tools enable cronjob
```

Exact tool commands should be verified against the current Hermes CLI before implementation; Hermes supports `hermes tools enable NAME`, but profile flag placement should be tested in the installer.

### 6.3 Install skills

Options:

1. install via Hermes skills hub if published
2. install from direct raw `SKILL.md` URLs
3. symlink from local checkout during development

For public distribution, prefer direct URL or skill hub:

```bash
hermes --profile agent-tutor-orchestrator skills install https://raw.githubusercontent.com/<org>/<repo>/main/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md
```

### 6.4 Install templates

Copy templates to:

```text
~/.hermes/profiles/agent-tutor-orchestrator/templates/ai-workflow/
```

Also print instructions for copying templates into a project:

```bash
cp ~/.hermes/profiles/agent-tutor-orchestrator/templates/ai-workflow/CLAUDE.md ./CLAUDE.md
cp ~/.hermes/profiles/agent-tutor-orchestrator/templates/ai-workflow/pull-request-template.md ./.github/pull_request_template.md
```

### 6.5 Configure updater

The installer should offer:

```text
Enable safe daily updater for the tutor profile? [Y/n]
```

Implementation options:

1. Hermes cron job
2. systemd user timer
3. simple `agent-tutor-orchestrator update` command only

Recommended default: Hermes cron, because it is native and cross-platform within Hermes environments.

Cron prompt should be self-contained:

```text
Check for updates to Agent Tutor Orchestrator from <repo>. If a newer version exists, download to staging, run validation, backup current tutor profile/skills/templates, apply only if validation passes, and write a concise update report. Do not change model/provider credentials. Do not mutate user projects. If validation fails, leave current version untouched and report the blocker.
```

## 7. Runtime interaction model

When a developer starts the tutor, it should begin with:

```text
I am your workflow tutor. I will guide you through the AI development process.
Current phase: unknown.
To start, give me either:
1. a GitHub issue URL/number, or
2. a local task description, or
3. a repo path to prepare for AI-ready development.
```

The tutor should maintain a compact state:

```yaml
current_phase: discovery|plan|implement|review|validate|deliver
issue: <url/number>
risk_level: low|medium|high
sensitive_data: none|pii|phi|secrets|regulated
human_review_required: true|false
worktree: <path|null>
last_verification: <commands/results>
open_blockers:
  - ...
```

In Hermes, this can start as conversational state + todo list. Later, it can become a small local state file under `.agent-runs/agent-tutor-orchestrator/`.

## 8. Proactive interventions

The tutor should interrupt or warn when it detects:

| Detection | Tutor action |
| --- | --- |
| No issue/ACs | Ask for issue or propose issue template before planning. |
| User asks to code immediately | Recommend Phase 2 plan first. |
| Prompt includes likely secret | Stop and ask user to redact. |
| Diff touches auth/data/payment/infra | Escalate risk; require security checklist and human review. |
| Tests not run | Recommend exact verification commands. |
| PR description lacks AC mapping | Generate/fix PR template content. |
| QA evidence missing | Provide QA evidence comment template. |
| User asks for production mutation | Require explicit same-session authorization and summarize blast radius. |
| Auto-update available | Stage, validate, then notify/apply according to configured policy. |

## 9. Scope: shipped vs remaining

**Shipped (core):**

1. Main `ai-workflow-orchestrator` skill (+ companion `orchestrate` in public include list).
2. `profiles/agent-tutor-orchestrator.yml` manifest (pure orchestrator limits;
   overlay skills listed under `requires_private_overlay`).
3. Front-door installer + doctor; internal bootstrap / preflight / status /
   delegate / audit / smoke scripts.
4. Generic clone-from and worklog env knobs (`AGENT_TUTOR_*`, no org defaults).
5. Documented private-overlay composition pattern.

**Remaining / optional:**

1. Richer project templates pack under the profile.
2. Opt-in safe auto-updater.
3. One-command remote installer polish.
4. Any private overlay content (outside this repo only).

## 10. Non-goals

Do not put in this public kit:

1. full custom Hermes plugin UI
2. automatic code mutation by the tutor itself
3. organization-specific policy or naming baked into the public tree
4. fully autonomous production operations
5. installing paid third-party tools without explicit confirmation
6. adopting firstmate as the runtime (see [agent-tutor-vs-firstmate.md](agent-tutor-vs-firstmate.md))

A profile + orchestrator skill + installer scripts is the v1 core.

## 11. Update strategy

Version every release:

```text
agent-tutor-orchestrator.version = 0.1.0
```

Keep a local metadata file:

```json
{
  "installed_version": "0.1.0",
  "source_repo": "https://github.com/<org>/<repo>",
  "installed_at": "...",
  "last_update_check": "...",
  "auto_update": true
}
```

Backup before update:

```text
~/.hermes/profiles/agent-tutor-orchestrator/backups/YYYYMMDD-HHMMSS/
```

Update policy:

| Change type | Auto-apply? |
| --- | --- |
| skill text patch | Yes after validation. |
| templates | Yes after validation, do not overwrite user project files. |
| installer script | Stage only; apply on next manual update. |
| Hermes provider/model config | No. Requires explicit confirmation. |
| cron schedule | No. Requires explicit confirmation. |
| destructive cleanup | Never auto-apply. |

## 12. Verification checklist

For the implementation to count as working:

- [ ] Fresh machine can run one install command.
- [ ] `hermes profile list` shows `agent-tutor-orchestrator`.
- [ ] `agent-tutor-orchestrator` alias starts the profile.
- [ ] Tutor skill loads in a fresh session.
- [ ] Tutor can guide a fake issue through all six phases.
- [ ] Templates install to the profile template directory.
- [ ] Updater can detect “no update available”.
- [ ] Updater can stage a fake newer version and apply after validation.
- [ ] Updater backs up before applying.
- [ ] Updater never changes model/provider secrets.
- [ ] Validation passes in `agent-dev-kit`.

## 13. Validate locally

Core is already in-tree. Smoke the profile:

```bash
./scripts/tutor-preflight.sh
./scripts/tutor-smoke.sh
hermes --profile agent-tutor-orchestrator -s ai-workflow-orchestrator
```

Optional next polish: richer templates under the profile, opt-in safe updater,
and composing a private org skills overlay on the operator machine (never in
this public tree).
