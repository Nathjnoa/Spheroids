# Fuentes de datos por figura — cart_spheroids_flow

Este documento describe, para cada figura generada en el proyecto, qué archivo Excel
de origen fue usado, qué columnas específicas se extrajeron y cómo se procesaron los
datos para producir la figura.

---

## Índice de archivos fuente

| Alias | Archivo en `data/raw/` | Formato | Filas de datos |
|-------|------------------------|---------|----------------|
| **CONT-ACT-POB** | `ACTIVADAS CONTEOS POBLACIONES (PBMC+CART) (1).xls` | XLS | 10 |
| **CONT-NOACT-POB** | `NO ACTIVADOS CONTEOS POBLACIONES (PBMC+CART) (1).xls` | XLS | 10 |
| **PCT-ACT-POB** | `ACTIVADAS PORCENTAJES POBLACIONES (PBMC+CART).xls` | XLS | 10 |
| **PCT-NOACT-POB** | `NO ACTIVADOS PORCENTAJES POBLACIONES (PBMC+CART).xls` | XLS | 10 |
| **CONT-ACT-VIAB** | `ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx` | XLSX | 19 |
| **CONT-NOACT-VIAB** | `NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx` | XLSX | 19 |
| **PCT-ACT-VIAB** | `ACTIVADAS PORCENTAJES VIABILIDAD (PBMC+CART).xlsx` | XLSX | 19 |
| **PCT-NOACT-VIAB** | `NO ACTIVADOS PORCENTAJES VIABILIDAD-FLAG (PBMC+CART).xlsx` | XLSX | 19 |
| **CONT-ACT-CAR** | `EXPRESIÓN CAR CONTEOS ACTIVADAS.xlsx` | XLSX | 9 |
| **CONT-NOACT-CAR** | `EXPRESIÓN CAR CONTEOS NO ACTIVADAS.xlsx` | XLSX | 9 |
| **PCT-ACT-CAR** | `EXPRESIÓN CAR PORCENTAJES ACTIVADAS.xlsx` | XLSX | 9 |
| **PCT-NOACT-CAR** | `EXPRESIÓN CAR PORCENTAJES NO ACTIVADAS.xlsx` | XLSX | 9 |
| **MFI-ACT** | `MFI CD19+ ACTIVADAS.xls` | XLS | 17 |
| **MFI-NOACT** | `MFI CD19+ NO ACTIVADOS.xls` | XLS | 21 + 4 controles |
| **MORFO** | `Medidas esferoides.xlsx` | XLSX | 16 |

> **Nota sobre tiempo:** Los archivos de POBLACIONES usan TIEMPO = 24/48/72 h, que
> representa el tiempo de contacto de las PBMCs (PBMC time), no el tiempo total del
> experimento. Los archivos de VIABILIDAD y EXPRESIÓN CAR usan el tiempo total del
> experimento (24/48/72/96 h, donde las PBMCs se añaden a las 24 h y las CAR-T a las 48 h).

---

## Script 01 — Datos procesados (archivo intermedio)

**Script:** `scripts/01_load_and_clean.R`
**Salida:** `data/processed/flow_clean.rds` (y `.csv`) — 40 filas × 31 columnas

Este script **no genera figuras**. Lee los 4 archivos de POBLACIONES y los unifica en
un único objeto R que sirve de entrada para los scripts 03, 04, 05, y 09.

| Archivo fuente | Columnas usadas | Columnas canónicas asignadas |
|----------------|-----------------|------------------------------|
| **CONT-ACT-POB** y **CONT-NOACT-POB** | Todas (28 cols) | Cols 1–5: metadata (`sample_label`, `pbmc`, `donor`, `cart`, `tiempo`); cols 6–28: poblaciones + `cd14neg_cd16neg` |
| **PCT-ACT-POB** y **PCT-NOACT-POB** | Todas (27 cols) | Cols 1–5: metadata; cols 6–27: poblaciones (sin `cd14neg_cd16neg`) |

