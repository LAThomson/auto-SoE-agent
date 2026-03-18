# Inspect AI Reference for Experiment Executor

This document captures everything an experiment-executor agent needs to run evaluations in Inspect AI. It is compiled from the source code and official documentation.

## Running Evaluations via CLI

### Basic Commands

```bash
# Single task, single model
inspect eval task.py --model openai/gpt-4

# Multiple tasks
inspect eval task1.py task2.py --model openai/gpt-4

# Specific task in a file
inspect eval ctf.py@jeopardy --model openai/gpt-4

# With sample limits (for development/testing)
inspect eval task.py --model openai/gpt-4 --limit 50

# Hugging Face datasets
inspect eval hf/OpenEvals/aime_24 --model openai/gpt-5
```

### Task Arguments

```bash
# Pass arguments to the @task function
inspect eval security.py -T system="researcher.txt" -T grader="hacker.txt"

# Or use a config file
inspect eval security.py --task-config=config.yaml
```

### Model Specification

Format: `provider/model-name`

```bash
inspect eval task.py --model openai/gpt-4
inspect eval task.py --model anthropic/claude-sonnet-4-0
inspect eval task.py --model google/gemini-2.5-pro
```

Model can also be set via environment variable:
```bash
export INSPECT_EVAL_MODEL=openai/gpt-4
```

Model-specific arguments:
```bash
inspect eval task.py --model google/gemini-2.5-pro -M location=us-east5
```

Model roles (for multi-model tasks like grading):
```bash
inspect eval math.py --model-role grader=google/gemini-2.0-flash
```

### Generation Parameters

| Flag | Env Var | Description |
|------|---------|-------------|
| `--temperature` | `INSPECT_EVAL_TEMPERATURE` | Sampling temperature (0-2) |
| `--max-tokens` | `INSPECT_EVAL_MAX_TOKENS` | Max tokens in completion |
| `--top-p` | `INSPECT_EVAL_TOP_P` | Nucleus sampling |
| `--top-k` | `INSPECT_EVAL_TOP_K` | Top-k sampling (Anthropic, Google, HF, vLLM) |
| `--seed` | `INSPECT_EVAL_SEED` | Random seed (OpenAI, Google, Groq, Mistral) |
| `--max-connections` | `INSPECT_EVAL_MAX_CONNECTIONS` | Max concurrent API connections (default: 10) |
| `--reasoning-effort` | `INSPECT_EVAL_REASONING_EFFORT` | Reasoning effort: none/minimal/low/medium/high/xhigh |

### Sample Selection

| Flag | Description |
|------|-------------|
| `--limit 50` | First 50 samples |
| `--limit 10-20` | Samples 10 through 20 |
| `--sample-id 22,23,24` | Specific sample IDs |
| `--sample-shuffle` | Randomize sample order |
| `--sample-shuffle 42` | Deterministic shuffle with seed |
| `--epochs 3` | Run each sample 3 times |
| `--epochs-reducer mean` | Reduce epoch scores with mean |

### Resource Limits (Per Sample)

| Flag | Env Var | Description |
|------|---------|-------------|
| `--message-limit` | `INSPECT_EVAL_MESSAGE_LIMIT` | Max messages per sample |
| `--token-limit` | `INSPECT_EVAL_TOKEN_LIMIT` | Max tokens per sample |
| `--time-limit` | `INSPECT_EVAL_TIME_LIMIT` | Wall-clock time limit (seconds) |
| `--working-limit` | `INSPECT_EVAL_WORKING_LIMIT` | Working time limit (excludes rate-limit waits) |

### Parallelism

| Flag | Default | Description |
|------|---------|-------------|
| `--max-samples` | `max_connections + 1` | Concurrent samples |
| `--max-tasks` | 1 (eval), 4 (eval-set) | Concurrent tasks |
| `--max-subprocesses` | `os.cpu_count()` | Concurrent subprocesses |
| `--max-sandboxes` | `2 * os.cpu_count()` | Concurrent sandboxes per provider |

### Error Handling

