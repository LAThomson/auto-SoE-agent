"""CLI entry point for the Transcript Analyst agent."""

import os
import sys

# Bootstrap: ensure project root is on sys.path before package imports.
sys.path.insert(
    0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)

from subagents.cli import AgentCLIConfig, run_cli  # noqa: E402
from subagents.transcript_analyst.agent import (  # noqa: E402
    run_transcript_analyst,
)

if __name__ == "__main__":
    run_cli(
        AgentCLIConfig(
            name="Transcript Analyst",
            required_fields=["topic", "transcript_source"],
            run_fn=run_transcript_analyst,
            directory_dict_field="transcript_source",
        )
    )