Los nombres canónicos se asignan **por posición**, no por encabezado (el header del XLS
no es confiable). Los porcentajes se normalizan eliminando el símbolo `%` y convirtiendo
coma a punto decimal. Los conteos se convierten directamente a numérico.

---

## Script 03 — Barras apiladas de composición inmune

**Figura:** `03_stacked_bars.pdf/.png` (250×110 mm, 2 paneles lado a lado)

**Fuente:** `data/processed/flow_clean.rds` (generado por script 01)

### Columnas usadas de flow_clean

| Columna | Origen en XLS | Descripción |
|---------|---------------|-------------|
| `pbmcs_live` | col 14 de CONTEOS | Denominador común (PBMCs vivas totales) |
| `cd4` | col 16 | CD4⁺ vivas (conteo) |
| `cd8` | col 18 | CD8⁺ vivas (conteo) |
| `b_cells` | col 27 | Linfocitos B (conteo) |
| `monocytes` | col 22 | Monocitos vivos (conteo) |
| `nk` | col 26 | NK cells (conteo) |
| `cd14neg_cd16neg` | col 28 | Células no definidas / "Other" (solo en CONTEOS, 28 cols) |

### Procesamiento

1. Se filtran solo filas con `data_type == "CONTEOS"` y `pbmc == "SI"` (excluye grupos sin PBMC).
2. Cada población se convierte a porcentaje relativo a `pbmcs_live`:
   `pct = (conteo_pop / pbmcs_live) × 100`
3. Se promedian los valores de D1 y D2 (media aritmética) por combinación `activation × cart × tiempo`.
4. Dentro de cada barra, las 6 poblaciones se renormalizan a 100% (la suma de las 6 puede ser <100%
   del total de PBMCs vivas; la normalización hace que la barra sume exactamente 100%).
5. El eje X muestra `−CAR-T` y `+CAR-T` facetado por tiempo del esferoide (3 tiempos).
6. Se generan 2 paneles: PBMC no activadas (izquierda) y activadas (derecha), combinados con patchwork.

---

## Script 04 — Curvas temporales de PBMCs vivas

**Figuras:**
- `04_pbmc_live_noact.pdf/.png` (120×100 mm)
- `04_pbmc_live_act.pdf/.png` (120×100 mm)

**Fuente:** `data/processed/flow_clean.rds`

### Columna usada

| Columna | Origen en XLS | Descripción |
|---------|---------------|-------------|
| `pbmcs_live` | col 14 de CONT-ACT-POB / CONT-NOACT-POB | Conteo de PBMCs vivas totales |

### Procesamiento

1. Se filtran filas con `data_type == "CONTEOS"` y `pbmc == "SI"`.
2. Se generan 2 líneas:
   - **`Sph+PBMC` (−CAR-T):** promedio D1+D2 en `cart == "NO"`, tiempos 24/48/72 h (PBMC time).
   - **`Sph+PBMC+CAR-T` (+CAR-T):** el punto a t=24 h se toma del grupo `cart == "NO"` (baseline compartido antes de añadir CAR-T); los puntos a t=48 y 72 h provienen de `cart == "SI"`.
3. Los 3 tiempos del eje X (24/48/72 h PBMC) se etiquetan con tiempo dual:
   - `48 h esf / 24 h PBMC`
   - `72 h esf / 48 h PBMC / 24 h CAR-T`
   - `96 h esf / 72 h PBMC / 48 h CAR-T`
4. Eje Y: 0–7000 células, breaks cada 500 (mostrados solo los múltiplos de 1000).

---

## Script 05 — Curvas temporales de poblaciones inmunes (8 variables)

**Figuras:** 16 archivos `05_<variable>_<act/noact>.pdf/.png`

**Fuente:** `data/processed/flow_clean.rds`

### Variables graficadas y columnas usadas

