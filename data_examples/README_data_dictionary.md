# Data Dictionary

This document describes the variables required by the analysis scripts in
`../scripts/`. The actual catchment-scale dataset (`ND2024_catch.csv` and
related files) used in the published study cannot be redistributed here
because Aquatic Ecosystem Health Indices (AEHIs) and water quality data
are obtained from the National Institute of Environmental Research (NIER)
and Ministry of Environment (MOE) under data-use agreements.

A `data_template.csv` is provided in this folder showing the column header
structure and two synthetic example rows. To run the scripts, you must
prepare your own catchment-scale dataset following this schema (see
`../docs/data_access_guide.md` for instructions on obtaining the source data).

---

## Identifier

| Variable | Type    | Description                                            |
|----------|---------|--------------------------------------------------------|
| SBSNCD   | string  | Sub-basin code (catchment ID) used by NIER/MOE         |

---

## Aquatic Ecosystem Health Indices (Response variables)

All three indices are standardized 0–100 (higher = healthier).
Calculation protocols defined by Ministry of Environment (2008, 2018).

| Variable | Type    | Description                                            |
|----------|---------|--------------------------------------------------------|
| TDI1618  | numeric | Trophic Diatom Index (mean of 2016–2018 surveys)       |
| BMI1618  | numeric | Benthic Macroinvertebrate Index (mean of 2016–2018)    |
| FAI1618  | numeric | Fish Assessment Index (mean of 2016–2018)              |

Grade thresholds: see `Classification_criteria.csv` in this folder.
- Grade A (Excellent): TDI ≥ 90, BMI ≥ 80, FAI ≥ 80
- Grade B (Good):      TDI ≥ 70, BMI ≥ 65, FAI ≥ 60   ← "healthy" cutoff
- Grade C (Fair):      TDI ≥ 50, BMI ≥ 50, FAI ≥ 40
- Grade D (Poor):      TDI ≥ 30, BMI ≥ 35, FAI ≥ 20
- Grade E (Very poor): TDI <  30, BMI <  35, FAI <  20

Naming convention:
- `TDI1618wet` / `TDI1618dry` — seasonal means (wet / dry)
- `TDI1618`                    — annual mean
- `_mean`, `_min`, `_max` suffixes appear in `summary_stat.csv`

---

## Water Quality Parameters

Catchment-scale data. Two suffix conventions:
- (no suffix) = raw monthly mean averaged to catchment over 2016–2018
- `2`         = post-processed catchment mean (used in 05–07 scripts)

| Variable | Unit  | Description                                         |
|----------|-------|-----------------------------------------------------|
| temp     | °C    | Water temperature                                   |
| pH       | -     | Acidity                                             |
| EC       | μS/cm | Electrical conductivity                             |
| DO       | mg/L  | Dissolved oxygen                                    |
| BOD      | mg/L  | Biochemical oxygen demand                           |
| COD      | mg/L  | Chemical oxygen demand                              |
| SS       | mg/L  | Suspended solids                                    |
| TN       | mg/L  | Total nitrogen                                      |
| TP       | mg/L  | Total phosphorus                                    |
| TOC      | mg/L  | Total organic carbon                                |

Non-point source pollution loads (computed by user from MOE pollution
load database; control scenario for year 2020):

| Variable             | Unit | Description                                  |
|----------------------|------|----------------------------------------------|
| NP_BOD2020_Control   | kg/d | Non-point BOD discharge load                 |
| NP_TP2020_Control    | kg/d | Non-point TP discharge load                  |
| P_BOD2020_Control    | kg/d | Point BOD discharge load                     |
| P_TP2020_Control     | kg/d | Point TP discharge load                      |

(`*2` versions are catchment-scale aggregated values used by RF models.)

---

## Physiographic Variables

Derived from 30-m Digital Elevation Model (NGII).

| Variable     | Unit      | Description                                  |
|--------------|-----------|----------------------------------------------|
| slope_mean   | degrees   | Mean slope gradient                          |
| relief_mean  | m         | Basin relief (Hmax − Hmin)                   |
| TWI_mean     | -         | Topographic Wetness Index                    |
| HI           | -         | Hypsometric Integral (0–1)                   |

