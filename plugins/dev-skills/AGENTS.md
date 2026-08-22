# AGENTS.md — Dev-Skills Plugin Subsystem Context

> **Progressive Disclosure Context.** Loaded when creating, editing, or auditing skills in `plugins/dev-skills/`.

---

## 1. Subsystem Scope & Invariants

This subsystem contains discrete agent capabilities formatted as standard skills (`SKILL.md`).

1. **Hard Invariants:**
   - **No Private Data Leaks:** Never commit employer or client names, private repo paths, internal ticket IDs, credentials, or personal emails.
   - **Frontmatter Validity:** Every skill must have a valid YAML frontmatter with `name` and `description`.
   - **Provenance Tracking:** Every new skill or change must be reflected in `skill-provenance.json` and `docs/skills-catalog.md`.
   - **Version Alignment:** Keep `package.json`, `.claude-plugin/plugin.json`, and `.codex-plugin/plugin.json` aligned.

2. **Skill Structure:**
   ```text
   plugins/dev-skills/skills/<skill-name>/
   ├── SKILL.md                 # Core instructions & frontmatter (mandatory)
   ├── scripts/                 # Optional helper scripts (deterministic logic)
   └── references/              # Optional extended documentation & guides
   ```

---

## 2. Adding or Modifying Skills

1. Create `plugins/dev-skills/skills/<name>/SKILL.md`.
2. Add metadata to `skill-provenance.json` (source, license, risk tier).
3. Add entry to `docs/skills-catalog.md`.
4. Run validation: `npm run validate`.

---

## 3. Subsystem Verification

```bash
# Validate skill frontmatters, provenance, and plugin manifests
node scripts/agent-dev-kit.mjs validate

# Run skill inventory
node scripts/agent-dev-kit.mjs inventory
```
