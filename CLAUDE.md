# cart_spheroids_flow — CLAUDE.md

Proyecto de citometría de flujo para evaluar la actividad de células CAR-T sobre
esferoides tumorales A549+MRC-5 en presencia de PBMCs (activadas y no activadas).

---

## Contexto biológico

**Modelo tumoral:** Esferoides 3D de A549 (adenocarcinoma pulmonar) + MRC-5 (fibroblastos).
Las células A549 expresan el antígeno **CD19** como diana del CAR-T (modelo experimental).

**Sistema inmune:** PBMCs de 2 donantes sanos (D1 y D2), usados como dos réplicas biológicas.
- Condición 1: PBMCs **no activadas**
- Condición 2: PBMCs **activadas** (antes del co-cultivo)

**Tratamiento:** Células CAR-T de los mismos donantes (D1 y D2), que reconocen CD19⁺
y ejercen actividad citotóxica. Se añaden **después** de las 24h iniciales de co-cultivo.

**Objetivo:** Evaluar si las CAR-T modifican las poblaciones inmunes a lo largo del tiempo
y si ejercen actividad citotóxica sobre las células tumorales del esferoide.

---

## Diseño experimental y temporalidad

### Línea de tiempo del experimento

| Tiempo total | Evento | Condiciones medidas |
|-------------|--------|---------------------|
| 0 h | Formación del esferoide | — |
| **24 h** | Primer corte: esferoide solo (baseline) | Esf. solo |
| **24 h** | Se añaden PBMCs | — |
| **48 h** | Segundo corte: PBMCs llevan 24h, CAR-T aún no | Esf.solo, ±PBMC |
| **48 h** | Se añaden CAR-T | — |
| **72 h** | Tercer corte: CAR-T llevan 24h | Todos los grupos |
| **96 h** | Cuarto corte: CAR-T llevan 48h | Todos los grupos |

### Convención de labels en eje X (curvas temporales)

| esf_time | Label eje X (línea 1 / línea 2 / línea 3) | Interpretación |
|----------|-------------------------------------------|----------------|
| 24 h | `24 h sph. / —` | Baseline pre-PBMC |
| 48 h | `48 h sph / 24 h PBMC` | PBMCs 24h, sin CAR-T |
| 72 h | `72 h sph / 48 h PBMC / 24 h CAR-T` | CAR-T 24h |
| 96 h | `96 h sph / 72 h PBMC / 48 h CAR-T` | CAR-T 48h |

### Grupos experimentales

| Grupo (código) | PBMC | CAR-T | Tiempos disponibles |
|----------------|------|-------|---------------------|
| Esf. solo | NO | NO | 24, 48, 72, 96 h |
| CAR-T solo | NO | SI | 72, 96 h |
| Sph+PBMC | SI | NO | 48, 72, 96 h |
| Sph+PBMC+CAR-T | SI | SI | 72, 96 h |

**Puntos compartidos en curvas temporales** (convención de todos los scripts):
- Línea `Sph+PBMC+CAR-T` @ t=48h ← valor de `Sph+PBMC` @ t=48h (antes de añadir CAR-T)
- Línea `CAR-T solo` @ t=48h ← valor de `Esf. solo` @ t=48h
- Todas las líneas @ t=24h ← valor de `Esf. solo` @ t=24h (baseline pre-PBMC)

---

## Datos

### Archivos crudos (`data/raw/`)

#### Grupo 1: Poblaciones inmunes (PBMC)

Datos de PBMCs en co-cultivo con el esferoide. Contienen la jerarquía completa
de gating de poblaciones linfoides, mieloides y NK.

| Archivo | Formato | Activación | Tipo | Columnas |
|---------|---------|------------|------|----------|
| `ACTIVADAS CONTEOS POBLACIONES (PBMC+CART) (1).xls` | XLS | Activadas | Conteos | 28 |
| `ACTIVADAS PORCENTAJES POBLACIONES (PBMC+CART).xls` | XLS | Activadas | % | 27 |
| `NO ACTIVADOS CONTEOS POBLACIONES (PBMC+CART) (1).xls` | XLS | No activadas | Conteos | 28 |
| `NO ACTIVADOS PORCENTAJES POBLACIONES (PBMC+CART).xls` | XLS | No activadas | % | 27 |

