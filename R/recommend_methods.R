# Exact ties abstain; raw best-versus-runner-up differences stay within a method.
recommend_index <- function(method, k, values, direction) {
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
      reason = paste("Non-finite scores at K =",
        paste(k[!is.finite(values)], collapse = ", ")
      ),
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

# Adapt existing calculation results without rerunning any clustering or scoring.
recommend_methods <- function(indices, gap = NULL, elbow = NULL) {
  directions <- c(
    silhouette = "max", calinski_harabasz = "max",
    davies_bouldin = "min", dunn = "max"
  )
  if (
    !is.data.frame(indices) ||
      !all(c("k", names(directions)) %in% names(indices))
  ) {
    stop("`indices` must contain k and the four internal-index score columns.",
      call. = FALSE
    )
  }
  records <- lapply(names(directions), function(method) {
    recommend_index(method, indices$k, indices[[method]], directions[[method]])
  })

  if (is.null(gap) || inherits(gap, "error")) {
    records[[5L]] <- method_recommendation("gap", reason = if (is.null(gap)) {
      "Gap was not supplied."
    } else {
      conditionMessage(gap)
    })
  } else {
    scores <- data.frame(k = seq_len(nrow(gap$gap$Tab)), gap$gap$Tab)
    defined <- all(is.finite(as.matrix(scores[, -1L, drop = FALSE])))
    records[[5L]] <- method_recommendation(
      "gap",
      preferred_k = if (defined) gap$k else NA_integer_,
      status = if (defined) "valid" else "undefined",
      reason = if (defined) gap$selection_method else "Gap contains non-finite scores.",
      scores = scores,
      diagnostics = gap[c("selection_method", "seed", "d_power")]
    )
  }
  if (is.null(elbow) || inherits(elbow, "error")) {
    records[[6L]] <- method_recommendation("elbow", reason = if (is.null(elbow)) {
      "Elbow was not supplied."
    } else {
      conditionMessage(elbow)
    })
  } else {
    records[[6L]] <- method_recommendation(
      "elbow",
      preferred_k = elbow$k,
      status = if (is.na(elbow$k)) "ambiguous" else "valid",
      reason = elbow$reason,
      scores = elbow$curve,
      diagnostics = elbow[c("candidate_k", "strength", "min_strength")]
    )
  }
  names(records) <- vapply(records, \(record) record$method, character(1))
  records
}
