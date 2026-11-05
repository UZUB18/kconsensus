# inconsistent records fail rather than silently changing votes

    Code
      method_recommendation("", reason = "No result.")
    Condition
      Error:
      ! `method` must be a single nonempty name.

---

    Code
      method_recommendation("m", status = "unknown")
    Condition
      Error:
      ! `status` must be valid, ambiguous, or undefined.

---

    Code
      method_recommendation("m")
    Condition
      Error:
      ! Supply a text `reason` for every abstention or exclusion.

---

    Code
      method_recommendation("m", status = "valid", scores = scores)
    Condition
      Error:
      ! Valid methods need a tested preferred K; abstaining methods cannot vote.

---

    Code
      method_recommendation("m", 5L, "valid", scores = scores)
    Condition
      Error:
      ! Valid methods need a tested preferred K; abstaining methods cannot vote.

---

    Code
      method_recommendation("m", 3L, "ambiguous", "Tie.", scores)
    Condition
      Error:
      ! Valid methods need a tested preferred K; abstaining methods cannot vote.

---

    Code
      method_recommendation("m", NA, "undefined", "Failed.", scores, eligible = TRUE)
    Condition
      Error:
      ! Valid methods need a tested preferred K; abstaining methods cannot vote.

---

    Code
      method_recommendation("m", 3L, "valid", scores = scores, eligible = FALSE)
    Condition
      Error:
      ! Supply a text `reason` for every abstention or exclusion.

---

    Code
      method_recommendation("m", reason = "Failed.", scores = data.frame(k = c(2, 2)))
    Condition
      Error:
      ! `scores` must be a data frame with distinct positive whole-number `k` values.

---

    Code
      method_recommendation("m", 2.5, "valid", scores = scores)
    Condition
      Error:
      ! `preferred_k` must be NA or a single positive whole number.

