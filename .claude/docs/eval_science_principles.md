# Methodological Reference: Science of Evaluations

This document contains summaries of seven papers that collectively inform rigorous science-of-evaluations work. The object of study is the evaluation itself, not the model being evaluated. These summaries distill principles that improve the quality of hypothesis formulation, experimental design, and interpretation of findings. They are drawn from the methodological literature on scientific inference, behavioural research, AI evaluation validity, and benchmark design.

Each summary explains what the paper argues, then extracts the principles most relevant to studying evaluations as scientific objects.

---

## 1. Strong Inference

**Source:** Platt, J.R. (1964). Strong Inference. *Science*, 146(3642), 347–353.

### What this paper argues

Platt observed that certain scientific fields (molecular biology, high-energy physics) progressed far faster than others (psychology, ecology) and attributed the difference to a single methodological habit: systematically applying a cycle of (1) devising multiple competing hypotheses, (2) designing experiments that can exclude at least one hypothesis, and (3) performing the experiment and recycling. He called this "strong inference" and contrasted it with weaker patterns: testing a single favoured hypothesis, running experiments that can only confirm but never disconfirm, and accumulating observations without a discriminating question.

Platt warned against two failure modes. The first is what he called "The Frozen Method": attachment to a single experimental technique, leading researchers to study only what that technique can measure rather than what the research question demands. The second is single-hypothesis worship, where a researcher becomes invested in one explanation and designs experiments that can only support it, never refute it.

### Principles

**Competing hypotheses are the unit of progress.** An experiment that cannot distinguish between two explanations has not advanced understanding, regardless of how many observations it produces. The value of an investigation cycle is measured by how many hypotheses it eliminates, not by how many patterns it surfaces.

**Falsifiability is a prerequisite, not a bonus.** If a prediction cannot be stated in a form where some observable outcome would make it wrong, it is not ready to be tested. Vague directional expectations ("we expect to see interesting differences") do not qualify.

**Technique attachment is a silent failure mode.** When the same kind of manipulation (e.g., prompt-level cue variation) appears in every cycle, the question to ask is whether the research question demands it or whether a familiar method has become the default. The method should follow the question, not the other way around.

**Tracking epistemic state prevents narrative drift.** After each cycle of work, a clear accounting of which hypotheses survive, which are eliminated, and which remain untested forces honest assessment of where the investigation stands, rather than allowing a post-hoc narrative to smooth over inconvenient ambiguity.

---

## 2. Lessons from a Chimp: AI "Scheming" and the Quest for Ape Language

**Source:** Summerfield, C., Luettgau, L., Dubois, M., Kirk, H.R., Hackenburg, K., et al. (2025). Lessons from a Chimp: AI "Scheming" and the Quest for Ape Language. arXiv:2507.03409. UK AI Security Institute.

### What this paper argues

Summerfield and colleagues draw a detailed analogy between the 1970s primate language research programme and contemporary AI scheming research. The ape language programme collapsed under methodological scrutiny: experimenters had over-attributed linguistic competence to chimpanzees based on cherry-picked anecdotes, uncritical interpretation of ambiguous evidence, and a failure to test alternative explanations. The authors identify three specific methodological failures that recur in current AI behavioural evaluation research.

The first failure is anthropomorphic overattribution. Researchers use mentalistic vocabulary ("the model knows," "the model attempted to deceive") when the evidence supports only third-person discrimination (the model produced output X under condition Y). The second failure is excessive reliance on anecdote. Individual transcripts are selected for their narrative interest rather than their statistical representativeness. The third failure is the absence of null hypotheses. Researchers often do not specify what they would expect to observe if their hypothesis were wrong, making it impossible to distinguish a genuine finding from noise or a confound.

The paper also identifies a structural risk: when a small, tight-knit research community shares assumptions and reviews each other's work, motivated reasoning can propagate unchecked.

### Principles

**Mechanistic description is the default; mentalistic language is a conclusion.** Describing what a model produced under what conditions is always more precise than attributing intent or knowledge to it. Mentalistic language ("the model recognised," "the model attempted") should only be used when simpler explanations (formatting artefacts, heuristic responses, statistical noise) have been systematically excluded and this exclusion has been documented. The threshold for escalation should be high, because the base rate of unwarranted mentalistic attribution in AI research is very high.

**Quantified patterns are evidence; individual transcripts are anecdotes.** A single striking transcript can generate a hypothesis, but it cannot support a conclusion. Every reported pattern must be accompanied by a base rate: how many transcripts exhibit it, out of how many examined, under what conditions.

**The null hypothesis and the simplest alternative explanation must be stated before interpretation begins.** What would be expected if the evaluation property under study had no effect? What would be expected if the observed effect were due to a confound rather than the intended manipulation? Would a simple heuristic account for the observation without any evaluation-specific explanation?