| Flag | Description |
|------|-------------|
| `--fail-on-error` | Fail immediately on any sample error (default) |
| `--no-fail-on-error` | Never fail on sample errors |
| `--fail-on-error=0.1` | Fail if >10% of samples error |
| `--fail-on-error=5` | Fail if >5 samples error |
| `--continue-on-fail` | Continue running even after failure threshold |
| `--retry-on-error` | Retry failed samples (default: 1 retry) |
| `--retry-on-error=3` | Retry up to 3 times |

### Logging

| Flag | Env Var | Default | Description |
|------|---------|---------|-------------|
| `--log-dir` | `INSPECT_LOG_DIR` | `./logs` | Log output directory |
| `--log-format` | `INSPECT_LOG_FORMAT` | `eval` | Format: `eval` (binary) or `json` |
| `--no-log-samples` | | | Omit sample data from logs |
| `--no-score` | | | Run without scoring |

### Sandbox Configuration

```bash
# Use Docker sandbox
inspect eval task.py --sandbox docker

# With custom compose file
inspect eval task.py --sandbox docker:compose.yaml

# Preserve containers for debugging
inspect eval task.py --sandbox docker --no-sandbox-cleanup

# Clean up sandboxes
inspect sandbox cleanup docker
```

### Tags and Metadata

```bash
inspect eval task.py --tags "experiment,v2" --metadata run_type=treatment
```

## Running Eval Sets

`eval-set` runs multiple task/model combinations with automatic retries:

```bash
inspect eval-set mmlu.py mathematics.py \
  --model openai/gpt-4,anthropic/claude-sonnet-4-0 \
  --log-dir logs-run-42
```

Re-running the same command resumes incomplete work. Additional eval-set flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--retry-attempts` | 10 | Max retry attempts |
| `--retry-wait` | 30 | Base wait seconds (exponential backoff) |
| `--retry-connections` | 1.0 | Connection reduction rate per retry |
| `--no-retry-cleanup` | | Preserve failed log files |

## Retrying Failed Evaluations

```bash
inspect eval-retry logs/2024-05-29T12-38-43_math_Gprr29Mv.eval
```

Preserves completed samples and only reruns failures.

## Python API

For programmatic execution:

```python
from inspect_ai import eval, eval_set, eval_retry

# Single evaluation
logs = eval(
    tasks="task.py",
    model="openai/gpt-4",
    limit=50,
    log_dir="./logs",
    max_samples=10,
    fail_on_error=0.1,
)

# Check status
for log in logs:
    if log.status == "success":
        print(f"Task: {log.eval.task}, Score: {log.results}")
    elif log.status == "error":
        print(f"Error: {log.error}")

# Eval set
success, logs = eval_set(
    tasks=["task1.py", "task2.py"],
    model=["openai/gpt-4", "anthropic/claude-sonnet-4-0"],
    log_dir="logs-run-42",
)

# Retry
eval_retry(log, max_connections=3)
```

## Task Structure

### Minimal Task

```python
from inspect_ai import Task, task
from inspect_ai.solver import generate
from inspect_ai.scorer import exact

@task
def my_task():
    return Task(
        dataset=[Sample(input="What is 2+2?", target="4")],
        solver=generate(),
        scorer=exact(),
    )
```

### Key Task Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `dataset` | `Dataset \| list[Sample]` | Samples to evaluate |
| `solver` | `Solver \| list[Solver]` | Processing pipeline (default: `generate()`) |
| `scorer` | `Scorer \| list[Scorer]` | How to score outputs |
| `sandbox` | `str \| tuple` | Sandbox environment (e.g., `"docker"`) |
| `epochs` | `int \| Epochs` | Times to repeat each sample |
| `message_limit` | `int` | Max messages per sample |
| `token_limit` | `int` | Max tokens per sample |
| `time_limit` | `int` | Wall-clock seconds per sample |
| `working_limit` | `int` | Working seconds per sample |
| `fail_on_error` | `bool \| float` | Error tolerance |
| `model` | `str \| Model` | Default model for this task |
| `config` | `GenerateConfig` | Default generation config |
| `model_roles` | `dict` | Named model roles |
| `metadata` | `dict` | Custom metadata |

### Datasets

```python
from inspect_ai.dataset import json_dataset, csv_dataset, hf_dataset, FieldSpec, Sample

