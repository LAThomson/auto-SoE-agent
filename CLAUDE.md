@README.md

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Lint/Test Commands
- Run all tests: `pytest`
- Run a single test: `pytest tests/path/to/test_file.py::test_function_name -v`
- Format code: `ruff format`
- Lint code: `ruff check --fix`
- Type check: `mypy --exclude tests/test_package src tests`

## Code Style Guidelines
- **Formatting**: Follow Google style convention. Use ruff for formatting
- **Imports**: Use isort order (enforced by ruff)
- **Types**: Strict typing is required. All functions must have type annotations
- **Naming**: Use snake_case for variables, functions, methods; PascalCase for classes
- **Docstrings**: Google-style docstrings required for public APIs
- **Error Handling**: Use appropriate exception types; include context in error messages
- **Testing**: Write tests with pytest; maintain high coverage

Respect existing code patterns when modifying files. Run linting before committing changes.

## Bash Operations

Complex bash syntax is hard for Claude Code to permission correctly. Keep commands simple.

Simple operations are fine: `|`, `||`, `&&`, `>` redirects.

For bulk operations on multiple files, use xargs:
- Plain: `ls *.md | xargs wc -l`
- With placeholder: `ls *.md | xargs -I{} head -1 {}`

Avoid string interpolation (`$()`, backticks, `${}`), heredocs, loops, and advanced xargs flags (`-P`, `-L`, `-n`) - these require scripts or simpler alternatives.

**Patterns:**
- File creation: Write tool, not `cat << 'EOF' > file`
- Env vars: `export VAR=val && command`, not `VAR=val command` or `env VAR=val command`
- Bulk operations: `ls *.md | xargs wc -l`, not `for f in *.md; do cmd "$f"; done`
- Parallel/batched xargs: use scripts, not `xargs -P4` or `xargs -L1`
- Per-item shell logic: use scripts, not `xargs sh -c '...'`
- Git: `git <command>`, not `git -C <path> <command>` (breaks permissions)

## Permission Rationale

Some commands are denied to enforce project conventions. When a denied command is the obvious choice, use the safe alternative. When no clear alternative exists, stop and explain why you need the command.

| Denied command | Why | Safe alternative |
|---|---|---|
| `python`, `pip` | Must use uv for dependency isolation | `uv run python`, `uv pip` |
| `pytest`, `mypy`, `ruff` | Must run through uv | `uv run pytest`, `uv run mypy`, `uv run ruff` |
| `find -exec/-execdir` | Arbitrary command execution risk | `find ... \| xargs ...` (will prompt for approval if needed) |
| `awk ... system()` | Shell escape via awk's system() builtin | `grep`, `sed`, `cut`, or a script |
| `bash -c`, `sh -c` | Unpermissionable shell-in-shell | Write a script in `scripts/` |
| `for`, `while`, `until` | Complex shell syntax breaks permissions | `xargs` or write a script |
| `env VAR=val cmd` | Bypass vector | `export VAR=val && cmd` |
| `git -C <path>` | Breaks permission matching | `cd` then `git` (or avoid) |
| `Read(.env)` | Contains API keys (ANTHROPIC, OPENAI) | Ask user for specific values needed |

**General rule:** If there's an obvious safe equivalent, use it silently. If not, stop and explain what you need and why.