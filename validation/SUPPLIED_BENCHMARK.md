# Supplied synthetic benchmark

Tested the unmodified collection in `data_test/kconsensus_benchmark` using the
implemented `kconsensus()` API, not the proposed `choose_k()` interface in its
example harness.

## Reproduce

```r
devtools::load_all()
local({
  environment <- new.env(parent = globalenv())
  sys.source("validation/run_supplied_benchmark.R", envir = environment)
  environment$run_supplied_benchmark()
})
```

The run uses raw supplied features, seed 6749, 25 K-means starts, 100 maximum
iterations, and 100 Gap reference simulations. Candidate K is 2:10 for all
fixtures, with an additional complete 2:15 run for `many_12`. Gap also evaluates
K = 1 and selects using `firstSEmax`. Elbow abstains without a caller-supplied
threshold. Each supplied dataset is evaluated once; these are not repeated-seed
recovery-rate estimates.

Truth labels never enter clustering. Every truth file was checked for exact
row alignment. The primary ARI excludes truth label -1 only when scoring
recovery; all rows remain in every clustering fit. Secondary all-row ARI treats
-1 as one truth category, which is a sensitivity analysis rather than a claim
that scattered outliers form a coherent cluster. Recovery uses the retained
central partition at the selected K, including when Gap supplies that K.

The 60 duplicate observations and the zero-variance feature were retained.
No data, original harness or generation script in the supplied collection was
modified, coerced to numeric or standardized.

## Software results

All 24 jobs passed the applicable software checks: 18 valid fixtures, one
extended-range valid run, and five intended invalid inputs. Each valid run
matched `cluster::silhouette()` and the relevant `clusterCrit::intCriteria()`
values on the exact retained partitions. WCSS, vote counts, denominators and
Gap selection also matched their reference calculations. All three ggplot
views built successfully for each valid run.

The intended errors correctly identified identical points, missing values,
infinite values, insufficient distinct points and nonnumeric columns. These
expected rejections are not counted as valid-dataset failures.

## Selected statistical outcomes

| Fixture | K range | Consensus | Agreement | Inlier ARI |
|---|---|---|---:|---:|
| `clear_3` | 2:10 | 3 | 100% | 1.000 |
| `clear_5` | 2:10 | 5 | 100% | 1.000 |
| `cluster_stress_test` | 2:10 | 3 | 100% | 0.924 |
| `unbalanced_4` | 2:10 | 4 | 60% | 1.000 |
| `high_dim_noise_3` | 2:10 | 2 | 80% | 0.530 |
| `many_12` | 2:10 | 10; upper-bound warning | 100% | 0.840 |
| `many_12` | 2:15 | Tie: 10 and 13; no recommendation | 40% each | Not defined |

The stress fixture has four generating groups plus 30 outliers. Its all-row
ARI is 0.865, compared with inlier ARI 0.924. This is not perfect recovery, and
unanimous method voting does not establish that three is the true group count.

The uniform control selected K = 6 and the single-Gaussian control selected
K = 2, both with 40% agreement, although Gap selected K = 1 in each. The voting
engine therefore remains a descriptive method-comparison tool, not a
calibrated test for whether discrete clusters exist.

Rings and moons each selected the upper boundary K = 10, with ARI 0.238 and
0.198 respectively. These illustrate K-means model mismatch, not a reason to
assert that the generating geometric groups are the unique optimum for the
K-means objective. `overlap_3` also selected the upper boundary. All four
upper-bound warnings are preserved in the output.

For `outliers_3`, Dunn tied exactly and abstained. Its vote denominator was
four, rather than five, and consensus agreement was 50%. On the extended
`many_12` run, the observed WCSS curve was non-monotonic and elbow abstained;
the curve was not forced to be monotonic or minimized to fabricate a knee.

The two `many_12` runs use the same base seed but separate full Gap simulations.
Their comparison includes changes to the reference random stream, unlike the
common-reference-controlled range experiment in the separate Monte Carlo
study. No frequency or causal attribution is inferred from this single pair.

Generating labels describe the fixture construction, not certified optimal
cluster counts for every criterion. Statistical disagreement is not relabelled
as software failure.

## Artifacts

`supplied_benchmark_summary.csv` includes every job and warning.
`supplied_benchmark_methods.csv` includes each method's eligibility, selected K
and both recovery metrics. `supplied_benchmark.rds` retains every full result,
fitted partition, method score curve, settings, manifest and session metadata.
