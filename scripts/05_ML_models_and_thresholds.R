# =============================================================================
# 05_ML_models_and_thresholds.R
# -----------------------------------------------------------------------------
# Purpose: Machine learning model comparison + management threshold derivation
#          - Compare four ML algorithms (RF, BRT, SVM, LR) for classifying
#            "healthy" (>= Grade B) vs. "impaired" sites for TDI/BMI/FAI
#          - For each AEHI, fit three predictor sets:
#              A: Water Quality only
#              B: Landscape + Physiography only
#              ALL: Integrated (A + B)
#          - VIF diagnostic to handle multicollinearity
#          - SECTION 8: Derive Table 2 management thresholds = mean of WQ
#            variables across sites classified as "healthy" by the final RF
#            model (BOD ~ 1.10 mg/L, TP ~ 0.03 mg/L, ...)
#
# Manuscript section: 3.3 Random Forest-based Classification
#                     Supplementary Table S8 (RF performance)
#                     Supplementary Table S9 (4 ML model comparison)
#                     Table 2 (Water quality management thresholds)
#
# Inputs:
#   ../data_local/ND2024_catch.csv    [restricted: AEHI scores included]
#
# Outputs (R environment + console):
#   tdi_results, bmi_results, fai_results : per-AEHI list with metrics + plots
#   final_table4_with_mean                : Table 2 (WQ thresholds) reproduced
#
# Reproducibility:
#   - set.seed(123) globally
#   - 5-fold CV repeated 3 times; 80/20 train/test split
#   - Expected results (manuscript Section 3.3):
#       Integrated RF AUC: TDI=0.70, BMI=0.93, FAI=0.88
#       Optimal cutoff:    TDI=0.57, BMI=0.56, FAI=0.43
#       Table 2 means:     BOD ~ 1.10 mg/L; TP ~ 0.03 mg/L
# =============================================================================

# ---- Load packages ----------------------------------------------------------
library(dplyr)
library(caret)
library(gbm)
library(kernlab)
library(ranger)
library(pROC)
library(ggplot2)
library(readr)
library(doParallel)
library(car)
library(stringr)
library(tidyr)

# ---- Parallel processing ----------------------------------------------------
cl <- makeCluster(detectCores() - 1)
registerDoParallel(cl)
clusterEvalQ(cl, { library(pROC) })

# Reproducibility
set.seed(123)

# =============================================================================
# 2. Variable definitions
# =============================================================================
ECO <- read.csv("../data_local/ND2024_catch.csv", fileEncoding = "euc-kr")

Response <- c("TDI1618", "FAI1618", "BMI1618")

# Full predictor sets (before VIF screening)
vars_A_full <- c("temp2", "pH2", "EC2", "DO2", "BOD2", "COD2", "SS2",
                 "TOC2", "TN2", "TP2",
                 "NP_BOD2020_Control2", "NP_TP2020_Control2")
vars_B_full <- c("slope_mean", "relief_mean", "TWI_mean", "HI",
                 "Aggregation_W", "Complexity_W",
                 "Agri", "Forest", "Grass", "Wet", "Bare", "Water")
vars_ALL_full <- c(vars_A_full, vars_B_full)

# =============================================================================
# 3. Helper functions
# =============================================================================
prepare_binary_data <- function(data, response_var, predictors, threshold) {
  df <- data %>%
    dplyr::select(all_of(c(response_var, predictors))) %>%
    na.omit()
  df$label <- ifelse(df[[response_var]] >= threshold, "pos", "neg")
  df$label <- factor(df$label, levels = c("neg", "pos"))
  df <- df %>% dplyr::select(-all_of(response_var))
  return(df)
}

ctrl <- trainControl(
  method = "repeatedcv", number = 5, repeats = 3,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final", allowParallel = TRUE
)

