# =============================================================================
# 03_RDA_VP.R
# -----------------------------------------------------------------------------
# Purpose: Redundancy Analysis (RDA) + Variance Partitioning (VP)
#          - 3-stage RDA examining hierarchical landscape -> water quality
#            -> aquatic ecosystem health pathways (Figure 4 in manuscript)
#          - Variance Partitioning to quantify unique vs. shared effects
#            of landscape and water quality variables on AEHIs (Figure 3)
#
# Manuscript section: 3.2 Hierarchical relationships
#                     Figure 3 (VP), Figure 4 (RDA biplots)
#
# Inputs:
#   ../data_local/ND2024_catch.csv    [restricted: contains AEHI scores]
#     Required columns:
#       Response: TDI1618, FAI1618, BMI1618
#       Water quality (catchment-mean):
#         temp2, pH2, EC2, DO2, BOD2, COD2, SS2, TOC2, TN2, TP2,
#         NP_BOD2020_Control2, NP_TP2020_Control2
#       Physiography:
#         slope_mean, relief_mean, TWI_mean, HI
#       Landscape composition:
#         Aggregation_W, Complexity_W, Agri, Forest, Grass, Wet,
#         Bare, Water, Urban
#
# Outputs:
#   - Console: RDA summary, eigenvalues, axis loadings
#   - Console: Variance Partitioning result (unique [a], [b], shared [c])
#   - Plots: RDA biplots (corresponds to Figure 4a, 4b, 4c)
#   - Plot: Venn-diagram-style VP visualization
#
# Reproducibility:
#   - RDA and VP are deterministic
#   - Expected results (manuscript Section 3.2):
#       RDA1 (Landscape -> WQ): 48.4%; RDA2: 10.4%
#       Total variance explained in AEHIs: 47.4%
#       Landscape unique [a]: 8.0%
#       Water quality unique [b]: 1.3%
#       Shared [c]: 38.1%
# =============================================================================

# ---- Load packages ----------------------------------------------------------
library(dplyr)
library(vegan)
library(ggplot2)
library(ggrepel)

# ---- Load data --------------------------------------------------------------
ECO <- read.csv("../data_local/ND2024_catch.csv", fileEncoding = "euc-kr")

# ---- Variable groups --------------------------------------------------------
Response          <- c("TDI1618", "FAI1618", "BMI1618")

water_quality_vars <- c("temp2", "pH2", "EC2", "DO2", "BOD2", "COD2", "SS2",
                        "TOC2", "TN2", "TP2",
                        "NP_BOD2020_Control2", "NP_TP2020_Control2")
physiography_vars  <- c("slope_mean", "relief_mean", "TWI_mean", "HI")
landscape_vars     <- c("Aggregation_W", "Complexity_W", "Agri", "Forest",
                        "Grass", "Wet", "Bare", "Water", "Urban")

# =============================================================================
# Part A: RDA biplots (Figure 4)
# =============================================================================

# ---- Prepare clean data -----------------------------------------------------
response_data <- ECO[, Response]
env_data      <- ECO[, c(physiography_vars, landscape_vars)]

complete_cases <- complete.cases(response_data, env_data)
response_clean <- response_data[complete_cases, ]
env_clean      <- env_data[complete_cases, ]

# Standardize
response_scaled <- scale(response_clean)
env_scaled      <- scale(env_clean)

# ---- Perform RDA ------------------------------------------------------------
rda_result <- rda(response_scaled ~ ., data = as.data.frame(env_scaled))

cat("\n--- RDA Summary ---\n")
print(summary(rda_result))

# Eigenvalues (variance explained per axis)
eigenvals <- summary(rda_result)$cont$importance[2, ]
axis_labels <- paste0("RDA", 1:2,
                      " (", round(eigenvals[1:2] * 100, 1), "%)")

# ---- Extract scores for biplot ----------------------------------------------
site_scores    <- as.data.frame(scores(rda_result, display = "sites",   scaling = 2))
species_scores <- as.data.frame(scores(rda_result, display = "species", scaling = 2))
env_scores     <- as.data.frame(scores(rda_result, display = "bp",      scaling = 2))

