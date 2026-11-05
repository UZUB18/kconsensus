#' Compare K-means cluster counts using method agreement
#'
#' Fits each candidate once for the four internal indices and WCSS. Gap uses
#' separate reference simulations and can recommend one cluster. Variables are
#' not standardized: pass `scale(x)` explicitly when appropriate.
#'
#' Invalid arguments stop immediately. A calculation that fails during the
#' analysis does not: if K-means fails or does not converge at some K, or an
#' index is undefined there, the methods that need that K abstain; if Gap
#' fails, Gap abstains. A warning lists the failures, and [summary()] shows each
#' abstaining method's reason. Failed fits are kept in `fits` as the error
#' condition.
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
  # Argument errors stop before any fitting; calculation failures do not.
  check_simulation_count(B)
  check_min_strength(elbow_min_strength)
  fits <- fit_clusters(x, k, seed = seed)
  indices <- compute_indices(x, fits)
  problems <- attr(indices, "problems")

  gap <- tryCatch(
    compute_gap(x, k_max = max(k), B = B, seed = seed),
    error = function(error) error
  )
  undefined_wcss <- indices$k[!is.finite(indices$wcss)]
  elbow <- if (length(undefined_wcss) > 0L) {
    simpleError(sprintf(
      "WCSS is undefined at K = %s.", paste(undefined_wcss, collapse = ", ")
    ))
  } else {
    compute_elbow(indices$k, indices$wcss, min_strength = elbow_min_strength)
  }

  failures <- c(
    sprintf("K = %s: %s", problems$k, problems$message),
    if (inherits(gap, "error")) paste("Gap:", conditionMessage(gap))
  )
  if (length(failures) > 0L) {
    warning(
      paste0(
        "Some calculations failed, so the affected methods abstain ",
        "(see summary()):\n",
        paste0("* ", failures, collapse = "\n")
      ),
      call. = FALSE
    )
  }

  result <- compute_consensus(recommend_methods(indices, gap, elbow))
  result$fits <- fits
  result$settings <- list(k = k, seed = seed, B = B, elbow_min_strength = elbow_min_strength)
  result$preprocessing <- attr(indices, "preprocessing")
  result
}
