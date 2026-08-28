# Profiles & multi-runtime layout

How to run one set of skills across Hermes, Codex, Claude, Pi, and other runtimes without
copying files around by hand.

## The idea

One **registry** (a git repo of skill folders, grouped into categories) is the
single source of truth. Each runtime or profile gets the subset it needs via
**symlinks**, declared in a per-profile manifest (`profiles/*.yml` for shipped
profiles, `manifests/*.yml` for examples or local experiments).

```
registry (git)                 runtime config
─────────────                  ──────────────
dev-skills/git-essentials  ──▶ ~/.claude/skills/git-essentials   (symlink)
dev-skills/pdf             ──▶ ~/.claude/skills/pdf              (symlink)
dev-skills/knip            ──▶ ~/.agents/skills/knip             (Codex global)
personal/my-thing          ──▶ ~/.claude/skills/my-thing         (symlink)
```

Edit a skill once in the registry; every runtime sees it. Commit + push to
sync across machines; `git pull` + re-link on the other host.

## Multiple Claude profiles

If you run several Claude accounts/configs (e.g. `~/.claude`, `~/.claude-work`),
point the secondary ones at the primary so they share everything:

```bash
ln -s ~/.claude/skills  ~/.claude-work/skills
ln -s ~/.claude/plugins ~/.claude-work/plugins
ln -s ~/.claude/agents  ~/.claude-work/agents
```

Then only `~/.claude` links into the registry. `jean-claude` (npm) automates
this profile setup if you'd rather not do it by hand.

## Orchestration Profiles

[`agent-tutor-orchestrator.yml`](../profiles/agent-tutor-orchestrator.yml) defines
the strict orchestrator and liaison configuration, deploying `orchestrate`,
`herdr`, and `tmux-delegation` across multiple harnesses.

See [`agent-tutor-orchestrator.md`](agent-tutor-orchestrator.md) for installation,
runtime commands, and orchestration policies.

## What NOT to link this way

- **External plugins** (caveman, ponytail, this kit's marketplace) — Claude
  manages them through `/plugin`; Codex receives their pinned upstream skill
  packs through `scripts/install-codex-workhorse.sh`. Do not vendor either
  project here, and don't symlink them into `skills/`.
- **GSD** — use `get-shit-done-cc` for the authoritative Hermes pack; `pi-gsd`
  is only the optional Pi-native helper. Don't mirror GSD into the shared
  Claude/Codex registry because that fights the runtime installers. The
  Personal Dev Tutor installer intentionally links only six core GSD skills
  from the Hermes installation into its isolated profile.

See [`external-deps.md`](external-deps.md).

## Profile contract

Every shipped profile declares:

- `profile`
- `runtime`
- `target`
- `sandbox_policy`
- `include_skills`
- `capabilities`
- `limits`

Sandbox policies live in [`../policies/sandbox-policies.json`](../policies/sandbox-policies.json).
They are contracts for agents and wrappers; private production policies belong
in a private overlay.
