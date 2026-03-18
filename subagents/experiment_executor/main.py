"""CLI entry point for the Experiment Executor agent."""

import os
import sys

# Bootstrap: ensure project root is on sys.path before package imports.
sys.path.insert(
    0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)

from subagents.cli import AgentCLIConfig, run_cli  # noqa: E402
from subagents.experiment_executor.agent import (  # noqa: E402
    run_experiment_executor,
)

if __name__ == "__main__":
    run_cli(
        AgentCLIConfig(
            name="Experiment Executor",
            required_fields=[
                "experiment_name",
                "experiment_dir",
                "conditions",
                "models",
            ],
            directory_field="experiment_dir",
            run_fn=run_experiment_executor,
        )
    )
