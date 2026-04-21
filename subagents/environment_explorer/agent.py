"""Environment Explorer agent — prompt building and config."""

from typing import Any

from subagents.environment_explorer.system_prompt import SYSTEM_PROMPT
from subagents.runner import run_agent

ALLOWED_TOOLS = ["Read", "Glob", "Grep"]
DISALLOWED_TOOLS = ["Edit", "Bash", "WebSearch", "WebFetch"]

# Files this agent must not read. Mapping of filename pattern → reason.
# The Explorer must read its own contract (explorer_interface_contract.md);
# it is intentionally absent from this list.
RESTRICTED_FILES: dict[str, str] = {
    "eval_science_principles.md": "Orchestrator-only methodological reference.",
    "analyst_delegation_guide.md": "Orchestrator-only delegation guide.",
    "analyst_interface_contract.md": (
        "Analyst-orchestrator interface contract. Not relevant to this agent."
    ),
}


async def run_environment_explorer(cwd: str | None = None, **data: Any) -> str:
    """Run the environment explorer agent and return its markdown report."""
    prompt = f"""\
## Experiment Description

{data["experiment_description"]}

## Hypothesis

{data["hypothesis"]}

## Environment Path

{data["environment_path"]}
"""
    constraints = data.get("constraints")
    if constraints:
        prompt += f"\n## Constraints\n\n{constraints}\n"

    # Memory is disabled for the Explorer: each invocation is self-contained,
    # per the interface contract. This also keeps the agent fully read-only
    # (runner.py only injects Write into allowed_tools when a memory_file is set).
    return await run_agent(
        prompt=prompt,
        system_prompt=SYSTEM_PROMPT,
        allowed_tools=ALLOWED_TOOLS,
        disallowed_tools=DISALLOWED_TOOLS,
        agent_name="Environment explorer",
        cwd=cwd,
        restricted_files=RESTRICTED_FILES,
        memory_file=None,
    )
