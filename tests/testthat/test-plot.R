as_kconsensus <- function(x) {
  structure(x, class = c("kconsensus_result", "list"))
}

sample_consensus_fixture <- function() {
  indices <- data.frame(
    k = 2:5,
    silhouette = c(0.42, 0.61, 0.51, 0.39),
    calinski_harabasz = c(90, 145, 120, 95),
    davies_bouldin = c(0.95, 0.52, 0.68, 0.88),
    dunn = c(0.18, 0.31, 0.44, 0.25)
  )
  tab <- cbind(
    logW = c(5.0, 4.5, 4.1, 3.9, 3.8),
    E.logW = c(5.1, 4.8, 4.6, 4.35, 4.2),
    gap = c(0.10, 0.30, 0.50, 0.45, 0.40),
    SE.sim = c(0.04, 0.05, 0.06, 0.05, 0.04)
  )
  gap <- list(
    k = 3L,
    gap = list(Tab = tab),
    selection_method = "firstSEmax",
    seed = 6749L,
    d_power = 1L
  )
  elbow <- compute_elbow(1:5, c(100, 58, 30, 25, 22), min_strength = NULL)
  recs <- recommend_methods(indices, gap = gap, elbow = elbow)
  as_kconsensus(compute_consensus(recs))
}

test_that("plot.kconsensus_result returns buildable ggplot objects for all three types", {
  res <- sample_consensus_fixture()

  p_con <- plot(res, type = "consensus")
  p_ind <- plot(res, type = "indices")
  p_mat <- plot(res, type = "matrix")

  expect_s3_class(p_con, "ggplot")
  expect_s3_class(p_ind, "ggplot")
  expect_s3_class(p_mat, "ggplot")

  expect_no_warning(ggplot2::ggplot_build(p_con))
  expect_no_warning(ggplot2::ggplot_build(p_ind))
  expect_no_warning(ggplot2::ggplot_build(p_mat))
})

test_that("consensus plot shows exact counts, denominator, abstentions, and caveat", {
  res <- sample_consensus_fixture()
  p <- plot(res, type = "consensus")

  expect_identical(as.integer(p$data$k), 1:5)
  expect_s3_class(p$data$k_factor, "factor")
  expect_identical(p$data$votes, c(0L, 0L, 4L, 1L, 0L))
  expect_equal(p$data$agreement_percent, c(0, 0, 80, 20, 0))
  expect_identical(p$data$label, c("", "", "4 (80%)", "1 (20%)", ""))
  expect_identical(
    as.character(p$data$role),
    c(
      "Other evaluated K", "Other evaluated K", "Selected consensus K",
      "Other evaluated K", "Other evaluated K"
    )
  )
  expect_match(p$labels$subtitle, "Majority: K = 3 (4 of 5 valid votes, 80%)", fixed = TRUE)
  expect_match(p$labels$subtitle, "Eligible denominator: 5 of 6 methods", fixed = TRUE)
  expect_match(p$labels$subtitle, "WCSS Elbow [ambiguous]", fixed = TRUE)
  expect_match(
    p$labels$caption,
    "Equal-weight vote agreement is descriptive, not statistical confidence.",
    fixed = TRUE
  )
  expect_match(
    p$labels$caption,
    "K-means favors compact, roughly spherical groups.",
    fixed = TRUE
  )
})

test_that("a plurality leader is labelled as lacking a majority", {
  scores <- data.frame(k = 2:5, score = c(0.2, 0.6, 0.4, 0.3))
  res <- as_kconsensus(compute_consensus(list(
    method_recommendation("silhouette", 3L, "valid", scores = scores),
    method_recommendation("dunn", 3L, "valid", scores = scores),
    method_recommendation("davies_bouldin", 4L, "valid", scores = scores),
    method_recommendation("calinski_harabasz", 5L, "valid", scores = scores),
    method_recommendation("custom", 2L, "valid", scores = scores)
  )))
  p <- plot(res, type = "consensus")

  expect_identical(
    as.character(p$data$role),
    c("Other evaluated K", "Leading K (no majority)", "Other evaluated K", "Other evaluated K")
  )
  expect_match(
    p$labels$subtitle,
    "Plurality, no majority: K = 3 (2 of 5 valid votes, 40%)",
    fixed = TRUE
  )
  expect_no_warning(ggplot2::ggplot_build(p))
})

