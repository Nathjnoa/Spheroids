# Viabilidad normalizada + MFI CD19 — Diseño

**Fecha:** 2026-03-21
**Estado:** Aprobado
**Problema:** Las curvas de viabilidad actuales (script 07, conteos brutos de Esferoide/Vivas) no discriminan el efecto citotóxico de las CAR-T del decaimiento natural del esferoide. Además, se quiere evaluar si la intensidad de expresión del transgén CD19 cambia con el tiempo/tratamiento.

---

## Contexto biológico

### Composición del esferoide (~50,000 células)

| Subpoblación | % del esferoide | Células | CD19 |
|---|---|---|---|
| MRC-5 (fibroblastos) | 66% | ~33,000 | CD19⁻ |
| A549 no transducidas | 16.5% | ~8,250 | CD19⁻ |
| A549 transducidas | 16.5% | ~8,250 | CD19⁺ |

- Las CAR-T anti-CD19 solo deberían matar las A549 transducidas (CD19⁺).
- Las A549 WT y MRC-5 son controles internos de bystander killing.
- El transgén CD19 fue introducido por transducción lentiviral; su MFI puede variar por silenciamiento epigenético, trogocitosis o selección clonal.

### Estrategia de gating

```
Esferoide total → Esferoide vivas (discriminación por tamaño FSC/SSC)
                     → Vivas CD19⁺
                     → Vivas CD19⁻
```

No hay gate intermedio de CD3⁻. La discriminación de células tumorales/fibroblastos se hace por scatter.

### Interpretación combinada conteo + MFI

| Conteo CD19⁺ | MFI CD19 | Interpretación |
|---|---|---|
| Baja | Estable | Killing selectivo de CD19⁺ por CAR-T |
| Baja | Baja | Killing + downregulation/silenciamiento (posible escape) |
| Estable | Baja | Downregulation sin muerte celular (resistencia) |
| Estable | Estable | Sin efecto de las CAR-T |

---

## Sección 1: Datos y parseo

### Archivos de entrada

#### Datos existentes (conteos de viabilidad, usados por script 07)

| Archivo | Contenido |
|---|---|
| `ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx` | Conteos, PBMCs activadas |
| `NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx` | Conteos, PBMCs no activadas |

Columnas relevantes: `Vivas CD19+`, `Vivas CD19-`, `Esferoide/Vivas` (ya mapeadas en script 07).

#### Datos nuevos (MFI)

| Archivo | Filas útiles | Contenido |
|---|---|---|
| `MFI CD19+ ACTIVADAS.xls` | 17 (excluir Mean/SD) | MFI Zombie Red + MFI CD19, PBMCs activadas |
| `MFI CD19+ NO ACTIVADOS.xls` | 21 (excluir Mean/SD) | Idem no activadas + 4 controles single-cell |

Columnas:

| Columna | Canal | Gate | Contenido |
|---|---|---|---|
| Col 2 | Zombie Red-A :: VIAVILIDAD | Singlets/Esferoide/Vivas | MFI de viabilidad (QC, no métrica principal) |
| Col 3 | Spark Violet 500-A :: CD19 | Singlets/Esferoide/Vivas/Vivas CD19+ | MFI del transgén CD19 |

### Parseo de metadata desde nombres FCS

La metadata se parsea del nombre del archivo FCS (col 1):

| Patrón en nombre | PBMC | CART | Donante | Grupo |
|---|---|---|---|---|
| `SOLO` | NO | NO | — | Sph. only |
| `CART D1/D2` (sin "PBMCs") | NO | SI | 1/2 | Sph+CAR-T |
| `PBMCs D1/D2` (sin "CART") | SI | NO | 1/2 | Sph+PBMC |
| `PBMCs...CART D1/D2` | SI | SI | 1/2 | Sph+PBMC+CAR-T |
| `UNS A549 CD19` | — | — | — | Control (A549 transducida) |
| `UNS A549 WT` | — | — | — | Control (A549 wild-type) |
| `UNS MRC5` | — | — | — | Control (fibroblastos) |

Tiempo: extraer con regex `(\d+)\s*[hH]` del nombre.

### Columnas canónicas del dataset parseado

```
sample_name, activation, group, donor, sph_time,
mfi_zombie_red, mfi_cd19
```

### Controles single-cell (solo en NO ACTIVADOS)

| Control | MFI CD19 esperada | Utilidad |
|---|---|---|
| `UNS A549 CD19` | Alta (transducidas) | Referencia de expresión máxima del transgén |
| `UNS A549 WT` | Baja/nula | Background de autofluorescencia A549 |
| `UNS MRC5` | Baja/nula | Background de autofluorescencia fibroblastos |

---

## Sección 2: Métricas a calcular

### Métrica A — Viabilidad normalizada al control (datos existentes)

Usando los conteos de los archivos VIABILIDAD CONTEOS:

| Métrica | Fórmula | Interpretación |
|---|---|---|
| % Viabilidad normalizada | `(Vivas_grupo / Vivas_sph_only) × 100` por timepoint | 100% = sin efecto, <100% = killing |
| % Citotoxicidad específica | `(1 − Vivas_grupo / Vivas_sph_only) × 100` | 0% = sin killing, positivo = killing |

