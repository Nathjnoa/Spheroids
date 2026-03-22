# Plotting Style Guide — cart_spheroids_flow

Referencia de todos los patrones visuales establecidos en los scripts de este proyecto.
Cualquier figura nueva debe seguir estas convenciones para mantener coherencia visual.

---

## 1. Tema base (`theme_flow`)

Todos los scripts definen un tema idéntico basado en `theme_bw`:

```r
theme_flow <- theme_bw(base_size = 13) +
  theme(
    axis.text.x        = element_text(size = 10, hjust = 0.5, lineheight = 0.9),
    axis.text.y        = element_text(size = 11),
    axis.title         = element_text(size = 12),
    plot.title         = element_text(size = 10, face = "bold", hjust = 0.5),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 10),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )
```

### Excepciones por tipo de figura

| Tipo | Diferencia respecto al tema base |
|------|----------------------------------|
| Barras apiladas (script 03) | `legend.position = "right"`, `legend.title = element_text(size = 11, face = "bold")`, `strip.background = element_rect(fill = "grey92", color = "grey55")`, `strip.text = element_text(face = "bold", size = 7.5)` |
| Curvas 3 grupos (script 09_cd4_cd8) | `legend.text = element_text(size = 9)`, `guides(nrow = 2)` |

---

## 2. Paleta de colores

### 2a. Grupos experimentales (4 grupos)

Paleta Okabe-Ito + grises para controles. Usada en scripts 07, 08, 10_morphology, 11_esf_cd19.

```r
group_colors <- c(
  "Sph. only"      = "#999999",   # gris medio
  "Sph+CAR-T"      = "#E69F00",   # naranja (Okabe-Ito)
  "Sph+PBMC"       = "#555555",   # gris oscuro
  "Sph+PBMC+CAR-T" = "#009E73"    # verde (Okabe-Ito)
)
```

### 2b. Grupos experimentales (subconjuntos)

Cuando solo se grafican 2 o 3 grupos, se usan los mismos colores del mapa completo:

```r
# 2 grupos (solo condiciones con CAR-T)
cols_2 <- c("Sph+CAR-T" = "#E69F00", "Sph+PBMC+CAR-T" = "#009E73")

# 3 grupos (sin Sph. only)
cols_3 <- c("Sph+CAR-T" = "#E69F00", "Sph+PBMC" = "#555555", "Sph+PBMC+CAR-T" = "#009E73")
```

### 2c. Curvas +/- CAR-T (2 lineas)

Para scripts donde se compara una condicion sin CAR-T vs con CAR-T (scripts 04, 05):

```r
line_colors <- c(
  "- CAR-T" = "#555555",    # gris oscuro (control)
  "+ CAR-T" = <color_de_la_poblacion>  # color especifico de la subpoblacion
)
```

### 2d. Poblaciones inmunes (barras apiladas y timecourse)

| Poblacion | Hex | Fuente |
|-----------|-----|--------|
| CD4+ | `#0072B2` | Okabe-Ito azul |
| CD8+ | `#D55E00` | Okabe-Ito rojo-naranja |
| B Cells | `#009E73` | Okabe-Ito verde |
| Monocytes | `#CC79A7` | Okabe-Ito rosa |
| NK Cells | `#E69F00` | Okabe-Ito naranja |
| CD3+ | `#56B4E9` | Okabe-Ito celeste |
| Macrophages HLA-DR+ | `#882255` | Purpura oscuro |

---

## 3. Formas de punto (`shape`)

### Mapa de formas por grupo

```r
group_shapes <- c(
  "Sph. only"      = 15L,   # cuadrado relleno
  "Sph+CAR-T"      = 18L,   # diamante relleno
  "Sph+PBMC"       = 16L,   # circulo relleno
  "Sph+PBMC+CAR-T" = 17L    # triangulo relleno
)
```

### Para curvas +/- CAR-T

```r
line_shapes <- c(
  "- CAR-T" = 16,   # circulo
  "+ CAR-T" = 17    # triangulo
)
```

---

## 4. Geometrias

### Curvas temporales (line + point)

```r
geom_line(linewidth = 0.9)
geom_point(size = 3.5)
```

