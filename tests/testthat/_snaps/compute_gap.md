# Gap simulation settings and input data are validated

    Code
      compute_gap(iris, k_max = 3, B = 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      compute_gap(x, k_max = c(2, 3), B = 2)
    Condition
      Error:
      ! `k_max` must be a single candidate cluster count.

---

    Code
      compute_gap(x, k_max = 1, B = 2)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      compute_gap(x, k_max = 150, B = 2)
    Condition
      Error:
      ! Every candidate in `k` must be less than the number of observations (150).

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = B)
    Condition
      Error:
      ! `B` must be a whole number from 2 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

---

    Code
      compute_gap(x, k_max = 2, B = 2, seed = seed)
    Condition
      Error:
      ! `seed` must be a whole number from 0 to .Machine$integer.max.

# failed Gap fits restore the RNG state on error

    Code
      compute_gap(iris[, 1:4], k_max = 2, B = 2)
    Condition
      Error:
      ! K-means failed during Gap calculation for K = 2.

# undefined Gap statistics are rejected

    Code
      compute_gap(x, k_max = 2, B = 2)
    Condition
      Error:
      ! Gap calculation produced undefined statistics or standard errors.

