#!/bin/bash
# Remove eval-science scaffold symlinks from a target repository.
#
# Only removes symlinks that point into this scaffold repo.
# Non-symlink files are never touched.
#
# Usage: ./uninstall.sh /path/to/inspect_ai
set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:?Usage: ./uninstall.sh /path/to/target_repo}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a directory"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Uninstalling eval-science scaffold"
echo "  Scaffold: $SCAFFOLD_DIR"
echo "  Target:   $TARGET_DIR"
echo ""

# --- Helper: remove a symlink only if it points into the scaffold repo ---
unlink_file() {
    local rel_path="$1"
    local dst="$TARGET_DIR/$rel_path"

    if [ -L "$dst" ]; then
        local link_target
        link_target="$(readlink "$dst")"
        if echo "$link_target" | grep -q "$SCAFFOLD_DIR"; then
            rm "$dst"
            echo "  Removed: $rel_path"
        else
            echo "  SKIP (points elsewhere): $rel_path"
        fi
    elif [ -e "$dst" ]; then
        echo "  SKIP (not a symlink): $rel_path"
    fi
}

echo "Removing symlinks..."

# subagents
unlink_file "subagents/__init__.py"
unlink_file "subagents/cli.py"
unlink_file "subagents/runner.py"
unlink_file "subagents/environment_explorer/__init__.py"
unlink_file "subagents/environment_explorer/agent.py"
unlink_file "subagents/environment_explorer/main.py"
unlink_file "subagents/environment_explorer/memory.md"
unlink_file "subagents/environment_explorer/system_prompt.py"
unlink_file "subagents/experiment_executor/__init__.py"
unlink_file "subagents/experiment_executor/agent.py"
unlink_file "subagents/experiment_executor/main.py"
unlink_file "subagents/experiment_executor/memory.md"
unlink_file "subagents/experiment_executor/system_prompt.py"
unlink_file "subagents/transcript_analyst/__init__.py"
unlink_file "subagents/transcript_analyst/agent.py"
unlink_file "subagents/transcript_analyst/main.py"
unlink_file "subagents/transcript_analyst/memory.md"
unlink_file "subagents/transcript_analyst/system_prompt.py"

# .claude/docs
unlink_file ".claude/docs/analyst_delegation_guide.md"
unlink_file ".claude/docs/analyst_interface_contract.md"
unlink_file ".claude/docs/eval_science_principles.md"
unlink_file ".claude/docs/inspect_reference.md"
unlink_file ".claude/docs/orchestrator_responsibilities.md"
unlink_file ".claude/docs/subagent_invocation.md"

# .claude/skills/orchestrator
unlink_file ".claude/skills/orchestrator/SKILL.md"
unlink_file ".claude/skills/orchestrator/experimental-design-patterns.md"
unlink_file ".claude/skills/orchestrator/hypothesis-methodology.md"

# .claude/settings.json
unlink_file ".claude/settings.json"

# CLAUDE.md
unlink_file "CLAUDE.md"

# Restore upstream CLAUDE.md if backup exists
if [ -f "$TARGET_DIR/CLAUDE.md.upstream" ]; then
    mv "$TARGET_DIR/CLAUDE.md.upstream" "$TARGET_DIR/CLAUDE.md"
    echo "  Restored: CLAUDE.md (from backup)"
fi

echo ""
echo "Uninstallation complete."
echo "Note: .gitignore entries and CLAUDE.local.md were left in place."
