# =============================================================================
# 07_RF_PDP_figureS4.R
# -----------------------------------------------------------------------------
# Purpose: Random Forest with Partial Dependence Plots (PDP)
#          Provides:
#            - RF model with cross-validation, OOB error, and AUC reporting
#            - Variable importance ranking
#            - Partial Dependence Plots (PDP) for top-N variables
#              (corresponds to Supplementary Figure S4)
#
# Manuscript section: 3.3 Random Forest classification
#                     Supplementary Figure S4 (PDP for BMI/BOD, FAI/Temp,
#                     TDI/Aggregation Index, etc.)
#
# Inputs:
#   ../data_local/ND2024_catch_206.csv  [restricted: AEHI included; NA-removed subset]
#
# Outputs:
#   PDFs (saved to current working directory):
#     - TDI_EnhancedAnalysis.pdf, TDI_PartialDependencePlots.pdf
#     - BMI_EnhancedAnalysis.pdf, BMI_PartialDependencePlots.pdf
#     - FAI_EnhancedAnalysis.pdf, FAI_PartialDependencePlots.pdf
#   CSVs:
#     - Table3_Enhanced_Performance.csv
#     - TableS6_CV_Results.csv
#     - {TDI,BMI,FAI}_performance_enhanced.csv
#     - {TDI,BMI,FAI}_importance_enhanced.csv
#   RDS (R serialized objects for reuse):
#     - {TDI,BMI,FAI}_enhanced_results.rds
#
# Reproducibility:
#   - set.seed(123) inside model fitting
#   - 5-fold CV; tuneGrid over mtry x min.node.size
#   - Expected results match Section 3.3 (AUC, CV-ROC, OOB Error)
# =============================================================================

# ---- Load packages ----------------------------------------------------------
library(tidyverse)
library(ranger)
library(caret)
library(ROCR)
library(vegan)
library(ggrepel)
library(pdp)         # Partial dependence plots
library(gridExtra)

# ============================================================================
# Function 1: PCA with detailed reporting
# ============================================================================
perform_pca_with_details <- function(data, config_vars) {
  data_scaled <- scale(data[, config_vars])
  pca_result <- prcomp(data_scaled, center = FALSE, scale. = FALSE)

  eigenvalues       <- pca_result$sdev^2
  var_explained     <- eigenvalues / sum(eigenvalues) * 100
  cumvar_explained  <- cumsum(var_explained)

  pca_summary <- data.frame(
    PC                  = paste0("PC", 1:length(eigenvalues)),
    Eigenvalue          = eigenvalues,
    Variance_Explained  = var_explained,
    Cumulative_Variance = cumvar_explained
  )

  loadings           <- as.data.frame(pca_result$rotation[, 1:2])
  loadings$Variable  <- rownames(loadings)
  pc_scores          <- as.data.frame(pca_result$x[, 1:2])

  cat("\n=== PCA Summary ===\n")
  print(pca_summary[1:5, ])
  cat(sprintf("\nPC1 explains %.1f%% of variance\n", var_explained[1]))
  cat(sprintf("PC2 explains %.1f%% of variance\n",   var_explained[2]))
  cat(sprintf("Total variance (PC1+PC2): %.1f%%\n",  cumvar_explained[2]))

  list(pca_result    = pca_result,
       summary       = pca_summary,
       loadings      = loadings,
       scores        = pc_scores,
       var_explained = var_explained)
}

