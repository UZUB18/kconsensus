# Find the best number of clusters (K) for your own data with kconsensus.
#
# Get your own editable copy of this script with:
#   file.copy(system.file("scripts", "find_k_for_my_data.R", package = "kconsensus"), "find_k.R")
#   file.edit("find_k.R")
#
# How to use:
#   1. Check the SETTINGS below. Leave data_file empty to pick the file in a
#      dialog, and list any ID or date columns in exclude_columns.
#   2. Click "Source" at the top right of this editor (or press Ctrl+Shift+S).
#   3. Read the ANSWER at the end of the Console. Plots, a summary and your
#      data with a cluster column are saved in a folder next to your data
#      file, named after it (for example "patients_kconsensus").

# ---- SETTINGS ---------------------------------------------------------------
data_file <- ""          # path to a .csv or .xlsx file; "" opens a file dialog
exclude_columns <- c()   # columns that are not measurements, e.g. c("patient_id", "year")
candidate_k <- 2:10      # the numbers of clusters to compare
standardize <- TRUE      # TRUE when columns use different units (usually right)
gap_simulations <- 100   # 100 for final results; 20 for a quick first look
# ------------------------------------------------------------------------------

library(kconsensus)

if (!nzchar(data_file)) {
  data_file <- file.choose()
}

# Excel files need readxl. CSV files separated by semicolons with decimal
# commas (as Dutch Excel saves them) are detected automatically.
read_data <- function(path) {
  if (grepl("\\.xlsx?$", path, ignore.case = TRUE)) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("To read Excel files, run install.packages(\"readxl\") or save the sheet as CSV.")
    }
    return(as.data.frame(readxl::read_excel(path)))
  }
  first_line <- readLines(path, n = 1L, warn = FALSE)
  count <- function(character) {
    lengths(regmatches(first_line, gregexpr(character, first_line, fixed = TRUE)))
  }
  if (count(";") > count(",")) {
    utils::read.csv2(path, check.names = FALSE)
  } else {
    utils::read.csv(path, check.names = FALSE)
  }
}
my_data <- read_data(data_file)
cat(sprintf("Read %d rows and %d columns from %s\n", nrow(my_data), ncol(my_data), basename(data_file)))

# Keep the numeric measurement columns, complete rows and non-constant columns.
unknown <- setdiff(exclude_columns, names(my_data))
if (length(unknown) > 0L) {
  stop("These exclude_columns are not in the file: ", paste(unknown, collapse = ", "),
    "\nThe file's columns are: ", paste(names(my_data), collapse = ", "))
}
x <- my_data[, setdiff(names(my_data), exclude_columns), drop = FALSE]
is_number <- vapply(x, is.numeric, logical(1))
if (any(!is_number)) {
  cat("Skipping non-numeric columns:", paste(names(x)[!is_number], collapse = ", "), "\n")
}
x <- x[, is_number, drop = FALSE]
complete <- stats::complete.cases(x)
if (any(!complete)) {
  cat(sprintf("Skipping %d rows with missing values.\n", sum(!complete)))
}
x <- x[complete, , drop = FALSE]
constant <- vapply(x, function(column) length(unique(column)) < 2L, logical(1))
if (any(constant)) {
  cat("Skipping constant columns:", paste(names(x)[constant], collapse = ", "), "\n")
}
x <- x[, !constant, drop = FALSE]
if (ncol(x) == 0L) {
  stop("No usable numeric columns are left.")
}
cat(sprintf("Clustering %d rows on %d columns: %s\n\n", nrow(x), ncol(x), paste(names(x), collapse = ", ")))

# Choose K.
result <- kconsensus(
  if (standardize) scale(x) else x,
  k = candidate_k,
  B = gap_simulations
)
print(result)
print(summary(result))

# Save the plots, the summary and the cluster labels next to the data file.
output_dir <- file.path(
  dirname(data_file),
  paste0(tools::file_path_sans_ext(basename(data_file)), "_kconsensus")
)
dir.create(output_dir, showWarnings = FALSE)
unlink(file.path(output_dir, "clusters.csv")) # never leave labels from an earlier run
for (type in c("consensus", "indices", "matrix")) {
  ggplot2::ggsave(
    file.path(output_dir, paste0(type, ".png")),
    plot(result, type = type),
    width = 9, height = 6.5, dpi = 150
  )
}
writeLines(utils::capture.output(print(summary(result))), file.path(output_dir, "summary.txt"))
best_k <- result$recommended_k
if (!is.na(best_k) && best_k >= 2L) {
  with_clusters <- my_data[complete, , drop = FALSE]
  with_clusters$cluster <- result$fits[[as.character(best_k)]]$cluster
  utils::write.csv(with_clusters, file.path(output_dir, "clusters.csv"), row.names = FALSE)
}

# Show the plots: use the arrows in the Plots pane to page through them.
print(plot(result, type = "matrix"))
print(plot(result, type = "indices"))
print(plot(result))

# The answer in plain words.
cat("\n==================== ANSWER ====================\n")
if (is.na(best_k)) {
  if (result$status == "tie") {
    cat(sprintf("No clear answer: the methods are tied between K = %s.\n",
      paste(result$tied_candidates, collapse = " and ")))
  } else {
    cat("No clear answer: no method could vote. See summary.txt for the reasons.\n")
  }
  cat("Your data may not contain clear clusters. Try a different candidate_k.\n")
} else if (best_k == 1L) {
  cat("Best supported K is 1: the data may not split into clusters at all.\n")
} else if (result$status %in% c("unanimous", "majority") && nrow(result$flags) == 0L) {
  cat(sprintf("Use K = %d (%s support from the methods).\n", best_k, result$status))
  cat("Each row's cluster is in clusters.csv.\n")
} else {
  cat(sprintf("K = %d is only weakly supported (%s%s).\n", best_k,
    gsub("_", " ", result$status),
    if (nrow(result$flags) > 0L) paste0("; flags: ", paste(result$flags$flag, collapse = ", ")) else ""))
  cat("Read summary.txt and the plots before using it; the clusters are in clusters.csv.\n")
}
cat("Saved in:", output_dir, "\n")
