#!/bin/bash
# Install the eval-science scaffold into a target repository.
#
# Creates symlinks from the target repo to this scaffold repo.
# The target repo's own files are left untouched except for
# CLAUDE.md (backed up and replaced) and .gitignore (appended).
#
# Usage: ./install.sh /path/to/inspect_ai
set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:?Usage: ./install.sh /path/to/target_repo}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a directory"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Installing eval-science scaffold"
echo "  Scaffold: $SCAFFOLD_DIR"
echo "  Target:   $TARGET_DIR"
echo ""

# --- Helper: create a symlink, skipping if a non-symlink file exists ---
link_file() {
    local rel_path="$1"
    local src="$SCAFFOLD_DIR/$rel_path"
    local dst="$TARGET_DIR/$rel_path"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    mkdir -p "$dst_dir"

    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        echo "  SKIP (exists): $rel_path"
        return
    fi

    ln -s "$src" "$dst"
    echo "  Linked: $rel_path"
}

# --- Symlink all scaffold files ---
echo "Creating symlinks..."

# subagents
link_file "subagents/__init__.py"
link_file "subagents/cli.py"
link_file "subagents/runner.py"

link_file "subagents/environment_explorer/__init__.py"
link_file "subagents/environment_explorer/agent.py"
link_file "subagents/environment_explorer/main.py"
link_file "subagents/environment_explorer/memory.md"
link_file "subagents/environment_explorer/system_prompt.py"

link_file "subagents/experiment_executor/__init__.py"
link_file "subagents/experiment_executor/agent.py"
link_file "subagents/experiment_executor/main.py"
link_file "subagents/experiment_executor/memory.md"
link_file "subagents/experiment_executor/system_prompt.py"

link_file "subagents/transcript_analyst/__init__.py"
link_file "subagents/transcript_analyst/agent.py"
link_file "subagents/transcript_analyst/main.py"
link_file "subagents/transcript_analyst/memory.md"
link_file "subagents/transcript_analyst/system_prompt.py"

# .claude/docs
link_file ".claude/docs/analyst_delegation_guide.md"
link_file ".claude/docs/analyst_interface_contract.md"
link_file ".claude/docs/eval_science_principles.md"
link_file ".claude/docs/inspect_reference.md"
link_file ".claude/docs/orchestrator_responsibilities.md"
link_file ".claude/docs/subagent_invocation.md"

# .claude/skills/orchestrator
link_file ".claude/skills/orchestrator/SKILL.md"
link_file ".claude/skills/orchestrator/experimental-design-patterns.md"
link_file ".claude/skills/orchestrator/hypothesis-methodology.md"

# .claude/settings.json
link_file ".claude/settings.json"

# --- Handle CLAUDE.md (backup and replace) ---
echo ""
echo "Setting up CLAUDE.md..."
if [ -f "$TARGET_DIR/CLAUDE.md" ] && [ ! -L "$TARGET_DIR/CLAUDE.md" ]; then
    cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.upstream"
    echo "  Backed up upstream CLAUDE.md to CLAUDE.md.upstream"
fi
ln -sf "$SCAFFOLD_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
echo "  Linked: CLAUDE.md"

# --- Handle CLAUDE.local.md (copy template if not present) ---
if [ ! -f "$TARGET_DIR/CLAUDE.local.md" ]; then
    cp "$SCAFFOLD_DIR/CLAUDE.local.md.template" "$TARGET_DIR/CLAUDE.local.md"
    echo "  Created: CLAUDE.local.md (from template — edit as needed)"
else
    echo "  SKIP (exists): CLAUDE.local.md"
fi

# --- Handle .gitignore (append scaffold entries) ---
echo ""
echo "Updating .gitignore..."
GITIGNORE_ENTRIES=(
    ".claude/autopilot/"
    "subagents/**/memory.md"
)
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if [ -f "$TARGET_DIR/.gitignore" ] && grep -qF "$entry" "$TARGET_DIR/.gitignore"; then
        echo "  Already present: $entry"
    else
        echo "$entry" >> "$TARGET_DIR/.gitignore"
        echo "  Appended: $entry"
    fi
done

echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Copy or create .claude/settings.local.json with your local overrides"
echo "  2. Ensure ANTHROPIC_API_KEY is set in your environment"
echo "  3. Test: uv run --with inspect-scout python -c 'import inspect_scout; print(inspect_scout.__version__)'"
