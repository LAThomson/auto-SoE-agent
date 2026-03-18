# Eval Science Scaffold

An automated experiment pipeline for studying AI evaluations. Uses Claude Code as the orchestrator and the Claude Agent SDK to run three specialised sub-agents: an environment explorer, an experiment executor, and a transcript analyst.

## Quick Start

```bash
# Clone a target repo (e.g., published inspect-ai)
git clone https://github.com/UKGovernmentBEIS/inspect_ai.git
cd inspect_ai

# Install the scaffold (creates symlinks)
/path/to/auto-SoE-agent/install.sh .

# Set up your local config
cp CLAUDE.local.md.template CLAUDE.local.md  # if not already created
# Edit CLAUDE.local.md with your local settings

# Verify inspect-scout resolves correctly
uv run --with inspect-scout python -c "import inspect_scout; print(inspect_scout.__version__)"

# Launch the orchestrator in Claude Code
# /orchestrator [research question]
```

## What This Is

The scaffold provides:

- **Three Agent SDK sub-agents** that handle mechanical work:
  - **Environment Explorer** — reads an eval environment and proposes minimal modifications to test a hypothesis
  - **Experiment Executor** — runs Inspect AI evaluations and returns structured execution reports
  - **Transcript Analyst** — analyses eval transcripts using Inspect Scout scanners, blinded to the hypothesis

- **An orchestrator skill** that drives the pipeline from hypothesis to findings, delegating to sub-agents and maintaining scientific rigour

- **Methodological guardrails** including a hypothesis firewall (the analyst never sees the hypothesis), file access controls (agents can only read docs relevant to their role), and methodological checkpoints drawn from evaluation science literature

## Architecture

```
Orchestrator (Claude Code + /orchestrator skill)
    │
    ├── Environment Explorer (Agent SDK, read-only)
    │
    ├── Experiment Executor (Agent SDK, runs evals)
    │
    └── Transcript Analyst (Agent SDK, Inspect Scout)
```

Sub-agents are invoked via CLI:
```bash
uv run --with claude-agent-sdk python subagents/<agent>/main.py input.json
```

## Installation

The scaffold installs into any target repository via symlinks:

```bash
./install.sh /path/to/target_repo
```

This creates symlinks from the target repo back to this scaffold repo. Files are edited in the scaffold repo and tracked in its git history. The target repo stays clean.

To remove:
```bash
./uninstall.sh /path/to/target_repo
```

## Directory Structure

```
auto-SoE-agent/
├── subagents/       # Agent SDK sub-agents
│   ├── runner.py                  # Shared SDK runner + hooks
│   ├── cli.py                     # Shared CLI boilerplate
│   ├── environment_explorer/      # Read-only eval environment analysis
│   ├── experiment_executor/       # Runs Inspect AI evals
│   └── transcript_analyst/        # Inspect Scout transcript analysis
├── .claude/
│   ├── docs/                      # Reference documents
│   │   ├── orchestrator_responsibilities.md
│   │   ├── subagent_invocation.md
│   │   ├── eval_science_principles.md
│   │   ├── analyst_delegation_guide.md
│   │   ├── analyst_interface_contract.md
│   │   └── inspect_reference.md
│   ├── skills/orchestrator/       # Orchestrator skill definition
│   └── settings.json              # Claude Code permissions
├── CLAUDE.md                      # Project instructions
├── CLAUDE.local.md.template       # Template for local settings
├── install.sh                     # Install into target repo
├── uninstall.sh                   # Remove from target repo
└── README.md
```

## Dependencies

- **Claude Code** with Agent SDK support
- **claude-agent-sdk** — provided via `uv run --with`, not installed globally
- **inspect-scout** — provided via `uv run --with`, not installed globally
- **inspect-ai** — the target repo (published version, not dev build)

## File Access Controls

Sub-agents have restricted file access enforced by PreToolUse hooks:

| Document | Explorer | Executor | Analyst | Orchestrator |
|----------|:--------:|:--------:|:-------:|:------------:|
| eval_science_principles.md | blocked | blocked | blocked | reads |
| analyst_delegation_guide.md | blocked | blocked | blocked | reads |
| analyst_interface_contract.md | blocked | blocked | reads | reads |
| inspect_reference.md | — | reads | — | — |

Each agent also has an append-only `memory.md` for persisting learnings across invocations.
