"""Experiment Executor agent — prompt building and config."""

import json
from typing import Any

from subagents.experiment_executor.system_prompt import SYSTEM_PROMPT
from subagents.runner import run_agent

ALLOWED_TOOLS = ["Bash", "Read", "Glob", "Grep"]
DISALLOWED_TOOLS = ["Edit", "WebSearch", "WebFetch"]
MEMORY_FILE = "subagents/experiment_executor/memory.md"

# Files this agent must not read. Mapping of filename pattern → reason.
RESTRICTED_FILES: dict[str, str] = {
    "eval_science_principles.md": "Orchestrator-only methodological reference.",
    "analyst_delegation_guide.md": "Orchestrator-only delegation guide.",
    "analyst_interface_contract.md": (
        "Analyst-orchestrator interface contract. Not relevant to this agent."
    ),
}


async def run_experiment_executor(cwd: str | None = None, **data: Any) -> str:
    """Run the experiment executor agent and return its execution report."""
    models = data["models"]
    prompt = f"""\
## Experiment Name

{data["experiment_name"]}

## Parent Experiment Directory

{data["experiment_dir"]}

## Condition Specifications

```json
{json.dumps(data["conditions"], indent=2)}
```

## Model Specifications

{chr(10).join(f"- `{m}`" for m in models)}

## Execution Parameter Overrides

```json
{json.dumps(data.get("overrides") or {}, indent=2)}
```
"""
    return await run_agent(
        prompt=prompt,
        system_prompt=SYSTEM_PROMPT,
        allowed_tools=ALLOWED_TOOLS,
        disallowed_tools=DISALLOWED_TOOLS,
        agent_name="Experiment executor",
        cwd=cwd,
        restricted_files=RESTRICTED_FILES,
        memory_file=MEMORY_FILE,
    )
