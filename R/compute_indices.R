# x and distances are prepared by compute_indices(), without standardization.
# Degenerate partitions can give non-finite indices; these are returned as is
# so the affected methods abstain instead of stopping the whole analysis.
score_partition <- function(x, groups, distances) {
  if (
    !is.numeric(groups) || is.complex(groups) || !is.null(dim(groups)) ||
      length(groups) != nrow(x) || anyNA(groups) ||
      any(!is.finite(groups)) || any(groups != floor(groups)) ||
      any(groups < 1 | groups > nrow(x))
  ) {
    stop("Cluster labels must be finite positive integers, one per observation.",
      call. = FALSE
    )
  }

  groups <- as.integer(groups)
  k <- length(unique(groups))
  if (
    k < 2L || k >= nrow(x) ||
      !identical(sort(unique(groups)), seq_len(k))
  ) {
    stop("Cluster labels must cover 1 through K, with 2 <= K < n.",
      call. = FALSE
    )
  }

  indices <- clusterCrit::intCriteria(
    x,
    groups,
    c("Calinski_Harabasz", "Davies_Bouldin", "Dunn")
  )
  sil <- cluster::silhouette(groups, distances)

  c(
    silhouette = mean(sil[, "sil_width"]),
    calinski_harabasz = as.numeric(indices[["calinski_harabasz"]]),
    davies_bouldin = as.numeric(indices[["davies_bouldin"]]),
    dunn = as.numeric(indices[["dunn"]])
  )
}

# fits must come from the same x, in the same observation order.
# The shared silhouette distances require quadratic memory; no K is selected.
# A K whose fit failed or cannot be scored gets NA scores, and the reason is
# kept in attr(result, "problems") rather than stopping the other candidates.
compute_indices <- function(x, fits) {
  if (
    !is.list(fits) || is.data.frame(fits) || length(fits) == 0L ||
      is.null(names(fits)) || anyNA(names(fits)) || any(names(fits) == "")
  ) {
    stop("`fits` must be a nonempty list named by candidate K values.",
      call. = FALSE
    )
  }
  k <- suppressWarnings(as.numeric(names(fits)))
  if (anyNA(k)) {
    stop("`fits` names must be numeric candidate K values.", call. = FALSE)
  }
  input <- validate_input(x, k)
  x <- as.matrix(input$data)
  # clusterCrit requires double storage, including for integer-valued inputs.
  storage.mode(x) <- "double"

  distances <- stats::dist(x)
  if (any(!is.finite(distances))) {
    stop("Pairwise distances are non-finite; check the magnitude of `x`.",
      call. = FALSE
    )
  }

  problems <- data.frame(k = integer(), message = character())
  rows <- lapply(seq_along(fits), function(i) {
    tryCatch({
      fit <- fits[[i]]
      if (inherits(fit, "error")) {
        stop(paste("K-means failed:", conditionMessage(fit)), call. = FALSE)
      }
      if (!inherits(fit, "kmeans")) {
        stop("Expected a successful kmeans fit.", call. = FALSE)
      }
      if (
        length(fit$ifault) != 1L || !is.numeric(fit$ifault) ||
          is.na(fit$ifault) || fit$ifault != 0
      ) {
        stop(
          sprintf(
            "K-means did not converge (ifault = %s).",
            paste(fit$ifault, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      scores <- score_partition(x, fit$cluster, distances)
      if (length(unique(fit$cluster)) != k[i]) {
        stop("The partition's cluster count does not match its candidate K.",
          call. = FALSE
        )
      }
      wcss <- fit$tot.withinss
      if (
        !is.numeric(wcss) || is.complex(wcss) || length(wcss) != 1L ||
          !is.finite(wcss) || wcss < 0
      ) {
        stop("The fit must contain a finite, nonnegative tot.withinss.",
          call. = FALSE
        )
      }
      data.frame(
        k = as.integer(k[i]),
        silhouette = scores[["silhouette"]],
        calinski_harabasz = scores[["calinski_harabasz"]],
        davies_bouldin = scores[["davies_bouldin"]],
        dunn = scores[["dunn"]],
        wcss = wcss
      )
    }, error = function(error) {
      problems[nrow(problems) + 1L, ] <<- list(as.integer(k[i]), conditionMessage(error))
      data.frame(
        k = as.integer(k[i]),
        silhouette = NA_real_,
        calinski_harabasz = NA_real_,
        davies_bouldin = NA_real_,
        dunn = NA_real_,
        wcss = NA_real_
      )
    })
  })

  result <- do.call(rbind, rows)
  attr(result, "preprocessing") <- input$preprocessing
  attr(result, "problems") <- problems
  result
}
