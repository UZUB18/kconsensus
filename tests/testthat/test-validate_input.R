test_that("valid inputs are returned unchanged with preprocessing metadata", {
  x <- matrix(seq_len(12), nrow = 6, dimnames = list(NULL, c("a", "b")))
  k <- c(4, 2, 3)

  for (input in list(x, as.data.frame(x), scale(x))) {
    result <- validate_input(input, k)
    expect_identical(result$data, input)
    expect_identical(result$k, k)
    expect_identical(result$preprocessing, list(
      data_used_as_supplied = TRUE,
      standardized_by_package = FALSE
    ))
  }
  expect_identical(validate_input(x, 2L)$k, 2L)
})

test_that("nonnumeric and unsupported data are rejected", {
  for (x in list(
    1:6,
    list(a = 1:6),
    array(1:8, dim = c(2, 2, 2)),
    matrix(letters[1:6], nrow = 3),
    matrix(TRUE, nrow = 3),
    matrix(1 + 1i, nrow = 3),
    data.frame(a = 1:3, b = c("1", "2", "3")),
    data.frame(a = factor(1:3)),
    data.frame(a = c(TRUE, FALSE, TRUE)),
    data.frame(a = rep(1 + 1i, 3)),
    data.frame(a = I(matrix(1:6, nrow = 3)))
  )) {
    expect_snapshot(error = TRUE, validate_input(x, 2))
  }
})

test_that("empty data and insufficient observations are rejected", {
  expect_snapshot(error = TRUE, validate_input(matrix(numeric(), nrow = 3), 2))
  expect_snapshot(error = TRUE, validate_input(data.frame(row.names = 1:3), 2))
  expect_snapshot(error = TRUE, validate_input(matrix(numeric(), ncol = 1), 2))
  expect_snapshot(error = TRUE, validate_input(matrix(1:2, ncol = 1), 2))
})

test_that("missing and infinite data are rejected rather than cleaned", {
  for (value in c(NA_real_, NaN, Inf, -Inf)) {
    x <- matrix(c(1:5, value), ncol = 1)
    expect_snapshot(error = TRUE, validate_input(x, 2))
    expect_snapshot(error = TRUE, validate_input(as.data.frame(x), 2))
  }
})

test_that("candidate cluster counts must be a finite numeric vector", {
  x <- matrix(1:12, nrow = 6)
  for (k in list(
    NULL, numeric(), "2", TRUE, list(2), factor(2), 2 + 0i,
    matrix(2), NA_real_, NaN, Inf, -Inf
  )) {
    expect_snapshot(error = TRUE, validate_input(x, k))
  }
})

test_that("candidate cluster counts are distinct whole numbers within bounds", {
  x <- matrix(1:12, nrow = 6)
  for (k in list(0, -2, 1, 2.5, c(2, 3.5), c(2, 2), c(2, 3, 2), 6, c(2, 7))) {
    expect_snapshot(error = TRUE, validate_input(x, k))
  }
  expect_identical(validate_input(x, 5)$k, 5)
})

test_that("distinct points are counted across complete rows", {
  x <- rbind(c(0, 0), c(0, 1), c(1, 0), c(0, 0), c(0, 1))
  expect_identical(validate_input(x, c(3, 2))$data, x)
  expect_identical(validate_input(as.data.frame(x), 3)$k, 3)
  expect_snapshot(error = TRUE, validate_input(x, 4))
  expect_snapshot(error = TRUE, validate_input(as.data.frame(x), 4))
  expect_snapshot(error = TRUE, validate_input(matrix(1, nrow = 5), 2))
})
