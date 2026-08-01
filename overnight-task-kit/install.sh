#!/usr/bin/env bash
# install.sh — Create symlinks in each agent's skill/command directory.
# Idempotent: re-running refreshes symlinks without duplicating files.
# Source of truth: ~/programming/agent-dev-kit/overnight-task-kit/skills/<name>/
#
# After running, the canonical SKILL.md (in skills/<name>/SKILL.md) is
# reachable from all 4 agents:
#   - Claude:   ~/.claude/skills/<name>/SKILL.md
#   - Codex:    ~/.agents/skills/<name>/SKILL.md
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
CODEX_DIR="$HOME/.agents/skills"
PI_DIR="$HOME/.pi/skills"
OPENCODE_DIR="$HOME/.config/opencode/command"
install_failed=0

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

skill_targets() {
    local skill="$1"
    printf '%s\n' \
        "$CLAUDE_DIR/$skill" \
        "$CODEX_DIR/$skill" \
        "$PI_DIR/$skill" \
        "$OPENCODE_DIR/$skill.md"
}

link_codex_skill() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$source" ]; then
            echo "✗  Codex skill conflict at $target; existing entry left unchanged" >&2
            return 1
        fi
    fi

    ln -sfn "$source" "$target"
}

case "$mode" in
    list)
        echo "Canonical skills in $SKILLS_DIR:"
        list_canonical
        echo
        echo "Symlink status per agent:"
        for skill in $(list_canonical); do
            while IFS= read -r path; do
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
            done < <(skill_targets "$skill")
        done
        exit 0
        ;;
    uninstall)
        echo "Uninstalling all skills from each agent dir..."
        for skill in $(list_canonical); do
            while IFS= read -r path; do
                if [ -L "$path" ]; then
                    rm "$path"
                    echo "  rm $path"
                fi
            done < <(skill_targets "$skill")
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
mkdir -p "$CLAUDE_DIR" "$CODEX_DIR" "$PI_DIR" "$OPENCODE_DIR"

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
    # (e.g., ~/.claude/skills/caveman -> ~/vault/Resources/AI/Skills/shared/caveman).
    # The skill dir contains SKILL.md + any references/ siblings.
    for target_root in "$CLAUDE_DIR" "$PI_DIR"; do
        ln -sfn "$src_dir" "$target_root/$skill"
        echo "  ✓  $target_root/$skill -> $src_dir"
    done
    if link_codex_skill "$src_dir" "$CODEX_DIR/$skill"; then
        echo "  ✓  $CODEX_DIR/$skill -> $src_dir"
    else
        install_failed=1
    fi

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
if [ "$install_failed" -ne 0 ]; then
    echo "Install completed with Codex conflicts. Other harness targets were installed." >&2
    exit 1
fi
echo "Done. Run './install.sh --list' to verify, or './install.sh --uninstall' to remove."
