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
  expect_identical(result$status, "majority")
  expect_identical(nrow(result$flags), 0L)
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
  result <- suppressWarnings(compute_consensus(list(test_vote("upper_boundary", 6L))))
  expect_identical(result$flags$flag, "upper_boundary")
  expect_match(result$flags$message, "K = 6 is the highest K tested", fixed = TRUE)
})

test_that("support grades separate unanimous, majority and plurality winners", {
  unanimous <- compute_consensus(list(test_vote("a", 3L), test_vote("b", 3L)))
  expect_identical(unanimous$status, "unanimous")
  expect_identical(unanimous$recommended_k, 3L)

  majority <- compute_consensus(list(
    test_vote("a", 3L), test_vote("b", 3L), test_vote("c", 3L), test_vote("d", 4L)
  ))
  expect_identical(majority$status, "majority")

  # Exactly half is not a majority.
  half <- compute_consensus(list(
    test_vote("a", 3L), test_vote("b", 3L), test_vote("c", 4L), test_vote("d", 5L)
  ))
  expect_identical(half$status, "plurality")
  expect_identical(half$recommended_k, 3L)

  plurality <- compute_consensus(list(
    test_vote("a", 3L), test_vote("b", 3L), test_vote("c", 4L),
    test_vote("d", 5L), test_vote("e", 2L)
  ))
  expect_identical(plurality$status, "plurality")
  expect_identical(plurality$recommended_k, 3L)
  expect_equal(plurality$agreement$agreement_percent[plurality$agreement$k == 3L], 40)

  # Abstentions leave the denominator, so they do not weaken the grade.
  with_abstention <- compute_consensus(list(
    test_vote("a", 3L), test_vote("b", 3L),
    test_vote("c", NA_integer_, "ambiguous", "Exact tie.")
  ))
  expect_identical(with_abstention$status, "unanimous")
})

test_that("a winner at the lower edge of its voters' ranges is flagged", {
  only_floor <- compute_consensus(list(
    test_vote("silhouette", 2L), test_vote("dunn", 2L), test_vote("other", 4L)
  ))
  expect_identical(only_floor$flags$flag, "lower_boundary")
  expect_identical(
    only_floor$flags$message,
    paste(
      "K = 2 is the smallest K evaluated by Silhouette and Dunn, so none of the",
      "methods voting for it could have chosen fewer clusters."
    )
  )

  # Gap evaluated K = 1 and still chose K = 2, which answers the boundary question.
  with_gap <- compute_consensus(list(
    test_vote("silhouette", 2L), test_vote("gap", 2L, tested_k = 1:6)
  ))
  expect_identical(nrow(with_gap$flags), 0L)

  # A winner above its voters' smallest tested K is not flagged.
  not_floor <- compute_consensus(list(test_vote("a", 3L), test_vote("b", 2L), test_vote("c", 3L)))
  expect_identical(nrow(not_floor$flags), 0L)
})

test_that("a K = 1 vote against subdivisions is flagged without changing the vote", {
  result <- compute_consensus(list(
    test_vote("silhouette", 3L), test_vote("dunn", 4L),
    test_vote("gap", 1L, tested_k = 1:6)
  ))

  expect_identical(result$status, "tie")
  expect_identical(result$tied_candidates, c(1L, 3L, 4L))
  expect_identical(result$flags$flag, "single_cluster_vote")
  expect_identical(
    result$flags$message,
    paste(
      "Gap Statistic voted for K = 1 (no subdivision), while 2 other methods voted",
      "for K >= 2. Silhouette and Dunn did not evaluate K = 1, so those votes do",
      "not test it."
    )
  )

  # A lone K = 1 vote has nothing to disagree with.
  alone <- compute_consensus(list(test_vote("gap", 1L, tested_k = 1:6)))
  expect_identical(nrow(alone$flags), 0L)

  # Excluded methods neither vote nor trigger the flag.
  excluded <- compute_consensus(list(
    test_vote("silhouette", 3L),
    test_vote("gap", 1L, tested_k = 1:6, eligible = FALSE, reason = "Excluded.")
  ))
  expect_identical(nrow(excluded$flags), 0L)
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

test_that("one valid vote is reported as a single vote, not as agreement", {
  result <- compute_consensus(list(
    test_vote("gap", 2L, tested_k = 1:6),
    test_vote("silhouette", NA_integer_, "undefined", "Calculation failed.")
  ))

  expect_identical(result$status, "single_vote")
  expect_identical(result$recommended_k, 2L)
  expect_identical(result$n_valid_methods, 1L)
})
