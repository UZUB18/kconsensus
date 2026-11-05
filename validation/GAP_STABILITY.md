# Gap seed and simulation-count stability

## Scope

This preliminary study holds the supplied uniform and single-Gaussian datasets
fixed and varies only the calculation seed and number of reference simulations.
The uniform dataset has 600 rows and two features; the Gaussian dataset has
550 rows and two features. Neither is standardized or otherwise modified.

The initial plan was reduced to five seeds after a measured runtime pilot.
The five reproducible seeds are 8614, 4544, 8592, 6666 and 4549, sampled using
`withr::with_seed(8053L, sample.int(10000L, 5L))`. Each is used at B = 100, 500
and 1,000 on both controls, giving 30 completed runs.

All runs call the unchanged package Gap wrapper: K = 1:10, 25 K-means starts,
100 maximum iterations, `d.power = 1`, `spaceH0 = "scaledPCA"`, and
`firstSEmax` selection. The same seed is paired across simulation counts.
Input-file and implementation hashes agree across batches, and the observed
log(W) curves are identical across B within every dataset/seed pair. This
last check verifies dispersions, not a direct comparison of partition labels.

## Results

| Reference simulations B | Uniform: selected K = 1 | Gaussian: selected K = 1 |
|---:|---:|---:|
| 100 | 5/5 | 5/5 |
| 500 | 5/5 | 5/5 |
| 1,000 | 5/5 | 5/5 |

There were no failed runs and no detected selection changes across the tested
seeds or simulation counts. The first local maximum was K = 1 in every run.
The adjacent-step `Tibs2001SEmax` rule also selected K = 1 throughout, but it is
a different rule from `firstSEmax`.

For uniform data, `globalmax` selected K = 7 and `globalSEmax` selected K = 3
in every run at every B. For Gaussian data, all four selection rules selected
K = 1 throughout. Thus, the uniform-data disagreement between local and global
rules persists after increasing B; it is not eliminated by these Monte Carlo
precision checks. Alternative rules are diagnostics only, not replacements
chosen after seeing the results.

The uniform difference Gap(1) - Gap(2) was positive in every run: 0.00169 to
0.00398 at B = 100 and 0.00243 to 0.00355 at B = 1,000. The corresponding
Gaussian differences were 0.08265 to 0.08828 and 0.08513 to 0.08620. These
differences describe the fixed samples and are not hypothesis-test statistics.

## Precision is not the same as the selection-rule SE

The installed `cluster::clusGap` implementation calculates
`SE.sim = sqrt((1 + 1/B) * var(reference log(W)))`. It is not the Monte Carlo
standard error of the reference mean. The latter is
`SE.sim / sqrt(B + 1)`.

For K = 1, the mean estimated Monte Carlo standard error across seeds decreased
from 0.00132 to 0.00042 for uniform data, and from 0.00153 to 0.00047 for
Gaussian data, when B increased from 100 to 1,000. Meanwhile, mean `SE.sim`
remained approximately 0.013 for uniform and 0.015 for Gaussian data. A nearly
constant `SE.sim` with increasing B is therefore not evidence of a problem.

## Interpretation boundaries

These results support numerical stability of the present K = 1 decision for
these two fixed datasets under the tested seeds and settings. Five seeds can
miss infrequent changes; seed-to-seed variance estimates also have substantial
uncertainty. Observed-data K-means solutions at K >= 2 can vary across seeds,
so seed variation is not exclusively reference-simulation variation.

This is not a population false-positive study: no new datasets were generated.
It does not establish that Gap is a calibrated test for absence of clusters,
nor does it validate using Gap to override the other methods. The different
candidate domains in the voting pool remain unchanged.

A descriptive flag stating that Gap recommends one cluster while the other
methods prefer subdivisions would be consistent with these observations.
An automatic claim that no clusters exist would require broader validation
across independently generated null and clustered datasets. No warning rule,
decision threshold or package behavior was changed during this study.

## Reproduce

Run from the project root; the full preliminary study takes several minutes:

```r
devtools::load_all()
local({
  environment <- new.env(parent = globalenv())
  sys.source("validation/run_gap_stability.R", envir = environment)
  batches <- lapply(c(100L, 500L, 1000L), function(B) {
    environment$gap_stability_batch(B = B, workers = 4L)
  })
  environment$save_gap_stability(batches)
})
```

`gap_stability_summary.csv` contains the six dataset/B summaries.
`gap_stability_trials.csv` retains every seed, selection-rule result, warning
and error. `gap_stability.rds` additionally retains the full curves, hashes,
settings and session information. These validation artifacts are excluded from
routine package builds and checks.
