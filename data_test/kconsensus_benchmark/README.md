# kconsensus synthetic K-selection benchmark

A deterministic benchmark collection for an R package that recommends the number
of clusters using elbow/WCSS, silhouette, gap statistic, Calinski-Harabasz,
Davies-Bouldin, Dunn, and consensus methods.

Generated with seed `20261105`. Regenerate with:

```bash
python generate_benchmarks.py
```

Requires `numpy` and `pandas`. No source dataset or external data is used.

## Where to start

- `data/cluster_stress_test.csv` — primary challenging dataset: 750 rows, two
  numeric features, three large generating groups plus a small fourth nearby,
  and 30 outliers. Generation involves **4 groups plus contamination**;
  the optimal K for K-means is **not** guaranteed to equal 4.
- `data/clear_3.csv` — easy positive control: three well-separated groups.
- `data/clear_5.csv` — easy positive control: five well-separated groups.
- `manifest.csv` — all scenarios, dimensions, generating structure, and what to test.

All input CSVs in `data/` contain **numeric features only** (`x01`, `x02`,...).
There are no label, ID, scenario, or truth columns to accidentally leak into
clustering. Each CSV can be passed directly to `as.matrix(read.csv(...))`.

## Folder structure

- `data/` — 18 valid numeric test datasets, ready for clustering.
- `truth/` — separate synthetic generating-group assignments with `row_index`
  (1-based, corresponding exactly to the row position in data) and
  `generating_group` (1..K, or -1 for injected outliers). Labels may be
  *absent* for unclustered controls.
- `invalid/` — five intentionally invalid inputs for testing errors:
  all identical, NA, Inf, too few distinct values for some K, and character data.
- `manifest.csv` — machine-readable scenario descriptions.
- `generate_benchmarks.py` — full data-generation source.
- `example_usage.R` — R test harness using the proposed `choose_k()` interface.

## R usage

```r
# Set working directory to the extracted kconsensus_benchmark/ folder.
x <- as.matrix(read.csv("data/cluster_stress_test.csv"))

# Once your package implements this proposed API:
library(kconsensus)
res <- choose_k(x, k = 2:10, seed = 42)
summary(res)
plot(res, type = "consensus")
plot(res, type = "indices")
```

For a straightforward sanity check, replace the first line with:

```r
x <- as.matrix(read.csv("data/clear_3.csv"))
```

Use `data/many_12.csv` with `k=2:10` and then `k=2:15` to check upper-
range sensitivity. Test `single_gaussian.csv` and `uniform_no_clusters.csv`
for unwanted overconfidence in forced K>=2 decisions. Use `invalid/` only
for expected-error tests, never for successful clustering runs.

## Testing priorities

1. **Correct implementation:** compare exact numeric metrics with their
   reference R implementations on the *same partitions*, with identical
   distance definitions, index formulas, selection rules, and seeds.
2. **Voting arithmetic:** verify numerator, denominator, abstentions, ties,
   unavailable methods, and upper-K-bound warnings.
3. **Clear positive controls:** `clear_3.csv` and `clear_5.csv` should generally
   provide strong evidence of the respective generating-group counts.
4. **Method disagreement:** `cluster_stress_test.csv`, `overlap_3.csv`,
   `close_split_4.csv`, `unbalanced_4.csv`, and `variable_density_3.csv`.
   These are designed to expose sensitivity, not guaranteed to make any
   particular pair of methods disagree for every implementation.
5. **Model mismatch:** rings and moons represent two geometric groups but
   K-means may partition them badly; check partition recovery, not only K.
6. **No clear cluster structure:** uniform and single-Gaussian cases should
   report uncertainty; an algorithm that must choose K>=2 will still return
   a K despite the absence of discrete generating groups.
7. **Efficiency:** `high_dim_noise_3.csv` (30 columns), `many_12.csv`
   (780 rows), and high requested K ranges.
8. **Input validation:** reject/flag invalid entries appropriately; a data
   set with only two distinct points cannot support three nonempty clusters.

## Important interpretation

`generating_groups` in the manifest describes how the synthetic data were
constructed. It is *not* a certified or uniquely correct optimal K. For
irregular, overlapping, unimodal, or noisy data, different optimization
criteria can legitimately select different K values. A vote fraction is
**method agreement**, not probability that a value of K is correct.

These datasets test the clustering-number selection component, not every
possible future feature of a package. Extend with larger-scale benchmarks,
real labeled data, extreme dimensions, alternative distance metrics, and
bootstrap runs when those features exist.
