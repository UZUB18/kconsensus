# Return the supplied inputs unchanged, with an explicit preprocessing record.
# Candidate K values must satisfy 2 <= K < n and K <= distinct rows.
validate_input <- function(x, k) {
  if (is.data.frame(x)) {
    numeric_columns <- vapply(
      x,
      \(column) is.numeric(column) && !is.complex(column) && is.null(dim(column)),
      logical(1)
    )
    valid_data <- all(numeric_columns)
  } else {
    valid_data <- is.matrix(x) && is.numeric(x) && !is.complex(x)
  }

  if (!valid_data) {
    stop(
      "`x` must be a numeric matrix or a data frame with only numeric columns.",
      call. = FALSE
    )
  }
  if (ncol(x) == 0L) {
    stop("`x` must contain at least one variable.", call. = FALSE)
  }
  if (nrow(x) < 3L) {
    stop(
      "`x` must contain at least three observations for 2 <= K < n.",
      call. = FALSE
    )
  }

  values <- as.matrix(x)
  if (anyNA(values)) {
    stop(
      paste0(
        "`x` must not contain missing values (NA or NaN).",
        if (any(is.nan(values))) {
          paste(
            " NaN often comes from scale() applied to a constant column;",
            "remove constant columns before scaling."
          )
        }
      ),
      call. = FALSE
    )
  }
  if (any(!is.finite(values))) {
    stop("`x` must not contain infinite values (Inf or -Inf).", call. = FALSE)
  }

  if (!is.numeric(k) || is.complex(k) || !is.null(dim(k)) || length(k) == 0L) {
    stop(
      "`k` must be a nonempty numeric vector of candidate cluster counts.",
      call. = FALSE
    )
  }
  if (anyNA(k) || any(!is.finite(k))) {
    stop("`k` must contain only finite values, with no NA or NaN.", call. = FALSE)
  }
  if (any(k != floor(k)) || any(k < 2)) {
    stop(
      "`k` must contain whole numbers greater than or equal to 2.",
      call. = FALSE
    )
  }
  if (anyDuplicated(k)) {
    stop(
      "`k` must contain distinct candidate cluster counts; duplicates are not allowed.",
      call. = FALSE
    )
  }
  if (any(k >= nrow(x))) {
    stop(
      sprintf(
        "Every candidate in `k` must be less than the number of observations (%s).",
        nrow(x)
      ),
      call. = FALSE
    )
  }

  n_distinct <- sum(!duplicated(values))
  if (any(k > n_distinct)) {
    stop(
      sprintf(
        paste(
          "Every candidate in `k` must be no greater than",
          "the number of distinct data points (%s)."
        ),
        n_distinct
      ),
      call. = FALSE
    )
  }

  list(
    data = x,
    k = k,
    preprocessing = list(
      data_used_as_supplied = TRUE,
      standardized_by_package = FALSE
    )
  )
}
