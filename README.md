# Automating Science of Evals

<p align="center">
  <img src="docs/scaffold-diagram.png" alt="Scaffold architecture: User talks to an Orchestrator, which delegates to an Environment Explorer, Experiment Executor, and Transcript Analyst (behind a hypothesis firewall)" width="500">
</p>

A scaffold for automating science-of-evaluations research in [Inspect AI](https://inspect.aisi.org.uk/) evaluations, built on [Claude Code](https://claude.com/product/claude-code), [Inspect Scout](https://meridianlabs-ai.github.io/inspect_scout/) and the [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/claude-agent-sdk).

The Orchestrator agent (initiated using the `/orchestrator [research question]` skill) starts by having a conversation with the User to define the scope of the research question. It then carries out the following loop, regularly updating an append-only investigation log to preserve the epistemic trajectory:

1. **Generate falsifiable hypotheses** that are relevant and targeted to the research scope defined in the discussion phase;
2. Ask the *Environment Explorer* sub-agent to **identify informative, minimal perturbations** in the target eval setting;
3. Use the *Experiment Executor* sub-agent to **run the eval variations**, handling parallelism, error recovery, and logging;
4. Give the *Transcript Analyst* sub-agent a neutral topic description from which it can **surface relevant behavioural patterns** in the eval outputs, importantly without it ever directly seeing the original hypothesis; and
5. **Collate and interpret results** from the Analyst, then determine whether to iterate, conclude, or check in with the User.

When finished, the Orchestrator produces a structured report for the User that summarises the key findings, caveats, and potential next steps.

## Quick Start

```bash
# Clone the scaffold and your target eval repo
git clone <this-repo> auto-SoE-agent
git clone <your-inspect-ai-eval-repo>
cd <your-inspect-ai-eval-repo>

# Install the scaffold (creates symlinks + patches devcontainer)
/path/to/auto-SoE-agent/install.sh .

# Add your API keys to a `.env` file
echo "ANTHROPIC_API_KEY=sk-..." >> .env
echo "OPENAI_API_KEY=sk-..." >> .env

# Launch Claude Code (https://claude.com/product/claude-code) and start an investigation
# /orchestrator [your research question]

# To uninstall (remove symlinks and revert target repo changes):
# /path/to/auto-SoE-agent/uninstall.sh .
```

## Directory Structure

```
auto-SoE-agent/
├── subagents/
│   ├── runner.py                  # Shared SDK runner + hooks
│   ├── cli.py                     # Shared CLI boilerplate
│   ├── environment_explorer/      # Eval environment analysis
│   ├── experiment_executor/       # Runs Inspect AI evals
│   └── transcript_analyst/        # Blinded transcript analysis
├── .claude/
│   ├── docs/                      # Orchestrator reference documents
│   ├── skills/orchestrator/       # Orchestrator skill definition
│   └── settings.json              # Claude Code permissions
├── scripts/
│   └── execute_evals.py           # Parallel eval execution engine
├── docs/
│   └── scaffold-diagram.png       # Architecture diagram
├── .githooks/                     # Git hooks for scaffold repo
├── install.sh                     # Install into target repo
├── uninstall.sh                   # Remove from target repo
└── README.md
```