# ============================================================================
# Function 2: RF with full validation metrics (CV, OOB, AUC)
# ============================================================================
create_rf_model_enhanced <- function(response_var, predictor_vars, data) {
  set.seed(123)

  model_data <- data[, c(response_var, predictor_vars)]
  cat("\nData summary before NA removal:\n")
  cat("Total rows:", nrow(model_data), "\n")
  cat(response_var, "distribution:\n")
  print(table(model_data[[response_var]], useNA = "ifany"))

  model_data <- na.omit(model_data)

  model_data[[response_var]] <- factor(model_data[[response_var]],
                                       levels = c(0, 1),
                                       labels = c("class0", "class1"))

  train_index <- createDataPartition(model_data[[response_var]],
                                     p = 0.7, list = FALSE)
  train_data  <- model_data[train_index, ]
  test_data   <- model_data[-train_index, ]

  tune_grid <- expand.grid(
    mtry          = seq(floor(sqrt(length(predictor_vars))),
                         length(predictor_vars), by = 2),
    splitrule     = "gini",
    min.node.size = c(1, 3, 5)
  )

  ctrl <- trainControl(
    method          = "cv", number = 5,
    classProbs      = TRUE,
    summaryFunction = twoClassSummary,
    savePredictions = "final",
    returnResamp    = "all"
  )

  rf_model <- train(
    as.formula(paste(response_var, "~ .")),
    data       = train_data,
    method     = "ranger",
    num.trees  = 1000,
    tuneGrid   = tune_grid,
    trControl  = ctrl,
    metric     = "ROC",
    importance = "permutation"
  )

  cat("\n=== Cross-Validation Results ===\n")
  cat("Best parameters:\n"); print(rf_model$bestTune)
  cv_results <- rf_model$results[
    rf_model$results$mtry          == rf_model$bestTune$mtry &
    rf_model$results$min.node.size == rf_model$bestTune$min.node.size, ]
  cat(sprintf("CV ROC: %.3f +/- %.3f\n", cv_results$ROC,  cv_results$ROCSD))
  cat(sprintf("CV Sens: %.3f +/- %.3f\n", cv_results$Sens, cv_results$SensSD))
  cat(sprintf("CV Spec: %.3f +/- %.3f\n", cv_results$Spec, cv_results$SpecSD))

  # OOB error via direct ranger fit
  final_rf <- ranger(
    as.formula(paste(response_var, "~ .")),
    data            = train_data,
    num.trees       = 1000,
    mtry            = rf_model$bestTune$mtry,
    min.node.size   = rf_model$bestTune$min.node.size,
    splitrule       = "gini",
    probability     = TRUE,
    importance      = "permutation"
  )
  cat(sprintf("\nOOB prediction error: %.3f\n", final_rf$prediction.error))

  # Test set predictions
  pred_probs <- predict(rf_model, test_data, type = "prob")

  pred  <- prediction(pred_probs[, "class1"],
                      ifelse(test_data[[response_var]] == "class1", 1, 0))
  perf  <- performance(pred, "tpr", "fpr")
  auc   <- performance(pred, "auc")@y.values[[1]]

  cutoffs <- seq(0, 1, by = 0.05)
  performance_metrics <- data.frame(cutoff = cutoffs,
                                    sensitivity = NA,
                                    specificity = NA,
                                    accuracy    = NA)
  for (i in seq_along(cutoffs)) {
    pred_class <- factor(ifelse(pred_probs[, "class1"] > cutoffs[i],
                                "class1", "class0"),
                         levels = c("class0", "class1"))
    cm <- confusionMatrix(pred_class, test_data[[response_var]])
    performance_metrics$sensitivity[i] <- cm$byClass["Sensitivity"]
    performance_metrics$specificity[i] <- cm$byClass["Specificity"]
    performance_metrics$accuracy[i]    <- cm$overall["Accuracy"]
  }

  optimal_idx    <- which.min(abs(performance_metrics$sensitivity -
                                  performance_metrics$specificity))
  optimal_cutoff <- cutoffs[optimal_idx]

  par(mfrow = c(1, 2))
  plot(perf, main = "A",
       xlab = "False-positive rate (1-specificity)",
       ylab = "True-positive rate (sensitivity)")
  abline(0, 1, lty = 2, col = "gray")
  text(0.6, 0.2, paste("AUC =", round(auc, 2)))
  points(1 - performance_metrics$specificity[optimal_idx],
         performance_metrics$sensitivity[optimal_idx],
         col = "red", pch = 19)

  plot(performance_metrics$cutoff, performance_metrics$sensitivity,
       type = "b", col = "red", pch = 15, main = "B",
       xlab = "Cutoff", ylab = "Classification proportion",
       ylim = c(0, 1))
  lines(performance_metrics$cutoff, performance_metrics$specificity,
        type = "b", col = "green", pch = 16)
  lines(performance_metrics$cutoff, performance_metrics$accuracy,
        type = "b", col = "blue",  pch = 17)
  abline(v = optimal_cutoff, lty = 2, col = "gray")
  legend("topright", legend = c("Sensitivity", "Accuracy", "Specificity"),
         col = c("red", "blue", "green"), pch = c(15, 17, 16), lty = 1)

  list(
    performance = data.frame(
      Response_Variable = response_var,
      AUC               = auc,
      Optimal_Cutoff    = optimal_cutoff,
      Sensitivity       = performance_metrics$sensitivity[optimal_idx],
      Specificity       = performance_metrics$specificity[optimal_idx],
      Accuracy          = performance_metrics$accuracy[optimal_idx],
      CV_ROC            = cv_results$ROC,
      CV_ROC_SD         = cv_results$ROCSD,
      OOB_Error         = final_rf$prediction.error
    ),
    model              = rf_model,
    final_rf           = final_rf,
    predictor_vars     = predictor_vars,
    cv_results         = rf_model$resample,
    performance_metrics = performance_metrics
  )
}

