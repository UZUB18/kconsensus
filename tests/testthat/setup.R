# Keep kconsensus quiet during tests, including interactive devtools::test() runs.
withr::local_options(kconsensus.verbose = FALSE, .local_envir = teardown_env())
