# Long-running Monte Carlo validation, intentionally separate from package tests.
generate_behavior_data <- function(scenario, seed) {
  withr::with_seed(seed, {
    sizes <- if (scenario == "small_group") c(55L, 60L, 5L) else rep(40L, 3)
    truth <- rep(seq_along(sizes), sizes)
    x <- matrix(stats::rnorm(2 * sum(sizes)), ncol = 2)
    if (scenario == "uniform") {
      x <- matrix(stats::runif(240, -5, 5), ncol = 2)
      truth <- NULL
    } else if (scenario == "elongated") {
      x[, 1] <- 4 * x[, 1]
      x[, 2] <- 0.35 * x[, 2] + c(-3, 0, 3)[truth]
    } else if (scenario == "small_group") {
      x[truth == 3, ] <- 0.35 * x[truth == 3, ]
      x[, 1] <- x[, 1] + c(-3, 3, 0)[truth]
    } else {
      separation <- if (scenario == "overlapping") 1.2 else 5
      noise <- if (scenario == "overlapping") 1 else 0.65
      x <- noise * x
      x[, 1] <- x[, 1] + c(-separation, 0, separation)[truth]
      if (scenario == "high_dimensional") {
        x <- cbind(x, matrix(stats::rnorm(nrow(x) * 48), ncol = 48))
      }
    }
    stopifnot(nrow(x) == 120L, !anyNA(x), all(is.finite(x)), !anyDuplicated(x))
    list(x = x, truth = truth)
  })
}

adjusted_rand <- function(truth, groups) {
  pairs <- function(n) n * (n - 1) / 2
  counts <- table(truth, groups)
  observed <- sum(pairs(counts))
  rows <- sum(pairs(rowSums(counts)))
  columns <- sum(pairs(colSums(counts)))
  expected <- rows * columns / pairs(sum(counts))
  denominator <- (rows + columns) / 2 - expected
  if (denominator == 0) return(as.numeric(observed == expected))
  (observed - expected) / denominator
}

run_behavior_case <- function(scenario, repetition) {
  data_seed <- 4861L + repetition
  fit_seed <- 6749L + repetition
  gap_seed <- 7919L + repetition
  data <- generate_behavior_data(scenario, data_seed)
  k_max <- if (scenario == "overlapping") 15L else 6L
  warnings <- character()
  started <- proc.time()[["elapsed"]]
  tryCatch(withCallingHandlers({
    fits <- kconsensus:::fit_clusters(data$x, 2:k_max, seed = fit_seed)
    indices <- kconsensus:::compute_indices(data$x, fits)
    gap <- tryCatch(
      kconsensus:::compute_gap(data$x, k_max = k_max, B = 100L, seed = gap_seed),
      error = identity
    )
    maxima <- if (scenario == "overlapping") c(6L, 15L) else 6L
    lapply(maxima, function(maximum) {
      selected_indices <- indices[indices$k <= maximum, , drop = FALSE]
      selected_gap <- gap
      if (!inherits(gap, "error")) {
        # Shared simulations isolate range sensitivity from Monte Carlo noise.
        selected_gap$gap$Tab <- gap$gap$Tab[seq_len(maximum), , drop = FALSE]
        selected_gap$k <- as.integer(cluster::maxSE(
          selected_gap$gap$Tab[, "gap"], selected_gap$gap$Tab[, "SE.sim"],
          method = "firstSEmax"
        ))
      }
      elbow <- kconsensus:::compute_elbow(selected_indices$k, selected_indices$wcss)
      records <- kconsensus:::recommend_methods(selected_indices, selected_gap, elbow)
      result <- kconsensus:::compute_consensus(records)
      preferred <- result$recommended_k
      groups <- if (is.na(preferred)) NULL else if (preferred == 1L) {
        rep(1L, nrow(data$x))
      } else fits[[as.character(preferred)]]$cluster
      ari <- if (is.null(groups) || is.null(data$truth)) NA_real_ else adjusted_rand(data$truth, groups)
      small_f1 <- NA_real_
      if (scenario == "small_group" && !is.null(groups)) {
        counts <- table(data$truth, groups)
        small_f1 <- max(2 * counts["3", ] / (sum(data$truth == 3) + colSums(counts)))
      }
      silhouette_row <- match(preferred, selected_indices$k)
      summary <- data.frame(
        scenario = scenario, repetition = repetition, k_max = maximum,
        reference_k_max = k_max, n = nrow(data$x), p = ncol(data$x),
        recommended_k = preferred, status = result$status,
        selection = if (!is.na(preferred)) as.character(preferred) else paste(result$status, paste(result$tied_candidates, collapse = ",")),
        n_valid_methods = result$n_valid_methods,
        max_agreement = if (result$n_valid_methods > 0) max(result$agreement$agreement_percent) else NA_real_,
        disagreement = length(unique(result$methods$preferred_k[result$methods$included])) > 1L,
        gap_k = if (inherits(selected_gap, "error")) NA_integer_ else selected_gap$k,
        selected_silhouette = selected_indices$silhouette[silhouette_row],
        adjusted_rand = ari, small_group_f1 = small_f1,
        elapsed_seconds = proc.time()[["elapsed"]] - started,
        warnings = paste(unique(warnings), collapse = " | "), error = ""
      )
      list(summary = summary, result = result)
    })
  }, warning = function(condition) {
    warnings <<- c(warnings, conditionMessage(condition))
    invokeRestart("muffleWarning")
  }), error = function(condition) {
    maxima <- if (scenario == "overlapping") c(6L, 15L) else 6L
    lapply(maxima, function(maximum) list(summary = data.frame(
      scenario = scenario, repetition = repetition, k_max = maximum,
      reference_k_max = k_max, n = nrow(data$x), p = ncol(data$x),
      recommended_k = NA_integer_, status = "error", selection = "error",
      n_valid_methods = 0L, max_agreement = NA_real_, disagreement = NA,
      gap_k = NA_integer_, selected_silhouette = NA_real_, adjusted_rand = NA_real_,
      small_group_f1 = NA_real_, elapsed_seconds = proc.time()[["elapsed"]] - started,
      warnings = paste(unique(warnings), collapse = " | "), error = conditionMessage(condition)
    ), result = NULL))
  })
}

