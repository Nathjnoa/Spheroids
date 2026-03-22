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

### Morfología del esferoide (1 archivo XLSX — usado por script 10)

```text
Medidas esferoides.xlsx
```

16 filas × 8 columnas: `UNIDAD EXPERIMENTAL`, `TIEMPO`, `PBMC`, `ACTIVACIÓN`, `CAR-T`,
`AREA` (µm²), `DIAMETRO` (µm), `CIRCULARIDAD` (0–1). n=1 por grupo × tiempo (sin réplicas).
Grupos: Esferoide solo, Esferoide+CAR-T, Esferoide+PBMC (act/no act), Esferoide+PBMC+CAR-T (act/no act).

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

### MFI de CD19 (2 archivos XLS — usados por script 13)

```text
MFI CD19+ ACTIVADAS.xls
MFI CD19+ NO ACTIVADOS.xls
```

3 columnas: nombre FCS, MFI Zombie Red, MFI CD19.
Metadata parseada del nombre FCS. Controles single-cell (UNS A549 CD19, WT, MRC5)
solo en NO ACTIVADOS.

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

# Paso 5 — Curvas de 8 poblaciones inmunes específicas
# Input:  data/processed/flow_clean.rds
# Output: results/figures/05_*.pdf/.png (16 figuras)
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

### Pipeline de morfología del esferoide (independiente)

```bash
# Paso 10 — Área, Diámetro y Circularidad del esferoide
# Input:  data/raw/Medidas esferoides.xlsx
# Output: results/figures/10_area_noact.pdf/.png
#                          10_area_act.pdf/.png
#                          10_diametro_noact.pdf/.png
#                          10_diametro_act.pdf/.png
#                          10_circularidad_noact.pdf/.png
#                          10_circularidad_act.pdf/.png
Rscript scripts/10_morphology_spheroids.R
```

### Pipeline de conteos CD4⁺/CD8⁺ PBMC (independiente)

```bash
# Paso 09 — Conteos de células CD4+ y CD8+ vivas a lo largo del tiempo
# Tres grupos: Sph+PBMC, Sph+PBMC+CAR-T, Sph+CAR-T
# Input:  data/processed/flow_clean.rds (Sph+PBMC y Sph+PBMC+CAR-T)
#         data/raw/EXPRESIÓN CAR CONTEOS ACTIVADAS.xlsx  (Sph+CAR-T)
#         data/raw/EXPRESIÓN CAR CONTEOS NO ACTIVADAS.xlsx
# Output: results/figures/09_cd4_count_noact.pdf/.png
#                          09_cd4_count_act.pdf/.png
#                          09_cd8_count_noact.pdf/.png
#                          09_cd8_count_act.pdf/.png
Rscript scripts/09_cd4_cd8_count_timecourse.R
```

### Pipeline de viabilidad normalizada (independiente)

```bash
# Paso 12 — Viabilidad normalizada al Sph.only + citotoxicidad específica
# Input:  data/raw/*VIABILIDAD CONTEOS*.xlsx (2 archivos, mismos que script 07)
# Output: results/figures/12_viab_total_noact.pdf/.png
#                          12_viab_total_act.pdf/.png
#                          12_viab_cd19pos_noact.pdf/.png
#                          12_viab_cd19pos_act.pdf/.png
#                          12_viab_cd19neg_noact.pdf/.png
#                          12_viab_cd19neg_act.pdf/.png
#         results/tables/12_citotoxicidad_resumen.csv
Rscript scripts/12_viabilidad_normalizada.R
```

### Pipeline de MFI CD19 (independiente)

```bash
# Paso 13 — MFI del transgén CD19 absoluta y normalizada
# Input:  data/raw/MFI CD19+ ACTIVADAS.xls
#         data/raw/MFI CD19+ NO ACTIVADOS.xls
# Output: results/figures/13_mfi_cd19_noact.pdf/.png
#                          13_mfi_cd19_act.pdf/.png
#                          13_mfi_cd19_norm_noact.pdf/.png
#                          13_mfi_cd19_norm_act.pdf/.png
#         results/tables/13_mfi_cd19_resumen.csv
Rscript scripts/13_mfi_cd19.R
```

