test_that("scores agree with a small hand-calculated example", {
  x <- matrix(c(1, 2, 9, 10), ncol = 1)
  groups <- c(1L, 1L, 2L, 2L)
  scores <- score_partition(x, groups, stats::dist(x))

  expect_equal(scores, c(
    silhouette = mean(c(1 - 1 / 8.5, 1 - 1 / 7.5)),
    calinski_harabasz = 128,
    davies_bouldin = 0.125,
    dunn = 7
  ))
})

test_that("each stored partition is scored without fitting again", {
  x <- scale(iris[, 1:4])
  fits <- fit_clusters(x, c(4, 2, 3))
  original_fits <- fits
  local_mocked_bindings(fit_clusters = function(...) stop("Unexpected refit."))

  result <- compute_indices(x, fits)

  expect_named(result, c(
    "k", "silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "wcss"
  ))
  expect_identical(result$k, c(4L, 2L, 3L))
  expect_identical(fits, original_fits)
  expect_identical(attr(result, "preprocessing"), list(
    data_used_as_supplied = TRUE,
    standardized_by_package = FALSE
  ))
  distances <- stats::dist(x)
  for (i in seq_along(fits)) {
    groups <- fits[[i]]$cluster
    expected <- clusterCrit::intCriteria(
      x, groups, c("Dunn", "Davies_Bouldin", "Calinski_Harabasz")
    )
    expect_equal(result$silhouette[i], mean(
      cluster::silhouette(groups, distances)[, "sil_width"]
    ))
    expect_equal(result$calinski_harabasz[i], expected$calinski_harabasz)
    expect_equal(result$davies_bouldin[i], expected$davies_bouldin)
    expect_equal(result$dunn[i], expected$dunn)
    expect_identical(result$wcss[i], fits[[i]]$tot.withinss)
  }
})

test_that("distances are calculated once across candidates", {
  x <- iris[, 1:4]
  fits <- fit_clusters(x, 2:4)
  calls <- 0L
  original_dist <- stats::dist
  local_mocked_bindings(
    dist = function(...) {
      calls <<- calls + 1L
      original_dist(...)
    },
    .package = "stats"
  )

  compute_indices(x, fits)

  expect_identical(calls, 1L)
})

test_that("integer data frames are scored without standardization", {
  x <- data.frame(a = c(1L, 2L, 9L, 10L), b = c(2L, 4L, 18L, 20L))
  original <- x
  fits <- fit_clusters(x, 2)
  result <- compute_indices(x, fits)

  expect_identical(x, original)
  expect_equal(result$calinski_harabasz, 128)
  expect_equal(result$davies_bouldin, 0.125)
  expect_equal(result$dunn, 7)
  expect_equal(result$wcss, 5)
})

test_that("scoring preserves the caller's random-number state", {
  x <- iris[, 1:4]
  fits <- fit_clusters(x, 2:4)
  withr::local_seed(9287L)
  seed_before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)

  compute_indices(x, fits)

  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    seed_before
  )
})

test_that("invalid fit containers and candidate names are rejected", {
  x <- iris[, 1:4]
  expect_snapshot(error = TRUE, compute_indices(x, list()))
  expect_snapshot(error = TRUE, compute_indices(x, list(NULL)))
  expect_snapshot(error = TRUE, compute_indices(x, list(bad = NULL)))
  expect_snapshot(error = TRUE, compute_indices(x, list("2" = NULL, "2" = NULL)))
})

test_that("failed or malformed fits leave only that K undefined", {
  x <- iris[, 1:4]
  fits <- fit_clusters(x, 2:3)
  expect_undefined_k2 <- function(fits, message) {
    result <- compute_indices(x, fits)
    expect_identical(result$k, c(2L, 3L))
    expect_true(all(is.na(unlist(result[1L, -1L]))))
    expect_true(all(is.finite(unlist(result[2L, -1L]))))
    expect_identical(attr(result, "problems")$k, 2L)
    expect_identical(attr(result, "problems")$message, message)
  }

  broken <- fits
  broken["2"] <- list(NULL)
  expect_undefined_k2(broken, "Expected a successful kmeans fit.")

  broken <- fits
  broken[["2"]] <- simpleError("empty cluster: try a better set of initial centers")
  expect_undefined_k2(
    broken,
    "K-means failed: empty cluster: try a better set of initial centers"
  )

  broken <- fits
  broken[["2"]]$ifault <- 4L
  expect_undefined_k2(broken, "K-means did not converge (ifault = 4).")

  broken <- fits
  broken[["2"]]$cluster <- broken[["2"]]$cluster[-1]
  expect_undefined_k2(
    broken,
    "Cluster labels must be finite positive integers, one per observation."
  )

  broken <- fits
  broken[["2"]]$tot.withinss <- Inf
  expect_undefined_k2(broken, "The fit must contain a finite, nonnegative tot.withinss.")

  mismatched <- fit_clusters(x, c(2, 4))
  names(mismatched) <- c("2", "3")
  result <- compute_indices(x, mismatched)
  expect_identical(attr(result, "problems")$k, 3L)
  expect_identical(
    attr(result, "problems")$message,
    "The partition's cluster count does not match its candidate K."
  )

  expect_identical(nrow(attr(compute_indices(x, fits), "problems")), 0L)
})

test_that("invalid partitions are rejected before native index calculations", {
  x <- matrix(c(1, 2, 9, 10), ncol = 1)
  distances <- stats::dist(x)
  for (groups in list(
    c(1, 1, NA, 2), c(1, 1, Inf, 2), c(1, 1, 2.5, 2),
    c(0, 0, 1, 1), c(1, 1, 3, 3), rep(1L, 4), 1:4,
    c("1", "1", "2", "2")
  )) {
    expect_snapshot(error = TRUE, score_partition(x, groups, distances))
  }
})

test_that("degenerate partitions return non-finite indices for the voting layer", {
  x <- matrix(c(0, 0, 1, 1), ncol = 1)
  result <- compute_indices(x, fit_clusters(x, 2))

  expect_identical(nrow(attr(result, "problems")), 0L)
  expect_false(is.finite(result$calinski_harabasz))
  expect_false(is.finite(result$dunn))
  records <- recommend_methods(result)
  expect_identical(records$calinski_harabasz$status, "undefined")
  expect_identical(records$calinski_harabasz$reason, "Non-finite scores at K = 2.")
  expect_identical(records$silhouette$status, "valid")
})

test_that("a singleton cluster can still have defined indices", {
  x <- matrix(c(1, 2, 10), ncol = 1)
  groups <- c(1L, 1L, 2L)
  scores <- score_partition(x, groups, stats::dist(x))
  expect_identical(all(is.finite(scores)), TRUE)
  expect_equal(scores[["silhouette"]], mean(c(8 / 9, 7 / 8, 0)))
})