Los archivos de CONTEOS tienen una columna adicional (col 28): `"Vivas CD19-CD16- (No definidas)"`,
mapeada a `cd14neg_cd16neg`. Los PORCENTAJES siguen con 27 columnas.

Estructura: 11 filas × 27/28 columnas. TIEMPO: 24, 48, 72 h (tiempo total experimento
desde adición de PBMCs; equivalente a PBMC time = TIEMPO − 24 h).

**Nota:** Estos 4 archivos se cargan mediante `01_load_and_clean.R` y se integran
en `flow_clean.rds`. Los archivos de la carpeta `data/raw/24h/`, `48h/`, `72h/` son
versiones antiguas de los mismos datos.

#### Grupo 2: Viabilidad tumoral + PBMC

Datos del gate de esferoide (células tumorales CD19⁺ y CD19⁻) y de PBMCs.
Incluyen controles "Esferoide solo" en todos los tiempos. **TIEMPO en horas totales
del experimento (24, 48, 72, 96 h).**

| Archivo | Formato | Activación | Tipo |
|---------|---------|------------|------|
| `ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx` | XLSX | Activadas | Conteos |
| `ACTIVADAS PORCENTAJES VIABILIDAD (PBMC+CART).xlsx` | XLSX | Activadas | % |
| `NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx` | XLSX | No activadas | Conteos |
| `NO ACTIVADOS PORCENTAJES VIABILIDAD-FLAG (PBMC+CART).xlsx` | XLSX | No activadas | % |

Estructura ACTIVADAS (19 filas × 29 cols):
- Col 10: `Esferoide/Vivas` — células vivas totales en gate de esferoide
- Col 14: `PBMC Vivas` — PBMCs vivas (gate separado)

Estructura NO ACTIVADAS (19 filas × 22 cols):
- Col 11: `Esferoide/Vivas`
- Col 17: `PBMC's Vivas`

> **Nota de conversión:** Los archivos originales .xls tenían TIEMPO = 0, 24, 48, 72.
> Se corrigieron el 2026-03-16 a horas totales del experimento (+24 a todos los valores)
> y se convirtieron a .xlsx. Los .xls originales fueron eliminados.

#### Grupo 3: Expresión del CAR en células T

Datos de subpoblaciones CAR-T (CD4⁺ y CD8⁺) dentro de las células vivas.
**TIEMPO en horas totales del experimento (72 y 96 h).**

| Archivo | Formato | Activación | Tipo |
|---------|---------|------------|------|
| `EXPRESIÓN CAR CONTEOS ACTIVADAS.xlsx` | XLSX | Activadas | Conteos |
| `EXPRESIÓN CAR PORCENTAJES ACTIVADAS.xlsx` | XLSX | Activadas | % |
| `EXPRESIÓN CAR CONTEOS NO ACTIVADAS.xlsx` | XLSX | No activadas | Conteos |
| `EXPRESIÓN CAR PORCENTAJES NO ACTIVADAS.xlsx` | XLSX | No activadas | % |

Estructura (9 filas × 8 cols):
- `Vivas/CAR-T` — total CAR-T vivas
- `Vivas/CAR-T CD4⁺` — CAR-T CD4⁺ vivas
- `Vivas/CAR-T CD8⁺` — CAR-T CD8⁺ vivas

Grupos: Esferoide solo Sph+PBMC+CAR-T (D1 y D2) y Esferoide + PBMC Sph+PBMC+CAR-T (D1 y D2), a t=72h y 96h.

> **Nota de conversión:** Archivos originados con TIEMPO inconsistente entre CONTEOS
> y PORCENTAJES. Homogeneizados el 2026-03-16 a tiempo total del experimento.
> CONTEOS ACTIVADAS: 24→72, 48→96 (+48). Resto: 48→72, 72→96 (+24).

#### Grupo 4: MFI de CD19 en Vivas CD19⁺

Median Fluorescence Intensity (MFI) del transgén CD19 y viabilidad (Zombie Red)
en el gate `Singlets/Esferoide/Vivas/Vivas CD19⁺`. Exportado desde FlowJo Table Editor.
**Metadata se parsea del nombre FCS** (no hay columnas de metadata separadas).

