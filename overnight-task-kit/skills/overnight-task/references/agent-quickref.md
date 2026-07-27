# Per-agent skill/command locations — quick reference

> Where each of the 4 agents supported by this kit looks for skills. Use this when
> installing a new skill or verifying an existing one.

## Claude (`~/.claude/skills/`)

```
~/.claude/skills/
├── <skill-name>/
│   └── SKILL.md          # frontmatter + body
└── ... (additional installed skills or symlinks)
```

**Format:** YAML frontmatter (`name`, `tags`, `description`, `metadata.openclaw.{emoji,side_effect,invocation}`) + Markdown body.

**Source of truth examples:** `<repo-root>/overnight-task-kit/skills/<name>/SKILL.md` or another explicitly managed source directory.

## Codex (`~/.agents/skills/`)

```
~/.agents/skills/
├── <skill-name>/
│   ├── SKILL.md          # frontmatter + body
│   └── agents/           # optional: sub-agents
└── ... (additional installed skills or symlinks)
```

**Format:** **Same as Claude.** Codex's skill loader is Claude-compatible.

## Pi (`~/.pi/skills/`)

```
~/.pi/skills/
├── <skill-name>/
│   └── SKILL.md          # frontmatter + body (Claude-compatible)
└── ... (additional installed skills or symlinks)
```

**Format:** **Same as Claude.** Pi's skill loader is also Claude-compatible.

## OpenCode (`~/.config/opencode/command/`)

```
~/.config/opencode/
├── AGENTS.md             # global opencode system context (has context7 reminder)
├── opencode.json         # model + provider + MCP config
├── command/              # commands (opencode's skills)
│   ├── <command-name>.md
│   └── ... (additional commands)
├── agents/               # agent definitions
├── hooks/                # lifecycle hooks
└── get-shit-done/        # GSD workflow definitions
```

**Format:** `description` + `argument-hint` + `tools` map + body with `<objective>`, `<execution_context>`, `<context>`, `<process>`.

**Key difference:** no subdir per command (file lives directly in `command/`, not `command/<name>/SKILL.md`).

**Source of truth example:** `~/.config/opencode/command/gsd-discuss-phase.md`.

## The symlink pattern

Skills in the agent directories may be **symlinks** to an explicitly managed source:

```bash
# Example: ~/.claude/skills/caveman
caveman -> <source-root>/caveman
```

When you install a new skill via the kit, the symlinks point to `<repo-root>/overnight-task-kit/skills/<name>/`.

```bash
# Example: ~/.claude/skills/overnight-task (after install)
overnight-task -> <repo-root>/overnight-task-kit/skills/overnight-task
```

Edit the source once; the symlinks pick it up everywhere.

## Adding a new skill — the install.sh matrix

| Source file | Symlink target |
|---|---|
| `<repo-root>/overnight-task-kit/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |
| same | `~/.agents/skills/<name>/SKILL.md` |
| same | `~/.pi/skills/<name>/SKILL.md` |
| `<repo-root>/overnight-task-kit/skills/<name>/<name>.opencode.md` | `~/.config/opencode/command/<name>.md` |

The `install.sh` script (in the kit root) creates all 4 symlinks per skill. Idempotent.

## Where to find agent-specific config

| Config | Path | Use |
|---|---|---|
| Claude `AGENTS.md` | (none global; per-project) | n/a — Claude loads from the working dir |
| Codex `AGENTS.md` | (none global) | n/a |
| Codex `auth.json` | `~/.codex/auth.json` | local API credentials |
| OpenCode `opencode.json` | `~/.config/opencode/opencode.json` | model, provider, MCP config |
| OpenCode `AGENTS.md` | `~/.config/opencode/AGENTS.md` | system prompt + context7 reminder |
| Pi `models.json` | `~/.pi/agent/models.json` | model list |
| Pi `auth.json` | `~/.pi/agent/auth.json` | API keys |

## Verifying an install

```bash
# After running install.sh
readlink -f ~/.claude/skills/overnight-task
# → <repo-root>/overnight-task-kit/skills/overnight-task

readlink -f ~/.config/opencode/command/overnight-task.md
# → <repo-root>/overnight-task-kit/skills/overnight-task/overnight-task.opencode.md
```

## See also

- `../docs/agent-formats.md` — full per-agent frontmatter/structure cheatsheet
- `../docs/adding-a-new-skill.md` — workflow for adding a new skill
- `../install.sh` — the installer