**Narrative coherence is a warning sign, not an achievement.** If an investigation's cumulative findings read like a clean story where each cycle builds naturally on the last, this may indicate that contradictions and ambiguities have been smoothed over rather than reported.

---

## 3. Measuring What Matters: Construct Validity in Large Language Model Benchmarks

**Source:** Bean, A.M., Rocher, L., Kearns, R.O., Romanou, A., et al. (2025). Measuring What Matters: Construct Validity in Large Language Model Benchmarks. arXiv:2511.04703. NeurIPS 2025 Datasets and Benchmarks Track.

### What this paper argues

Bean and colleagues systematically reviewed 445 LLM benchmarks published at six top ML venues and found pervasive construct validity failures. Roughly 22% of benchmarks did not define the target phenomenon they claimed to measure. Only 53% provided any justification for why their evaluation was a valid measure of that phenomenon. Only 16% used statistical methods when comparing model performance.

The paper imports construct validity theory from psychometrics and translates it into categories applicable to AI benchmarks: face validity (does the benchmark look like it measures what it claims?), content validity (do the items cover the relevant domain?), predictive validity (do benchmark scores predict performance on tasks we care about?), ecological validity (does the benchmark setting resemble the real-world setting of interest?), and convergent validity (do different benchmarks that claim to measure the same thing agree?).

A key finding: benchmarks that fail on construct validity are not merely imprecise; they may be measuring something entirely different from what they claim.

### Principles

**Every evaluation study begins with five validity questions.** (1) What construct does this evaluation claim to measure, and is this claim stated explicitly? (2) Do the evaluation items actually test for that construct, or could a model score well for unrelated reasons? (3) Does the evaluation setting resemble the deployment setting the construct is meant to predict? (4) Would a different evaluation of the same construct produce similar results? (5) Could the evaluation be measuring a different construct entirely?

**The gap between an evaluation's stated construct and its actual construct is itself a finding.** This is the core of science-of-evaluations work. When an evaluation labelled "safety" primarily measures instruction-following, or an evaluation labelled "reasoning" primarily measures memorisation, documenting that discrepancy advances the field's understanding of its own tools.

**Evaluation flaws should be characterised, not fixed.** The role of evaluation science is to study evaluations as they exist in the field, not to engineer improved versions. Cleaning up an evaluation before studying it changes the object of study. Known flaws should be documented and treated as potential confounds when interpreting results. If a specific flaw drives the majority of the observed behavioural variation, that discovery is itself the contribution.

---

## 4. Mainstream Approach for Alignment Evals is a Dead End

**Source:** Ivanov, I. (2026). Mainstream approach for alignment evals is a dead end. LessWrong. https://www.lesswrong.com/posts/GctsnCDxr73G4WiTq/

### What this paper argues

Ivanov presents the case that the dominant strategy for alignment evaluation, creating increasingly realistic scenarios and hoping models do not detect they are being evaluated, faces a structural problem that cannot be solved by incremental improvements to realism. He documents the key empirical puzzle: when Anthropic tested Claude Sonnet 4.5, misalignment dropped to approximately 0% on synthetic honeypots, but the model mentioned being evaluated in over 80% of transcripts. When activation steering was used to suppress eval awareness features, misalignment reappeared. The evaluations were measuring eval awareness, not alignment.

Ivanov identifies several structural reasons why "just make it more realistic" fails. First, we cannot enumerate all features that make a scenario look like an evaluation. Second, ablating the cues that models self-report as causing awareness does not eliminate awareness. Third, hand-crafted evaluation scenarios are distributional outliers even when every individual feature is plausible, because the joint distribution of features differs from genuine deployment.

### Principles

**Evaluation awareness is a default confound in alignment evaluations.** Any observed behaviour in an alignment or safety evaluation may be partly or wholly driven by the model's detection of the evaluation context, unless specific evidence says otherwise.

**Manipulating an evaluation property simultaneously changes how "eval-like" the scenario appears.** The intended manipulation and the eval-awareness confound are entangled. Disentangling them requires explicit attention and should be considered when designing any experiment that varies properties of alignment evaluations.

**Ablating verbalized cues does not resolve the eval awareness confound.** If a model reports that feature X caused its awareness, removing feature X may not eliminate awareness: the model may detect the evaluation context through features it did not report. Evaluation awareness should always be included among the competing hypotheses when interpreting results from alignment evaluations.

---

## 5. Questionable Practices in Machine Learning

**Source:** Leech, G., Vazquez, J., et al. (2024). Questionable Practices in Machine Learning. arXiv:2407.12220.

### What this paper argues

Leech and colleagues catalogue 44 questionable research practices (QRPs) observed in machine learning research, importing the QRP framework from psychology's replication crisis. Several QRPs are directly relevant to studying evaluations. "Baseline nerfing" involves deliberately weakening a baseline to make a new method look better. "Dirty paraphrases" involve making multiple changes when testing a single manipulation. "Optional stopping" involves running experiments until a desired result appears. "Benchmark item errors" documents that roughly 9% of items in well-known benchmarks contain errors. "Cherry-picking" involves selectively reporting results that support the hypothesis.