| Archivo | Formato | Activación | Filas útiles |
|---------|---------|------------|--------------|
| `MFI CD19+ ACTIVADAS.xls` | XLS | Activadas | 17 (excl. Mean/SD) |
| `MFI CD19+ NO ACTIVADOS.xls` | XLS | No activadas | 21 (excl. Mean/SD) + 4 controles |

Columnas (3):
- Col 1: Nombre del archivo FCS (contiene metadata)
- Col 2: `Singlets/Esferoide/Vivas | Median (Zombie Red-A :: VIAVILIDAD)` — MFI viabilidad (QC)
- Col 3: `Singlets/Esferoide/Vivas/Vivas CD19+ | Median (Spark Violet 500-A :: CD19)` — MFI del transgén

Controles single-cell (solo en NO ACTIVADOS):
- `UNS A549 CD19` — referencia de expresión máxima del transgén (MFI ≈ 267,188)
- `UNS A549 WT` — background autofluorescencia A549 (MFI ≈ 231,527)
- `UNS MRC5` — background fibroblastos

> **Parseo de nombre FCS:** El nombre tiene formato
> `Inmunofenotipo-{date} {experiment}-{sample_desc}_Unmixed.fcs`.
> La metadata se extrae de `{sample_desc}` (después del último `-`):
> grupo (SOLO/PBMC/CART/PBMC+CART), donante (D1/D2), tiempo (`\d+H`).

### Datos procesados (`data/processed/`)

| Archivo | Descripción | Script origen |
|---------|-------------|---------------|
| `flow_clean.rds` | Tabla unificada PBMC (40 filas, columnas canónicas) | `01_load_and_clean.R` |
| `flow_clean.csv` | Mismo contenido en CSV | `01_load_and_clean.R` |

### Estructura de columnas canónicas (`flow_clean.rds`)

| Columna | Descripción |
|---------|-------------|
| `sample_label` | Etiqueta de muestra |
| `pbmc` | "SI" / "NO" |
| `donor` | 1 / 2 |
| `cart` | "SI" / "NO" |
| `tiempo` | 24 / 48 / 72 (PBMC time; tiempo total − 24) |
| `activation` | "ACTIVADAS" / "NO_ACTIVADOS" |
| `data_type` | "CONTEOS" / "PORCENTAJES" |
| `pbmcs_live` | Conteo de PBMCs vivas (denominador común) |
| `cd3`, `cd4`, `cd4_hladr`, `cd8`, `cd8_hladr` | Linfocitos T y activación |
| `monocytes`, `macrophages`, `macrophages_cd11b`, `macrophages_hladr` | Macrófagos |
| `b_cells`, `nk` | Linfocitos B y NK |
| `singlets`, `singlets_live`, `singlets_dead` | Jerarquía de gating |

> Los archivos de viabilidad y expresión CAR **no se integran** en `flow_clean.rds`.
> Se leen directamente desde `data/raw/` en el script `07_viabilidad_esferoide.R`.

---

## Reglas críticas sobre fuente de datos

**Barras apiladas de composición** → desde CONTEOS, recalcular con `pbmcs_live`:
```
pct = (pop_count / pbmcs_live) × 100
```

**Porcentajes de subpoblaciones T (CD4/CD8 × HLA-DR)** → desde CONTEOS:
```
CD4⁺/HLA-DR⁻ % = (cd4 − cd4_hladr) / cd4 × 100
CD8⁺/HLA-DR⁻ % = (cd8 − cd8_hladr) / cd8 × 100
```

**Porcentajes de subpoblaciones de macrófagos** → usar PORCENTAJES directamente
(gate padre diferente en FlowJo: `macrophages_cd11b > macrophages` en CONTEOS → >100% falso).

**Viabilidad esferoide y PBMC (script 07)** → desde CONTEOS VIABILIDAD.

**CD19⁺ % (script 08)** → desde PORCENTAJES VIABILIDAD (col 12 ACTIVADAS / col 13 NO ACTIVADAS).

**CD3⁺ count (script 08)** → desde CONTEOS VIABILIDAD:
- ACTIVADOS col 15 (O): `CD3+ Vivas`
- NO ACTIVADOS col 18 (R): `PBMC's Vivas/CD3+`
- Punto t=48h (Sph+PBMC+CAR-T) ← valor Sph+PBMC @ t=48h; Sph+CAR-T @ t=48h = 0

