# invalid curves and thresholds are rejected instead of cleaned

    Code
      compute_elbow(c(2, 2, 3), c(100, 40, 20))
    Condition
      Error:
      ! `k` must contain distinct positive whole-number cluster counts.

---

    Code
      compute_elbow(c(2, NA, 4), c(100, 40, 20))
    Condition
      Error:
      ! `k` must contain distinct positive whole-number cluster counts.

---

    Code
      compute_elbow(2:4, c(100, Inf, 20))
    Condition
      Error:
      ! `wcss` must contain one finite, nonnegative value per candidate K.

---

    Code
      compute_elbow(2:4, c(100, -1, 20))
    Condition
      Error:
      ! `wcss` must contain one finite, nonnegative value per candidate K.

---

    Code
      compute_elbow(2:4, c(100, 20))
    Condition
      Error:
      ! `wcss` must contain one finite, nonnegative value per candidate K.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

---

    Code
      compute_elbow(2:4, c(100, 40, 20), threshold)
    Condition
      Error:
      ! `min_strength` must be NULL or a single finite number from 0 to 1.