### Barras apiladas

```r
geom_col(
  position  = position_stack(reverse = FALSE),
  width     = 0.72,
  color     = "white",       # borde blanco entre segmentos
  linewidth = 0.2
)
```

---

## 5. Dimensiones de figuras (mm)

| Tipo de figura | Ancho | Alto | Ejemplo |
|----------------|-------|------|---------|
| Multipanel barras apiladas (1x2) | 250 | 110 | `03_stacked_bars` |
| Curva temporal simple (2 lineas) | 120 | 100 | `04_pbmc_live_*`, `05_*`, `08_*` |
| Curva temporal 4 lineas | 130 | 110 | `07_*`, `11_esf_cd19_*` |
| Morfologia (4 lineas) | 130 | 115 | `10_morphology_*` |
| Curva CD4/CD8 count (3 lineas) | 120 | 100 | `09_cd4_count_*`, `09_cd8_count_*` |

---

## 6. Exportacion

Todas las figuras se exportan en **dos formatos** simultaneamente:

```r
ggsave(pdf_path, p, width = w, height = h, units = "mm",
       device = cairo_pdf, limitsize = FALSE)
ggsave(png_path, p, width = w, height = h, units = "mm",
       dpi = 300, device = "png", limitsize = FALSE)
```

- **PDF**: via `cairo_pdf` (soporte Unicode completo para superscripts)
- **PNG**: 300 DPI

---

## 7. Eje X: etiquetas de tiempo

### 4 tiempos (esf_vivas, CD19+, morfologia)

```r
c(
  "24" = "24 h sph.\n\u2014",                       # baseline pre-PBMC
  "48" = "48 h sph\n24 h PBMC",
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)
```

### 3 tiempos (PBMC populations, CD4/CD8 count)

```r
c(
  "24" = "48 h esf\n24 h PBMC",
  "48" = "72 h esf\n48 h PBMC\n24 h CAR-T",
  "72" = "96 h esf\n72 h PBMC\n48 h CAR-T"
)
```

### 2 tiempos (expresion CAR, % CAR-T)

```r
c(
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)
```

Cada etiqueta muestra multiples lineas con el tiempo relativo de cada componente del co-cultivo.

---

## 8. Eje Y: convenciones

### Porcentajes (0-100%)

```r
scale_y_continuous(
  breaks = seq(0, 100, 20),
  labels = label_number(suffix = "%", accuracy = 1),
  limits = c(0, 100),
  expand = expansion(mult = c(0, 0.03))
)
```

### Conteos (escala lineal)

```r
# Limites adaptados al maximo de los datos
y_ceil <- max(ceiling(max(data$value) / 100) * 100, 500)
scale_y_continuous(
  breaks = pretty(c(0, y_ceil), n = 5),
  labels = label_comma(),
  limits = c(0, y_ceil),
  expand = expansion(mult = c(0, 0.03))
)
```

Excepciones con limites fijos:

| Script | Variable | Limite Y |
|--------|----------|----------|
| 04 | PBMCs vivas | 0-7000, breaks seq(0, 7000, 500), labels solo en multiplos de 1000 |
| 05 | NK cells count | 0-1500 |
| 08 | CD3+ count noact | 0-5000 (fijo) |

### Conteos (escala log10) — script 07

```r
scale_y_log10(
  breaks = c(1000, 2000, 3000, 5000, 10000, 20000, 30000),
  labels = label_comma(),
  limits = c(300, 30000),
  expand = expansion(mult = c(0.08, 0.03))
)
```

### Area/Diametro — notacion cientifica

```r
scale_y_continuous(
  labels = label_scientific(digits = 2),
  expand = expansion(mult = c(0.05, 0.08))
)
```

### Circularidad — escala 0-1

```r
scale_y_continuous(
  limits = c(0, 1),
  breaks = seq(0, 1, 0.2),
  expand = expansion(mult = c(0, 0.03))
)
```

---

## 9. Titulos

### Formato estandar

```
A549+MRC-5+{Activated/Non-activated PBMC}+CAR-T
```

Ejemplos:
- `"A549+MRC-5+Non-activated PBMC+CAR-T"`
- `"A549+MRC-5+Activated PBMC+CAR-T"`

