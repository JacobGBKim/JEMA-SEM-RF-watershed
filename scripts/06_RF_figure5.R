# =============================================================================
# 06_RF_figure5.R
# -----------------------------------------------------------------------------
# Purpose: Reproduce Figure 5 (Random Forest performance evaluation)
#          For each AEHI (TDI/BMI/FAI) and each predictor set
#          (WQ-only, Landscape-only, All-models), produce:
#            - ROC curve with AUC value
#            - Sensitivity/Specificity/Accuracy vs. probability cutoff curves
#
# Manuscript section: 3.3 Random Forest classification
#                     Figure 5 (panels a–c: ROC; panels d–f: threshold curves)
#
# Inputs:
#   ../data_local/ND2024_catch.csv    [restricted: AEHI scores included]
#
# Outputs:
#   - 9 paired plots (3 indices x 3 predictor sets) rendered to RStudio Plots
#   - Vertical dashed line marks the optimal probability cutoff
#
# Reproducibility:
#   - set.seed(123); ranger random forest with random hyperparameter search
#   - Expected results (manuscript Figure 5):
#       Integrated RF AUC: TDI = 0.70, BMI = 0.93, FAI = 0.88
#       Optimal cutoff:    TDI = 0.57, BMI = 0.56, FAI = 0.43
# =============================================================================

# ---- Load packages ----------------------------------------------------------
library(dplyr)
library(caret)
library(ranger)
library(pROC)
library(ggplot2)
library(tidyr)
library(foreach)
library(doParallel)
library(gridExtra)
library(grid)
library(digest)

# Reproducibility
set.seed(123)

# ---- Load data --------------------------------------------------------------
ECO <- read.csv("../data_local/ND2024_catch.csv", fileEncoding = "euc-kr")

# ---- Variable groups (3 predictor sets) -------------------------------------
wq_vars <- c("temp2", "pH2", "EC2", "DO2", "BOD2", "COD2", "SS2",
             "TOC2", "TN2", "TP2")

land_phys_vars <- c(
  "slope_mean", "relief_mean", "TWI_mean", "HI",        # physiography
  "Aggregation_W", "Complexity_W",
  "Agri", "Forest", "Grass", "Wet", "Bare", "Water", "Urban"  # landscape
)

all_vars <- c(wq_vars, land_phys_vars)

predictor_sets <- list(
  `WQ-only`        = wq_vars,
  `Landscape-only` = land_phys_vars,
  `All-models`     = all_vars
)

# ---- AEHI definitions (response, threshold) --------------------------------
indices <- list(
  TDI = list(var = "TDI1618", threshold = 70),
  BMI = list(var = "BMI1618", threshold = 65),
  FAI = list(var = "FAI1618", threshold = 60)
)

# =============================================================================
# Helper: Random Forest with hyperparameter random search + cache
# =============================================================================
global_rf_cache <- list()

get_rf_model <- function(ml_data, seed = 123) {
  cache_key <- digest(list(ml_data, seed))
  if (!is.null(global_rf_cache[[cache_key]])) {
    return(global_rf_cache[[cache_key]])
  }

  train_index <- createDataPartition(ml_data$label, p = 0.8, list = FALSE)
  train_data  <- ml_data[train_index, ]
  test_data   <- ml_data[-train_index, ]

  hyper_grid <- data.frame(
    mtry            = sample(floor(ncol(train_data) * c(0.05, 0.15, 0.25, 0.333, 0.4)),
                              size = 5, replace = TRUE),
    min.node.size   = sample(c(1, 3, 5, 10, 20), size = 5, replace = TRUE),
    replace         = sample(c(TRUE, FALSE), size = 5, replace = TRUE),
    sample.fraction = sample(c(0.5, 0.63, 0.8), size = 5, replace = TRUE),
    error_rate      = NA
  )

  cl <- makeCluster(detectCores() - 1)
  registerDoParallel(cl)

  error_rates <- foreach(i = 1:nrow(hyper_grid),
                         .combine = c, .packages = "ranger") %dopar% {
    fit <- ranger(
      formula = label ~ ., data = train_data, num.trees = 1000,
      mtry            = hyper_grid$mtry[i],
      min.node.size   = hyper_grid$min.node.size[i],
      replace         = hyper_grid$replace[i],
      sample.fraction = hyper_grid$sample.fraction[i],
      probability = TRUE, seed = seed, verbose = FALSE
    )
    fit$prediction.error
  }
  stopCluster(cl)
  hyper_grid$error_rate <- error_rates

  best_params <- hyper_grid %>% arrange(error_rate) %>% slice(1)

  final_model <- ranger(
    formula = label ~ ., data = train_data, num.trees = 1000,
    mtry            = best_params$mtry,
    min.node.size   = best_params$min.node.size,
    replace         = best_params$replace,
    sample.fraction = best_params$sample.fraction,
    importance = "permutation", probability = TRUE,
    seed = seed, verbose = FALSE
  )

  result <- list(final_model = final_model, test_data = test_data)
  global_rf_cache[[cache_key]] <- result
  return(result)
}

