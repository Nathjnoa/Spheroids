# Guía de interpretación de figuras — cart_spheroids_flow

Este documento explica, figura por figura, qué se está midiendo, de dónde provienen
los datos, cómo se calcula la métrica del eje Y, y cómo interpretar los resultados.

---

## Contexto general del experimento

El modelo consiste en esferoides 3D de **A549** (adenocarcinoma pulmonar, CD19⁺ por
transducción lentiviral) y **MRC-5** (fibroblastos, CD19⁻) co-cultivados con:

- **PBMCs** de 2 donantes sanos (D1 y D2): añadidas a las 24h desde la formación del
  esferoide. Se prueban en dos estados: **no activadas** y **activadas**.
- **Células CAR-T** de los mismos donantes: añadidas a las 48h (24h después de las PBMCs).
  Reconocen y eliminan células CD19⁺.

Todos los experimentos se miden en 4 puntos temporales (**24, 48, 72, 96 h** desde la
formación del esferoide). Los dos donantes funcionan como **réplicas biológicas** (n = 2);
no hay poder estadístico para tests formales — todos los análisis son descriptivos.

### Grupos experimentales

| Código | PBMC | CAR-T | Tiempos medidos |
|--------|------|-------|-----------------|
| Sph. only | No | No | 24, 48, 72, 96 h |
| Sph+CAR-T | No | Sí | 72, 96 h (inicio real) |
| Sph+PBMC | Sí | No | 48, 72, 96 h |
| Sph+PBMC+CAR-T | Sí | Sí | 72, 96 h (inicio real) |

### Convención de puntos compartidos (baselines)

Para conectar las curvas con sentido temporal, se aplica la siguiente lógica en todos
los scripts de curvas temporales:

- **t = 24 h (todos los grupos):** antes de añadir PBMCs ni CAR-T, todos los grupos
  parten del mismo esferoide. Se usa el valor de **Sph. only @ t = 24 h** como punto
  inicial compartido.
- **t = 48 h (Sph+CAR-T):** a las 48 h aún no se han añadido CAR-T a este grupo.
  Se usa el valor de **Sph. only @ t = 48 h** como punto de inicio.
- **t = 48 h (Sph+PBMC+CAR-T):** a las 48 h las CAR-T aún no se han añadido. Se usa
  el valor de **Sph+PBMC @ t = 48 h** como punto de inicio.

---

## Script 07 — Viabilidad absoluta del esferoide y de las PBMCs

### Archivo fuente

| Condición | Archivo |
|-----------|---------|
| Activadas | `ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx` |
| No activadas | `NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx` |

Estos archivos son exportaciones del **FlowJo Table Editor** con los conteos de células
en cada gate para cada muestra.

### Figuras `07_esf_vivas_*` — Viable cells in the spheroid (count)

**Columna leída:**
- ACTIVADAS → col 10: `Esferoide/Vivas`
- NO ACTIVADAS → col 11: `Esferoide/Vivas`

**Qué representa:** el número absoluto de células **vivas** dentro del gate
`Singlets/Esferoide` del esferoide. Este gate captura tanto células A549 (CD19⁺) como
MRC-5 (CD19⁻). La muerte celular (por CAR-T u otros mecanismos) se refleja como una
caída en este conteo a lo largo del tiempo.

**Eje Y:** número de células (conteo bruto de FlowJo). Escala log con límites 300–30,000.

**Interpretación:** una reducción en los grupos tratados con CAR-T respecto a Sph. only
indica actividad citotóxica general sobre el esferoide.

---

### Figuras `07_pbmc_vivas_*` — Viable PBMCs (count)

**Columna leída:**
- ACTIVADAS → col 14: `PBMC Vivas`
- NO ACTIVADAS → col 17: `PBMC's Vivas`

**Qué representa:** el número absoluto de PBMCs vivas en el co-cultivo (gate separado
del esferoide). Refleja la expansión o contracción de la población inmune a lo largo
del tiempo.

**Eje Y:** número de células (conteo bruto). Escala log.

---

## Script 12 — Viabilidad normalizada y citotoxicidad específica

### Archivo fuente

Los mismos archivos CONTEOS VIABILIDAD del script 07, pero se leen columnas adicionales:

