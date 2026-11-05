test_vote <- function(
  method, preferred_k = 3L, status = "valid", reason = "",
  eligible = status == "valid", tested_k = 2:6
) {
  method_recommendation(
    method, preferred_k, status, reason,
    scores = data.frame(k = tested_k), eligible = eligible
  )
}

test_that("the example agreement uses five eligible voting methods", {
  records <- list(
    test_vote("silhouette", 3L), test_vote("calinski_harabasz", 3L),
    test_vote("davies_bouldin", 4L), test_vote("dunn", 3L),
    test_vote("gap", 4L, tested_k = 1:6),
    test_vote("elbow", NA_integer_, "ambiguous", "No defensible knee.")
  )
  result <- compute_consensus(records)

  expect_identical(result$recommended_k, 3L)
  expect_identical(result$status, "unique_winner")
  expect_identical(result$tied_candidates, integer())
  expect_identical(result$n_valid_methods, 5L)
  expect_identical(result$agreement$votes, c(0L, 0L, 3L, 2L, 0L, 0L))
  expect_equal(result$agreement$agreement_percent, c(0, 0, 60, 40, 0, 0))
  expect_identical(result$methods$included, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(result$methods$reason[6], "No defensible knee.")
  expect_identical(result$methods$tested_min, c(2L, 2L, 2L, 2L, 1L, 2L))
})

test_that("ties return all leaders and never select the smaller K", {
  result <- compute_consensus(list(test_vote("a", 4L), test_vote("b", 3L)))

  expect_identical(result$recommended_k, NA_integer_)
  expect_identical(result$tied_candidates, c(3L, 4L))
  expect_identical(result$status, "tie")
  expect_equal(result$agreement$agreement_percent[result$agreement$votes > 0], c(50, 50))
})

test_that("an explicitly ineligible method cannot enter the denominator", {
  result <- compute_consensus(list(
    test_vote("eligible", 3L),
    test_vote("excluded", 4L, eligible = FALSE, reason = "Outside the intended scope.")
  ))

  expect_identical(result$n_valid_methods, 1L)
  expect_identical(result$recommended_k, 3L)
  expect_equal(result$agreement$agreement_percent[result$agreement$k == 3L], 100)
  expect_identical(result$methods$reason[2], "Outside the intended scope.")
})

test_that("Gap K = 1 remains eligible and is not changed to K = 2", {
  result <- compute_consensus(list(
    test_vote("gap", 1L, tested_k = 1:6),
    test_vote("other", NA_integer_, "ambiguous", "Exact tie.")
  ))

  expect_identical(result$recommended_k, 1L)
  expect_identical(result$n_valid_methods, 1L)
})

test_that("no valid votes means undefined agreement rather than zero confidence", {
  result <- compute_consensus(list(
    test_vote("ambiguous", NA_integer_, "ambiguous", "Exact tie."),
    method_recommendation("undefined", reason = "Calculation failed.")
  ))

  expect_identical(result$recommended_k, NA_integer_)
  expect_identical(result$tied_candidates, integer())
  expect_identical(result$status, "no_valid_votes")
  expect_identical(result$n_valid_methods, 0L)
  expect_identical(result$agreement$votes, rep(0L, 5))
  expect_identical(result$agreement$agreement_percent, rep(NA_real_, 5))
  empty <- compute_consensus(list(method_recommendation("failed", reason = "No scores.")))
  expect_identical(nrow(empty$agreement), 0L)
})

test_that("a unique upper-bound winner triggers an explicit warning", {
  expect_snapshot({
    compute_consensus(list(test_vote("upper_boundary", 6L)))$boundary_warning
  })
})

test_that("all supplied score curves and diagnostics survive aggregation", {
  scores <- data.frame(k = 2:6, score = c(0.1, 0.501, 0.500, 0.2, 0.05))
  record <- method_recommendation(
    "custom", 3L, "valid", scores = scores, diagnostics = list(score_gap = 0.001)
  )
  result <- compute_consensus(list(record))

  expect_identical(result$recommendations$custom$scores, scores)
  expect_identical(result$recommendations$custom$diagnostics, record$diagnostics)
})

test_that("malformed and duplicated records cannot manufacture votes", {
  expect_snapshot(error = TRUE, compute_consensus(list()))
  expect_snapshot(error = TRUE, compute_consensus(list(list(method = "incomplete"))))
  expect_snapshot(error = TRUE, compute_consensus(list(test_vote("same"), test_vote("same"))))
  record <- test_vote("tampered")
  record$preferred_k <- 100L
  expect_snapshot(error = TRUE, compute_consensus(list(record)))
})
