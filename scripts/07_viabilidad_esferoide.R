#!/usr/bin/env Rscript
# 07_viabilidad_spheroide.R
# Curvas temporales de viabilidad del spheroide tumoral y de PBMCs en
# co-cultivo ± CAR-T (PBMCs activadas y no activadas).
#
# Datos: CONTEOS de los archivos de viabilidad (4 nuevos XLS en data/raw/).
# Eje X: tiempo de cultivo del spheroide (24 h = baseline → 96 h = fin).
#
# Plots generados:
#   07_sph_vivas_noact.pdf/.png  — Esferoide/Vivas, PBMCs no activadas
#   07_sph_vivas_act.pdf/.png    — Esferoide/Vivas, PBMCs activadas
#   07_pbmc_vivas_noact.pdf/.png — PBMC Vivas,      PBMCs no activadas
#   07_pbmc_vivas_act.pdf/.png   — PBMC Vivas,      PBMCs activadas
#
# Convención de tiempo (igual que scripts 04 y 05):
#   - La línea + CAR-T comparte el punto sph_time=48h con − CAR-T
#     (instante en que se añaden las CAR-T, antes de su efecto).
#   - sph_time = tiempo_XLS + 24 (convierte al tiempo real del spheroide).
#
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(here)

})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
raw_dir     <- file.path(project_dir, "data", "raw")
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(
  log_dir,
  paste0("07_viabilidad_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
)
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 07_viabilidad_spheroide.R === ", Sys.time())

# ── Función de lectura ────────────────────────────────────────────────────────
# Los archivos de viabilidad tienen estructuras de columnas distintas entre
# ACTIVADAS y NO ACTIVADAS; se asignan nombres canónicos por posición.
#
# ACTIVADAS CONTEOS VIABILIDAD (29 cols):
#   col 10 = Esferoide/Vivas,  col 14 = PBMC Vivas
#
# NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (22 cols):
#   col 11 = Esferoide/Vivas,  col 17 = PBMC's Vivas
#
read_viabilidad_cnt <- function(path, activation) {
  raw <- suppressMessages(
    read_excel(path, col_names = FALSE, na = c("", "-", "NA"))
  )
  # Row 1 = header; data from row 2 onward
  df <- as.data.frame(raw[-1, ])

  col_sph  <- if (activation == "ACTIVADAS") 10L else 11L
  col_pbmc <- if (activation == "ACTIVADAS") 14L else 17L

  data.frame(
    sample_label = as.character(df[[1]]),
    pbmc         = toupper(trimws(as.character(df[[2]]))),
    donor        = as.character(df[[3]]),
    cart         = toupper(trimws(as.character(df[[4]]))),
    tiempo       = suppressWarnings(as.numeric(df[[5]])),
    activation   = activation,
    sph_vivas    = suppressWarnings(as.numeric(df[[col_sph]])),
    pbmc_vivas   = suppressWarnings(as.numeric(df[[col_pbmc]])),
    stringsAsFactors = FALSE
  ) |>
    filter(!is.na(tiempo))
}

# ── Leer ambos archivos ───────────────────────────────────────────────────────
f_act   <- file.path(raw_dir, "ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx")
f_noact <- file.path(raw_dir, "NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx")

df_act   <- read_viabilidad_cnt(f_act,   "ACTIVADAS")
df_noact <- read_viabilidad_cnt(f_noact, "NO_ACTIVADOS")

message("Filas ACTIVADAS:    ", nrow(df_act))
message("Filas NO_ACTIVADOS: ", nrow(df_noact))

# ── Transformar tiempo y asignar grupos ───────────────────────────────────────
# Los archivos ya tienen tiempo en horas totales del experimento (24/48/72/96 h)
# (corregido desde la fuente XLS → XLSX). No se aplica offset aquí.
df_all <- bind_rows(df_act, df_noact) |>
  mutate(
    sph_time = tiempo,
    group = case_when(
      pbmc == "NO" & cart == "NO" ~ "Sph. only",
      pbmc == "NO" & cart == "SI" ~ "Sph+CAR-T",
      pbmc == "SI" & cart == "NO" ~ "Sph+PBMC",
      pbmc == "SI" & cart == "SI" ~ "Sph+PBMC+CAR-T"
    ),
    group = factor(group,
                   levels = c("Sph. only", "Sph+CAR-T",
                               "Sph+PBMC", "Sph+PBMC+CAR-T"))
  )

message("\nResumen de grupos y tiempos:")
print(df_all |> count(activation, group, sph_time))

# ── Preparar datos para graficar ──────────────────────────────────────────────
# Puntos compartidos (baseline antes de añadir la siguiente condición):
#   Todos los grupos  @ t=24h ← Esf. solo @ t=24h  (antes de añadir PBMCs)
#   + CAR-T           @ t=48h ← − CAR-T  @ t=48h   (antes de añadir CAR-T)
#   CAR-T solo        @ t=48h ← Esf. solo @ t=48h   (ídem, sin PBMCs)
#
# include_t24: TRUE  → eje X con 4 tiempos (24, 48, 72, 96) — para sph_vivas
#              FALSE → eje X con 3 tiempos (48, 72, 96)      — para pbmc_vivas
prep_plot_data <- function(df, act_val, y_col, include_t24 = TRUE) {
  grp_levels <- c("Sph. only", "Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T")
  src <- df |> filter(activation == act_val)

  # Promediar D1 y D2 por grupo y tiempo
  df_avg <- src |>
    group_by(group, sph_time) |>
    summarise(value = mean(.data[[y_col]], na.rm = TRUE), .groups = "drop")

  if (include_t24) {
    # Valor del spheroide solo a t=24h → baseline compartido para todas las líneas
    baseline_24 <- df_avg |>
      filter(group == "Sph. only", sph_time == 24) |>
      select(sph_time, value)

    shared_24 <- lapply(
      c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"),
      function(g) data.frame(group = g, sph_time = 24L,
                              value = baseline_24$value,
                              stringsAsFactors = FALSE)
    ) |> bind_rows()

    df_avg <- bind_rows(df_avg, shared_24)
    time_levels <- c("24", "48", "72", "96")
    time_labels <- c("24 h sph.\n\u2014",
                     "48 h sph\n24 h PBMC",
                     "72 h sph\n48 h PBMC\n24 h CAR-T",
                     "96 h sph\n72 h PBMC\n48 h CAR-T")
  } else {
    df_avg <- df_avg |> filter(sph_time >= 48)
    time_levels <- c("48", "72", "96")
    time_labels <- c("48 h sph\n24 h PBMC",
                     "72 h sph\n48 h PBMC\n24 h CAR-T",
                     "96 h sph\n72 h PBMC\n48 h CAR-T")
  }

  # Punto compartido: + CAR-T @ t=48 ← − CAR-T @ t=48
  t0_pbmccart <- df_avg |>
    filter(group == "Sph+PBMC", sph_time == 48) |>
    mutate(group = "Sph+PBMC+CAR-T")

  # Punto compartido: CAR-T solo @ t=48 ← Esf. solo @ t=48
  t0_cartsolo <- df_avg |>
    filter(group == "Sph. only", sph_time == 48) |>
    mutate(group = "Sph+CAR-T")

  # Eliminar puntos t=48 propios de grupos que usan valor compartido
  df_avg <- df_avg |>
    filter(!(group == "Sph+PBMC+CAR-T"    & sph_time == 48),
           !(group == "Sph+CAR-T" & sph_time == 48))

  bind_rows(df_avg, t0_pbmccart, t0_cartsolo) |>
    filter(!is.na(value)) |>
    arrange(group, sph_time) |>
    mutate(
      group = factor(group, levels = grp_levels),
      sph_time_f = factor(as.character(sph_time),
                          levels = time_levels,
                          labels = time_labels)
    )
}

# ── Tema (consistente con scripts 04 y 05) ────────────────────────────────────
theme_flow <- theme_bw(base_size = 13) +
  theme(
    axis.text.x        = element_text(size = 10, hjust = 0.5, lineheight = 0.9),
    axis.text.y        = element_text(size = 11),
    axis.title         = element_text(size = 12),
    plot.title         = element_text(size = 10, face = "bold", hjust = 0.5),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 11),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )

# Colores y formas Okabe-Ito, consistentes con scripts anteriores
group_colors <- c(
  "Sph. only"   = "#999999",
  "Sph+CAR-T"  = "#E69F00",
  "Sph+PBMC" = "#555555",
  "Sph+PBMC+CAR-T"     = "#009E73"
)
group_shapes <- c(
  "Sph. only"   = 15L,
  "Sph+CAR-T"  = 18L,
  "Sph+PBMC" = 16L,
  "Sph+PBMC+CAR-T"     = 17L
)

# ── Función de plot ───────────────────────────────────────────────────────────
make_viab_plot <- function(plot_data, title, y_lab) {
  ggplot(plot_data,
         aes(x = sph_time_f, y = value,
             color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors, drop = TRUE) +
    scale_shape_manual(values = group_shapes, drop = TRUE) +
    scale_y_log10(
      breaks = c(1000, 2000, 3000, 5000, 10000, 20000, 30000),
      labels = label_comma(),
      limits = c(300, 30000),
      expand = expansion(mult = c(0.08, 0.03))
    ) +
    labs(title = title, x = NULL, y = y_lab) +
    theme_flow
}

# ── Función de guardado ───────────────────────────────────────────────────────
save_fig <- function(p, name, w = 130, h = 110) {
  pdf_path <- file.path(fig_dir, paste0(name, ".pdf"))
  png_path <- file.path(fig_dir, paste0(name, ".png"))
  ggsave(pdf_path, p, width = w, height = h, units = "mm",
         device = cairo_pdf, limitsize = FALSE)
  ggsave(png_path, p, width = w, height = h, units = "mm",
         dpi = 300, device = "png", limitsize = FALSE)
  message("\u2713 Guardado: ", basename(pdf_path),
          sprintf("  (%.0f\u00d7%.0f mm)", w, h))
}

# ── Generar figuras ───────────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC"),
  list(val = "ACTIVADAS",    suf = "act",   label = "Activated PBMC")
)