**% CAR-T, CD4⁺, CD8⁺ (script 08)** → desde EXPRESIÓN CAR PORCENTAJES cols 6, 7, 8.

**Viabilidad normalizada (script 12)** → desde CONTEOS VIABILIDAD:
- Col 10/11 (ACT/NOACT): `Esferoide/Vivas` (total)
- Col 11/13 (ACT/NOACT): `Vivas CD19⁺`
- Col 12/12 (ACT/NOACT): `Vivas CD19⁻`
- Normalización: `(Vivas_grupo / Vivas_sph_only) × 100` por timepoint

**MFI CD19 (script 13)** → desde archivos MFI CD19+ (.xls):
- Col 3: MFI Spark Violet 500 en gate `Vivas CD19⁺`
- Metadata parseada del nombre FCS (grupo, donante, tiempo)
- Referencia: `UNS A549 CD19` para normalización

---

## Scripts activos

| Script | Estado | Input | Descripción |
|--------|--------|-------|-------------|
| `01_load_and_clean.R` | ✅ | `data/raw/*.xls` (4 POBLACIONES) | Carga, asigna nombres canónicos, exporta RDS+CSV |
| `03_stacked_bars.R` | ✅ | `flow_clean.rds` | Barras apiladas de composición inmune |
| `04_pbmc_live_timecourse.R` | ✅ | `flow_clean.rds` | Curvas temporales PBMCs vivas ±CAR-T |
| `05_immune_pop_timecourse.R` | ✅ | `flow_clean.rds` | Curvas 9 poblaciones inmunes (incl. NK cells) |
| `07_viabilidad_esferoide.R` | ✅ | `data/raw/*VIABILIDAD*.xlsx` | Curvas de viabilidad esferoide y PBMC |
| `08_car_expression.R` | ✅ | `data/raw/*VIABILIDAD PORCENTAJES*.xlsx`, `data/raw/EXPRESIÓN CAR *.xlsx` | CD19+ %, CD3+ count, % CAR-T, CD4+, CD8+ |
| `09_cd4_cd8_count_timecourse.R` | ✅ | `flow_clean.rds`, `data/raw/EXPRESIÓN CAR CONTEOS *.xlsx` | Conteos CD4⁺/CD8⁺ vivas: Sph+PBMC, Sph+PBMC+CAR-T, Sph+CAR-T |
| `10_morphology_spheroids.R` | ✅ | `data/raw/Medidas esferoides.xlsx` | Área, Diámetro y Circularidad del esferoide (n=1) |
| `11_esf_cd19_estrategia1.R` | ⏸️ | `data/raw/*ESTRATEGIA1*.xlsx` | Células esferoide CD3⁻ vivas y CD19⁺ (Estrategia 1 de gating) — temporalmente inactivo |
| `12_viabilidad_normalizada.R` | ✅ | `data/raw/*VIABILIDAD CONTEOS*.xlsx` | Viabilidad normalizada al Sph.only + citotoxicidad específica (total, CD19⁺, CD19⁻) |
| `13_mfi_cd19.R` | ✅ | `data/raw/MFI CD19+ *.xls` | MFI del transgén CD19 absoluta y normalizada a UNS A549 CD19 |

### Detalles de scripts activos

**`01_load_and_clean.R`**
- Lee los 4 archivos XLS de POBLACIONES (ACTIVADAS y NO ACTIVADAS, CONTEOS y %)
- Asigna nombres canónicos por posición de columna (header no es confiable)
- Exporta `flow_clean.rds` y `flow_clean.csv` (40 filas)

**`03_stacked_bars.R`**
- Usa solo `data_type == "CONTEOS"`, recalcula % con `pbmcs_live`
- Filtra `pbmc == "SI"`, promedia D1 y D2
- Poblaciones: CD4⁺, CD8⁺, B Cells, Monocytes, NK Cells — paleta Okabe-Ito
- Salida: `03_stacked_bars.pdf/.png` (250×110 mm)

