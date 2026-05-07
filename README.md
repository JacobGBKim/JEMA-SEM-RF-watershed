# Hierarchical Landscape–Water Quality–Biota Pathways: A Hybrid SEM–Random Forest Framework for Watershed Management Target Derivation

R analysis code for the manuscript published in Journal of Environmental
Management (2026).

This repository provides all R scripts used to perform:
1. Descriptive analysis of Aquatic Ecosystem Health Indices (AEHIs)
2. Principal Component Analysis (PCA) of landscape configuration metrics
3. Redundancy Analysis (RDA) and Variance Partitioning (VP)
4. Structural Equation Modeling (SEM) for hierarchical mediation
5. Comparison of four machine learning algorithms (RF, BRT, SVM, LR)
6. Random Forest performance visualization (ROC, threshold curves)
7. Random Forest with Partial Dependence Plots (PDPs)

---

## Citation

If you use this code in your research, please cite:

> Kim, G., Kim, K.-H., Park, J., & Kim, Y. (2026). Hierarchical
> Landscape–Water Quality–Biota Pathways: A Hybrid SEM–Random Forest
> Framework for Watershed Management Target Derivation. *Journal of
> Environmental Management*, [DOI to be added upon acceptance].

Code DOI (Zenodo): `[to be added after Zenodo release]`

---

## Repository Structure

```
Code_Data_for_GitHub/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── R_session_info.txt                 # Required R packages and versions
├── .gitignore                         # Excludes restricted data and runtime outputs
│
├── scripts/                           # 7 analysis scripts (run in order)
│   ├── 01_descriptive_AEHI.R
│   ├── 02_PCA_landscape.R
│   ├── 03_RDA_VP.R
│   ├── 04_SEM_mediation.R
│   ├── 05_ML_models_and_thresholds.R
│   ├── 06_RF_figure5.R
│   └── 07_RF_PDP_figureS4.R
│
├── data_examples/
│   ├── README_data_dictionary.md      # Variable definitions and units
│   ├── Classification_criteria.csv    # AEHI grade thresholds (public)
│   └── data_template.csv              # Header structure + synthetic example
│
└── docs/
    ├── analysis_pipeline.md           # Execution order and outputs
    ├── data_access_guide.md           # How to obtain source data from NIER/MOE
    └── github_zenodo_release_guide.md # Step-by-step publishing + DOI minting
```

---

## Data Availability

Code is fully open-source. Input data is restricted by source agency policies:

- Aquatic Ecosystem Health Indices (TDI, BMI, FAI)
  Source: National Institute of Environmental Research (NIER), South Korea
  Access: Available upon request to NIER
  URL: <http://water.nier.go.kr> (National Aquatic Ecological Monitoring Program)

- Water quality data
  Source: Water Environmental Monitoring Networks (WEMN), Ministry of
  Environment, South Korea
  URL: <http://water.nier.go.kr/web>

- Land cover data (1:25,000)
  Source: Environmental Geographic Information Service (EGIS),
  Ministry of Environment
  URL: <https://egis.me.go.kr/intro/land.do>

- Digital Elevation Model (30 m)
  Source: National Geographic Information Institute (NGII)
  URL: <https://map.ngii.go.kr/>

Researchers with equivalent watershed datasets (AEHI scores + water
quality + landscape metrics for catchments) can apply the framework
directly to derive context-specific management thresholds.

See `data_examples/README_data_dictionary.md` for the required data
schema and `docs/data_access_guide.md` for detailed instructions.

---

## Quick Start

### Requirements

- R version 4.2.0 or later (tested on 4.2.0)
- See `R_session_info.txt` for the full list of required packages.

Install all required packages with:
```r
install.packages(c(
  "tidyverse", "dplyr", "tidyr", "readr", "stringr",
  "ggplot2", "ggpubr", "ggrepel", "gridExtra",
  "FactoMineR", "factoextra", "vegan", "car",
  "lavaan", "lavaanPlot",
  "caret", "ranger", "gbm", "kernlab", "ROCR", "pROC",
  "doParallel", "foreach", "digest", "pdp",
  "rstatix"
))
```

### Workflow

1. Obtain source data from NIER/MOE (see Data Availability above).
2. Format your catchment-scale data following
   `data_examples/data_template.csv` and place the CSVs in a sibling
   folder named `../data_local/` (i.e., next to this repository, not
   inside it). The scripts read from `../data_local/...` so that
   restricted data physically cannot be pushed to GitHub.
3. Open this folder as an RStudio Project (or `setwd()` to the root).
4. Run scripts in order (see `docs/analysis_pipeline.md`).

### Reproducing Manuscript Results

Each script's header documents the expected output values that should
match the corresponding tables and figures in the manuscript. Random
seeds are fixed (`set.seed(123)`) wherever stochastic procedures occur,
ensuring run-to-run reproducibility.

---

## Mapping: Manuscript → Scripts

| Manuscript section / figure / table | Script |
|-------------------------------------|--------|
| Section 3.1 / Fig S1 (Mann–Whitney) | `01_descriptive_AEHI.R` |
| Section 3.2 / Supp Table S6 (PCA loadings) | `02_PCA_landscape.R` |
| Section 3.2 / Fig 3 (VP) / Fig 4 (RDA) | `03_RDA_VP.R` |
| Section 3.2 / Table 1 / Supp Fig S3 (SEM) | `04_SEM_mediation.R` |
| Section 3.3 / Supp Table S9 (4 ML benchmark) | `05_ML_models_and_thresholds.R` |
| Section 3.3 / Table 2 (WQ thresholds) | `05_ML_models_and_thresholds.R` (Section 8) |
| Section 3.3 / Fig 5 (RF performance) | `06_RF_figure5.R` |
| Section 3.3 / Supp Fig S4 (PDPs) | `07_RF_PDP_figureS4.R` |

---

## License

This code is released under the MIT License. See `LICENSE` for the
full text.

In short: you may freely use, modify, and distribute this code for any
purpose (including commercial), provided that the copyright notice and
license text are preserved. The code is provided "as is" with no
warranty.

---

## Contact

- Corresponding authors:
  - Yeonjoo Kim — `yeonjoo.kim@yonsei.ac.kr`
  - Kyoung-Ho Kim — `khkim@kei.re.kr`
- First author / repository maintainer: Gyobeom Kim

For questions about the code or methodology, please open an issue on
the GitHub repository.