# ---- Biplot -----------------------------------------------------------------
p_rda <- ggplot() +
  geom_segment(data = env_scores,
               aes(x = 0, y = 0, xend = RDA1, yend = RDA2),
               color = "blue", arrow = arrow(length = unit(0.2, "cm"))) +
  geom_text_repel(data = env_scores,
                  aes(x = RDA1, y = RDA2, label = rownames(env_scores)),
                  color = "blue", size = 3) +
  geom_segment(data = species_scores,
               aes(x = 0, y = 0, xend = RDA1, yend = RDA2),
               color = "red", arrow = arrow(length = unit(0.2, "cm"))) +
  geom_text_repel(data = species_scores,
                  aes(x = RDA1, y = RDA2, label = rownames(species_scores)),
                  color = "red", size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey70") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey70") +
  coord_fixed(ratio = 1) +
  labs(x = axis_labels[1], y = axis_labels[2],
       title = "RDA Biplot (Landscape -> AEHIs, Scaling 2)") +
  theme_minimal()

print(p_rda)

# Note: Figure 4 in the manuscript shows three RDA biplots from three separate
# RDAs:
#   (a) Landscape characteristics -> Water quality parameters
#   (b) Landscape characteristics -> AEHIs
#   (c) Water quality parameters  -> AEHIs
# To reproduce panels (a) and (c), substitute response_data and env_data
# accordingly (same RDA call, different variable groups).

# =============================================================================
# Part B: Variance Partitioning (Figure 3)
# =============================================================================

# ---- Prepare clean data with all groups -------------------------------------
vars_all <- c(Response, water_quality_vars, physiography_vars, landscape_vars)
ECO_clean <- na.omit(ECO[, vars_all])

wq_data   <- scale(ECO_clean[, water_quality_vars])
phys_data <- scale(ECO_clean[, physiography_vars])
land_data <- scale(ECO_clean[, landscape_vars])
resp_data <- scale(ECO_clean[, Response])

# ---- 3-group VP: WQ vs Physiography vs Landscape ---------------------------
vp_3 <- varpart(resp_data,
                wq_data,    # X1: Water Quality
                phys_data,  # X2: Physiography
                land_data)  # X3: Landscape composition
cat("\n--- VP: 3 groups (WQ / Physiography / Landscape) ---\n")
print(vp_3)
plot(vp_3,
     Xnames = c("Water Quality", "Physiography", "Landscape"),
     bg = c("skyblue", "pink", "lightgreen"))

# ---- 2-group VP: WQ vs Landscape (matches Figure 3 in manuscript) ----------
# Note: For Figure 3, we combine physiography + landscape composition into a
# single "Landscape characteristics" group, following the manuscript design.
landchar_data <- cbind(phys_data, land_data)

vp_2 <- varpart(resp_data,
                landchar_data,  # X1: All Landscape characteristics
                wq_data)        # X2: Water Quality
cat("\n--- VP: 2 groups (Landscape characteristics / WQ) ---\n")
cat("    Expected: [a] Landscape unique = 8.0%,\n",
    "             [b] WQ unique = 1.3%,\n",
    "             [c] Shared = 38.1%,\n",
    "             Total explained = 47.4%\n")
print(vp_2)
plot(vp_2,
     Xnames = c("Landscape characteristics", "Water Quality"),
     bg = c("lightgreen", "skyblue"))

# ---- Significance test for unique effects -----------------------------------
rda_land <- rda(resp_data ~ . + Condition(wq_data),
                data = as.data.frame(landchar_data))
rda_wq   <- rda(resp_data ~ . + Condition(landchar_data),
                data = as.data.frame(wq_data))

cat("\n--- Significance test: unique Landscape effect ---\n")
print(anova(rda_land))

cat("\n--- Significance test: unique Water Quality effect ---\n")
print(anova(rda_wq))
