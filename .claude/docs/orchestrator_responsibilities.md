# Orchestrator Responsibilities

This document specifies everything the orchestrator (main Claude Code agent) must do to drive the experimental pipeline. It covers every handoff, every piece of work that falls between sub-agents, and every decision point where the orchestrator must exercise judgment.

## Role

The orchestrator is the only agent that talks to the user, holds the hypothesis, and makes scientific decisions. It delegates mechanical work to three sub-agents:

| Agent | Receives | Returns |
|-------|----------|---------|
| Environment Explorer | Hypothesis, experiment description, environment path | Structured report: file catalogue, modification sites with diffs, recommended conditions with activation parameters, risk assessment |
| Experiment Executor | Experiment directory, condition specs, models, execution overrides | Execution report: log paths, status per condition-model pair, errors, retry flags |
| Transcript Analyst | Topic (not hypothesis), transcript source (condition→path mapping), scanning model?, constraints? | Scanner definitions, validation metrics, quantified results, scan results path, transcript exclusions, excerpts |

The orchestrator does everything else.

## Pipeline Overview

```
Phase 1: Scoping Discussion (with user)
    ↓
Phase 2: Investigation Loop (autonomous, may repeat)
    ├── 2a. Launch Environment Explorer
    ├── 2b. Review Explorer report and decide on conditions
    ├── 2c. Create experiment directory and apply modifications
    ├── 2d. Construct Executor input and launch Executor
    ├── 2e. Review Executor report and handle failures
    ├── 2f. Translate hypothesis → neutral topic
    ├── 2g. Launch Transcript Analyst
    ├── 2h. Sanity-check Analyst report
    ├── 2i. Interpret Analyst findings against hypothesis
    └── 2j. Decide: iterate, conclude, or escalate to user
    ↓
Phase 3: Report to User
```

---

## Phase 1: Scoping Discussion

### What happens

The user presents a research question. The orchestrator helps refine it into a testable hypothesis and gathers the information needed to begin investigation.

### Orchestrator responsibilities

1. **Refine the hypothesis.** Help the user articulate a specific, testable hypothesis. A good hypothesis names a specific independent variable (what changes between conditions), a dependent variable (what is measured), and a direction (what the expected effect is). A vague question like "does the system prompt matter?" is not yet a hypothesis.

   **Methodological checks** (see `eval_science_principles.md`):
   - *Falsifiability*: Can you state what outcome would make this hypothesis wrong? If not, it is not ready to test.
   - *Competing hypotheses*: What alternative explanations exist for the predicted outcome? A good investigation cycle eliminates at least one alternative, not just accumulates evidence for the favoured hypothesis.
   - *Eval awareness*: If this is an alignment or safety evaluation, flag evaluation awareness as a default competing hypothesis. The observed behaviour may be driven by the model detecting the evaluation context rather than by the manipulated variable.

2. **Identify the eval environment.** Determine the path to the evaluation environment that will be used. Confirm it exists and contains task files.

   **Methodological check** (see `eval_science_principles.md`):
   - *Five validity questions*: (1) What construct does this evaluation claim to measure? (2) Do the items actually test for it? (3) Does the setting resemble real deployment? (4) Would a different evaluation of the same construct agree? (5) Could it be measuring something else entirely? Document the answers — validity gaps are themselves findings about the evaluation.

3. **Determine models.** Agree with the user on which model(s) to evaluate. Record the exact `provider/model-name` strings.

4. **Set execution parameters.** Discuss with the user:
   - Sample limit (full dataset or a subset for rapid iteration?)
   - Number of epochs per sample
   - Whether to skip preflight validation
   - Any other Inspect CLI overrides

5. **Initialize the investigation log.** Create `investigation-log.md` in the experiment's parent directory to track state across iterations (see State Management below).

### What can go wrong

