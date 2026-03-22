#!/usr/bin/env Rscript
# 03_stacked_bars.R
# Barras apiladas de composición inmune (CD4+, CD8+, Linfocitos B, Macrófagos, NK)
# para condiciones PBMC sin/con CAR-T a 24h, 48h, 72h.
# Genera 4 figuras (NO_ACTIVADOS y ACTIVADAS × CONTEOS y PORCENTAJES)
# agrupadas en un multipanel 2×2 con patchwork.
# Fuente: data/processed/flow_clean.rds
# Salida: results/figures/03_stacked_bars.pdf / .png
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(forcats)
})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

source(file.path(project_dir, "scripts", "00_theme.R"))
# Override para barras apiladas: leyenda a la derecha, texto más pequeño
theme_flow <- theme_flow + theme(legend.position  = "right",
                                 legend.text       = element_text(size = 10))

log_file <- file.path(log_dir, paste0("03_stacked_bars_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 03_stacked_bars.R === ", Sys.time())

# ── Cargar datos ──────────────────────────────────────────────────────────────
flow <- readRDS(file.path(project_dir, "data", "processed", "flow_clean.rds"))
message("Total filas cargadas: ", nrow(flow))

# ── Configuración de poblaciones ──────────────────────────────────────────────
pops <- c("cd4", "cd8", "b_cells", "monocytes", "nk")

pop_labels <- c(
  cd4       = "CD4\u207A",
  cd8       = "CD8\u207A",
  b_cells   = "B Cells",
  monocytes = "Monocytes",
  nk        = "NK Cells"
)

# Colores Okabe-Ito (colorblind-safe, 5 poblaciones)
pop_colors <- c(
  "CD4\u207A"  = "#0072B2",
  "CD8\u207A"  = "#D55E00",
  "B Cells"    = "#009E73",
  "Monocytes"  = "#CC79A7",
  "NK Cells"   = "#E69F00"
)

# ── Preparación de datos ──────────────────────────────────────────────────────
# Usar solo CONTEOS para tener pbmcs_live disponible como denominador común
df_counts <- flow |>
  filter(pbmc == "SI", data_type == "CONTEOS") |>
  select(activation, cart, tiempo, donor, pbmcs_live, all_of(pops))

message("Filas con pbmc==SI, CONTEOS: ", nrow(df_counts))

# % normalizado con denominador común (pbmcs_live)
# Cada pop = (conteo / pbmcs_live) × 100  → todos comparten el mismo denominador
df_sub <- df_counts |>
  mutate(across(all_of(pops), \(x) (x / pbmcs_live) * 100),
         data_type = "PORCENTAJES") |>
  select(activation, cart, tiempo, donor, data_type, all_of(pops))

message("Combinaciones activation × cart × tiempo × data_type disponibles:")
print(count(df_sub, activation, cart, tiempo, data_type))

# Promediar donantes (media aritmética de D1 y D2)
df_avg <- df_sub |>
  group_by(activation, cart, tiempo, data_type) |>
  summarise(across(all_of(pops), \(x) mean(x, na.rm = TRUE)), .groups = "drop")

# Formato largo — etiquetas con \n para evitar solapamiento en eje X
cart_labels <- c("NO" = "-\nCAR-T", "SI" = "+\nCAR-T")

df_long <- df_avg |>
  pivot_longer(cols = all_of(pops), names_to = "population", values_to = "value") |>
  mutate(
    population = factor(population, levels = pops, labels = pop_labels[pops]),
    cart_label = factor(cart, levels = c("NO", "SI"), labels = cart_labels),
    tiempo_f   = factor(as.character(tiempo),
                        levels = c("24", "48", "72"),
                        labels = c("48 h esf\n24 h PBMC",
                                   "72 h esf\n48 h PBMC\n24 h CAR-T",
                                   "96 h esf\n72 h PBMC\n48 h CAR-T"))
  )

# ── Tema local: agrega elementos específicos de barras apiladas ───────────────
# (legend.position y legend.text sobreescritos via override en source(), arriba)
theme_flow <- theme_flow +
  theme(
    strip.background   = element_rect(fill = "grey92", color = "grey55"),
    strip.text         = element_text(face = "bold", size = 7.5, lineheight = 1.05),
    axis.text.x        = element_text(size = 11, angle = 0, hjust = 0.5, lineheight = 0.9),
    axis.title.y       = element_text(size = 12),
    legend.title       = element_text(size = 11, face = "bold")
  )

# ── Función para construir cada panel ────────────────────────────────────────
make_panel <- function(data, act_val, dtype_val, title = NULL) {
  plot_data <- data |>
    filter(activation == act_val, data_type == dtype_val)

  n_combos <- nrow(distinct(plot_data, cart_label, tiempo_f))
  message(sprintf("  [%s / %s] combinaciones cart×tiempo: %d", act_val, dtype_val, n_combos))

  y_label <- "% Immune Cell Populations"

  plot_data <- droplevels(plot_data)   # elimina niveles sin datos (e.g. +CAR-T a 24h)

  ggplot(plot_data, aes(x = cart_label, y = value, fill = population)) +
    geom_col(
      position  = position_stack(reverse = FALSE),
      width     = 0.72,
      color     = "white",
      linewidth = 0.2
    ) +
    facet_grid(~ tiempo_f, scales = "free_x", space = "free_x") +
    scale_fill_manual(
      values = pop_colors,
      name   = "Population",
      guide  = guide_legend(reverse = FALSE)
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
    labs(
      title = title,
      x     = NULL,
      y     = y_label
    ) +
    theme_flow +
    theme(plot.title = element_text(size = 9, face = "bold", hjust = 0.5,
                                    margin = margin(b = 4)))
}

# ── Generar los 4 paneles ─────────────────────────────────────────────────────
# ── Multipanel 1×2 ────────────────────────────────────────────────────────────
p_noact_pct <- make_panel(df_long, "NO_ACTIVADOS", "PORCENTAJES",
                          "A549+MRC-5 + PBMC + CAR-T")
p_act_pct   <- make_panel(df_long, "ACTIVADAS",    "PORCENTAJES",
                          "A549+MRC-5 + Activated PBMC + CAR-T")

p_combined <- p_noact_pct + p_act_pct +
  plot_layout(guides = "collect") &
  theme(legend.position = "right")

# Multipanel combinado (250×110 mm — 1 fila × 2 columnas)
save_fig(p_combined, "03_stacked_bars", w = 250, h = 110)

message("=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
