#!/bin/bash
# Install the eval-science scaffold into a target repository.
#
# Creates symlinks from the target repo to this scaffold repo,
# patches devcontainer.json to mount the scaffold into the container,
# and sets up CLAUDE.md and .gitignore.
#
# Usage: ./install.sh /path/to/inspect_ai
set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:?Usage: ./install.sh /path/to/target_repo}"

# In-container path where the scaffold will be mounted.
CONTAINER_SCAFFOLD="/home/inspect/auto-SoE-agent"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a directory"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Installing eval-science scaffold"
echo "  Scaffold: $SCAFFOLD_DIR"
echo "  Target:   $TARGET_DIR"
echo "  Container mount: $CONTAINER_SCAFFOLD"
echo ""

# --- Helper: create a symlink pointing to the in-container path ---
link_file() {
    local rel_path="$1"
    local src="$CONTAINER_SCAFFOLD/$rel_path"
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

# scripts
link_file "scripts/execute_evals.py"

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
ln -sf "$CONTAINER_SCAFFOLD/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
echo "  Linked: CLAUDE.md"

# --- Handle CLAUDE.local.md (copy template if not present) ---
if [ ! -f "$TARGET_DIR/CLAUDE.local.md" ]; then
    cp "$SCAFFOLD_DIR/CLAUDE.local.md.template" "$TARGET_DIR/CLAUDE.local.md"
    echo "  Created: CLAUDE.local.md (from template — edit as needed)"
else
    echo "  SKIP (exists): CLAUDE.local.md"
fi

# --- Handle .gitignore (backup and append scaffold entries) ---
echo ""
echo "Updating .gitignore..."
if [ -f "$TARGET_DIR/.gitignore" ] && [ ! -f "$TARGET_DIR/.gitignore.pre-scaffold" ]; then
    cp "$TARGET_DIR/.gitignore" "$TARGET_DIR/.gitignore.pre-scaffold"
    echo "  Backed up .gitignore to .gitignore.pre-scaffold"
fi
GITIGNORE_ENTRIES=(
    ""
    "# Eval Science Scaffold (symlinks managed by auto-SoE-agent/install.sh)"
    "subagents/"
    ".claude/docs/analyst_delegation_guide.md"
    ".claude/docs/analyst_interface_contract.md"
    ".claude/docs/eval_science_principles.md"
    ".claude/docs/inspect_reference.md"
    ".claude/docs/orchestrator_responsibilities.md"
    ".claude/docs/subagent_invocation.md"
    ".claude/skills/orchestrator/"
    ".claude/settings.json"
    ".claude/autopilot/"
    "CLAUDE.md"
    "CLAUDE.md.upstream"
    "CLAUDE.local.md"
    ".devcontainer/devcontainer.json.pre-scaffold"
    ".gitignore.pre-scaffold"
)
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if [ -f "$TARGET_DIR/.gitignore" ] && grep -qF "$entry" "$TARGET_DIR/.gitignore"; then
        echo "  Already present: $entry"
    else
        echo "$entry" >> "$TARGET_DIR/.gitignore"
        echo "  Appended: $entry"
    fi
done

# --- Configure git hooks for the scaffold repo ---
echo ""
echo "Configuring git hooks..."
if [ -d "$SCAFFOLD_DIR/.git" ]; then
    git -C "$SCAFFOLD_DIR" config core.hooksPath .githooks
    echo "  Activated .githooks/pre-commit for scaffold repo"
else
    echo "  SKIP: scaffold directory is not a git repo"
fi

# --- Patch devcontainer.json to mount the scaffold repo ---
DEVCONTAINER="$TARGET_DIR/.devcontainer/devcontainer.json"
if [ -f "$DEVCONTAINER" ]; then
    echo ""
    echo "Patching devcontainer.json..."

    # Backup original devcontainer.json before patching.
    if [ ! -f "$DEVCONTAINER.pre-scaffold" ]; then
        cp "$DEVCONTAINER" "$DEVCONTAINER.pre-scaffold"
        echo "  Backed up devcontainer.json to devcontainer.json.pre-scaffold"
    fi

    # Compute relative path from target repo to scaffold repo.
    # Use python3 for portability (macOS realpath lacks --relative-to).
    REL_PATH="$(python3 -c "import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$SCAFFOLD_DIR" "$TARGET_DIR")"
    MOUNT_SOURCE="\${localWorkspaceFolder}/$REL_PATH"

    # Use python3 to safely add the mount entry if not already present.
    python3 -c "
import json, sys

devcontainer_path = sys.argv[1]
mount_source = sys.argv[2]
mount_target = sys.argv[3]

with open(devcontainer_path) as f:
    config = json.load(f)

mounts = config.setdefault('mounts', [])

# Check if mount already exists.
mount_present = any(
    isinstance(m, dict) and m.get('target') == mount_target
    for m in mounts
)

if mount_present:
    print('  Already present: scaffold mount in devcontainer.json')
else:
    mounts.append({
        'source': mount_source,
        'target': mount_target,
        'type': 'bind'
    })
    print('  Added scaffold mount to devcontainer.json')

# --- Add Claude Code devcontainer feature ---
CLAUDE_FEATURE = 'ghcr.io/anthropics/devcontainer-features/claude-code:latest'
features = config.setdefault('features', {})
 
if CLAUDE_FEATURE in features:
    print('  Already present: Claude Code feature in devcontainer.json')
else:
    features[CLAUDE_FEATURE] = {}
    print('  Added Claude Code feature to devcontainer.json')

with open(devcontainer_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

" "$DEVCONTAINER" "$MOUNT_SOURCE" "$CONTAINER_SCAFFOLD"
else
    echo ""
    echo "  No .devcontainer/devcontainer.json found — skipping container setup."
    echo "  If using a devcontainer, manually mount $SCAFFOLD_DIR at $CONTAINER_SCAFFOLD"
fi

# --- Tell git to ignore local changes to patched upstream files ---
echo ""
echo "Marking patched files as assume-unchanged in git..."
if [ -d "$TARGET_DIR/.git" ]; then
    git -C "$TARGET_DIR" update-index --assume-unchanged \
        .devcontainer/devcontainer.json \
        .gitignore \
        CLAUDE.md \
        2>/dev/null || true
    echo "  Done (git status will stay clean)"
else
    echo "  SKIP: target is not a git repo"
fi

echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Open the target repo in VS Code and accept the devcontainer prompt"
echo "  2. Copy or create .claude/settings.local.json with your local overrides"
echo "  3. Ensure ANTHROPIC_API_KEY is set in your environment"
echo "  4. Launch the orchestrator: /orchestrator [research question]"
