# Hands-on checks for kconsensus.
#
# Open kconsensus.Rproj in RStudio, then run this file from top to bottom,
# one block at a time (Ctrl+Enter). Each block says what you should see.
# Run the blocks in order: the random data in block 2 depends on block 1.
# In RStudio you will also see progress messages; that is expected.

devtools::load_all() # or Ctrl+Shift+L


# 1. Clear structure: three separated groups ----------------------------------
set.seed(2026)
centers <- rbind(c(-4, 0), c(0, 4), c(4, 0))
blobs <- do.call(rbind, lapply(1:3, function(i) {
  cbind(rnorm(50, centers[i, 1], 0.8), rnorm(50, centers[i, 2], 0.8))
}))
clear <- kconsensus(blobs, k = 2:8, B = 20)

clear # Recommended K: 3 (unanimous: 5 of 5 valid votes, 100%)
summary(clear) # every method votes 3; WCSS Elbow does not vote (no threshold)
plot(clear) # one blue bar at K = 3
plot(clear, type = "indices") # all curves peak at 3 (Davies-Bouldin dips)
plot(clear, type = "matrix") # one "Vote" cell per method, all at K = 3


# 2. No structure at all: uniform noise ----------------------------------------
noise <- cbind(runif(300, -5, 5), runif(300, -5, 5))
unclear <- kconsensus(noise, k = 2:8, B = 20)

unclear # majority for K = 4 (3 of 5) -- even though there are no clusters!
# The warning signs: the single_cluster_vote flag (Gap chose K = 1) and tiny
# margins. Silhouette's margin is about 0.0027 here versus 0.14 in block 1:
as.data.frame(unclear)[, c("method", "preferred_k", "margin")]
as.data.frame(clear)[, c("method", "preferred_k", "margin")]
summary(unclear)
plot(unclear, type = "indices") # separate y-axes: silhouette only spans 0.37-0.42


# 3. Weak and inconclusive votes -------------------------------------------------
uniform <- read.csv("data_test/kconsensus_benchmark/data/uniform_no_clusters.csv")
kconsensus(uniform, k = 2:10, B = 20)
# Recommended K: 6 (plurality, no majority: 2 of 5 valid votes, 40%)

kconsensus(iris[, 1:4], k = 2:4, B = 5)
# Recommended K: none (tie between K = 2 and 4); no K is picked for you


# 4. Only one method voting -------------------------------------------------------
kconsensus(scale(iris[, 1:4]), k = 2:6, methods = "gap", B = 20)
# Recommended K: 2 (single vote: only Gap Statistic voted) -- not "unanimous"


# 5. A calculation fails part-way -------------------------------------------------
# Four distinct points, so K = 4 has zero spread: Calinski-Harabasz and Dunn are
# undefined there, and Gap cannot be computed.
degenerate <- rbind(
  matrix(rep(c(0, 0), 5), ncol = 2, byrow = TRUE),
  matrix(rep(c(5, 0), 5), ncol = 2, byrow = TRUE),
  matrix(rep(c(0, 5), 5), ncol = 2, byrow = TRUE),
  c(0.1, 0)
)
failed <- kconsensus(degenerate, k = 2:4, B = 5)
# Warning: "Some calculations failed, so the affected methods abstain ... Gap: ..."
failed # Recommended K: none (tie between K = 3 and 4)
summary(failed) # "Not voting" lists each abstaining method with its reason
plot(failed, type = "matrix") # "NA" cells mark undefined scores


# 6. Faster runs for big data -----------------------------------------------------
system.time(
  quick <- kconsensus(
    scale(iris[, 1:4]),
    k = 2:10,
    methods = c("calinski_harabasz", "davies_bouldin", "elbow")
  )
) # well under a second: no Gap, no pairwise distances
quick # unanimous for K = 2, with a lower_boundary flag
kconsensus(scale(iris[, 1:4]), k = 2:10, B = 20, nstart = 5, verbose = TRUE)
# progress messages, then one dot per Gap reference dataset


# 7. Clear errors for bad input -----------------------------------------------------
with_constant <- iris[, 1:4]
with_constant$constant <- 1
try(kconsensus(scale(with_constant))) # NaN from scale(): remove constant columns
try(kconsensus(iris[, 1:4], k = 3)) # at least two candidate K are needed
try(kconsensus(iris[, 1:4], methods = "ch")) # lists the valid method names
try(kconsensus(iris)) # Species is not numeric


# 8. Getting results out ------------------------------------------------------------
as.data.frame(clear) # one row per method
head(as.data.frame(clear, what = "scores")) # every score at every K
as.data.frame(clear, what = "agreement") # the vote table
clear$fits[["3"]]$cluster # the K-means cluster labels for K = 3
ggplot2::ggsave(tempfile(fileext = ".png"), plot(clear), width = 7, height = 5)


# 9. Your own data ------------------------------------------------------------------
# my_data <- read.csv("path/to/your_file.csv")
# numeric <- my_data[, vapply(my_data, is.numeric, logical(1))]
# result <- kconsensus(scale(numeric), k = 2:10, B = 20) # B = 100 for final results
# summary(result)
# plot(result, type = "indices")


# 10. The automated checks ------------------------------------------------------------
# devtools::test()  # Ctrl+Shift+T: 698 expectations, about a minute
# devtools::check() # Ctrl+Shift+E: full R CMD check, about a minute