# JSON/JSONL
dataset = json_dataset("data.jsonl", sample_fields=FieldSpec(
    input="question", target="answer", metadata=["category"]
))

# CSV
dataset = csv_dataset("data.csv")

# Hugging Face
dataset = hf_dataset("openai_humaneval", split="test", trust=True)

# Manual
dataset = [
    Sample(input="Q1", target="A1", id="1"),
    Sample(input="Q2", target="A2", id="2"),
]
```

Sample fields: `input` (required), `target`, `choices`, `id`, `metadata`, `sandbox`, `files`, `setup`.

### Solvers

```python
from inspect_ai.solver import (
    generate, chain_of_thought, system_message, user_message,
    prompt_template, use_tools, multiple_choice, self_critique,
)

# Chain solvers
solver = [
    system_message("You are a helpful assistant."),
    chain_of_thought(),
    generate(),
]

# With tools
from inspect_ai.tool import bash, python, web_search
solver = [
    use_tools([bash(timeout=180), python()]),
    generate(),
]
```

### Scorers

```python
from inspect_ai.scorer import (
    exact, includes, match, pattern, answer, choice,
    model_graded_qa, model_graded_fact, f1,
    accuracy, stderr, mean,
)

# Built-in text matching
scorer = exact()
scorer = includes()
scorer = match()

# Model-graded
scorer = model_graded_qa(
    model="openai/gpt-4",
    include_history=True,
    partial_credit=True,
)

# Multiple scorers
scorer = [
    model_graded_qa(model="openai/gpt-4"),
    model_graded_qa(model="anthropic/claude-sonnet-4-0"),
]
```

Score existing logs:
```bash
inspect score ./logs/eval.log --scorer match -S location=end
```

### Epochs and Reducers

```python
from inspect_ai.scorer import Epochs

# Simple
epochs = 3  # uses mean reducer by default

# With specific reducer
epochs = Epochs(5, reducer="mode")
epochs = Epochs(5, reducer=["at_least_2", "at_least_5"])
```

Built-in reducers: `mean`, `median`, `mode`, `max`, `pass_at_{k}`, `at_least_{k}`.

## Log System

### Log Formats

| Format | Extension | Size | Notes |
|--------|-----------|------|-------|
| eval | `.eval` | 1x (default) | Binary ZIP; fast; incremental sample access |
| json | `.json` | 5-8x | Human-readable; slow for large files |

### Log File Structure (.eval)

```
.eval (ZIP archive)
├── header.json          # Full eval metadata (written at finish)
├── summaries.json       # Sample summaries (written at finish)
├── reductions.json      # Multi-epoch reductions (optional)
├── _journal/
│   ├── start.json       # Initial spec and plan
│   ├── results.json     # Final results
│   └── summaries/       # Buffered summaries during execution
└── samples/
    ├── {id}_epoch_{n}.json  # Individual sample data
    └── ...
```

### Default Log Location

`./logs` relative to cwd. Configure via:
- CLI: `--log-dir ./my-logs`
- Env: `INSPECT_LOG_DIR=./my-logs`
- `.env` file: paths resolve relative to `.env` location

### File Naming Pattern

Default: `{timestamp}_{task}_{id}.eval`

Customize: `INSPECT_EVAL_LOG_FILE_PATTERN={task}_{model}_{id}`

### Reading Logs Programmatically

```python
from inspect_ai.log import (
    list_eval_logs,
    read_eval_log,
    read_eval_log_sample,
    read_eval_log_samples,
    read_eval_log_sample_summaries,
    write_eval_log,
)

# List all logs
logs = list_eval_logs(log_dir="./logs")

# Read full log
log = read_eval_log("path/to/log.eval")

# Read header only (fast for large logs)
log = read_eval_log("path/to/log.eval", header_only=True)

# Stream samples (memory-efficient)
for sample in read_eval_log_samples("path/to/log.eval"):
    process(sample)