test_that("ties and zero-vote states are explicit and never pick an arbitrary winner", {
  tie_res <- as_kconsensus(compute_consensus(list(
    method_recommendation("silhouette", 3L, "valid", scores = data.frame(k = 2:5, score = c(0.2, 0.6, 0.4, 0.3))),
    method_recommendation("dunn", 4L, "valid", scores = data.frame(k = 2:5, score = c(0.1, 0.3, 0.5, 0.2)))
  )))
  p_tie <- plot(tie_res, type = "consensus")

  expect_identical(
    as.character(p_tie$data$role),
    c("Other evaluated K", "Tied leading candidate", "Tied leading candidate", "Other evaluated K")
  )
  expect_match(p_tie$labels$subtitle, "Tied leading candidates: K = 3, 4 (no single K selected)", fixed = TRUE)

  zero_res <- as_kconsensus(compute_consensus(list(
    method_recommendation("silhouette", NA_integer_, "ambiguous", "Tie.", scores = data.frame(k = 2:4, score = c(1, 1, 0.5))),
    method_recommendation("gap", NA_integer_, "undefined", "Failed.", scores = data.frame(k = integer()))
  )))
  p_zero <- plot(zero_res, type = "consensus")

  expect_identical(as.character(p_zero$data$role), rep("No eligible votes", 3L))
  expect_identical(p_zero$data$label, rep("", 3L))
  expect_match(p_zero$labels$subtitle, "No eligible votes cast (agreement undefined)", fixed = TRUE)
  expect_match(p_zero$labels$subtitle, "Eligible denominator: 0 of 2 methods", fixed = TRUE)

  empty_res <- as_kconsensus(compute_consensus(list(
    method_recommendation("gap", NA_integer_, "undefined", "No scores.")
  )))
  p_empty <- plot(empty_res, type = "consensus")
  p_empty_mat <- plot(empty_res, type = "matrix")
  p_empty_ind <- plot(empty_res, type = "indices")

  expect_s3_class(p_empty, "ggplot")
  expect_s3_class(p_empty_mat, "ggplot")
  expect_s3_class(p_empty_ind, "ggplot")
  expect_no_warning(ggplot2::ggplot_build(p_empty))
  expect_no_warning(ggplot2::ggplot_build(p_empty_mat))
  expect_no_warning(ggplot2::ggplot_build(p_empty_ind))
})

test_that("indices plot preserves raw values, free_y facets, score_gap, and Gap SE.sim bars", {
  res <- sample_consensus_fixture()
  p <- plot(res, type = "indices")

  expect_identical(p$facet$params$free$y, TRUE)
  expect_identical(p$facet$params$free$x, FALSE)

  panel_levels <- levels(p$data$panel)
  expect_length(panel_levels, 6L)
  expect_match(panel_levels[1], "Silhouette | Selected K = 3 | score_gap = 0.1", fixed = TRUE)
  expect_match(panel_levels[2], "Calinski-Harabasz | Selected K = 3 | score_gap = 25", fixed = TRUE)
  expect_match(panel_levels[3], "Davies-Bouldin | Selected K = 3 | score_gap = 0.16", fixed = TRUE)
  expect_match(panel_levels[4], "Dunn | Selected K = 4 | score_gap = 0.13", fixed = TRUE)
  expect_match(panel_levels[5], "Gap Statistic | Selected K = 3 | SE.sim = simulation SE (not CI)", fixed = TRUE)
  expect_match(panel_levels[6], "WCSS Elbow | Abstained [ambiguous]", fixed = TRUE)

  sil_rows <- p$data[p$data$method == "silhouette", ]
  expect_equal(sil_rows$value, c(0.42, 0.61, 0.51, 0.39))
  expect_equal(unique(sil_rows$score_gap), 0.10)

  gap_rows <- p$data[p$data$method == "gap", ]
  expect_equal(gap_rows$value, c(0.10, 0.30, 0.50, 0.45, 0.40))
  expect_equal(gap_rows$ymin, gap_rows$value - c(0.04, 0.05, 0.06, 0.05, 0.04))
  expect_equal(gap_rows$ymax, gap_rows$value + c(0.04, 0.05, 0.06, 0.05, 0.04))

  elbow_rows <- p$data[p$data$method == "elbow", ]
  expect_equal(elbow_rows$value, c(100, 58, 30, 25, 22))
  expect_identical(any(elbow_rows$is_selected), FALSE)
  expect_match(p$labels$subtitle, "not a confidence interval", fixed = TRUE)
})

