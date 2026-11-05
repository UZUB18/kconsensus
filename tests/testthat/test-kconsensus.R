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
  local_mocked_bindings(fit_clusters = function(x, k, seed, nstart) {
    fits <- real_fit_clusters(x, k, seed = seed, nstart = nstart)
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
  expect_error(
    kconsensus(iris[, 1:4], k = 3),
    "`k` must contain at least two candidate cluster counts to compare.",
    fixed = TRUE
  )
  expect_error(
    kconsensus(iris[, 1:4], methods = c("gap", "ch")),
    "`methods` must be distinct names from",
    fixed = TRUE
  )
  expect_error(
    kconsensus(iris[, 1:4], methods = character()),
    "`methods` must be distinct names from",
    fixed = TRUE
  )
  expect_error(
    kconsensus(iris[, 1:4], nstart = 0),
    "`nstart` must be a single whole number of at least 1.",
    fixed = TRUE
  )
  expect_error(
    kconsensus(iris[, 1:4], verbose = NA),
    "`verbose` must be TRUE or FALSE.",
    fixed = TRUE
  )
})

test_that("only the requested methods are calculated and vote", {
  x <- scale(iris[, 1:4])
  full <- kconsensus(x, k = 2:5, B = 2)
  local_mocked_bindings(compute_gap = function(...) stop("Gap should not run."))
  local_mocked_bindings(
    dist = function(...) stop("Distances should not be computed."),
    .package = "stats"
  )
  result <- kconsensus(
    x,
    k = 2:5,
    methods = c("elbow", "davies_bouldin", "calinski_harabasz")
  )

  selected <- c("calinski_harabasz", "davies_bouldin", "elbow")
  expect_named(result$recommendations, selected)
  expect_identical(result$methods$method, selected)
  expect_identical(result$settings$methods, selected)
  expect_identical(result$n_valid_methods, 2L)
  for (method in selected) {
    expect_identical(result$recommendations[[method]], full$recommendations[[method]])
  }
})

test_that("nstart sets the random starts for the fits and for Gap", {
  x <- scale(iris[, 1:4])
  result <- kconsensus(x, k = 2:4, B = 3, nstart = 3)

  expect_identical(result$fits, fit_clusters(x, 2:4, nstart = 3))
  gap <- compute_gap(x, k_max = 4, B = 3, nstart = 3)
  expect_identical(
    unname(as.matrix(result$recommendations$gap$scores[, -1L])),
    unname(gap$gap$Tab)
  )
  expect_identical(result$settings$nstart, 3)
})

test_that("verbose = TRUE reports progress and verbose = FALSE is silent", {
  x <- scale(iris[, 1:4])
  messages <- character()
  withCallingHandlers(
    kconsensus(x, k = 2:4, methods = c("silhouette", "dunn"), verbose = TRUE),
    message = function(condition) {
      messages <<- c(messages, conditionMessage(condition))
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(messages, c(
    "Fitting K-means for K = 2:4 (25 random starts each).\n",
    "Scoring the fits with Silhouette and Dunn.\n"
  ))

  gap_output <- capture_output(
    gap_messages <- capture_messages(
      kconsensus(x, k = 2:3, methods = "gap", B = 2, verbose = TRUE)
    )
  )
  expect_match(
    gap_messages[2],
    "Running the gap statistic for K = 1:3 with 2 reference datasets",
    fixed = TRUE
  )
  expect_match(gap_output, "Bootstrapping", fixed = TRUE)
  expect_silent(kconsensus(x, k = 2:4, B = 2, verbose = FALSE))
  option_messages <- withr::with_options(
    list(kconsensus.verbose = TRUE),
    capture_messages(kconsensus(x, k = 2:3, methods = "silhouette"))
  )
  expect_identical(option_messages, c(
    "Fitting K-means for K = 2, 3 (25 random starts each).\n",
    "Scoring the fits with Silhouette.\n"
  ))
})

test_that("tibbles, data frames and matrices give the same votes", {
  skip_if_not_installed("tibble")
  x <- as.data.frame(scale(iris[, 1:4]))
  from_df <- kconsensus(x, k = 2:4, B = 2)
  from_tibble <- kconsensus(tibble::as_tibble(x), k = 2:4, B = 2)
  from_matrix <- kconsensus(as.matrix(x), k = 2:4, B = 2)

  expect_identical(from_tibble$recommendations, from_df$recommendations)
  expect_equal(from_matrix$recommendations, from_df$recommendations)
  expect_identical(from_tibble$status, from_df$status)
})
