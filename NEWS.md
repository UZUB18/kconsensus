# kconsensus 0.1.0

First usable release.

## Choosing K

* `kconsensus()` fits K-means once per candidate K and lets the silhouette,
  Calinski-Harabasz, Davies-Bouldin and Dunn indices, the gap statistic and an
  optional elbow rule vote on the number of clusters. Data are used as supplied;
  nothing is standardized automatically.
* `status` grades the support for the leading K as `"unanimous"`, `"majority"`
  (more than half of the valid votes), `"plurality"` (most votes but no
  majority), `"single_vote"` (only one method voted), `"tie"` or
  `"no_valid_votes"`. Ties and missing votes give no recommended K.
* `flags` adds descriptive notes that never change a vote: `upper_boundary`,
  `lower_boundary` (no method voting for the winner evaluated a smaller K) and
  `single_cluster_vote` (a method voted for K = 1 while others voted for
  subdivisions).
* Methods abstain, with a recorded reason, on exact score ties, undefined
  scores and failed calculations. A K-means error or non-convergence at one K,
  a non-finite index value, or a Gap failure no longer stops the analysis; a
  warning lists the failures instead. Invalid arguments still stop before any
  fitting starts.
* `methods` selects which methods run and vote, `nstart` sets the number of
  K-means starts (including Gap's reference fits), and `verbose` shows progress
  in interactive sessions (`options(kconsensus.verbose = FALSE)` silences it).
  Leaving out `"gap"`, `"silhouette"` and `"dunn"` makes large datasets
  practical.
* A single candidate K is rejected: choosing K needs at least two candidates.
* The error for `NaN` input points at `scale()` on a constant column, its most
  common cause.

## Results

* `print()` gives a short overview, `summary()` explains the support, runner-up,
  abstentions, flags and caveats, and `as.data.frame()` returns the methods,
  agreement or long-format scores table.
* `plot()` draws consensus bars, raw index curves or a method-by-K evidence
  matrix as customizable ggplot objects.

## Documentation

* The README describes the package with worked examples, and
  `vignette("choosing-k")` walks through a dataset where the methods agree and
  one where they do not.