test_that("indices plot does not bridge across missing scores or warn on one-point segments", {
  gapped_scores <- data.frame(
    k = 2:6,
    score = c(0.5, NA_real_, 0.7, 0.6, NA_real_)
  )
  single_point <- data.frame(
    k = 2:4,
    score = c(NA_real_, 0.8, NA_real_)
  )
  custom_metric <- data.frame(
    k = 2:4,
    criterion = c(10, 20, 15)
  )
  res <- as_kconsensus(compute_consensus(list(
    method_recommendation("silhouette", NA_integer_, "undefined", "Missing at K = 3, 6.", scores = gapped_scores),
    method_recommendation("dunn", NA_integer_, "undefined", "Only one finite point.", scores = single_point),
    method_recommendation("custom_m", 3L, "valid", scores = custom_metric)
  )))

  p <- plot(res, type = "indices")
  expect_no_warning(built <- ggplot2::ggplot_build(p))

  # Gapped scores have an isolated point at K = 2 and a 2-point segment at K = 4..5
  sil_pts <- p$data[p$data$method == "silhouette", ]
  expect_identical(nrow(sil_pts), 5L)
  expect_identical(
    as.character(sil_pts$point_role),
    c("Evaluated K", "Undefined / abstained", "Evaluated K", "Evaluated K", "Undefined / abstained")
  )
  line_layers <- Filter(
    function(l) inherits(l$geom, "GeomLine"),
    p$layers
  )
  expect_length(line_layers, 1L)
  line_data <- line_layers[[1L]]$data
  expect_identical(
    as.integer(line_data$k[line_data$method == "silhouette"]),
    c(4L, 5L)
  )
  expect_identical(nrow(line_data[line_data$method == "dunn", , drop = FALSE]), 0L)
  expect_equal(p$data$value[p$data$method == "custom_m"], c(10, 20, 15))
})

test_that("matrix plot preserves K = 1 untested cells, marks excluded methods, and adds no fake elbow vote", {
  res <- sample_consensus_fixture()
  res$recommendations$dunn <- method_recommendation(
    "dunn",
    preferred_k = 4L,
    status = "valid",
    reason = "Excluded by user policy.",
    scores = res$recommendations$dunn$scores,
    diagnostics = res$recommendations$dunn$diagnostics,
    eligible = FALSE
  )
  res <- as_kconsensus(compute_consensus(res$recommendations))

  p <- plot(res, type = "matrix")
  df <- p$data

  expect_identical(levels(df$k_factor), as.character(1:5))

  internal_k1 <- df[
    df$method %in% c("silhouette", "calinski_harabasz", "davies_bouldin", "dunn") &
      df$k == 1L,
    ,
    drop = FALSE
  ]
  expect_identical(as.character(internal_k1$cell_state), rep("Untested", 4L))

  dunn_pref <- df[df$method == "dunn" & df$k == 4L, , drop = FALSE]
  expect_identical(as.character(dunn_pref$cell_state), "Excluded preference")
  expect_match(as.character(dunn_pref$method_label), "Dunn [excluded]", fixed = TRUE)

  indices_panels <- levels(plot(res, type = "indices")$data$panel)
  expect_true(any(grepl("Dunn | K = 4 [excluded]", indices_panels, fixed = TRUE)))

  elbow_cells <- df[df$method == "elbow", , drop = FALSE]
  expect_identical(as.character(elbow_cells$cell_state), rep("Evaluated", 5L))
  expect_match(unique(as.character(elbow_cells$method_label)), "WCSS Elbow [ambiguous]", fixed = TRUE)
})

