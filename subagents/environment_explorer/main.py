"""CLI entry point for the Environment Explorer agent."""

import os
import sys

# Bootstrap: ensure project root is on sys.path before package imports.
sys.path.insert(
    0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)

from subagents.cli import AgentCLIConfig, run_cli  # noqa: E402
from subagents.environment_explorer.agent import (  # noqa: E402
    run_environment_explorer,
)

if __name__ == "__main__":
    run_cli(
        AgentCLIConfig(
            name="Environment Explorer",
            required_fields=[
                "hypothesis",
                "experiment_description",
                "environment_path",
            ],
            directory_field="environment_path",
            run_fn=run_environment_explorer,
        )
    )
