# Self-checking runtime tests for kconsensus.
#
# Run from the project root (open kconsensus.Rproj in RStudio):
#   source("dev/runtime_checks.R")
# Every check prints [PASS] or [FAIL]; a summary and the failed checks are
# printed at the end, and the results stay in `runtime_results`.
# Takes about two minutes, most of it in the timing section (section 8).
# Expected values were verified on R 4.6.1 with this version of the package.

devtools::load_all(quiet = TRUE)
old_options <- options(kconsensus.verbose = FALSE)

runtime_results <- data.frame(id = character(), passed = logical(), detail = character())
check <- function(id, ok, detail = "") {
  ok <- isTRUE(ok)
  runtime_results[nrow(runtime_results) + 1L, ] <<- list(id, ok, detail)
  cat(sprintf("[%s] %s%s\n", if (ok) "PASS" else "FAIL", id,
    if (nzchar(detail)) paste0("  (", detail, ")") else ""))
  invisible(ok)
}
with_warnings <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(expr, warning = function(condition) {
    warnings <<- c(warnings, conditionMessage(condition))
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = warnings)
}
with_messages <- function(expr) {
  messages <- character()
  withCallingHandlers(expr, message = function(condition) {
    messages <<- c(messages, conditionMessage(condition))
    invokeRestart("muffleMessage")
  })
  messages
}
error_text <- function(expr) {
  tryCatch({
    expr
    NA_character_
  }, error = conditionMessage)
}
expect_error_text <- function(id, expr, pattern) {
  message <- error_text(expr)
  check(id, !is.na(message) && grepl(pattern, message, fixed = TRUE),
    if (is.na(message)) "no error was raised" else message)
}
section <- function(title) cat("\n==", title, "==\n")


# 1. Data -----------------------------------------------------------------------
set.seed(2026)
centers <- rbind(c(-4, 0), c(0, 4), c(4, 0))
blobs <- do.call(rbind, lapply(1:3, function(i) {
  cbind(rnorm(50, centers[i, 1], 0.8), rnorm(50, centers[i, 2], 0.8))
}))
noise <- cbind(runif(300, -5, 5), runif(300, -5, 5))
set.seed(1)
noise_readme <- cbind(runif(300, -5, 5), runif(300, -5, 5))
uniform <- utils::read.csv("data_test/kconsensus_benchmark/data/uniform_no_clusters.csv")
iris_scaled <- scale(iris[, 1:4])
degenerate <- rbind(
  matrix(rep(c(0, 0), 5), ncol = 2, byrow = TRUE),
  matrix(rep(c(5, 0), 5), ncol = 2, byrow = TRUE),
  matrix(rep(c(0, 5), 5), ncol = 2, byrow = TRUE),
  c(0.1, 0)
)


# 2. Every support level and flag -------------------------------------------------
section("2. Support levels and flags")
clear <- kconsensus(blobs, k = 2:8, B = 20)
check("S1 clear groups: unanimous K = 3, 5 votes, no flags",
  clear$status == "unanimous" && identical(clear$recommended_k, 3L) &&
    clear$n_valid_methods == 5L && nrow(clear$flags) == 0L)
check("S1 elbow abstains without a threshold",
  clear$recommendations$elbow$status == "ambiguous")

unclear <- kconsensus(noise, k = 2:8, B = 20)
check("S2 uniform noise: majority K = 4 with 3 of 5 votes",
  unclear$status == "majority" && identical(unclear$recommended_k, 4L) &&
    max(unclear$agreement$votes) == 3L)
check("S2 noise carries the single_cluster_vote flag",
  identical(unclear$flags$flag, "single_cluster_vote"))
margin_noise <- as.data.frame(unclear)$margin[1]
margin_clear <- as.data.frame(clear)$margin[1]
check("S2 silhouette margin is far smaller on noise",
  margin_noise < 0.01 && margin_clear > 0.1,
  sprintf("noise %.4f vs clear %.4f", margin_noise, margin_clear))

weak <- kconsensus(uniform, k = 2:10, B = 20)
check("S3 uniform benchmark file: plurality K = 6 at 40%",
  weak$status == "plurality" && identical(weak$recommended_k, 6L) &&
    max(weak$agreement$agreement_percent) == 40)