| Columna | ACTIVADAS | NO ACTIVADAS |
|---------|-----------|--------------|
| Esferoide/Vivas (total) | col 10 | col 11 |
| Vivas CD19⁺ | col 11 | col 13 |
| Vivas CD19⁻ | col 12 | col 12 |

### Cálculo de la viabilidad normalizada

El número absoluto de células vivas por grupo varía entre muestras y tiempos por
razones no relacionadas con el tratamiento (densidad inicial del esferoide, eficiencia
del gating, etc.). Para aislar el **efecto del tratamiento**, cada grupo se normaliza al
control sin tratamiento del mismo timepoint:

```
Viabilidad normalizada (%) = (Vivas_grupo / Vivas_sph_only) × 100
```

Donde:
- `Vivas_grupo` = media de D1 y D2 del grupo en ese timepoint
- `Vivas_sph_only` = valor de Sph. only en el mismo timepoint y condición de activación

**El resultado es relativo al control Sph. only = 100%.**

- **= 100%:** el grupo tiene el mismo número de células vivas que el esferoide sin tratar.
- **< 100%:** hay menos células vivas → el tratamiento redujo la viabilidad.
- **> 100%:** hay más células vivas → inesperado en este contexto; podría reflejar
  proliferación o variabilidad técnica.

#### Baselines en estas figuras

Dado que todos los grupos parten del mismo esferoide antes del tratamiento, a t = 24 h
todos valen **100% por definición** (se fuerza manualmente). Igualmente, Sph+CAR-T a
t = 48 h = 100% (las CAR-T aún no se añadieron), y Sph+PBMC+CAR-T a t = 48 h hereda
el valor normalizado de Sph+PBMC @ t = 48 h.

La línea horizontal punteada en y = 100% sirve de referencia visual.

### Figuras `12_viab_total_*` — Viabilidad normalizada del esferoide total

**Qué se grafica:** la viabilidad normalizada calculada sobre el conteo total de células
vivas en el gate del esferoide (A549 + MRC-5 juntos).

**Eje Y:** `Normalized viability (%)`. Valor relativo al control Sph. only.

**Interpretación:** refleja el efecto global del tratamiento sobre la supervivencia
celular del esferoide. No distingue entre tipos celulares.

---

### Figuras `12_viab_cd19pos_*` — Viabilidad normalizada CD19⁺

**Qué se grafica:** lo mismo que arriba pero solo sobre las células **Vivas CD19⁺**
(principalmente células A549 transducidas, que expresan el antígeno diana del CAR-T).

**Eje Y:** `Normalized viability CD19⁺ (%)`.

**Interpretación:** esta es la métrica más relevante para evaluar la **actividad
citotóxica específica del CAR-T**. Si el CAR-T funciona, debería verse una caída
selectiva en este subgrupo, mayor que en el esferoide total o en las células CD19⁻.

---

### Figuras `12_viab_cd19neg_*` — Viabilidad normalizada CD19⁻

**Qué se grafica:** viabilidad normalizada sobre las células **Vivas CD19⁻** (principalmente
células MRC-5 y posiblemente A549 que perdieron expresión de CD19).

**Eje Y:** `Normalized viability CD19⁻ (%)`.

**Interpretación:** sirve como **control interno de especificidad**. Si el CAR-T actúa
específicamente sobre CD19⁺, las células CD19⁻ deberían mostrar menos o ninguna reducción.
Si CD19⁻ también cae, puede indicar:
- Citotoxicidad por bystander effect (fragmentación del esferoide)
- Efecto no específico de las PBMCs
- Cambio en la composición A549:MRC-5 dentro del gate

### Tabla de resultados: `12_citotoxicidad_resumen.csv`

Contiene por cada combinación `activation × group × sph_time`:
- `viab_total_pct`, `viab_cd19pos_pct`, `viab_cd19neg_pct`: viabilidad normalizada (%)
- `citotox_total_pct`, `citotox_cd19pos_pct`: citotoxicidad específica = `100 - viabilidad_normalizada`
- Filas separadas para D1, D2 y la media (`donor = "mean"`)

---

## Script 13 — MFI de CD19 (intensidad de expresión del transgén)

### ¿Qué es la MFI?