| Variable | Figura | Archivo fuente | Columnas usadas | Cálculo |
|----------|--------|----------------|-----------------|---------|
| CD3⁺ count | `05_cd3_count_*` | CONT-ACT/NOACT-POB | `cd3` (col 15) | Directo (conteo) |
| CD4⁺/HLA-DR⁻ % | `05_cd4_hladr_neg_*` | CONT-ACT/NOACT-POB | `cd4` (col 16), `cd4_hladr` (col 17) | `(cd4 − cd4_hladr) / cd4 × 100` |
| CD8⁺/HLA-DR⁻ % | `05_cd8_hladr_neg_*` | CONT-ACT/NOACT-POB | `cd8` (col 18), `cd8_hladr` (col 19) | `(cd8 − cd8_hladr) / cd8 × 100` |
| Macrófagos count | `05_macrophages_count_*` | CONT-ACT/NOACT-POB | `macrophages` (col 23) | Directo (conteo) |
| Macrófagos CD11b⁺ % | `05_macrophages_cd11b_*` | **PCT-ACT/NOACT-POB** | `macrophages_cd11b` (col 24) | Directo desde PORCENTAJES† |
| Macrófagos HLA-DR⁺ % | `05_macrophages_hladr_*` | **PCT-ACT/NOACT-POB** | `macrophages_hladr` (col 25) | Directo desde PORCENTAJES† |
| CD4⁺/HLA-DR⁺ % | `05_cd4_hladr_pos_*` | CONT-ACT/NOACT-POB | `cd4` (col 16), `cd4_hladr` (col 17) | `cd4_hladr / cd4 × 100` |
| CD8⁺/HLA-DR⁺ % | `05_cd8_hladr_pos_*` | CONT-ACT/NOACT-POB | `cd8` (col 18), `cd8_hladr` (col 19) | `cd8_hladr / cd8 × 100` |

† Las subpoblaciones de macrófagos (CD11b⁺ y HLA-DR⁺) se toman directamente de
PORCENTAJES porque el gate padre en FlowJo es distinto: usar CONTEOS generaría
porcentajes >100% falsos (el denominador en el gate anidado difiere).

### Procesamiento común a todas las variables

1. Se filtran filas con `pbmc == "SI"`, separando CONTEOS y PORCENTAJES según la variable.
2. Se promedian D1 y D2.
3. Se grafican 2 líneas: `Sph+PBMC` (gris `#555555`) y `Sph+PBMC+CAR-T` (color de la población).
4. El punto a t=24 h de `Sph+PBMC+CAR-T` es compartido (toma el valor de `Sph+PBMC` @ t=24 h).
5. Tiempos y etiquetas iguales que script 04.

---

## Script 07 — Viabilidad del esferoide y CD19⁺ vivas

**Figuras:**
- `07_esf_vivas_noact.pdf/.png` (130×110 mm)
- `07_esf_vivas_act.pdf/.png` (130×110 mm)
- `07_cd19p_vivas_noact.pdf/.png` (130×110 mm)
- `07_cd19p_vivas_act.pdf/.png` (130×110 mm)

**Fuente:** Leído directamente desde `data/raw/` (no usa `flow_clean.rds`)

### Archivos y columnas

| Variable | Archivo fuente | Columna (ACTIVADAS) | Columna (NO ACTIVADAS) | Descripción |
|----------|---------------|---------------------|------------------------|-------------|
| Esf. vivas totales | **CONT-ACT-VIAB** / **CONT-NOACT-VIAB** | col 11 | col 11 | `Esferoide/Vivas` — células vivas del gate de esferoide |
| CD19⁺ vivas | **CONT-ACT-VIAB** / **CONT-NOACT-VIAB** | col 12 | col 13 | `Vivas CD19⁺` — células del esferoide CD19⁺ vivas |

> Metadata (pbmc, donor, cart): cols 3, 4, 5.
> Tiempo de contacto: extraído del nombre de la muestra (etiqueta texto) con regex.

