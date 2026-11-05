test_that("rigid rotations and uniform scaling preserve internal index evidence", {
  x <- withr::with_seed(8129L, rbind(
    matrix(stats::rnorm(60, -4), ncol = 2),
    matrix(stats::rnorm(60), ncol = 2),
    matrix(stats::rnorm(60, 4), ncol = 2)
  ))
  rotation <- matrix(c(cos(0.3), sin(0.3), -sin(0.3), cos(0.3)), ncol = 2)
  original <- compute_indices(x, fit_clusters(x, 2:5))
  transformed_x <- 7 * x %*% rotation
  transformed <- compute_indices(transformed_x, fit_clusters(transformed_x, 2:5))

  for (index in c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn")) {
    expect_equal(original[[index]], transformed[[index]], tolerance = 1e-7)
  }
  expect_equal(49 * original$wcss, transformed$wcss, tolerance = 1e-7)
})

test_that("duplicates are allowed when distinct points support the requested K", {
  x <- rbind(c(0, 0), c(0, 0), c(1, 0), c(5, 5), c(5, 5), c(6, 5))
  fits <- fit_clusters(x, 2:3)
  expect_named(fits, c("2", "3"))
  expect_snapshot(error = TRUE, fit_clusters(x, 5))
  expect_snapshot(error = TRUE, fit_clusters(matrix(1, nrow = 6), 2))
})
