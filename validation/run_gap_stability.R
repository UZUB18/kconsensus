# Re-run the official Gap wrapper on fixed inputs, changing only seed and B.
gap_stability_batch <- function(
  B,
  seeds = withr::with_seed(8053L, sample.int(10000L, 5L)),
  workers = 4L,
  benchmark_dir = "data_test/kconsensus_benchmark"
) {
  scenarios <- c("uniform_no_clusters", "single_gaussian")
  paths <- file.path(benchmark_dir, "data", paste0(scenarios, ".csv"))
  inputs <- lapply(paths, function(path) {
    x <- utils::read.csv(path)
    kconsensus:::validate_input(x, 10L)
    as.matrix(x)
  })
  names(inputs) <- scenarios
  jobs <- expand.grid(scenario = scenarios, seed = seeds, stringsAsFactors = FALSE)
  run <- function(i) {
    scenario <- jobs$scenario[i]
    seed <- jobs$seed[i]
    messages <- character()
    started <- proc.time()[["elapsed"]]
    gap <- tryCatch(withCallingHandlers(
      kconsensus:::compute_gap(inputs[[scenario]], k_max = 10L, B = B, seed = seed),
      warning = function(condition) {
        messages <<- c(messages, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ), error = identity)
    failed <- inherits(gap, "error")
    curve <- if (failed) NULL else gap$gap$Tab
    select <- function(rule) {
      if (failed) return(NA_integer_)
      as.integer(cluster::maxSE(curve[, "gap"], curve[, "SE.sim"], method = rule))
    }
    summary <- data.frame(
      scenario = scenario, seed = seed, B = B,
      selected_k = if (failed) NA_integer_ else gap$k,
      firstmax_k = select("firstmax"),
      tibs2001_k = select("Tibs2001SEmax"),
      global_se_k = select("globalSEmax"),
      global_max_k = select("globalmax"),
      gap_k1 = if (failed) NA_real_ else curve[1, "gap"],
      gap_k2 = if (failed) NA_real_ else curve[2, "gap"],
      se_k1 = if (failed) NA_real_ else curve[1, "SE.sim"],
      se_k2 = if (failed) NA_real_ else curve[2, "SE.sim"],
      mcse_reference_mean_k1 = if (failed) NA_real_ else curve[1, "SE.sim"] / sqrt(B + 1),
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      warnings = paste(unique(messages), collapse = " | "),
      error = if (failed) conditionMessage(gap) else ""
    )
    if (!failed) stopifnot(summary$selected_k == select("firstSEmax"))
    list(summary = summary, curve = curve)
  }
  runs <- withr::with_preserve_seed({
    if (.Platform$OS.type == "unix" && workers > 1L) {
      parallel::mclapply(seq_len(nrow(jobs)), run, mc.cores = workers, mc.set.seed = FALSE)
    } else lapply(seq_len(nrow(jobs)), run)
  })
  if (any(vapply(runs, inherits, logical(1), "try-error"))) stop("A Gap stability worker failed.")
  list(
    settings = list(
      B = B, seeds = seeds, k_max = 10L, nstart = 25L, iter_max = 100L,
      d_power = 1L, spaceH0 = "scaledPCA", selection_method = "firstSEmax",
      input_md5 = tools::md5sum(paths),
      implementation_md5 = tools::md5sum("R/compute_gap.R")
    ),
    runs = runs,
    summary = do.call(rbind, lapply(runs, `[[`, "summary"))
  )
}

save_gap_stability <- function(batches, output_dir = "validation") {
  stopifnot(length(batches) > 0L)
  for (batch in batches) {
    stopifnot(
      identical(batch$settings$seeds, batches[[1]]$settings$seeds),
      identical(batch$settings$input_md5, batches[[1]]$settings$input_md5),
      identical(batch$settings$implementation_md5, batches[[1]]$settings$implementation_md5)
    )
  }
  runs <- unlist(lapply(batches, `[[`, "runs"), recursive = FALSE)
  trials <- do.call(rbind, lapply(runs, `[[`, "summary"))
  rownames(trials) <- NULL
  for (scenario in unique(trials$scenario)) {
    for (seed in unique(trials$seed)) {
      matching <- Filter(function(run) {
        run$summary$scenario == scenario && run$summary$seed == seed && !is.null(run$curve)
      }, runs)
      if (length(matching) > 1L) {
        # Compare observed dispersions; this does not inspect partition labels.
        stopifnot(all(vapply(matching, function(run) {
          identical(run$curve[, "logW"], matching[[1]]$curve[, "logW"])
        }, logical(1))))
      }
    }
  }
  summary <- do.call(rbind, lapply(split(trials, interaction(trials$scenario, trials$B, drop = TRUE)), function(rows) {
    data.frame(
      scenario = rows$scenario[1], B = rows$B[1], attempted = nrow(rows),
      completed = sum(!nzchar(rows$error)),
      selected_k1 = sum(rows$selected_k == 1L, na.rm = TRUE),
      selected_k_values = paste(sort(unique(rows$selected_k[!is.na(rows$selected_k)])), collapse = ","),
      global_max_k_values = paste(sort(unique(rows$global_max_k[!is.na(rows$global_max_k)])), collapse = ","),
      gap_k1_sd_across_seeds = stats::sd(rows$gap_k1, na.rm = TRUE),
      mean_se_k1 = mean(rows$se_k1, na.rm = TRUE),
      mean_mcse_reference_mean_k1 = mean(rows$mcse_reference_mean_k1, na.rm = TRUE)
    )
  }))
  rownames(summary) <- NULL
  study <- list(
    settings = lapply(batches, `[[`, "settings"),
    summary = summary, trials = trials, runs = runs,
    observed_logW_identical_across_B = TRUE,
    session_info = utils::sessionInfo()
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(study, file.path(output_dir, "gap_stability.rds"))
  utils::write.csv(trials, file.path(output_dir, "gap_stability_trials.csv"), row.names = FALSE)
  utils::write.csv(summary, file.path(output_dir, "gap_stability_summary.csv"), row.names = FALSE)
  summary
}
