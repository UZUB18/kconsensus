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
  # Support grades describe the vote count only; no threshold is a confidence level.
  status <- if (n_valid == 0L) {
    "no_valid_votes"
  } else if (length(leaders) > 1L) {
    "tie"
  } else if (max(votes) == n_valid) {
    "unanimous"
  } else if (2L * max(votes) > n_valid) {
    "majority"
  } else {
    "plurality"
  }
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
    status = status,
    n_valid_methods = n_valid,
    agreement = agreement,
    methods = methods,
    flags = consensus_flags(recommended, methods, boundary),
    recommendations = records,
    boundary_warning = boundary
  ), class = c("kconsensus_result", "list"))
}

# Descriptive notes about where votes sit relative to each method's tested range.
# Uses only the standardized records, so it stays independent of method internals.
consensus_flags <- function(recommended, methods, boundary) {
  rows <- list()
  if (boundary) {
    rows[[length(rows) + 1L]] <- c(
      "upper_boundary",
      sprintf(
        "K = %d is the highest K tested; larger values were not evaluated.",
        recommended
      )
    )
  }

  voters <- methods[methods$included, , drop = FALSE]
  if (!is.na(recommended) && recommended > 1L) {
    for_winner <- voters[voters$preferred_k == recommended, , drop = FALSE]
    # A voter that evaluated fewer clusters and still chose the winner answers
    # the boundary question, so flag only when none of them could.
    if (all(for_winner$tested_min == recommended)) {
      message <- sprintf(
        paste(
          "K = %d is the smallest K evaluated by %s, so none of the methods",
          "voting for it could have chosen fewer clusters."
        ),
        recommended,
        format_list(friendly_method_name(for_winner$method))
      )
      rows[[length(rows) + 1L]] <- c("lower_boundary", message)
    }
  }

  single <- voters$preferred_k == 1L
  if (any(single) && any(!single)) {
    others <- voters[!single, , drop = FALSE]
    message <- sprintf(
      "%s voted for K = 1 (no subdivision), while %d other method%s voted for K >= 2.",
      format_list(friendly_method_name(voters$method[single])),
      nrow(others),
      if (nrow(others) == 1L) "" else "s"
    )
    untested <- others$tested_min > 1L
    if (any(untested)) {
      message <- paste(message, sprintf(
        "%s did not evaluate K = 1, so %s not test it.",
        format_list(friendly_method_name(others$method[untested])),
        if (sum(untested) == 1L) "that vote does" else "those votes do"
      ))
    }
    rows[[length(rows) + 1L]] <- c("single_cluster_vote", message)
  }

  data.frame(
    flag = vapply(rows, `[[`, character(1), 1L),
    message = vapply(rows, `[[`, character(1), 2L)
  )
}

format_list <- function(x) {
  if (length(x) <= 1L) {
    return(paste(x, collapse = ""))
  }
  paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
}

format_percent <- function(p) {
  ifelse(
    is.na(p),
    "NA",
    ifelse(
      abs(p - round(p)) < 1e-6,
      sprintf("%.0f%%", p),
      sprintf("%.1f%%", p)
    )
  )
}
