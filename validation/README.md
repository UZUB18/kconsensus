# Statistical-behavior validation

This is an exploratory Monte Carlo study, not a guarantee of recovery or a
calibration of consensus agreement. The software checks and the statistical
behavior study answer different questions.

## Reproduce

Run from the package root:

```r
devtools::load_all()
local({
  environment <- new.env(parent = globalenv())
  sys.source("validation/run_statistical_behavior.R", envir = environment)
  environment$run_statistical_behavior(repetitions = 100L, workers = 4L)
})
```

The script uses four forked workers on Unix and a serial fallback elsewhere.
All data-generation, clustering and Gap seeds are explicit and recorded. The
caller RNG state is preserved. Runtime depends on hardware and worker count.

## Design

Each scenario has 100 independently seeded repetitions with 120 observations.
The ordinary candidate range is 2:6. Gap also evaluates K = 1 and uses 100
reference simulations, `d.power = 1`, PCA-rotated references and `firstSEmax`.
K-means uses 25 starts and 100 maximum iterations. Variables are used as
generated, without automatic standardization. Elbow always abstains because no
calibrated minimum knee strength is available.

| Scenario | Data-generating situation |
|---|---|
| Separated | Three equally sized 2D Gaussian groups; first-coordinate means -5, 0, 5; within-group SD 0.65 |
| Overlapping | Three equally sized 2D Gaussian groups; first-coordinate means -1.2, 0, 1.2; within-group SD 1 |
| Uniform | Independent uniform coordinates on [-5, 5]; no generating Gaussian-group count |
| Small group | Group sizes 55, 60, 5; first-coordinate means -3, 3, 0; SD 1 for large groups, 0.35 for the small group |
| Elongated | Three horizontal Gaussian groups; horizontal SD 4, vertical SD 0.35; vertical means -3, 0, 3 |
| High dimensional | The separated 2D design plus 48 independent standard-normal noise variables |

For overlapping data, each repetition is evaluated on both 2:6 and 2:15. These
paired evaluations reuse the same fitted partitions and reference simulations.
Gap selection is recomputed after restricting the same Gap table to each range.
This isolates range sensitivity from changing the simulated reference samples.
There are 600 generated datasets and 700 consensus evaluations in total.

Duplicate observations and invalid K are deterministic software-test cases,
not additional Monte Carlo scenarios. Rotation and uniform-scale invariance
are also checked by the regular unit tests.

## Observed results

| Scenario | K range | K = 3 recovery | Median adjusted Rand index | Ties |
|---|---|---:|---:|---:|
| Separated | 2:6 | 100/100 | 1.000 | 0 |
| Overlapping | 2:6 | 3/100 | 0.209 | 30 |
| Overlapping | 2:15 | 1/100 | 0.074 | 25 |
| Small group | 2:6 | 0/100 | 0.917 | 0 |
| Elongated | 2:6 | 0/100 | 0.268 | 24 |
| High dimensional | 2:6 | 0/100 | 0.555 | 0 |
| Uniform | 2:6 | Not defined | Not defined | 17 |

### Support levels (version 0.1.0)

The study was re-run with version 0.1.0, which grades the support for each
recommendation and adds descriptive flags. The re-run reproduced every
recommendation, tie, Gap choice, silhouette value and partition metric of the
original run exactly; only the status labels and flags are new.

| Scenario | K range | Unanimous | Majority | Plurality | Tie | Unanimous or majority with no flag |
|---|---|---:|---:|---:|---:|---:|
| Separated | 2:6 | 99 | 1 | 0 | 0 | 100 |
| Small group | 2:6 | 60 | 40 | 0 | 0 | 100 |
| Uniform | 2:6 | 1 | 58 | 24 | 17 | 16 |
| Overlapping | 2:6 | 0 | 32 | 38 | 30 | 1 |
| Overlapping | 2:15 | 0 | 27 | 48 | 25 | 1 |
| Elongated | 2:6 | 0 | 45 | 31 | 24 | 0 |
| High dimensional | 2:6 | 0 | 100 | 0 | 0 | 0 |

No run ended with a single valid vote. On separated data, every run gave
unanimous or majority support with no flag. On uniform data only 16 runs did;
the other 84 were pluralities, ties, or carried a flag, mostly
`single_cluster_vote` because Gap chose K = 1 (81 runs). Every high-dimensional
run was a majority for K = 2 flagged `lower_boundary`: none of the methods
voting for K = 2 could have chosen fewer clusters.

The grading does not rescue the small-group design. All 100 runs reported
unanimous or majority support for K = 2 without any flag, although the data
were generated with three groups. Strong, unflagged agreement is therefore a
descriptive pattern, not a calibrated test that the recommended K is right.

### Recovery and partition agreement

Recovery counts use all 100 repetitions, including ties as non-recoveries.
Adjusted Rand summaries are conditional on a unique recommendation; ties have
no selected partition. The CSV also reports 95% Wilson intervals for the Monte
Carlo recovery proportions. These intervals concern repeated datasets from
these specified generators, not confidence that a real dataset has K groups.
For example, the 100/100 separated-data recovery interval is 96.3% to 100%.

The small-group scenario selected K = 2 in all 100 repetitions. Its median
best-matching small-group F1 was only 0.116, despite a high overall adjusted
Rand index. An aggregate partition score can conceal failure on a tiny group.

The high-dimensional scenario also selected K = 2 in all 100 repetitions.
Its median selected silhouette was 0.176 versus 0.761 for the separated 2D
scenario. Median case runtime was 9.56 versus 1.06 seconds on this machine
with four workers; these timings are descriptive, not portable benchmarks.

Uniform data produced K = 2, 3, 4, 5 and 6 in 1, 4, 43, 7 and 28 repetitions,
respectively, with 17 ties. Gap itself recommended K = 1 in 81 repetitions,
but that recommendation did not win the multi-method vote. One uniform-data
repetition even had unanimous voting. Agreement is therefore not evidence
that real clusters exist, and this engine is not a calibrated no-clusters test.

On the paired overlapping-data comparison, the recommendation or tied set
changed in 90/100 repetitions when the range expanded from 2:6 to 2:15.
Candidate-range sensitivity is substantial in this design and should be
investigated in applied analyses, not hidden by a single reported K.

All 700 evaluations completed without calculation errors. Boundary warnings
are captured in the trial output rather than suppressed or treated as errors.
The plots show a general compact/spherical K-means caveat; no automatic shape
detector has been asserted or validated.

## Artifacts

`statistical_behavior_summary.csv` contains scenario summaries, support-level
counts, flag rates and Monte Carlo intervals. `statistical_behavior_trials.csv`
retains every evaluation, status, flag, warning, timing and partition
diagnostic. `statistical_behavior.rds` additionally keeps
the full method score curves and records, seeds, paired-range summary and
session information. This directory is excluded from package builds so the
long study is not run during routine package checks.
