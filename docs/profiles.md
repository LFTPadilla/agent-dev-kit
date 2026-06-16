# Profiles & multi-runtime layout

How to run one set of skills across several Claude profiles / runtimes without
copying files around by hand.

## The idea

One **registry** (a git repo of skill folders, grouped into categories) is the
single source of truth. Each runtime or profile gets the subset it needs via
**symlinks**, declared in a per-profile manifest (`manifests/*.yml`).

```
registry (git)                 runtime config
─────────────                  ──────────────
dev-skills/git-essentials  ──▶ ~/.claude/skills/git-essentials   (symlink)
dev-skills/pdf             ──▶ ~/.claude/skills/pdf              (symlink)
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

## What NOT to link this way

- **Plugins** (caveman, ponytail, this kit's marketplace) — installed via
  `/plugin`, managed by Claude. Don't symlink them into `skills/`.
- **GSD** — installs per-runtime via `pi-gsd`; it has its own `/gsd:update
  --sync` to align runtimes. Don't symlink GSD into the registry — it fights
  the installer.

See [`external-deps.md`](external-deps.md).
