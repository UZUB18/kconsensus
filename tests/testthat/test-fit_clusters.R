test_that("one named fit is returned per candidate with the specified settings", {
  x <- scale(iris[, 1:4])
  k <- 2:10
  fits <- fit_clusters(x, k, seed = 8157L)

  expect_length(fits, length(k))
  expect_named(fits, as.character(k))
  for (kk in k) {
    fit <- fits[[as.character(kk)]]
    expected <- withr::with_seed(
      8157L + kk,
      stats::kmeans(x, centers = kk, nstart = 25, iter.max = 100)
    )
    expect_s3_class(fit, "kmeans")
    expect_identical(fit, expected)
    expect_length(fit$cluster, nrow(x))
    expect_length(unique(fit$cluster), kk)
  }
})

test_that("fits are reproducible regardless of candidate order or subset", {
  x <- iris[, 1:4]
  fits <- fit_clusters(x, c(4, 2, 3))

  expect_named(fits, c("4", "2", "3"))
  expect_identical(fits, fit_clusters(x, c(4, 2, 3)))
  expect_identical(fits[c("2", "3", "4")], fit_clusters(x, 2:4))
  expect_identical(fits["3"], fit_clusters(x, 3))
  expect_identical(fits, fit_clusters(as.matrix(x), c(4, 2, 3)))
})

test_that("the supplied data are not changed or automatically standardized", {
  x <- iris[, 1:4]
  original <- x
  fits <- fit_clusters(x, 2)

  expect_identical(x, original)
  expect_equal(fits[["2"]]$totss, sum(scale(as.matrix(x), scale = FALSE)^2))
})

test_that("the caller's random seed and RNG kind are preserved", {
  withr::local_seed(3917L)
  seed_before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  kind_before <- RNGkind()

  fit_clusters(iris[, 1:4], 2:4)

  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    seed_before
  )
  expect_identical(RNGkind(), kind_before)
})

test_that("no random seed is left behind if the caller had none", {
  withr::local_preserve_seed()
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(list = ".Random.seed", envir = globalenv())
  }

  fit_clusters(iris[, 1:4], 2:4)

  expect_identical(
    exists(".Random.seed", envir = globalenv(), inherits = FALSE),
    FALSE
  )
})

test_that("a K-means error at one K is kept and the other K still fit", {
  real_kmeans <- stats::kmeans
  local_mocked_bindings(
    kmeans = function(x, centers, ...) {
      if (centers == 3) stop("empty cluster: try a better set of initial centers")
      real_kmeans(x, centers, ...)
    },
    .package = "stats"
  )
  fits <- fit_clusters(iris[, 1:4], 2:4)

  expect_named(fits, c("2", "3", "4"))
  expect_s3_class(fits[["2"]], "kmeans")
  expect_s3_class(fits[["3"]], "error")
  expect_identical(
    conditionMessage(fits[["3"]]),
    "empty cluster: try a better set of initial centers"
  )
  expect_s3_class(fits[["4"]], "kmeans")
})

test_that("invalid data and candidate counts are rejected before fitting", {
  expect_snapshot(error = TRUE, fit_clusters(iris, 2))
  expect_snapshot(error = TRUE, fit_clusters(iris[, 1:4], c(2, 2)))
})

test_that("invalid seeds and seed overflow are rejected", {
  for (seed in list(
    NULL, numeric(), c(1, 2), "1", TRUE, 1 + 0i, matrix(1),
    NA_real_, NaN, Inf, -1, 1.5, .Machine$integer.max - 1
  )) {
    expect_snapshot(error = TRUE, fit_clusters(iris[, 1:4], 2, seed = seed))
  }
})
