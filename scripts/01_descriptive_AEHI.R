# =============================================================================
# 01_descriptive_AEHI.R
# -----------------------------------------------------------------------------
# Purpose: Descriptive analysis of Aquatic Ecosystem Health Indices (AEHIs)
#          - Seasonal comparison (dry vs. wet) via Mann-Whitney U test
#          - Mainstream vs. tributary comparison
#          - Boxplot generation (corresponds to Supplementary Figure S1)
#
# Manuscript section: 3.1 Spatiotemporal Characteristics of AEHIs
#
# Inputs:
#   ../data_local/ND2024_raw.csv     [restricted: AEHI from NIER]
#     Required columns:
#       SBSNCD                            : Sub-basin code (catchment ID)
#       TDI1618{wet,dry}, BMI1618{wet,dry}, FAI1618{wet,dry} : AEHI scores
#       TDI1618, BMI1618, FAI1618         : Annual mean AEHIs
#       Stream                            : "mainstream" or "tributary"
#
# Outputs (rendered to RStudio Plots pane):
#   - Boxplot: TDI/BMI/FAI between Dry vs. Wet seasons
#   - Boxplot: TDI/BMI/FAI between Mainstream vs. Tributary
#   - Console: Mann-Whitney U test p-values (bonferroni-adjusted)
#
# Reproducibility:
#   - All tests are deterministic (no random sampling)
#   - Expected p-values match Section 3.1: TDI dry/wet p < 0.01;
#     BMI/FAI dry/wet p > 0.05; mainstem/tributary all p < 0.05
# =============================================================================

# ---- Load packages ----------------------------------------------------------
library(ggplot2)
library(dplyr)
library(tidyr)
library(rstatix)
library(ggpubr)

# ---- Load data --------------------------------------------------------------
# NOTE: Replace ../data_local/ND2024_raw.csv with your own data following the
#       schema described in ./data_examples/README_data_dictionary.md
data <- read.csv("../data_local/ND2024_raw.csv")

# ---- Aggregate to catchment scale -------------------------------------------
summary_stats <- data %>%
  group_by(SBSNCD) %>%
  summarize(
    TDI1618wet_mean = mean(TDI1618wet, na.rm = TRUE),
    TDI1618dry_mean = mean(TDI1618dry, na.rm = TRUE),
    TDI1618_mean    = mean(TDI1618,    na.rm = TRUE),
    BMI1618wet_mean = mean(BMI1618wet, na.rm = TRUE),
    BMI1618dry_mean = mean(BMI1618dry, na.rm = TRUE),
    BMI1618_mean    = mean(BMI1618,    na.rm = TRUE),
    FAI1618wet_mean = mean(FAI1618wet, na.rm = TRUE),
    FAI1618dry_mean = mean(FAI1618dry, na.rm = TRUE),
    FAI1618_mean    = mean(FAI1618,    na.rm = TRUE),
    Stream          = first(Stream)
  )

# =============================================================================
# Part A: Seasonal comparison (Dry vs. Wet)  -- Section 3.1, Fig S1a-b
# =============================================================================

plot_data_season <- summary_stats %>%
  select(TDI1618dry_mean, TDI1618wet_mean,
         BMI1618dry_mean, BMI1618wet_mean,
         FAI1618dry_mean, FAI1618wet_mean) %>%
  pivot_longer(cols = everything(),
               names_to = c("Index", "Season"),
               names_pattern = "(.+)1618(.+)_mean",
               values_to = "Value") %>%
  mutate(Season = factor(Season, levels = c("dry", "wet")),
         Index  = factor(Index,  levels = c("TDI", "BMI", "FAI")))

# Mann-Whitney U test (bonferroni-adjusted)
season_test <- plot_data_season %>%
  group_by(Index) %>%
  wilcox_test(Value ~ Season) %>%
  adjust_pvalue(method = "bonferroni") %>%
  add_significance()

cat("\n--- Seasonal comparison (Dry vs. Wet) ---\n")
print(season_test)

# Boxplot
ggplot(plot_data_season, aes(x = Season, y = Value, fill = Season)) +
  geom_boxplot(alpha = 0.5) +
  geom_jitter(width = 0.2, alpha = 0.5, aes(color = Season)) +
  facet_wrap(~ Index, scales = "free_y", ncol = 3) +
  stat_compare_means(method = "wilcox.test", label = "p.format",
                     label.x = 1.5, label.y.npc = "top") +
  scale_y_continuous(limits = c(0, 100)) +
  labs(title = "AEHIs: Dry vs. Wet Seasons (2016-2018)",
       x = "Season", y = "Index Value") +
  theme_bw() +
  theme(legend.position = "bottom")

# =============================================================================
# Part B: Mainstream vs. Tributary comparison  -- Section 3.1, Fig S1c
# =============================================================================

plot_data_stream <- summary_stats %>%
  select(Stream, TDI1618_mean, BMI1618_mean, FAI1618_mean) %>%
  pivot_longer(cols = c(TDI1618_mean, BMI1618_mean, FAI1618_mean),
               names_to = "Index", values_to = "Value") %>%
  mutate(Index = factor(Index,
                        levels = c("BMI1618_mean", "FAI1618_mean", "TDI1618_mean"),
                        labels = c("BMI", "FAI", "TDI")))

# Mann-Whitney U test
stream_test <- plot_data_stream %>%
  group_by(Index) %>%
  wilcox_test(Value ~ Stream) %>%
  adjust_pvalue(method = "bonferroni") %>%
  add_significance()

cat("\n--- Stream comparison (Mainstream vs. Tributary) ---\n")
print(stream_test)

# Boxplot
ggplot(plot_data_stream, aes(x = Stream, y = Value, fill = Stream)) +
  geom_boxplot(alpha = 0.5) +
  geom_jitter(width = 0.2, alpha = 0.5, aes(color = Stream)) +
  facet_wrap(~ Index, scales = "free_y", ncol = 3) +
  stat_compare_means(method = "wilcox.test", label = "p.format",
                     label.x = 1.5, label.y.npc = "top") +
  scale_y_continuous(limits = c(0, 100)) +
  scale_fill_manual(values = c("mainstream" = "#F8766D", "tributary" = "#00BFC4")) +
  labs(title = "AEHIs: Mainstream vs. Tributary (2016-2018)",
       x = "Stream Type", y = "Index Value") +
  theme_bw() +
  theme(legend.position = "bottom")
