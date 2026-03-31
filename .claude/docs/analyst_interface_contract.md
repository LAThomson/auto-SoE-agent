# Transcript Analyst: Interface Contract

This document defines the interface between the orchestrator and the Transcript Analyst. Both agents have access to this document. It specifies what the orchestrator provides, what the analyst returns, and the format of each. This is the single source of truth for the contract; neither agent should redefine these structures independently.

---

## Orchestrator → Analyst: Request Format

Each request from the orchestrator to the Transcript Analyst contains the following fields.

### Neutral topic description (required)

A plain-language description of the behavioural domain the analyst should attend to. This description specifies what to look for without revealing the experimental hypothesis, the predicted direction of effect, or the nature of the experimental manipulation.

Good: "Examine how models reason about their operational context and whether they adjust their approach based on perceived circumstances."

Bad: "Check whether models show reduced eval awareness in the treatment condition."

Bad: "Look for evidence that the prompt modification reduced strategic behaviour."

The topic description may include specific signals to scan for if the orchestrator has prior knowledge from earlier investigation cycles, but these should be framed as behavioural descriptions (e.g., "look for instances where the model references features of the environment as evidence about the nature of the interaction") rather than hypothesis-confirming queries.

### Transcript source (required)

A mapping from opaque condition labels to Inspect AI log directory paths or transcript database URIs. Each condition is provided as a separate path, corresponding to a separate execution of the Experiment Executor.

```
{
    "condition_A": "./logs/run_001",
    "condition_B": "./logs/run_002",
    "condition_C": "./logs/run_003"
}
```

The analyst partitions transcripts by condition label using these paths. The analyst should be able to compute per-condition statistics without being able to infer what the conditions represent.

### Scanning model (optional)

The model to use for LLM-based scanning. If not specified, the analyst uses the project default.

### Constraints (optional)

Constraints on the analysis scope. Some constraints are enforceable via Scout CLI flags; others are best-effort.

Enforceable: maximum number of transcripts to scan (maps to `--limit`), maximum concurrent transcripts (maps to `--max-transcripts`). These are hard limits.

Best-effort: budget limits on API calls, specific scanner types to use or avoid, or preferences about scanning granularity. The analyst should respect these but there is no mechanism that enforces them at the tooling level.

### Artefacts directory (optional)

A path to a shared artefacts directory for the investigation. When provided, the analyst creates an `analyst/` subdirectory within it and writes all file outputs there (scripts, scan results, validation sets, reports). This keeps all investigation artefacts co-located. If not provided, the analyst writes to the current working directory.

---

## Analyst → Orchestrator: Report Format

Each report from the Transcript Analyst to the orchestrator contains the following sections.

### Scanner definitions

For each scanner built during this analysis cycle:

- **Name**: The scanner's identifier (e.g., `eval_cue_detection`).
- **Type**: `llm_scanner`, `grep_scanner`, or `custom`.
- **Question/pattern**: The exact question posed to the scanning model (for LLM scanners) or the pattern list (for grep scanners).
- **Answer type**: `boolean`, `numeric`, classification labels, or structured schema.
- **Message scope**: Which messages the scanner receives (e.g., `"all"`, `["assistant"]`).

### Validation metrics

For each scanner, computed against a labelled validation set:

- **Balanced accuracy**: Average of recall and specificity.
- **Precision**: When the scanner flags something, how often is it correct?
- **Recall**: Of all items that should be flagged, how many did the scanner find?
- **F1**: Harmonic mean of precision and recall.
- **Validation set size**: How many labelled transcripts were used, and the positive/negative balance.
- **Labelling method**: Whether validation labels were produced by a human or by an AI model. If AI-labelled, specify the labelling model. The orchestrator should apply wider uncertainty bounds when interpreting results validated against AI labels, since LLM judges have been found to disagree with human annotators 23-28% of the time in comparable settings (UK AISI International Joint Testing Exercise, 2025).

If a scanner has not been validated, this must be stated explicitly, and any results from that scanner should be flagged as provisional.

### Quantified results

Detection rates, distributions, and breakdowns by condition label and any other relevant metadata dimensions. Specifically:

- **Per-condition detection rates** for boolean scanners (e.g., "condition_A: 34% detected, n=200; condition_B: 12% detected, n=200").
- **Per-condition distributions** for numeric or classification scanners (means, standard deviations, histograms, or confusion matrices as appropriate).
- **Overall counts**: Total transcripts scanned, total per condition, any transcripts excluded and why.

Results should be presented as structured data (DataFrames or tabular summaries) that the orchestrator can further analyse, not as narrative prose.

### Scan results path

The filesystem or S3 path to the raw scan results directory. This enables the orchestrator to run lightweight sanity checks on the summary statistics (e.g., verifying that reported counts sum to the total, that detection rates are consistent with raw values) without needing to deeply analyse the logs. The analyst should not assume the orchestrator will use this path for anything beyond verification.

### Transcript exclusions

A count and explanation of any transcripts excluded from the analysis, broken down by condition. Exclusion reasons include: model crashes, sandbox errors, tool-call failures, empty transcripts, or transcripts that hit a limit (token, message, or time). The orchestrator needs this information to assess whether differential attrition across conditions may confound the results.

### Transcript excerpts

Specific message references (e.g., "[M2]", "[M5] <think>") illustrating detected patterns, drawn from the scanner's `message_references` output. These are provided for context and to enable the orchestrator to drill down into specific cases. They are explicitly illustrative, not evidential: no conclusion should rest on an individual excerpt.

### Additional observations

Patterns not directly related to the topic description or outside the scope of the designed scanners, but noticed during the analysis. These are reported descriptively without interpretation. For example: "15 transcripts in condition_B contained no assistant messages at all; these were excluded from detection rate calculations."

---

## Conventions

**Each invocation is self-contained.** Every delegation from the orchestrator to the analyst is a single-shot interaction: one request, one report, no follow-up within the same invocation. The analyst has no memory of prior invocations and builds all scanners from scratch based on the current topic description. This preserves the informational firewall: the orchestrator cannot inadvertently leak directional information through iterative refinement, and the analyst is never handed tools that encode what a previous analysis found interesting. If the orchestrator needs a different analysis, it constructs a new request from scratch.

**Condition label opacity.** The analyst should not attempt to infer what the condition labels represent. If the analyst notices that condition labels correlate with observable transcript properties (e.g., condition_A transcripts are systematically longer), it should report this observation as a metadata finding, not as an inference about the experimental design.
