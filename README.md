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
| `01_load_and_clean.R` | Load XLS files, assign canonical columns | Done |
| `02_viabilidad_tiempos.R` | PBMC viability over time | Done |
| `03_stacked_bars.R` | Stacked bar charts — immune composition | Done |
| `04_cd8cd4_ratio.R` | CD8/CD4 ratio + HLA-DR activation index | Pending |
| `05_delta_cart_effect.R` | Δ% relative CAR-T effect | Pending |
| `06_heatmap.R` | Annotated heatmap (ComplexHeatmap) | Pending |
| `07_viabilidad_esferoide.R` | Tumor spheroid viability | Awaiting data |
| `08_car_expression.R` | CAR expression (% CAR+ in CD8) | Awaiting data |

## Quick start

```bash
conda activate omics-R
cd ~/bioinfo/projects/cart_spheroids_flow
Rscript scripts/01_load_and_clean.R
Rscript scripts/03_stacked_bars.R
```

See `CLAUDE.md` for full biological context and `docs/RUNBOOK.md` for step-by-step instructions.
