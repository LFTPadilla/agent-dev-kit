# Hermes Workflow Tutor — product and implementation design

Status: proposal for an open-source, installable Hermes profile/agent.

## 1. Goal

### 1.1 Role: pure orchestrator

The Hermes Workflow Tutor is **not an implementer**. It does not edit code, run
tests, commit, push, or open PRs. Its value is in:

- **holding the picture** — knowing what every subagent is doing right now
- **decomposing** work into lanes
- **routing** every concrete task to a subagent (tmux delegation to a Claude Code
  TUI in the `komp` session, or a kanban card for restart-safe work)
- **monitoring** — `tmux capture-pane`, kanban tails, status reads
- **verifying by audit** — disk-level diff and contract check, never "I read the
  agent's summary and it sounded good"

The user can monitor each Claude Code TUI pane in tmux directly. The tutor's job
is to keep their mental model accurate and ensure no lane is silently dropped.

### 1.2 Lifecycle

Build a Hermes profile that acts as a proactive AI development orchestrator and process coach.

The tutor should guide a developer through the full development lifecycle:

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

The deliverable should be an installable, self-updating Hermes profile made of:

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

- tmux delegation (load-buffer + paste-buffer + Enter to a Claude TUI in `komp:*`)
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

### 2.2 Subagents live in the `komp` tmux session

The orchestrator delegates to **Claude Code TUIs attached to tmux windows in a
named session** (default `komp`). Each window is an independent worker:

- `komp:<n>` is a window index inside the `komp` tmux session
- the pane in that window runs `claude --dangerously-skip-permissions`
- the user can `tmux attach -t komp` and watch live
- the orchestrator sends prompts via the tmux-safe three-step
  (load-buffer + paste-buffer + sleep + send-keys Enter)
- the orchestrator watches for spinner verbs and completion
- the orchestrator audits the diff on disk before reporting back

Branch-per-delegate is the default: each lane gets its own worktree, its own
tmux window, and its own branch. Merges happen later via a synthesis lane.

For multi-step, restart-safe work, the orchestrator uses **Hermes Kanban**
instead of tmux delegation. Kanban cards survive Hermes restarts, can run in
parallel, and keep a permanent audit trail.

### 2.3 Public core, organization overlay, project overlay

The open-source tutor should include generic reusable machinery:

- workflow phases
- safety policies
- prompts
- skill definitions
- installation scripts
- templates
- update mechanism

Company/client-specific details belong in a private organization overlay:

- internal repo names
- staging/prod URLs
- GitHub org policies
- QA ownership rules
- customer data constraints
- approved model/provider policy
- internal examples

Repository-specific details belong in the repository itself:

- repo `CLAUDE.md` / `AGENTS.md`
- repo-local skills
- repo-local agents
- repo-local hooks
- repo-specific test/build/deploy commands
- repo-specific domain vocabulary and architecture notes

The intended layering is:

| Layer | Location | Contents | Update owner |
| --- | --- | --- | --- |
| Public workflow tutor | open-source repo | generic phases, safety rules, installer, updater, templates | public maintainers |
| Organization overlay | private skills/overlay repo | company policies, approved tools/models, QA evidence rules, internal examples | organization |
| Project overlay | each project repo | project instructions, project skills/agents/hooks, commands, domain context | project team |

This separation prevents context bleed: the public tutor teaches the method, the organization overlay adds company policy, and the project overlay adds only the local facts needed for that repository.

### 2.3 One command to install

Target user experience:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/agent-dev-kit/main/install-hermes-workflow-tutor.sh | bash
```

or, if bundled into the existing agent-dev-kit CLI:

```bash
npx agent-dev-kit tutor install
```

Expected result:

- Hermes is installed or verified.
- A Hermes profile is created: `hermes-tutor`.
- Required toolsets are enabled.
- Tutor skills are installed or symlinked.
- Templates are copied into an accessible directory.
- Optional updater cron is configured.
- A launch alias is created, e.g. `hermes-tutor`.

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

## 3. Proposed repository layout

If implemented inside `agent-dev-kit`, add:

```text
agent-dev-kit/
├── docs/
│   └── hermes-workflow-tutor.md
├── profiles/
│   └── hermes-tutor.yml
├── plugins/dev-skills/skills/
│   ├── ai-workflow-orchestrator/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── phase-checklists.md
│   │   │   ├── risk-matrix.md
│   │   │   └── prompt-security.md
│   │   └── templates/
│   │       ├── CLAUDE.md
│   │       ├── issue-template.md
│   │       ├── pull-request-template.md
│   │       └── qa-evidence-comment.md
│   └── ai-review-contract/
│       └── SKILL.md
├── scripts/
│   ├── install-hermes-workflow-tutor.mjs
│   └── update-hermes-workflow-tutor.mjs
└── install-hermes-workflow-tutor.sh
```

Alternative: create a separate public repo, e.g. `hermes-workflow-tutor`, and let `agent-dev-kit` reference it as an optional package.

I would start inside `agent-dev-kit` while iterating, then split later if it grows into its own product.

## 4. Hermes profile contract

Profile name:

```text
hermes-tutor
```

Launch commands:

```bash
hermes --profile hermes-tutor
hermes-tutor
```

Suggested profile config:

```yaml
profile: hermes-tutor
runtime: hermes
target: ~/.hermes/profiles/hermes-tutor/skills
sandbox_policy: workspace-write
include_skills:
  - ai-workflow-orchestrator
  - semgrep
  - security-checklist
  - live-qa
  - playwright-stability
  - git-essentials
  - improve
