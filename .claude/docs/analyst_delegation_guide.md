# Transcript Analyst: Delegation Guide

This document explains how the orchestrator should delegate to and interpret results from the Transcript Analyst. It covers when to invoke the analyst, how to construct requests, how to interpret the report, and common pitfalls. The interface contract governing request and report formats is defined in `analyst_interface_contract.md`.

---

## When to delegate to the Transcript Analyst

Invoke the Transcript Analyst when you need to understand what happened inside evaluation transcripts beyond what aggregate scores reveal. Specifically:

**After the Experiment Executor completes a run.** The executor returns log paths and execution metadata. Before interpreting pass/fail rates as evidence about the evaluation, delegate to the analyst to check whether the scores reflect what you think they reflect. Identical pass rates can arise from qualitatively different model behaviours (refusals, tool-use faults, evaluation awareness), and only transcript analysis can distinguish these.

**When testing whether an evaluation property affects model behaviour.** If your investigation cycle manipulated an evaluation property (a prompt cue, an environmental feature, a scoring function), the analyst can quantify whether transcripts differ between conditions in ways that go beyond the score. This is typically the core use case.

**When screening for confounds before interpreting results.** Even if your investigation does not directly concern evaluation awareness, refusals, or environment faults, these phenomena may be present in the transcripts and may confound your findings. A screening scan for known confounds is good practice before drawing conclusions.

**Do not invoke the analyst** for tasks that do not require transcript content: comparing aggregate scores across conditions, computing statistical tests on pass/fail rates, or checking execution metadata for anomalies. These are better handled by other agents or by the orchestrator directly.

---

## Constructing the request

Your request to the analyst must follow the format specified in `analyst_interface_contract.md`. The most important element is the neutral topic description. This is where the hypothesis firewall operates: if your topic description leaks the hypothesis, the structural separation between hypothesis-holder and transcript-reader breaks down.

### Writing a neutral topic description

The topic description should specify the behavioural domain, not the expected finding. Before sending a topic description, review it and ask: could the analyst infer my hypothesis from this description alone? If yes, revise.

**Techniques for maintaining neutrality:**

Frame the topic as an open question about what models do, not as a check for a specific pattern. "Examine how models reason about the nature of their interaction and whether this reasoning influences their approach to the task" is open. "Check whether removing the XML tags reduced evaluation awareness" is not.

Use symmetrical phrasing that does not privilege one outcome. "Examine whether models adjust their behaviour based on perceived circumstances, and if so, in what ways" treats behavioural adjustment and non-adjustment as equally interesting outcomes.

If you need the analyst to scan for a specific signal (e.g., because an earlier cycle identified it), describe the signal behaviourally: "Scan for instances where the model references specific features of its environment (e.g., file names, prompt formatting, task structure) as evidence about the nature of the interaction." Do not explain why this signal matters to your hypothesis.

### Providing condition labels

Use opaque labels (condition_A, condition_B) rather than descriptive names. Each condition corresponds to a separate execution of the Experiment Executor, producing a separate log directory. The analyst receives a mapping from labels to paths as specified in `analyst_interface_contract.md`.

Randomise the mapping between conditions and labels. Do not always assign condition_A to the control and condition_B to the treatment. If the analyst (or the scanning model) were to develop a prior that condition_A is typically the baseline, this would compromise the firewall. A simple randomisation (e.g., coin flip for which label maps to which condition) eliminates this risk.

Because each condition runs as a separate executor instantiation, be aware of temporal confounds: if conditions are run sequentially rather than in parallel, time-varying factors (API provider behaviour, rate limit patterns) are confounded with condition. Where feasible, run conditions in parallel or interleave them. If sequential execution is unavoidable, note this as a potential confound in the cumulative report.

If you are running the analyst on transcripts from a single condition (e.g., only the treatment group), be aware that you are implicitly revealing something about your experimental design. Where possible, include all conditions and let the analyst report on each.

---

## Before delegating: pre-checks on execution data

Before sending transcripts to the analyst, review the Experiment Executor's execution report for issues that affect transcript quality.

### Differential attrition

If completion rates differ between conditions (e.g., 40% of condition_A runs crashed due to tool errors while only 5% of condition_B did), the surviving transcripts are not a representative sample. The attrition pattern is itself a finding about the evaluation's properties under those conditions, and should be documented in the cumulative report. Do not re-run the evaluation until enough transcripts "succeed" in the failing condition: this introduces a selection bias where models that crash under certain conditions are silently excluded from the analysis. Instead, report the failure rate as evidence, note the reduced sample size in the affected condition, and flag differential attrition as a confound when interpreting the analyst's results.

### Transcript validity screening

