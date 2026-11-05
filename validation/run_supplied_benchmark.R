# Keep the supplied benchmark collection unchanged; write results to validation/.
run_supplied_benchmark <- function(
  benchmark_dir = "data_test/kconsensus_benchmark",
  output_dir = "validation",
  seed = 6749L,
  B = 100L,
  workers = 2L
) {
  helpers <- new.env(parent = globalenv())
  sys.source("validation/run_statistical_behavior.R", envir = helpers)
  ari <- helpers$adjusted_rand
  manifest <- utils::read.csv(file.path(benchmark_dir, "manifest.csv"), stringsAsFactors = FALSE)
  stopifnot(all(manifest$valid_input %in% c("True", "False")))
  jobs <- manifest
  jobs$k_max <- 10L
  extended <- manifest[manifest$scenario == "many_12", , drop = FALSE]
  extended$k_max <- 15L
  jobs <- rbind(jobs, extended)

  # Read inputs in the main session before forking numerical-only workers.
  inputs <- lapply(seq_len(nrow(jobs)), function(i) {
    item <- jobs[i, ]
    x <- utils::read.csv(file.path(benchmark_dir, item$csv_path), stringsAsFactors = FALSE)
    stopifnot(nrow(x) == item$n_rows, ncol(x) == item$n_features)
    labels <- NULL
    if (!is.na(item$labels_path) && nzchar(item$labels_path)) {
      labels <- utils::read.csv(file.path(benchmark_dir, item$labels_path))
      stopifnot(
        identical(names(labels), c("row_index", "generating_group")),
        identical(labels$row_index, seq_len(nrow(x))),
        !anyNA(labels), all(labels$generating_group == -1 | labels$generating_group >= 1)
      )
    }
    list(item = item, x = x, labels = labels)
  })

  recovery <- function(result, preferred_k, truth) {
    if (is.null(truth) || is.na(preferred_k)) return(c(inliers = NA_real_, all_rows = NA_real_))
    groups <- if (preferred_k == 1L) rep(1L, length(truth)) else {
      result$fits[[as.character(preferred_k)]]$cluster
    }
    keep <- truth != -1
    c(inliers = ari(truth[keep], groups[keep]), all_rows = ari(truth, groups))
  }

  reference_checks <- function(result, x) {
    x <- as.matrix(x)
    storage.mode(x) <- "double"
    distances <- stats::dist(x)
    method_names <- c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn")
    matched <- vapply(names(result$fits), function(candidate) {
      fit <- result$fits[[candidate]]
      reference <- clusterCrit::intCriteria(x, as.integer(fit$cluster), c(
        "Calinski_Harabasz", "Davies_Bouldin", "Dunn"
      ))
      expected <- c(
        silhouette = mean(cluster::silhouette(fit$cluster, distances)[, "sil_width"]),
        calinski_harabasz = reference$calinski_harabasz,
        davies_bouldin = reference$davies_bouldin,
        dunn = reference$dunn
      )
      actual <- vapply(result$recommendations[method_names], function(record) {
        record$scores$score[match(as.integer(candidate), record$scores$k)]
      }, numeric(1))
      isTRUE(all.equal(actual, expected, tolerance = 1e-10)) &&
        identical(result$recommendations$elbow$scores$wcss[
          match(as.integer(candidate), result$recommendations$elbow$scores$k)
        ], fit$tot.withinss)
    }, logical(1))
    included <- result$methods$included
    expected_votes <- vapply(result$agreement$k, function(candidate) {
      sum(result$methods$preferred_k[included] == candidate)
    }, integer(1))
    denominator <- sum(included)
    votes_match <- identical(expected_votes, result$agreement$votes) &&
      denominator == result$n_valid_methods &&
      isTRUE(all.equal(result$agreement$agreement_percent, 100 * expected_votes / denominator))
    gap <- result$recommendations$gap$scores
    gap_match <- result$recommendations$gap$preferred_k == cluster::maxSE(
      gap$gap, gap$SE.sim, method = "firstSEmax"
    )
    for (type in c("consensus", "indices", "matrix")) {
      ggplot2::ggplot_build(graphics::plot(result, type = type))
    }
    c(reference_match = all(matched), votes_match = votes_match, gap_selection_match = gap_match)
  }

  expected_errors <- c(
    invalid_all_identical = "distinct data points",
    invalid_missing = "missing values",
    invalid_infinite = "infinite values",
    invalid_few_distinct = "distinct data points",
    invalid_nonnumeric = "only numeric columns"
  )
  run <- function(input) {
    item <- input$item
    valid <- item$valid_input == "True"
    messages <- character()
    started <- proc.time()[["elapsed"]]
    result <- tryCatch(withCallingHandlers(
      kconsensus::kconsensus(input$x, k = 2:item$k_max, seed = seed, B = B, verbose = FALSE),
      warning = function(condition) {
        messages <<- c(messages, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ), error = identity)
    error <- inherits(result, "error")
    truth <- if (is.null(input$labels)) NULL else input$labels$generating_group
    preferred <- if (error) NA_integer_ else result$recommended_k
    metrics <- if (error) c(inliers = NA_real_, all_rows = NA_real_) else recovery(result, preferred, truth)
    checks <- if (valid && !error) reference_checks(result, input$x) else rep(NA, 3)
    expected_rejection <- if (valid) NA else error && grepl(
      expected_errors[[item$scenario]], conditionMessage(result), fixed = TRUE
    )
    methods <- NULL
    if (!error && valid) {
      methods <- result$methods
      metrics_by_method <- t(vapply(methods$preferred_k, function(candidate) {
        recovery(result, candidate, truth)
      }, numeric(2)))
      methods$ari_inliers <- metrics_by_method[, "inliers"]
      methods$ari_all_rows <- metrics_by_method[, "all_rows"]
      methods$scenario <- item$scenario
      methods$k_max <- item$k_max
    }
    summary <- data.frame(
      scenario = item$scenario, k_max = item$k_max, valid_input = valid,
      n = nrow(input$x), p = ncol(input$x),
      generating_groups = item$generating_groups,
      outliers = if (is.null(truth)) NA_integer_ else sum(truth == -1),
      recommended_k = preferred,
      status = if (error) "error" else result$status,
      flags = if (error) "" else paste(result$flags$flag, collapse = ","),
      tied_candidates = if (error) "" else paste(result$tied_candidates, collapse = ","),
      agreement_percent = if (error || result$n_valid_methods == 0L) NA_real_ else max(result$agreement$agreement_percent),
      voting_methods = if (error) 0L else result$n_valid_methods,
      gap_k = if (error) NA_integer_ else result$recommendations$gap$preferred_k,
      ari_inliers = metrics[["inliers"]], ari_all_rows = metrics[["all_rows"]],
      reference_match = checks[1], votes_match = checks[2], gap_selection_match = checks[3],
      expected_rejection = expected_rejection,
      software_checks_pass = if (valid) !error && all(checks) else expected_rejection,
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      warnings = paste(unique(messages), collapse = " | "),
      error_message = if (error) conditionMessage(result) else ""
    )
    list(summary = summary, methods = methods, result = if (error) NULL else result)
  }
  results <- withr::with_preserve_seed({
    if (.Platform$OS.type == "unix" && workers > 1L) {
      parallel::mclapply(inputs, run, mc.cores = workers, mc.set.seed = FALSE)
    } else lapply(inputs, run)
  })
  if (any(vapply(results, inherits, logical(1), "try-error"))) stop("A benchmark worker failed.")
  summary <- do.call(rbind, lapply(results, `[[`, "summary"))
  methods <- do.call(rbind, lapply(results, `[[`, "methods"))
  rownames(summary) <- rownames(methods) <- NULL
  study <- list(
    settings = list(seed = seed, B = B, standardized = FALSE,
      outlier_policy = "Inlier ARI primary; all-row ARI including -1 as sensitivity",
      range_comparison = "Separate complete runs with the same base seed"),
    manifest = manifest, summary = summary, methods = methods,
    results = results, session_info = utils::sessionInfo()
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(study, file.path(output_dir, "supplied_benchmark.rds"))
  utils::write.csv(summary, file.path(output_dir, "supplied_benchmark_summary.csv"), row.names = FALSE)
  utils::write.csv(methods, file.path(output_dir, "supplied_benchmark_methods.csv"), row.names = FALSE)
  summary
}