plot_vars <- list(
  list(
    col    = "sph_vivas",
    id     = "esf_vivas",
    y_lab  = "Spheroid viable cells (count)",
    title  = "Spheroid viable cells",
    # Incluir todos los grupos (spheroide solo, CAR-T solo, ±CAR-T con PBMC)
    filter_pbmc_only = FALSE
  ),
  list(
    col    = "pbmc_vivas",
    id     = "pbmc_vivas",
    y_lab  = "Viable PBMCs (count)",
    title  = "PBMC viability in co-culture",
    # Solo condiciones con PBMC (excluir Esf. solo y CAR-T solo)
    filter_pbmc_only = TRUE
  )
)

for (pvar in plot_vars) {
  message("\n--- Variable: ", pvar$col, " ---")
  for (act in act_meta) {
    # sph_vivas incluye t=24h baseline; pbmc_vivas empieza en t=48h
    pd <- prep_plot_data(df_all, act$val, pvar$col,
                         include_t24 = !pvar$filter_pbmc_only)

    if (pvar$filter_pbmc_only) {
      pd <- pd |> filter(group %in% c("Sph+PBMC", "Sph+PBMC+CAR-T"))
    }

    if (nrow(pd) == 0 || all(is.na(pd$value))) {
      message("  SKIP: sin datos para ", act$val)
      next
    }

    message("  ", act$val, ": ", nrow(pd), " filas, grupos: ",
            paste(unique(pd$group), collapse = ", "))

    title <- paste0("A549+MRC-5+", act$label, "+CAR-T")

    p     <- make_viab_plot(pd, title, pvar$y_lab)
    fname <- paste0("07_", pvar$id, "_", act$suf)
    save_fig(p, fname)
  }
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
