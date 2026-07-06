# Per-agent skill/command format reference

> Quick reference for the 4 agents this kit targets. All 4 use Markdown with YAML frontmatter, but the frontmatter schema and file location differ.

## Common shape

Every agent's skill/command is a single Markdown file with:

```markdown
---
<frontmatter keys per agent>
---

<body in Markdown>
```

The body should be **agent-agnostic prose** wherever possible (the frontmatter is the only thing that changes per agent).

## Claude (`~/.claude/skills/<name>/SKILL.md`)

Standard frontmatter + body. Source-of-truth examples: `/home/felipe/vault/Resources/AI/Skills/shared/caveman/SKILL.md`, `agent-constraints/SKILL.md`, `acp-triage/SKILL.md`.

```markdown
---
name: <skill-name>
tags: [<list>]
description: |
  <one-paragraph "Use when..." text>
metadata:
  openclaw:
    emoji: <emoji>
    side_effect: <what the skill changes>
    invocation: <when it fires>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# <Skill Name>

<body>
```

Notes:
- `description` is what the agent reads when deciding to invoke the skill. Be specific ("Use when X") not generic.
- Runtime-specific metadata should stay generic in this public kit. Put proprietary runtime hints in a private overlay.
- `tags` is for grep-ability, not agent-decision.
- Body should be lean — extract large content to `references/` siblings.

## Codex (`~/.codex/skills/<name>/SKILL.md`)

**Same format as Claude.** Codex's skill loader is Claude-compatible. Keep the file identical to the Claude version.

## Pi (`~/.pi/skills/<name>/SKILL.md`)

**Same format as Claude.** Pi's skill loader is also Claude-compatible. Keep the file identical.

## OpenCode (`~/.config/opencode/command/<name>.md`)

**Different.** OpenCode uses **commands** (not skills) and the frontmatter has unique keys. Source-of-truth example: `~/.config/opencode/command/gsd-discuss-phase.md`.

```markdown
---
description: <one-paragraph "Use when..." text>
argument-hint: "<args> [--flag]"
argument-instructions: |
  <how to parse $ARGUMENTS>
tools:
  read: true
  write: true
  edit: true
  bash: true
  glob: true
  grep: true
  agent: true
  question: true
---

<objective>
<what the command does, in 1-2 paragraphs>
</objective>

<execution_context>
@/home/felipe/.config/opencode/get-shit-done/workflows/<workflow>.md
</execution_context>

<context>
$ARGUMENTS (required)
</context>

<process>
<numbered steps or branching>
</process>
```

Notes:
- **No subdir** — file lives directly in `command/`, not `command/<name>/SKILL.md`.
- `tools:` is a boolean map of which tools the agent may use during this command. **Set `question: false` for overnight-style skills** to enforce no-questions.
- `argument-hint` + `argument-instructions` are how the command parses its arguments.
- `<execution_context>` can reference a workflow file (like GSD does) or be omitted for self-contained commands.
- `<objective>`, `<context>`, `<process>` are the structural blocks. Other agents may not enforce these tags strictly but they're a useful scaffold.
- No `metadata:` block.

## Conversion cheat sheet (claude → opencode)

| Claude field | OpenCode field |
|---|---|
| `name:` | filename (no `name:` key) |
| `description:` | `description:` (same) |
| `tags:` | omit (opencode doesn't tag) |
| `metadata.openclaw.emoji` | omit |
| `metadata.openclaw.invocation` | `<objective>` body |
| `metadata.openclaw.side_effect` | `<process>` body |
| frontmatter `tools` map | `tools:` map (different position) |
| body | body (with structural blocks) |

## When the formats diverge

Sometimes a skill's intent doesn't map cleanly between formats. Examples:

- **OpenCode-only tools** (e.g., `mcp__context7__resolve-library-id`): add the tool to the `tools:` map; the Claude version silently ignores.
- **Claude's `metadata.openclaw.emoji`**: cosmetic; the opencode command just uses `<objective>`.
- **No-question enforcement**: set `question: false` in opencode's `tools:` map; in claude/codex/pi, rely on prose ("do not call the question tool").
- **Large bodies**: both formats allow `references/` siblings, but opencode's `command/` is flat, so use `<execution_context>` to reference a workflow file.

When in doubt: **write the Claude version first**, then convert to OpenCode. The Claude version is the canonical source.

## See also

- `adding-a-new-skill.md` — workflow for adding a new skill in 4 formats
- `../skills/overnight-task/SKILL.md` — the first skill, exemplifying the patterns