---

## Land Cover Composition (proportion 0–1)

Derived from 2018 land cover map (1:25,000) by EGIS, Ministry of Environment.

| Variable | Description                                              |
|----------|----------------------------------------------------------|
| Forest   | Proportion of forested area                              |
| Agri     | Proportion of agricultural land                          |
| Urban    | Proportion of urban area                                 |
| Grass    | Proportion of grassland                                  |
| Wet      | Proportion of wetland                                    |
| Bare     | Proportion of bare land                                  |
| Water    | Proportion of water bodies                               |

---

## Landscape Configuration Metrics

Computed using the `landscapemetrics` R package (Hesselbarth et al., 2019).
Two sets are provided:
- `*_W` suffix : watershed-level (catchment-scale)
- (no suffix) or `1`-`7` numbered: per land-cover class (1=urban, 2=agri,
  3=forest, 4=grass, 5=water, 6=wet, 7=bare)

| Variable     | Description                                         |
|--------------|-----------------------------------------------------|
| ai           | Aggregation Index                                   |
| cohesion     | Patch Cohesion Index                                |
| contag       | Contagion Index                                     |
| division     | Landscape Division Index                            |
| iji          | Interspersion and Juxtaposition Index               |
| lpi          | Largest Patch Index                                 |
| lsi          | Landscape Shape Index                               |
| msidi        | Modified Simpson's Diversity Index                  |
| msiei        | Modified Simpson's Evenness Index                   |
| pafrac       | Perimeter-Area Fractal Dimension                    |
| pd           | Patch Density                                       |
| pladj        | Percentage of Like Adjacencies                      |
| shdi         | Shannon's Diversity Index                           |
| shei         | Shannon's Evenness Index                            |
| sidi         | Simpson's Diversity Index                           |
| siei         | Simpson's Evenness Index                            |

PCA-derived synthetic axes (script `02_PCA_landscape.R` produces these):

| Variable        | Description                                       |
|-----------------|---------------------------------------------------|
| Aggregation_W   | PC1 of landscape configuration (75.4% variance)   |
| Complexity_W    | PC2 of landscape configuration (10.8% variance)   |

---

## Files Used by Each Script

| Script                          | Required input file              |
|---------------------------------|----------------------------------|
| 01_descriptive_AEHI.R           | ND2024_raw.csv                   |
| 02_PCA_landscape.R              | ND2024_catch.csv                 |
| 03_RDA_VP.R                     | ND2024_catch.csv                 |
| 04_SEM_mediation.R              | data_sem.csv                     |
| 05_ML_models_and_thresholds.R   | ND2024_catch.csv                 |
| 06_RF_figure5.R                 | ND2024_catch.csv                 |
| 07_RF_PDP_figureS4.R            | ND2024_catch_206.csv             |

`ND2024_catch_206.csv` = `ND2024_catch.csv` filtered to 206 catchments
with non-missing AEHI scores (script 05 generates this automatically
when run; or you can derive it as `ECO[!is.na(ECO$TDI1618), ]`).

---

## Provided Files

| File                              | Source / status                        |
|-----------------------------------|----------------------------------------|
| Classification_criteria.csv       | Public (MOE 2008, 2018)                |
| data_template.csv                 | Synthetic example (this repo)          |
| ND2024_raw.csv                    | Restricted (NIER) — not provided       |
| ND2024_catch.csv                  | Restricted — not provided              |
| ND2024_catch_206.csv              | Restricted — derive from ND2024_catch  |
| data_sem.csv                      | Restricted — derive from ND2024_catch  |

To obtain the source data, see `../docs/data_access_guide.md`.

---

## References

- Hesselbarth, M.H.K., Sciaini, M., With, K.A., Wiegand, K., Nowosad, J.
  (2019). landscapemetrics: an open-source R tool to calculate landscape
  metrics. Ecography 42, 1648–1657.
- Ministry of Environment (2008, 2018). Stream/River Ecosystem Survey
  and Health Assessment.
- McGarigal, K. (2015). FRAGSTATS help. Documentation file (referenced
  by `landscapemetrics`).