test_that("plots support standard ggplot2 customization and validate inputs", {
  res <- sample_consensus_fixture()
  p <- plot(res, type = "consensus") +
    ggplot2::labs(title = "Custom Title") +
    ggplot2::theme(legend.position = "none")

  expect_identical(p$labels$title, "Custom Title")
  expect_identical(p$theme$legend.position, "none")

  expect_snapshot(error = TRUE, plot.kconsensus_result(list(a = 1)))
  expect_snapshot(error = TRUE, plot.kconsensus_result(res, y = 1:3))
  expect_snapshot(error = TRUE, plot.kconsensus_result(res, type = "unknown"))
})

# Drawing runs the facet labeller, themes and scales that ggplot_build() skips.
expect_renders <- function(p) {
  withr::local_pdf(NULL)
  expect_no_warning(grob <- ggplot2::ggplotGrob(p))
  expect_s3_class(grob, "gtable")
}

plot_vote <- function(method, k, scores = data.frame(k = 2:5, score = c(0.2, 0.6, 0.4, 0.3))) {
  method_recommendation(method, k, "valid", scores = scores)
}

test_that("every plot type draws for every support level", {
  failed <- method_recommendation("z", reason = "Failed.", scores = data.frame(k = 2:5))
  results <- list(
    unanimous = compute_consensus(list(plot_vote("a", 3L), plot_vote("b", 3L))),
    majority = sample_consensus_fixture(),
    plurality = compute_consensus(list(
      plot_vote("a", 3L), plot_vote("b", 3L), plot_vote("c", 4L),
      plot_vote("d", 5L), plot_vote("e", 2L)
    )),
    single_vote = compute_consensus(list(plot_vote("a", 3L), failed)),
    tie = compute_consensus(list(plot_vote("a", 3L), plot_vote("b", 4L))),
    no_valid_votes = compute_consensus(list(failed))
  )
  for (status in names(results)) {
    expect_identical(results[[status]]$status, status)
    for (type in c("consensus", "indices", "matrix")) {
      expect_renders(plot(results[[status]], type = type))
    }
  }
})

test_that("undefined scores are shown as undefined in the matrix and indices views", {
  res <- compute_consensus(list(
    plot_vote("silhouette", 4L, data.frame(k = 2:5, score = c(0.4, 0.45, 0.5, 0.3))),
    method_recommendation(
      "dunn", NA_integer_, "undefined", "Non-finite scores at K = 3.",
      scores = data.frame(k = 2:5, score = c(0.4, NA, 0.5, 0.3))
    ),
    method_recommendation(
      "davies_bouldin", NA_integer_, "undefined", "Non-finite scores at K = 2, 3, 4, 5.",
      scores = data.frame(k = 2:5, score = rep(NA_real_, 4))
    )
  ))

  matrix_plot <- plot(res, type = "matrix")
  dunn_k3 <- matrix_plot$data[matrix_plot$data$method == "dunn" & matrix_plot$data$k == 3L, ]
  expect_identical(as.character(dunn_k3$cell_state), "Undefined score")
  expect_identical(dunn_k3$cell_label, "NA")

  indices_plot <- plot(res, type = "indices")
  panels <- levels(indices_plot$data$panel)
  expect_true("Dunn | Abstained [undefined] | Undefined at K = 3" %in% panels)
  expect_true("Davies-Bouldin | Abstained [undefined] | All scores undefined" %in% panels)
  # Notes live in the panel titles, not in a text layer that can be clipped.
  expect_false(any(vapply(indices_plot$layers, function(layer) {
    inherits(layer$geom, "GeomText")
  }, logical(1))))
  expect_renders(matrix_plot)
  expect_renders(indices_plot)

  no_scores <- compute_consensus(list(
    plot_vote("silhouette", 3L),
    method_recommendation("gap", reason = "Gap failed.")
  ))
  expect_true(
    "Gap Statistic | Abstained [undefined] | No scores available" %in%
      levels(plot(no_scores, type = "indices")$data$panel)
  )
})

