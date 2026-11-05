# Exact ties abstain; raw best-versus-runner-up differences stay within a method.
# `notes` explain undefined K (e.g. failed fits) in the abstention reason.
recommend_index <- function(method, k, values, direction, notes = character()) {
  if (
    !is.numeric(values) || is.complex(values) || !is.null(dim(values)) ||
      length(values) != length(k) || length(k) == 0L ||
      !is.character(direction) || length(direction) != 1L ||
      !direction %in% c("max", "min")
  ) {
    stop("Supply numeric scores for each K and direction max or min.", call. = FALSE)
  }
  scores <- data.frame(k = k, score = values)
  if (any(!is.finite(values))) {
    return(method_recommendation(
      method,
      status = "undefined",
      reason = paste(c(
        paste0(
          "Non-finite scores at K = ",
          paste(k[!is.finite(values)], collapse = ", "),
          "."
        ),
        notes
      ), collapse = " "),
      scores = scores,
      diagnostics = list(selection_rule = direction)
    ))
  }

  ordering <- order(values, decreasing = direction == "max")
  best <- as.numeric(values[ordering[1L]])
  best_k <- k[values == best]
  runner_up <- if (length(values) > 1L) as.numeric(values[ordering[2L]]) else NA_real_
  diagnostics <- list(
    selection_rule = direction,
    best_k = best_k,
    best_score = best,
    runner_up_k = k[which(values == runner_up)],
    runner_up_score = runner_up,
    score_gap = abs(best - runner_up)
  )
  tied <- length(best_k) != 1L
  method_recommendation(
    method,
    preferred_k = if (tied) NA_integer_ else best_k,
    status = if (tied) "ambiguous" else "valid",
    reason = if (tied) {
      paste("Exact best-score tie at K =", paste(best_k, collapse = ", "))
    } else {
      paste("Unique", if (direction == "max") "maximum" else "minimum", "score.")
    },
    scores = scores,
    diagnostics = diagnostics
  )
}

# Method names in their canonical (output) order.
index_method_names <- c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn")
method_names <- c(index_method_names, "gap", "elbow")

# Validate a user-supplied method selection and return it in canonical order.
check_methods <- function(methods) {
  if (
    !is.character(methods) || length(methods) == 0L || anyNA(methods) ||
      !all(methods %in% method_names) || anyDuplicated(methods)
  ) {
    stop(
      sprintf(
        "`methods` must be distinct names from: %s.",
        paste0("\"", method_names, "\"", collapse = ", ")
      ),
      call. = FALSE
    )
  }
  method_names[method_names %in% methods]
}

# Adapt existing calculation results without rerunning any clustering or scoring.
# Only the requested methods get a record; gap and elbow may be NULL or an error.
recommend_methods <- function(indices, gap = NULL, elbow = NULL, methods = method_names) {
  methods <- check_methods(methods)
  directions <- c(
    silhouette = "max", calinski_harabasz = "max",
    davies_bouldin = "min", dunn = "max"
  )
  index_methods <- intersect(names(directions), methods)
  if (
    !is.data.frame(indices) ||
      !all(c("k", index_methods) %in% names(indices))
  ) {
    stop("`indices` must contain k and a score column for every requested index.",
      call. = FALSE
    )
  }
  problems <- attr(indices, "problems")
  records <- lapply(index_methods, function(method) {
    undefined_k <- indices$k[!is.finite(indices[[method]])]
    notes <- if (is.data.frame(problems)) {
      relevant <- problems[problems$k %in% undefined_k, , drop = FALSE]
      sprintf("K = %s: %s", relevant$k, relevant$message)
    } else {
      character()
    }
    recommend_index(
      method, indices$k, indices[[method]], directions[[method]], notes = notes
    )
  })
  if ("gap" %in% methods) {
    records[[length(records) + 1L]] <- gap_record(gap)
  }
  if ("elbow" %in% methods) {
    records[[length(records) + 1L]] <- elbow_record(elbow)
  }
  names(records) <- vapply(records, \(record) record$method, character(1))
  records
}

gap_record <- function(gap) {
  if (is.null(gap) || inherits(gap, "error")) {
    return(method_recommendation("gap", reason = if (is.null(gap)) {
      "Gap was not supplied."
    } else {
      conditionMessage(gap)
    }))
  }
  scores <- data.frame(k = seq_len(nrow(gap$gap$Tab)), gap$gap$Tab)
  defined <- all(is.finite(as.matrix(scores[, -1L, drop = FALSE])))
  method_recommendation(
    "gap",
    preferred_k = if (defined) gap$k else NA_integer_,
    status = if (defined) "valid" else "undefined",
    reason = if (defined) gap$selection_method else "Gap contains non-finite scores.",
    scores = scores,
    diagnostics = gap[c("selection_method", "seed", "d_power")]
  )
}

elbow_record <- function(elbow) {
  if (is.null(elbow) || inherits(elbow, "error")) {
    return(method_recommendation("elbow", reason = if (is.null(elbow)) {
      "Elbow was not supplied."
    } else {
      conditionMessage(elbow)
    }))
  }
  method_recommendation(
    "elbow",
    preferred_k = elbow$k,
    status = if (is.na(elbow$k)) "ambiguous" else "valid",
    reason = elbow$reason,
    scores = elbow$curve,
    diagnostics = elbow[c("candidate_k", "strength", "min_strength")]
  )
}
