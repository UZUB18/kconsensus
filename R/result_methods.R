#' Summarize and print a kconsensus result
#'
#' `summary()` explains the vote: how much support the leading K has, what
#' each method chose, which methods did not vote and why, and any descriptive
#' flags. `print()` shows a short overview.
#'
#' The support level describes the vote count only:
#' * `"unanimous"`: every valid method chose the same K.
#' * `"majority"`: the leading K has more than half of the valid votes.
#' * `"plurality"`: the leading K has the most votes but no majority, so it is
#'   a weak preference.
#' * `"tie"`: several K share the most votes and no K is recommended.
#' * `"no_valid_votes"`: no method cast a valid vote.
#'
#' None of these levels is a statistical confidence statement.
#'
#' @param object A `kconsensus_result` returned by [kconsensus()].
#' @param x A `kconsensus_result`, or a `summary.kconsensus_result` for its
#'   print method.
#' @param ... Unused; present for S3 compatibility.
#'
#' @return `summary()` returns a `summary.kconsensus_result` list with the
#'   recommendation, support level, runner-up K, the K values that received
#'   votes, a per-method table, flags, settings and preprocessing record.
#'   The print methods return their input invisibly.
#' @seealso [as.data.frame.kconsensus_result()] to extract tables,
#'   [plot.kconsensus_result()] for diagnostics.
#' @examples
#' result <- kconsensus(scale(iris[, 1:4]), k = 2:5, B = 2)
#' result
#' summary(result)
#' @export
summary.kconsensus_result <- function(object, ...) {
  validate_kconsensus_result(object, "object")
  agreement <- object$agreement
  votes <- agreement[agreement$votes > 0L, , drop = FALSE]
  rownames(votes) <- NULL

  runner_up <- integer()
  if (has_single_winner(object)) {
    others <- votes[votes$k != object$recommended_k, , drop = FALSE]
    if (nrow(others) > 0L) {
      runner_up <- others$k[others$votes == max(others$votes)]
    }
  }

  methods <- result_methods_table(object)
  methods$runner_up <- vapply(
    object$recommendations[match(methods$method, names(object$recommendations))],
    function(record) {
      candidates <- record$diagnostics$runner_up_k
      if (identical(record$status, "valid") && length(candidates) > 0L) {
        paste(candidates, collapse = ", ")
      } else {
        NA_character_
      }
    },
    character(1)
  )

  structure(list(
    recommended_k = object$recommended_k,
    status = object$status,
    tied_candidates = object$tied_candidates,
    runner_up_k = runner_up,
    n_valid_methods = object$n_valid_methods,
    n_methods = nrow(object$methods),
    support = support_detail(object),
    votes = votes,
    methods = methods,
    flags = result_flags(object),
    verdict = verdict_text(object),
    settings = object$settings,
    preprocessing = object$preprocessing
  ), class = "summary.kconsensus_result")
}

#' @rdname summary.kconsensus_result
#' @export
print.summary.kconsensus_result <- function(x, ...) {
  width <- max(40L, min(getOption("width", 80L), 100L) - 2L)
  wrap <- function(text, initial = "", prefix = "") {
    writeLines(strwrap(text, width = width, initial = initial, prefix = prefix))
  }
  field <- function(name, value) {
    cat(sprintf("%-15s%s\n", paste0(name, ":"), value))
  }

  cat("kconsensus: number of clusters for K-means\n")
  cat(strrep("-", 44L), "\n", sep = "")
  field("Recommended K", if (is.na(x$recommended_k)) "none" else x$recommended_k)
  field("Support", x$support)
  if (length(x$runner_up_k) > 0L) {
    runner_votes <- x$votes$votes[match(x$runner_up_k[1L], x$votes$k)]
    field("Runner-up", sprintf(
      "K = %s (%d %s%s)",
      format_list(x$runner_up_k),
      runner_votes,
      if (runner_votes == 1L) "vote" else "votes",
      if (length(x$runner_up_k) > 1L) " each" else ""
    ))
  }
  field("Valid votes", sprintf("%d of %d methods", x$n_valid_methods, x$n_methods))
  if (!is.null(x$settings)) {
    field("Candidate K", format_k_values(x$settings$k))
    field("Seed", x$settings$seed)
    field("Gap B", x$settings$B)
  }

  cat("\nVotes\n")
  if (nrow(x$votes) == 0L) {
    cat("  No valid votes.\n")
  } else {
    writeLines(paste0(
      "  ",
      format(paste("K =", x$votes$k)), "  ",
      format(sprintf(
        "%d %s", x$votes$votes, ifelse(x$votes$votes == 1L, "vote", "votes")
      )), "  ",
      format(format_percent(x$votes$agreement_percent), justify = "right")
    ))
  }

  methods <- x$methods
  vote <- ifelse(
    methods$included,
    as.character(methods$preferred_k),
    ifelse(
      is.na(methods$preferred_k),
      "-",
      paste(methods$preferred_k, "(excluded)")
    )
  )
  table <- data.frame(
    Method = friendly_method_name(methods$method),
    Vote = vote,
    `Runner-up` = ifelse(is.na(methods$runner_up), "-", methods$runner_up),
    Margin = ifelse(
      is.na(methods$margin),
      "-",
      trimws(formatC(methods$margin, digits = 3L, format = "g"))
    ),
    check.names = FALSE
  )
  cat("\nMethods\n")
  writeLines(paste0("  ", format_text_table(table)))
  if (any(!is.na(methods$margin))) {
    wrap(
      paste(
        "Margin: raw score difference between the best and runner-up K,",
        "comparable only within one method."
      ),
      initial = "  ", prefix = "  "
    )
  }

  not_voting <- methods[!methods$included, , drop = FALSE]
  if (nrow(not_voting) > 0L) {
    cat("\nNot voting\n")
    tags <- ifelse(not_voting$status == "valid", "excluded", not_voting$status)
    for (i in seq_len(nrow(not_voting))) {
      wrap(
        sprintf(
          "%s [%s]: %s",
          friendly_method_name(not_voting$method[i]),
          tags[i],
          not_voting$reason[i]
        ),
        initial = "  ", prefix = "    "
      )
    }
  }

  if (nrow(x$flags) > 0L) {
    cat("\nFlags\n")
    for (message in x$flags$message) {
      wrap(message, initial = "  ! ", prefix = "    ")
    }
  }

  cat("\n")
  wrap(x$verdict)
  cat("\n")
  wrap(paste(
    "Note: vote percentages describe agreement between methods,",
    "not statistical confidence."
  ))
  if (isFALSE(x$preprocessing$standardized_by_package)) {
    wrap("Data were used as supplied; kconsensus did not standardize them.")
  }
  invisible(x)
}

