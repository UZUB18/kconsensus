# plots support standard ggplot2 customization and validate inputs

    Code
      plot.kconsensus_result(list(a = 1))
    Condition
      Error:
      ! `x` must be a valid `kconsensus_result` object.

---

    Code
      plot.kconsensus_result(res, y = 1:3)
    Condition
      Error:
      ! `y` is not used when plotting a `kconsensus_result` object.

---

    Code
      plot.kconsensus_result(res, type = "unknown")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "consensus", "indices", "matrix"