### Estilo

```r
plot.title = element_text(size = 10, face = "bold", hjust = 0.5)
```

- Centrado (`hjust = 0.5`)
- Negrita
- Tamano 10pt

### Variantes

| Script | Formato del titulo |
|--------|-------------------|
| 03 (barras apiladas) | `"A549+MRC-5 + PBMC + CAR-T"` / `"A549+MRC-5 + Activated PBMC + CAR-T"` (con espacios alrededor de `+`, titulo size=9) |
| 05 (2 lineas, no en lista corta) | Titulo lleva `\n` + nombre de la poblacion como subtitulo |
| 11_esf_cd19 | `"A549+MRC-5 CD19+ +/- {label} +/- CAR-T"` (con `\u00b1`) |

---

## 10. Leyenda

### Posicion y layout

| Tipo de figura | Posicion | nrow | Titulo |
|----------------|----------|------|--------|
| Curva temporal (2 lineas) | `"top"` | 1 | Sin titulo (`element_blank()`) |
| Curva temporal (3 lineas) | `"top"` | 2 | Sin titulo |
| Curva temporal (4 lineas) | `"top"` | 2 | Sin titulo |
| Barras apiladas | `"right"` | — | `"Population"` (bold, size 11) |

### Etiquetas en curvas +/- CAR-T

```r
leg_labels <- c(
  "- CAR-T" = "Sph+PBMC",
  "+ CAR-T" = "Sph+PBMC+CAR-T"
)
```

En curvas de 4 grupos, las etiquetas son los nombres directos del grupo
(`"Sph. only"`, `"Sph+CAR-T"`, `"Sph+PBMC"`, `"Sph+PBMC+CAR-T"`).

---

## 11. Idioma

- **Todo el texto visible en ingles**: titulos, ejes, leyendas, labels.
- **Unicode superscripts**: `\u207A` para + (e.g., CD4+), `\u207B` para - (e.g., CD3-).
- **Unidades**: `(\u03bcm\u00b2)` para area, `(\u03bcm)` para diametro, `(a.u.)` para circularidad.
- **Variables internas y logs**: pueden estar en espanol.

---

## 12. Patrones de codigo reutilizables

### Funcion de guardado estandar

```r
save_fig <- function(p, name, w = 120, h = 100) {
  pdf_path <- file.path(fig_dir, paste0(name, ".pdf"))
  png_path <- file.path(fig_dir, paste0(name, ".png"))
  ggsave(pdf_path, p, width = w, height = h, units = "mm",
         device = cairo_pdf, limitsize = FALSE)
  ggsave(png_path, p, width = w, height = h, units = "mm",
         dpi = 300, device = "png", limitsize = FALSE)
  message("\u2713 Guardado: ", basename(pdf_path),
          sprintf("  (%.0f\u00d7%.0f mm)", w, h))
}
```

### Logging

Todos los scripts usan logging con timestamp:

```r
log_file <- file.path(log_dir, paste0("XX_nombre_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
# ... script ...
sink(type = "message")
sink(type = "output")
close(con)
```

### Rutas con `here::here()`

```r
project_dir <- here::here()
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")
```

---

## 13. Checklist para figuras nuevas

Al crear un nuevo script de graficacion:

1. Definir `theme_flow` con los mismos parametros del tema base (Seccion 1)
2. Usar los colores de grupo de la Seccion 2a (o el subconjunto apropiado)
3. Usar las formas de punto de la Seccion 3
4. `geom_line(linewidth = 0.9)` + `geom_point(size = 3.5)`
5. Exportar en PDF (`cairo_pdf`) + PNG (300 DPI)
6. Titulo: `"A549+MRC-5+{activation}+CAR-T"`, size 10, bold, centrado
7. Leyenda en `"top"`, sin titulo, nrow segun numero de grupos
8. Eje Y desde 0, `expand = expansion(mult = c(0, 0.03))`
9. Eliminar `panel.grid.minor` y `panel.grid.major.x`
10. Texto en ingles, Unicode superscripts
11. Incluir `save_fig()` y logging con timestamp
