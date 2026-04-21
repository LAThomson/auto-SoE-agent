# Experimental Design Patterns

Practical decision frameworks for designing conditions, sizing experiments, managing confounds, and handling failures.

## Condition Design Patterns

Three patterns for structuring experimental conditions. Choose based on how the independent variable maps to the evaluation setup.

### Pattern A: Parameter-Based Conditions

**When to use:** The IV can be expressed as a task parameter value. The task file is the same across conditions; only a `-T` flag changes.

**Example:** Testing system prompt variants.
```
control:   task.py -T system="system_prompt_control.txt"
treatment: task.py -T system="system_prompt_treatment.txt"
```

**Advantages:** Minimal file duplication. Clean separation of what varies (parameter value) from what's constant (task logic, scoring).

**Watch for:** The task file must actually parameterize the relevant feature. If the system prompt is hardcoded in the task file rather than loaded from a parameter, this pattern won't work — you'll need Pattern B.

### Pattern B: Separate Task Files

**When to use:** The IV requires structural changes to the task file itself — different prompt templates, different tool configurations, different scoring logic, or changes too complex to parameterize.

**Example:** Testing different elicitation strategies.
```
control:   task_direct.py
treatment: task_cot.py
```

**Advantages:** Full flexibility. Each condition can differ in arbitrary ways.

**Watch for:** The more the task files diverge, the more potential confounds. If `task_cot.py` has a different prompt template AND different scoring, you won't know which change caused the effect. Keep non-IV aspects identical. Diff the two files and verify that only the intended differences exist.

### Pattern C: Model Variation Only

**When to use:** The IV is the model itself. Same task, same parameters, different models.

**Example:** Comparing behaviour across model families.
```
condition_a: task.py --model anthropic/claude-sonnet-4-5-20250929
condition_b: task.py --model openai/gpt-4o
```

**Advantages:** No file modifications needed. Simplest to set up.

**Watch for:** Model differences are confounded with everything — training data, architecture, RLHF procedure, system prompt handling. Cross-model comparisons describe differences but cannot attribute them to any specific cause.

### Choosing a Pattern

| Situation | Pattern | Reasoning |
|-----------|---------|-----------|
| Vary a prompt file or text string | A | Parameterizable, minimal divergence |
| Vary task structure or scoring | B | Requires separate task definitions |
| Compare models on same task | C | No modifications needed |
| Vary a prompt AND compare models | A + C | Parameter-based conditions, run each on multiple models |
| Complex multi-factor design | B | Separate files give full control, but verify only intended factors differ |

## Sample Size and Statistical Power

LLM eval experiments are not classical statistical studies, but sample size still matters for the reliability of qualitative observations.

### Rapid Iteration vs. Conclusive Runs

| Goal | Sample Limit | Epochs | When |
|------|-------------|--------|------|
| Sanity check (does it run?) | 5-10 | 1 | Before committing to a full run. Catches task errors, API issues, scoring bugs. |
| Rapid iteration (directional signal) | 20-50 | 1 | Early iterations. Enough to spot strong effects; too few for subtle patterns. |
| Conclusive run (reportable findings) | 100+ or full dataset | 1-2 | Final iteration. Sufficient for the Analyst to identify reliable patterns. |

### When Epochs Matter

- **High-variance tasks:** Tasks where model output varies significantly across runs (creative writing, open-ended reasoning). Multiple epochs help distinguish signal from noise.
- **Low-variance tasks:** Tasks with constrained output formats (multiple choice, binary classification). Single epoch is usually sufficient.
- **When comparing conditions:** Use the same number of epochs for all conditions. Asymmetric epochs create unequal sample sizes and complicate comparison.

### Cost Awareness

Each condition-model-epoch combination is a separate eval run. The total number of API calls is:
```
conditions x models x samples x epochs
```

For a 2-condition, 1-model, 100-sample, 2-epoch experiment: 400 API calls. Budget accordingly and check with the user before large runs.

