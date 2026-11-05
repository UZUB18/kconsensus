# Run from inside extracted kconsensus_benchmark/ directory.
# This demonstrates the PROPOSED kconsensus API; package implementation is
# not provided here and this R script has not been executed.

library(kconsensus)

manifest <- read.csv('manifest.csv', stringsAsFactors = FALSE)
valid <- manifest[manifest$valid_input, ]

for (i in seq_len(nrow(valid))) {
  item <- valid[i, ]
  x <- as.matrix(read.csv(item$csv_path))

  # For many_12, compare 2:10 with 2:15 in a separate second run.
  range <- if (item$scenario == 'many_12') 2:15 else 2:10

  cat('\n===== ', item$scenario, ' =====\n', sep = '')
  result <- try(choose_k(x, k = range, seed = 42), silent = TRUE)
  if (inherits(result, 'try-error')) {
    cat('Error: ', as.character(result), '\n')
  } else {
    print(summary(result))
  }
}

# Example expected-error checks (do not coerce character input to numeric):
invalid <- manifest[!manifest$valid_input, ]
for (i in seq_len(nrow(invalid))) {
  item <- invalid[i, ]
  data <- read.csv(item$csv_path)
  cat('\nExpected rejection: ', item$scenario, '\n', sep = '')
  print(try(choose_k(data, k = 2:10, seed = 42), silent = TRUE))
}
