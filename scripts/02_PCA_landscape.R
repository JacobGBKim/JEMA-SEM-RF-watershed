# =============================================================================
# 02_PCA_landscape.R
# -----------------------------------------------------------------------------
# Purpose: Principal Component Analysis (PCA) of landscape configuration metrics
#          - Multicollinearity diagnosis via Variance Inflation Factor (VIF)
#          - Dimensionality reduction to two ecologically meaningful axes:
#              PC1 = Aggregation-connectivity
#              PC2 = Shape complexity
#
# Manuscript section: 3.2 Hierarchical relationships (PCA portion)
#                     Supplementary Table S6 (PCA factor loadings)
#
# Inputs:
#   ../data_local/ND2024_catch.csv    [restricted: contains AEHI scores]
#     Required columns (16 landscape configuration metrics):
#       ai_W, cohesion_W, contag_W, division_W, iji_W, lpi_W, lsi_W,
#       msidi_W, msiei_W, pafrac_W, pd_W, pladj_W, shdi_W, shei_W,
#       sidi_W, siei_W
#     (See ./data_examples/README_data_dictionary.md for definitions)
#
# Outputs:
#   ../data_local/landuse_data_with_pc_scores.csv  : Original data + PC1 (Aggregation),
#                                             PC2 (Diversity/Shape Complexity)
#   Plots: Scree plot, Variable contribution, Biplot
#
# Reproducibility:
#   - PCA is deterministic (no random sampling)
#   - Expected variance explained (manuscript Supplementary Table S6):
#       PC1 = 75.43%, PC2 = 10.78% (cumulative 86.21%)
#
# Note on minor variance discrepancies:
#   With the merged ND2024_catch.csv currently shipped in this repo, PC2
#   may report ~14.8% instead of 10.78% (PC1 stays ~75%). The difference
#   stems from a small number of catchments included after the merge step
#   that were filtered out in the manuscript-version dataset. The PC1
#   dominance and the ecological interpretation (PC1 = aggregation,
#   PC2 = shape complexity) are unaffected. To reproduce the manuscript
#   PC2 value exactly, restrict the input to the 195 catchments that
#   contain non-NA AEHI scores before running this script.
# =============================================================================

# ---- Load packages ----------------------------------------------------------
if (!require(tidyverse))  install.packages("tidyverse")
if (!require(FactoMineR)) install.packages("FactoMineR")
if (!require(factoextra)) install.packages("factoextra")
if (!require(car))        install.packages("car")

library(tidyverse)
library(FactoMineR)
library(factoextra)
library(car)

# ---- Load data --------------------------------------------------------------
landuse_data <- read.csv("../data_local/ND2024_catch.csv")

# ---- Select 16 landscape configuration metrics ------------------------------
config_vars <- c("ai_W", "cohesion_W", "contag_W", "division_W",
                 "iji_W", "lpi_W", "lsi_W",
                 "msidi_W", "msiei_W", "pafrac_W",
                 "pd_W", "pladj_W", "shdi_W", "shei_W", "sidi_W", "siei_W")

config_data <- landuse_data[, config_vars]

# ---- Multicollinearity check (VIF, diagnostic only) ------------------------
# Use a dummy response variable to compute VIF for predictor set.
# Note: Some landscape metrics are linear combinations of others (e.g.,
#       evenness = diversity / log(richness)), causing perfect collinearity.
#       VIF is reported for diagnostic purposes; PCA proceeds regardless.
set.seed(123)
dummy_response <- rnorm(nrow(config_data))
lm_model <- lm(dummy_response ~ ., data = config_data)

vif_threshold <- 5
high_vif_vars <- tryCatch({
  vif_values <- vif(lm_model)
  cat("VIF values (>", vif_threshold, "flagged):\n")
  print(vif_values)
  names(vif_values[vif_values > vif_threshold])
}, error = function(e) {
  cat("VIF could not be computed due to perfect collinearity among metrics.\n")
  cat("Aliased coefficients indicate ", e$message, "\n")
  cat("Proceeding with PCA, which handles collinearity by orthogonalization.\n")
  character(0)
})

cat("\nVariables flagged with VIF >", vif_threshold, ":\n",
    if(length(high_vif_vars)) high_vif_vars else "(none / undetermined)", "\n")

# Note: All 16 variables are retained for PCA; VIF is diagnostic only.

# ---- Prepare data for PCA ---------------------------------------------------
config_data <- landuse_data %>%
  select(all_of(config_vars)) %>%
  na.omit()

landuse_data_clean <- landuse_data[row.names(config_data), ]

# Standardize (z-score)
config_data_scaled <- scale(config_data)

# ---- Perform PCA ------------------------------------------------------------
pca_result <- PCA(config_data_scaled, graph = FALSE)

# Sign convention: flip variable coordinates so that PC1 reflects
# "aggregation/connectivity" with positive sign
pca_result$var$coord <- -pca_result$var$coord

# ---- Visualize --------------------------------------------------------------
# Scree plot
fviz_eig(pca_result, addlabels = TRUE)

# Variable contribution
fviz_contrib(pca_result, choice = "var", axes = 1:2, top = 16)

# Correlation circle
fviz_pca_var(pca_result, col.var = "contrib",
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
             repel = TRUE)

# Biplot
fviz_pca_biplot(pca_result,
                col.var = "contrib",
                gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
                repel = TRUE)

# ---- Extract PC scores ------------------------------------------------------
pc_scores <- as.data.frame(-pca_result$ind$coord[, 1:2])
names(pc_scores) <- c("Aggregation", "Diversity")  # PC1, PC2

landuse_data_with_pc <- cbind(landuse_data_clean, pc_scores)

# ---- Summary ----------------------------------------------------------------
summary(pca_result)
cat("\nOriginal rows:", nrow(landuse_data), "\n")
cat("Rows after NA removal:", nrow(landuse_data_clean), "\n")
cat("Rows removed:", nrow(landuse_data) - nrow(landuse_data_clean), "\n")

# ---- Export -----------------------------------------------------------------
write.csv(landuse_data_with_pc,
          "../data_local/landuse_data_with_pc_scores.csv", row.names = FALSE)
