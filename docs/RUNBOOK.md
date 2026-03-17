# RUNBOOK — cart_spheroids_flow

Guía de reproducción paso a paso.

## Requisitos

- Conda con el ambiente `omics-R`
- 12 archivos crudos en `data/raw/` (ver sección Archivos de entrada)

## Activar ambiente

```bash
conda activate omics-R
cd ~/bioinfo/projects/cart_spheroids_flow
```

## Archivos de entrada (`data/raw/`)

### Poblaciones inmunes (4 archivos XLS — usados por script 01)

```text
ACTIVADAS CONTEOS POBLACIONES (PBMC+CART).xls
ACTIVADAS PORCENTAJES POBLACIONES (PBMC+CART).xls
NO ACTIVADOS CONTEOS POBLACIONES (PBMC+CART).xls
NO ACTIVADOS PORCENTAJES POBLACIONES (PBMC+CART).xls
```

### Viabilidad tumoral y PBMC (4 archivos XLSX — usados por script 07)

```text
ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx
ACTIVADAS PORCENTAJES VIABILIDAD (PBMC+CART).xlsx
NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx
NO ACTIVADOS PORCENTAJES VIABILIDAD-FLAG (PBMC+CART).xlsx
```

TIEMPO en estos archivos: 24, 48, 72, 96 h (horas totales del experimento).
Los archivos originales .xls tenían TIEMPO = 0/24/48/72 y fueron corregidos (+24)
y convertidos a .xlsx el 2026-03-16.

### Expresión del CAR (4 archivos XLSX — usados por script 08)

```text
EXPRESIÓN CAR CONTEOS ACTIVADAS.xlsx
EXPRESIÓN CAR PORCENTAJES ACTIVADAS.xlsx
EXPRESIÓN CAR CONTEOS NO ACTIVADAS.xlsx
EXPRESIÓN CAR PORCENTAJES NO ACTIVADAS.xlsx
```

TIEMPO en estos archivos: 72 y 96 h.

## Orden de ejecución

### Pipeline de poblaciones inmunes

```bash
# Paso 1 — Carga y limpieza de datos de POBLACIONES
# Input:  data/raw/*.xls (4 archivos POBLACIONES)
# Output: data/processed/flow_clean.rds + flow_clean.csv (40 filas)
Rscript scripts/01_load_and_clean.R

# Paso 3 — Barras apiladas de composición inmune
# Input:  data/processed/flow_clean.rds
# Output: results/figures/03_stacked_bars.pdf/.png
Rscript scripts/03_stacked_bars.R

# Paso 4 — Curvas temporales de PBMCs vivas
# Input:  data/processed/flow_clean.rds
# Output: results/figures/04_pbmc_live_noact.pdf/.png
#                          04_pbmc_live_act.pdf/.png
Rscript scripts/04_pbmc_live_timecourse.R

# Paso 5 — Curvas de 6 poblaciones inmunes específicas
# Input:  data/processed/flow_clean.rds
# Output: results/figures/05_*.pdf/.png (12 figuras)
Rscript scripts/05_immune_pop_timecourse.R
```

### Pipeline de viabilidad (independiente)

```bash
# Paso 7 — Curvas de viabilidad de esferoide y PBMCs
# Input:  data/raw/*VIABILIDAD CONTEOS*.xlsx (2 archivos)
# Output: results/figures/07_sph_vivas_noact.pdf/.png
#                          07_sph_vivas_act.pdf/.png
#                          07_pbmc_vivas_noact.pdf/.png
#                          07_pbmc_vivas_act.pdf/.png
Rscript scripts/07_viabilidad_esferoide.R
```

### Pipeline de expresión CAR y CD19+ (independiente)

```bash
# Paso 8 — CD19+ %, CD3+ count, % CAR-T, % CAR-T CD4+, % CAR-T CD8+
# Input:  data/raw/*VIABILIDAD PORCENTAJES*.xlsx (2 archivos)
#         data/raw/EXPRESIÓN CAR *.xlsx (4 archivos)
# Output: results/figures/08_cd19_pct_*.pdf/.png
#                          08_cd3_count_*.pdf/.png
#                          08_cart_pct_*.pdf/.png
#                          08_cd4_pct_*.pdf/.png
#                          08_cd8_pct_*.pdf/.png
Rscript scripts/08_car_expression.R
```

### Pipeline completo (orden recomendado)