check("S3 single_cluster_vote flag", "single_cluster_vote" %in% weak$flags$flag)

tie <- kconsensus(iris[, 1:4], k = 2:4, B = 5)
check("S4 unscaled iris: tie between K = 2 and 4, no recommendation",
  tie$status == "tie" && is.na(tie$recommended_k) &&
    identical(tie$tied_candidates, c(2L, 4L)))

single <- kconsensus(iris_scaled, k = 2:6, methods = "gap", B = 20)
check("S5 Gap only: single_vote for K = 2",
  single$status == "single_vote" && identical(single$recommended_k, 2L))

none <- kconsensus(iris_scaled, k = 2:6, methods = "elbow")
check("S6 elbow only without threshold: no_valid_votes",
  none$status == "no_valid_votes" && is.na(none$recommended_k))
elbow_vote <- kconsensus(iris_scaled, k = 2:10, methods = "elbow", elbow_min_strength = 0)
check("S6 elbow with threshold 0 votes: single_vote for K = 5",
  elbow_vote$status == "single_vote" && identical(elbow_vote$recommended_k, 5L))
elbow_strict <- kconsensus(iris_scaled, k = 2:10, methods = "elbow", elbow_min_strength = 0.5)
check("S6 elbow with threshold 0.5 abstains (knee strength is about 0.38)",
  elbow_strict$status == "no_valid_votes" &&
    elbow_strict$recommendations$elbow$reason ==
      "Knee strength is below the user-supplied min_strength.")

failed <- with_warnings(kconsensus(degenerate, k = 2:4, B = 5))
check("S7 failed calculations return a result instead of an error",
  inherits(failed$value, "kconsensus_result"))
check("S7 the warning lists the Gap failure",
  any(grepl("Gap: Gap calculation produced undefined statistics", failed$warnings, fixed = TRUE)))
failed_methods <- failed$value$methods
undefined <- failed_methods[failed_methods$method %in% c("calinski_harabasz", "dunn"), ]
check("S7 Calinski-Harabasz and Dunn abstain with their reason",
  all(undefined$status == "undefined") &&
    all(undefined$reason == "Non-finite scores at K = 4."))
check("S7 the remaining votes tie between K = 3 and 4",
  failed$value$status == "tie" && identical(failed$value$tied_candidates, c(3L, 4L)))

upper <- with_warnings(kconsensus(noise_readme, k = 2:8))
check("S8 README noise example: plurality K = 8",
  upper$value$status == "plurality" && identical(upper$value$recommended_k, 8L))
check("S8 flags upper_boundary and single_cluster_vote",
  identical(upper$value$flags$flag, c("upper_boundary", "single_cluster_vote")))
check("S8 boundary warning",
  any(grepl("Consensus winner K = 8 is the highest tested K", upper$warnings, fixed = TRUE)))

quick <- kconsensus(
  iris_scaled,
  k = 2:10,
  methods = c("elbow", "davies_bouldin", "calinski_harabasz")
)
check("S9 a method subset is returned in canonical order, without Gap",
  identical(quick$methods$method, c("calinski_harabasz", "davies_bouldin", "elbow")) &&
    !"gap" %in% names(quick$recommendations))
check("S9 unanimous K = 2 (2 of 2) with the lower_boundary flag",
  quick$status == "unanimous" && identical(quick$recommended_k, 2L) &&
    quick$n_valid_methods == 2L && identical(quick$flags$flag, "lower_boundary"))

readme <- kconsensus(iris_scaled, k = 2:10)
check("S10 README iris example: unanimous K = 2, 5 votes, no flags",
  readme$status == "unanimous" && identical(readme$recommended_k, 2L) &&
    readme$n_valid_methods == 5L && nrow(readme$flags) == 0L)


# 3. Arguments ----------------------------------------------------------------------
section("3. Arguments")
starts <- kconsensus(iris_scaled, k = 2:4, B = 3, nstart = 3)
check("A1 nstart reaches the K-means fits",
  identical(starts$fits, fit_clusters(iris_scaled, 2:4, nstart = 3)) &&
    starts$settings$nstart == 3)
