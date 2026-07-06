#!/usr/bin/env bash
# install.sh — Create symlinks in each agent's skill/command directory.
# Idempotent: re-running refreshes symlinks without duplicating files.
# Source of truth: ~/programming/agent-dev-kit/overnight-task-kit/skills/<name>/
#
# After running, the canonical SKILL.md (in skills/<name>/SKILL.md) is
# reachable from all 4 agents:
#   - Claude:   ~/.claude/skills/<name>/SKILL.md
#   - Codex:    ~/.codex/skills/<name>/SKILL.md
#   - Pi:       ~/.pi/skills/<name>/SKILL.md
#   - OpenCode: ~/.config/opencode/command/<name>.md  (uses *.opencode.md source variant)
#
# Usage:
#   ./install.sh                   # install all skills
#   ./install.sh <skill-name>      # install one skill
#   ./install.sh --uninstall       # remove all symlinks
#   ./install.sh --list            # list installed skills

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$KIT_DIR/skills"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.codex/skills"
PI_DIR="$HOME/.pi/skills"
OPENCODE_DIR="$HOME/.config/opencode/command"

mode="install"
target_skill=""
for arg in "$@"; do
    case "$arg" in
        --uninstall) mode="uninstall" ;;
        --list) mode="list" ;;
        -h|--help)
            grep -E '^#( |$)' "$0" | sed 's/^#//; s/^ //; s/^$//'
            exit 0
            ;;
        *) target_skill="$arg" ;;
    esac
done

# Helper: list canonical skills (each skill is a subdir of skills/)
list_canonical() {
    [ -d "$SKILLS_DIR" ] && find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

case "$mode" in
    list)
        echo "Canonical skills in $SKILLS_DIR:"
        list_canonical
        echo
        echo "Symlink status per agent:"
        for skill in $(list_canonical); do
            for path in \
                "$CLAUDE_DIR/$skill" \
                "$CODEX_DIR/$skill" \
                "$PI_DIR/$skill" \
                "$OPENCODE_DIR/$skill.md"; do
                if [ -L "$path" ]; then
                    target=$(readlink -f "$path")
                    if [ -e "$target" ]; then
                        printf '  ✓  %-60s -> %s\n' "$path" "$target"
                    else
                        printf '  ✗  %-60s -> %s [BROKEN]\n' "$path" "$target"
                    fi
                elif [ -e "$path" ]; then
                    printf '  !  %-60s [EXISTS, not a symlink]\n' "$path"
                else
                    printf '  ·  %-60s [not installed]\n' "$path"
                fi
            done
        done
        exit 0
        ;;
    uninstall)
        echo "Uninstalling all skills from each agent dir..."
        for skill in $(list_canonical); do
            [ -L "$CLAUDE_DIR/$skill" ] && rm "$CLAUDE_DIR/$skill" && echo "  rm $CLAUDE_DIR/$skill"
            [ -L "$CODEX_DIR/$skill" ] && rm "$CODEX_DIR/$skill" && echo "  rm $CODEX_DIR/$skill"
            [ -L "$PI_DIR/$skill" ] && rm "$PI_DIR/$skill" && echo "  rm $PI_DIR/$skill"
            [ -L "$OPENCODE_DIR/$skill.md" ] && rm "$OPENCODE_DIR/$skill.md" && echo "  rm $OPENCODE_DIR/$skill.md"
        done
        echo "Done. Source files in $SKILLS_DIR untouched."
        exit 0
        ;;
esac

# Install mode

# Pick the skills to install
if [ -n "$target_skill" ]; then
    skills=("$target_skill")
else
    mapfile -t skills < <(list_canonical)
fi

if [ ${#skills[@]} -eq 0 ]; then
    echo "No skills found in $SKILLS_DIR. Nothing to install."
    exit 0
fi

# Create agent dirs if missing
for dir in "$CLAUDE_DIR" "$CODEX_DIR" "$PI_DIR" "$OPENCODE_DIR"; do
    [ -d "$dir" ] || mkdir -p "$dir"
done

for skill in "${skills[@]}"; do
    src_dir="$SKILLS_DIR/$skill"
    if [ ! -d "$src_dir" ]; then
        echo "✗  $skill: source dir not found at $src_dir"
        continue
    fi

    src_skill_md="$src_dir/SKILL.md"
    if [ ! -f "$src_skill_md" ]; then
        echo "✗  $skill: SKILL.md missing at $src_skill_md"
        continue
    fi

    echo "→  Installing $skill ..."

    # Claude, Codex, Pi: symlink the WHOLE skill directory (not just SKILL.md).
    # This matches the convention used by the vault-symlinked skills
    # (e.g., ~/.claude/skills/caveman -> /home/felipe/vault/Resources/AI/Skills/shared/caveman).
    # The skill dir contains SKILL.md + any references/ siblings.
    ln -sfn "$src_dir" "$CLAUDE_DIR/$skill"
    echo "  ✓  $CLAUDE_DIR/$skill -> $src_dir"
    ln -sfn "$src_dir" "$CODEX_DIR/$skill"
    echo "  ✓  $CODEX_DIR/$skill -> $src_dir"
    ln -sfn "$src_dir" "$PI_DIR/$skill"
    echo "  ✓  $PI_DIR/$skill -> $src_dir"

    # OpenCode: symlink to the *.opencode.md variant if present, else the SKILL.md.
    src_opencode_md="$src_dir/$skill.opencode.md"
    if [ -f "$src_opencode_md" ]; then
        ln -sfn "$src_opencode_md" "$OPENCODE_DIR/$skill.md"
        echo "  ✓  $OPENCODE_DIR/$skill.md -> $src_opencode_md"
    else
        # Fallback: use the canonical SKILL.md. The opencode command loader
        # tolerates the SKILL.md frontmatter as long as the body has the right
        # structural blocks. Many skills won't need a separate *.opencode.md.
        ln -sfn "$src_skill_md" "$OPENCODE_DIR/$skill.md"
        echo "  ✓  $OPENCODE_DIR/$skill.md -> $src_skill_md (no opencode variant; using canonical)"
    fi
done

echo
echo "Done. Run './install.sh --list' to verify, or './install.sh --uninstall' to remove."
