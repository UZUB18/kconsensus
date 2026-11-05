#' Plot consensus clustering diagnostics and method agreement
#'
#' Visualizes candidate cluster counts from a `kconsensus_result` object as
#' a consensus vote bar chart (`type = "consensus"`), per-method raw diagnostic
#' curves (`type = "indices"`), or a method-by-K evaluation matrix
#' (`type = "matrix"`). All views use a single accent color (`#0072B2`) for
#' eligible selected or tied leading candidates and neutral greys for other
#' marks.
#'
#' @param x A `kconsensus_result` object returned by [kconsensus()].
#' @param y Unused; must be `NULL`.
#' @param type Character string selecting the plot view: `"consensus"`,
#'   `"indices"`, or `"matrix"`.
#' @param ... Unused additional arguments for S3 compatibility.
#'
#' @return A `ggplot2::ggplot` object that can be customized with standard
#'   `ggplot2` layers, scales, labels, and themes.
#' @importFrom graphics plot
#' @export
plot.kconsensus_result <- function(
  x,
  y = NULL,
  type = c("consensus", "indices", "matrix"),
  ...
) {
  validate_consensus_plot_input(x, y)
  type <- match.arg(type)
  switch(
    type,
    consensus = plot_consensus_bars(x),
    indices = plot_consensus_indices(x),
    matrix = plot_consensus_matrix(x)
  )
}

validate_consensus_plot_input <- function(x, y) {
  if (!is.null(y)) {
    stop(
      "`y` is not used when plotting a `kconsensus_result` object.",
      call. = FALSE
    )
  }
  required <- c(
    "recommended_k", "tied_candidates", "status", "n_valid_methods",
    "agreement", "methods", "recommendations"
  )
  if (
    !is.list(x) || !all(required %in% names(x)) ||
      !is.data.frame(x$agreement) || !is.data.frame(x$methods) ||
      !is.list(x$recommendations) || length(x$recommendations) == 0L
  ) {
    stop("`x` must be a valid `kconsensus_result` object.", call. = FALSE)
  }
  invisible(x)
}

friendly_method_name <- function(method) {
  known <- c(
    silhouette = "Silhouette",
    calinski_harabasz = "Calinski-Harabasz",
    davies_bouldin = "Davies-Bouldin",
    dunn = "Dunn",
    gap = "Gap Statistic",
    elbow = "WCSS Elbow"
  )
  out <- ifelse(method %in% names(known), unname(known[method]), method)
  as.character(out)
}

consensus_caveat <- function(boundary_warning = FALSE, extra = NULL) {
  parts <- c(
    extra,
    if (isTRUE(boundary_warning)) {
      "Warning: Winner lies at the upper tested K boundary."
    },
    "Equal-weight vote agreement is descriptive, not statistical confidence.",
    "K-means favors compact, roughly spherical groups."
  )
  paste(parts[nzchar(parts)], collapse = "\n")
}

theme_kconsensus <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0, size = 9.5),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.subtitle = ggplot2::element_text(color = "#404040"),
      plot.caption = ggplot2::element_text(color = "#595959", hjust = 0),
      legend.position = "bottom"
    )
}

consensus_subtitle <- function(x) {
  n_total <- nrow(x$methods)
  n_valid <- as.integer(x$n_valid_methods)
  outcome <- if (identical(x$status, "unique_winner") && !is.na(x$recommended_k)) {
    sprintf("Selected consensus candidate: K = %d", x$recommended_k)
  } else if (identical(x$status, "tie") && length(x$tied_candidates) > 0L) {
    sprintf(
      "Tied leading candidates: K = %s (no single K selected)",
      paste(x$tied_candidates, collapse = ", ")
    )
  } else {
    "No eligible votes cast (agreement undefined)"
  }

  non_voting <- x$methods[!x$methods$included, , drop = FALSE]
  if (nrow(non_voting) == 0L) {
    denom <- sprintf(
      "Eligible denominator: %d of %d methods (0 abstentions)",
      n_valid,
      n_total
    )
  } else {
    tags <- ifelse(
      non_voting$status == "valid" & !non_voting$eligible,
      "excluded",
      non_voting$status
    )
    details <- paste(
      sprintf("%s [%s]", friendly_method_name(non_voting$method), tags),
      collapse = ", "
    )
    denom <- sprintf(
      "Eligible denominator: %d of %d methods (%d non-voting)\n%s",
      n_valid,
      n_total,
      nrow(non_voting),
      details
    )
  }
  paste(outcome, denom, sep = "\n")
}

