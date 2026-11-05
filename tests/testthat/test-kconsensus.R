test_that("the public interface matches the existing calculation pipeline", {
  x <- scale(iris[, 1:4])
  result <- kconsensus(x, k = 2:5, B = 3, seed = 5167L)
  fits <- fit_clusters(x, 2:5, seed = 5167L)
  indices <- compute_indices(x, fits)
  expected <- compute_consensus(recommend_methods(
    indices,
    compute_gap(x, k_max = 5, B = 3, seed = 5167L),
    compute_elbow(indices$k, indices$wcss)
  ))

  expect_s3_class(result, "kconsensus_result")
  expect_identical(result$agreement, expected$agreement)
  expect_identical(result$recommendations, expected$recommendations)
  expect_identical(result$fits, fits)
  expect_identical(result$preprocessing$standardized_by_package, FALSE)
  for (type in c("consensus", "indices", "matrix")) {
    expect_s3_class(plot(result, type = type), "ggplot")
  }
})

test_that("the public interface preserves RNG state and reproducibility", {
  withr::local_seed(9163L)
  before <- get(".Random.seed", envir = globalenv())
  first <- kconsensus(iris[, 1:4], k = 2:4, B = 2)
  second <- kconsensus(iris[, 1:4], k = 2:4, B = 2)

  expect_identical(first, second)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("undefined indices make only the affected methods abstain", {
  # Four distinct points, so K = 4 has zero within-cluster spread.
  x <- rbind(
    matrix(rep(c(0, 0), 5), ncol = 2, byrow = TRUE),
    matrix(rep(c(5, 0), 5), ncol = 2, byrow = TRUE),
    matrix(rep(c(0, 5), 5), ncol = 2, byrow = TRUE),
    c(0.1, 0)
  )
  expect_warning(
    result <- kconsensus(x, k = 2:4, B = 5),
    "Gap: Gap calculation produced undefined statistics",
    fixed = TRUE
  )

  methods <- result$methods
  rownames(methods) <- methods$method
  expect_identical(methods["calinski_harabasz", "status"], "undefined")
  expect_identical(methods["calinski_harabasz", "reason"], "Non-finite scores at K = 4.")
  expect_identical(methods["dunn", "status"], "undefined")
  expect_identical(methods["gap", "status"], "undefined")
  expect_identical(methods[c("silhouette", "davies_bouldin"), "status"], c("valid", "valid"))
  expect_identical(result$n_valid_methods, 2L)
})

test_that("a Gap failure makes Gap abstain with a warning instead of stopping", {
  local_mocked_bindings(
    compute_gap = function(...) stop("Reference simulation failed.", call. = FALSE)
  )
  expect_warning(
    result <- kconsensus(scale(iris[, 1:4]), k = 2:4, B = 2),
    "* Gap: Reference simulation failed.",
    fixed = TRUE
  )

  expect_identical(result$recommendations$gap$status, "undefined")
  expect_identical(result$recommendations$gap$reason, "Reference simulation failed.")
  expect_identical(result$n_valid_methods, 4L)
})

test_that("a K-means failure at one K is reported and does not stop the run", {
  real_fit_clusters <- fit_clusters
  local_mocked_bindings(fit_clusters = function(x, k, seed) {
    fits <- real_fit_clusters(x, k, seed = seed)
    fits[["3"]] <- simpleError("empty cluster: try a better set of initial centers")
    fits
  })
  expect_warning(
    result <- kconsensus(scale(iris[, 1:4]), k = 2:4, B = 2),
    "* K = 3: K-means failed: empty cluster",
    fixed = TRUE
  )

  for (method in c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn")) {
    expect_identical(result$recommendations[[method]]$status, "undefined")
    expect_match(
      result$recommendations[[method]]$reason,
      "K = 3: K-means failed: empty cluster",
      fixed = TRUE
    )
  }
  expect_identical(result$recommendations$elbow$reason, "WCSS is undefined at K = 3.")
  expect_identical(result$recommendations$gap$status, "valid")
  expect_identical(result$n_valid_methods, 1L)
  expect_s3_class(result$fits[["3"]], "error")
})

test_that("invalid arguments still stop before any fitting", {
  local_mocked_bindings(fit_clusters = function(...) stop("Fitting should not start."))
  expect_error(
    kconsensus(iris[, 1:4], B = 1),
    "`B` must be a whole number from 2 to .Machine$integer.max.",
    fixed = TRUE
  )
  expect_error(
    kconsensus(iris[, 1:4], elbow_min_strength = 2),
    "`min_strength` must be NULL or a single finite number from 0 to 1.",
    fixed = TRUE
  )
})