**`04_pbmc_live_timecourse.R`**
- Y: conteo de `pbmcs_live` promediado entre donantes
- 2 líneas: `Sph+PBMC` y `Sph+PBMC+CAR-T`; la línea `Sph+PBMC+CAR-T` comparte t=24h con `Sph+PBMC`
- Eje X dual: tiempo PBMC + tiempo CAR-T
- Salida: `04_pbmc_live_noact.pdf/.png` y `04_pbmc_live_act.pdf/.png`

**`05_immune_pop_timecourse.R`**
- Misma estructura que script 04
- 8 poblaciones × 2 estados de activación = 16 figuras
- Leyendas: `Sph+PBMC` (gris) / `Sph+PBMC+CAR-T` (color de la población)

| Variable | Fuente | Cálculo | Color | Y-axis label |
|----------|--------|---------|-------|--------------|
| CD3⁺ count | CONTEOS | `cd3` | `#56B4E9` | "Live CD3⁺ cells (count)" |
| CD4⁺/HLA-DR⁻ % | CONTEOS | `(cd4 − cd4_hladr) / cd4 × 100` | `#0072B2` | "CD4⁺/HLA-DR⁻ (%)" |
| CD8⁺/HLA-DR⁻ % | CONTEOS | `(cd8 − cd8_hladr) / cd8 × 100` | `#D55E00` | "CD8⁺/HLA-DR⁻ (%)" |
| Macrophages count | CONTEOS | `macrophages` | `#D55E00` | "Live CD64⁺ macrophages (count)" |
| Macrophages CD11b⁺ % | **PORCENTAJES** | columna directa | `#D55E00` | "Macrophages CD11b⁺ (%)" |
| Macrophages HLA-DR⁺ % | **PORCENTAJES** | columna directa | `#882255` | "Macrophages HLA-DR⁺ (%)" |
| CD4⁺/HLA-DR⁺ % | CONTEOS | `cd4_hladr / cd4 × 100` | `#0072B2` | "CD4⁺/HLA-DR⁺ (%)" |
| CD8⁺/HLA-DR⁺ % | CONTEOS | `cd8_hladr / cd8 × 100` | `#D55E00` | "CD8⁺/HLA-DR⁺ (%)" |

**`07_viabilidad_esferoide.R`**
- Lee directamente desde `data/raw/` los 2 archivos CONTEOS VIABILIDAD (.xlsx)
- Variables: `Spheroid viable cells (count)` y `Viable PBMCs (count)`
- Figuras nombradas `07_esf_vivas_*` y `07_pbmc_vivas_*`
- 4 líneas: Sph. only, Sph+CAR-T, Sph+PBMC, Sph+PBMC+CAR-T
- Eje X: 4 tiempos para `esf_vivas` (24, 48, 72, 96 h), 3 tiempos para `pbmc_vivas` (48, 72, 96 h)
- Puntos compartidos: todas las líneas parten del baseline Sph.only @ t=24h;
  Sph+CAR-T comparte t=48h con Sph.only; Sph+PBMC+CAR-T comparte t=48h con Sph+PBMC
- Colores: `Sph. only`=#999999, `Sph+CAR-T`=#E69F00, `Sph+PBMC`=#555555, `Sph+PBMC+CAR-T`=#009E73
- Escala Y: límites 300–30 000, breaks c(1000, 2000, 3000, 5000, 10000, 20000, 30000), expansión inferior 8%
- Límite inferior 300 (permite mostrar Sph.only @ 96h ≈ 471 células)
- Labels en inglés
- Salida: 4 figuras (2 variables × 2 activaciones), 130×110 mm

**`08_car_expression.R`**
- Lee desde `data/raw/` los archivos VIABILIDAD CONTEOS, VIABILIDAD PORCENTAJES y EXPRESIÓN CAR PORCENTAJES
- 5 variables: CD19⁺ % (viabilidad), CD3⁺ count, % CAR-T, % CAR-T CD4⁺, % CAR-T CD8⁺
- CD19⁺: 4 grupos × 4 tiempos (24–96 h); con baselines compartidos (misma lógica script 07)
- CD3⁺ count: 2 grupos × 3 tiempos (48, 72, 96 h); t=48h es baseline (Sph+PBMC+CAR-T ← Sph+PBMC, Sph+CAR-T ← 0)
- % CAR-T, CD4⁺, CD8⁺: 2 grupos × 2 tiempos (72, 96 h)
- Fuentes de datos:
  - CD19⁺ % → PORCENTAJES VIABILIDAD col 12 (ACTIVADAS) / col 13 (NO ACTIVADAS)
  - CD3⁺ count → CONTEOS VIABILIDAD col 15/O (ACTIVADOS: `CD3+ Vivas`) / col 18/R (NO ACTIVADOS: `PBMC's Vivas/CD3+`)
  - % CAR-T, CD4⁺, CD8⁺ → EXPRESIÓN CAR PORCENTAJES cols 6, 7, 8
