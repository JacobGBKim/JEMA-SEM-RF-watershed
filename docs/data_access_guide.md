# Data Access Guide

This guide explains how to obtain the source datasets used in the
published study. All input data come from public agencies in South Korea;
some require formal request procedures.

---

## 1. Aquatic Ecosystem Health Indices (AEHIs)

Source: National Institute of Environmental Research (NIER),
Ministry of Environment, South Korea

Data: Trophic Diatom Index (TDI), Benthic Macroinvertebrate Index
(BMI), Fish Assessment Index (FAI) — all calculated from biannual
biological surveys (spring + fall) at ~ 700 sites across the Nakdong
River basin since 2008.

Access procedure:

1. Visit the National Aquatic Ecological Monitoring Program (NAEMP)
   portal: <http://water.nier.go.kr>
2. For raw species occurrence data and pre-calculated AEHI scores,
   submit a formal data request to NIER specifying:
   - Research purpose and intended use
   - Geographic scope (e.g., Nakdong River basin)
   - Time period (e.g., 2016-2018)
3. Approval and data delivery typically take 2–4 weeks.

Citation:

> Ministry of Environment (2008, 2018). Stream/River Ecosystem Survey
> and Health Assessment*. National Institute of Environmental Research,
> Incheon, South Korea.

---

## 2. Water Quality Data

Source: Water Environmental Monitoring Networks (WEMN), Ministry of
Environment, South Korea

Data: Monthly measurements at 222+ stations of pH, water temperature,
DO, BOD, COD, SS, TN, TP, TOC, EC.

Access procedure:

1. Visit the Water Environment Information System:
   <http://water.nier.go.kr/web>
2. Most water quality measurements are downloadable directly without
   a formal request:
   - Navigate to "수질오염도 (Water Pollution)" → "측정자료조회 (Search Measurements)"
   - Filter by basin, station, parameter, and date range
   - Export as Excel or CSV

For this study, we used catchment-scale means aggregated from
monthly observations during 2016–2018.

Citation:

> Ministry of Environment (2024). *Installation and Operation Plan for
> Water Environment Monitoring Network*. Available from:
> <https://www.water.or.kr/upload/board/2024/03/20240320180535_1.pdf>

---

## 3. Non-point Source Pollution Loads (NP_BOD, NP_TP)

Source: Pollution Load Management System, Ministry of Environment

Data: Catchment-scale non-point source pollution loads for BOD and TP,
calculated annually from land-use and rainfall data using the MOE
methodology.

Access: Aggregated values for the 2020 control scenario are
available from the National Pollutant Load Database
(<http://wems.nier.go.kr/>). Researchers may compute their own values
following the published MOE methodology.

---

## 4. Land Cover Map (1:25,000)

Source: Environmental Geographic Information Service (EGIS),
Ministry of Environment

Data: Sub-classified land cover categories (forest, agriculture,
urban, grassland, wetland, bare land, water bodies) at 1:25,000 scale.

Access procedure:

1. Visit <https://egis.me.go.kr/intro/land.do>
2. Select "Subclassified Land Cover Map" (세분류 토지피복지도)
3. Choose target year (we used 2018) and download as Shapefile or GeoTIFF.

No formal request required; downloads are free for academic use.

---

## 5. Digital Elevation Model (DEM)

Source: National Geographic Information Institute (NGII)

Data: 30-m resolution Digital Elevation Model

Access procedure:

1. Visit <https://map.ngii.go.kr/>
2. Select "수치지형도" (Digital Topographic Map) → DEM downloads
3. May require a free user registration.

---

## 6. Watershed and Catchment Boundaries

Source: Water Management Information System (WAMIS)

Data: Sub-basin (소권역, SBSNCD) boundary shapefiles for the
Nakdong River basin (195 catchments).

Access: <https://www.wamis.go.kr/> → "유역 (Watershed)" downloads

---

## Computing the Catchment-Scale Dataset

After obtaining the raw datasets, the following processing steps were
performed to produce `ND2024_catch.csv`:

1. AEHI aggregation: For each catchment (SBSNCD), compute the mean
   of TDI/BMI/FAI scores across all monitoring sites within that
   catchment over 2016–2018.

2. Water quality aggregation: Compute monthly means at each WEMN
   station, then catchment-scale means averaged over 2016–2018.

3. Landscape metrics computation: Use the `landscapemetrics` R
   package (Hesselbarth et al., 2019) to compute the 16 configuration
   metrics from the 2018 land cover raster, clipped to each catchment
   polygon.

4. Land cover composition: Compute proportional area (0–1) of each
   of the 7 land cover classes within each catchment.

5. Physiographic metrics: Use the DEM to compute mean slope, basin
   relief, TWI, and HI per catchment.

6. Merge: Join all variables on SBSNCD to produce one row per
   catchment.

The resulting file should match the column structure shown in
`../data_examples/data_template.csv`.

---

## Required Input Files

After processing, place the following in `../data_local/` (a sibling
folder next to this repository — not inside the repo, so restricted
data cannot be accidentally pushed to GitHub):

| File                    | Required by script(s)              |
|-------------------------|------------------------------------|
| ND2024_raw.csv          | 01_descriptive_AEHI.R              |
| ND2024_catch.csv        | 02, 03, 05, 06                     |
| ND2024_catch_206.csv    | 07 (or auto-derived in 05)         |
| data_sem.csv            | 04_SEM_mediation.R                 |

`data_sem.csv` is a subset of `ND2024_catch.csv` containing only the
variables used in the SEM:
- Forest, slope_mean, relief_mean, HI
- BOD, COD, TN, TP
- TDI1618, BMI1618, FAI1618

---

## Questions

For data acquisition questions:
- NIER: <https://www.nier.go.kr/NIER/eng/index.do>
- MOE: <https://eng.me.go.kr/eng/web/main.do>

For code/methodology questions: see `../README.md` for contact info.