The Experiment Executor should report basic transcript quality metrics: how many transcripts contain no assistant messages, how many hit token or time limits, how many terminated with errors. If a large fraction of transcripts are uninformative (e.g., the model crashed before producing any relevant behaviour), this limits what the analyst can usefully detect. The orchestrator should note this in the research brief and adjust its expectations for the analyst's report accordingly. The analyst will report exclusions in its report (as required by the interface contract), but the orchestrator should already know the approximate scale of the problem before delegating.

---

## Interpreting the analyst's report

The analyst returns behavioural observations. Your job is to translate these into evidence about the evaluation's properties. This translation step is where science-of-evaluations work happens.

### Sanity-checking the report

The analyst provides a scan results path alongside its summary statistics. Before interpreting the findings, run a lightweight consistency check: do the reported per-condition counts sum to the total? Are detection rates arithmetically consistent with the raw counts? If there are discrepancies, flag them rather than trusting the summary. This is a checksumming operation, not a deep analysis of the logs, and should not require significant context.

### The translation step

The analyst reports in model-level terms: "34% of condition_A transcripts contain explicit reasoning about evaluation context; 12% of condition_B transcripts do." Your interpretation reframes this as evaluation-level evidence: "The evaluation is confounded by eval awareness in roughly a third of runs under condition A, and this confound is substantially reduced under condition B, consistent with the hypothesis that [the manipulated property] drives eval awareness in this setting."

This translation is not trivial. It requires you to consider whether the analyst's observation actually supports the evaluation-level conclusion, or whether alternative explanations could account for the same data.

### Checking for confounds in the report

Before interpreting the analyst's findings, check:

**Are the validation metrics adequate, and how were labels produced?** If a scanner has low precision (many false positives), the reported detection rate is inflated. If it has low recall (many missed cases), the detection rate is deflated. Factor these into your interpretation. A 34% detection rate from a scanner with 60% precision could reflect a true rate anywhere from roughly 20% to 34%. Additionally, check whether the validation labels were human-produced or AI-produced. AI labels introduce an additional layer of uncertainty: apply wider error bounds when interpreting AI-validated results.

**Are completion rates balanced across conditions?** If the Experiment Executor reported asymmetric completion rates, the analyst's per-condition statistics may be computed on non-representative samples. Check whether the analyst noted any transcript exclusions and whether these were balanced across conditions.

**Could a metadata imbalance explain the finding?** If condition_A and condition_B happen to use different models, or different tasks, or different prompt lengths, the analyst's findings might reflect these differences rather than the intended manipulation. Check whether the analyst reported any metadata correlations with condition labels.

**Could the scanner design explain the finding?** If the scanner question is phrased in a way that is more likely to trigger on certain kinds of transcripts for reasons unrelated to the target signal (e.g., longer transcripts, transcripts with more reasoning tokens), the finding may be an artefact. Consider whether a differently-phrased scanner would produce the same result.

### Using transcript excerpts

The analyst provides message references illustrating detected patterns. These are useful for understanding what the scanner is detecting and for generating hypotheses about why a pattern appears, but they are not evidence for any claim. Do not cite individual transcripts as support for a conclusion. Use them to calibrate your understanding of the scanner's output.

### Each invocation is self-contained

Each delegation to the analyst is a single-shot interaction: you send one request, receive one report, and do not go back for refinement or follow-up within the same invocation. This is essential for preserving the informational firewall. Multi-step interaction erodes the barrier because the mere act of requesting a follow-up, and the specific dimension you ask the analyst to drill into, carries information about what you found interesting in the first report, which is partial directional information about your hypothesis.

If you need a different analysis (a different signal, a different breakdown, a robustness check with a differently-phrased scanner), construct a new request from scratch with a fresh topic description. The analyst treats each invocation as an independent task with no memory of prior invocations. This means the analyst will rebuild scanners from its own design process each time rather than reusing tools from previous cycles, which strengthens the firewall: the analyst is never handed a tool that implicitly encodes what a previous analysis found interesting.

---

## Common pitfalls

**Leaking the hypothesis through the topic description.** The most common failure. Review every topic description before sending it and ask whether the analyst could infer your prediction. Descriptive condition names are the most frequent source of leakage.

**Treating the analyst's report as a final answer.** The analyst reports patterns; you interpret them. If you accept the analyst's detection rates at face value without checking validation metrics, metadata balance, and alternative explanations, you are outsourcing the interpretive step that the pipeline is designed to keep under your control.

**Over-interpreting small differences.** A detection rate of 34% in one condition and 30% in another is not a meaningful difference if the scanner has 70% recall and the sample size is 50 per condition. Consider the uncertainty introduced by scanner imprecision, sample size, and stochastic variation before treating a numerical difference as evidence.

**Requesting overly specific scans.** If you ask the analyst to "check whether models mention the phrase 'this is a test' more often in condition_A," you have effectively designed the scanner yourself and bypassed the analyst's expertise. Provide the behavioural domain; let the analyst design the signal detection.