```bash
Rscript scripts/01_load_and_clean.R
Rscript scripts/03_stacked_bars.R
Rscript scripts/04_pbmc_live_timecourse.R
Rscript scripts/05_immune_pop_timecourse.R
Rscript scripts/07_viabilidad_esferoide.R
Rscript scripts/08_car_expression.R
```

## Scripts — estado actual

| Script | Estado | Descripción |
| ------ | ------ | ----------- |
| `01_load_and_clean.R` | Activo | POBLACIONES XLS → flow_clean.rds |
| `02_plots.R` | Deprecado | Reemplazado por 03, 04 y 05 |
| `03_stacked_bars.R` | Activo | Barras apiladas composición inmune |
| `04_pbmc_live_timecourse.R` | Activo | Curvas PBMCs vivas ±CAR-T |
| `05_immune_pop_timecourse.R` | Activo | Curvas 6 poblaciones específicas |
| `06_heatmap.R` | Pendiente | Heatmap ComplexHeatmap todas las poblaciones |
| `07_viabilidad_esferoide.R` | Activo | Curvas viabilidad esferoide y PBMC |
| `08_car_expression.R` | Activo | CD19+ %, CD3+ count, % CAR-T, CD4⁺, CD8⁺ |

## Figuras generadas

### Script 03

| Archivo | Descripción |
| ------- | ----------- |
| `03_stacked_bars.pdf/.png` | Composición inmune — 2 paneles Act/No Act |

### Script 04

| Archivo | Descripción |
| ------- | ----------- |
| `04_pbmc_live_noact.pdf/.png` | PBMCs vivas — no activadas |
| `04_pbmc_live_act.pdf/.png` | PBMCs vivas — activadas |

### Script 05 (12 figuras)

| Archivo | Descripción |
| ------- | ----------- |
| `05_cd3_count_noact.pdf/.png` | CD3⁺ count — no activadas |
| `05_cd3_count_act.pdf/.png` | CD3⁺ count — activadas |
| `05_cd4_hladr_neg_noact.pdf/.png` | CD4⁺/HLA-DR⁻ % — no activadas |
| `05_cd4_hladr_neg_act.pdf/.png` | CD4⁺/HLA-DR⁻ % — activadas |
| `05_cd8_hladr_neg_noact.pdf/.png` | CD8⁺/HLA-DR⁻ % — no activadas |
| `05_cd8_hladr_neg_act.pdf/.png` | CD8⁺/HLA-DR⁻ % — activadas |
| `05_macrophages_count_noact.pdf/.png` | Macrófagos count — no activadas |
| `05_macrophages_count_act.pdf/.png` | Macrófagos count — activadas |
| `05_macrophages_cd11b_noact.pdf/.png` | Macrófagos CD11b⁺ % — no activadas |
| `05_macrophages_cd11b_act.pdf/.png` | Macrófagos CD11b⁺ % — activadas |
| `05_macrophages_hladr_noact.pdf/.png` | Macrófagos HLA-DR⁺ % — no activadas |
| `05_macrophages_hladr_act.pdf/.png` | Macrófagos HLA-DR⁺ % — activadas |

### Script 07

| Archivo | Descripción |
| ------- | ----------- |
| `07_esf_vivas_noact.pdf/.png` | Spheroid viable cells — no activadas (4 líneas, 4 tiempos) |
| `07_esf_vivas_act.pdf/.png` | Spheroid viable cells — activadas (4 líneas, 4 tiempos) |
| `07_pbmc_vivas_noact.pdf/.png` | Viable PBMCs — no activadas (2 líneas, 3 tiempos) |
| `07_pbmc_vivas_act.pdf/.png` | Viable PBMCs — activadas (2 líneas, 3 tiempos) |

### Script 08 (10 figuras)

| Archivo | Descripción |
| ------- | ----------- |
| `08_cd19_pct_noact.pdf/.png` | % CD19⁺ viable — no activadas (4 líneas, 4 tiempos) |
| `08_cd19_pct_act.pdf/.png` | % CD19⁺ viable — activadas (4 líneas, 4 tiempos) |
| `08_cd3_count_noact.pdf/.png` | Viable CD3⁺ cells (count) — no activadas (2 líneas, **3 tiempos**: 48, 72, 96 h sph) |
| `08_cd3_count_act.pdf/.png` | Viable CD3⁺ cells (count) — activadas (2 líneas, 3 tiempos) |
| `08_cart_pct_noact.pdf/.png` | CAR expression (%) — no activadas (2 líneas, 2 tiempos) |
| `08_cart_pct_act.pdf/.png` | CAR expression (%) — activadas (2 líneas, 2 tiempos) |
| `08_cd4_pct_noact.pdf/.png` | % CAR-T CD4⁺ cells — no activadas (2 líneas, 2 tiempos) |
| `08_cd4_pct_act.pdf/.png` | % CAR-T CD4⁺ cells — activadas (2 líneas, 2 tiempos) |
| `08_cd8_pct_noact.pdf/.png` | % CAR-T CD8⁺ cells — no activadas (2 líneas, 2 tiempos) |
| `08_cd8_pct_act.pdf/.png` | % CAR-T CD8⁺ cells — activadas (2 líneas, 2 tiempos) |