Se calcula para:
- **Esferoide/Vivas total** (todas las células del esferoide)
- **Vivas CD19⁺** (solo las transducidas — target de las CAR-T)
- **Vivas CD19⁻** (A549 WT + MRC-5 — control de bystander killing)

### Métrica B — MFI de CD19 (datos nuevos)

| Métrica | Qué mide | Gate |
|---|---|---|
| MFI CD19 en Vivas CD19⁺ | Intensidad del transgén en las que sobreviven | `Esferoide/Vivas/Vivas CD19⁺` |
| MFI CD19 normalizada | `MFI_muestra / MFI_UNS_A549_CD19 × 100` | Fracción de la expresión máxima del transgén (%) |

La MFI de Zombie Red en `Esferoide/Vivas` es QC interno (no métrica principal). Si sube dentro del gate de vivas, indica compromiso temprano de membrana (early apoptosis que no cruza el threshold del gate).

---

## Sección 3: Figuras propuestas

### Script `12_viabilidad_normalizada.R`

Fuente: archivos CONTEOS VIABILIDAD existentes en `data/raw/`.

**Figura 12.1 — Viabilidad normalizada del esferoide total**
- Y: `% Viabilidad = (Vivas_grupo / Vivas_sph_only) × 100`
- X: sph_time (24, 48, 72, 96 h) con labels triple (sph / PBMC / CAR-T)
- Líneas: Sph+CAR-T, Sph+PBMC, Sph+PBMC+CAR-T (Sph. only = referencia 100%)
- Línea horizontal punteada en y=100%
- 2 figuras: `12_viab_total_act.pdf/.png`, `12_viab_total_noact.pdf/.png`
- Paleta Okabe-Ito, tema `theme_flow`

**Figura 12.2 — Viabilidad normalizada CD19⁺ vs CD19⁻**
- Mismo formato que 12.1 pero para `Vivas CD19⁺` y `Vivas CD19⁻` por separado
- Si las CAR-T matan selectivamente: la línea CD19⁺ cae, la CD19⁻ se mantiene ~100%
- 4 figuras: `12_viab_cd19pos_act/noact.pdf/.png`, `12_viab_cd19neg_act/noact.pdf/.png`

### Script `13_mfi_cd19.R`

Fuente: archivos MFI nuevos en `data/raw/`.

**Figura 13.1 — MFI de CD19 en Vivas CD19⁺ a lo largo del tiempo**
- Y: MFI Spark Violet 500 (escala lineal)
- X: sph_time con labels triple
- Líneas: mismos grupos que 12.1
- Líneas horizontales de referencia: MFI de `UNS A549 CD19` (alto) y `UNS A549 WT` (background)
- 2 figuras: `13_mfi_cd19_act.pdf/.png`, `13_mfi_cd19_noact.pdf/.png`

**Figura 13.2 — MFI de CD19 normalizada**
- Y: `MFI_muestra / MFI_UNS_A549_CD19 × 100` (% de expresión máxima)
- Misma estructura que 13.1 pero en escala relativa
- 2 figuras: `13_mfi_cd19_norm_act.pdf/.png`, `13_mfi_cd19_norm_noact.pdf/.png`

### Dimensiones y estilo (todos los scripts)
- 130×110 mm, paleta Okabe-Ito, tema `theme_flow`
- Leyenda 2 filas si >2 líneas
- Labels en inglés

### Resumen de outputs gráficos

| Script | Figuras | Datos fuente |
|---|---|---|
| `12_viabilidad_normalizada.R` | 6 figuras | CONTEOS VIABILIDAD existentes |
| `13_mfi_cd19.R` | 4 figuras | MFI CD19+ nuevos |

---

## Sección 4: Tablas resumen para manuscrito

### `results/tables/12_citotoxicidad_resumen.csv`

| Columna | Contenido |
|---|---|
| activation | ACTIVADAS / NO_ACTIVADOS |
| group | Sph+CAR-T, Sph+PBMC, Sph+PBMC+CAR-T |
| sph_time | 48, 72, 96 h |
| viab_total_pct | % Viabilidad normalizada (esferoide total) |
| viab_cd19pos_pct | % Viabilidad normalizada (CD19⁺) |
| viab_cd19neg_pct | % Viabilidad normalizada (CD19⁻) |
| citotox_total_pct | % Citotoxicidad específica (esferoide total) |
| citotox_cd19pos_pct | % Citotoxicidad específica (CD19⁺) |

### `results/tables/13_mfi_cd19_resumen.csv`

| Columna | Contenido |
|---|---|
| activation | ACTIVADAS / NO_ACTIVADOS |
| group | Todos los grupos + controles |
| sph_time | Timepoint |
| donor | D1 / D2 / mean |
| mfi_cd19 | MFI absoluta (Spark Violet 500) |
| mfi_cd19_norm_pct | MFI normalizada a UNS A549 CD19 (%) |

Las tablas incluyen valores por donante individual y el promedio.
