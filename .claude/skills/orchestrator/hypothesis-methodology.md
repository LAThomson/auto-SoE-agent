# Hypothesis Methodology

This document provides detailed guidance on hypothesis generation, refinement, operationalization, and the neutral topic translation that shields the Transcript Analyst from bias.

## Hypothesis Formulation

### Structure

A testable hypothesis has three components:

1. **Independent variable (IV):** What changes between conditions. Must be a concrete, manipulable feature of the evaluation setup — not an abstract concept.
2. **Dependent variable (DV):** What is measured or observed. Must be something visible in model transcripts or eval scores.
3. **Direction:** The expected effect. "X increases Y," "X decreases Y," or "X changes the pattern of Y."

Template: "When [IV is changed in this specific way], [DV] will [direction]."

### Operationalization

The gap between a research question and a testable hypothesis is operationalization: making abstract concepts concrete and measurable.

**Abstract → Concrete progression:**

| Level | Example |
|-------|---------|
| Research interest | "Does the system prompt matter?" |
| Research question | "Does the system prompt affect how models handle ambiguous instructions?" |
| Directional hypothesis | "A system prompt that emphasizes helpfulness will lead to more compliant responses to ambiguous instructions" |
| Operationalized hypothesis | "Adding 'Always prioritize being helpful to the user' to the system prompt will increase the rate at which the model attempts the task (rather than asking for clarification) when given ambiguous instructions" |

At each level, ask: "Could two researchers independently set up this experiment and get comparable results?" If not, the hypothesis needs further operationalization.

### Common Failure Modes

**Too vague:** "System prompts affect model behaviour."
- Problem: Every system prompt affects behaviour. This isn't falsifiable.
- Fix: Specify WHICH aspect of the system prompt and WHICH behaviour.

**Too broad:** "Persona framing changes everything about how the model responds."
- Problem: "Everything" can't be measured. Any observation confirms it.
- Fix: Pick one specific behavioural dimension.

**Multi-variable:** "Adding a persona AND changing the temperature will affect accuracy."
- Problem: If you see an effect, you can't attribute it. Two variables changed.
- Fix: Test one variable at a time, or use a factorial design with conditions for each combination.

**Unfalsifiable:** "The model has an internal representation of the user's expertise level."
- Problem: Internal representations aren't visible in transcripts. No observable DV.
- Fix: Reformulate in terms of observable behaviour: "The model adjusts its vocabulary complexity based on stated user expertise."

**Circular:** "Models that are more sycophantic will give more sycophantic responses."
- Problem: The IV and DV are the same thing.
- Fix: Identify the upstream cause (e.g., a system prompt instruction) as the IV.

### Worked Example: From Vague to Testable

**Starting point:** "I want to know if models are sycophantic."

**Round 1 — What do you mean by sycophantic?**
"They agree with the user too much, especially when the user is wrong."

Refined: "Models agree with incorrect user claims."
Still vague — what kind of claims? In what context?

**Round 2 — What's the experimental manipulation?**
"I want to see if telling the model that the user is an expert makes it more likely to agree."

Refined: "Adding 'The user is a domain expert' to the system prompt increases the rate at which the model agrees with incorrect factual claims."
Better — we have an IV (expert framing in system prompt), a DV (agreement with incorrect claims), and a direction (increases).

**Round 3 — Is this operationalizable?**
- IV: Add "The user is a recognized expert in this domain" to the system prompt (treatment) vs. no expertise mention (control). This is a clean, minimal manipulation.
- DV: Whether the model's response agrees with, corrects, or equivocates on a factually incorrect claim made by the user. This is observable in transcripts.
- We need an eval that presents factually incorrect user claims. Does one exist?

Final hypothesis: "Adding an explicit statement of user expertise to the system prompt ('The user is a recognized expert in this domain') increases the proportion of model responses that agree with factually incorrect user claims, compared to a control condition with no expertise framing."

## Neutral Topic Translation

The Transcript Analyst must never receive the hypothesis. This is the primary defence against confirmation bias. The orchestrator translates the hypothesis into a neutral topic that covers the same behavioural space without implying an expected direction.

### Translation Rules