#' @rdname summary.kconsensus_result
#' @export
print.kconsensus_result <- function(x, ...) {
  validate_kconsensus_result(x)
  cat("<kconsensus result>\n")
  cat("Recommended K: ", recommendation_line(x), "\n", sep = "")
  votes <- x$agreement[x$agreement$votes > 0L, , drop = FALSE]
  if (nrow(votes) > 0L) {
    cat(
      "Votes: ",
      paste(sprintf("K = %d (%d)", votes$k, votes$votes), collapse = ", "),
      "\n",
      sep = ""
    )
  }
  flags <- result_flags(x)
  if (nrow(flags) > 0L) {
    cat("Flags: ", paste(flags$flag, collapse = ", "), "\n", sep = "")
  }
  cat("Use summary() for reasons and flags, and plot() for diagnostics.\n")
  invisible(x)
}

#' Extract kconsensus results as a data frame
#'
#' @param x A `kconsensus_result` returned by [kconsensus()].
#' @param row.names Optional row names for the returned data frame.
#' @param optional Ignored; present for compatibility with the generic.
#' @param ... Unused; present for S3 compatibility.
#' @param what Which table to return:
#'   * `"methods"` (default): one row per method, with its preferred K,
#'     status, eligibility, whether its vote was counted (`included`), the
#'     reason, the tested K range and `margin`, the raw score difference
#'     between its best and runner-up K. Margins are comparable only within a
#'     method and are `NA` for Gap and elbow.
#'   * `"agreement"`: one row per evaluated K, with votes and agreement
#'     percentage.
#'   * `"scores"`: one row per method and evaluated K, with the method's
#'     criterion value (`criterion` names the score column used), Gap's
#'     simulation standard error in `se`, and whether that K is the method's
#'     preferred K (`preferred`) and a counted vote (`vote_counted`).
#'
#' @return A data frame.
#' @examples
#' result <- kconsensus(scale(iris[, 1:4]), k = 2:5, B = 2)
#' as.data.frame(result)
#' head(as.data.frame(result, what = "scores"))
#' @export
as.data.frame.kconsensus_result <- function(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  what = c("methods", "agreement", "scores")
) {
  validate_kconsensus_result(x)
  what <- match.arg(what)
  out <- switch(
    what,
    methods = result_methods_table(x),
    agreement = x$agreement,
    scores = result_scores_table(x)
  )
  row.names(out) <- row.names
  out
}

result_methods_table <- function(x) {
  out <- x$methods
  records <- x$recommendations[match(out$method, names(x$recommendations))]
  out$margin <- vapply(records, function(record) {
    margin <- record$diagnostics$score_gap
    if (is.numeric(margin) && length(margin) == 1L && is.finite(margin)) {
      as.numeric(margin)
    } else {
      NA_real_
    }
  }, numeric(1))
  rownames(out) <- NULL
  out
}

