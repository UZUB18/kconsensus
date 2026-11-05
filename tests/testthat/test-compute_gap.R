test_that("Gap matches the seeded reference calculation and firstSEmax", {
  x <- scale(iris[, 1:4])
  original <- x
  result <- compute_gap(x, k_max = 3, B = 5, seed = 3647L)
  expected <- withr::with_seed(3647L, cluster::clusGap(
    x,
    FUNcluster = function(z, k) {
      stats::kmeans(z, centers = k, nstart = 25, iter.max = 100)
    },
    K.max = 3,
    B = 5,
    d.power = 1,
    spaceH0 = "scaledPCA",
    verbose = FALSE
  ))

  expect_s3_class(result$gap, "clusGap")
  expect_identical(result$gap$Tab, expected$Tab)
  expect_identical(result$k, as.integer(cluster::maxSE(
    expected$Tab[, "gap"], expected$Tab[, "SE.sim"], method = "firstSEmax"
  )))
  expect_identical(result$selection_method, "firstSEmax")
  expect_identical(result$d_power, 1L)
  expect_identical(result$gap$spaceH0, "scaledPCA")
  expect_identical(x, original)
  expect_identical(result$preprocessing, list(
    data_used_as_supplied = TRUE,
    standardized_by_package = FALSE
  ))
})

test_that("Gap can report K = 1 without changing the internal candidate range", {
  x <- as.matrix(expand.grid(a = 1:5, b = 1:5))
  result <- compute_gap(x, k_max = 3, B = 5, seed = 3647L)

  expect_identical(result$k, 1L)
  expect_identical(nrow(result$gap$Tab), 3L)
  expect_identical(validate_input(x, 2:3)$k, 2:3)
})

test_that("Gap preserves an existing RNG state and is reproducible", {
  withr::local_seed(8831L)
  seed_before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  x <- iris[, 1:4]
  result <- compute_gap(x, k_max = 3, B = 3)

  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    seed_before
  )
  expect_identical(result$gap$Tab, compute_gap(x, k_max = 3, B = 3)$gap$Tab)
})

test_that("Gap leaves no RNG state when the caller had none", {
  withr::local_preserve_seed()
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(list = ".Random.seed", envir = globalenv())
  }

  compute_gap(iris[, 1:4], k_max = 2, B = 2)

  expect_identical(
    exists(".Random.seed", envir = globalenv(), inherits = FALSE), FALSE
  )
})

test_that("Gap simulation settings and input data are validated", {
  x <- iris[, 1:4]
  expect_snapshot(error = TRUE, compute_gap(iris, k_max = 3, B = 2))
  expect_snapshot(error = TRUE, compute_gap(x, k_max = c(2, 3), B = 2))
  expect_snapshot(error = TRUE, compute_gap(x, k_max = 1, B = 2))
  expect_snapshot(error = TRUE, compute_gap(x, k_max = 150, B = 2))
  for (B in list(NULL, 1, 2.5, NA_real_, Inf, "2")) {
    expect_snapshot(error = TRUE, compute_gap(x, k_max = 2, B = B))
  }
  for (seed in list(NULL, -1, 1.5, NA_real_, Inf, "1")) {
    expect_snapshot(error = TRUE, compute_gap(x, k_max = 2, B = 2, seed = seed))
  }
})

test_that("failed Gap fits restore the RNG state on error", {
  withr::local_seed(8831L)
  seed_before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  local_mocked_bindings(kmeans = function(...) list(ifault = 2L), .package = "stats")

  expect_snapshot(error = TRUE, compute_gap(iris[, 1:4], k_max = 2, B = 2))

  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    seed_before
  )
})

test_that("undefined Gap statistics are rejected", {
  x <- matrix(c(0, 0, 1, 1), ncol = 1)
  expect_snapshot(error = TRUE, compute_gap(x, k_max = 2, B = 2))
})
