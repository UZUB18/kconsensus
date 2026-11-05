# Gap is separate from the internal indices and evaluates every K from 1.
# Keep clusGap's historical distance power and PCA-rotated reference space.
compute_gap <- function(
  x, k_max = 10L, B = 100L, seed = 6749L, nstart = 25L, verbose = FALSE
) {
  if (length(k_max) != 1L || !is.null(dim(k_max))) {
    stop("`k_max` must be a single candidate cluster count.", call. = FALSE)
  }
  input <- validate_input(x, k_max)
  check_simulation_count(B)
  check_nstart(nstart)
  check_flag(verbose, "verbose")
  if (
    !is.numeric(seed) || is.complex(seed) || length(seed) != 1L ||
      !is.null(dim(seed)) || is.na(seed) || !is.finite(seed) ||
      seed != floor(seed) || seed < 0 || seed > .Machine$integer.max
  ) {
    stop("`seed` must be a whole number from 0 to .Machine$integer.max.",
      call. = FALSE
    )
  }

  gap <- withr::with_seed(
    seed,
    cluster::clusGap(
      as.matrix(input$data),
      FUNcluster = function(z, k) {
        fit <- stats::kmeans(z, centers = k, nstart = nstart, iter.max = 100)
        if (!is.null(fit$ifault) && fit$ifault != 0) {
          stop(sprintf("K-means failed during Gap calculation for K = %s.", k),
            call. = FALSE
          )
        }
        fit
      },
      K.max = k_max,
      B = B,
      d.power = 1,
      spaceH0 = "scaledPCA",
      verbose = verbose
    )
  )
  if (any(!is.finite(gap$Tab))) {
    stop("Gap calculation produced undefined statistics or standard errors.",
      call. = FALSE
    )
  }

  list(
    k = as.integer(cluster::maxSE(
      gap$Tab[, "gap"],
      gap$Tab[, "SE.sim"],
      method = "firstSEmax",
      SE.factor = 1
    )),
    gap = gap,
    selection_method = "firstSEmax",
    seed = seed,
    d_power = 1L,
    preprocessing = input$preprocessing
  )
}

check_simulation_count <- function(B) {
  if (
    !is.numeric(B) || is.complex(B) || length(B) != 1L ||
      !is.null(dim(B)) || is.na(B) || !is.finite(B) ||
      B != floor(B) || B < 2 || B > .Machine$integer.max
  ) {
    stop("`B` must be a whole number from 2 to .Machine$integer.max.",
      call. = FALSE
    )
  }
  invisible(B)
}

check_flag <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be TRUE or FALSE.", name), call. = FALSE)
  }
  invisible(value)
}