plot_consensus_bars <- function(x) {
  k_factor <- votes <- role <- label <- NULL
  subtitle <- consensus_subtitle(x)
  caption <- consensus_caveat(x$boundary_warning)

  if (nrow(x$agreement) == 0L) {
    empty_df <- data.frame(
      k = integer(),
      k_factor = factor(character()),
      votes = integer(),
      agreement_percent = numeric(),
      role = character(),
      label = character()
    )
    return(
      ggplot2::ggplot(empty_df) +
        ggplot2::annotate(
          "text",
          x = 1,
          y = 0.5,
          label = "No candidate K values or eligible votes available.",
          color = "#4D4D4D"
        ) +
        ggplot2::scale_x_continuous(breaks = NULL) +
        ggplot2::scale_y_continuous(limits = c(0, 1), breaks = 0:1) +
        ggplot2::labs(
          title = "Consensus support for K",
          subtitle = subtitle,
          x = "Candidate cluster count (K)",
          y = "Eligible method votes",
          caption = caption
        ) +
        theme_kconsensus()
    )
  }

  df <- x$agreement
  df$k_factor <- factor(df$k, levels = sort(unique(df$k)))
  df$role <- if (identical(x$status, "unique_winner") && !is.na(x$recommended_k)) {
    ifelse(df$k == x$recommended_k, "Selected consensus K", "Other evaluated K")
  } else if (identical(x$status, "tie") && length(x$tied_candidates) > 0L) {
    ifelse(
      df$k %in% x$tied_candidates,
      "Tied leading candidate",
      "Other evaluated K"
    )
  } else {
    rep("No eligible votes", nrow(df))
  }
  df$role <- factor(
    df$role,
    levels = unique(c(
      "Selected consensus K",
      "Tied leading candidate",
      "Other evaluated K",
      "No eligible votes"
    ))
  )
  df$label <- if (x$n_valid_methods > 0L) {
    pct <- ifelse(
      abs(df$agreement_percent - round(df$agreement_percent)) < 1e-6,
      sprintf("%.0f%%", df$agreement_percent),
      sprintf("%.1f%%", df$agreement_percent)
    )
    sprintf("%d (%s)", df$votes, pct)
  } else {
    sprintf("%d (NA)", df$votes)
  }

  upper_y <- max(1L, as.integer(x$n_valid_methods), max(df$votes, na.rm = TRUE))
  ggplot2::ggplot(
    df,
    ggplot2::aes(x = k_factor, y = votes, fill = role)
  ) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::geom_text(
      ggplot2::aes(label = label),
      vjust = -0.45,
      size = 3.3,
      color = "#262626"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Selected consensus K" = "#0072B2",
        "Tied leading candidate" = "#0072B2",
        "Other evaluated K" = "#B8B8B8",
        "No eligible votes" = "#D0D0D0"
      ),
      drop = TRUE,
      name = NULL
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq.int(0L, upper_y),
      expand = ggplot2::expansion(mult = c(0, 0.18))
    ) +
    ggplot2::coord_cartesian(ylim = c(0, upper_y * 1.15)) +
    ggplot2::labs(
      title = "Consensus support for K",
      subtitle = subtitle,
      x = "Candidate cluster count (K)",
      y = "Eligible method votes",
      caption = caption
    ) +
    theme_kconsensus()
}