# =============================================================================
# Helper: Generate ROC + Performance-vs-cutoff plots
# =============================================================================
analyze_and_plot_rf <- function(data, response_var, predictor_vars,
                                threshold, title_prefix) {

  model_data <- data %>%
    select(all_of(c(response_var, predictor_vars))) %>%
    na.omit()

  ml_data <- model_data %>%
    mutate(label = factor(ifelse(.data[[response_var]] >= threshold, 1, 0),
                          levels = c(0, 1))) %>%
    select(-all_of(response_var))

  if (length(unique(ml_data$label)) < 2) {
    warning("Only one class present; skipping analysis.")
    return(NULL)
  }

  rf_result   <- get_rf_model(ml_data)
  predictions <- predict(rf_result$final_model, data = rf_result$test_data)
  pred_prob   <- predictions$predictions[, "1"]
  true_labels <- rf_result$test_data$label

  # ---- ROC curve ------------------------------------------------------------
  roc_obj <- roc(true_labels, pred_prob, quiet = TRUE)
  auc_val <- as.numeric(auc(roc_obj))

  plot_roc <- ggroc(roc_obj, color = "black") +
    geom_abline(intercept = 1, slope = 1, linetype = "dashed", color = "grey50") +
    annotate("text", x = 0.6, y = 0.2,
             label = paste("AUC =", round(auc_val, 2)), size = 5) +
    labs(title = paste(title_prefix, "- ROC Curve"),
         x = "1-specificity (False Positive Rate)",
         y = "Sensitivity (True Positive Rate)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"))

  # ---- Performance vs. cutoff -----------------------------------------------
  coords_df <- coords(roc_obj, "all",
                      ret = c("threshold", "sensitivity", "specificity"),
                      transpose = FALSE)

  n_pos <- sum(true_labels == 1)
  n_neg <- sum(true_labels == 0)
  coords_df <- coords_df %>%
    mutate(accuracy = (sensitivity * n_pos + specificity * n_neg) / (n_pos + n_neg))

  plot_data <- coords_df %>%
    select(threshold, sensitivity, specificity, accuracy) %>%
    pivot_longer(cols = c(sensitivity, specificity, accuracy),
                 names_to = "Metric", values_to = "Proportion")

  opt_cutoff <- coords(roc_obj, "best")$threshold

  plot_perf <- ggplot(plot_data, aes(x = threshold, y = Proportion,
                                     color = Metric, shape = Metric)) +
    geom_line(aes(linetype = Metric)) +
    geom_point() +
    scale_color_manual(values = c("accuracy"    = "blue",
                                  "sensitivity" = "green",
                                  "specificity" = "red")) +
    scale_shape_manual(values = c("accuracy"    = 17,
                                  "sensitivity" = 1,
                                  "specificity" = 1)) +
    geom_vline(xintercept = opt_cutoff, linetype = "dotted", color = "black") +
    annotate("text", x = opt_cutoff + 0.02, y = 0.1,
             label = round(opt_cutoff, 2), hjust = 0) +
    labs(title = paste(title_prefix, "- Performance vs. Cutoff"),
         x = "Probability Cutoff", y = "Classification Proportion") +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.position = "bottom")

  return(list(plot_roc = plot_roc, plot_perf = plot_perf))
}

# =============================================================================
# Run for all (AEHI x predictor set) combinations
# =============================================================================
final_plots <- list()

for (index_name in names(indices)) {
  for (set_name in names(predictor_sets)) {

    title <- paste(index_name, " (", set_name, ")", sep = "")

    cat("========================================================\n")
    cat("Generating plots for:", title, "\n")
    cat("========================================================\n")

    plots <- analyze_and_plot_rf(
      data           = ECO,
      response_var   = indices[[index_name]]$var,
      predictor_vars = predictor_sets[[set_name]],
      threshold      = indices[[index_name]]$threshold,
      title_prefix   = title
    )

    final_plots[[title]] <- plots
  }
}

# ---- Render all plots -------------------------------------------------------
for (plot_name in names(final_plots)) {
  if (!is.null(final_plots[[plot_name]])) {
    grid.arrange(
      final_plots[[plot_name]]$plot_roc,
      final_plots[[plot_name]]$plot_perf,
      ncol = 2,
      top = textGrob(plot_name, gp = gpar(fontsize = 16, fontface = "bold"))
    )
  }
}
