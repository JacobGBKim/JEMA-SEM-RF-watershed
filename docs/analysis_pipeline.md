# Analysis Pipeline

This document describes the execution order and expected outputs of the
seven analysis scripts.

---

## Recommended Execution Order

Scripts can be run independently (each is self-contained), but the
recommended order matches the manuscript's narrative flow:

```
01_descriptive_AEHI.R           (Section 3.1)
        ↓
02_PCA_landscape.R              (Section 3.2 - PCA)
        ↓
03_RDA_VP.R                     (Section 3.2 - RDA + VP)
        ↓
04_SEM_mediation.R              (Section 3.2 - SEM)
        ↓
05_ML_models_and_thresholds.R   (Section 3.3 - 4 ML + Table 2)
        ↓
06_RF_figure5.R                 (Section 3.3 - Figure 5)
        ↓
07_RF_PDP_figureS4.R            (Section 3.3 - Figure S4)
```

---

## Script-by-Script Description

### 01_descriptive_AEHI.R

Purpose: Mann-Whitney U tests + boxplots for AEHIs
- Seasonal comparison (dry vs. wet)
- Mainstream vs. tributary comparison

Input: `../data_local/ND2024_raw.csv`

Outputs:
- Console: bonferroni-adjusted p-values
- Plots: 2 boxplots (corresponds to Supplementary Figure S1)

Expected results:
- TDI: dry vs. wet p < 0.01 (significant seasonal difference)
- BMI: p = 0.77 (not significant)
- FAI: p = 0.56 (not significant)
- Mainstem vs. tributary: TDI/FAI p < 0.05; BMI p < 0.01

---

### 02_PCA_landscape.R

Purpose: PCA of 16 landscape configuration metrics

Input: `../data_local/ND2024_catch.csv`

Outputs:
- Console: PCA summary, VIF diagnostic
- Plots: scree plot, contribution plot, biplot
- File: `../data_local/landuse_data_with_pc_scores.csv` (PC1, PC2 scores added)

Expected results (Supplementary Table S6):
- PC1 (Aggregation): 75.43% variance explained
- PC2 (Shape Complexity): 10.78% variance explained
- Cumulative: 86.21%

---

### 03_RDA_VP.R

Purpose: Redundancy Analysis + Variance Partitioning

Input: `../data_local/ND2024_catch.csv`

Outputs:
- Console: RDA summary, eigenvalues, VP results
- Plots: RDA biplot (Fig 4), VP Venn diagram (Fig 3)

Expected results (Section 3.2):
- RDA1 (Landscape → AEHIs): 48.4%
- RDA2: 10.4%
- VP: Landscape unique 8.0%, WQ unique 1.3%, Shared 38.1%
- Total explained: 47.4%

---

### 04_SEM_mediation.R

Purpose: SEM with mediation analysis (Landscape → WQ → Health)

Input: `../data_local/data_sem.csv`

Outputs:
- Console: SEM summary with fit indices
- R environment: `fit_indices_df`, `loadings_table`,
  `structural_table`, `effects_table`, `r_squared_df`
- Plot: SEM path diagram (Supplementary Figure S3)

Expected results (Manuscript Table 1):
- Direct (Landscape → Health):    β = 0.425, p < 0.001
- Indirect (Landscape → WQ → H):  β = 0.261, p = 0.004
- Total effect:                    β = 0.686
- Fit: CFI = 0.919, TLI = 0.889, SRMR = 0.077, RMSEA = 0.131

---

### 05_ML_models_and_thresholds.R

Purpose: Four ML models (RF, BRT, SVM, LR) comparison + management
threshold derivation

Input: `../data_local/ND2024_catch.csv`

Outputs:
- Console: per-AEHI performance table (Supplementary Table S9)
- Plots: AUC comparison bar charts
- Console: Reproduced Table 2 (Water quality management thresholds)

Expected results:
- Integrated RF AUC: TDI = 0.70, BMI = 0.93, FAI = 0.88
- Optimal cutoff:    TDI = 0.57, BMI = 0.56, FAI = 0.43
- Table 2: BOD ≈ 1.10 mg/L, TP ≈ 0.03 mg/L (means of healthy sites)

Runtime: ~10–20 min on a modern desktop (uses parallel processing)

---

### 06_RF_figure5.R

Purpose: Reproduce Figure 5 (RF performance ROC + threshold curves)

Input: `../data_local/ND2024_catch.csv`

Outputs:
- 9 paired plots (3 AEHIs × 3 predictor sets) rendered to RStudio
- Each plot: ROC curve (left) + Performance vs. cutoff (right)

Expected results: Same AUC and cutoff values as script 05.

Note: This script uses a different CV approach (random hyperparameter
search via `ranger`) than script 05 (caret-based grid search). Both
produce the same paper figures.

---

### 07_RF_PDP_figureS4.R

Purpose: RF with detailed validation (CV, OOB) + Partial Dependence Plots

Input: `../data_local/ND2024_catch_206.csv`
(can be derived from `ND2024_catch.csv` by removing rows with NA in TDI/BMI/FAI)

Outputs (saved to current working directory):
- PDFs: `{TDI,BMI,FAI}_EnhancedAnalysis.pdf`,
        `{TDI,BMI,FAI}_PartialDependencePlots.pdf` (Figure S4)
- CSVs: `Table3_Enhanced_Performance.csv`, `TableS6_CV_Results.csv`,
        per-AEHI performance / importance / CV results
- RDS:  `{TDI,BMI,FAI}_enhanced_results.rds`

Expected results: Section 3.3 Integrated RF metrics +
PDP curves showing tipping points (e.g., BMI sharp decline when
BOD > ~1.1 mg/L).

---

## Setup Tips

1. Working directory: Open this folder as an RStudio Project, or use
   `setwd("path/to/Code_Data_for_GitHub")` before running scripts.
2. Data folder: Create `../data_local/` (i.e., a sibling folder next to
   this repository) and place your prepared CSVs there. Restricted data
   is intentionally kept outside the repo so it cannot be accidentally
   pushed to GitHub.
3. Package conflicts: Some packages (e.g., `MASS::select` vs
   `dplyr::select`) may conflict. Scripts use `dplyr::select` explicitly
   to avoid this.
4. Parallel processing: Scripts 05 and 06 spin up parallel clusters.
   Ensure no other parallel R sessions are running.

---

## Troubleshooting

Issue: `Error: cannot allocate vector of size ...`
- Solution: Reduce `tuneLength` in script 05 (line ~80) from 10 to 5.

Issue: Different RF AUC values across runs
- Solution: Verify `set.seed(123)` runs at the top of each script.
  Note that results may vary slightly between R versions due to
  internal RNG changes.

Issue: SEM model fails to converge
- Solution: Verify your `data_sem.csv` includes all 11 required columns
  (see `../data_examples/README_data_dictionary.md`) without NAs in
  the SEM variables.