### Procesamiento

1. El tiempo de contacto se extrae del `sample_label` (ej. "24 HORAS" → 24).
2. Se convierte a `sph_time` (tiempo total del esferoide):
   - `Sph. only`: `sph_time = contact_time` (sin offset)
   - `Sph+PBMC`: `sph_time = contact_time + 24`
   - `Sph+CAR-T`: `sph_time = contact_time + 48`
   - `Sph+PBMC+CAR-T`: `sph_time = contact_time + 48`
3. Se promedian D1 y D2 por grupo y `sph_time`.
4. Puntos compartidos:
   - Todos los grupos @ t=24 h ← `Sph. only` @ t=24 h (baseline pre-PBMC)
   - `Sph+PBMC+CAR-T` @ t=48 h ← `Sph+PBMC` @ t=48 h (antes de añadir CAR-T)
   - `Sph+CAR-T` @ t=48 h ← `Sph. only` @ t=48 h
5. Escala Y logarítmica: límites 300–30 000 (esf. vivas) o 50–15 000 (CD19⁺), con breaks fijos.
6. Las 4 curvas usan colores Okabe-Ito: Sph. only=#999999, Sph+CAR-T=#E69F00, Sph+PBMC=#555555, Sph+PBMC+CAR-T=#009E73.

---

## Script 08 — Expresión CAR y CD19⁺ % (5 variables)

**Figuras:** 10 archivos `08_<variable>_<act/noact>.pdf/.png` (120×100 mm)

**Fuentes:** Tres tipos de archivos diferentes según la variable.

### Variables, archivos y columnas

#### (1) `08_cd19_pct_*` — % células viables CD19⁺

| Archivo fuente | Columna (ACTIVADAS) | Columna (NO ACTIVADAS) | Descripción |
|----------------|---------------------|------------------------|-------------|
| **PCT-ACT-VIAB** | col 12 | — | `Vivas CD19⁺ (%)` |
| **PCT-NOACT-VIAB** | — | col 13 | `Vivas CD19⁺ (%)` |

- 4 grupos × 4 tiempos (24/48/72/96 h sph); mismos puntos compartidos que script 07.
- Los valores pueden venir en formato mixto: `"7.67%"`, `"26,5 %"`, proporciones `0.145`. Se normalizan a escala 0–100.

#### (2) `08_cd3_count_*` — Conteo de células CD3⁺ vivas

| Archivo fuente | Columna (ACTIVADAS) | Columna (NO ACTIVADAS) | Descripción |
|----------------|---------------------|------------------------|-------------|
| **CONT-ACT-VIAB** | col 15 (`O`) | — | `CD3⁺ Vivas` |
| **CONT-NOACT-VIAB** | — | col 18 (`R`) | `PBMC's Vivas/CD3⁺` |

- 2 grupos (`Sph+CAR-T` y `Sph+PBMC+CAR-T`) × 3 tiempos (48/72/96 h sph).
- Punto @ t=48 h: `Sph+PBMC+CAR-T` ← `Sph+PBMC` @ t=48 h; `Sph+CAR-T` ← 0 (no hay CD3⁺ antes de añadir CAR-T).
- `08_cd3_count_noact`: eje Y fijo con límite superior = 5000.

#### (3) `08_cart_pct_*` — % CAR-T de células vivas

| Archivo fuente | Columna | Descripción |
|----------------|---------|-------------|
| **PCT-ACT-CAR** y **PCT-NOACT-CAR** | col 6 | `Vivas/CAR-T (%)` |

- 2 grupos (`Sph+CAR-T` y `Sph+PBMC+CAR-T`) × 2 tiempos (72/96 h sph).

#### (4) `08_cd4_pct_*` — % CAR-T CD4⁺

| Archivo fuente | Columna | Descripción |
|----------------|---------|-------------|
| **PCT-ACT-CAR** y **PCT-NOACT-CAR** | col 7 | `Vivas/CAR-T CD4⁺ (%)` |

