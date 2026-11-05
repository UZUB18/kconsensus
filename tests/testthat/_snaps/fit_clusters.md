# nstart sets the number of random starts

    Code
      fit_clusters(x, 2, nstart = nstart)
    Condition
      Error:
      ! `nstart` must be a single whole number of at least 1.

---

    Code
      fit_clusters(x, 2, nstart = nstart)
    Condition
      Error:
      ! `nstart` must be a single whole number of at least 1.

---

    Code
      fit_clusters(x, 2, nstart = nstart)
    Condition
      Error:
      ! `nstart` must be a single whole number of at least 1.

---

    Code
      fit_clusters(x, 2, nstart = nstart)
    Condition
      Error:
      ! `nstart` must be a single whole number of at least 1.

---

    Code
      fit_clusters(x, 2, nstart = nstart)
    Condition
      Error:
      ! `nstart` must be a single whole number of at least 1.

# invalid data and candidate counts are rejected before fitting

    Code
      fit_clusters(iris, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      fit_clusters(iris[, 1:4], c(2, 2))
    Condition
      Error:
      ! `k` must contain distinct candidate cluster counts; duplicates are not allowed.

# invalid seeds and seed overflow are rejected

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

---

    Code
      fit_clusters(iris[, 1:4], 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a single nonnegative whole number with seed + max(k) <= .Machine$integer.max.