### Principles

**Multiple simultaneous changes make attribution impossible.** When an experimental modification changes more than one thing, the observed effect could be due to any of the changes. A "minimal" change to an evaluation prompt may simultaneously alter its semantics, formatting, length, and distributional properties.

**Stopping rules must be committed to in advance.** If multiple investigation cycles are run and only the one that "worked" is reported, the apparent strength of the finding is inflated. All cycles, including null results, must be reported.

**Selective reporting distorts the evidential picture.** The full set of observations must be considered, not just those that align with the hypothesis. Findings that contradict the hypothesis deserve equal prominence.

**Evaluation items themselves may contain errors.** Before attributing model behaviour to a construct, it is worth checking whether the evaluation items are well-formed. Errors in evaluation items can produce spurious behavioural patterns.

**Knowledge from earlier cycles can contaminate later ones.** If findings from cycle N are used to design the hypothesis for cycle N+1, the later hypothesis is not independent of the data. This is acceptable when labelled as hypothesis-generating rather than hypothesis-testing, but the distinction must be explicit.

---

## 6. Quantifying Language Models' Sensitivity to Spurious Features in Prompt Design

**Source:** Sclar, M., Choi, Y., Tsvetkov, Y., Suhr, A. (2024). Quantifying Language Models' Sensitivity to Spurious Features in Prompt Design or: How I learned to start worrying about prompt formatting. arXiv:2310.11324. ICLR 2024.

### What this paper argues

Sclar and colleagues demonstrate that LLM performance on benchmarks is highly sensitive to superficial prompt formatting choices that should be irrelevant to the underlying task. Formatting changes alone can cause accuracy to vary by up to 76 percentage points for the same model on the same task. This sensitivity persists across model sizes and families.

A note on currency: the most extreme results were measured on LLaMA-2-13B, and subsequent work (including a 2025 large-scale comparison extending to GPT-4.1 and DeepSeek V3) has found that frontier models are meaningfully more robust to formatting perturbations. However, sensitivity has not disappeared at the frontier. The problem is most acute when effect sizes are small, which is typical in behavioural safety evaluations.

A further finding: format performance only weakly correlates between models, making cross-model comparisons unreliable when only a single prompt format is used.

### Principles

**Any modification to an evaluation simultaneously modifies its formatting properties.** Formatting includes delimiters, whitespace patterns, answer choice labels, instruction phrasing style, punctuation, capitalisation, line breaks, and structural markup. When an experiment varies an evaluation property, it also varies these incidental features.

**Robustness across prompt formulations is a minimum standard for reportable findings.** If a behavioural difference is observed under a single prompt formulation, it may be a prompt artefact. Testing the same manipulation under multiple semantically equivalent but formatically distinct variants is necessary before drawing conclusions.

**Placebo conditions help distinguish content effects from perturbation effects.** A modification of similar magnitude and formatting impact but orthogonal content provides a baseline for how much behavioural change is attributable to the mere fact of modification, as opposed to its specific content.

---

## 7. Establishing Best Practices for Building Rigorous Agentic Benchmarks

**Source:** Zhu, Y., Jin, T., Pruksachatkun, Y., Zhang, A., et al. (2025). Establishing Best Practices for Building Rigorous Agentic Benchmarks. arXiv:2507.02825.

### What this paper argues

Zhu and colleagues audited 17 agentic benchmarks used by frontier labs and developed the Agentic Benchmark Checklist (ABC). Their central contribution is a clean distinction between two types of validity failure.

Task validity failures occur when the evaluation task does not actually require the target capability for success: tasks solvable by shortcuts, tasks with mismatched difficulty, tasks with unintended solution paths. Outcome validity failures occur when the scoring function does not correctly identify success or failure: scoring functions that count empty responses as successes, insufficient test cases, scoring metrics insensitive to the construct of interest.

Applying the checklist to 10 benchmarks revealed that 7 of 10 had outcome validity flaws and 7 of 10 had task validity issues. SWE-Lancer allowed 100% scores without resolving any tasks. KernelBench overestimated performance by 31 percentage points.

### Principles

**Task validity and outcome validity are distinct failure modes requiring different diagnostics.** Task validity asks whether the evaluation tests what it claims to test. Outcome validity asks whether the scoring function captures what it claims to capture. Both must be assessed independently.

**Validity failures are findings, not defects.** When studying an evaluation, the goal is to identify and characterise its validity failures as evidence about the evaluation's properties. A demonstrated shortcut that bypasses the intended test tells us what the evaluation actually measures, which may differ from what it claims.

**The severity of a validity failure determines what it implies for existing results.** A task validity failure affecting 2% of items is a minor caveat. One affecting 40% calls into question every published result that relies on the evaluation. Quantifying impact is more valuable than merely cataloguing the flaw.