### Pipeline completo (orden recomendado)

```bash
Rscript scripts/01_load_and_clean.R
Rscript scripts/03_stacked_bars.R
Rscript scripts/04_pbmc_live_timecourse.R
Rscript scripts/05_immune_pop_timecourse.R
Rscript scripts/07_viabilidad_esferoide.R
Rscript scripts/08_car_expression.R
Rscript scripts/09_cd4_cd8_count_timecourse.R
Rscript scripts/10_morphology_spheroids.R
Rscript scripts/12_viabilidad_normalizada.R
Rscript scripts/13_mfi_cd19.R
```

## Scripts — estado actual

| Script | Estado | Descripción |
| ------ | ------ | ----------- |
| `01_load_and_clean.R` | ✅ Activo | POBLACIONES XLS → flow_clean.rds |
| `02_plots.R` | ⚠️ Deprecado | Reemplazado por 03, 04 y 05 |
| `03_stacked_bars.R` | ✅ Activo | Barras apiladas composición inmune |
| `04_pbmc_live_timecourse.R` | ✅ Activo | Curvas PBMCs vivas ±CAR-T |
| `05_immune_pop_timecourse.R` | ✅ Activo | Curvas 9 poblaciones específicas (incluye NK cells) |
| `06_heatmap.R` | ⏳ Pendiente | Heatmap ComplexHeatmap todas las poblaciones |
| `07_viabilidad_esferoide.R` | ✅ Activo | Curvas viabilidad esferoide y PBMC; leyenda 2 filas en esf_vivas |
| `08_car_expression.R` | ✅ Activo | CD19+ %, CD3+ count, % CAR-T, CD4⁺, CD8⁺ |
| `09_cd4_cd8_count_timecourse.R` | ✅ Activo | Conteos CD4⁺/CD8⁺ PBMC: 3 grupos × 3 tiempos × 2 activaciones |
| `10_morphology_spheroids.R` | ✅ Activo | Área, Diámetro y Circularidad del esferoide (n=1) |
| `11_esf_cd19_estrategia1.R` | ⏸️ Inactivo | Células esferoide CD3⁻ vivas y CD19⁺ (Estrategia 1 de gating) — temporalmente fuera del flujo |
| `12_viabilidad_normalizada.R` | ✅ Activo | Viabilidad normalizada + citotoxicidad específica (total, CD19⁺, CD19⁻) + tabla resumen |
| `13_mfi_cd19.R` | ✅ Activo | MFI CD19 absoluta y normalizada a UNS A549 CD19 + tabla resumen |

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

### Script 05 (18 figuras)

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
| `05_cd4_hladr_pos_noact.pdf/.png` | CD4⁺/HLA-DR⁺ % — no activadas |
| `05_cd4_hladr_pos_act.pdf/.png` | CD4⁺/HLA-DR⁺ % — activadas |
| `05_cd8_hladr_pos_noact.pdf/.png` | CD8⁺/HLA-DR⁺ % — no activadas |
| `05_cd8_hladr_pos_act.pdf/.png` | CD8⁺/HLA-DR⁺ % — activadas |
| `05_nk_count_noact.pdf/.png` | NK cells (count) — no activadas |
| `05_nk_count_act.pdf/.png` | NK cells (count) — activadas |

> **Nota script 05:** NK cells usan `y_max = 1500` (rango real 34–1094 conteos).
> `make_pop_plot()` soporta `y_max` por spec; omitirlo usa la escala estándar 0–7000.

### Script 07

| Archivo | Descripción |
| ------- | ----------- |
| `07_esf_vivas_noact.pdf/.png` | Spheroid viable cells — no activadas (4 líneas, 4 tiempos) |
| `07_esf_vivas_act.pdf/.png` | Spheroid viable cells — activadas (4 líneas, 4 tiempos) |
| `07_pbmc_vivas_noact.pdf/.png` | Viable PBMCs — no activadas (2 líneas, 3 tiempos) |
| `07_pbmc_vivas_act.pdf/.png` | Viable PBMCs — activadas (2 líneas, 3 tiempos) |