- Parseo de formato mixto: "7.67%", "26,5 %", 0.145 (proporción×100), "4.66E-2"
- Escala Y: 0–100% para porcentajes; adaptativa desde 0 para conteos
- Excepción: `08_cd3_count_noact` tiene eje Y fijo con límite superior 5000
- Títulos de figuras: `A549+MRC-5+{Activated/Non-activated PBMC}+CAR-T` (sin ± genérico)
- Labels de eje Y: "Viable CD3⁺ cells (count)", "CAR expression (%)", "% CAR-T CD4⁺ cells", "% CAR-T CD8⁺ cells"
- Salida: 10 figuras (5 variables × 2 activaciones), 120×100 mm

**`12_viabilidad_normalizada.R`**
- Lee los 2 archivos CONTEOS VIABILIDAD (mismos que script 07)
- Columnas adicionales: `Vivas CD19⁺` (ACT col 11, NOACT col 13), `Vivas CD19⁻` (col 12 ambos)
- Normaliza cada grupo al Sph. only del mismo timepoint: `(Vivas/Vivas_sph_only) × 100`
- 3 líneas: Sph+CAR-T, Sph+PBMC, Sph+PBMC+CAR-T (Sph. only = referencia 100%)
- Línea horizontal punteada en y=100%
- Baselines compartidos: todos @ t=24h = 100%; Sph+CAR-T @ t=48h = 100%
- Tabla: `results/tables/12_citotoxicidad_resumen.csv` con valores por donante + mean
- Salida: 6 figuras (3 variables × 2 activaciones), 130×110 mm

**`13_mfi_cd19.R`**
- Lee los 2 archivos MFI CD19+ (.xls) con metadata parseada del nombre FCS
- Parseo: `sub(".*-", "", sub("_Unmixed\\.fcs$", "", name))` → extrae `{sample_desc}`
- Grupo/donante/tiempo detectados por regex en la descripción
- Controles (NO ACTIVADOS): UNS A549 CD19 (MFI=267188), UNS A549 WT (MFI=231527), UNS MRC5
- MFI normalizada: `MFI_muestra / MFI_UNS_A549_CD19 × 100`
- 4 líneas: Sph. only, Sph+CAR-T, Sph+PBMC, Sph+PBMC+CAR-T
- Líneas de referencia: A549 CD19 (dashed), A549 WT (dotted) en plot absoluto; 100% en normalizado
- Tabla: `results/tables/13_mfi_cd19_resumen.csv` con valores por donante + mean + controles
- Salida: 4 figuras (2 métricas × 2 activaciones), 130×110 mm

---

## Figuras activas (`results/figures/`)

### Script 03

| Archivo | Descripción |
|---------|-------------|
| `03_stacked_bars.pdf/.png` | Composición inmune — 2 paneles (Act / No Act) |

### Script 04

| Archivo | Descripción |
|---------|-------------|
| `04_pbmc_live_noact.pdf/.png` | PBMCs vivas — no activadas |
| `04_pbmc_live_act.pdf/.png` | PBMCs vivas — activadas |

### Script 05

| Archivo | Descripción |
|---------|-------------|
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

### Script 07

| Archivo | Descripción |
|---------|-------------|
| `07_esf_vivas_noact.pdf/.png` | Spheroid viable cells — no activadas (4 líneas, 4 tiempos) |
| `07_esf_vivas_act.pdf/.png` | Spheroid viable cells — activadas (4 líneas, 4 tiempos) |
| `07_pbmc_vivas_noact.pdf/.png` | Viable PBMCs — no activadas (2 líneas, 3 tiempos) |
| `07_pbmc_vivas_act.pdf/.png` | Viable PBMCs — activadas (2 líneas, 3 tiempos) |