extract_method_curve <- function(record, default_k) {
  scores <- record$scores
  method <- record$method
  friendly <- friendly_method_name(method)
  is_eligible_valid <- identical(record$status, "valid") &&
    isTRUE(record$eligible) &&
    !is.na(record$preferred_k)

  score_cols <- setdiff(names(scores), "k")
  y_col <- if (identical(method, "gap") && "gap" %in% score_cols) {
    "gap"
  } else if (identical(method, "elbow") && "wcss" %in% score_cols) {
    "wcss"
  } else if ("score" %in% score_cols) {
    "score"
  } else {
    num_cols <- score_cols[vapply(scores[score_cols], is.numeric, logical(1))]
    if (length(num_cols) > 0L) num_cols[1L] else NULL
  }
  se_col <- if (identical(method, "gap") && "SE.sim" %in% score_cols) {
    "SE.sim"
  } else {
    NULL
  }

  raw_gap <- record$diagnostics$score_gap
  has_score_gap <- is.numeric(raw_gap) &&
    length(raw_gap) == 1L &&
    is.finite(raw_gap)
  score_gap_val <- if (has_score_gap) as.numeric(raw_gap) else NA_real_

  status_tag <- if (is_eligible_valid) {
    sprintf("Selected K = %d", record$preferred_k)
  } else if (identical(record$status, "valid") && !isTRUE(record$eligible)) {
    sprintf("K = %d [excluded]", record$preferred_k)
  } else {
    sprintf("Abstained [%s]", record$status)
  }

  detail_tag <- if (has_score_gap) {
    sprintf("score_gap = %.4g", score_gap_val)
  } else if (identical(method, "gap")) {
    "SE.sim = simulation SE (not CI)"
  } else {
    NULL
  }
  panel <- paste(c(friendly, status_tag, detail_tag), collapse = " | ")

  if (nrow(scores) == 0L || is.null(y_col)) {
    k_vals <- if (nrow(scores) > 0L) as.integer(scores$k) else default_k
    if (length(k_vals) == 0L) k_vals <- 2L
    return(list(
      panel = panel,
      points = data.frame(
        method = rep(method, length(k_vals)),
        panel = rep(panel, length(k_vals)),
        k = as.numeric(k_vals),
        value = rep(NA_real_, length(k_vals)),
        se = rep(NA_real_, length(k_vals)),
        ymin = rep(NA_real_, length(k_vals)),
        ymax = rep(NA_real_, length(k_vals)),
        score_gap = rep(score_gap_val, length(k_vals)),
        is_selected = rep(FALSE, length(k_vals)),
        point_role = rep("Undefined / abstained", length(k_vals)),
        segment_id = rep(NA_character_, length(k_vals)),
        status = rep(record$status, length(k_vals)),
        eligible = rep(record$eligible, length(k_vals))
      ),
      note = sprintf("No finite score curve (%s)", record$status)
    ))
  }

  ord <- order(scores$k)
  k_num <- as.numeric(scores$k[ord])
  y_num <- as.numeric(scores[[y_col]][ord])
  se_num <- if (!is.null(se_col)) {
    as.numeric(scores[[se_col]][ord])
  } else {
    rep(NA_real_, length(k_num))
  }
  finite <- is.finite(y_num)
  breaks <- !finite | c(TRUE, !finite[-length(finite)] | diff(k_num) > 1)
  seg_num <- cumsum(breaks)
  seg_id <- ifelse(finite, paste0(method, "_", seg_num), NA_character_)
  is_sel <- finite & is_eligible_valid & (as.integer(k_num) == record$preferred_k)

  list(
    panel = panel,
    points = data.frame(
      method = rep(method, length(k_num)),
      panel = rep(panel, length(k_num)),
      k = k_num,
      value = y_num,
      se = se_num,
      ymin = ifelse(finite & is.finite(se_num), y_num - se_num, NA_real_),
      ymax = ifelse(finite & is.finite(se_num), y_num + se_num, NA_real_),
      score_gap = rep(score_gap_val, length(k_num)),
      is_selected = is_sel,
      point_role = ifelse(
        !finite,
        "Undefined / abstained",
        ifelse(is_sel, "Eligible preferred K", "Evaluated K")
      ),
      segment_id = seg_id,
      status = rep(record$status, length(k_num)),
      eligible = rep(record$eligible, length(k_num))
    ),
    note = if (!any(finite)) {
      sprintf("All scores undefined (%s)", record$status)
    } else if (any(!finite)) {
      sprintf(
        "Undefined at K = %s",
        paste(as.integer(k_num[!finite]), collapse = ", ")
      )
    } else {
      NULL
    }
  )
}

