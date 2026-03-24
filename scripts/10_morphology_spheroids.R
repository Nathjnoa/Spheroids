#!/usr/bin/env Rscript
# 10_morphology_spheroids.R
# Curvas temporales de morfología del esferoide (Área, Diámetro, Circularidad)
# para PBMC activadas y no activadas ± CAR-T.
#
# Datos: data/raw/Medidas esferoides.xlsx  (16 filas, n=1 por grupo × tiempo)
# Convención de tiempos y puntos compartidos: igual que script 07.
#
# Figuras generadas (6):
#   10_area_noact.pdf/.png        — Área, PBMC no activadas
#   10_area_act.pdf/.png          — Área, PBMC activadas
#   10_diametro_noact.pdf/.png    — Diámetro, PBMC no activadas
#   10_diametro_act.pdf/.png      — Diámetro, PBMC activadas
#   10_circularidad_noact.pdf/.png — Circularidad, PBMC no activadas
#   10_circularidad_act.pdf/.png   — Circularidad, PBMC activadas
#
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(ggplot2)
  library(scales)
})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
raw_dir     <- file.path(project_dir, "data", "raw")
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

source(file.path(project_dir, "scripts", "00_theme.R"))
theme_flow <- theme_flow + theme(legend.text = element_text(size = 10))

