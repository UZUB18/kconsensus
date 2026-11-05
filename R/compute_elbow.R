# Sort paired K/WCSS values, then measure their gap below the normalized chord.
# min_strength is a user policy, not a package-calibrated statistical cutoff.
compute_elbow <- function(k, wcss, min_strength = NULL) {
  if (
    !is.numeric(k) || is.complex(k) || !is.null(dim(k)) || length(k) == 0L ||
      anyNA(k) || any(!is.finite(k)) || any(k != floor(k)) ||
      any(k < 1 | k > .Machine$integer.max) || anyDuplicated(k)
  ) {
    stop("`k` must contain distinct positive whole-number cluster counts.",
      call. = FALSE
    )
  }
  if (
    !is.numeric(wcss) || is.complex(wcss) || !is.null(dim(wcss)) ||
      length(wcss) != length(k) || anyNA(wcss) ||
      any(!is.finite(wcss)) || any(wcss < 0)
  ) {
    stop("`wcss` must contain one finite, nonnegative value per candidate K.",
      call. = FALSE
    )
  }
  if (!is.null(min_strength) && (
    !is.numeric(min_strength) || is.complex(min_strength) ||
      length(min_strength) != 1L || !is.null(dim(min_strength)) ||
      is.na(min_strength) || !is.finite(min_strength) ||
      min_strength < 0 || min_strength > 1
  )) {
    stop("`min_strength` must be NULL or a single finite number from 0 to 1.",
      call. = FALSE
    )
  }

  ordering <- order(k)
  curve <- data.frame(
    k = as.integer(k[ordering]),
    wcss = wcss[ordering],
    normalized_k = NA_real_,
    normalized_wcss = NA_real_,
    deviation = NA_real_
  )
  result <- list(
    k = NA_integer_,
    candidate_k = NA_integer_,
    strength = NA_real_,
    min_strength = min_strength,
    reason = NULL,
    curve = curve
  )
  if (nrow(curve) < 3L) {
    result$reason <- "At least three candidate K values are required."
    return(result)
  }
  if (any(diff(curve$wcss) > 0)) {
    result$reason <- "WCSS increases with K; inspect the fitted solutions."
    return(result)
  }
  if (max(curve$wcss) == min(curve$wcss)) {
    result$strength <- 0
    result$reason <- "The WCSS curve is flat."
    return(result)
  }

  curve$normalized_k <- (curve$k - min(curve$k)) / diff(range(curve$k))
  curve$normalized_wcss <- (curve$wcss - min(curve$wcss)) / diff(range(curve$wcss))
  curve$deviation <- 1 - curve$normalized_k - curve$normalized_wcss
  result$curve <- curve
  interior <- seq.int(2L, nrow(curve) - 1L)
  result$strength <- max(0, max(curve$deviation[interior]))

  # Numerical equality tolerance only; this is not a meaningful-knee threshold.
  tolerance <- sqrt(.Machine$double.eps)
  if (result$strength <= tolerance) {
    result$reason <- "The curve is numerically straight or has no positive knee."
    return(result)
  }
  candidates <- interior[
    abs(curve$deviation[interior] - result$strength) <= tolerance
  ]
  if (length(candidates) != 1L) {
    result$reason <- "Multiple candidate knees have indistinguishable strength."
    return(result)
  }
  result$candidate_k <- curve$k[candidates]
  if (is.null(min_strength)) {
    result$reason <- "Automatic selection disabled: no min_strength supplied."
  } else if (result$strength < min_strength) {
    result$reason <- "Knee strength is below the user-supplied min_strength."
  } else {
    result$k <- result$candidate_k
    result$reason <- "Selected using a user-supplied, uncalibrated min_strength."
  }
  result
}

plot_elbow <- function(elbow) {
  k <- wcss <- NULL
  ggplot2::ggplot(elbow$curve, ggplot2::aes(x = k, y = wcss)) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    ggplot2::labs(
      title = "WCSS elbow curve",
      x = "Number of clusters (K)",
      y = "Total within-cluster sum of squares",
      caption = elbow$reason
    )
}
