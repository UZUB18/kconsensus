# One standardized record; the consensus engine never interprets score columns.
method_recommendation <- function(
  method,
  preferred_k = NA_integer_,
  status = "undefined",
  reason = "",
  scores = data.frame(k = integer()),
  diagnostics = list(),
  eligible = status == "valid"
) {
  if (
    !is.character(method) || length(method) != 1L ||
      is.na(method) || !nzchar(trimws(method))
  ) {
    stop("`method` must be a single nonempty name.", call. = FALSE)
  }
  if (
    !is.character(status) || length(status) != 1L || is.na(status) ||
      !status %in% c("valid", "ambiguous", "undefined")
  ) {
    stop("`status` must be valid, ambiguous, or undefined.", call. = FALSE)
  }
  if (!is.logical(eligible) || length(eligible) != 1L || is.na(eligible)) {
    stop("`eligible` must be a single TRUE or FALSE.", call. = FALSE)
  }
  if (
    !is.character(reason) || length(reason) != 1L || is.na(reason) ||
      ((!eligible || status != "valid") && !nzchar(trimws(reason)))
  ) {
    stop("Supply a text `reason` for every abstention or exclusion.", call. = FALSE)
  }
  if (
    !is.data.frame(scores) || sum(names(scores) == "k") != 1L ||
      !is.numeric(scores$k) || is.complex(scores$k) ||
      !is.null(dim(scores$k)) || anyNA(scores$k) ||
      any(!is.finite(scores$k)) || any(scores$k != floor(scores$k)) ||
      any(scores$k < 1 | scores$k > .Machine$integer.max) || anyDuplicated(scores$k)
  ) {
    stop("`scores` must be a data frame with distinct positive whole-number `k` values.",
      call. = FALSE
    )
  }
  if (
    length(preferred_k) != 1L || !is.null(dim(preferred_k)) ||
      is.complex(preferred_k) ||
      (!is.numeric(preferred_k) && !identical(preferred_k, NA)) ||
      (!is.na(preferred_k) && (
        !is.finite(preferred_k) || preferred_k != floor(preferred_k) ||
          preferred_k < 1 || preferred_k > .Machine$integer.max
      ))
  ) {
    stop("`preferred_k` must be NA or a single positive whole number.", call. = FALSE)
  }
  if (
    (status == "valid" && (is.na(preferred_k) || !preferred_k %in% scores$k)) ||
      (status != "valid" && (!is.na(preferred_k) || eligible))
  ) {
    stop("Valid methods need a tested preferred K; abstaining methods cannot vote.",
      call. = FALSE
    )
  }
  if (!is.list(diagnostics)) {
    stop("`diagnostics` must be a list.", call. = FALSE)
  }

  list(
    method = method,
    preferred_k = as.integer(preferred_k),
    status = status,
    eligible = eligible,
    reason = reason,
    scores = scores,
    diagnostics = diagnostics
  )
}
