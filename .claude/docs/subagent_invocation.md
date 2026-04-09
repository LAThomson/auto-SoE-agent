# Sub-Agent Invocation Reference

Sub-agents are invoked as CLI scripts via the Agent SDK. The orchestrator writes a JSON input file, runs the script via Bash, and captures the report from stdout.

## General Pattern

```bash
uv run --with claude-agent-sdk --with python-dotenv python subagents/<agent>/main.py <input.json> [--cwd <dir>]
```

- **Input**: JSON file with agent-specific fields (see below)
- **Output**: Structured markdown report printed to stdout
- **Errors**: Printed to stderr
- **Exit codes**: 0 = success, 1 = input validation error, 2 = agent error

The orchestrator should: (1) write the input JSON to a temp file, (2) run the command via Bash, (3) capture stdout as the report. All agents run fire-and-forget — no back-and-forth.

## Environment Explorer

**Script**: `subagents/environment_explorer/main.py`

**Input JSON**:
```json
{
    "hypothesis": "Adding X to the system prompt increases Y...",
    "experiment_description": "Testing whether X affects Y...",
    "environment_path": "/absolute/path/to/eval/environment"
}
```

- `environment_path` must be an existing directory

**Returns**: File catalogue, modification sites with diffs, recommended conditions, activation parameters, risk assessment.

## Experiment Executor

**Script**: `subagents/experiment_executor/main.py`

**Input JSON**:
```json
{
    "experiment_name": "explicit_goal_framing",
    "experiment_dir": "/absolute/path/to/experiment",
    "conditions": {
        "control": {
            "task": "task.py",
            "args": {}
        },
        "treatment": {
            "task": "task.py",
            "args": {"system": "system_prompt_treatment.txt"}
        }
    },
    "models": ["anthropic/claude-sonnet-4-5-20250929"],
    "overrides": {
        "sample_limit": 50,
        "epochs": 1,
        "skip_preflight": false
    }
}
```

- `experiment_dir` must be an existing directory
- `overrides` is optional; may include `max_parallel` to cap concurrent eval processes

**Returns**: Log paths, status per condition-model pair, concurrency summary, error summary, retry flags, execution summary.

## Transcript Analyst

**Script**: `subagents/transcript_analyst/main.py`

**Input JSON**:
```json
{
    "topic": "How models reason about their operational context and whether they adjust their approach based on perceived circumstances",
    "transcript_source": {
        "condition_A": "/absolute/path/to/logs/run_001",
        "condition_B": "/absolute/path/to/logs/run_002"
    },
    "scanning_model": "openai/gpt-4.1-mini",
    "constraints": {"limit": 100},
    "artefacts_dir": "/absolute/path/to/investigation/artefacts"
}
```

- `transcript_source` values must all be existing directories containing `.eval` log files
- `topic` must be a **neutral description** — never the hypothesis
- Use **opaque condition labels** (condition_A, condition_B) — randomise the mapping to conditions
- `scanning_model`, `constraints`, and `artefacts_dir` are optional
- When `artefacts_dir` is provided, the analyst writes all file outputs to `<artefacts_dir>/analyst/`

**Returns**: Scanner definitions, validation metrics, quantified results (per-condition detection rates), scan results path, transcript exclusions, transcript excerpts, additional observations. See `analyst_interface_contract.md` for the full report format.
