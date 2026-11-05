# Equal-weight vote agreement is descriptive, not statistical confidence.
compute_consensus <- function(recommendations) {
  required <- c(
    "method", "preferred_k", "status", "eligible", "reason", "scores", "diagnostics"
  )
  if (!is.list(recommendations) || length(recommendations) == 0L) {
    stop("`recommendations` must be a nonempty list of standardized records.",
      call. = FALSE
    )
  }
  records <- lapply(recommendations, function(record) {
    if (!is.list(record) || !all(required %in% names(record))) {
      stop("Every recommendation must be a complete standardized method record.",
        call. = FALSE
      )
    }
    do.call(method_recommendation, record[required])
  })
  method_names <- vapply(records, \(record) record$method, character(1))
  if (anyDuplicated(method_names)) {
    stop("Method names must be distinct; each method can cast only one vote.",
      call. = FALSE
    )
  }
  names(records) <- method_names

  methods <- do.call(rbind, lapply(records, function(record) {
    tested <- record$scores$k
    data.frame(
      method = record$method,
      preferred_k = record$preferred_k,
      status = record$status,
      eligible = record$eligible,
      included = record$status == "valid" && record$eligible,
      reason = record$reason,
      tested_min = if (length(tested)) min(tested) else NA_integer_,
      tested_max = if (length(tested)) max(tested) else NA_integer_
    )
  }))
  rownames(methods) <- NULL
  tested_k <- sort(unique(unlist(lapply(records, \(record) record$scores$k))))
  n_valid <- sum(methods$included)
  votes <- tabulate(
    match(methods$preferred_k[methods$included], tested_k),
    nbins = length(tested_k)
  )
  agreement <- data.frame(
    k = as.integer(tested_k),
    votes = votes,
    agreement_percent = if (n_valid > 0L) 100 * votes / n_valid else rep(NA_real_, length(votes))
  )
  leaders <- if (n_valid > 0L) agreement$k[votes == max(votes)] else integer()
  recommended <- if (length(leaders) == 1L) leaders else NA_integer_
  boundary <- !is.na(recommended) && recommended == max(tested_k)
  if (boundary) {
    warning(
      sprintf("Consensus winner K = %s is the highest tested K; larger values were not evaluated.",
        recommended
      ),
      call. = FALSE
    )
  }

  structure(list(
    recommended_k = recommended,
    tied_candidates = if (length(leaders) > 1L) leaders else integer(),
    status = if (n_valid == 0L) "no_valid_votes" else if (length(leaders) > 1L) "tie" else "unique_winner",
    n_valid_methods = n_valid,
    agreement = agreement,
    methods = methods,
    recommendations = records,
    boundary_warning = boundary
  ), class = c("kconsensus_result", "list"))
}
