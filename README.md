# cart_spheroids_flow

Flow cytometry analysis of A549+MRC-5 tumor spheroids co-cultured with PBMCs and CAR-T cells.

## Goal

Characterize how CAR-T cells modify immune cell populations over time in a 3D tumor
spheroid model, using non-activated and pre-activated PBMCs from two donors.

## Experimental design

- **Tumor model**: A549 (lung adenocarcinoma) + MRC-5 (fibroblasts) 3D spheroids
- **Immune cells**: PBMCs from 2 donors (biological replicates), non-activated or pre-activated
- **Treatment**: Donor-matched CAR-T cells added at 24h
- **Timepoints**: 24h / 48h / 72h (PBMC); 48h / 72h (PBMC + CAR-T)

## Status

| Script | Description | Status |
|--------|-------------|--------|
| `01_load_and_clean.R` | Load POBLACIONES XLS → `flow_clean.rds` (40 rows) | ✅ Done |
| `03_stacked_bars.R` | Stacked bar charts — immune composition | ✅ Done |
| `04_pbmc_live_timecourse.R` | Live PBMC count time-course ± CAR-T | ✅ Done |
| `05_immune_pop_timecourse.R` | Time-course for 9 immune populations (incl. NK) | ✅ Done |
| `06_heatmap.R` | Annotated heatmap (ComplexHeatmap) all populations | ⏳ Pending |
| `07_viabilidad_esferoide.R` | Spheroid and PBMC viability curves (4 groups) | ✅ Done |
| `08_car_expression.R` | CD19+ %, CD3+ count, % CAR-T, CAR-T CD4+/CD8+ % | ✅ Done |
| `09_cd4_cd8_count_timecourse.R` | Live CD4+/CD8+ PBMC count (3 groups × 3 timepoints) | ✅ Done |
| `10_morphology_spheroids.R` | Spheroid area, diameter, circularity (n=1) | ✅ Done |
| `11_esf_cd19_estrategia1.R` | Spheroid CD3⁻ viable cells and CD19⁺ (Strategy 1) | ⏸️ Inactive |

## Quick start

```bash
conda activate omics-R
cd ~/bioinfo/projects/cart_spheroids_flow
Rscript scripts/01_load_and_clean.R   # must run first
Rscript scripts/03_stacked_bars.R
Rscript scripts/04_pbmc_live_timecourse.R
Rscript scripts/05_immune_pop_timecourse.R
Rscript scripts/09_cd4_cd8_count_timecourse.R
Rscript scripts/07_viabilidad_esferoide.R   # independent
Rscript scripts/08_car_expression.R         # independent
Rscript scripts/10_morphology_spheroids.R   # independent
Rscript scripts/11_esf_cd19_estrategia1.R  # independent
```

See `CLAUDE.md` for full biological context and `docs/RUNBOOK.md` for step-by-step instructions.
