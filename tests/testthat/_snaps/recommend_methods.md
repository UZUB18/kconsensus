# records are built only for the requested methods, in canonical order

    Code
      recommend_methods(indices, methods = "silhouette")
    Condition
      Error:
      ! `indices` must contain k and a score column for every requested index.

---

    Code
      recommend_methods(indices, methods = c("dunn", "dunn"))
    Condition
      Error:
      ! `methods` must be distinct names from: "silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "gap", "elbow".

---

    Code
      recommend_methods(indices, methods = "kmeans")
    Condition
      Error:
      ! `methods` must be distinct names from: "silhouette", "calinski_harabasz", "davies_bouldin", "dunn", "gap", "elbow".

# malformed index inputs are rejected

    Code
      recommend_index("m", 2:4, c(0.1, 0.2), "max")
    Condition
      Error:
      ! Supply numeric scores for each K and direction max or min.

---

    Code
      recommend_index("m", 2:4, c(0.1, 0.2, 0.3), "up")
    Condition
      Error:
      ! Supply numeric scores for each K and direction max or min.