log_file <- file.path(log_dir,
  paste0("10_morphology_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 10_morphology_spheroids.R === ", Sys.time())

# ── Leer y limpiar datos ──────────────────────────────────────────────────────
raw <- read_excel(file.path(raw_dir, "Medidas esferoides.xlsx"),
                  na = c("", "NA"))

df <- raw |>
  rename(
    unit         = `UNIDAD EXPERIMENTAL`,
    tiempo       = TIEMPO,
    pbmc         = PBMC,
    activation   = `ACTIVACIÓN`,
    cart         = `CAR-T`,
    area         = AREA,
    diametro     = DIAMETRO,
    circularidad = CIRCULARIDAD
  ) |>
  mutate(
    across(c(area, diametro, circularidad), as.numeric),
    pbmc = toupper(trimws(pbmc)),
    cart = toupper(trimws(cart)),
    group = case_when(
      pbmc == "NO" & cart == "NO" ~ "Sph. only",
      pbmc == "NO" & cart == "SI" ~ "Sph+CAR-T",
      pbmc == "SI" & cart == "NO" ~ "Sph+PBMC",
      pbmc == "SI" & cart == "SI" ~ "Sph+PBMC+CAR-T"
    ),
    group = factor(group,
                   levels = c("Sph. only", "Sph+CAR-T",
                              "Sph+PBMC", "Sph+PBMC+CAR-T")),
    # act_clean: NA para filas sin PBMC (compartidas entre ambos estados)
    act_clean = ifelse(is.na(activation) | activation == "NA",
                       NA_character_, activation)
  )

message("Dimensiones: ", nrow(df), " x ", ncol(df))
print(df |> select(unit, tiempo, act_clean, cart, group, area, diametro, circularidad))

# ── Preparar datos por estado de activación ───────────────────────────────────
# Para cada estado ("NO" / "SI"), incluir:
#   - Sph. only y Sph+CAR-T (act_clean == NA, compartidos en ambos gráficos)
#   - Sph+PBMC y Sph+PBMC+CAR-T del estado correspondiente
#
# Puntos compartidos (misma lógica que script 07):
#   Todos los grupos   @ t=24 ← Sph. only @ t=24
#   Sph+CAR-T         @ t=48 ← Sph. only @ t=48
#   Sph+PBMC+CAR-T    @ t=48 ← Sph+PBMC  @ t=48 (del estado correspondiente)
prep_morph_data <- function(df, act_val) {
  grp_levels <- c("Sph. only", "Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T")

  src <- df |>
    filter(is.na(act_clean) | act_clean == act_val) |>
    select(group, sph_time = tiempo, area, diametro, circularidad)

  # Punto baseline t=24 (Sph. only) compartido con todos los demás grupos
  baseline_24 <- src |> filter(group == "Sph. only", sph_time == 24)

  shared_24 <- lapply(c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"), function(g) {
    baseline_24 |> mutate(group = g)
  }) |> bind_rows()

  # Sph+CAR-T @ t=48 ← Sph. only @ t=48 (antes de añadir CAR-T)
  t48_cartsolo <- src |>
    filter(group == "Sph. only", sph_time == 48) |>
    mutate(group = "Sph+CAR-T")

  # Sph+PBMC+CAR-T @ t=48 ← Sph+PBMC @ t=48 (antes de añadir CAR-T)
  t48_pbmccart <- src |>
    filter(group == "Sph+PBMC", sph_time == 48) |>
    mutate(group = "Sph+PBMC+CAR-T")

  # Eliminar los puntos propios que ya están cubiertos por los compartidos
  src <- src |>
    filter(
      !(group %in% c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T") & sph_time == 24),
      !(group == "Sph+CAR-T"      & sph_time == 48),
      !(group == "Sph+PBMC+CAR-T" & sph_time == 48)
    )

  bind_rows(src, shared_24, t48_cartsolo, t48_pbmccart) |>
    arrange(group, sph_time) |>
    mutate(
      group = factor(group, levels = grp_levels),
      sph_time_f = factor(as.character(sph_time),
                          levels = c("24", "48", "72", "96"),
                          labels = c("24 h sph.\n\u2014",
                                     "48 h sph\n24 h PBMC",
                                     "72 h sph\n48 h PBMC\n24 h CAR-T",
                                     "96 h sph\n72 h PBMC\n48 h CAR-T"))
    )
}

# ── Colores y formas (consistentes con script 07) ─────────────────────────────
group_colors <- c(
  "Sph. only"      = "#999999",
  "Sph+CAR-T"      = "#E69F00",
  "Sph+PBMC"       = "#555555",
  "Sph+PBMC+CAR-T" = "#009E73"
)
group_shapes <- c(
  "Sph. only"      = 15L,
  "Sph+CAR-T"      = 18L,
  "Sph+PBMC"       = 16L,
  "Sph+PBMC+CAR-T" = 17L
)

# ── Función de plot ───────────────────────────────────────────────────────────
make_morph_plot <- function(plot_data, title, y_col, y_lab, log_scale = TRUE,
                            y_limits = NULL, y_breaks = NULL) {
  p <- ggplot(plot_data,
              aes(x = sph_time_f, y = .data[[y_col]],
                  color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    scale_shape_manual(values = group_shapes, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    labs(title = title, x = NULL, y = y_lab) +
    theme_flow

  if (log_scale) {
    p <- p + scale_y_continuous(
      labels = label_scientific(digits = 2),
      limits = y_limits,
      breaks = y_breaks,
      expand = expansion(mult = c(0.05, 0.05))
    )
  } else {
    # Circularidad: rango teórico 0–1, escala lineal
    p <- p + scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2),
      expand = expansion(mult = c(0, 0.03))
    )
  }

  p
}

# ── Generar las 6 figuras ─────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO", suf = "noact", label = "Non-activated PBMC"),
  list(val = "SI", suf = "act",   label = "Activated PBMC")
)

# Calcular límites y breaks globales para área y diámetro.
# Ambas condiciones (act y noact) usan exactamente los mismos límites y breaks.
global_scale <- function(col) {
  act_no <- prep_morph_data(df, "NO")[[col]]
  act_si <- prep_morph_data(df, "SI")[[col]]
  vals   <- c(act_no, act_si)
  vals   <- vals[is.finite(vals)]
  rng    <- range(vals)
  list(
    lims   = rng,
    breaks = pretty(rng, n = 5)
  )
}

sc_area     <- global_scale("area")
sc_diametro <- global_scale("diametro")

plot_vars <- list(
  list(col = "area",
       id  = "area",
       y_lab = "Spheroid area (\u03bcm\u00b2)",
       log_scale = TRUE,
       y_limits  = sc_area$lims,
       y_breaks  = sc_area$breaks),
  list(col = "diametro",
       id  = "diametro",
       y_lab = "Spheroid diameter (\u03bcm)",
       log_scale = TRUE,
       y_limits  = sc_diametro$lims,
       y_breaks  = sc_diametro$breaks),
  list(col = "circularidad",
       id  = "circularidad",
       y_lab = "Circularity (a.u.)",
       log_scale = FALSE,
       y_limits  = NULL,
       y_breaks  = NULL)
)

for (pvar in plot_vars) {
  message("\n--- Variable: ", pvar$col, " ---")
  for (act in act_meta) {
    pd <- prep_morph_data(df, act$val)

    message("  ", act$val, ": ", nrow(pd), " filas | grupos: ",
            paste(levels(droplevels(pd$group)), collapse = ", "))

    title <- paste0("A549+MRC-5+", act$label, "+CAR-T")
    p     <- make_morph_plot(pd, title, pvar$col, pvar$y_lab, pvar$log_scale,
                             pvar$y_limits, pvar$y_breaks)
    fname <- paste0("10_", pvar$id, "_", act$suf)
    save_fig(p, fname, 130, 115)
  }
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
