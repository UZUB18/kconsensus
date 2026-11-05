# Plurality for K = 4 (2 of 5 votes) with a Gap vote for K = 1; no clustering runs.
plurality_fixture <- function() {
  indices <- data.frame(
    k = 2:6,
    silhouette = c(0.30, 0.35, 0.41, 0.40, 0.33),
    calinski_harabasz = c(100, 210, 180, 190, 170),
    davies_bouldin = c(0.9, 0.8, 0.5, 0.6, 0.7),
    dunn = c(0.10, 0.20, 0.25, 0.30, 0.20)
  )
  gap <- list(
    k = 1L,
    gap = list(Tab = cbind(
      logW = c(5.0, 4.8, 4.6, 4.5, 4.4, 4.3),
      E.logW = c(5.3, 5.05, 4.85, 4.74, 4.63, 4.52),
      gap = c(0.30, 0.25, 0.25, 0.24, 0.23, 0.22),
      SE.sim = c(0.03, 0.03, 0.03, 0.03, 0.03, 0.03)
    )),
    selection_method = "firstSEmax",
    seed = 1L,
    d_power = 1L
  )
  elbow <- compute_elbow(2:6, c(90, 60, 45, 40, 37))
  result <- compute_consensus(recommend_methods(indices, gap, elbow))
  result$settings <- list(k = 2:6, seed = 1L, B = 10L, elbow_min_strength = NULL)
  result$preprocessing <- list(data_used_as_supplied = TRUE, standardized_by_package = FALSE)
  result
}

simple_vote <- function(method, preferred_k, tested_k = 2:6) {
  method_recommendation(
    method, preferred_k, "valid",
    scores = data.frame(k = tested_k, score = seq_along(tested_k))
  )
}

test_that("the fixture is a plurality with a K = 1 flag", {
  result <- plurality_fixture()

  expect_identical(result$status, "plurality")
  expect_identical(result$recommended_k, 4L)
  expect_identical(result$flags$flag, "single_cluster_vote")
})

test_that("print gives a short overview instead of the raw list", {
  result <- plurality_fixture()

  expect_snapshot(print(result))
  output <- capture.output(printed <- withVisible(print(result)))
  expect_false(printed$visible)
  expect_identical(printed$value, result)
  expect_lt(length(output), 10L)
})

test_that("summary explains support, runner-up, abstentions, flags and caveats", {
  result <- plurality_fixture()
  s <- summary(result)

  expect_s3_class(s, "summary.kconsensus_result")
  expect_identical(s$status, "plurality")
  expect_identical(s$runner_up_k, c(1L, 3L, 5L))
  expect_identical(s$votes$k, c(1L, 3L, 4L, 5L))
  expect_identical(s$n_valid_methods, 5L)
  expect_identical(s$n_methods, 6L)
  expect_match(s$verdict, "Weak preference only", fixed = TRUE)
  expect_identical(
    s$methods$runner_up,
    c("5", "5", "5", "4", NA_character_, NA_character_)
  )
  expect_snapshot(print(s))
})

test_that("summary states inconclusive outcomes without a recommended K", {
  tie <- compute_consensus(list(simple_vote("a", 3L), simple_vote("b", 4L)))
  tie_summary <- summary(tie)
  expect_identical(tie_summary$recommended_k, NA_integer_)
  expect_identical(tie_summary$runner_up_k, integer())
  expect_match(tie_summary$verdict, "Inconclusive: K = 3 and 4 are tied", fixed = TRUE)
  expect_output(print(tie), "Recommended K: none  (tie between K = 3 and 4)", fixed = TRUE)

  none <- compute_consensus(list(
    method_recommendation("a", reason = "Calculation failed.", scores = data.frame(k = 2:4))
  ))
  expect_match(summary(none)$verdict, "no method cast a valid vote", fixed = TRUE)
  expect_output(print(summary(none)), "No valid votes.", fixed = TRUE)
  expect_output(print(none), "Recommended K: none  (no valid votes)", fixed = TRUE)
})

test_that("unanimous and majority summaries use the matching wording", {
  unanimous <- compute_consensus(list(simple_vote("a", 3L), simple_vote("b", 3L)))
  expect_identical(summary(unanimous)$verdict, "All valid methods agree on K = 3.")
  expect_output(print(unanimous), "unanimous: 2 of 2 valid votes, 100%", fixed = TRUE)

  majority <- compute_consensus(list(
    simple_vote("a", 3L), simple_vote("b", 3L), simple_vote("c", 4L)
  ))
  expect_match(summary(majority)$verdict, "Most valid methods agree on K = 3", fixed = TRUE)
  expect_identical(summary(majority)$runner_up_k, 4L)
})

test_that("as.data.frame returns the methods, agreement and scores tables", {
  result <- plurality_fixture()

  methods <- as.data.frame(result)
  expect_identical(methods$method, names(result$recommendations))
  expect_identical(methods$preferred_k, c(4L, 3L, 4L, 5L, 1L, NA_integer_))
  expect_equal(methods$margin, c(0.01, 20, 0.1, 0.05, NA, NA))
  expect_identical(
    names(methods),
    c(names(result$methods), "margin")
  )

  expect_identical(as.data.frame(result, what = "agreement"), result$agreement)

  scores <- as.data.frame(result, what = "scores")
  expect_identical(nrow(scores), 4L * 5L + 6L + 5L)
  expect_identical(
    names(scores),
    c("method", "k", "criterion", "value", "se", "preferred", "vote_counted")
  )
  gap_rows <- scores[scores$method == "gap", ]
  expect_identical(gap_rows$k, 1:6)
  expect_identical(unique(gap_rows$criterion), "gap")
  expect_equal(gap_rows$se, rep(0.03, 6))
  expect_identical(gap_rows$vote_counted, c(TRUE, rep(FALSE, 5)))
  elbow_rows <- scores[scores$method == "elbow", ]
  expect_identical(unique(elbow_rows$criterion), "wcss")
  expect_false(any(elbow_rows$preferred))
  expect_identical(sum(scores$vote_counted), result$n_valid_methods)

  named <- as.data.frame(result, row.names = letters[1:6])
  expect_identical(rownames(named), letters[1:6])
})

test_that("excluded methods keep their preference but do not count as votes", {
  result <- compute_consensus(list(
    simple_vote("a", 3L),
    method_recommendation(
      "b", 4L, "valid", "Excluded by user policy.",
      scores = data.frame(k = 2:6, score = 1:5), eligible = FALSE
    )
  ))

  scores <- as.data.frame(result, what = "scores")
  b_rows <- scores[scores$method == "b", ]
  expect_identical(b_rows$preferred, b_rows$k == 4L)
  expect_false(any(b_rows$vote_counted))
  expect_output(print(summary(result)), "4 (excluded)", fixed = TRUE)
  expect_output(print(summary(result)), "b [excluded]: Excluded by user policy.", fixed = TRUE)
})

test_that("the result methods reject malformed objects", {
  expect_snapshot(error = TRUE, summary.kconsensus_result(list(a = 1)))
  expect_snapshot(error = TRUE, as.data.frame.kconsensus_result(list(a = 1)))
  expect_snapshot(error = TRUE, as.data.frame(plurality_fixture(), what = "fits"))
})