progress <- with_messages(
  kconsensus(iris_scaled, k = 2:4, methods = c("silhouette", "dunn"), verbose = TRUE)
)
check("A2 verbose = TRUE reports progress", identical(progress, c(
  "Fitting K-means for K = 2:4 (25 random starts each).\n",
  "Scoring the fits with Silhouette and Dunn.\n"
)))
check("A3 verbose = FALSE is silent",
  length(with_messages(kconsensus(iris_scaled, k = 2:4, B = 2, verbose = FALSE))) == 0L)


# 4. Invalid input fails fast with a clear message ----------------------------------
section("4. Invalid input")
with_constant <- iris[, 1:4]
with_constant$constant <- 1
with_missing <- iris_scaled
with_missing[3, 2] <- NA
expect_error_text("E1 constant column after scale()",
  kconsensus(scale(with_constant)), "NaN often comes from scale()")
expect_error_text("E2 a single candidate K",
  kconsensus(iris_scaled, k = 3), "at least two candidate cluster counts")
expect_error_text("E3 unknown method name",
  kconsensus(iris_scaled, methods = "ch"), "`methods` must be distinct names from")
expect_error_text("E4 non-numeric column",
  kconsensus(iris), "only numeric columns")
expect_error_text("E5 missing value",
  kconsensus(with_missing), "missing values (NA or NaN)")
expect_error_text("E6 B below 2",
  kconsensus(iris_scaled, B = 1), "`B` must be a whole number from 2")
expect_error_text("E7 nstart of 0",
  kconsensus(iris_scaled, nstart = 0), "`nstart` must be a single whole number of at least 1")
expect_error_text("E8 verbose = NA",
  kconsensus(iris_scaled, verbose = NA), "`verbose` must be TRUE or FALSE")
expect_error_text("E9 elbow threshold above 1",
  kconsensus(iris_scaled, elbow_min_strength = 2), "`min_strength` must be NULL")
expect_error_text("E10 candidate K not below the number of rows",
  kconsensus(iris_scaled[1:8, ]), "less than the number of observations (8)")
expect_error_text("E11 infinite value",
  kconsensus(rbind(iris_scaled, Inf)), "infinite values")
fail_fast <- system.time(error_text(kconsensus(iris_scaled, B = 1)))[["elapsed"]]
check("E12 argument errors stop before any fitting", fail_fast < 0.5,
  sprintf("%.3f s", fail_fast))


# 5. Input types and reproducibility --------------------------------------------------
section("5. Input types and reproducibility")
as_frame <- as.data.frame(iris_scaled)
from_frame <- kconsensus(as_frame, k = 2:4, B = 2)
from_tibble <- kconsensus(tibble::as_tibble(as_frame), k = 2:4, B = 2)
from_matrix <- kconsensus(iris_scaled, k = 2:4, B = 2)
check("D1 data frame, tibble and matrix give the same votes",
  identical(from_frame$recommendations, from_tibble$recommendations) &&
    isTRUE(all.equal(from_frame$recommendations, from_matrix$recommendations)))
set.seed(99)
seed_before <- .Random.seed
first <- kconsensus(iris_scaled, k = 2:5, B = 5)
second <- kconsensus(iris_scaled, k = 2:5, B = 5)
check("R1 the same call gives identical results", identical(first, second))
check("R2 the session's random-number state is untouched",
  identical(.Random.seed, seed_before))
reordered <- kconsensus(iris_scaled, k = c(5, 2, 4, 3), B = 5)
check("R3 the order of candidate K does not matter",
  identical(reordered$agreement, first$agreement) &&
    identical(reordered$recommended_k, first$recommended_k) &&
    identical(reordered$fits[as.character(2:5)], first$fits))


# 6. Output methods ----------------------------------------------------------------------
section("6. print, summary and as.data.frame")
printed_lines <- utils::capture.output(printed <- withVisible(print(clear)))
check("O1 print is short and returns the result invisibly",
  length(printed_lines) <= 6L && !printed$visible && identical(printed$value, clear))
unclear_summary <- summary(unclear)
check("O2 summary reports support and runner-up",
  inherits(unclear_summary, "summary.kconsensus_result") &&
    unclear_summary$status == "majority" &&
    identical(unclear_summary$runner_up_k, c(1L, 8L)))
summary_text <- utils::capture.output(print(unclear_summary))
check("O3 printed summary shows support, flags and the caveat",
  any(grepl("Support:", summary_text, fixed = TRUE)) &&
    any(grepl("Flags", summary_text, fixed = TRUE)) &&
    any(grepl("not statistical", summary_text, fixed = TRUE)))