run_statistical_behavior <- function(repetitions = 100L, workers = 4L, output_dir = "validation") {
  scenarios <- c("separated", "overlapping", "uniform", "small_group", "elongated", "high_dimensional")
  jobs <- expand.grid(scenario = scenarios, repetition = seq_len(repetitions), stringsAsFactors = FALSE)
  run <- function(i) run_behavior_case(jobs$scenario[i], jobs$repetition[i])
  batches <- withr::with_preserve_seed({
    if (.Platform$OS.type == "unix" && workers > 1L) {
      parallel::mclapply(seq_len(nrow(jobs)), run, mc.cores = workers, mc.set.seed = FALSE)
    } else lapply(seq_len(nrow(jobs)), run)
  })
  if (any(vapply(batches, inherits, logical(1), "try-error"))) stop("A simulation worker failed.")
  results <- unlist(batches, recursive = FALSE)
  trials <- do.call(rbind, lapply(results, `[[`, "summary"))
  rownames(trials) <- NULL
  median_finite <- function(x) if (any(is.finite(x))) stats::median(x[is.finite(x)]) else NA_real_
  summaries <- lapply(split(trials, interaction(trials$scenario, trials$k_max, drop = TRUE)), function(rows) {
    null <- rows$scenario[1] == "uniform"
    success <- sum(rows$recommended_k == 3L, na.rm = TRUE)
    n <- nrow(rows)
    z <- stats::qnorm(0.975)
    p <- success / n
    center <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
    radius <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
    data.frame(
      scenario = rows$scenario[1], k_max = rows$k_max[1], repetitions = n,
      errors = sum(rows$status == "error"),
      recovered_k3 = if (null) NA_integer_ else success,
      recovery_percent = if (null) NA_real_ else 100 * p,
      recovery_lower = if (null) NA_real_ else 100 * (center - radius),
      recovery_upper = if (null) NA_real_ else 100 * (center + radius),
      disagreement_percent = 100 * mean(rows$disagreement, na.rm = TRUE),
      unanimous_percent = 100 * mean(rows$max_agreement == 100, na.rm = TRUE),
      gap_k1_percent = 100 * mean(rows$gap_k == 1L, na.rm = TRUE),
      ties = sum(rows$status == "tie"),
      median_adjusted_rand = median_finite(rows$adjusted_rand),
      median_small_group_f1 = median_finite(rows$small_group_f1),
      median_selected_silhouette = median_finite(rows$selected_silhouette),
      median_elapsed_seconds = median_finite(rows$elapsed_seconds)
    )
  })
  summary <- do.call(rbind, summaries)
  rownames(summary) <- NULL
  short <- trials[trials$scenario == "overlapping" & trials$k_max == 6L, ]
  long <- trials[trials$scenario == "overlapping" & trials$k_max == 15L, ]
  sensitivity <- data.frame(
    repetitions = nrow(short),
    changed_recommendations = sum(short$selection != long$selection)
  )
  study <- list(
    settings = list(repetitions = repetitions, B = 100L, n = 120L, high_dimensional_p = 50L,
      data_seed = 4861L, fit_seed = 6749L, gap_seed = 7919L,
      elbow_min_strength = NULL, range_comparison = "Paired fits and reference simulations"),
    summary = summary, range_sensitivity = sensitivity, trials = trials,
    results = results, session_info = utils::sessionInfo()
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(study, file.path(output_dir, "statistical_behavior.rds"))
  utils::write.csv(summary, file.path(output_dir, "statistical_behavior_summary.csv"), row.names = FALSE)
  utils::write.csv(trials, file.path(output_dir, "statistical_behavior_trials.csv"), row.names = FALSE)
  study$summary
}
