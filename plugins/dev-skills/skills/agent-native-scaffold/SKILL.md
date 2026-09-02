---
name: agent-native-scaffold
description: Audit, scaffold, or refactor any software repository into the Agent-Native Repository Architecture (ANRS-1.0) with Hub-and-Spoke context, O(1) REGISTRY.yaml, and shallow directory ergonomics.
tags: [agent-native, architecture, context-engineering, scaffolding, refactor, skill]
metadata:
  openclaw:
    emoji: 🏛️
    scope: developer-tooling
    provenance: first-party
    requires:
      bins: [python3, git]
created: 2026-08-22
updated: 2026-08-31
---

# agent-native-scaffold 🏛️

Transform greenfield or legacy software repositories into high-efficiency **Agent-Native** codebases adhering to the ANRS-1.0 specification.

## When to invoke
- User says: "Make this repo Agent-Native", "Organize this codebase for AI agents", "Audit repository context bloat", "reorganiza esta carpeta", "renombra los archivos".
- Initializing a new repository or refactoring a legacy project with bloated root prompts.
- When an AI agent experiences high tool hallucination or context rot.

## When NOT to invoke
- Single-script micro-tools with fewer than 5 files.
- Modifying business logic without changing codebase architecture.
- Renaming files purely for cosmetic reasons when no `AGENTS.md` will be added — first ask whether the user wants a full ANRS conversion or just a rename.

---

## The Transformation Workflow

### Phase 0: Pre-flight — is this a Git repo?
ANRS-1.0 was designed for code repositories. Real-world "ops" folders
(freelancer billing, business records, vendor artifacts) often are **not**
Git repos and never will be. Classify the target before choosing a path:

1. **Code repo:** normal ANRS playbook (Phases 1-5, then `git worktree` per
   `AGENTS.md` global policy, branch, commit, PR).
2. **Ops / records folder (no Git):** apply the same ANRS layout, but
   skip the worktree/PR machinery. The verification checklist (Phase 5
   plus the secrets-and-archive sweep) is still mandatory because the
   folder typically holds Digital IDs, owner-only `.env` files, signed
   PDFs, and personal data. There is no commit to undo; the only safety
   net is the pre-snapshot (Phase 0b).

> Pitfall: do not assume the AGENTS.md `worktree` rule applies. That rule
> governs repos with a remote and a default branch. Ops folders that are
> just a directory tree on disk should not invent a Git history to comply
> with it. State the Git status explicitly in the rollout reply.

### Phase 0b: Pre-snapshot (non-Git targets only)
Before any rename or move:

```bash
tar -czf /tmp/<repo>-pre-scaffold-<YYYYMMDD-HHMM>.tgz -C <parent> <repo>
```

This is the only rollback mechanism when there is no Git reflog. Do not
proceed to renames without it. Confirm the archive size and a `tar -tzf`
spot-check before continuing.

### Phase 1: Audit & Discovery
Run the ANRS linter to inspect the target repository:
```bash
python3 scripts/audit-agent-native.py --repo-root <TARGET_DIR> --strict-depth --json
```
Analyze:
1. **Context Bloat:** Is root `AGENTS.md` / `CLAUDE.md` > 150 lines?
2. **Catalog Presence:** Is `REGISTRY.yaml` missing?
3. **Directory Depth:** Are there paths nested deeper than 4 levels?
   Use `--strict-depth` to surface warnings as well as hard errors.
4. **Stale inventory:** scan for `__pycache__` and `*.pyc` BEFORE the
   audit. Tools that import sibling modules (e.g. `daily_log.py`,
   `invoice_reminder.py`) leave cache directories that skew file counts
   and create `__pycache__` folders the audit was not designed to
   whitelist. Remove caches first, or the post-scaffold file-count
   receipt will be wrong by tens of items.

---

