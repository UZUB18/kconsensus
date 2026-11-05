# Runtime test plan: kconsensus 0.1.0

## Context

You are testing the R package **kconsensus** in this RStudio session.
kconsensus helps choose the number of clusters (K) for K-means. It fits K-means
once per candidate K, lets six methods vote (silhouette, Calinski-Harabasz,
Davies-Bouldin, Dunn, gap statistic, WCSS elbow), and grades the vote as
`unanimous`, `majority`, `plurality`, `single_vote`, `tie` or `no_valid_votes`,
with descriptive flags (`upper_boundary`, `lower_boundary`,
`single_cluster_vote`). A calculation that fails part-way makes only the
affected methods abstain, with a warning.

- Project root: `/home/trbuzu/Documents/Projects/Kconsensus/kconsensus`
  (the folder containing `kconsensus.Rproj`)
- Git branch: `consensus-diagnostics`

Your job is to run the steps below in order, record what happens, and report.
You are a tester: do not fix anything.

## Rules

1. Run R code in the R console, with the working directory set to the project
   root.
2. Do not edit, create, delete, commit or push project files, and do not install
   or update packages. If a required package is missing, stop and report it.
3. Steps marked **Terminal** must run in RStudio's Terminal tab, or as an
   RStudio Background Job with the project root as working directory, not in the
   R console. They start parallel worker processes, which is unsafe inside the
   RStudio GUI.
4. If a step fails, keep its exact output, continue with the next step, and
   include everything in the report. Never change package code, tests or
   expected values to make a step pass.
5. Some steps take minutes. Long silences are normal; durations are given.

## Step 0: Environment (seconds)

```r
setwd("/home/trbuzu/Documents/Projects/Kconsensus/kconsensus")
R.version.string
for (p in c("devtools", "testthat", "cluster", "clusterCrit", "ggplot2",
            "withr", "knitr", "rmarkdown", "tibble")) {
  cat(p, as.character(packageVersion(p)), "\n")
}
rmarkdown::pandoc_available()
read.dcf("DESCRIPTION", fields = c("Version", "Authors@R"))
```

Pass if: R is 4.1 or newer (tested on 4.6.1), every package prints a version,
`pandoc_available()` is `TRUE`, Version is `0.1.0`, and Authors@R names
`UZUB18` with `trbuzu@gmail.com`.

Optional, in the **Terminal**: `git branch --show-current` (expect
`consensus-diagnostics`), `git log --oneline -1` and `git status --short`.
Files under `dev/` and `vignettes/choosing-k.Rmd` may show as new or modified
if they have not been committed yet.

## Step 1: Unit tests (about 1 minute)

```r
test_results <- as.data.frame(devtools::test(reporter = "summary"))
c(passed = sum(test_results$passed), failed = sum(test_results$failed),
  errors = sum(test_results$error), warnings = sum(test_results$warning),
  skipped = sum(test_results$skipped))
```

Pass if: passed 698, failed 0, errors 0, warnings 0, skipped 0.

## Step 2: Full package check (about 1 minute)

```r
check_result <- devtools::check(document = FALSE, error_on = "never")
check_result
```

Pass if: `0 errors | 0 warnings | 0 notes`. This also rebuilds the vignette and
runs the tests again in a separate session.

## Step 3: Runtime checks (about 2 minutes)

```r
source("dev/runtime_checks.R")
```

Pass if: the last line reads `75 of 75 checks passed.` and no line starts with
`[FAIL]`.

It covers every support level and flag on known datasets; failure handling (a
failing calculation must give a warning and abstentions, not an error); the
`methods`, `nstart`, `verbose` and `elbow_min_strength` arguments; 11 invalid
inputs and their messages; data frame, tibble and matrix input;
reproducibility and preservation of the session's random-number state;
`print()`, `summary()` and `as.data.frame()`; and drawing all three plot types
for eight different outcomes.

