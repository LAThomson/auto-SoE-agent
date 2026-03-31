"""Transcript Analyst agent — prompt building and config."""

import json
from typing import Any

from subagents.runner import run_agent
from subagents.transcript_analyst.system_prompt import SYSTEM_PROMPT

ALLOWED_TOOLS = ["Bash", "Read", "Write", "Glob", "Grep"]
DISALLOWED_TOOLS = ["Edit", "WebSearch", "WebFetch"]
MEMORY_FILE = "subagents/transcript_analyst/memory.md"

# Files this agent must not read. Mapping of filename pattern → reason.
RESTRICTED_FILES: dict[str, str] = {
    "eval_science_principles.md": (
        "Contains hypothesis-informing methodological principles. "
        "The analyst must not access this to prevent confirmation bias."
    ),
    "analyst_delegation_guide.md": (
        "Orchestrator-internal delegation logic. "
        "Contains hypothesis translation guidance not intended for the analyst."
    ),
}


async def run_transcript_analyst(cwd: str | None = None, **data: Any) -> str:
    """Run the transcript analyst agent and return its analysis report."""
    sections = [
        f"## Neutral Topic Description\n\n{data['topic']}",
        f"## Transcript Source\n\n```json\n{json.dumps(data['transcript_source'], indent=2)}\n```",
    ]

    if data.get("scanning_model"):
        sections.append(f"## Scanning Model\n\n{data['scanning_model']}")

    if data.get("constraints"):
        sections.append(
            f"## Constraints\n\n```json\n{json.dumps(data['constraints'], indent=2)}\n```"
        )

    if data.get("artefacts_dir"):
        sections.append(f"## Artefacts Directory\n\n{data['artefacts_dir']}")

    prompt = "\n\n".join(sections) + "\n"

    return await run_agent(
        prompt=prompt,
        system_prompt=SYSTEM_PROMPT,
        allowed_tools=ALLOWED_TOOLS,
        disallowed_tools=DISALLOWED_TOOLS,
        agent_name="Transcript analyst",
        cwd=cwd,
        restricted_files=RESTRICTED_FILES,
        memory_file=MEMORY_FILE,
        restrict_writes_to_memory=False,
    )