## Confound Management

A confound is anything that varies between conditions other than the intended IV. Confounds make results uninterpretable.

### Common Confounds in LLM Evals

**Prompt length differences:** If the treatment prompt is significantly longer than the control prompt, any behavioural difference might be due to length rather than content. Mitigate by padding the control prompt with neutral filler text of equal length, or by keeping prompts as close in length as practical.

**Information leakage:** If the treatment condition's system prompt mentions the topic being evaluated (e.g., "You will be tested on your honesty"), the model may adjust its behaviour based on knowing it's being tested rather than because of the intended manipulation. Check the Explorer's risk assessment for this.

**Scoring artifacts:** If the scoring rubric was designed for one condition and doesn't generalize to the other, apparent differences may be scoring artifacts rather than behavioural differences. Verify that the scorer produces meaningful results for ALL conditions.

**Order effects (within-sample):** If the eval presents multiple items in sequence within a single transcript, the model's responses to later items may be influenced by earlier items. This is a concern when conditions affect the model's self-perception (e.g., persona framing).

**Prompt formatting differences:** Subtle differences in whitespace, punctuation, or formatting between conditions can influence model behaviour in unexpected ways. Diff the actual prompts sent to the model, not just the template files.

### Using the Explorer's Risk Assessment

The Environment Explorer produces per-site risks and a global Risk Assessment covering confounds, cross-condition interactions, information leakage, scoring concerns, and ecological validity. The Explorer flags **Blocker** on any risk that would invalidate the experiment; non-Blocker risks are described in prose (see `explorer_interface_contract.md`). Use the report as follows:

- **Blocker flags** (global or per-site/variant): these must be addressed before proceeding. A global Blocker means redesign or hypothesis revision; a per-variant Blocker means that variant is unusable (others at the same site may be fine).
- **Non-Blocker risks:** weigh them against budget, iteration history, and the hypothesis itself. Mitigate where practical (cleaner manipulation, placebo condition, matched length), note as caveats in the final report where not.
- **Uncertainty & Open Questions:** the Explorer enumerates items it could not resolve from static reading. Resolve these (read the relevant file, ask the user, run a cheap sanity check) before applying modifications.

## Failure Handling

When the Executor reports failures, use this decision framework.

### Total Failure (all conditions failed)

**Do not proceed to the Analyst.** There is no data to analyze.

Diagnosis checklist:
1. API key / authentication issues? (Check error messages for 401/403.)
2. Task file errors introduced by modifications? (Re-read modified files, compare to Explorer's diffs.)
3. Sandbox or environment issues? (Missing dependencies, file permissions.)
4. Model-specific issues? (Model unavailable, rate limited, context length exceeded.)

After diagnosing, fix the issue and re-run. If unfixable, escalate to the user.

### Asymmetric Failure (one condition failed significantly more)

**This is a potential confound.** If 80% of control samples succeeded but only 30% of treatment samples did, the surviving treatment samples are not representative — they may be systematically different from the failed ones.

Decision:
- If the failure is clearly due to a mechanical issue (API timeout, rate limit) that's unrelated to the experimental manipulation: re-run the failed condition only.
- If the failure might be related to the manipulation (e.g., the treatment prompt causes the model to produce outputs that the scorer can't parse): this is itself a finding. Note it and consider whether the manipulation is too aggressive.

### Symmetric Partial Failure (both conditions lost similar proportions)

Usually safe to proceed, with caveats:
- Note the failure rate in the investigation log.
- Ask whether the failed samples share characteristics (e.g., all long inputs, all from a specific category).
- If failure rates are above ~20%, consider whether the task itself is unreliable.

### Individual Sample Errors

Small numbers of sample-level errors (< 5%) are normal in LLM evals. Common causes: context length exceeded on a particularly long input, model refused to respond, scorer encountered unexpected output format.

- If errors are evenly distributed across conditions: proceed.
- If errors cluster in one condition: investigate whether the manipulation causes the errors.
