# nonnumeric and unsupported data are rejected

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must be a numeric matrix or a data frame with only numeric columns.

# empty data and insufficient observations are rejected

    Code
      validate_input(matrix(numeric(), nrow = 3), 2)
    Condition
      Error:
      ! `x` must contain at least one variable.

---

    Code
      validate_input(data.frame(row.names = 1:3), 2)
    Condition
      Error:
      ! `x` must contain at least one variable.

---

    Code
      validate_input(matrix(numeric(), ncol = 1), 2)
    Condition
      Error:
      ! `x` must contain at least three observations for 2 <= K < n.

---

    Code
      validate_input(matrix(1:2, ncol = 1), 2)
    Condition
      Error:
      ! `x` must contain at least three observations for 2 <= K < n.

# missing and infinite data are rejected rather than cleaned

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must not contain missing values (NA or NaN).

---

    Code
      validate_input(as.data.frame(x), 2)
    Condition
      Error:
      ! `x` must not contain missing values (NA or NaN).

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must not contain missing values (NA or NaN).

---

    Code
      validate_input(as.data.frame(x), 2)
    Condition
      Error:
      ! `x` must not contain missing values (NA or NaN).

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must not contain infinite values (Inf or -Inf).

---

    Code
      validate_input(as.data.frame(x), 2)
    Condition
      Error:
      ! `x` must not contain infinite values (Inf or -Inf).

---

    Code
      validate_input(x, 2)
    Condition
      Error:
      ! `x` must not contain infinite values (Inf or -Inf).

---

    Code
      validate_input(as.data.frame(x), 2)
    Condition
      Error:
      ! `x` must not contain infinite values (Inf or -Inf).

# candidate cluster counts must be a finite numeric vector

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must be a nonempty numeric vector of candidate cluster counts.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain only finite values, with no NA or NaN.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain only finite values, with no NA or NaN.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain only finite values, with no NA or NaN.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain only finite values, with no NA or NaN.

# candidate cluster counts are distinct whole numbers within bounds

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain whole numbers greater than or equal to 2.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain distinct candidate cluster counts; duplicates are not allowed.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! `k` must contain distinct candidate cluster counts; duplicates are not allowed.

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! Every candidate in `k` must be less than the number of observations (6).

---

    Code
      validate_input(x, k)
    Condition
      Error:
      ! Every candidate in `k` must be less than the number of observations (6).

# distinct points are counted across complete rows

    Code
      validate_input(x, 4)
    Condition
      Error:
      ! Every candidate in `k` must be no greater than the number of distinct data points (3).

---

    Code
      validate_input(as.data.frame(x), 4)
    Condition
      Error:
      ! Every candidate in `k` must be no greater than the number of distinct data points (3).

---

    Code
      validate_input(matrix(1, nrow = 5), 2)
    Condition
      Error:
      ! Every candidate in `k` must be no greater than the number of distinct data points (1).

