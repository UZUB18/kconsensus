#' Compare K-means cluster counts using method agreement
#'
#' Fits K-means once for each candidate K for the internal indices and elbow.
#' Gap independently refits both the observed data and simulated reference
#' data, so its partitions may differ from the stored fits. It can recommend
#' one cluster. Variables are not standardized: pass `scale(x)` explicitly
#' when appropriate.
#'
#' Gap retains `cluster::clusGap()`'s historical `d.power = 1` for compatibility
#' with existing results, using unsquared distances rather than the squared
#' distances of `d.power = 2`. It uses PCA-rotated reference data
#' (`spaceH0 = "scaledPCA"`) and `firstSEmax` selection with `SE.factor = 1`.
#' These settings can affect recommendations; agreement is not a sensitivity
#' analysis of these choices.
#'
#' Invalid arguments stop immediately, before any fitting. A calculation that
#' fails during the analysis does not: if K-means fails or does not converge
#' at some K, or an index is undefined there, the methods that need that K
#' abstain; if Gap fails, Gap abstains. A warning lists the failures, and
#' [summary()] shows each abstaining method's reason. Failed fits are kept in
#' `fits` as the error condition.
#'
#' @section Runtime:
#' The gap statistic is usually by far the slowest step: it runs roughly
#' `B * max(k) * nstart` K-means fits on simulated data. For a first look at a
#' large dataset, use a smaller `B` or `nstart`, or leave `"gap"` out of
#' `methods`. Silhouette needs all pairwise distances, so its memory grows with
#' the square of the number of rows, and Dunn's computing time grows the same
#' way. Leave them out of `methods` for very large datasets.
#'
#' @param x A finite numeric matrix or numeric data frame.
#' @param k At least two distinct candidate cluster counts, with
#'   `2 <= k < nrow(x)` and enough distinct observations for every candidate.
#'   When Gap is enabled, candidates must include every integer from 2 to
#'   `max(k)`, in any order. Gap also evaluates K = 1, which has no stored fit.
#' @param methods The methods that vote: any of `"silhouette"`,
#'   `"calinski_harabasz"`, `"davies_bouldin"`, `"dunn"`, `"gap"` and
#'   `"elbow"`. All six are calculated by default: five voting methods plus
#'   an optional elbow vote, enabled by setting `elbow_min_strength`.
#' @param seed A nonnegative integer controlling reproducible local RNG scopes.
#'   The caller's random-number state is left unchanged.
#' @param B Number of Gap reference simulations; at least two. Small values are
#'   useful for quick looks and examples, not precise Monte Carlo estimates.
#' @param nstart Number of random starts for every K-means fit, including Gap's
#'   fits to observed and simulated data. Fewer starts are faster but more likely
#'   to miss the best partition.
#' @param elbow_min_strength Optional user-supplied, uncalibrated elbow threshold.
#'   The elbow method abstains when this is `NULL`.
#' @param verbose Show progress messages? Defaults to the `kconsensus.verbose`
#'   option, or `TRUE` in interactive sessions. Set
#'   `options(kconsensus.verbose = FALSE)` to silence them everywhere.
#' @return A `kconsensus_result` containing recommendations, all method scores,
#'   fitted partitions, agreement percentages, method eligibility and boundary
#'   diagnostics. Its main fields:
#'   * `recommended_k`: the single leading K, or `NA` for a tie or no votes.
#'   * `status`: the support for that K, one of `"unanimous"`, `"majority"`
#'     (more than half of the valid votes), `"plurality"` (most votes but no
#'     majority; a weak preference), `"single_vote"` (only one method voted),
#'     `"tie"` or `"no_valid_votes"`.
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
#'
#' # A faster look that skips Gap and the distance-based indices
#' quick <- kconsensus(
#'   scale(iris[, 1:4]),
#'   k = 2:6,
#'   methods = c("calinski_harabasz", "davies_bouldin", "elbow")
#' )
#' quick
#' @export
kconsensus <- function(
  x,
  k = 2:10,
  methods = c(
    "silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "gap", "elbow"
  ),
  seed = 6749L,
  B = 100L,
  nstart = 25L,
  elbow_min_strength = NULL,
  verbose = getOption("kconsensus.verbose", interactive())
) {
  # Argument errors stop before any fitting; calculation failures do not.
  methods <- check_methods(methods)
  check_flag(verbose, "verbose")
  input <- validate_input(x, k)
  if (length(input$k) < 2L) {
    stop("`k` must contain at least two candidate cluster counts to compare.",
      call. = FALSE
    )
  }
  if ("gap" %in% methods && (min(k) != 2 || length(k) != max(k) - 1)) {
    stop("When Gap is enabled, `k` must be contiguous and start at 2 (2:max(k)).",
      call. = FALSE
    )
  }
  check_simulation_count(B)
  check_nstart(nstart)
  check_min_strength(elbow_min_strength)
  progress <- function(...) {
    if (verbose) message(sprintf(...))
  }

  progress(
    "Fitting K-means for K = %s (%d random starts each).",
    format_k_values(k), as.integer(nstart)
  )
  fits <- fit_clusters(x, k, seed = seed, nstart = nstart)
  index_methods <- intersect(methods, index_method_names)
  if (length(index_methods) > 0L) {
    progress(
      "Scoring the fits with %s.",
      format_list(friendly_method_name(index_methods))
    )
  }
  indices <- compute_indices(x, fits, indices = index_methods)
  problems <- attr(indices, "problems")

  gap <- NULL
  if ("gap" %in% methods) {
    progress(
      paste(
        "Running the gap statistic for K = 1:%d with %d reference datasets",
        "(usually the slowest step)."
      ),
      as.integer(max(k)), as.integer(B)
    )
    gap <- tryCatch(
      compute_gap(
        x,
        k_max = max(k), B = B, seed = seed, nstart = nstart, verbose = verbose
      ),
      error = function(error) error
    )
  }
  elbow <- NULL
  if ("elbow" %in% methods) {
    undefined_wcss <- indices$k[!is.finite(indices$wcss)]
    elbow <- if (length(undefined_wcss) > 0L) {
      simpleError(sprintf(
        "WCSS is undefined at K = %s.", paste(undefined_wcss, collapse = ", ")
      ))
    } else {
      compute_elbow(indices$k, indices$wcss, min_strength = elbow_min_strength)
    }
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

  result <- compute_consensus(recommend_methods(indices, gap, elbow, methods = methods))
  result$fits <- fits
  result$settings <- list(
    k = k,
    methods = methods,
    seed = seed,
    B = B,
    nstart = nstart,
    elbow_min_strength = elbow_min_strength
  )
  result$preprocessing <- attr(indices, "preprocessing")
  result
}