- The user's hypothesis is too vague or tests multiple variables simultaneously. Push for specificity.
- The eval environment path doesn't exist or is empty. Verify before proceeding.
- The user wants to test a model the orchestrator doesn't have API access to. Verify model accessibility early (or let the Executor's preflight catch it).

---

## Phase 2: Investigation Loop

### Step 2a: Launch Environment Explorer

**Input to Explorer:**
- Experiment description (plain English)
- Hypothesis (specific, testable)
- Environment path (directory containing the eval)

**Orchestrator work:**
- Construct the Explorer input JSON and launch via CLI script (see `subagent_invocation.md`).
- The hypothesis IS passed to the Explorer — this is the one agent that receives it directly. (The Transcript Analyst must NOT receive it.)
- Save the Explorer's stdout report to `<experiment_dir>/artefacts/explorer/report.md`.

**What can go wrong:**
- The Explorer reports that the hypothesis is untestable with the given environment (e.g., the eval doesn't have the right structure). Report to user and revise.
- The Explorer reports that the environment path is empty or unreadable. Check the path and retry.

---

### Step 2b: Review Explorer Report

**What the orchestrator receives:**
- File catalogue (all files, their types and roles)
- Modification sites with diffs (before/after text, line numbers)
- Recommended experimental conditions table (condition names, variant choices per site)
- Condition activation parameters table (which parameters or files to vary per condition)
- Risk assessment (confounds, cross-file interactions, information leakage, scoring concerns, ecological validity)

**Orchestrator work:**

1. **Review the risk assessment.** If the Explorer flagged confounds, information leakage, or scoring risks, decide whether to accept, mitigate, or reject the proposed design. If risks are severe, consider revising the hypothesis or the approach before proceeding.

2. **Check for dirty paraphrases** (see `eval_science_principles.md`). Review each proposed diff and ask: does this modification change only the intended variable, or does it simultaneously alter formatting, length, style, or other incidental properties? Any modification to an evaluation simultaneously modifies its formatting properties. If the diff changes more than one thing, consider whether a cleaner manipulation exists or whether a placebo condition (same magnitude of change, orthogonal content) is needed to distinguish content effects from perturbation effects.

3. **Select conditions.** If the Explorer proposed multiple variant options or additional arms beyond control/treatment, decide which to implement. More conditions means more eval runs (cost and time).

4. **Review condition activation parameters.** Confirm the table makes sense:
   - If conditions differ by task parameters: note the parameter names and values. These become `-T` flags.
   - If conditions differ by task file: note the separate file paths. The orchestrator will need to create these files.
   - If conditions differ by model only: note that the Executor just varies `--model`.

5. **Review cross-file interactions.** If the Explorer flagged coordinated changes across multiple files, plan to apply all of them together. Missing one could introduce confounds or break the eval.

6. **Consider evaluation item quality** (see `eval_science_principles.md`). Before attributing model behaviour to the construct under study, check whether the evaluation items are well-formed. Roughly 9% of items in well-known benchmarks contain errors. If the Explorer flagged scoring or task validity concerns, factor these into the experimental design — they may explain more of the variance than the intended manipulation.

**What can go wrong:**
- The Explorer's proposed diffs are ambiguous or reference files that have changed since it read them. Re-read the files and verify the diffs still apply.
- The condition activation parameters don't clearly map to Inspect invocations. The orchestrator may need to read the task file to understand its parameterization.

---

### Step 2c: Create Experiment Directory and Apply Modifications

This is entirely the orchestrator's work. No sub-agent handles this.

**Methodological check** (see `eval_science_principles.md`): Evaluation flaws should be characterised, not fixed. Do not clean up the evaluation environment before studying it — that changes the object of study. If you notice flaws (ambiguous items, broken scoring, unrealistic scenarios), document them as potential confounds but leave them in place. The flaw itself may be driving the behavioural variation, and that discovery is a contribution.

**Orchestrator work:**

1. **Create an experiment directory.** Copy the eval environment to a new, isolated directory for this experiment. Convention:
   ```
   <parent>/<experiment_name>/
   ```
   where `<experiment_name>` is a descriptive snake_case identifier (e.g., `explicit_goal_framing_v1`). This preserves the original eval environment and allows clean restarts for new iterations.

   If iterating on a previous experiment, create a new directory (e.g., `explicit_goal_framing_v2`) rather than modifying the previous one. Previous experiment directories are evidence and should not be altered.

   **Create an artefacts directory** within the experiment directory:
   ```
   <parent>/<experiment_name>/artefacts/
   ```
   This directory is passed to sub-agents that produce file outputs. Each sub-agent creates its own subdirectory (e.g., `artefacts/analyst/`). The orchestrator saves stdout reports from sub-agents that cannot write files themselves (the Environment Explorer) to `artefacts/explorer/report.md`.

2. **Apply the Explorer's diffs.** For each modification site in each condition:
   - If using **parameter-based conditions** (Pattern A): apply any shared modifications that are common to all conditions, then rely on different `-T` values to activate each condition at runtime. This may involve creating condition-specific copies of files referenced by the parameter (e.g., `system_prompt_control.txt`, `system_prompt_treatment.txt`).
   - If using **separate task files** (Pattern B): create a copy of the task file for each condition, applying the relevant diffs to each copy. Name them with the condition name (e.g., `task_control.py`, `task_treatment.py`).
   - If using **model variation only** (Pattern C): no file modifications needed beyond any shared setup.

3. **Verify the modifications.** Read each modified file back and confirm the changes match the Explorer's diffs. This catches copy/paste errors and merge conflicts.

4. **Handle cross-file dependencies.** Apply all coordinated changes flagged by the Explorer. If the Explorer said "changing the system prompt at Site 1 requires updating the scoring rubric at Site 2," both must be applied.

**What can go wrong:**
- The Explorer's diffs don't apply cleanly (e.g., the "before" text doesn't match what's in the file because of whitespace or encoding differences). Manually inspect and adapt.
- The experiment directory copy fails because of large data files or symlinks. Use the appropriate copy strategy (e.g., symlink data files rather than copying them).
- For iteration 2+, the orchestrator accidentally modifies the previous iteration's directory. Always create a new directory.

---

### Step 2d: Construct Executor Input and Launch Executor

**Orchestrator work:**

1. **Build the condition specification.** Using the Explorer's condition activation parameters table, construct a mapping for each condition:
   - Condition name (snake_case, from Explorer)
   - Task file path (relative to experiment directory)
   - Task arguments (`-T` key=value pairs that differ between conditions)

2. **Assemble the Executor input JSON** (see `subagent_invocation.md` for the full schema):
   - `experiment_name`: snake_case identifier (used in `--tags "exp:<name>"`)
   - `experiment_dir`: parent experiment directory path
   - `conditions`: the mapping from step 1 above
   - `models`: list of `provider/model-name` strings
   - `overrides` (optional): `sample_limit`, `epochs`, `skip_preflight`, `max_connections`, `runs_per_condition`

3. **Launch the Experiment Executor sub-agent** via CLI script (see `subagent_invocation.md`).

4. **Save the Executor's stdout report** to `<experiment_dir>/artefacts/executor/report.md`.

**Example input JSON:**
```json
{
    "experiment_name": "explicit_goal_framing",
    "experiment_dir": "/path/to/explicit_goal_framing_v1/",
    "conditions": {
        "control": {"task": "task.py", "args": {"system": "system_prompt_control.txt"}},
        "treatment": {"task": "task.py", "args": {"system": "system_prompt_treatment.txt"}}
    },
    "models": ["anthropic/claude-sonnet-4-5-20250929"],
    "overrides": {"sample_limit": 50, "epochs": 1, "skip_preflight": false}
}
```

**What can go wrong:**
- The orchestrator passes a task file path that doesn't exist in the experiment directory. Double-check paths before launching.
- The orchestrator forgets to include an execution parameter that was discussed with the user. Refer to the investigation log.

---

### Step 2e: Review Executor Report

**What the orchestrator receives:**
- Parent log directory path
- Table: condition-model pairs → log paths, status, samples completed/total, retries, duration
- Error summary (transient recovered, sample-level errors, structural failures)
- Retry flags (which condition-model pairs have retried samples)
- Execution summary (total attempted, completed, failed)

**Orchestrator work:**

1. **Check for complete success.** If all condition-model pairs completed with status "success" and no sample errors, proceed to the Analyst.

2. **Handle partial failures.** If some conditions failed:
   - If failures are symmetric across conditions (both control and treatment lost similar proportions), the data may still be usable but note this for the Analyst.
   - If failures are asymmetric (one condition failed significantly more than another), this is a potential confound. Consider re-running the failed pairs or reporting the asymmetry to the user.
   - For structural failures, diagnose the root cause. It may indicate a problem with the modifications applied in Step 2c.

3. **Handle total failure.** If all conditions failed, do not proceed to the Analyst. Diagnose the issue (check the Executor's error details), fix if possible, and re-run. If the problem is unfixable, escalate to the user.

4. **Note retry flags.** If any condition-model pairs had retried samples, record this. The Transcript Analyst's report should be read with awareness that retried samples may exhibit distribution shift (retried samples may have different characteristics than non-retried ones).

5. **Record in investigation log.** Update the investigation log with execution results.

**What can go wrong:**
- The Executor's report is ambiguous about whether a failure is structural or transient. Read the error details carefully.
- The log paths in the report don't exist (Executor bug). Verify log paths exist before passing them to the Analyst.

---

### Step 2f: Translate Hypothesis to Neutral Topic

This is the orchestrator's most important cognitive task. The Transcript Analyst must never receive the hypothesis. It receives only a neutral topic.

**Translation rules:**

1. **Strip directionality.** Remove words like "increases," "decreases," "improves," "reduces," "more," "less."
2. **Strip mechanism claims.** Remove "because," "due to," "by causing," "leads to."
3. **Keep the domain.** The topic should cover the same behavioral space as the hypothesis.
4. **Keep it open-ended.** The topic should allow the Analyst to find patterns in either direction (or no direction).
5. **Don't smuggle the hypothesis.** Avoid loaded language that implies an expected direction.

**Examples:**

| Hypothesis | BAD Topic | GOOD Topic |
|------------|-----------|------------|
| "Explicit goal framing increases deceptive behavior" | "Whether explicit goals cause deception" | "How the model reasons about and frames its goals across conditions" |
| "Chain-of-thought prompting improves accuracy on reasoning tasks" | "Whether CoT helps with reasoning" | "Differences in response structure and problem-solving approach across conditions" |
| "System prompt persona framing increases refusal rates" | "How persona affects refusals" | "Response patterns and refusal behaviour across conditions" |
| "Models are more sycophantic when told the user is an expert" | "Sycophancy toward experts" | "How the model adjusts its communication style based on user context" |

**Self-check:** After writing the topic, ask: "If I read only this topic and knew nothing about the hypothesis, would I be biased toward finding any particular pattern?" If yes, revise.

---

### Step 2g: Launch Transcript Analyst

**Orchestrator work:**

1. **Construct the request** following the format in `analyst_interface_contract.md`:
   - **Topic**: The neutral topic from Step 2f.
   - **Transcript source**: A mapping from opaque condition labels to log directory paths (e.g., `{"condition_A": "<experiment_dir>/logs/control/", "condition_B": "<experiment_dir>/logs/treatment/"}`). Randomise the mapping between condition labels and actual conditions.
   - **Scanning model** (optional): Override the default scanning model if needed.
   - **Constraints** (optional): Limit transcript count, concurrency, etc.
   - **Artefacts directory**: Pass `<experiment_dir>/artefacts/` so the analyst writes its outputs to `<experiment_dir>/artefacts/analyst/`.

2. **Launch the Transcript Analyst sub-agent** via CLI script (see `subagent_invocation.md`).

3. **After the Analyst returns**, review the scan results path provided in the report for sanity-checking summary statistics.

**What can go wrong:**
- The log directories contain no `.eval` files (e.g., the Executor put logs in a different location than reported). Verify the paths contain logs before launching.
- The condition labels leak the experimental design (e.g., using "control" and "treatment" instead of opaque labels). Always use condition_A, condition_B, etc.
- The topic accidentally contains hypothesis-leaking language. Re-read the topic one more time before launching. See `analyst_delegation_guide.md` for detailed guidance.

---

### Step 2h: Sanity-Check Analyst Report

**What the orchestrator receives** (see `analyst_interface_contract.md` for full format):
- Scanner definitions (names, types, questions/patterns)
- Validation metrics (balanced accuracy, precision, recall, F1 per scanner)
- Quantified results (per-condition detection rates and distributions)
- Scan results path (for sanity-checking summary statistics)
- Transcript exclusions (counts and reasons, by condition)
- Transcript excerpts (illustrative message references)
- Additional observations

**Orchestrator work:**

Before interpreting findings, run lightweight consistency checks. See `analyst_delegation_guide.md` for detailed guidance on checking validation metrics, completion rate balance, metadata imbalances, and scanner design artefacts.

1. **Verify summary statistics.** Do per-condition counts sum to the total? Are detection rates arithmetically consistent with the raw counts reported?
2. **Check validation metrics.** Are scanner precision and recall adequate? Factor imprecision into any downstream interpretation.
3. **Check for differential attrition.** Are transcript exclusion counts balanced across conditions?

---

### Step 2i: Interpret Analyst Findings

**Orchestrator work:**

1. **Read the full report.** Do not skim. The Analyst's report is structured to prevent cherry-picking — outliers and limitations are given equal weight.

2. **State the null hypothesis and simplest alternative before interpreting** (see `eval_science_principles.md`). What would you expect if the manipulated variable had no effect? What would you expect if the observed effect were due to a confound (e.g., formatting differences, eval awareness) rather than the intended manipulation? Write these down in the investigation log before reading the Analyst's quantified results. This prevents post-hoc rationalisation.

3. **Map patterns to the hypothesis.** For each pattern the Analyst observed, consider:
   - Does this pattern relate to the hypothesis? (Some patterns may be interesting but irrelevant.)
   - Does it support the hypothesis, contradict it, or is it ambiguous?
   - How strong is the evidence? (How many transcripts? What percentage?)

4. **Check for unexpected findings.** The Analyst may have found patterns the orchestrator didn't anticipate. These are valuable — they may suggest alternative hypotheses or confounds.

5. **Use mechanistic language** (see `eval_science_principles.md`). Describe what models produced under what conditions. Do not attribute intent or knowledge ("the model recognised it was being tested"). Mentalistic language is a conclusion that requires systematic exclusion of simpler explanations — it is almost never warranted at this stage.

6. **Quantified patterns are evidence; individual transcripts are anecdotes.** The Analyst provides transcript excerpts for context, but no conclusion should rest on an individual excerpt. Cite detection rates and validation metrics, not striking examples.

7. **Consider the limitations.** If the Analyst flagged sampling limitations, ambiguous cases, or insufficient evidence, factor this into interpretation.

8. **Consider the Executor's retry flags.** If retried samples exist, the Analyst's patterns might be influenced by distribution shift. Note this caveat.

9. **Record in investigation log.** Update with key findings, interpretation, and any new questions raised.

---

### Step 2j: Decide Next Action

**Options:**

1. **Conclude.** The findings are clear enough to report. Proceed to Phase 3.

2. **Iterate with refined hypothesis.** The findings suggest a more specific or different hypothesis worth testing. Go back to Step 2a with a new hypothesis, potentially using the same eval environment.

3. **Iterate with different execution parameters.** The findings are promising but the sample size was too small, or more epochs are needed. Go back to Step 2d with different parameters (same conditions, same modifications).

4. **Iterate with additional conditions.** The findings suggest a confound or an unexplored variable. Go back to Step 2a asking the Explorer for additional conditions.

5. **Escalate to user.** The findings are ambiguous, the orchestrator is unsure how to proceed, or the investigation has reached the limits of what's useful without human judgment. Present what's been found and ask for direction.

**Methodological checks before deciding** (see `eval_science_principles.md`):
- *Track epistemic state*: Update the investigation log with which hypotheses survive, which are eliminated, and which remain untested. This prevents narrative drift — the temptation to smooth over ambiguity and present a cleaner story than the evidence supports.
- *Check for technique attachment*: If you are iterating with the same kind of manipulation (e.g., another prompt-level cue variation), ask whether the research question demands it or whether a familiar method has become the default. The method should follow the question.
- *Label hypothesis provenance*: If this iteration's findings are generating the hypothesis for the next iteration, that next hypothesis is not independent of the data. Label it as hypothesis-generating rather than hypothesis-testing, and flag this in the investigation log.

**Decision criteria:**
- If after 3 iterations the findings are still ambiguous, escalate to user rather than continuing to iterate.
- If the investigation has consumed significant compute, check with the user before continuing.
- If the Analyst's report contradicts the hypothesis cleanly, that IS a finding worth reporting — do not iterate just because the result wasn't what was expected.
- If you are tempted to iterate because the result "didn't work," check whether you are engaging in optional stopping — running cycles until you find a desired result. All cycles, including null results, must be reported.

---

## Phase 3: Report to User

**Orchestrator work:**

1. **Synthesize across iterations.** If multiple iterations occurred, present the arc: what was hypothesized, what was tried, what was found, and how understanding evolved.

2. **Present findings in context.** Connect the Analyst's observations back to the hypothesis. Use the Analyst's language (descriptive, not causal) and cite the same agent run IDs.

3. **Distinguish evidence strength.** Be clear about whether findings are strong (large effect, consistent across transcripts), moderate (present but variable), or weak (observed in a few cases, potentially noise).

4. **Provide the scan results path.** The user can drill into specific transcripts using the raw scan results.

5. **Acknowledge limitations.** Surface the Analyst's limitations section and any caveats from the Executor (retry flags, asymmetric failures).

6. **Check for narrative coherence** (see `eval_science_principles.md`). If the report reads like a clean story where each iteration builds naturally on the last, this is a warning sign. Check whether contradictions, ambiguities, or null results have been smoothed over. A messy but honest account is more valuable than a tidy but misleading one.

7. **Suggest next steps** (if appropriate). This might include: running with more samples, testing on different models, exploring a related hypothesis, or refining the eval environment.

---

## State Management

### Investigation Log

The orchestrator maintains `investigation-log.md` in the experiment's parent directory. It is updated at every decision point. Structure:

```markdown
# Investigation Log: <Experiment Name>

## Hypothesis
<current hypothesis>

## Configuration
- Models: <list>
- Eval environment: <path>
- Execution parameters: <details>

## Iteration 1
### Explorer Report Summary
- Conditions proposed: <list>
- Key risks flagged: <summary>
- Conditions selected: <list>

### Modifications Applied
- Experiment directory: <path>
- Files modified: <list with brief descriptions>

### Executor Results
- Condition-model pairs: <completed/total>
- Key errors: <summary>
- Retry flags: <any>
- Log directory: <path>

### Analyst Findings
- Scan results path: <path>
- Key patterns: <summary>
- Supports/contradicts/ambiguous: <assessment>

### Decision
<iterate/conclude/escalate> — <reasoning>

## Iteration 2
[same structure]
```

### Why state management matters

- **Context window pressure.** The orchestrator's conversation will grow across iterations. The investigation log provides a durable summary that survives context compaction.
- **Auditability.** The user (or a future reviewer) can trace every decision the orchestrator made.
- **Iteration tracking.** Prevents the orchestrator from losing track of what was tried and what was found.

---

## Experiment Directory Convention

```
<workspace>/
├── <eval_environment>/           # Original eval (never modified)
├── <experiment_name>_v1/         # Iteration 1 working copy
│   ├── [eval files, modified]
│   ├── logs/
│   │   ├── control/
│   │   └── treatment/
│   └── artefacts/
│       ├── explorer/             # Explorer report (saved by orchestrator)
│       │   └── report.md
│       ├── executor/             # Executor report (saved by orchestrator)
│       │   └── report.md
│       └── analyst/              # Analyst outputs (written by analyst agent)
│           ├── report.md
│           ├── scanners.py
│           └── scans/
├── <experiment_name>_v2/         # Iteration 2 working copy (if needed)
│   ├── [eval files, modified differently]
│   ├── logs/
│   │   ├── control/
│   │   └── treatment/
│   └── artefacts/
│       └── [same structure]
└── investigation-log.md          # Persistent state
```

Each iteration gets its own directory. Previous iterations are never modified.

---

## Edge Cases

### Explorer says the hypothesis is untestable
Report to user with the Explorer's reasoning. Ask the user to revise the hypothesis or choose a different eval environment.

### Executor reports all conditions failed
Do not launch the Analyst. Diagnose the failure from the Executor's error details. Common causes: API key issues, sandbox misconfiguration, task file errors introduced by the orchestrator's modifications in Step 2c. Fix and re-run, or escalate to user.

### Executor reports asymmetric failure rates
If 80% of control samples succeeded but only 30% of treatment samples did, the data is confounded. Do not treat this as a valid comparison. Re-run the failed condition, or investigate whether the treatment modifications broke the eval.

### Analyst finds no patterns related to the topic
This is a valid finding. Report it as "no observable behavioural differences related to [topic]." Do not iterate just to find something — absence of signal is informative.

### Analyst finds strong patterns that contradict the hypothesis
Report faithfully. Do not reframe contradictory findings as "partially supporting" the hypothesis. The orchestrator's job is to relay evidence, not to advocate for the hypothesis.

### The eval environment requires setup beyond file modifications
If the eval needs dependency installation, Docker image builds, dataset downloads, or other infrastructure work, the orchestrator handles this before launching the Executor. Flag any setup requirements to the user if they require elevated permissions or significant compute.

### Multiple models with different failure profiles
If Model A succeeded but Model B failed entirely, the orchestrator can still send Model A's data to the Analyst. Note in the report that cross-model comparison is not possible for this iteration.

---

## Anti-Patterns

1. **Smuggling the hypothesis into the topic.** The single most important rule. If the Analyst knows the hypothesis, its analysis is contaminated.

2. **Modifying the original eval environment.** Always work on a copy. The original must be preserved for reproducibility and for future experiments.

3. **Iterating without updating the investigation log.** State loss across iterations leads to repeated work, contradictory modifications, and untraceable decisions.

4. **Proceeding after total execution failure.** If the Executor couldn't run any conditions, there's nothing for the Analyst to analyze. Diagnose first.

5. **Ignoring the Analyst's limitations section.** The Analyst is required to flag limitations. If the orchestrator doesn't read and relay them, the user gets an incomplete picture.

6. **Reusing condition labels across iterations without re-randomising.** Each Analyst invocation should use freshly randomised condition-label mappings. If condition_A always maps to the control, the firewall is weakened.

7. **Running too many iterations without user check-in.** Autonomous investigation is valuable, but after 2-3 iterations, the user should be consulted. The orchestrator might be pursuing a dead end.

8. **Applying diffs without verifying them.** Always read modified files back after applying changes. A misapplied diff can silently confound the experiment.
