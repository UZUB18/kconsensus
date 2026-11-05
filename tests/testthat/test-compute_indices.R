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

test_that("failed or malformed fits give K-specific errors", {
  x <- iris[, 1:4]
  fits <- fit_clusters(x, 2)
  expect_snapshot(error = TRUE, compute_indices(x, list("2" = NULL)))
  fits[[1]]$ifault <- 2L
  expect_snapshot(error = TRUE, compute_indices(x, fits))
  fits[[1]]$ifault <- 0L
  fits[[1]]$cluster <- fits[[1]]$cluster[-1]
  expect_snapshot(error = TRUE, compute_indices(x, fits))
  fits <- fit_clusters(x, 2)
  names(fits) <- "3"
  expect_snapshot(error = TRUE, compute_indices(x, fits))
  names(fits) <- "2"
  fits[[1]]$tot.withinss <- Inf
  expect_snapshot(error = TRUE, compute_indices(x, fits))
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

test_that("degenerate partitions stop instead of returning infinite indices", {
  x <- matrix(c(0, 0, 1, 1), ncol = 1)
  fits <- fit_clusters(x, 2)
  expect_snapshot(error = TRUE, compute_indices(x, fits))
})

test_that("a singleton cluster can still have defined indices", {
  x <- matrix(c(1, 2, 10), ncol = 1)
  groups <- c(1L, 1L, 2L)
  scores <- score_partition(x, groups, stats::dist(x))
  expect_identical(all(is.finite(scores)), TRUE)
  expect_equal(scores[["silhouette"]], mean(c(8 / 9, 7 / 8, 0)))
})