train_and_evaluate <- function(df, method) {
  idx <- createDataPartition(df$label, p = 0.8, list = FALSE)
  train_df <- df[idx, , drop = FALSE]
  test_df  <- df[-idx, , drop = FALSE]

  set.seed(123)
  train_params <- list(
    label ~ ., data = train_df, method = method,
    metric = "ROC", trControl = ctrl,
    preProcess = c("center", "scale"), tuneLength = 10
  )
  if (method == "ranger") train_params$importance <- "permutation"

  fit   <- do.call(caret::train, train_params)
  probs <- predict(fit, newdata = test_df, type = "prob")[, "pos"]
  obs   <- test_df$label

  roc_obj <- pROC::roc(obs, probs, levels = c("neg", "pos"), quiet = TRUE)
  best_coords <- pROC::coords(roc_obj, "best",
                              best.method = "closest.topleft",
                              ret = c("threshold", "sensitivity",
                                      "specificity", "accuracy"))
  list(model = fit, obs = obs, probs = probs,
       AUC = as.numeric(pROC::auc(roc_obj)),
       Cutoff = best_coords$threshold,
       Sensitivity = best_coords$sensitivity,
       Specificity = best_coords$specificity,
       Accuracy = best_coords$accuracy)
}

compare_models_for_set <- function(data, response_var, predictors, threshold) {
  df <- prepare_binary_data(data, response_var, predictors, threshold)

  model_results <- list(
    LR  = train_and_evaluate(df, method = "glm"),
    BRT = train_and_evaluate(df, method = "gbm"),
    SVM = train_and_evaluate(df, method = "svmRadial"),
    RF  = train_and_evaluate(df, method = "ranger")
  )

  metrics_df <- tibble::tibble(
    Model       = names(model_results),
    AUC         = sapply(model_results, `[[`, "AUC"),
    Cutoff      = sapply(model_results, `[[`, "Cutoff"),
    Sensitivity = sapply(model_results, `[[`, "Sensitivity"),
    Specificity = sapply(model_results, `[[`, "Specificity"),
    Accuracy    = sapply(model_results, `[[`, "Accuracy")
  )

  list(metrics = metrics_df, model_outputs = model_results)
}