#### (5) `08_cd8_pct_*` — % CAR-T CD8⁺

| Archivo fuente | Columna | Descripción |
|----------------|---------|-------------|
| **PCT-ACT-CAR** y **PCT-NOACT-CAR** | col 8 | `Vivas/CAR-T CD8⁺ (%)` |

### Procesamiento común (variables 3–5)

- Solo 2 tiempos disponibles (72 y 96 h totales del experimento).
- Se promedian D1 y D2. Eje Y: 0–100%.

---

## Script 09 — Conteos CD4⁺ y CD8⁺ (3 grupos)

**Figuras:**
- `09_cd4_count_noact.pdf/.png` (120×100 mm)
- `09_cd4_count_act.pdf/.png` (120×100 mm)
- `09_cd8_count_noact.pdf/.png` (120×100 mm)
- `09_cd8_count_act.pdf/.png` (120×100 mm)

**Fuentes:** Dos fuentes combinadas según el grupo.

### Archivos y columnas

#### Grupos `Sph+PBMC` y `Sph+PBMC+CAR-T`

| Fuente | Archivo | Columnas usadas | Descripción |
|--------|---------|-----------------|-------------|
| `data/processed/flow_clean.rds` | CONT-ACT/NOACT-POB (vía script 01) | `cd4` (col 16), `cd8` (col 18) | Conteos de CD4⁺ y CD8⁺ vivas de PBMCs |

- `tiempo` en `flow_clean.rds` = PBMC time (24/48/72 h).

#### Grupo `Sph+CAR-T` (sin PBMCs)

| Fuente | Archivo | Columnas usadas | Descripción |
|--------|---------|-----------------|-------------|
| Leído directo | **CONT-ACT-CAR** y **CONT-NOACT-CAR** | col 7 (`Vivas/CAR-T CD4⁺`), col 8 (`Vivas/CAR-T CD8⁺`) | Conteos de subpoblaciones CD4⁺/CD8⁺ dentro de CAR-T vivas |

- TIEMPO en estos archivos = tiempo total del experimento (72, 96 h) → se convierte a PBMC time restando 24: `tiempo_pbmc = tiempo_total − 24`.

### Procesamiento

1. Se combinan las dos fuentes en un mismo `data.frame` con columnas `cd4`, `cd8`, `group`, `tiempo` (PBMC time).
2. Se promedian D1 y D2 por grupo y tiempo.
3. Baselines compartidos @ PBMC time 24 h:
   - `Sph+PBMC+CAR-T` @ 24 h ← `Sph+PBMC` @ 24 h
   - `Sph+CAR-T` @ 24 h = 0 (no hay células antes de añadir las CAR-T)
4. 3 tiempos en eje X (24/48/72 h PBMC = 48/72/96 h sph).
5. Eje Y adaptativo: límite superior = máximo redondeado al centenar más cercano (mínimo 500).

---

## Script 10 — Morfología del esferoide

**Figuras:**
- `10_area_noact.pdf/.png` (130×115 mm)
- `10_area_act.pdf/.png` (130×115 mm)
- `10_diametro_noact.pdf/.png` (130×115 mm)
- `10_diametro_act.pdf/.png` (130×115 mm)
- `10_circularidad_noact.pdf/.png` (130×115 mm)
- `10_circularidad_act.pdf/.png` (130×115 mm)

**Fuente:** `data/raw/Medidas esferoides.xlsx` (16 filas, n=1 por grupo × tiempo)

### Columnas del Excel

