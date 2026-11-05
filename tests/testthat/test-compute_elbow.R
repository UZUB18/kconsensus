test_that("a normalized knee candidate is not automatically selected", {
  result <- compute_elbow(2:6, c(100, 40, 30, 25, 20))

  expect_identical(result$k, NA_integer_)
  expect_identical(result$candidate_k, 3L)
  expect_equal(result$strength, 0.5)
  expect_match(result$reason, "no min_strength supplied", fixed = TRUE)
  expect_identical(result$curve$wcss, c(100, 40, 30, 25, 20))
})

test_that("a user cutoff controls selection without minimizing WCSS", {
  selected <- compute_elbow(2:6, c(100, 40, 30, 25, 20), min_strength = 0.4)
  abstained <- compute_elbow(2:6, c(100, 40, 30, 25, 20), min_strength = 0.6)

  expect_identical(selected$k, 3L)
  expect_identical(abstained$k, NA_integer_)
  expect_identical(abstained$candidate_k, 3L)
  expect_match(selected$reason, "uncalibrated", fixed = TRUE)
})

test_that("straight, flat and weak curves do not force automatic choices", {
  straight <- compute_elbow(2:6, c(100, 80, 60, 40, 20), min_strength = 0)
  flat <- compute_elbow(2:6, rep(100, 5), min_strength = 0)
  weak <- compute_elbow(2:6, c(100, 79.99, 60, 40, 20))
  weak_cutoff <- compute_elbow(2:6, c(100, 79.99, 60, 40, 20), min_strength = 0.1)

  expect_identical(straight$k, NA_integer_)
  expect_identical(straight$candidate_k, NA_integer_)
  expect_equal(straight$strength, 0)
  expect_identical(flat$k, NA_integer_)
  expect_equal(flat$strength, 0)
  expect_identical(weak$k, NA_integer_)
  expect_identical(weak$candidate_k, 3L)
  expect_lt(weak$strength, 0.001)
  expect_identical(weak_cutoff$k, NA_integer_)
})

test_that("ambiguous, increasing and underspecified curves abstain", {
  tied <- compute_elbow(1:4, c(100, 50, 20, 10), min_strength = 0)
  increasing <- compute_elbow(2:5, c(100, 40, 45, 20), min_strength = 0)
  short <- compute_elbow(2:3, c(100, 20), min_strength = 0)

  expect_identical(tied$k, NA_integer_)
  expect_identical(tied$candidate_k, NA_integer_)
  expect_match(tied$reason, "Multiple candidate knees", fixed = TRUE)
  expect_identical(increasing$k, NA_integer_)
  expect_match(increasing$reason, "WCSS increases", fixed = TRUE)
  expect_identical(short$k, NA_integer_)
  expect_match(short$reason, "At least three", fixed = TRUE)
})

test_that("normalization respects scales, paired ordering and irregular K gaps", {
  k <- c(2, 3, 5, 8, 10)
  wcss <- c(100, 40, 30, 25, 20)
  result <- compute_elbow(k, wcss, min_strength = 0.4)
  transformed <- compute_elbow(5 * k + 12, 7 * wcss + 100, min_strength = 0.4)
  reordered <- compute_elbow(rev(k), rev(wcss), min_strength = 0.4)

  expect_equal(result$strength, transformed$strength)
  expect_equal(transformed$k, 5 * result$k + 12)
  expect_identical(result, reordered)
  expect_equal(result$curve$normalized_k, c(0, 0.125, 0.375, 0.75, 1))
})

test_that("elbow uses the stored WCSS even when other indices are undefined", {
  x <- matrix(c(0, 0, 1, 1, 2, 2), ncol = 1)
  fits <- fit_clusters(x, 2:3)
  wcss <- vapply(fits, \(fit) fit$tot.withinss, numeric(1))
  result <- compute_elbow(2:3, wcss)

  expect_identical(unname(result$curve$wcss), unname(wcss))
  expect_identical(result$k, NA_integer_)
})

test_that("the elbow plot retains raw K and WCSS rather than normalized axes", {
  elbow <- compute_elbow(2:6, c(100, 40, 30, 25, 20))
  plot <- plot_elbow(elbow)

  expect_s3_class(plot, "ggplot")
  expect_identical(plot$data, elbow$curve)
  expect_identical(plot$labels$caption, elbow$reason)
  expect_equal(ggplot2::ggplot_build(plot)$data[[1]]$y, elbow$curve$wcss)
})

test_that("invalid curves and thresholds are rejected instead of cleaned", {
  expect_snapshot(error = TRUE, compute_elbow(c(2, 2, 3), c(100, 40, 20)))
  expect_snapshot(error = TRUE, compute_elbow(c(2, NA, 4), c(100, 40, 20)))
  expect_snapshot(error = TRUE, compute_elbow(2:4, c(100, Inf, 20)))
  expect_snapshot(error = TRUE, compute_elbow(2:4, c(100, -1, 20)))
  expect_snapshot(error = TRUE, compute_elbow(2:4, c(100, 20)))
  for (threshold in list(-0.1, 1.1, NA_real_, Inf, c(0.1, 0.2), "0.1")) {
    expect_snapshot(error = TRUE, compute_elbow(2:4, c(100, 40, 20), threshold))
  }
})