> **Nota script 07:** `esf_vivas` usa leyenda en 2 filas (`legend_nrow = 2`) por tener 4 grupos.
> `pbmc_vivas` mantiene leyenda en 1 fila (`legend_nrow = 1`) con solo 2 grupos.

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
- [ ] Línea `Sph+PBMC+CAR-T` en curvas temporales comparte punto t=24h con `Sph+PBMC`
- [ ] Script 05 genera 18 figuras (9 poblaciones × 2 activaciones, incluye NK cells)
- [ ] Leyendas en scripts 04 y 05: `Sph+PBMC` (gris) y `Sph+PBMC+CAR-T` (color población)

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
- [ ] `08_cd3_count_noact` tiene eje Y con límite superior fijo en 5000
- [ ] `08_cart_pct_*`, `08_cd4_pct_*`, `08_cd8_pct_*` tienen 2 líneas y 2 tiempos (72, 96 h sph)

### Script 09 — cd4_cd8_count_timecourse (4 figuras)

| Archivo | Descripción |
| ------- | ----------- |
| `09_cd4_count_noact.pdf/.png` | Live CD4⁺ cells (count) — no activadas (3 líneas, 3 tiempos) |
| `09_cd4_count_act.pdf/.png` | Live CD4⁺ cells (count) — activadas (3 líneas, 3 tiempos) |
| `09_cd8_count_noact.pdf/.png` | Live CD8⁺ cells (count) — no activadas (3 líneas, 3 tiempos) |
| `09_cd8_count_act.pdf/.png` | Live CD8⁺ cells (count) — activadas (3 líneas, 3 tiempos) |

