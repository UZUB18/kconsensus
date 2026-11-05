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