capabilities:
  - process-coaching
  - code-review
  - prompt-security
  - repo-readiness
  - browser-qa
  - docs-generation
limits:
  production: explicit-only
  secrets: never-read-or-print
  git_push: explicit-only
  destructive_ops: explicit-only
notes:
  - Proactive workflow coach for issue-to-QA AI-assisted development.
  - Uses public generic workflow rules; private company overlays are installed separately.
```

## 5. Skill design

### 5.1 Main skill: `ai-workflow-orchestrator`

Trigger description:

```yaml
name: ai-workflow-orchestrator
description: Use when guiding a developer through an AI-assisted software development workflow as a pure orchestrator. Holds the picture, decomposes work into lanes, and delegates every concrete task to a Claude Code subagent attached to a tmux window in a named session (default `komp`) or to a Hermes Kanban card. Does not edit, test, build, commit, or push itself. Trusts but verifies via disk-level audit.
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

Example private overlay:

```text
kommit-workflow-overlay
```

Contains:

- Kommit-specific QA evidence rules
- internal repo examples
- Macroscope/CodeRabbit policy
- staging handoff details
- team-specific GitHub templates
- approved model/provider policy

This should not live in the public repo.

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
hermes profile create hermes-tutor --clone-all
hermes profile alias hermes-tutor hermes-tutor
```

If cloning all existing configuration is too broad, use:

```bash
hermes profile create hermes-tutor
hermes profile alias hermes-tutor hermes-tutor
```

Then configure minimal safety settings:

```bash
hermes --profile hermes-tutor tools enable file
hermes --profile hermes-tutor tools enable terminal
hermes --profile hermes-tutor tools enable skills
hermes --profile hermes-tutor tools enable todo
hermes --profile hermes-tutor tools enable session_search
hermes --profile hermes-tutor tools enable cronjob
```

Exact tool commands should be verified against the current Hermes CLI before implementation; Hermes supports `hermes tools enable NAME`, but profile flag placement should be tested in the installer.

### 6.3 Install skills

Options:

1. install via Hermes skills hub if published
2. install from direct raw `SKILL.md` URLs
3. symlink from local checkout during development

For public distribution, prefer direct URL or skill hub:

```bash
hermes --profile hermes-tutor skills install https://raw.githubusercontent.com/<org>/<repo>/main/plugins/dev-skills/skills/ai-workflow-orchestrator/SKILL.md
```

### 6.4 Install templates

Copy templates to:

```text
~/.hermes/profiles/hermes-tutor/templates/ai-workflow/
```

Also print instructions for copying templates into a project:

```bash
cp ~/.hermes/profiles/hermes-tutor/templates/ai-workflow/CLAUDE.md ./CLAUDE.md
cp ~/.hermes/profiles/hermes-tutor/templates/ai-workflow/pull-request-template.md ./.github/pull_request_template.md
```

### 6.5 Configure updater

The installer should offer:

```text
Enable safe daily updater for the tutor profile? [Y/n]
```

Implementation options:

1. Hermes cron job
2. systemd user timer
3. simple `hermes-tutor update` command only

Recommended default: Hermes cron, because it is native and cross-platform within Hermes environments.

Cron prompt should be self-contained:

```text
Check for updates to Hermes Workflow Tutor from <repo>. If a newer version exists, download to staging, run validation, backup current tutor profile/skills/templates, apply only if validation passes, and write a concise update report. Do not change model/provider credentials. Do not mutate user projects. If validation fails, leave current version untouched and report the blocker.
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

In Hermes, this can start as conversational state + todo list. Later, it can become a small local state file under `.agent-runs/hermes-tutor/`.

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

## 9. MVP scope

Build the MVP in this order:

1. Main `ai-workflow-orchestrator` skill.
2. Templates: `CLAUDE.md`, issue, PR, QA evidence.
3. `profiles/hermes-tutor.yml` manifest.
4. Installer script that creates Hermes profile and installs skill/templates.
5. Manual update command.
6. Safe auto-updater.
7. Private overlay support.
8. Optional dashboard/status command.

## 10. Non-goals for MVP

Do not start with:

- full custom Hermes plugin
- complex UI
- automatic code mutation across repos
- company-specific policy baked into public repo
- fully autonomous production operations
- installing paid third-party tools without explicit confirmation

A profile + skills + templates + installer is enough for v1.

## 11. Update strategy

Version every release:

```text
hermes-tutor.version = 0.1.0
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
~/.hermes/profiles/hermes-tutor/backups/YYYYMMDD-HHMMSS/
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
- [ ] `hermes profile list` shows `hermes-tutor`.
- [ ] `hermes-tutor` alias starts the profile.
- [ ] Tutor skill loads in a fresh session.
- [ ] Tutor can guide a fake issue through all six phases.
- [ ] Templates install to the profile template directory.
- [ ] Updater can detect “no update available”.
- [ ] Updater can stage a fake newer version and apply after validation.
- [ ] Updater backs up before applying.
- [ ] Updater never changes model/provider secrets.
- [ ] Validation passes in `agent-dev-kit`.

## 13. Suggested next implementation step

Start with the smallest useful vertical slice:

1. Add `ai-workflow-orchestrator/SKILL.md`.
2. Add templates under that skill.
3. Add `profiles/hermes-tutor.yml`.
4. Add an installer that only supports local checkout installation.
5. Validate by launching:

```bash
hermes --profile hermes-tutor -s ai-workflow-orchestrator
```

Once that works locally, add the public one-command remote installer and safe updater.
