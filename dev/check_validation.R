# Re-run the validation studies into a temporary folder and check that they
# reproduce the committed results in validation/ exactly (timings aside).
#
# Run from the project root in a terminal, not in the RStudio console: the
# studies fork worker processes, which is unsafe inside the RStudio GUI.
# In RStudio use the Terminal tab, or Background Jobs with the project root
# as working directory.
#
#   Rscript dev/check_validation.R        # quick: first 5 repetitions, ~6 minutes
#   Rscript dev/check_validation.R 100    # full study, ~20 minutes
#
# Exits with status 0 when everything matches and 1 otherwise.

args <- commandArgs(trailingOnly = TRUE)
repetitions <- if (length(args) > 0L) suppressWarnings(as.integer(args[[1]])) else 5L
if (is.na(repetitions) || repetitions < 1L || repetitions > 100L) {
  stop("The optional argument must be a number of repetitions from 1 to 100.")
}
if (!file.exists("validation/run_supplied_benchmark.R")) {
  stop("Run this script from the kconsensus project root.")
}

suppressMessages(devtools::load_all(quiet = TRUE))
output_dir <- file.path(tempdir(), "kconsensus-validation")
dir.create(output_dir, showWarnings = FALSE)
all_passed <- TRUE
report <- function(label, ok, detail = "") {
  if (!isTRUE(ok)) all_passed <<- FALSE
  cat(sprintf("[%s] %s%s\n", if (isTRUE(ok)) "PASS" else "FAIL", label,
    if (nzchar(detail)) paste0("  (", detail, ")") else ""))
}
same <- function(label, new, old) {
  result <- all.equal(old, new, check.attributes = FALSE)
  report(label, isTRUE(result), if (isTRUE(result)) "" else paste(result, collapse = "; "))
}
sorted <- function(data, keys) {
  data <- data[do.call(order, unname(as.list(data[keys]))), , drop = FALSE]
  rownames(data) <- NULL
  data
}

cat(sprintf("Supplied benchmark (24 jobs), writing to %s\n", output_dir))
benchmark <- new.env(parent = globalenv())
sys.source("validation/run_supplied_benchmark.R", envir = benchmark)
started <- proc.time()[["elapsed"]]
invisible(benchmark$run_supplied_benchmark(output_dir = output_dir))
cat(sprintf("  finished in %.0f s\n", proc.time()[["elapsed"]] - started))

old_summary <- utils::read.csv("validation/supplied_benchmark_summary.csv")
new_summary <- utils::read.csv(file.path(output_dir, "supplied_benchmark_summary.csv"))
columns <- setdiff(names(old_summary), "elapsed_seconds")
same("Benchmark: every result except timing matches", new_summary[columns], old_summary[columns])
report("Benchmark: all 24 software checks pass", all(new_summary$software_checks_pass),
  sprintf("%d of %d", sum(new_summary$software_checks_pass), nrow(new_summary)))
same(
  "Benchmark: per-method results match",
  utils::read.csv(file.path(output_dir, "supplied_benchmark_methods.csv")),
  utils::read.csv("validation/supplied_benchmark_methods.csv")
)

cat(sprintf("\nStatistical behavior study, repetitions 1 to %d of 100\n", repetitions))
behavior <- new.env(parent = globalenv())
sys.source("validation/run_statistical_behavior.R", envir = behavior)
started <- proc.time()[["elapsed"]]
invisible(behavior$run_statistical_behavior(repetitions = repetitions, output_dir = output_dir))
cat(sprintf("  finished in %.0f s\n", proc.time()[["elapsed"]] - started))

keys <- c("scenario", "repetition", "k_max")
old_trials <- utils::read.csv("validation/statistical_behavior_trials.csv")
old_trials <- sorted(old_trials[old_trials$repetition <= repetitions, ], keys)
new_trials <- sorted(utils::read.csv(file.path(output_dir, "statistical_behavior_trials.csv")), keys)
columns <- setdiff(names(old_trials), "elapsed_seconds")
report("Behavior: same number of evaluations", nrow(new_trials) == nrow(old_trials),
  sprintf("%d new vs %d committed", nrow(new_trials), nrow(old_trials)))
same("Behavior: every evaluation except timing matches", new_trials[columns], old_trials[columns])
if (repetitions == 100L) {
  old_study <- utils::read.csv("validation/statistical_behavior_summary.csv")
  new_study <- utils::read.csv(file.path(output_dir, "statistical_behavior_summary.csv"))
  columns <- setdiff(names(old_study), "median_elapsed_seconds")
  same("Behavior: scenario summary matches", new_study[columns], old_study[columns])
}

cat(if (all_passed) "\nAll validation checks passed.\n" else "\nSome validation checks FAILED.\n")
quit(status = if (all_passed) 0L else 1L, save = "no")