| Columna en Excel | Nombre canónico | Descripción |
|------------------|-----------------|-------------|
| `UNIDAD EXPERIMENTAL` | `unit` | Identificador de la unidad |
| `TIEMPO` | `sph_time` | Tiempo total del esferoide (24/48/72/96 h) |
| `PBMC` | `pbmc` | "SI" / "NO" |
| `ACTIVACIÓN` | `activation` | "SI" / "NO" (NA para grupos sin PBMC) |
| `CAR-T` | `cart` | "SI" / "NO" |
| `AREA` | `area` | Área del esferoide (µm²) |
| `DIAMETRO` | `diametro` | Diámetro del esferoide (µm) |
| `CIRCULARIDAD` | `circularidad` | Circularidad (0–1, adimensional) |

### Procesamiento

1. Los grupos sin PBMCs (`pbmc == "NO"`) tienen `activation == NA` → se incluyen en **ambas** figuras (act y noact) como controles compartidos.
2. Los grupos con PBMCs se filtran por `activation == "SI"` (activadas) o `"NO"` (no activadas).
3. **No hay promedio de donantes** (n=1, medición de microscopía única por condición).
4. Puntos compartidos (misma lógica que script 07):
   - Todos los grupos @ t=24 h ← `Sph. only` @ t=24 h
   - `Sph+CAR-T` @ t=48 h ← `Sph. only` @ t=48 h
   - `Sph+PBMC+CAR-T` @ t=48 h ← `Sph+PBMC` @ t=48 h (del estado de activación correspondiente)
5. Escalas Y:
   - Área y diámetro: escala continua con límites y breaks calculados globalmente (mismos para act y noact, usando `pretty()`).
   - Circularidad: escala lineal fija 0–1, breaks cada 0.2.

---

## Script 12 — Viabilidad normalizada y citotoxicidad específica

**Figuras:**
- `12_viab_total_noact.pdf/.png`, `12_viab_total_act.pdf/.png` (130×110 mm)
- `12_viab_cd19pos_noact.pdf/.png`, `12_viab_cd19pos_act.pdf/.png`
- `12_viab_cd19neg_noact.pdf/.png`, `12_viab_cd19neg_act.pdf/.png`

**Tabla:** `results/tables/12_citotoxicidad_resumen.csv`

**Fuente:** Leído directamente desde `data/raw/`

### Archivos y columnas

| Variable | Archivo fuente | Columna (ACTIVADAS) | Columna (NO ACTIVADAS) | Descripción |
|----------|---------------|---------------------|------------------------|-------------|
| Esferoide total vivas | **CONT-ACT-VIAB** / **CONT-NOACT-VIAB** | col 10 | col 11 | `Esferoide/Vivas` |
| Vivas CD19⁺ | **CONT-ACT-VIAB** / **CONT-NOACT-VIAB** | col 11 | col 13 | `Vivas CD19⁺` |
| Vivas CD19⁻ | **CONT-ACT-VIAB** / **CONT-NOACT-VIAB** | col 12 | col 12 | `Vivas CD19⁻` |

> Nota: los índices difieren entre ACTIVADAS (29 cols) y NO ACTIVADAS (22 cols) por la
> estructura de gating exportada desde FlowJo.

### Procesamiento

1. Se normalizan los conteos de cada grupo al `Sph. only` del **mismo timepoint**:
   `% viabilidad = (Vivas_grupo / Vivas_sph_only) × 100`
2. Sph. only = referencia 100% (no se grafica como curva, sino como línea de referencia punteada en y=100).
3. 3 líneas graficadas: `Sph+CAR-T`, `Sph+PBMC`, `Sph+PBMC+CAR-T`.
4. Baselines compartidos idénticos a script 07 (todos @ t=24 h = 100%; `Sph+CAR-T` @ t=48 h = 100%).
5. Se promedian D1 y D2; también se exportan valores por donante en la tabla CSV.

---

## Script 13 — MFI de CD19 en células CD19⁺ vivas

**Figuras:**
- `13_mfi_cd19_noact.pdf/.png` (130×110 mm)
- `13_mfi_cd19_act.pdf/.png` (130×110 mm)
- `13_mfi_cd19_norm_noact.pdf/.png` (130×110 mm)
- `13_mfi_cd19_norm_act.pdf/.png` (130×110 mm)