check("O4 methods table", identical(names(as.data.frame(clear)), c(names(clear$methods), "margin")))
scores <- as.data.frame(clear, what = "scores")
check("O5 scores table with one counted vote per valid method",
  identical(names(scores), c("method", "k", "criterion", "value", "se", "preferred", "vote_counted")) &&
    sum(scores$vote_counted) == clear$n_valid_methods)
check("O6 agreement table", identical(as.data.frame(clear, what = "agreement"), clear$agreement))


# 7. Plots draw for every outcome ------------------------------------------------------
section("7. Plots")
outcomes <- list(
  unanimous = clear, majority = unclear, plurality = weak, tie = tie,
  single_vote = single, no_valid_votes = none, failure = failed$value,
  upper_boundary = upper$value
)
for (name in names(outcomes)) {
  for (type in c("consensus", "indices", "matrix")) {
    plot_warnings <- character()
    file <- tempfile(fileext = ".png")
    drawn <- tryCatch({
      withCallingHandlers(
        ggplot2::ggsave(file, plot(outcomes[[name]], type = type), width = 8, height = 6, dpi = 72),
        warning = function(condition) {
          plot_warnings <<- c(plot_warnings, conditionMessage(condition))
          invokeRestart("muffleWarning")
        }
      )
      file.exists(file) && file.size(file) > 0
    }, error = function(error) {
      plot_warnings <<- c(plot_warnings, conditionMessage(error))
      FALSE
    })
    check(sprintf("P %s / %s draws without warnings", name, type),
      drawn && length(plot_warnings) == 0L, paste(plot_warnings, collapse = "; "))
  }
}
check("P subtitle states a plurality has no majority",
  grepl("Plurality, no majority: K = 6", plot(weak)$labels$subtitle, fixed = TRUE))
check("P subtitle states a single vote",
  grepl("Single vote: K = 2 (only Gap Statistic voted)", plot(single)$labels$subtitle, fixed = TRUE))


# 8. Timing ---------------------------------------------------------------------------
section("8. Timing (reference: R 4.6.1, 12-core Linux machine)")
elapsed <- function(expr) system.time(expr)[["elapsed"]]
set.seed(7)
profile <- sample(1:3, 3000, TRUE)
profile_means <- rbind(c(2, 2, 2, 4, 4), c(4, 4, 4, 2, 2), c(3, 3, 3, 3, 3))
survey <- t(sapply(profile, function(p) {
  pmin(5, pmax(1, round(rnorm(5, profile_means[p, ], 0.9))))
}))
time_iris <- elapsed(kconsensus(iris_scaled, k = 2:10))
time_cheap <- elapsed(kconsensus(survey, k = 2:10,
  methods = c("calinski_harabasz", "davies_bouldin", "elbow")))
time_no_gap <- elapsed(kconsensus(survey, k = 2:10,
  methods = c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "elbow")))
time_gap <- elapsed(kconsensus(survey, k = 2:10, B = 10))
cat(sprintf("iris, all methods, B = 100:          %6.1f s (reference about 4 s)\n", time_iris))
cat(sprintf("3000 rows, CH + DB + elbow:          %6.1f s (reference about 3 s)\n", time_cheap))
cat(sprintf("3000 rows, all methods except Gap:   %6.1f s (reference about 3.5 s)\n", time_no_gap))
cat(sprintf("3000 rows, all methods, B = 10:      %6.1f s (reference about 35 s)\n", time_gap))
check("T1 leaving out Gap is at least 5 times faster on 3000 rows",
  time_no_gap * 5 < time_gap, sprintf("%.1f s vs %.1f s", time_no_gap, time_gap))
check("T2 the iris example stays interactive (under 30 s)", time_iris < 30,
  sprintf("%.1f s", time_iris))


# Summary ----------------------------------------------------------------------------
options(old_options)
cat(sprintf("\n%d of %d checks passed.\n", sum(runtime_results$passed), nrow(runtime_results)))
if (any(!runtime_results$passed)) {
  cat("Failed checks:\n")
  print(runtime_results[!runtime_results$passed, ], row.names = FALSE)
}