**MFI** (Median Fluorescence Intensity) es la mediana de la distribución de
fluorescencia de un canal en un gate determinado. A diferencia del conteo de células,
la MFI mide **cuánta proteína CD19 hay en la superficie de las células**, no cuántas
células hay. Valores altos = más CD19 por célula.

El canal utilizado es **Spark Violet 500-A**, donde está conjugado el anticuerpo
anti-CD19 del panel.

### Gate analizado

`Singlets/Esferoide/Vivas/Vivas CD19⁺`

Solo se analiza el subconjunto de células del esferoide que son vivas y **ya son CD19⁺**
(positivas para el transgén). Esto significa que la MFI refleja la intensidad de
expresión del antígeno en las células que siguen siendo positivas.

### Archivo fuente

| Condición | Archivo | Filas útiles |
|-----------|---------|--------------|
| Activadas | `MFI CD19+ ACTIVADAS.xls` | 17 muestras experimentales |
| No activadas | `MFI CD19+ NO ACTIVADOS.xls` | 17 muestras experimentales + 4 controles |

Estructura de cada archivo (3 columnas):
1. Nombre del archivo FCS (contiene toda la metadata)
2. MFI canal Zombie Red (viabilidad) — columna de QC, no graficada
3. MFI canal Spark Violet 500 (CD19) — **la variable de interés**

#### Parseo de metadata desde el nombre FCS

Los archivos de FlowJo no tienen columnas separadas de metadata. Toda la información
(grupo, donante, tiempo) está codificada en el nombre del archivo FCS, que sigue el
formato:

```
Inmunofenotipo-{fecha} {nombre_experimento}-{descripción}_Unmixed.fcs
```

El nombre del experimento contiene "PBMCs CART" lo cual confundiría la detección de
grupo si se busca en el nombre completo. Por eso el script extrae **solo la
`{descripción}`** (todo lo que aparece después del último guión, antes de
`_Unmixed.fcs`) y busca ahí:

- Grupo: presencia de "PBMC" y/o "CART" y/o "SOLO" en la descripción
- Donante: "D1" o "D2" como palabras completas (para no confundir con "CD19")
- Tiempo: primer número seguido de "H" (ej. "48H")

### Controles de célula única (single-cell controls)

Los controles están presentes solo en el archivo de NO ACTIVADOS y sirven como
referencia de la expresión del transgén en condiciones sin mezcla de tipos celulares:

| Control | Significado | MFI CD19 observada |
|---------|-------------|-------------------|
| UNS A549 CD19 | A549 transducidas con CD19, sin esferoide ni PBMC | ≈ 267,188 |
| UNS A549 WT | A549 wild-type (sin CD19), background autofluorescencia | ≈ 231,527 |
| UNS MRC5 | Fibroblastos, background | — |
| ESFEROIDE_BASELINE | Esferoide formado pero sin tratamiento | — |

La diferencia entre A549 CD19 (≈ 267k) y A549 WT (≈ 231k) es relativamente pequeña
en valor absoluto, lo que refleja que ambas líneas tienen autofluorescencia alta en
este canal. La MFI "verdadera" del transgén CD19 sería la diferencia entre ambos
valores (≈ 35,000 unidades).

---

### Figuras `13_mfi_cd19_*` — MFI CD19 absoluta

**Eje Y:** `MFI CD19 (Spark Violet 500)`. Valores de mediana de fluorescencia,
escala lineal de 0 a 350,000 (fija en ambas figuras para comparación directa).

**Líneas de referencia:**
- **Línea azul discontinua (dashed):** MFI del control UNS A549 CD19 (≈ 267,188).
  Indica el nivel de expresión de CD19 en células A549 puras, sin estar mezcladas en
  el esferoide. Es el **techo de referencia**: si las células del esferoide están
  cerca de este valor, expresan CD19 a un nivel similar al de las células de cultivo
  puro.
- **Línea naranja punteada (dotted):** MFI del control UNS A549 WT (≈ 231,527).
  Indica el **background de autofluorescencia** de las A549 en este canal. Valores
  del esferoide cercanos a esta línea indicarían que la señal de CD19 es casi ruido.

**Qué se grafica:** la MFI promedio de D1 y D2 para cada grupo y timepoint.

