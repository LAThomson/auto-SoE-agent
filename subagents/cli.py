"""Shared CLI boilerplate for all sub-agents."""

import asyncio
import json
import os
import sys
from collections.abc import Callable, Coroutine
from dataclasses import dataclass
from typing import Any


@dataclass
class AgentCLIConfig:
    """Configuration for a sub-agent's CLI entry point."""

    name: str
    required_fields: list[str]
    run_fn: Callable[..., Coroutine[Any, Any, str]]
    directory_field: str | None = None
    directory_dict_field: str | None = None


def run_cli(config: AgentCLIConfig) -> None:
    """Generic CLI entry point for any sub-agent.

    Handles argument parsing, JSON validation, directory checks,
    CLAUDECODE cleanup, and agent invocation. Prints the agent's
    report to stdout.

    Exit codes: 0 success, 1 input error, 2 agent error.
    """
    import argparse

    parser = argparse.ArgumentParser(description=f"Run the {config.name} agent.")
    parser.add_argument(
        "input_file",
        help=f"Path to a JSON file with: {', '.join(config.required_fields)}.",
    )
    parser.add_argument(
        "--cwd",
        default=None,
        help="Working directory for the agent (defaults to project root).",
    )
    args = parser.parse_args()

    # --- Load and validate input JSON ---
    try:
        with open(args.input_file) as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: input file not found: {args.input_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in {args.input_file}: {exc}", file=sys.stderr)
        sys.exit(1)

    missing = [f for f in config.required_fields if f not in data]
    if missing:
        print(
            f"Error: missing required fields in input JSON: {', '.join(missing)}",
            file=sys.stderr,
        )
        sys.exit(1)

    if config.directory_field:
        dir_path = data[config.directory_field]
        if not os.path.isdir(dir_path):
            print(
                f"Error: {config.directory_field} is not a directory: {dir_path}",
                file=sys.stderr,
            )
            sys.exit(1)

    if config.directory_dict_field:
        dir_dict = data[config.directory_dict_field]
        if not isinstance(dir_dict, dict):
            print(
                f"Error: {config.directory_dict_field} must be a JSON object",
                file=sys.stderr,
            )
            sys.exit(1)
        for label, dir_path in dir_dict.items():
            if not os.path.isdir(dir_path):
                print(
                    f"Error: {config.directory_dict_field}[{label}] "
                    f"is not a directory: {dir_path}",
                    file=sys.stderr,
                )
                sys.exit(1)

    # Load .env so API keys are available without manual export.
    # Keys enter the process environment here and propagate to Agent SDK
    # subprocesses and inspect eval calls — they never appear in any
    # Claude Code transcript.
    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ImportError:
        pass  # python-dotenv not available; rely on shell environment

    # Allow the Agent SDK to launch a nested Claude Code subprocess.
    # The orchestrator runs inside Claude Code, so CLAUDECODE is always set.
    os.environ.pop("CLAUDECODE", None)

    # --- Run the agent ---
    # Remove 'cwd' from data to avoid conflict with the explicit cwd kwarg.
    data.pop("cwd", None)
    try:
        report = asyncio.run(config.run_fn(cwd=args.cwd, **data))
    except RuntimeError as exc:
        print(f"Agent error: {exc}", file=sys.stderr)
        sys.exit(2)

    print(report)