plot_consensus_indices <- function(x) {
  k <- value <- segment_id <- point_role <- ymin <- ymax <- label <- NULL
  all_k <- sort(unique(unlist(lapply(x$recommendations, \(r) r$scores$k))))
  default_k <- if (length(all_k) > 0L) min(all_k) else 2L

  extracted <- lapply(x$recommendations, extract_method_curve, default_k = default_k)
  panel_levels <- vapply(extracted, \(item) item$panel, character(1))
  raw_df <- do.call(rbind, lapply(extracted, `[[`, "points"))
  rownames(raw_df) <- NULL
  raw_df$panel <- factor(raw_df$panel, levels = panel_levels)

  finite_df <- raw_df[is.finite(raw_df$value), , drop = FALSE]
  seg_counts <- table(finite_df$segment_id)
  multi_segs <- names(seg_counts[seg_counts >= 2L])
  line_df <- finite_df[finite_df$segment_id %in% multi_segs, , drop = FALSE]

  error_df <- finite_df[
    finite_df$method == "gap" &
      is.finite(finite_df$ymin) &
      is.finite(finite_df$ymax),
    ,
    drop = FALSE
  ]

  missing_rows <- lapply(extracted, function(item) {
    pts <- item$points
    bad <- pts[!is.finite(pts$value), , drop = FALSE]
    if (nrow(bad) == 0L) return(NULL)
    fin <- pts$value[is.finite(pts$value)]
    baseline <- if (length(fin) > 0L) min(fin) else 0
    bad$value <- baseline
    bad
  })
  missing_df <- do.call(rbind, missing_rows)
  if (!is.null(missing_df) && nrow(missing_df) > 0L) {
    missing_df$panel <- factor(missing_df$panel, levels = panel_levels)
  }

  note_rows <- lapply(extracted, function(item) {
    if (is.null(item$note)) return(NULL)
    pts <- item$points
    fin <- pts$value[is.finite(pts$value)]
    y_pos <- if (length(fin) > 0L) max(fin) else 0
    x_pos <- stats::median(pts$k, na.rm = TRUE)
    data.frame(
      panel = factor(item$panel, levels = panel_levels),
      k = x_pos,
      value = y_pos,
      label = item$note
    )
  })
  note_df <- do.call(rbind, note_rows)

  plot_df <- raw_df
  plot_df <- plot_df[order(plot_df$panel, plot_df$k), , drop = FALSE]
  rownames(plot_df) <- NULL
  plot_df$point_role <- factor(
    plot_df$point_role,
    levels = c("Eligible preferred K", "Evaluated K", "Undefined / abstained")
  )
  attr(plot_df, "raw_scores") <- raw_df

  selected_df <- finite_df[finite_df$is_selected, , drop = FALSE]
  k_breaks <- if (length(all_k) > 0L) all_k else default_k

  ggplot2::ggplot(plot_df, ggplot2::aes(x = k, y = value)) +
    (if (nrow(selected_df) > 0L) {
      ggplot2::geom_vline(
        data = selected_df,
        ggplot2::aes(xintercept = k),
        linetype = "dashed",
        color = "#0072B2",
        linewidth = 0.45
      )
    }) +
    (if (nrow(error_df) > 0L) {
      ggplot2::geom_errorbar(
        data = error_df,
        ggplot2::aes(x = k, ymin = ymin, ymax = ymax),
        width = 0.16,
        color = "#595959",
        linewidth = 0.45
      )
    }) +
    (if (nrow(line_df) > 0L) {
      ggplot2::geom_line(
        data = line_df,
        ggplot2::aes(group = segment_id),
        color = "#7F7F7F",
        linewidth = 0.6
      )
    }) +
    ggplot2::geom_point(
      data = finite_df,
      ggplot2::aes(color = point_role),
      size = 2
    ) +
    (if (!is.null(missing_df) && nrow(missing_df) > 0L) {
      ggplot2::geom_rug(
        data = missing_df, ggplot2::aes(x = k),
        inherit.aes = FALSE, sides = "b", color = "#A6A6A6"
      )
    }) +
    (if (!is.null(note_df) && nrow(note_df) > 0L) {
      ggplot2::geom_text(
        data = note_df,
        ggplot2::aes(x = k, y = value, label = label),
        vjust = -0.4,
        size = 2.9,
        color = "#595959"
      )
    }) +
    ggplot2::facet_wrap(
      ~panel, scales = "free_y", drop = FALSE, ncol = 3,
      labeller = ggplot2::as_labeller(function(labels) {
        labels <- gsub(" | ", "\n", labels, fixed = TRUE)
        gsub("SE.sim = simulation SE (not CI)", "Simulation SE (not CI)", labels, fixed = TRUE)
      })
    ) +
    ggplot2::scale_x_continuous(breaks = k_breaks) +
    ggplot2::scale_color_manual(
      values = c(
        "Eligible preferred K" = "#0072B2",
        "Evaluated K" = "#7F7F7F",
        "Undefined / abstained" = "#A6A6A6"
      ),
      limits = c("Eligible preferred K", "Evaluated K", "Undefined / abstained"),
      breaks = unique(finite_df$point_role),
      drop = TRUE,
      name = NULL
    ) +
    ggplot2::labs(
      title = "Raw index diagnostics",
      subtitle = paste(
        "Raw indices with separate y-scales.",
        "score_gap: raw difference between the two best scores.",
        "Gap bars: +/-1 simulation SE, not a confidence interval.",
        sep = "\n"
      ),
      x = "Candidate cluster count (K)",
      y = "Raw method criterion value",
      caption = consensus_caveat(x$boundary_warning)
    ) +
    theme_kconsensus()
}

