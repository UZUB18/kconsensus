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