### Phase 2: Generate Declarative Catalog (`REGISTRY.yaml`)
Create `REGISTRY.yaml` at the project root by cataloging:
- **Services:** Ports, entrypoints, health check URLs.
- **MCP Servers:** Tool schemas, executable paths, required env vars.
- **Skills:** Custom capabilities and prerequisites.
- **Agents:** Dedicated operational personas.

Use [`templates/agent-native/REGISTRY.yaml.template`](../../../../templates/agent-native/REGISTRY.yaml.template) as baseline.

---

### Phase 3: Construct Hub-and-Spoke Context (`AGENTS.md`)
1. **Root `AGENTS.md` (Hub):**
   - Keep under 120 lines.
   - Encode non-negotiable invariants (Git worktree rules, SSoT for secrets/tasks).
   - Build the **Semantic Routing Table** pointing to subsystem guides.
   - Use [`templates/agent-native/AGENTS.md.template`](../../../../templates/agent-native/AGENTS.md.template).

2. **Subsystem Contexts (Spokes):**
   - Create nested `AGENTS.md` files at each subsystem root (e.g. `services/api/AGENTS.md`, `infra/AGENTS.md`).
   - Move specialized implementation rules out of the root prompt into these spoke files.
   - Use [`templates/agent-native/subsystem-AGENTS.md.template`](../../../../templates/agent-native/subsystem-AGENTS.md.template).

3. **Agent Cognition Isolation:**
   - Place agent system prompts and identities under `agents/<slug>/` or `ops/agents/<slug>/`.
   - Never mix agent behavioral prompts with shared runtime library code.

---

### Phase 4: Flatten Directory Hierarchy
If paths exceed depth 4:
- Flatten redundant wrapper folders (e.g., `src/modules/core/v1/...` → `core/...`).
- If in a live production environment, create relative symlinks (`ln -s`) to maintain backward compatibility during transition.

**When the user explicitly asked to "organize all the file and folder names",** treat the renaming as a class of work with its own pitfalls:

1. **Convert numeric prefixes to semantic names.** `00-branding`,
   `01-compensation-framework`, `02-contratos` → `branding`, `compensation`,
   `contracts`. The order is preserved by `ls` (or by `REGISTRY.yaml`
   ordering if alphabetical is wrong).
2. **Preserve human-meaningful identifiers.** Document IDs like
   `KAP-003`, `KAP-013`, and contract IDs like `SOW-02` must round-trip
   unchanged — they are referenced externally. Define an explicit regex
   allow-list for these before the rename pass.
3. **Use the canonical client-facing name for shared artifacts.** Invoices
   or documents that leave the repo (e.g. weekly billing PDFs) should
   follow the user-facing format the recipient expects, not a kebab-case
   internal slug. Example: `Invoice - Luis Felipe Tejada Padilla - 2026-08-24 - 2026-08-30.pdf`.
4. **Legacy artifacts get a `legacy-` prefix**, not deletion. Past
   invoices or contracts that already went out the door should be
   kept under `archive/` with a `legacy-` prefix that names the original
   recipient and period.
5. **Scripts and machine-readable logs keep their dot-notation.** Worklog
   files like `worklog-YYYY-MM-DD.txt` and plan files like
   `plan-YYYY-MM-DD.md` are parsed by daily tooling; do not convert their
   dates to ISO ordering or different separators.

### Phase 5: Verification & Gate
Execute the audit script to ensure compliance:
```bash
python3 scripts/audit-agent-native.py --repo-root <TARGET_DIR> --strict-depth --json
```
Output receipt must confirm:
- `Root AGENTS.md: Budget and Routing Table OK`
- `REGISTRY.yaml: Present and Formatted`

For **ops / records folders**, extend the verification sweep with a
secrets-and-archive checklist. Each item is a real command — never a
hand-wave — and the agent must report its exit code:

1. **Audit clean:** `audit-agent-native.py` → `status: PASS`, `hard_error_count: 0`.
2. **YAML valid:** `python -c 'import yaml; yaml.safe_load(open("REGISTRY.yaml"))'`
   (or `uv run --with pyyaml --python 3.14 python -c ...` on PEP-668 hosts).