## Checklist de reproducción

### Pipeline de poblaciones

- [ ] Ambiente `omics-R` activado
- [ ] 4 archivos XLS de POBLACIONES presentes en `data/raw/`
- [ ] Script 01 genera `flow_clean.rds` sin errores (40 filas)
- [ ] Script 03 genera `03_stacked_bars.pdf` con 2 paneles y 3 facets cada uno
- [ ] Facet 24h en script 03 tiene solo 1 barra (`− CAR-T`); facets 48h y 72h tienen 2 barras
- [ ] Scripts 04 y 05 generan curvas con eje X triple (sph / PBMC time / CAR-T time)
- [ ] Línea `+ CAR-T` en curvas temporales comparte punto t=24h con `− CAR-T`

### Pipeline de viabilidad

- [ ] 2 archivos CONTEOS VIABILIDAD (.xlsx) presentes en `data/raw/`
- [ ] Script 07 genera 4 figuras en `results/figures/`
- [ ] `07_esf_vivas_*` tiene 4 líneas y 4 puntos de tiempo (24, 48, 72, 96 h sph)
- [ ] `07_pbmc_vivas_*` tiene 2 líneas (±CAR-T) y 3 puntos de tiempo (48, 72, 96 h sph)
- [ ] Eje Y fijo: límite 300–30 000; breaks en 1 000, 2 000, 3 000, 5 000, 10 000, 20 000, 30 000; expand 8% inferior
- [ ] Eje X: primera etiqueta es `24 h sph. / —` (baseline pre-PBMC)

### Pipeline expresión CAR y CD19+

- [ ] 6 archivos XLSX presentes en `data/raw/` (2 VIABILIDAD PORCENTAJES + 4 EXPRESIÓN CAR)
- [ ] Script 08 genera 10 figuras en `results/figures/`
- [ ] `08_cd19_pct_*` tiene 4 líneas y 4 puntos de tiempo (24–96 h sph)
- [ ] `08_cd3_count_*` tiene 2 líneas y **3 tiempos** (48, 72, 96 h sph); datos de CD3⁺ Vivas col O (ACTIVADOS) / col R (NO ACTIVADOS) de VIABILIDAD CONTEOS
- [ ] `08_cart_pct_*`, `08_cd4_pct_*`, `08_cd8_pct_*` tienen 2 líneas y 2 tiempos (72, 96 h sph)

## Re-ejecución tras modificar archivos fuente

| Cambio | Acción |
| ------ | ------ |
| Cambios en XLS de POBLACIONES | Re-ejecutar pipeline completo desde script 01 |
| Cambios en XLSX de VIABILIDAD CONTEOS | Re-ejecutar script 07 |
| Cambios en XLSX de VIABILIDAD PORCENTAJES | Re-ejecutar script 08 |
| Cambios en XLSX de EXPRESIÓN CAR | Re-ejecutar script 08 |

## Decisiones de análisis documentadas

- **Denominador de %**: siempre `pbmcs_live` (conteos). No usar directamente los % del XLS.
- **Macrófagos CD11b/HLA-DR %**: usar archivo de PORCENTAJES (no recalcular desde CONTEOS).
- **Promedio de donantes**: media aritmética D1 y D2 (n=2, solo descriptivo).
- **Baseline esferoide**: punto t=24h de `Esf. solo` es compartido por todas las líneas en curvas de `esf_vivas`.
- **Punto compartido CAR-T**: línea `+ CAR-T` comparte t=48h con `− CAR-T`; `CAR-T solo` comparte t=48h con `Esf. solo`.
- **Paleta**: Okabe-Ito (colorblind-safe): gris=Esf.solo, naranja=CAR-T solo, gris oscuro=−CAR-T, verde=+CAR-T.
- **Idioma**: inglés en todas las figuras.
- **TIEMPO en archivos de viabilidad**: horas totales del experimento (24/48/72/96 h).