### Script 08

| Archivo | Descripción |
|---------|-------------|
| `08_cd19_pct_noact.pdf/.png` | % CD19⁺ viable — no activadas (4 líneas, 4 tiempos) |
| `08_cd19_pct_act.pdf/.png` | % CD19⁺ viable — activadas (4 líneas, 4 tiempos) |
| `08_cd3_count_noact.pdf/.png` | Viable CD3⁺ cells (count) — Non-activated PBMC+CAR-T (2 líneas: Sph+CAR-T, Sph+PBMC+CAR-T; **3 tiempos**: 48, 72, 96 h sph) |
| `08_cd3_count_act.pdf/.png` | Viable CD3⁺ cells (count) — Activated PBMC+CAR-T (2 líneas; 3 tiempos) |
| `08_cart_pct_noact.pdf/.png` | CAR expression (%) — Non-activated PBMC + CAR-T (2 líneas, 2 tiempos: 72, 96 h) |
| `08_cart_pct_act.pdf/.png` | CAR expression (%) — Activated PBMC + CAR-T (2 líneas, 2 tiempos) |
| `08_cd4_pct_noact.pdf/.png` | % CAR-T CD4⁺ cells — Non-activated PBMC+CAR-T (2 líneas, 2 tiempos) |
| `08_cd4_pct_act.pdf/.png` | % CAR-T CD4⁺ cells — Activated PBMC+CAR-T (2 líneas, 2 tiempos) |
| `08_cd8_pct_noact.pdf/.png` | % CAR-T CD8⁺ cells — Non-activated PBMC+CAR-T (2 líneas, 2 tiempos) |
| `08_cd8_pct_act.pdf/.png` | % CAR-T CD8⁺ cells — Activated PBMC+CAR-T (2 líneas, 2 tiempos) |

### Script 09_cd4_cd8_count_timecourse

| Archivo | Descripción |
|---------|-------------|
| `09_cd4_count_noact.pdf/.png` | Live CD4⁺ cells (count) — no activadas (3 líneas, 3 tiempos) |
| `09_cd4_count_act.pdf/.png` | Live CD4⁺ cells (count) — activadas (3 líneas, 3 tiempos) |
| `09_cd8_count_noact.pdf/.png` | Live CD8⁺ cells (count) — no activadas (3 líneas, 3 tiempos) |
| `09_cd8_count_act.pdf/.png` | Live CD8⁺ cells (count) — activadas (3 líneas, 3 tiempos) |

### Script 12

| Archivo | Descripción |
|---------|-------------|
| `12_viab_total_noact.pdf/.png` | Viabilidad normalizada esferoide total — no activadas (3 líneas, 4 tiempos, ref 100%) |
| `12_viab_total_act.pdf/.png` | Viabilidad normalizada esferoide total — activadas |
| `12_viab_cd19pos_noact.pdf/.png` | Viabilidad normalizada CD19⁺ — no activadas |
| `12_viab_cd19pos_act.pdf/.png` | Viabilidad normalizada CD19⁺ — activadas |
| `12_viab_cd19neg_noact.pdf/.png` | Viabilidad normalizada CD19⁻ — no activadas |
| `12_viab_cd19neg_act.pdf/.png` | Viabilidad normalizada CD19⁻ — activadas |

### Script 13

| Archivo | Descripción |
|---------|-------------|
| `13_mfi_cd19_noact.pdf/.png` | MFI CD19 absoluta — no activadas (4 líneas, refs UNS A549 CD19/WT) |
| `13_mfi_cd19_act.pdf/.png` | MFI CD19 absoluta — activadas |
| `13_mfi_cd19_norm_noact.pdf/.png` | MFI CD19 normalizada (% de A549 CD19) — no activadas |
| `13_mfi_cd19_norm_act.pdf/.png` | MFI CD19 normalizada (% de A549 CD19) — activadas |

### Tablas resumen (`results/tables/`)

| Archivo | Descripción | Script |
|---------|-------------|--------|
| `12_citotoxicidad_resumen.csv` | Viabilidad normalizada y citotoxicidad específica por donante + mean | 12 |
| `13_mfi_cd19_resumen.csv` | MFI CD19 absoluta y normalizada por donante + mean + controles | 13 |

