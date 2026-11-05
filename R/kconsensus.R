#' Compare K-means cluster counts using method agreement
#'
#' Fits each candidate once for the four internal indices and WCSS. Gap uses
#' separate reference simulations and can recommend one cluster. Variables are
#' not standardized: pass `scale(x)` explicitly when appropriate.
#'
#' @param x A finite numeric matrix or numeric data frame.
#' @param k Distinct candidate cluster counts, with `2 <= k < nrow(x)` and enough
#'   distinct observations for every candidate.
#' @param seed A nonnegative integer controlling reproducible local RNG scopes.
#' @param B Number of Gap reference simulations; at least two. Small values are
#'   useful for software examples, not precise Monte Carlo estimates.
#' @param elbow_min_strength Optional user-supplied, uncalibrated elbow threshold.
#'   The elbow method abstains when this is `NULL`.
#' @return A `kconsensus_result` containing recommendations, all method scores,
#'   fitted partitions, agreement percentages, method eligibility and boundary
#'   diagnostics. Its main fields:
#'   * `recommended_k`: the single leading K, or `NA` for a tie or no votes.
#'   * `status`: the support for that K, one of `"unanimous"`, `"majority"`
#'     (more than half of the valid votes), `"plurality"` (most votes but no
#'     majority; a weak preference), `"tie"` or `"no_valid_votes"`.
#'   * `flags`: a data frame of descriptive notes (`flag`, `message`):
#'     `"upper_boundary"` when the winner is the highest K tested,
#'     `"lower_boundary"` when it is the smallest K that every method voting
#'     for it evaluated, and `"single_cluster_vote"` when a method votes for
#'     K = 1 while others vote for K >= 2.
#'   * `agreement`, `methods`, `recommendations`, `fits`, `settings` and
#'     `preprocessing`.
#'
#'   Agreement is descriptive, not a probability that a cluster count is true.
#'   Use [summary.kconsensus_result()] for an explanation and
#'   [as.data.frame.kconsensus_result()] to extract tables.
#' @examples
#' result <- kconsensus(scale(iris[, 1:4]), k = 2:5, B = 2)
#' summary(result)
#' plot(result, type = "consensus")
#' @export
kconsensus <- function(x, k = 2:10, seed = 6749L, B = 100L, elbow_min_strength = NULL) {
  fits <- fit_clusters(x, k, seed = seed)
  indices <- compute_indices(x, fits)
  gap <- compute_gap(x, k_max = max(k), B = B, seed = seed)
  elbow <- compute_elbow(indices$k, indices$wcss, min_strength = elbow_min_strength)
  result <- compute_consensus(recommend_methods(indices, gap, elbow))
  result$fits <- fits
  result$settings <- list(k = k, seed = seed, B = B, elbow_min_strength = elbow_min_strength)
  result$preprocessing <- attr(indices, "preprocessing")
  result
}
