# duplicates are allowed when distinct points support the requested K

    Code
      fit_clusters(x, 5)
    Condition
      Error:
      ! Every candidate in `k` must be no greater than the number of distinct data points (4).

---

    Code
      fit_clusters(matrix(1, nrow = 6), 2)
    Condition
      Error:
      ! Every candidate in `k` must be no greater than the number of distinct data points (1).