3. **Python parses:** `compile(open(p).read(), p, "exec")` for every
   `.py` file (skipping `__pycache__`).
4. **Bash parses:** `bash -n` for every `.sh` file.
5. **Hub link integrity:** extract every Markdown link target
   `[text](<target>)` and `Path.resolve()` it; report any miss.
6. **Stale-path sweep:** grep every non-binary file for old path
   patterns (e.g. `/home/user/kommit/empresa|~/kommit/empresa`) and
   confirm the old directory no longer exists.
7. **Permission check on secrets:** `stat -c %a` on `.env`, `.p12`, and
   the Digital ID file — must be `600`. Flag any `644` or `755` for a
   human-visible artifact.
8. **Signed-PDF integrity:** for any final/shared PDF, run `pdfsig` and
   require `Signature Validation: Signature is Valid.` and
   `Total document signed`. Reject the rollout if either is missing.
9. **External-side-effect test:** any script that fires email, webhook,
   or push must NOT be invoked during the scaffold. State "no email
   sent" / "no PR opened" explicitly in the final reply.
10. **Caches removed:** `find <repo> -name __pycache__ -o -name '*.pyc'`
    returns nothing.
11. **Local validator (preferred for ops folders).** When the target is an
    ops/records folder with a Python script tree, pair the external ANRS
    audit with a small repo-local validator that checks folder-specific
    invariants the generic audit does not know about: file mode on
    `Digital ID` and `.env` files (must be `0o600`), state dir mode
    (must be `0o700`), month-partition layout under `invoices/`, signed
    PDF integrity, and the absence of legacy directory names. Ship the
    validator as `scripts/validate_ops.py` (or repo-equivalent) and run
    it on every refactor. Two-line `--json` output makes it cheap to
    diff against the previous PASS. See
    `references/ops-folder-validator.md` for the verified recipe.
12. **TDD the portable-root claim.** For any ops script that derives
    its location from `__file__`/`BASH_SOURCE`, write a test that runs
    the script with `KOMMIT_OPS_ROOT=<tempdir>/relocated-ops` and
    asserts the script wrote to the relocated root, not the real one.
    Verified 2026-08-31: this catches the silent "first-run-with-no-env
    defaults to real path" regression that the lint-only checks miss.

> Pitfall: do not run a final round of `python3 <script>.py` against the
> production `.env` just to "prove the path works". The script's
> existence and correct path constants are sufficient evidence; the
> idempotent `compile()` check covers the syntax half.

---

## Common pitfalls

- **"Organize" ≠ "rename".** Ask before you convert a numbered prefix to
  a semantic name. Once `00-branding` becomes `branding`, every link in
  every Markdown file and every reference in `.env`, `REGISTRY.yaml`,
  and skills must be updated. The cost is acceptable for ANRS; it is
  NOT acceptable if the user only wanted a cosmetic tidy.
- **Cache artifacts masquerade as project files.** `daily_log.py`
  imports a sibling helper, Python writes `__pycache__/`, and the audit
  reports 4 phantom directories plus 4 phantom `.pyc` files. Remove
  them between runs.
- **`audit-agent-native.py` default omits depth warnings.** Add
  `--strict-depth` to surface paths that are exactly at the limit
  before they become violations after the next rename.
- **Skill-sync drift.** Patches to a skill in
  `~/.hermes/profiles/<p>/skills/` may not be picked up if the
  canonical source lives in another repo (e.g. `agent-dev-kit`'s
  `plugins/dev-skills/skills/`). Patch the canonical source, not the
  sync shadow, unless the skill is curator-managed locally.

## Files in this skill

- `references/ops-folder-validator.md` — verified recipe for the
  repo-local `validate_ops.py` script that pairs with the external ANRS
  audit when scaffolding a non-Git ops/records folder. Use this whenever
  the target holds secrets, signed PDFs, runtime state, or any
  folder-specific invariant the generic audit does not know about.
