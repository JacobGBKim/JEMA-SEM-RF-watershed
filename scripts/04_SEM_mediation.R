# =============================================================================
# 04_SEM_mediation.R
# -----------------------------------------------------------------------------
# Purpose: Structural Equation Modeling (SEM) — mediation analysis
#          Test the central hypothesis that water quality partially mediates
#          the effect of landscape characteristics on aquatic ecosystem health.
#
#          Final model:
#            Landscape  =~ Forest + slope_mean + relief_mean + HI
#            WQ         =~ BOD + COD + TN + TP
#            Health     =~ TDI1618 + BMI1618 + FAI1618
#            WQ         ~  a * Landscape
#            Health     ~  b * WQ + c * Landscape
#            indirect   := a * b
#            total      := c + (a*b)
#            BOD ~~ COD                 # error covariance
#
# Manuscript section: 3.2 Hierarchical relationships (SEM portion)
#                     Table 1: standardized path coefficients
#                     Supplementary Figure S3: SEM diagram
#                     Supplementary Table S7: goodness-of-fit indices
#
# Inputs:
#   ../data_local/data_sem.csv     [restricted: AEHI scores included]
#     Required columns:
#       Forest, slope_mean, relief_mean, HI            (Landscape indicators)
#       BOD, COD, TN, TP                               (WQ indicators)
#       TDI1618, BMI1618, FAI1618                      (Health indicators)
#
# Outputs (R environment data frames):
#   fit_indices_df      : Model fit (chi^2, df, CFI, TLI, RMSEA, SRMR, ...)
#   loadings_table      : Factor loadings (measurement model)
#   structural_table    : Path coefficients (structural model)
#   effects_table       : Direct, indirect, total effects
#   r_squared_df        : R^2 values
#   plot_obj            : SEM path diagram
#
# Reproducibility:
#   - SEM is deterministic (lavaan default ML estimator)
#   - Expected results (manuscript Table 1, Section 3.2):
#       Direct (Landscape -> Health):     β = 0.425, p < 0.001
#       Indirect (Landscape -> WQ -> H):  β = 0.261, p = 0.004
#       Total:                             β = 0.686
#       CFI = 0.919, TLI = 0.889, SRMR = 0.077, RMSEA = 0.131
# =============================================================================

# ---- Load packages ----------------------------------------------------------
if (!require("lavaan"))     install.packages("lavaan")
if (!require("dplyr"))      install.packages("dplyr")
if (!require("lavaanPlot")) install.packages("lavaanPlot")

library(lavaan)
library(dplyr)
library(lavaanPlot)

cat("Final SEM analysis script (no semPlot dependency) is ready.\n")

# ---- Load and standardize data ---------------------------------------------
full_data <- read.csv("../data_local/data_sem.csv")

# z-score standardization for numeric columns
numeric_cols <- sapply(full_data, is.numeric)
scaled_data  <- as.data.frame(scale(full_data[, numeric_cols]))

cat("Data loaded and scaled successfully.\n")

# ---- Define the final SEM model --------------------------------------------
final_model_def <- '
  # 1. Measurement model
  Landscape =~ Forest + slope_mean + relief_mean + HI
  WQ        =~ BOD + COD + TN + TP
  Health    =~ TDI1618 + BMI1618 + FAI1618

  # 2. Structural model
  WQ     ~ a * Landscape
  Health ~ b * WQ + c * Landscape

  # 3. Effect decomposition
  indirect_effect := a * b
  total_effect    := c + (a*b)

  # 4. Error covariance
  BOD ~~ COD
'

cat("Final SEM model has been defined.\n")

# ---- Fit the model ----------------------------------------------------------
final_fit <- sem(final_model_def, data = scaled_data, std.lv = TRUE)

cat("\n\n--- SUMMARY OF THE FINAL MODEL ---\n")
summary(final_fit, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE)

# =============================================================================
# Generate publication-ready result tables
# =============================================================================

cat("\nGenerating result data frames in the R environment...\n")

# ---- Fit indices ------------------------------------------------------------
fit_indices <- fitMeasures(final_fit,
  c("chisq", "df", "pvalue", "cfi", "tli", "gfi", "agfi",
    "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr"))
fit_indices_df <- data.frame(Index = names(fit_indices), Value = fit_indices)

cmin_df <- fit_indices_df$Value[fit_indices_df$Index == "chisq"] /
           fit_indices_df$Value[fit_indices_df$Index == "df"]
fit_indices_df <- rbind(fit_indices_df,
                        data.frame(Index = "cmin/df", Value = cmin_df))
fit_indices_df$Value <- round(fit_indices_df$Value, 3)

# ---- Standardized parameter estimates --------------------------------------
params_df <- standardizedSolution(final_fit)

add_significance_stars <- function(p_value) {
  if (is.na(p_value)) return("")
  if (p_value < 0.001) return("***")
  if (p_value < 0.01)  return("**")
  if (p_value < 0.05)  return("*")
  return("")
}

params_df <- params_df %>%
  mutate(stars = sapply(pvalue, add_significance_stars))

# Measurement model (factor loadings)
loadings_table <- params_df %>%
  filter(op == "=~") %>%
  select(Latent_Factor = lhs, Indicator = rhs,
         B = est.std, SE = se, Z = z, p_value = pvalue, Sig = stars) %>%
  mutate_if(is.numeric, ~round(., 3))

# Structural model (path coefficients)
structural_table <- params_df %>%
  filter(op == "~") %>%
  select(To = lhs, From = rhs,
         B = est.std, SE = se, Z = z, p_value = pvalue, Sig = stars) %>%
  mutate_if(is.numeric, ~round(., 3))

# Indirect and total effects
effects_table <- params_df %>%
  filter(op == ":=") %>%
  select(Effect = label,
         B = est.std, SE = se, Z = z, p_value = pvalue, Sig = stars) %>%
  mutate_if(is.numeric, ~round(., 3))

# R-squared values
r_squared_values <- inspect(final_fit, "r2")
r_squared_df     <- data.frame(Variable = names(r_squared_values),
                               R_Squared = round(r_squared_values, 3))

cat("-> Result tables available in the R environment:\n")
cat("   - fit_indices_df    : Model fit indices\n")
cat("   - loadings_table    : Measurement model results\n")
cat("   - structural_table  : Structural model results\n")
cat("   - effects_table     : Indirect and total effects\n")
cat("   - r_squared_df      : R-squared values\n")

# =============================================================================
# Visualize the SEM path diagram
# =============================================================================

cat("\nGenerating path diagram (RStudio Plots pane)...\n")

plot_obj <- lavaanPlot(model = final_fit,
                       node_options  = list(shape = "box",
                                            fontname = "Helvetica"),
                       edge_options  = list(color = "black"),
                       coefs  = TRUE,
                       stand  = TRUE,
                       stars  = TRUE,
                       graph_options = list(rankdir = "LR"))

print(plot_obj)

cat("\nPath diagram has been displayed.\n")
cat("Analysis complete.\n")
