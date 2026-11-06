# kconsensus

<!-- badges: start -->
[![R-CMD-check](https://github.com/UZUB18/kconsensus/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/UZUB18/kconsensus/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
<!-- badges: end -->

**Compare cluster counts for K-means, and inspect method agreement.**

kconsensus compares five voting methods (silhouette, Calinski-Harabasz,
Davies-Bouldin, Dunn and the gap statistic), plus an optional elbow vote.
The internal indices and elbow share stored K-means fits; Gap refits the data
independently. The package counts their votes, reports how strong the agreement
is, and says so when there is no clear answer.

![On three clear groups every method votes K = 3. On pure noise the votes scatter, and kconsensus reports a weak plurality instead of a confident answer.](man/figures/README-hero.png)

## Install

``` r
# install.packages("remotes")
remotes::install_github("UZUB18/kconsensus")
```

## Quick start

``` r
library(kconsensus)

result <- kconsensus(scale(iris[, 1:4]), k = 2:10)
result
#> <kconsensus result>
#> Recommended K: 2  (unanimous: 5 of 5 valid votes, 100%)
#> Votes: K = 2 (5)
#> Use summary() for reasons and flags, and plot() for diagnostics.

summary(result)                  # each method's vote, margin and any warnings
plot(result)                     # vote chart
plot(result, type = "indices")   # every method's score across K
```

## Your own data, no coding

A ready-made script reads a CSV or Excel file, cleans it (skips text columns,
constant columns and rows with missing values), chooses K, and saves the plots,
a summary and your data with a `cluster` column next to the file.

``` r
file.copy(system.file("scripts", "find_k_for_my_data.R", package = "kconsensus"), "find_k.R")
file.edit("find_k.R")   # then click Source and pick your file
```

It reports the best-supported K and reminds you to inspect cluster quality and
model assumptions before adopting it.

## Reading the answer

| Status | Meaning | What to do |
|---|---|---|
| `unanimous` | Every valid method chose the same K | Strong method agreement; inspect cluster quality and model assumptions before adopting K |
| `majority` | More than half of valid votes chose it | Majority agreement; inspect cluster quality and model assumptions before adopting K |
| `plurality` | Most votes, but no majority | Weak: inspect the plots before using it |
| `single_vote` | Only one method could vote | No agreement to assess |
| `tie` | Several K share the most votes | No answer; try another K range |
| `no_valid_votes` | No method could vote | No answer; see `summary()` |

**Flags** add warnings without changing the vote: `upper_boundary` (the winner
is the largest K you tested, so try more), `lower_boundary` (the winner is the
smallest K its voters could evaluate) and `single_cluster_vote` (the gap
statistic says the data may not split at all).

## Good to know

* **Choose your columns.** Only include variables that should define the
  groups; unrelated columns blur the clusters.
* **Scale first** when variables use different units: `kconsensus(scale(x))`.
  Nothing is standardized for you.
* **Agreement is not proof.** Methods can agree on noise or miss a very small
  group. Vote percentages describe agreement between methods, not the
  probability that K is right. In the [simulation study](validation/README.md),
  all 100 small-group trials chose K = 2 instead of the three generating groups,
  despite unanimous or majority support with no flags.
* **Gap needs a complete range:** include every integer from 2 to `max(k)`
  (for example, `k = 2:10`). Sparse ranges or ranges starting above 2 are allowed
  only when `"gap"` is omitted from `methods`. Gap can still recommend K = 1;
  this means no subdivision and has no partition stored in `result$fits`.
* **Big data?** The gap statistic is the slow part. For a first look use
  `B = 20`, or skip it with
  `methods = c("silhouette", "calinski_harabasz", "davies_bouldin", "elbow")`.
* **Reproducible:** `seed` fixes every random step without touching your
  session's random-number state.

<details>
<summary><b>Five voting methods and the optional elbow vote</b></summary>

| Method | Chooses | Implementation |
|---|---|---|
| Silhouette | Highest average silhouette width | `cluster::silhouette()` |
| Calinski-Harabasz | Highest index | `clusterCrit::intCriteria()` |
| Davies-Bouldin | Lowest index | `clusterCrit::intCriteria()` |
| Dunn | Highest index | `clusterCrit::intCriteria()` |
| Gap statistic | `firstSEmax` rule; can choose K = 1 | `cluster::clusGap()` |
| Elbow (WCSS) | Strongest knee; votes only if you set `elbow_min_strength` | kconsensus |

A method abstains, and leaves the vote count, when its best score is an exact
tie, a score is undefined, or its calculation fails. `summary()` always gives
the reason. Elbow abstains by default (`elbow_min_strength = NULL`), so the
default denominator is at most five valid votes.

Gap independently runs K-means on both the observed and reference data; its
partitions may differ from `result$fits`, even with the same `seed` and `nstart`.
It retains `cluster::clusGap()`'s historical `d.power = 1` (unsquared distances)
for compatibility with existing results, rather than `d.power = 2` (squared
distances). References use `spaceH0 = "scaledPCA"`; selection uses `firstSEmax`
with `SE.factor = 1`. These choices can affect the recommended K; the existing
validation does not measure sensitivity to `d.power`.

</details>

<details>
<summary><b>Other ways to install</b></summary>

From a shared package file:

``` r
install.packages(c("cluster", "clusterCrit", "ggplot2", "withr"))
install.packages("kconsensus_0.1.0.tar.gz", repos = NULL, type = "source")
```

From a local copy of this repository:

``` r
devtools::install("path/to/kconsensus", upgrade = FALSE)
```

</details>

## Learn more

* `vignette("choosing-k", package = "kconsensus")`: one dataset where the
  methods agree, one where they do not, and what to conclude.
* [PROJECT_SHOWCASE.md](PROJECT_SHOWCASE.md) and [validation/](validation/):
  how it was built and tested, including 700 simulated datasets.

MIT licensed.
