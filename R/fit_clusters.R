# Return one named kmeans fit per K for reuse across internal indices.
# Each K has its own seed, independent of candidate order or caller RNG state.
# A K-means error at one K is stored as its condition so other K still run.
fit_clusters <- function(x, k, seed = 6749L) {
  input <- validate_input(x, k)

  if (
    !is.numeric(seed) || is.complex(seed) || length(seed) != 1L ||
      !is.null(dim(seed)) || is.na(seed) || !is.finite(seed) ||
      seed != floor(seed) || seed < 0 ||
      seed > .Machine$integer.max - max(input$k)
  ) {
    stop(
      "`seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.",
      call. = FALSE
    )
  }

  fits <- lapply(input$k, function(kk) {
    tryCatch(
      withr::with_seed(
        seed + kk,
        stats::kmeans(
          input$data,
          centers = kk,
          nstart = 25,
          iter.max = 100
        )
      ),
      error = function(error) error
    )
  })

  names(fits) <- as.character(input$k)
  fits
}