---

## Anomalías conocidas en los datos

- **Macrófagos en NO ACTIVADAS CONTEOS POBLACIONES**: columnas `Macrófagos`,
  `Macrófagos CD11b⁺` y `Macrófagos HLA-DR⁺` tienen valores idénticos en todas las
  filas. En ACTIVADAS son distintos. Probable artefacto de gating en FlowJo.
- **D2 NO ACTIVADAS CAR-T a 96h**: 354 CAR-T vivas vs D1 con solo 43 — diferencia
  ~8× entre donantes al mismo tiempo. Puede reflejar variabilidad biológica real (n=2).
- **EXPRESIÓN CAR PORCENTAJES ACTIVADAS**: fila D1 PBMC+CAR-T a 72h tiene valores NA.
- **FLAG en viabilidad NO ACTIVADAS**: los archivos de NO ACTIVADAS llevan el sufijo
  `-FLAG` en el nombre original. Sin implicación en el análisis actual.

---

## Pendientes

### Scripts por implementar

| Script | Descripción | Datos disponibles |
|--------|-------------|-------------------|
| `06_heatmap.R` | Heatmap anotado (ComplexHeatmap) todas las poblaciones × muestras | `flow_clean.rds` ✅ |

### Notas de estado

- `flow_clean.rds` lee los 4 archivos de POBLACIONES directamente desde `data/raw/` (40 filas). ✅
- Los subdirectorios `24h/`, `48h/`, `72h/` están vacíos y pueden ignorarse.

---

## Limitaciones conocidas

- **n = 2 donantes**: sin poder estadístico para tests formales. Todo es descriptivo.
- **Sin replicados técnicos**: D1 y D2 son réplicas biológicas, no técnicas.
- **Viabilidad tumoral específica (CD19⁺)**: graficada en script 08 (`08_cd19_pct_*`),
  usando `Vivas CD19⁺` de los archivos PORCENTAJES VIABILIDAD.

---

## Ambiente y ejecución

```bash
conda activate omics-R
cd ~/bioinfo/projects/cart_spheroids_flow

# Pipeline de poblaciones inmunes
Rscript scripts/01_load_and_clean.R
Rscript scripts/03_stacked_bars.R
Rscript scripts/04_pbmc_live_timecourse.R
Rscript scripts/05_immune_pop_timecourse.R

# Pipeline de viabilidad (independiente, lee directo desde data/raw/)
Rscript scripts/07_viabilidad_esferoide.R

# Pipeline de expresión CAR y CD19+ (independiente)
Rscript scripts/08_car_expression.R

# Conteos CD4+/CD8+ PBMC (requiere flow_clean.rds + EXPRESIÓN CAR CONTEOS)
Rscript scripts/09_cd4_cd8_count_timecourse.R

# Morfología del esferoide (independiente)
Rscript scripts/10_morphology_spheroids.R
Rscript scripts/11_esf_cd19_estrategia1.R

# Viabilidad normalizada + citotoxicidad (independiente, lee CONTEOS VIABILIDAD)
Rscript scripts/12_viabilidad_normalizada.R

# MFI CD19 (independiente, lee MFI CD19+ .xls)
Rscript scripts/13_mfi_cd19.R
```

### Re-ejecución tras cambios en archivos fuente

- **Cambios en XLS de POBLACIONES** → re-ejecutar pipeline completo desde script 01 (y luego 03, 04, 05, 09_cd4_cd8)
- **Cambios en XLSX de VIABILIDAD CONTEOS** → re-ejecutar scripts 07 y 12
- **Cambios en XLSX de VIABILIDAD PORCENTAJES** → re-ejecutar script 08
- **Cambios en XLSX de EXPRESIÓN CAR PORCENTAJES** → re-ejecutar script 08
- **Cambios en XLSX de EXPRESIÓN CAR CONTEOS** → re-ejecutar scripts 08 y 09_cd4_cd8
- **Cambios en `Medidas esferoides.xlsx`** → re-ejecutar script 10_morphology
- **Cambios en XLS de MFI CD19+** → re-ejecutar script 13
