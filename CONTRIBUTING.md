# Contributing

Small, curated, public-safe. Before opening a PR, read
[`AGENTS.md`](AGENTS.md) (how agents use this repo), [`CURATION.md`](CURATION.md)
(what gets in and why), and [`ATTRIBUTION.md`](ATTRIBUTION.md) (what is borrowed).

## Adding or changing a skill

1. Add `plugins/dev-skills/skills/<name>/SKILL.md` with `name` + `description`
   frontmatter (kebab-case name, `description` states what it does and when to
   use it).
2. Keep it dependency-free, or list dependencies and install per host — see
   `docs/external-deps.md`.
3. **Scrub before commit:** no absolute paths, host IPs, account IDs, internal
   system names, client names, or vendored `node_modules`. Private context
   belongs in overlays outside this repo (`docs/private-overlays.md`).
4. Bump plugin versions with `package.json` (keep
   `plugins/dev-skills/.claude-plugin/plugin.json` and
   `plugins/dev-skills/.codex-plugin/plugin.json` aligned).
5. Add a `skill-provenance.json` entry (source · license · risk).
6. Run `npm run validate` — it must pass.

## Adding a diagram

- Editorial diagrams use the **diagram-design** skill: the self-contained
  `docs/diagrams/<name>.html` is the source of truth; commit the exported
  `.svg` and `.png` alongside it.
- D2 / Mermaid sources rebuild via `npm run render:diagrams`.
- Update the table in `docs/README.md` (Diagrams section) when you add one.

## Keeping the repo honest

- Never reintroduce employer/client names, private paths, or employer-named
  defaults into tracked files — re-run the coupling scan before major public
  updates (`docs/going-public.md`).
- `evals/` numbers and caveats must stay accurate; update
  `evals/PROTOCOL.md` when you score a new run.

## Merge discipline

- CI runs `npm run validate` plus shell syntax/shellcheck on every push and PR.
- Third-party skills must stay **untracked** and be restored from
  `skills-lock.json` — a tracked `.agents/skills` tree fails the gate.