# =============================================================================
# 4. Main wrapper
# =============================================================================
run_model_comparison <- function(data, response_var, threshold,
                                 predictors_A, predictors_B, predictors_ALL) {

  cat("========================================================\n")
  cat("Running comparison for:", response_var,
      "with threshold:", threshold, "\n")
  cat("========================================================\n\n")

  res_A_list   <- compare_models_for_set(data, response_var, predictors_A,   threshold)
  res_B_list   <- compare_models_for_set(data, response_var, predictors_B,   threshold)
  res_ALL_list <- compare_models_for_set(data, response_var, predictors_ALL, threshold)

  results_df <- dplyr::bind_rows(
    res_A_list$metrics   %>% mutate(Set = "A (Water-only)"),
    res_B_list$metrics   %>% mutate(Set = "B (Landscape-only)"),
    res_ALL_list$metrics %>% mutate(Set = "ALL (Integrated)")
  ) %>%
    dplyr::select(Set, Model, AUC, Cutoff, Sensitivity, Specificity, Accuracy) %>%
    dplyr::arrange(Set, dplyr::desc(AUC))

  plot_auc <- ggplot(results_df, aes(x = Model, y = AUC, fill = Set)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    geom_text(aes(label = round(AUC, 3)), vjust = -0.5,
              position = position_dodge(width = 0.8), size = 3) +
    coord_cartesian(ylim = c(0.5, 1)) + theme_minimal(base_size = 12) +
    labs(title = paste("AUC Comparison for", response_var),
         x = "ML Model", y = "AUC")

  list(
    results_table  = results_df,
    plot_auc       = plot_auc,
    final_rf_model = res_ALL_list$model_outputs$RF$model
  )
}

# =============================================================================
# 5. VIF diagnostic and final variable selection
# =============================================================================
cat("\n--- VIF diagnostic for the 'ALL' variable group ---\n")

vif_data <- ECO %>%
  dplyr::select(all_of(vars_ALL_full)) %>%
  na.omit()

if (nrow(vif_data) > 0 && length(vars_ALL_full) > 1) {

  vif_model <- lm(paste0(vars_ALL_full[1], " ~ ."), data = vif_data)
  aliased_coeffs <- names(coef(vif_model)[is.na(coef(vif_model))])

  # High-VIF variables identified in iterative analysis
  high_vif_vars <- c("NP_BOD2020_Control2", "NP_TP2020_Control2",
                     "slope_mean", "TWI_mean")

  vars_to_remove <- unique(c(aliased_coeffs, high_vif_vars))
  vars_ALL_final <- setdiff(vars_ALL_full, vars_to_remove)

  cat("\nVariables removed for multicollinearity:\n")
  print(vars_to_remove)

  vif_model_final  <- lm(paste0(vars_ALL_final[1], " ~ ."),
                         data = vif_data[, vars_ALL_final])
  vif_values_final <- car::vif(vif_model_final)

  cat("\nFinal VIF values:\n")
  print(vif_values_final)

} else {
  cat("Not enough data to calculate VIF.\n")
  vars_to_remove <- character(0)
  vars_ALL_final <- vars_ALL_full
}
cat("--- VIF diagnostic complete ---\n\n")

vars_A_final <- setdiff(vars_A_full, vars_to_remove)
vars_B_final <- setdiff(vars_B_full, vars_to_remove)

# =============================================================================
# 6. Run analysis for each AEHI
# =============================================================================
tdi_results <- run_model_comparison(ECO, "TDI1618", 70,
                                    vars_A_final, vars_B_final, vars_ALL_final)
fai_results <- run_model_comparison(ECO, "FAI1618", 60,
                                    vars_A_final, vars_B_final, vars_ALL_final)
bmi_results <- run_model_comparison(ECO, "BMI1618", 65,
                                    vars_A_final, vars_B_final, vars_ALL_final)

# =============================================================================
# 7. Print performance tables  (matches Supplementary Table S9)
# =============================================================================
cat("\n\n--- [TDI] Detailed performance ---\n"); print(tdi_results$results_table)
cat("\n\n--- [FAI] Detailed performance ---\n"); print(fai_results$results_table)
cat("\n\n--- [BMI] Detailed performance ---\n"); print(bmi_results$results_table)

# =============================================================================
# 8. Derive Table 2 management thresholds
#    (mean of WQ variables across sites classified as "healthy" by the
#     final integrated RF model)
# =============================================================================

recalculate_thresholds <- function(model_result_object, original_data,
                                   final_predictors) {

  final_model <- model_result_object$final_rf_model

  optimal_cutoff <- model_result_object$results_table %>%
    filter(Set == "ALL (Integrated)" & Model == "RF") %>%
    pull(Cutoff)

  data_to_predict <- original_data %>%
    select(all_of(final_predictors)) %>%
    na.omit()

  original_indices <- as.numeric(rownames(data_to_predict))
  predictions_prob <- predict(final_model,
                              newdata = data_to_predict,
                              type = "prob")$pos

  healthy_indices    <- original_indices[predictions_prob >= optimal_cutoff]
  healthy_sites_data <- original_data[healthy_indices, ]

  response_var_name <- model_result_object$plot_auc$labels$title %>%
    str_extract("TDI1618|FAI1618|BMI1618")
  cat(paste("\n[", response_var_name, "] N healthy sites:",
            nrow(healthy_sites_data), "\n"))

  wq_vars_table <- c("DO2", "BOD2", "COD2", "SS2", "TOC2", "TP2")
  wq_vars_to_summarise <- intersect(wq_vars_table, names(original_data))

  threshold_table <- healthy_sites_data %>%
    summarise(across(all_of(wq_vars_to_summarise),
                     .fns = list(mean = mean), na.rm = TRUE)) %>%
    tidyr::pivot_longer(everything(), names_to = "Variable",
                        values_to = "Threshold") %>%
    mutate(Variable = toupper(gsub("_mean|_|2", "", Variable)))

  return(threshold_table)
}

tdi_thresholds <- recalculate_thresholds(tdi_results, ECO, vars_ALL_final)
fai_thresholds <- recalculate_thresholds(fai_results, ECO, vars_ALL_final)
bmi_thresholds <- recalculate_thresholds(bmi_results, ECO, vars_ALL_final)

final_table2 <- tdi_thresholds %>% rename(TDI_Threshold = Threshold) %>%
  left_join(fai_thresholds %>% rename(FAI_Threshold = Threshold), by = "Variable") %>%
  left_join(bmi_thresholds %>% rename(BMI_Threshold = Threshold), by = "Variable")

final_table2_with_mean <- final_table2 %>%
  rowwise() %>%
  mutate(
    Mean_Threshold = mean(c(TDI_Threshold, FAI_Threshold, BMI_Threshold), na.rm = TRUE),
    SD_Threshold   = sd  (c(TDI_Threshold, FAI_Threshold, BMI_Threshold), na.rm = TRUE)
  )

cat("\n\n--- Reproduced Table 2 (Water quality management thresholds) ---\n")
print(final_table2_with_mean)

# Stop parallel cluster
stopCluster(cl)