> **3 líneas:** `Sph+CAR-T` (naranja #E69F00, romb), `Sph+PBMC` (gris #555555, círculo),
> `Sph+PBMC+CAR-T` (verde #009E73, triángulo).
> **Fuentes de datos:** Sph+PBMC y Sph+PBMC+CAR-T → `cd4`/`cd8` de `flow_clean.rds` (CONTEOS);
> Sph+CAR-T → columnas `Vivas/CAR-T CD4+` y `Vivas/CAR-T CD8+` de EXPRESIÓN CAR CONTEOS (PBMC=NO).
> **Conversión de tiempo:** EXPRESIÓN CAR usa tiempo total; se resta 24 para alinear con PBMC time.
> **Baselines compartidos en t=24h (PBMC time):** Sph+PBMC+CAR-T ← Sph+PBMC; Sph+CAR-T ← 0.
> **Leyenda en 2 filas** (guide_legend nrow=2) para evitar corte a la derecha.

### Script 10 — morphology (6 figuras)

| Archivo | Descripción |
| ------- | ----------- |
| `10_area_noact.pdf/.png` | Spheroid area (µm²) — no activadas (4 líneas, 4 tiempos) |
| `10_area_act.pdf/.png` | Spheroid area (µm²) — activadas (4 líneas, 4 tiempos) |
| `10_diametro_noact.pdf/.png` | Spheroid diameter (µm) — no activadas (4 líneas, 4 tiempos) |
| `10_diametro_act.pdf/.png` | Spheroid diameter (µm) — activadas (4 líneas, 4 tiempos) |
| `10_circularidad_noact.pdf/.png` | Circularity (a.u.) — no activadas (4 líneas, 4 tiempos) |
| `10_circularidad_act.pdf/.png` | Circularity (a.u.) — activadas (4 líneas, 4 tiempos) |

### Script 11 — esf_cd19_estrategia1 (4 figuras)

| Archivo | Descripción |
| ------- | ----------- |
| `11_esf_vivas_pct_act.pdf/.png` | % CD3⁻ Vivas del gate CD3 — activadas |
| `11_esf_vivas_cnt_act.pdf/.png` | #Células CD3⁻ Vivas — activadas |
| `11_cd19_pct_act.pdf/.png` | % CD19⁺ del gate Vivas — activadas |
| `11_cd19_cnt_act.pdf/.png` | #Células CD19⁺ — activadas |

> Área y Diámetro: eje Y en notación científica (escala lineal). Circularidad: escala lineal 0–1.
> n=1 por grupo × tiempo; no se promedia entre donantes (dato único por condición).

### Script 12 — viabilidad_normalizada (6 figuras + 1 tabla)

| Archivo | Descripción |
| ------- | ----------- |
| `12_viab_total_noact.pdf/.png` | Viabilidad normalizada esferoide total — no activadas (3 líneas, ref 100%) |
| `12_viab_total_act.pdf/.png` | Viabilidad normalizada esferoide total — activadas |
| `12_viab_cd19pos_noact.pdf/.png` | Viabilidad normalizada CD19⁺ — no activadas |
| `12_viab_cd19pos_act.pdf/.png` | Viabilidad normalizada CD19⁺ — activadas |
| `12_viab_cd19neg_noact.pdf/.png` | Viabilidad normalizada CD19⁻ — no activadas |
| `12_viab_cd19neg_act.pdf/.png` | Viabilidad normalizada CD19⁻ — activadas |
| `12_citotoxicidad_resumen.csv` | Tabla: viabilidad y citotoxicidad por donante + mean (en `results/tables/`) |

### Script 13 — mfi_cd19 (4 figuras + 1 tabla)

| Archivo | Descripción |
| ------- | ----------- |
| `13_mfi_cd19_noact.pdf/.png` | MFI CD19 absoluta — no activadas (4 líneas, refs A549 CD19/WT) |
| `13_mfi_cd19_act.pdf/.png` | MFI CD19 absoluta — activadas |
| `13_mfi_cd19_norm_noact.pdf/.png` | MFI CD19 normalizada (% de A549 CD19) — no activadas |
| `13_mfi_cd19_norm_act.pdf/.png` | MFI CD19 normalizada (% de A549 CD19) — activadas |
| `13_mfi_cd19_resumen.csv` | Tabla: MFI absoluta y normalizada por donante + mean + controles (en `results/tables/`) |

## Re-ejecución tras modificar archivos fuente

| Cambio | Acción |
| ------ | ------ |
| Cambios en XLS de POBLACIONES | Re-ejecutar pipeline completo desde script 01 |
| Cambios en XLSX de VIABILIDAD CONTEOS | Re-ejecutar scripts 07 y 12 |
| Cambios en XLSX de VIABILIDAD PORCENTAJES | Re-ejecutar script 08 |
| Cambios en XLSX de EXPRESIÓN CAR PORCENTAJES | Re-ejecutar script 08 |
| Cambios en XLSX de EXPRESIÓN CAR CONTEOS | Re-ejecutar scripts 08 y 09_cd4_cd8 |
| Cambios en `Medidas esferoides.xlsx` | Re-ejecutar script 10_morphology |
| Cambios en XLS de MFI CD19+ | Re-ejecutar script 13 |

## Decisiones de análisis documentadas

- **Denominador de %**: siempre `pbmcs_live` (conteos). No usar directamente los % del XLS.
- **Macrófagos CD11b/HLA-DR %**: usar archivo de PORCENTAJES (no recalcular desde CONTEOS).
- **Promedio de donantes**: media aritmética D1 y D2 (n=2, solo descriptivo).
- **Baseline esferoide**: punto t=24h de `Esf. solo` es compartido por todas las líneas en curvas de `esf_vivas`.
- **Punto compartido CAR-T**: línea `+ CAR-T` comparte t=48h con `− CAR-T`; `CAR-T solo` comparte t=48h con `Esf. solo`.
- **Paleta**: Okabe-Ito (colorblind-safe): gris=Esf.solo, naranja=CAR-T solo, gris oscuro=−CAR-T, verde=+CAR-T.
- **Idioma**: inglés en todas las figuras.
- **TIEMPO en archivos de viabilidad**: horas totales del experimento (24/48/72/96 h).