result_scores_table <- function(x) {
  rows <- lapply(x$recommendations, function(record) {
    scores <- record$scores
    if (nrow(scores) == 0L) {
      return(NULL)
    }
    scores <- scores[order(scores$k), , drop = FALSE]
    columns <- method_score_columns(record)
    n <- nrow(scores)
    preferred <- !is.na(record$preferred_k) & scores$k == record$preferred_k
    counted <- identical(record$status, "valid") && isTRUE(record$eligible)
    data.frame(
      method = rep(record$method, n),
      k = as.integer(scores$k),
      criterion = rep(
        if (is.null(columns$value)) NA_character_ else columns$value, n
      ),
      value = if (is.null(columns$value)) {
        rep(NA_real_, n)
      } else {
        as.numeric(scores[[columns$value]])
      },
      se = if (is.null(columns$se)) rep(NA_real_, n) else as.numeric(scores[[columns$se]]),
      preferred = preferred,
      vote_counted = preferred & counted
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- data.frame(
      method = character(), k = integer(), criterion = character(),
      value = numeric(), se = numeric(), preferred = logical(),
      vote_counted = logical()
    )
  }
  rownames(out) <- NULL
  out
}

# The score column that represents each method's selection criterion.
method_score_columns <- function(record) {
  scores <- record$scores
  score_cols <- setdiff(names(scores), "k")
  value <- if (identical(record$method, "gap") && "gap" %in% score_cols) {
    "gap"
  } else if (identical(record$method, "elbow") && "wcss" %in% score_cols) {
    "wcss"
  } else if ("score" %in% score_cols) {
    "score"
  } else {
    numeric_cols <- score_cols[vapply(scores[score_cols], is.numeric, logical(1))]
    if (length(numeric_cols) > 0L) numeric_cols[1L] else NULL
  }
  se <- if (identical(record$method, "gap") && "SE.sim" %in% score_cols) {
    "SE.sim"
  } else {
    NULL
  }
  list(value = value, se = se)
}

validate_kconsensus_result <- function(x, arg = "x") {
  required <- c(
    "recommended_k", "tied_candidates", "status", "n_valid_methods",
    "agreement", "methods", "recommendations"
  )
  if (
    !is.list(x) || !all(required %in% names(x)) ||
      !is.data.frame(x$agreement) || !is.data.frame(x$methods) ||
      !is.list(x$recommendations) || length(x$recommendations) == 0L
  ) {
    stop(
      sprintf("`%s` must be a valid `kconsensus_result` object.", arg),
      call. = FALSE
    )
  }
  invisible(x)
}

has_single_winner <- function(x) {
  length(x$recommended_k) == 1L && !is.na(x$recommended_k) &&
    !x$status %in% c("tie", "no_valid_votes")
}

support_label <- function(status) {
  switch(
    status,
    unanimous = "Unanimous",
    majority = "Majority",
    plurality = "Plurality, no majority",
    "Selected"
  )
}

winner_share <- function(x) {
  votes <- x$agreement$votes[match(x$recommended_k, x$agreement$k)]
  sprintf(
    "%d of %d valid votes, %s",
    votes,
    x$n_valid_methods,
    format_percent(100 * votes / x$n_valid_methods)
  )
}

support_detail <- function(x) {
  if (has_single_winner(x)) {
    sprintf("%s (%s)", support_label(x$status), winner_share(x))
  } else if (identical(x$status, "tie")) {
    sprintf("Tie between K = %s", format_list(x$tied_candidates))
  } else {
    "No valid votes"
  }
}

recommendation_line <- function(x) {
  if (has_single_winner(x)) {
    sprintf(
      "%d  (%s: %s)",
      x$recommended_k,
      tolower(support_label(x$status)),
      winner_share(x)
    )
  } else if (identical(x$status, "tie")) {
    sprintf("none  (tie between K = %s)", format_list(x$tied_candidates))
  } else {
    "none  (no valid votes)"
  }
}

verdict_text <- function(x) {
  indices_hint <- "plot(result, type = \"indices\")"
  verdict <- switch(
    x$status,
    unanimous = sprintf("All valid methods agree on K = %d.", x$recommended_k),
    majority = sprintf(
      "Most valid methods agree on K = %d, but not all. Compare the index curves with %s.",
      x$recommended_k, indices_hint
    ),
    plurality = sprintf(
      paste(
        "Weak preference only: K = %d leads without a majority, so the methods",
        "disagree. Inspect %s before choosing K."
      ),
      x$recommended_k, indices_hint
    ),
    tie = sprintf(
      "Inconclusive: K = %s are tied, so no single K is recommended. Inspect %s.",
      format_list(x$tied_candidates), indices_hint
    ),
    no_valid_votes = "Inconclusive: no method cast a valid vote; see the reasons above.",
    ""
  )
  if (has_single_winner(x) && nrow(result_flags(x)) > 0L) {
    verdict <- paste(verdict, "Check the flags above.")
  }
  verdict
}

result_flags <- function(x) {
  if (is.data.frame(x$flags)) {
    x$flags
  } else {
    data.frame(flag = character(), message = character())
  }
}

format_k_values <- function(k) {
  k <- sort(as.integer(k))
  if (length(k) > 2L && all(diff(k) == 1L)) {
    sprintf("%d:%d", k[1L], k[length(k)])
  } else {
    paste(k, collapse = ", ")
  }
}

# Left-aligned plain-text table with a header row, separated by two spaces.
format_text_table <- function(df) {
  columns <- lapply(names(df), function(name) {
    format(c(name, as.character(df[[name]])), justify = "left")
  })
  trimws(do.call(paste, c(columns, sep = "  ")), which = "right")
}