1. **Strip directionality.** Remove "increases," "decreases," "improves," "reduces," "more," "less," "higher," "lower."
2. **Strip mechanism claims.** Remove "because," "due to," "by causing," "leads to," "results in."
3. **Keep the domain.** The topic must cover the same behavioural space as the hypothesis so the Analyst looks in the right place.
4. **Keep it open-ended.** The topic should allow the Analyst to find patterns in either direction, or no direction, or unexpected directions.
5. **Don't smuggle the hypothesis.** Avoid loaded language that implies an expected direction.

### Examples

| Hypothesis | BAD Topic | GOOD Topic |
|------------|-----------|------------|
| "Expert framing increases sycophancy" | "Whether expert framing causes sycophancy" | "How the model handles factual disagreements with the user across conditions" |
| "Explicit goal framing increases deceptive behaviour" | "Whether explicit goals cause deception" | "How the model reasons about and frames its goals across conditions" |
| "Chain-of-thought prompting improves accuracy on reasoning tasks" | "Whether CoT helps with reasoning" | "Differences in response structure and problem-solving approach across conditions" |
| "System prompt persona framing increases refusal rates" | "How persona affects refusals" | "Response patterns and refusal behaviour across conditions" |

### Common Smuggling Patterns

These are subtle ways the hypothesis leaks into the topic. Watch for them:

- **Naming the expected outcome:** "How the model's accuracy changes" implies you expect accuracy to change.
- **Using evaluative adjectives:** "How the model's reasoning quality differs" implies one condition has better reasoning.
- **Framing one condition as the baseline:** "How the treatment condition affects behaviour" reveals which condition you expect to be different.
- **Including causal language:** "How the system prompt influences responses" implies influence exists.
- **Narrowing to the expected effect:** If your hypothesis is about sycophancy, asking about "agreement behaviour" is too narrow — it focuses the Analyst exactly where you expect to find the effect.

### Self-Check Procedure

After writing the topic, perform this check:

1. Read the topic as if you know nothing about the hypothesis. Would you be biased toward finding any particular pattern?
2. Could the Analyst's findings under this topic include patterns that CONTRADICT your hypothesis? If not, the topic is too narrow.
3. Replace your hypothesis with its opposite. Does the topic still work? If not, it's smuggling.
4. Show the topic to an imaginary colleague who doesn't know the hypothesis. Would they guess what you're looking for? If yes, revise.

## Iteration Logic

After the Analyst returns findings, the orchestrator must decide what to do next. The hypothesis guides this decision.

### When findings are ambiguous

Ambiguous findings usually mean the hypothesis lacks specificity, not that more data is needed.

- **First check:** Is the ambiguity in the data or in the hypothesis? If the hypothesis is "persona framing affects response style," any observation about response style counts as "supporting" or "contradicting" — the hypothesis is too broad to be informative.
- **Preferred action:** Refine the hypothesis to be more specific, then re-run with the narrower hypothesis.
- **Avoid:** Re-running the same experiment hoping for clearer results. If the experiment was well-powered and the results were ambiguous, running it again will likely produce ambiguous results again.

### When findings contradict the hypothesis

Contradictory findings are signal, not failure. They are often the most informative outcome.

- **Report faithfully.** Do not soften contradictory findings or frame them as "partial support."
- **Consider alternative explanations.** Could the contradiction be due to a confound? Did the manipulation work as intended? Check the Explorer's risk assessment.
- **If the contradiction is clean and the experiment is well-designed:** This is a strong finding. Report it and move to Phase 3.
- **If the contradiction might be artifactual:** Design a follow-up that addresses the potential confound.

### When findings support the hypothesis

Supporting findings feel satisfying but require extra scrutiny.

- **Ask:** What alternative explanations exist? Could a confound produce this pattern?
- **Ask:** Is the effect size meaningful or trivially small?
- **Ask:** Are there limiting conditions? Does the effect hold across all samples or only a subset?
- **If evidence is strong and no alternative explanations are compelling:** Report and conclude.
- **If evidence is moderate:** Consider whether additional evidence (more samples, different model) would strengthen confidence enough to justify the compute cost.

### When to stop iterating

- **3-iteration guideline.** After 3 iterations without clear findings, escalate to the user. You may be pursuing a dead end, or the hypothesis may need fundamental revision that requires human judgment.
- **Diminishing returns.** If iteration 2 adds little to iteration 1, a third iteration is unlikely to help.
- **Compute cost.** Each iteration consumes API credits. Check with the user before iteration 3+.
- **Clean contradiction or clean support.** If the evidence is clear in either direction, there's no need to iterate further. Report the findings.
