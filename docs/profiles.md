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

## Flagship Hermes + Codex profile

[`personal-dev-tutor.yml`](../profiles/personal-dev-tutor.yml) is the flagship
profile contract. Its installer links 19 capabilities into the blank Hermes
profile (excluding alternate orchestrators and dynamic discovery), installs a
filtered implementation/review set into a profile-owned isolated Codex home,
and links the six public GSD core workflow skills from `~/.hermes/skills/gsd`.
Workers started with `personal-tutor-codex` run in tmux session `personal` by
default. It also installs the pinned Graphify skill for both runtimes, links
Graphify into the isolated Hermes profile, and configures Context7 for current
library-documentation retrieval. GSD remains the only lifecycle authority.

See [`personal-dev-tutor.md`](personal-dev-tutor.md) for installation, runtime
commands, cognitive-debt checkpoints, and Mermaid/D2 diagram policy.

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
