# Adding a new skill — workflow

> Step-by-step guide for adding a skill to this kit in all 4 agent formats. From a 5-minute skill to a 30-minute one.

## Decision tree

When the user says "I keep doing X — make a skill for it":

1. **Is X already covered by a skill in `skills/`?** If yes, update the existing skill; don't add a new one.
2. **Does X need per-agent differences?** (e.g., OpenCode's `tools:` map, Claude's `metadata.openclaw.emoji`) If yes, you need 2 files; otherwise 1.
3. **Does X have lots of supporting data?** (e.g., host lists, command cheatsheets) If yes, use a `references/` subdir.

## The 7 steps

### 1. Pick a name

- Lowercase, hyphenated, max 30 chars.
- Describe the *intent*, not the *implementation*. `overnight-task` not `shutdown-script-runner`.
- Check `skills/` to make sure the name isn't taken.

### 2. Create the directory

```bash
mkdir -p skills/<name>/references
```

### 3. Write the canonical SKILL.md (Claude/Codex/Pi)

```bash
touch skills/<name>/SKILL.md
```

Use the Claude format (see `agent-formats.md`):

```markdown
---
name: <name>
tags: [<intents>]
description: |
  <one-paragraph "Use when..." text>
metadata:
  openclaw:
    emoji: <appropriate>
    side_effect: <what changes>
    invocation: <auto | on-intent-match | manual>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# <Skill Name>

<one-line description>

## When to invoke
- <trigger 1>
- <trigger 2>

## When NOT to invoke
- <anti-trigger 1>

## Process
<numbered steps>

## Guardrails
- <safety rule 1>
- <safety rule 2>

## Output contract
<what the agent should produce>
```

Keep `SKILL.md` under 6KB. Put large content in `references/`.

### 4. Write the OpenCode command variant

```bash
touch skills/<name>/<name>.opencode.md
```

Use the OpenCode format (see `agent-formats.md`):

```markdown
---
description: |
  <same as Claude's description>
argument-hint: "[<args>]"
argument-instructions: |
  <how to parse $ARGUMENTS, or "no arguments">
tools:
  read: true
  write: true
  edit: true
  bash: true
  glob: true
  grep: true
  agent: true
  question: <true|false>   # set false for overnight/autonomous skills
---

<objective>
<what this command does>
</objective>

<context>
$ARGUMENTS (optional)
</context>

<process>
<numbered steps, or "@<path-to-SKILL.md>" for delegation>
</process>
```

The body of the OpenCode command is usually a **directive** to the agent (read the canonical SKILL.md and follow its process) rather than a copy of the same content. This avoids drift.

### 5. Add reference files (optional)

If the skill has supporting data (host lists, command cheatsheets, etc.), put it in `skills/<name>/references/`:

```bash
touch skills/<name>/references/<topic>.md
```

Reference from `SKILL.md`:

```markdown
See `references/<topic>.md` for the full list.
```

### 6. Update `install.sh`

If you used the same filename for Claude/Codex/Pi (just different symlink targets), the existing install.sh already handles it. If you added a custom opencode variant, append:

```bash
ln -sf "$KIT/skills/<name>/<name>.opencode.md" "$HOME/.config/opencode/command/<name>.md"
```

### 7. Test the install

```bash
./install.sh

# Verify symlinks
readlink -f ~/.claude/skills/<name>
readlink -f ~/.codex/skills/<name>
readlink -f ~/.pi/skills/<name>
readlink -f ~/.config/opencode/command/<name>.md
```

All four should resolve to files under `~/programming/agent-dev-kit/overnight-task-kit/skills/<name>/`.

## Tips

- **Keep the canonical SKILL.md the source of truth.** OpenCode's command file is a thin wrapper. Don't duplicate content.
- **Use shared `references/` files** when the same supporting data is needed by multiple skills.
- **Test the symlink before declaring done.** A stale symlink looks fine until the agent tries to read it.
- **Update `docs/why-this-exists.md` if the new skill represents a new pattern.** The kit is documentation-as-museum: every skill is an artifact of a real recurring need.
- **Don't over-formalize.** A 50-line skill that solves a real problem is better than a 500-line skill that's mostly aspirational.

## See also

- `agent-formats.md` — per-agent frontmatter/structure cheatsheet
- `../skills/overnight-task/SKILL.md` — the first skill, exemplifying the pattern
- `../install.sh` — the installer