# ============================================================================
# Function 3: Partial Dependence Plots (Figure S4)
# ============================================================================
create_partial_dependence_plots <- function(model_results, response_name,
                                            top_n = 6) {
  cat(sprintf("\n=== PDP for %s ===\n", response_name))

  var_imp <- varImp(model_results$model)$importance
  var_imp$Variable <- rownames(var_imp)
  var_imp <- var_imp %>% arrange(desc(Overall))

  top_vars <- head(var_imp$Variable, top_n)
  cat("Creating PDP for top", top_n, "variables:\n"); print(top_vars)

  pd_plots <- list()
  for (var in top_vars) {
    cat("  Processing:", var, "\n")
    pd_data <- partial(model_results$model,
                       pred.var    = var,
                       prob        = TRUE,
                       which.class = "class1",
                       train       = model_results$model$trainingData)

    p <- ggplot(pd_data, aes_string(x = var, y = "yhat")) +
      geom_line(color = "steelblue", size = 1.2) +
      geom_rug(sides = "b", alpha = 0.3) +
      labs(title = var, x = var,
           y = "Predicted Probability\n(Healthy Status)") +
      theme_minimal() +
      theme(plot.title = element_text(face = "bold", size = 10))

    pd_plots[[var]] <- p
  }

  combined <- do.call(grid.arrange, c(pd_plots, ncol = 3))
  list(plots = pd_plots, combined = combined, top_variables = top_vars)
}

# ============================================================================
# Function 4: Comprehensive diagnostics
# ============================================================================
generate_model_diagnostics <- function(model_results, response_name) {
  cat(sprintf("\n=== Diagnostics for %s ===\n", response_name))

  var_imp <- varImp(model_results$model)$importance
  var_imp$Variable <- rownames(var_imp)
  var_imp <- var_imp %>% arrange(desc(Overall))
  cat("\nTop 10 variables:\n"); print(head(var_imp, 10))

  cv_results <- model_results$cv_results
  cat(sprintf("\nMean CV ROC: %.3f (SD %.3f)\n",
              mean(cv_results$ROC), sd(cv_results$ROC)))
  cat(sprintf("OOB Error: %.3f\n", model_results$performance$OOB_Error))
  cat(sprintf("Test AUC: %.3f, Sens: %.3f, Spec: %.3f, Acc: %.3f\n",
              model_results$performance$AUC,
              model_results$performance$Sensitivity,
              model_results$performance$Specificity,
              model_results$performance$Accuracy))

  list(variable_importance = var_imp,
       cv_summary  = cv_results,
       performance = model_results$performance)
}