**Interpretación:**
- Si la MFI cae a lo largo del tiempo en los grupos tratados con CAR-T, sugiere
  **pérdida de antígeno** (escape antigénico): las células CD19⁺ que quedaron vivas
  expresan menos CD19, probablemente porque las que tenían más antígeno fueron
  eliminadas primero.
- Si la MFI es similar entre grupos, la expresión de CD19 es estable.
- Una MFI muy cercana a A549 WT indica que el anticuerpo apenas detecta señal, lo
  que podría ser un artefacto de gating o pérdida real del transgén.

---

### Figuras `13_mfi_cd19_norm_*` — MFI CD19 normalizada (% de A549 CD19)

**Cálculo:**

```
MFI normalizada (%) = (MFI_muestra / MFI_UNS_A549_CD19) × 100
```

Donde `MFI_UNS_A549_CD19` = 267,188 (valor del control de célula única).

**Eje Y:** `Normalized MFI CD19 (% of A549 CD19)`. Escala libre (auto).

**Línea de referencia:**
- **Línea azul discontinua al 100%:** nivel de expresión de las células A549 CD19 puras.
  Los valores del esferoide que estén por encima o debajo de 100% se interpretan como
  mayor o menor expresión que la referencia.

**Interpretación:**
- **100%:** las células CD19⁺ del esferoide expresan CD19 al mismo nivel que las
  células A549 transducidas en monocultivo.
- **< 100%:** menor expresión en el esferoide. Puede ser porque:
  (a) el microambiente 3D reduce la expresión del transgén,
  (b) las células con mayor expresión fueron eliminadas primero por el CAR-T
  (presión de selección).
- **Diferencia entre grupos con y sin CAR-T:** si los grupos con CAR-T muestran MFI
  normalizada más baja que Sph. only o Sph+PBMC, apoya la hipótesis de escape
  antigénico mediado por el CAR-T.

### Tabla de resultados: `13_mfi_cd19_resumen.csv`

Contiene por cada combinación `activation × group × sph_time`:
- `mfi_cd19`: MFI absoluta del canal Spark Violet 500 (mediana de D1 y D2)
- `mfi_cd19_norm_pct`: MFI normalizada al UNS A549 CD19 (%)
- Filas para D1, D2, y la media (`donor = "mean"`)
- Filas adicionales de controles con `group = "UNS_A549_CD19"`, `"UNS_A549_WT"`, etc.

---

## Convenciones visuales compartidas

### Colores de grupos (paleta Okabe-Ito, colorblind-safe)

| Grupo | Color | Hex |
|-------|-------|-----|
| Sph. only | Gris | `#999999` |
| Sph+CAR-T | Naranja | `#E69F00` |
| Sph+PBMC | Gris oscuro | `#555555` |
| Sph+PBMC+CAR-T | Verde | `#009E73` |

### Formas de los puntos

| Grupo | Forma |
|-------|-------|
| Sph. only | Cuadrado (■) |
| Sph+CAR-T | Rombo (◆) |
| Sph+PBMC | Círculo (●) |
| Sph+PBMC+CAR-T | Triángulo (▲) |

### Eje X (etiquetas de tiempo)

Las etiquetas del eje X muestran múltiples tiempos simultáneos para claridad:

| Punto | Label |
|-------|-------|
| 24 h | `24 h sph. / —` |
| 48 h | `48 h sph / 24 h PBMC` |
| 72 h | `72 h sph / 48 h PBMC / 24 h CAR-T` |
| 96 h | `96 h sph / 72 h PBMC / 48 h CAR-T` |

---

## Limitaciones interpretativas

- **n = 2 donantes:** todos los resultados son exploratorios/descriptivos. No se aplican
  tests estadísticos.
- **Sin replicados técnicos:** D1 y D2 son réplicas biológicas independientes.
- **Viabilidad normalizada y gating:** si el gate del esferoide cambia entre muestras
  (por morfología, agregados), el denominador `Vivas_sph_only` puede ser ruidoso.
- **MFI y viabilidad CD19⁺:** la MFI se mide solo en las células que quedaron CD19⁺.
  Si las CAR-T eliminaron la mayoría, el gate puede quedar con pocas células y la MFI
  puede ser menos representativa.
- **Autofluorescencia A549:** el canal Spark Violet 500 tiene autofluorescencia alta en
  A549, por lo que la diferencia entre CD19⁺ y WT no es tan grande como en otras líneas.