score_defined_at_k <- function(record, k_val) {
  scores <- record$scores
  row_idx <- match(k_val, scores$k)
  if (is.na(row_idx)) return(FALSE)
  score_cols <- setdiff(names(scores), "k")
  if (length(score_cols) == 0L) return(TRUE)
  if (identical(record$method, "gap") && all(c("gap", "SE.sim") %in% score_cols)) {
    return(is.finite(scores$gap[row_idx]) && is.finite(scores$SE.sim[row_idx]))
  }
  if (identical(record$method, "elbow") && "wcss" %in% score_cols) {
    return(is.finite(scores$wcss[row_idx]))
  }
  if ("score" %in% score_cols) {
    return(is.finite(scores$score[row_idx]))
  }
  num_cols <- score_cols[vapply(scores[score_cols], is.numeric, logical(1))]
  if (length(num_cols) == 0L) return(TRUE)
  is.finite(scores[[num_cols[1L]]][row_idx])
}

plot_consensus_matrix <- function(x) {
  k_factor <- method_label <- cell_state <- cell_label <- NULL
  tested_k <- sort(unique(unlist(lapply(x$recommendations, \(r) r$scores$k))))
  all_k <- as.integer(tested_k)

  method_labels <- vapply(
    x$recommendations,
    function(record) {
      base <- friendly_method_name(record$method)
      if (identical(record$status, "valid") && isTRUE(record$eligible)) {
        base
      } else if (identical(record$status, "valid") && !isTRUE(record$eligible)) {
        paste0(base, " [excluded]")
      } else {
        paste0(base, " [", record$status, "]")
      }
    },
    character(1)
  )
  label_levels <- rev(unname(method_labels))

  if (length(all_k) == 0L) {
    empty_grid <- data.frame(
      method = names(x$recommendations),
      method_label = factor(unname(method_labels), levels = label_levels),
      k = rep(NA_integer_, length(x$recommendations)),
      k_factor = factor(rep("None", length(x$recommendations)), levels = "None"),
      tested = rep(FALSE, length(x$recommendations)),
      eligible = vapply(x$recommendations, \(r) r$eligible, logical(1)),
      status = vapply(x$recommendations, \(r) r$status, character(1)),
      cell_state = factor(
        rep("Untested", length(x$recommendations)),
        levels = c(
          "Eligible vote",
          "Excluded preference",
          "Evaluated",
          "Undefined score",
          "Untested"
        )
      ),
      cell_label = rep("-", length(x$recommendations))
    )
    return(
      ggplot2::ggplot(
        empty_grid,
        ggplot2::aes(x = k_factor, y = method_label, fill = cell_state)
      ) +
        ggplot2::geom_tile(color = "#FFFFFF", linewidth = 0.6) +
        ggplot2::geom_text(
          ggplot2::aes(label = cell_label),
          size = 3.1,
          color = "#4D4D4D"
        ) +
        ggplot2::scale_fill_manual(
          values = c("Untested" = "#F2F2F2"),
          name = NULL
        ) +
        ggplot2::labs(
          title = "Method-by-K evidence",
          subtitle = consensus_subtitle(x),
          x = "Candidate cluster count (K)",
          y = "Method",
          caption = consensus_caveat(x$boundary_warning)
        ) +
        theme_kconsensus()
    )
  }

  rows <- lapply(seq_along(x$recommendations), function(i) {
    record <- x$recommendations[[i]]
    m_label <- method_labels[[i]]
    do.call(rbind, lapply(all_k, function(k_val) {
      is_tested <- k_val %in% record$scores$k
      is_defined <- is_tested && score_defined_at_k(record, k_val)
      is_pref <- identical(record$status, "valid") &&
        !is.na(record$preferred_k) &&
        k_val == record$preferred_k
      state <- if (is_pref && isTRUE(record$eligible)) {
        "Eligible vote"
      } else if (is_pref && !isTRUE(record$eligible)) {
        "Excluded preference"
      } else if (!is_tested) {
        "Untested"
      } else if (!is_defined) {
        "Undefined score"
      } else {
        "Evaluated"
      }
      txt <- switch(
        state,
        "Eligible vote" = "Vote",
        "Excluded preference" = "Excl.",
        "Undefined score" = "NA",
        "Untested" = "-",
        ""
      )
      data.frame(
        method = record$method,
        method_label = m_label,
        k = as.integer(k_val),
        k_factor = as.character(k_val),
        tested = is_tested,
        eligible = record$eligible,
        status = record$status,
        cell_state = state,
        cell_label = txt
      )
    }))
  })
  grid_df <- do.call(rbind, rows)
  rownames(grid_df) <- NULL
  grid_df$method_label <- factor(grid_df$method_label, levels = label_levels)
  grid_df$k_factor <- factor(grid_df$k_factor, levels = as.character(all_k))
  grid_df$cell_state <- factor(
    grid_df$cell_state,
    levels = c(
      "Eligible vote",
      "Excluded preference",
      "Evaluated",
      "Undefined score",
      "Untested"
    )
  )

  ggplot2::ggplot(
    grid_df,
    ggplot2::aes(x = k_factor, y = method_label, fill = cell_state)
  ) +
    ggplot2::geom_tile(color = "#FFFFFF", linewidth = 0.65) +
    ggplot2::geom_text(
      ggplot2::aes(label = cell_label),
      size = 3.1,
      color = ifelse(grid_df$cell_state == "Eligible vote", "#FFFFFF", "#333333")
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Eligible vote" = "#0072B2",
        "Excluded preference" = "#7F7F7F",
        "Evaluated" = "#D9D9D9",
        "Undefined score" = "#BDBDBD",
        "Untested" = "#F2F2F2"
      ),
      drop = TRUE,
      name = NULL
    ) +
    ggplot2::labs(
      title = "Method-by-K evidence",
      subtitle = consensus_subtitle(x),
      x = "Candidate cluster count (K)",
      y = "Method",
      caption = consensus_caveat(x$boundary_warning)
    ) +
    theme_kconsensus()
}