# Read single sample
sample = read_eval_log_sample("path/to/log.eval", id=42, epoch=1)

# Sample summaries (lightweight)
summaries = read_eval_log_sample_summaries("path/to/log.eval")
```

### EvalLog Structure

```
EvalLog:
  version: int              # Format version (currently 2)
  status: str               # "started" | "success" | "cancelled" | "error"
  eval: EvalSpec            # Task, model, dataset metadata
  plan: EvalPlan            # Solvers and generation config
  results: EvalResults      # Aggregate scoring metrics
  stats: EvalStats          # Token usage and timing
  error: EvalError | None   # Error info if status == "error"
  samples: list[EvalSample] # All evaluated samples
  location: str             # File URI
```

### EvalSample Structure

```
EvalSample:
  id: str | int             # Sample identifier
  epoch: int                # Epoch number
  input: str | list[msg]    # Original input
  target: str | list[str]   # Expected output
  messages: list[msg]       # Full conversation history
  output: ModelOutput       # Model's final output
  scores: dict[str, Score]  # Scorer results
  metadata: dict            # Custom sample metadata
  model_usage: dict         # Token usage per model
  total_time: float         # Total execution time
  working_time: float       # Working time (excludes waits)
  error: EvalError | None   # Error if sample failed
  limit: str | None         # Limit that halted sample
```

## Sandbox Environments

### Docker (Built-in)

Docker auto-discovers configuration by searching the task directory:
- No config → uses standard `inspect-tool-support` image
- `Dockerfile` present → builds custom image
- `compose.yaml` present → uses compose configuration

Minimal compose.yaml:
```yaml
services:
  default:
    build: .
    init: true
    command: tail -f /dev/null
    cpus: 1.0
    mem_limit: 0.5gb
    network_mode: none
```

Key directives:
- `init: true` — graceful shutdown
- `command: tail -f /dev/null` — keeps container running
- `network_mode: none` — network isolation (blocks internet)

Multiple sandboxes:
```yaml
services:
  default:
    image: attacker-env
    x-local: true
    init: true
  victim:
    image: victim-env
    x-local: true
    init: true
```

### Debugging Sandboxes

```bash
# Preserve containers after eval
inspect eval task.py --no-sandbox-cleanup

# Access container
docker exec -it inspect-task-ielnkhh-default-1 bash -l

# Clean up
inspect sandbox cleanup docker
```

### Diagnostics

```bash
inspect trace anomalies <logfile>
```

## Important Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INSPECT_EVAL_MODEL` | (none) | Default model |
| `INSPECT_LOG_DIR` | `./logs` | Log directory |
| `INSPECT_LOG_FORMAT` | `eval` | Log format |
| `INSPECT_LOG_LEVEL` | `warning` | Console log level |
| `INSPECT_EVAL_MAX_CONNECTIONS` | `10` | Max API connections |
| `INSPECT_EVAL_LOG_FILE_PATTERN` | `{task}_{id}` | Log file naming |
| `INSPECT_EVAL_LOG_IMAGES` | `true` | Include base64 images in logs |

## Common Gotchas

1. **Sample IDs for retries**: Shuffled datasets break sample reuse on retry unless samples have explicit `id` fields.
2. **Relative .env paths**: Paths in `.env` resolve relative to the `.env` file, not the cwd.
3. **Multiple choice**: Target must be a capital letter (A, B, C, D). Do NOT include `generate()` separately when using `multiple_choice()` solver.
4. **Model access timing**: Call `get_model(role="grader")` inside solver/scorer functions, not at module initialization.
5. **Working vs clock time**: Use `working_limit` for fair comparisons (excludes rate-limit waits and infrastructure delays).
6. **Large log files**: Use `header_only=True` or `read_eval_log_samples()` generator for >50MB JSON logs.
7. **Distribution shift**: Retried samples may have different success rates than non-retried ones.
8. **Rate limit recovery**: Reduce `max_connections` on retry: `eval_retry(log, max_connections=3)`.
9. **Sandbox network**: `network_mode: none` blocks all internet access by default.
10. **Async requirement**: All solver/scorer functions must be `async def`; model calls need `await`.