Report the four timing lines from section 8. They are informational: flag one
only if it is more than three times its reference.

## Step 4: Help-page examples (seconds)

```r
devtools::run_examples(run_donttest = TRUE, document = FALSE)
```

Pass if: it finishes without an error. Progress messages such as "Fitting
K-means ..." are normal in an interactive session.

## Step 5: Vignette (about 30 seconds)

```r
devtools::load_all()
vignette_html <- rmarkdown::render(
  "vignettes/choosing-k.Rmd",
  output_dir = tempdir(),
  intermediates_dir = tempdir(),
  envir = new.env(),
  quiet = TRUE
)
utils::browseURL(vignette_html)
```

Pass if: it renders without an error and the page opens. On the page, the
clear example should give unanimous support for K = 3. The uniform-noise
example should give majority support for K = 4, with the `single_cluster_vote`
flag and a silhouette margin of 0.0027 versus 0.14 for the clear example. The
page must not contain progress messages such as "Fitting K-means".

## Step 6: Hands-on walkthrough (about 1 minute)

```r
source("dev/try_kconsensus.R", echo = TRUE, max.deparse.length = 300)
```

Pass if: it runs to the end, with plots appearing in the Plots pane. Progress
messages such as "Fitting K-means ..." appear throughout; that is normal in
RStudio. The printed `Recommended K` lines should match the comments in the
file, in this order (summaries repeat the same values):

1. 3, unanimous
2. 4, majority, with the `single_cluster_vote` flag
3. 6, plurality; then none (tie between K = 2 and 4)
4. 2, single vote (only Gap Statistic voted)
5. None (tie between K = 3 and 4), after a warning that the Gap calculation
   failed. When a file is sourced, this warning may be printed later, next to
   the first error of block 7; that is normal.
6. 2, unanimous with the `lower_boundary` flag; then, after progress
   messages and one dot per Gap reference dataset, 2, majority (4 of 5 votes)

Block 7 must print four clear error messages: `NaN often comes from scale()`,
`at least two candidate cluster counts`, the list of valid method names, and
`only numeric columns`.

## Step 7: Validation re-run (Terminal; quick about 6 minutes, full about 20 minutes)

In the **Terminal** tab:

```
cd /home/trbuzu/Documents/Projects/Kconsensus/kconsensus
Rscript dev/check_validation.R
```

This re-runs the supplied benchmark (24 datasets) and the first 5 repetitions
of the simulation study into a temporary folder. It then checks that every
result except timing matches the committed results in `validation/`. Nothing in
the project is overwritten.

Pass if: every check line (the lines that start with a bracketed result)
shows `[PASS]`, none shows `[FAIL]`, and the output ends with
`All validation checks passed.` The other lines are progress headers and
timings.

For the full study, run `Rscript dev/check_validation.R 100` instead (about 20
minutes; it also compares the scenario summary).

## Step 8: Visual review (about 1 minute)

After step 6, these objects exist in the session:

```r
plot(clear)                       # one blue bar at K = 3
plot(unclear, type = "indices")   # each panel has its own y-axis
plot(failed, type = "indices")    # notes such as "Undefined at K = 4" in panel titles
plot(failed, type = "matrix")     # "NA" cells where scores are undefined
```

Pass if: each plot draws in the Plots pane and, with the pane at roughly
600 × 450 pixels or larger, no text is cut off. Titles, subtitles, panel
titles, axis labels and legends must be fully visible. Do not judge the index
curves by their shape: each panel has its own y-axis, so even tiny
differences fill the panel. On this noise the silhouette only spans 0.37 to
0.42.

## Report

Return:

1. A table with one row per step: step, PASS or FAIL, key numbers (for example
   "698 passed" or "75 of 75"), and duration.
2. For every failure, the exact output or error text, unedited.
3. The environment from step 0: R version, operating system and package
   versions.
4. The four timings from step 3.
5. Anything unexpected even if the step passed: warnings, unusually slow steps,
   odd output.