**Tabla:** `results/tables/13_mfi_cd19_resumen.csv`

**Fuente:** Leído directamente desde `data/raw/`

### Archivos y columnas

| Variable | Archivo fuente | Columna | Descripción |
|----------|---------------|---------|-------------|
| MFI viabilidad (QC) | **MFI-ACT** y **MFI-NOACT** | col 2 | `Singlets/Esferoide/Vivas \| Median (Zombie Red-A :: VIABILIDAD)` |
| MFI CD19 absoluta | **MFI-ACT** y **MFI-NOACT** | col 3 | `Singlets/Esferoide/Vivas/Vivas CD19⁺ \| Median (Spark Violet 500-A :: CD19)` |
| Nombre FCS (metadata) | **MFI-ACT** y **MFI-NOACT** | col 1 | Nombre del archivo FCS exportado por FlowJo |

### Extracción de metadata desde el nombre del archivo FCS

Los archivos XLS no tienen columnas separadas de grupo/donante/tiempo. Toda la metadata
se parsea del nombre del archivo FCS en col 1 con formato:

```
Inmunofenotipo-{fecha} {experimento}-{descripcion}_Unmixed.fcs
```

La descripción (último segmento antes de `_Unmixed.fcs`) contiene:
- **Grupo:** SOLO / PBMC / CART / PBMC+CART
- **Donante:** D1 / D2
- **Tiempo:** `\d+H` (ej. `72H`)

### Controles de referencia (solo en **MFI-NOACT**)

| Control | MFI típico | Uso |
|---------|-----------|-----|
| `UNS A549 CD19` | ~267,188 | Referencia para normalización (100%) |
| `UNS A549 WT` | ~231,527 | Background de autofluorescencia A549 |
| `UNS MRC5` | (variable) | Background de fibroblastos |

### Procesamiento

1. Se excluyen las filas de `Mean` y `SD` que FlowJo añade al final.
2. MFI normalizada: `MFI_muestra / MFI_UNS_A549_CD19 × 100` (expresa cuánto % de la expresión
   máxima del transgén conservan las células).
3. Los controles `UNS` se grafican como líneas de referencia (A549 CD19 = dashed, A549 WT = dotted)
   en las figuras de MFI absoluta.
4. En las figuras normalizadas, se dibuja una línea en y=100% como referencia.
5. Se promedian D1 y D2; se exportan valores por donante + controles en la tabla CSV.

---

## Notas generales de procesamiento

### Convención de baselines compartidos

Todos los scripts que grafican curvas temporales con 4 grupos aplican la misma lógica:

| Punto compartido | Grupo destino | Fuente del valor |
|------------------|---------------|------------------|
| t=24 h sph (pre-PBMC) | Todos los grupos | `Sph. only` @ t=24 h |
| t=48 h sph (pre-CAR-T) | `Sph+PBMC+CAR-T` | `Sph+PBMC` @ t=48 h |
| t=48 h sph | `Sph+CAR-T` | `Sph. only` @ t=48 h |

Esta convención refleja que en el momento del baseline, el grupo aún no había recibido el
tratamiento adicional (PBMC o CAR-T), por lo que su estado es idéntico al del control.

### Promediado de donantes

Todos los scripts promedian aritméticamente D1 y D2 antes de graficar. El proyecto tiene
n=2 réplicas biológicas → no se realizan tests estadísticos formales, todo es descriptivo.

### Paleta de colores (Okabe-Ito, colorblind-safe)

| Grupo | Color HEX | Forma |
|-------|-----------|-------|
| Sph. only | `#999999` (gris claro) | cuadrado (15) |
| Sph+CAR-T | `#E69F00` (naranja) | diamante (18) |
| Sph+PBMC | `#555555` (gris oscuro) | círculo (16) |
| Sph+PBMC+CAR-T | `#009E73` (verde) | triángulo (17) |
