# Inspect AI Reference for the Experiment Executor

This document captures the stable semantic and pattern-level content an Experiment Executor needs to run evaluations in Inspect AI. It deliberately does **not** include exhaustive flag listings, per-flag syntax tables, or argument defaults — these drift between Inspect versions and are better obtained from the installed CLI itself.

**For flag-specific questions, consult `--help` on the installed Inspect version:**

```bash
uv run inspect eval --help
uv run inspect log list --help
uv run inspect sandbox --help
```

The reference doc tells you *what* to do and *why*. `--help` tells you *how to spell it* on this installation.

---

## Running Evaluations

The Executor runs evaluations exclusively via the CLI wrapper `uv run inspect eval ...`. The Python API (`from inspect_ai import eval`) is not used by this scaffold.

### Invocation patterns

Three patterns cover every investigation this scaffold supports:

- **Pattern A — Same task file, different task arguments.** Pass per-condition values via `-T key=value`. Preferred when the task is already parameterised (e.g., `-T system=system_prompt_control.txt` vs. `-T system=system_prompt_treatment.txt`). Minimises the number of task files to keep coherent.
- **Pattern B — Different task files per condition.** One task file per condition, all invoked with the same flags but different paths. Used when conditions differ structurally (different solvers, different datasets).
- **Pattern C — Same task, different models.** One task file, `--model` varied across invocations. Used when the manipulated variable is the model itself.

Patterns A and B can combine with Pattern C: every condition runs against every model the orchestrator requested.

### Policy flags the Executor applies to every invocation

These flags are policy, not configuration. They are not in the request's `overrides` — the Executor sets them unconditionally. Check the current spelling of each via `--help`:

- `--display none` — headless operation (no TTY output)
- `--log-dir <experiment_dir>/logs/<condition_name>/` — per-condition log organisation
- `--tags "exp:<experiment_name>,cond:<condition_name>"` — namespaced tags avoid substring ambiguity
- `--metadata condition=<condition_name> --metadata model=<model_string>` — embeds condition label in the log file itself (load-bearing: provides redundancy against later file reorganisation)
- `--no-fail-on-error` — sample errors do not abort the eval
- `--retry-on-error 3` — Inspect retries errored samples up to 3 times inside the eval
- Any `overrides` from the request (`--limit`, `--epochs`, `--max-connections`)

### Metadata convention

Two pieces of metadata are attached to every log:

- `condition=<condition_name>` — the snake_case identifier from the orchestrator's request
- `model=<model_string>` — the full `provider/model-name` string

This is redundant with the log directory structure and the tag, and that is intentional. The Analyst downstream may reorganise logs by metadata rather than by path, and the label must survive such reorganisation. Do not omit these `--metadata` flags even if the log path seems sufficient.

---

## Parallelism semantics

Inspect has **four** nested concurrency dimensions; understanding them matters for the Concurrency Decision step because they multiply:

| Dimension | Meaning | Set by |
|---|---|---|
| `--max-samples` | Concurrent samples within a single eval | Orchestrator override or inherited default |
| `--max-tasks` | Concurrent tasks within a single `inspect eval` process | Usually 1 for `eval` (not used here) |
| `--max-connections` | Concurrent API calls within a single eval | Orchestrator override or Inspect default |
| `--max-sandboxes` | Concurrent sandbox containers per provider (e.g., Docker) | Default: `2 * os.cpu_count()` |

The Executor also manages a **fifth** dimension externally: `max_parallel` eval subprocesses (distinct `inspect eval` processes launched by `execute_evals.py`). Total load on the machine and on the APIs multiplies across all five.

Sandbox pool is the most common bottleneck: multiple parallel evals all share the same `2 * cpu_count` sandbox slots per provider. If you launch 4 parallel sandbox-based evals with `max_samples=10` each, you are asking for 40 sandboxes from a pool of ~16 on an 8-core machine — contention, timeouts, and cascading failures follow.

### Concurrency heuristics

- **API-only evals (no sandbox)**: `max_parallel` up to the number of condition-model pairs is usually safe; provider rate limits tend to be the binding constraint.
- **Sandbox-based evals**: start conservative (`max_parallel: 2`) and only increase if a concurrency preflight passes. Sandbox setup takes 10–30s; API-only preflight takes 1–3s — use the preflight duration as a sandbox detector.
- **When in doubt**: run sequentially. A slow complete run beats a fast cascade of resource failures.

---

## Sandbox environments

### Docker auto-discovery

Inspect's Docker sandbox discovers configuration by searching the task directory:

- No config file → uses the standard `inspect-tool-support` image
- `Dockerfile` present → builds a custom image
- `compose.yaml` present → uses the compose configuration

Typical minimal `compose.yaml`:

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

Three directives worth recognising when diagnosing sandbox issues:

- `init: true` — graceful shutdown handling
- `command: tail -f /dev/null` — keeps the container alive for the eval's duration
- `network_mode: none` — blocks internet access (default isolation posture)

### Multi-sandbox patterns

Some evals define multiple sandbox services (e.g., attacker and victim containers):

```yaml
services:
  default:
    image: attacker-env
    x-local: true
  victim:
    image: victim-env
    x-local: true
```

Both sandboxes count against the pool per invocation.

### Sandbox debugging

If a sandbox failure persists across retries (structural failure), the typical recovery sequence is:

```bash
inspect sandbox cleanup docker    # clear stale containers
docker ps -a                       # check for orphans
docker system df                   # check for space pressure
```

The Executor does not take these recovery actions itself — it reports the structural failure with evidence; the orchestrator decides whether sandbox cleanup is warranted.

---

## Log system

