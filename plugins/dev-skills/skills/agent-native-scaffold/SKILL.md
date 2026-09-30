---
name: agent-native-scaffold
description: Audit, scaffold, or refactor any software repository into the Agent-Native Repository Architecture (ANRS-1.0) with Hub-and-Spoke context, O(1) REGISTRY.yaml, and shallow directory ergonomics.
---

# agent-native-scaffold

Turn a repository or workspace folder into an ANRS-1.0 layout. The spec is in `docs/agent-native-architecture.md`.

## When to invoke
- "Make this repo Agent-Native", "Organize this codebase for AI agents", "Audit repository context bloat", "reorganiza esta carpeta", "renombra los archivos".
- A new repository, or a legacy project with a bloated root prompt.
- A workspace or project folder (client, research, ops): also use the [Workspace profile](#workspace-profile-optional-overlay).

## When NOT to invoke
- Single-script tools with fewer than 5 files.
- Business-logic changes that do not touch the codebase layout.
- Cosmetic renames when no `AGENTS.md` will be added. Ask first: full ANRS conversion or only a rename?

---

## The Transformation Workflow

### Phase 0: Pre-flight
Check whether the target is a Git repo.

1. **Code repo:** follow Phases 1-5. Then use a worktree, branch, commit, and PR as the repo's `AGENTS.md` says.
2. **Folder without Git (ops, records, billing):** follow the same layout. Skip the worktree and PR steps. State the Git status in the final reply.
   Before any rename or move, take a snapshot. It is the only rollback:
   ```bash
   tar -czf /tmp/<repo>-pre-scaffold-<YYYYMMDD-HHMM>.tgz -C <parent> <repo>
   ```
   Check the archive size and run `tar -tzf` as a spot-check first.

For a workspace folder, also apply the [Workspace profile](#workspace-profile-optional-overlay) after Phase 3.

### Phase 1: Audit
Remove `__pycache__` and `*.pyc` first. They add phantom files to the audit counts. Then run:
```bash
python3 ~/programming/agent-dev-kit/scripts/audit-agent-native.py --repo-root <TARGET_DIR> --strict-depth --json
```
The audit checks the hub size (150 lines max), the routing-table links, `REGISTRY.yaml`, and directory depth (4 max).
`--strict-depth` turns depth warnings into failures.

### Phase 2: Catalog (`REGISTRY.yaml`)
Create `REGISTRY.yaml` at the root from [`templates/agent-native/REGISTRY.yaml.template`](../../../../templates/agent-native/REGISTRY.yaml.template).
List services (ports, entrypoints, health URLs), MCP servers, skills, and agents.

### Phase 3: Hub and Spokes (`AGENTS.md`)
1. **Root `AGENTS.md` (hub):** 150 lines max. List the invariants (worktree rules, sources of truth for secrets and tasks) and the **Semantic Routing Table**.
   Use [`AGENTS.md.template`](../../../../templates/agent-native/AGENTS.md.template).
2. **Subsystem `AGENTS.md` files (spokes):** one per subsystem root (for example `services/api/`, `infra/`).
   Move specialized rules out of the hub. Use [`subsystem-AGENTS.md.template`](../../../../templates/agent-native/subsystem-AGENTS.md.template).
3. **Agent cognition:** keep agent prompts and identities under `agents/<slug>/` or `ops/agents/<slug>/`. Do not mix them with runtime code.

### Phase 4: Flatten
If paths are deeper than 4 levels:
- Flatten wrapper folders (`src/modules/core/v1/...` becomes `core/...`).
- In a live production environment, add relative symlinks (`ln -s`) for backward compatibility.

Rename rules, only when the user asked to "organize the file and folder names":
- Ask before you replace numeric prefixes (`00-branding` becomes `branding`). Then update every link in Markdown, `.env`, `REGISTRY.yaml`, and skills.
- Keep IDs that other systems reference (for example `KAP-003`, `SOW-02`). Write a regex allow-list before the rename.
- Keep the names that recipients expect on shared files (for example invoice PDFs). Keep the date format of parsed logs (`worklog-YYYY-MM-DD.txt`).
- Move old artifacts to `archive/` with a `legacy-` prefix. Do not delete them.

### Phase 5: Verification
Run the Phase 1 command again. Report `status: PASS` and `hard_error_count: 0`.

For ops or records folders, also run these checks and report the result of each:
1. `stat -c %a` on `.env`, `.p12`, and Digital ID files. The mode must be `600`.
2. Do not run scripts that send email, call webhooks, or push. Do not run scripts against the production `.env`. State "no email sent" or "no PR opened".

---

## Workspace profile (optional overlay)

Use this profile for workspace or project folders (client, research, ops). It adds to ANRS-1.0. It does not replace the hub, spokes, or `REGISTRY.yaml`.
Do not use it for code repos. Start with the foundation. Add structure only when complexity earns it.

### Layout

```text
<workspace>/
├── AGENTS.md          # Rules for every agent (hub)
├── REGISTRY.yaml      # Machine catalog
├── PROJECT.md         # Goal, scope, definition of done
├── STATUS.md          # Current state and next steps
├── DECISIONS.md       # Important choices, kept for later
├── inbox/             # New things land here first
├── areas/<area>/      # Natural sections of the project
├── work/
│   ├── queued/<slug>/     # brief.md, notes.md, handoffs/
│   ├── active/<slug>/
│   └── completed/<slug>/
├── resources/         # Files, references, assets, data
├── outputs/           # Finished or review-ready work
└── archive/           # Old or replaced material
```

Templates: [`PROJECT.md`](../../../../templates/agent-native/PROJECT.md.template),
[`STATUS.md`](../../../../templates/agent-native/STATUS.md.template),
[`DECISIONS.md`](../../../../templates/agent-native/DECISIONS.md.template).
Use the hub template for `AGENTS.md`. Add the three root files to its routing table.

Mapping to ANRS: `areas/<area>/AGENTS.md` is a spoke. Create it only when the area has rules the hub does not state.
`REGISTRY.yaml` lists machine items only, not work items. `STATUS.md` replaces `WORKING-STATE.md`. `DECISIONS.md` is the project log, not the agent authority matrix (that stays in `agents/<slug>/`).

### Lifecycle rules

1. **Enter.** Every new thing (request, file, idea, transcript) goes to `inbox/` first.
   Name it `<YYYY-MM-DD>-<short-name>`. Do not put it in `areas/` or `work/` directly.
2. **Triage.** At session start, empty `inbox/`. Send each item to exactly one place:
   - Work to do: `work/queued/<slug>/`. Write `brief.md` (goal, done criteria, inputs).
   - Reference material: `resources/`, or `areas/<area>/` if one area owns it.
   - A choice already made: `DECISIONS.md`.
   - Not needed: `archive/`. Agents do not delete.
3. **Start.** Move `work/queued/<slug>/` to `work/active/<slug>/` when work begins.
   Move the whole folder. `brief.md` must state the done criteria first. List the item in `STATUS.md`.
4. **Finish.** Move the folder to `work/completed/<slug>/` when every done criterion is met.
   Record the evidence in `notes.md`. Put finished or review-ready files in `outputs/`.
   Link them from `notes.md`.
5. **Archive.** Move `work/completed/<slug>/` to `archive/<slug>/` when the output is
   accepted and no follow-up is open. Move replaced material from `resources/` or `outputs/` the same way.
   Do not edit archived material.
6. **Hand off.** Write handoffs inside the item: `work/<stage>/<slug>/handoffs/<YYYY-MM-DD>-<topic>.md`.
   State what is done, what is next, and what is open. The handoffs move with the folder.
   Do not keep a global handoffs folder.
7. **Status.** Rewrite `STATUS.md` in place at the end of every session. Do not append history.
   Mark a blocked item in `STATUS.md` and `brief.md`. There is no `blocked/` stage.
8. **Decide.** Add an entry to `DECISIONS.md` when a choice is hard to reverse, changes scope
   or the definition of done, changes a rule in `AGENTS.md`, or someone will ask "why" later.
   Append entries. Supersede an old entry with a new one. Put routine task facts in `notes.md`.

The audit detects this profile when at least two of `PROJECT.md`, `STATUS.md`, `inbox/`, `areas/`, `work/` exist.
Use `--profile workspace` to force it on and `--profile none` to force it off. It only warns about missing items.
