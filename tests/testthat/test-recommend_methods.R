test_that("adapters produce the example recommendations and preserve all scores", {
  indices <- data.frame(
    k = 2:6,
    silhouette = c(0.3, 0.501, 0.500, 0.4, 0.2),
    calinski_harabasz = c(10, 30, 20, 15, 12),
    davies_bouldin = c(0.9, 0.6, 0.5, 0.7, 0.8),
    dunn = c(0.1, 0.4, 0.3, 0.2, 0.15),
    wcss = c(100, 40, 30, 25, 20)
  )
  gap <- list(
    k = 4L,
    gap = list(Tab = cbind(
      logW = c(5, 4, 3, 2, 1), E.logW = c(5.1, 4.2, 3.4, 2.6, 1.5),
      gap = c(0.1, 0.2, 0.4, 0.6, 0.5), SE.sim = rep(0.05, 5)
    )),
    selection_method = "firstSEmax", seed = 6749L, d_power = 1L
  )
  elbow <- compute_elbow(indices$k, indices$wcss)
  records <- recommend_methods(indices, gap, elbow)
  result <- compute_consensus(records)

  expect_named(records, c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "gap", "elbow"))
  expect_identical(vapply(records, \(record) record$preferred_k, integer(1)), c(
    silhouette = 3L, calinski_harabasz = 3L, davies_bouldin = 4L,
    dunn = 3L, gap = 4L, elbow = NA_integer_
  ))
  expect_identical(records$elbow$status, "ambiguous")
  expect_identical(records$elbow$reason, elbow$reason)
  expect_identical(records$elbow$scores, elbow$curve)
  expect_identical(records$gap$scores[, -1L], as.data.frame(gap$gap$Tab))
  expect_identical(records$silhouette$scores$score, indices$silhouette)
  expect_equal(records$silhouette$diagnostics$score_gap, 0.001)
  expect_identical(result$recommended_k, 3L)
  expect_identical(result$n_valid_methods, 5L)
  expect_equal(result$agreement$agreement_percent[result$agreement$k == 3], 60)
  expect_equal(result$agreement$agreement_percent[result$agreement$k == 4], 40)
})

test_that("near-ties have different raw diagnostics but equal vote weights", {
  close <- recommend_index("silhouette", 2:5, c(0.2, 0.501, 0.500, 0.1), "max")
  separated <- recommend_index("silhouette", 2:5, c(0.2, 0.65, 0.31, 0.1), "max")

  expect_identical(close$preferred_k, 3L)
  expect_identical(separated$preferred_k, 3L)
  expect_equal(close$diagnostics$score_gap, 0.001)
  expect_equal(separated$diagnostics$score_gap, 0.34)
  expect_identical(close$diagnostics$runner_up_k, 4L)
  expect_identical(compute_consensus(list(close))$agreement, compute_consensus(list(separated))$agreement)
})

test_that("exact max and min ties abstain with zero raw score gap", {
  for (direction in c("max", "min")) {
    record <- recommend_index("custom", 2:4, c(0.5, 0.5, 0.5), direction)
    expect_identical(record$status, "ambiguous")
    expect_identical(record$eligible, FALSE)
    expect_identical(record$preferred_k, NA_integer_)
    expect_equal(record$diagnostics$score_gap, 0)
    expect_identical(record$diagnostics$best_k, 2:4)
  }
})

test_that("non-finite scores abstain without deleting or replacing values", {
  scores <- c(0.4, NA_real_, Inf)
  record <- recommend_index("custom", 2:4, scores, "max")

  expect_identical(record$status, "undefined")
  expect_identical(record$scores$score, scores)
  expect_match(record$reason, "3, 4", fixed = TRUE)
  expect_identical(compute_consensus(list(record))$n_valid_methods, 0L)
})

test_that("adapters accept actual Gap results and respect elbow abstention", {
  x <- as.matrix(expand.grid(a = 1:5, b = 1:5))
  fits <- fit_clusters(x, 2:3)
  indices <- compute_indices(x, fits)
  gap <- compute_gap(x, k_max = 3, B = 5, seed = 3647L)
  records <- recommend_methods(indices, gap, compute_elbow(indices$k, indices$wcss))

  expect_identical(records$gap$preferred_k, 1L)
  expect_identical(records$gap$eligible, TRUE)
  expect_identical(records$gap$scores$k, 1:3)
  expect_identical(records$elbow$eligible, FALSE)
  expect_identical(records$elbow$preferred_k, NA_integer_)
})

test_that("absent and failed optional methods are explicitly excluded", {
  indices <- data.frame(
    k = 2:4, silhouette = c(0.3, 0.5, 0.4),
    calinski_harabasz = c(10, 30, 20), davies_bouldin = c(0.8, 0.5, 0.6),
    dunn = c(0.1, 0.3, 0.2)
  )
  missing <- recommend_methods(indices)
  failed <- recommend_methods(indices, gap = simpleError("Reference simulation failed."))

  expect_identical(missing$gap$status, "undefined")
  expect_identical(missing$elbow$status, "undefined")
  expect_identical(compute_consensus(missing)$n_valid_methods, 4L)
  expect_identical(failed$gap$reason, "Reference simulation failed.")
  expect_identical(compute_consensus(failed)$n_valid_methods, 4L)
})

test_that("abstention reasons explain undefined K from failed fits", {
  indices <- data.frame(
    k = 2:4, silhouette = c(0.3, NA, 0.4),
    calinski_harabasz = c(10, NA, 20), davies_bouldin = c(0.8, NA, 0.6),
    dunn = c(0.1, NA, 0.2), wcss = c(10, NA, 5)
  )
  attr(indices, "problems") <- data.frame(
    k = 3L, message = "K-means did not converge (ifault = 4)."
  )
  records <- recommend_methods(indices)

  for (method in c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn")) {
    expect_identical(records[[method]]$status, "undefined")
    expect_identical(
      records[[method]]$reason,
      "Non-finite scores at K = 3. K = 3: K-means did not converge (ifault = 4)."
    )
  }
})