### File format

Inspect's default log format is `.eval` (a binary ZIP archive), not JSON. JSON logs exist but are 5–8× larger and slower to work with. The Executor uses the default `.eval` format.

The `.eval` archive contains:

- `header.json` — full eval metadata (written at finish)
- `summaries.json` — per-sample summaries (written at finish)
- `reductions.json` — multi-epoch reductions (optional)
- `_journal/` — start spec, final results, buffered summaries during execution
- `samples/{id}_epoch_{n}.json` — individual sample data

Reading `summaries.json` is sufficient for the transcript termination metadata the Executor needs; full sample content is not required.

### Log file naming

Default pattern: `{timestamp}_{task}_{id}.eval`. Path organisation under `<experiment_dir>/logs/<condition>/` is the Executor's responsibility, not Inspect's; always pass `--log-dir` explicitly rather than relying on defaults.

### EvalLog structure (at the Executor's level of need)

The Executor cares about:

- `status`: `"started"` | `"success"` | `"cancelled"` | `"error"`
- `samples[].error`: populated when an individual sample errored
- `samples[].limit`: populated when a sample hit a token / message / time / working limit
- `samples[].messages`: presence and contents of assistant-role messages (for no-assistant-msg detection)

Sample summaries (obtained via `read_eval_log_sample_summaries` or the CLI equivalent — check `--help`) are the right level of access: richer than the log header, cheaper than reading full samples.

### Transcript termination metadata

For each condition-model pair, the Executor counts:

- **No-assistant-msg transcripts** — samples whose message list contains no assistant-role messages
- **Limit-hit transcripts** — samples whose `limit` field is set (token, message, time, or working limit)
- **Error-terminated transcripts** — samples whose `error` field is set

These three categories are not mutually exclusive (a sample can both hit a limit and terminate with an error); the Executor reports each count independently.

---

## Error handling semantics

### `--fail-on-error` vs `--retry-on-error`

These two flags govern different behaviours that are easy to conflate:

- `--fail-on-error` controls when an eval **stops**. Default is to stop on any sample error; `--no-fail-on-error` lets the eval complete with sample errors present. The Executor always uses `--no-fail-on-error` because silent stopping would hide sample-level errors.
- `--retry-on-error` controls how Inspect handles sample errors **while the eval continues**. It re-runs errored samples inline, up to a budget (default 1). The Executor uses `--retry-on-error 3` — a balance between absorbing transient sample failures and terminating on deterministic ones.

### Sample-retry distribution shift

When `--retry-on-error` fires, the retried sample's transcript was generated on an attempt conditioned on a prior failure. This introduces a subtle selection effect: retried transcripts may differ systematically from first-attempt transcripts (e.g., the first attempt hit a content filter; the retry happened to phrase things differently and succeeded).

The Executor surfaces per-pair retry counts in the Execution Matrix so the orchestrator can flag this to the Analyst. The Executor does not suppress retries — doing so would convert distribution shift into silent attrition, which is strictly worse.

### Transient vs structural

These two error classes require different responses (see `executor_interface_contract.md §Error Taxonomy`):

- **Transient** errors are absorbed by process-level retries inside `execute_evals.py` (rate limits, transient network failures, provider 500s). The eval ultimately succeeds.
- **Structural** errors persist across retries (ImportError from a bad modification, missing API key, Docker daemon down). Re-running without intervention does not help.

The three-category taxonomy is defined operationally in the contract; the Executor applies it by observable criteria, not by guessing cause.

---

## Common gotchas

1. **Sample IDs for retries.** Shuffled datasets break sample reuse on retry unless samples have explicit `id` fields. Check the task's dataset construction if retries produce unexpected sample identities.
2. **Relative `.env` paths.** Paths in `.env` resolve relative to the `.env` file, not the current working directory. Relevant when the Executor's cwd differs from the task file's location.
3. **Model access timing.** For tasks that call `get_model(role="grader")`, this must happen inside solver/scorer functions, not at module initialisation. Tasks that violate this fail at preflight with an error that surfaces as structural.
4. **Working time vs clock time.** `working_limit` excludes rate-limit waits and infrastructure delays; `time_limit` is wall-clock. For fair cross-condition comparisons, task authors prefer `working_limit`; for the Executor, the difference matters when diagnosing whether a limit-hit transcript reflects slow generation or slow infrastructure.
5. **Large log files.** If the Executor needs to stream sample summaries from unusually large logs, use a summary-level reader rather than loading the full `.eval`. Check `--help` for the current API.
6. **Rate limit recovery.** When the process-management wrapper retries a subprocess after a rate-limit failure, it reduces `max_connections` for the retry (`eval_retry(log, max_connections=3)` equivalent). This is handled internally by the wrapper.
7. **Sandbox network isolation.** `network_mode: none` in the compose file blocks all internet access by default. Tasks that require network access must declare this explicitly in their compose file.
8. **Async requirements.** All solver and scorer functions must be `async def`; model calls need `await`. Violations fail at preflight and surface as structural.

---

## What is deliberately not in this document

- **Flag tables** (generation parameters, sample selection, resource limits, logging flags). These drift across Inspect versions. Use `uv run inspect eval --help` instead.
- **Python API details** (`from inspect_ai import eval` and related). The Executor uses the CLI exclusively.
- **Task / Dataset / Solver / Scorer construction.** This is the Explorer's and task-author's concern, not the Executor's.
- **`eval-set` and `eval-retry` workflows.** The Executor uses `eval` and manages retries externally via `execute_evals.py`.

If you need one of these and it is not in `--help`, escalate via Additional Notes in your execution report rather than guessing.