test_that("plots stay legible at small sizes", {
  failed <- method_recommendation("z", reason = "Failed.", scores = data.frame(k = 2:5))
  many_abstentions <- compute_consensus(list(
    plot_vote("silhouette", 3L),
    method_recommendation(
      "calinski_harabasz", reason = "Non-finite scores at K = 3.",
      scores = data.frame(k = 2:5, score = c(10, NA, 20, 15))
    ),
    method_recommendation("davies_bouldin", reason = "Non-finite scores.", scores = data.frame(k = 2:5)),
    method_recommendation("dunn", reason = "Non-finite scores.", scores = data.frame(k = 2:5)),
    method_recommendation("gap", reason = "Gap failed."),
    method_recommendation("elbow", NA_integer_, "ambiguous", "No threshold.", scores = data.frame(k = 2:5))
  ))

  # The list of methods that did not vote wraps instead of running off the plot.
  subtitle_lines <- strsplit(plot(many_abstentions)$labels$subtitle, "\n")[[1]]
  expect_gt(length(subtitle_lines), 3L)
  expect_true(all(nchar(subtitle_lines) <= 62L))

  # A legend with more than three keys uses two rows; two keys fit on one.
  matrix_plot <- plot(many_abstentions, type = "matrix")
  expect_identical(length(unique(matrix_plot$data$cell_state)), 4L)
  expect_identical(matrix_plot$guides$guides$fill$params$nrow, 2L)
  few_keys <- plot(compute_consensus(list(plot_vote("a", 3L), failed)), type = "matrix")
  expect_identical(few_keys$guides$guides$fill$params$nrow, 1L)

  # Overlapping K labels are dropped, and the legend keeps a fixed order.
  wide <- compute_consensus(list(
    plot_vote("a", 2L, data.frame(k = 2:15, score = c(1, seq(0.9, 0.3, length.out = 13)))),
    plot_vote("b", 3L, data.frame(k = 2:15, score = c(0.5, 1, seq(0.9, 0.3, length.out = 12)))),
    failed
  ))
  indices_plot <- plot(wide, type = "indices")
  x_scale <- indices_plot$scales$get_scales("x")
  expect_true(isTRUE(x_scale$guide$params$check.overlap))
  colour_scale <- indices_plot$scales$get_scales("colour")
  expect_identical(colour_scale$breaks, c("Eligible preferred K", "Evaluated K"))

  for (p in list(plot(wide), plot(many_abstentions, type = "matrix"), indices_plot)) {
    withr::with_options(list(), {
      grDevices::png(tempfile(fileext = ".png"), width = 600, height = 450, res = 96)
      expect_no_warning(print(p))
      grDevices::dev.off()
    })
  }
})

test_that("an upper-boundary winner is called out in every plot caption", {
  res <- suppressWarnings(compute_consensus(list(plot_vote("a", 5L), plot_vote("b", 5L))))
  for (type in c("consensus", "indices", "matrix")) {
    expect_match(
      plot(res, type = type)$labels$caption,
      "Warning: Winner lies at the upper tested K boundary.",
      fixed = TRUE
    )
  }
})