# =============================================================================
# Main execution
# =============================================================================

# ---- Load data --------------------------------------------------------------
ECO <- read.csv("../data_local/ND2024_catch_206.csv", fileEncoding = "euc-kr")
cat("Total observations:", nrow(ECO), "\n")

# ---- Create binary response variables ---------------------------------------
ECO$TDI_bi <- factor(ifelse(ECO$TDI1618 > 70, 1, 0), levels = c(0, 1))
ECO$BMI_bi <- factor(ifelse(ECO$BMI1618 > 65, 1, 0), levels = c(0, 1))
ECO$FAI_bi <- factor(ifelse(ECO$FAI1618 > 60, 1, 0), levels = c(0, 1))

# ---- Predictor list ---------------------------------------------------------
water_quality           <- c("temp2", "pH2", "EC2", "DO2", "BOD2", "COD2",
                             "SS2", "TOC2", "TN2", "TP2",
                             "NP_BOD2020_Control2", "NP_TP2020_Control2")
physiography            <- c("slope_mean", "relief_mean", "TWI_mean", "HI")
landscape_composition   <- c("Agri", "Forest", "Grass", "Wet", "Bare",
                             "Water", "Urban")
landscape_configuration <- c("Aggregation_W", "Complexity_W")

all_predictors <- c(water_quality, physiography,
                    landscape_composition, landscape_configuration)

# ---- Run analysis for each AEHI ---------------------------------------------
for (idx_name in c("TDI", "BMI", "FAI")) {
  cat(sprintf("\n========== %s analysis ==========\n", idx_name))

  response_bi <- paste0(idx_name, "_bi")

  pdf(paste0(idx_name, "_EnhancedAnalysis.pdf"), width = 12, height = 8)
  results <- create_rf_model_enhanced(response_bi, all_predictors, ECO)
  dev.off()

  diagnostics <- generate_model_diagnostics(results, idx_name)

  pdf(paste0(idx_name, "_PartialDependencePlots.pdf"), width = 12, height = 8)
  pdp_obj <- create_partial_dependence_plots(results, idx_name, top_n = 6)
  dev.off()

  saveRDS(results, paste0(idx_name, "_enhanced_results.rds"))
  write.csv(results$performance,
            paste0(idx_name, "_performance_enhanced.csv"), row.names = FALSE)
  write.csv(diagnostics$variable_importance,
            paste0(idx_name, "_importance_enhanced.csv"), row.names = FALSE)
  write.csv(diagnostics$cv_summary,
            paste0(idx_name, "_CV_results.csv"), row.names = FALSE)

  assign(paste0("results_", idx_name, "_enhanced"), results)
  assign(paste0("diagnostics_", idx_name),          diagnostics)
}

# ---- Combined summary tables ------------------------------------------------
performance_summary <- rbind(
  data.frame(Index = "TDI", results_TDI_enhanced$performance),
  data.frame(Index = "BMI", results_BMI_enhanced$performance),
  data.frame(Index = "FAI", results_FAI_enhanced$performance)
)
write.csv(performance_summary, "Table3_Enhanced_Performance.csv",
          row.names = FALSE)

cv_summary <- rbind(
  data.frame(Index = "TDI", results_TDI_enhanced$cv_results),
  data.frame(Index = "BMI", results_BMI_enhanced$cv_results),
  data.frame(Index = "FAI", results_FAI_enhanced$cv_results)
)
write.csv(cv_summary, "TableS6_CV_Results.csv", row.names = FALSE)

cat("\n\n========== Summary ==========\n")
print(performance_summary)

for (idx in c("TDI", "BMI", "FAI")) {
  cv_data <- cv_summary[cv_summary$Index == idx, ]
  cat(sprintf("\n%s: CV-ROC = %.3f +/- %.3f\n",
              idx, mean(cv_data$ROC), sd(cv_data$ROC)))
}

cat("\nAnalysis complete.\n")
