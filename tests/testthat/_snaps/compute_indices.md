# invalid fit containers and candidate names are rejected

    Code
      compute_indices(x, list())
    Condition
      Error:
      ! `fits` must be a nonempty list named by candidate K values.

---

    Code
      compute_indices(x, list(NULL))
    Condition
      Error:
      ! `fits` must be a nonempty list named by candidate K values.

---

    Code
      compute_indices(x, list(bad = NULL))
    Condition
      Error:
      ! `fits` names must be numeric candidate K values.

---

    Code
      compute_indices(x, list(`2` = NULL, `2` = NULL))
    Condition
      Error:
      ! `k` must contain distinct candidate cluster counts; duplicates are not allowed.

# failed or malformed fits give K-specific errors

    Code
      compute_indices(x, list(`2` = NULL))
    Condition
      Error:
      ! Cannot score K = 2: Expected a successful kmeans fit.

---

    Code
      compute_indices(x, fits)
    Condition
      Error:
      ! Cannot score K = 2: K-means did not report successful convergence (ifault = 0).

---

    Code
      compute_indices(x, fits)
    Condition
      Error:
      ! Cannot score K = 2: Cluster labels must be finite positive integers, one per observation.

---

    Code
      compute_indices(x, fits)
    Condition
      Error:
      ! Cannot score K = 3: The partition's cluster count does not match its candidate K.

---

    Code
      compute_indices(x, fits)
    Condition
      Error:
      ! Cannot score K = 2: The fit must contain a finite, nonnegative tot.withinss.

# invalid partitions are rejected before native index calculations

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must be finite positive integers, one per observation.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must be finite positive integers, one per observation.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must be finite positive integers, one per observation.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must be finite positive integers, one per observation.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must cover 1 through K, with 2 <= K < n.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must cover 1 through K, with 2 <= K < n.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must cover 1 through K, with 2 <= K < n.

---

    Code
      score_partition(x, groups, distances)
    Condition
      Error:
      ! Cluster labels must be finite positive integers, one per observation.

# degenerate partitions stop instead of returning infinite indices

    Code
      compute_indices(x, fits)
    Condition
      Error:
      ! Cannot score K = 2: Undefined or non-finite indices: calinski_harabasz, dunn

