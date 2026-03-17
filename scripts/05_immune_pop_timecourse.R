#!/usr/bin/env Rscript
# 05_immune_pop_timecourse.R
# Evolución temporal de 6 poblaciones inmunes (líneas ± CAR-T, promedio D1+D2).
# La línea + CAR-T comparte t=24h con - CAR-T (antes de añadir CAR-T).
# Genera 12 figuras (6 poblaciones × 2 estados de activación).
# Todas calculadas desde CONTEOS para evitar problemas de denominadores FlowJo.
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(ggbreak)
})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(log_dir, paste0("05_immune_pop_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 05_immune_pop_timecourse.R === ", Sys.time())

# ── Cargar datos ──────────────────────────────────────────────────────────────
flow <- readRDS(file.path(project_dir, "data", "processed", "flow_clean.rds"))

df_base <- flow |> filter(pbmc == "SI", data_type == "CONTEOS")
df_pct  <- flow |> filter(pbmc == "SI", data_type == "PORCENTAJES")

message("Filas base (pbmc==SI, CONTEOS): ", nrow(df_base))
message("Filas pct  (pbmc==SI, PORCENTAJES): ", nrow(df_pct))

# ── Definir poblaciones a graficar ────────────────────────────────────────────
# Colores consistentes con 03_stacked_bars.R:
#   CD4+ = "#0072B2", CD8+ = "#D55E00", Monocytes = "#CC79A7"
# Nuevos para poblaciones no presentes en stacked bars:
#   CD3+ = "#56B4E9" (sky blue, Okabe-Ito)

pop_specs <- list(
  list(
    id            = "cd3_count",
    label         = "CD3\u207A",
    y_lab         = "Live CD3\u207A cells (count)",
    color         = "#56B4E9",
    src_data      = "cnt",
    use_break     = FALSE,
    calc          = function(d) d$cd3,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  ),
  list(
    id       = "cd4_hladr_neg",
    label    = "CD4\u207A/HLA-DR\u207B",
    y_lab    = "CD4\u207A/HLA-DR\u207B (%)",
    color    = "#0072B2",
    src_data = "cnt",
    calc     = function(d) (d$cd4 - d$cd4_hladr) / d$cd4 * 100
  ),
  list(
    id       = "cd8_hladr_neg",
    label    = "CD8\u207A/HLA-DR\u207B",
    y_lab    = "CD8\u207A/HLA-DR\u207B (%)",
    color    = "#D55E00",
    src_data = "cnt",
    calc     = function(d) (d$cd8 - d$cd8_hladr) / d$cd8 * 100
  ),
  list(
    id           = "macrophages_count",
    label        = "Macrophages",
    y_lab        = "Live CD64\u207A macrophages (count)",
    color        = "#D55E00",
    src_data     = "cnt",
    use_break    = TRUE,
    calc         = function(d) d$macrophages,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  ),
  list(
    id            = "macrophages_cd11b",
    label         = "Macrophages CD11b\u207A",
    y_lab         = "Macrophages CD11b\u207A (%)",
    color         = "#D55E00",
    src_data      = "pct",   # porcentaje FlowJo directo (denominador correcto)
    calc          = function(d) d$macrophages_cd11b,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  ),
  list(
    id            = "macrophages_hladr",
    label         = "Macrophages HLA-DR\u207A",
    y_lab         = "Macrophages HLA-DR\u207A (%)",
    color         = "#882255",
    src_data      = "pct",   # porcentaje FlowJo directo (denominador correcto)
    calc          = function(d) d$macrophages_hladr,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  ),
  list(
    id            = "cd4_hladr_pos",
    label         = "CD4\u207A/HLA-DR\u207A",
    y_lab         = "CD4\u207A/HLA-DR\u207A (%)",
    color         = "#0072B2",
    src_data      = "cnt",
    calc          = function(d) d$cd4_hladr / d$cd4 * 100,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  ),
  list(
    id            = "cd8_hladr_pos",
    label         = "CD8\u207A/HLA-DR\u207A",
    y_lab         = "CD8\u207A/HLA-DR\u207A (%)",
    color         = "#D55E00",
    src_data      = "cnt",
    calc          = function(d) d$cd8_hladr / d$cd8 * 100,
    legend_labels = c("- CAR-T" = "Sph+PBMC", "+ CAR-T" = "Sph+PBMC+CAR-T")
  )
)

# ── Preparar datos por población ──────────────────────────────────────────────
build_pop_data <- function(spec) {
  # Seleccionar fuente de datos según spec
  src <- if (spec$src_data == "pct") df_pct else df_base
  # Calcular el valor para todas las filas
  df <- src |>
    mutate(pop_value = spec$calc(src))

  # Línea - CAR-T: cart==NO, 3 tiempos, promedio donantes
  df_no_cart <- df |>
    filter(pbmc == "SI", cart == "NO") |>
    group_by(activation, tiempo) |>
    summarise(value = mean(pop_value, na.rm = TRUE), .groups = "drop") |>
    mutate(line = "- CAR-T")

  # Línea + CAR-T: t=24h del control, t=48/72 de +CAR-T
  df_cart_t0 <- df |>
    filter(pbmc == "SI", cart == "NO", tiempo == 24) |>
    group_by(activation, tiempo) |>
    summarise(value = mean(pop_value, na.rm = TRUE), .groups = "drop") |>
    mutate(line = "+ CAR-T")

  df_cart_rest <- df |>
    filter(pbmc == "SI", cart == "SI") |>
    group_by(activation, tiempo) |>
    summarise(value = mean(pop_value, na.rm = TRUE), .groups = "drop") |>
    mutate(line = "+ CAR-T")

  bind_rows(df_no_cart, df_cart_t0, df_cart_rest) |>
    mutate(
      tiempo_f = factor(as.character(tiempo),
                        levels = c("24", "48", "72"),
                        labels = c("48 h esf\n24 h PBMC",
                                   "72 h esf\n48 h PBMC\n24 h CAR-T",
                                   "96 h esf\n72 h PBMC\n48 h CAR-T")),
      line = factor(line, levels = c("- CAR-T", "+ CAR-T"))
    )
}

# ── Tema ──────────────────────────────────────────────────────────────────────
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

# ── Función de plot ───────────────────────────────────────────────────────────
make_pop_plot <- function(data, act_val, spec, title) {
  plot_data <- data |> filter(activation == act_val)

  # Colores: gris para - CAR-T, color de la población para + CAR-T
  line_colors <- c("- CAR-T" = "#555555", "+ CAR-T" = spec$color)
  line_shapes <- c("- CAR-T" = 16,        "+ CAR-T" = 17)
  leg_labels  <- if (!is.null(spec$legend_labels)) spec$legend_labels else waiver()

  # Y axis: formato según count o %
  is_count <- grepl("count", spec$y_lab, ignore.case = TRUE)

  # Conteos: escala compartida 0-7000, líneas cada 500
  cnt_all_brk   <- seq(0, 7000, 500)
  # CD3: labels cada 1000 (sin break); Macrophages: labels en segmentos (con break)
  use_break     <- isTRUE(spec$use_break)
  cnt_label_brk <- if (use_break) c(0, 1000, 2000, 3500, 5000, 6500)
                   else           seq(0, 7000, 1000)
  cnt_labels_fn <- function(x) ifelse(x %in% cnt_label_brk,
                                      format(x, big.mark = ",", scientific = FALSE), "")

  p <- ggplot(plot_data, aes(x = tiempo_f, y = value,
                              color = line, group = line, shape = line)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = line_colors, labels = leg_labels) +
    scale_shape_manual(values = line_shapes, labels = leg_labels) +
    scale_y_continuous(
      breaks = if (is_count) cnt_all_brk   else seq(0, 100, 20),
      labels = if (is_count) cnt_labels_fn else label_number(suffix = "%", accuracy = 1),
      limits = if (is_count) c(0, 7000)    else c(0, 100),
      expand = expansion(mult = c(0, 0.03))
    )

  # Break visual en 2000 solo para macrophages (use_break == TRUE)
  if (is_count && use_break) {
    p <- p + scale_y_break(c(2000, 2001), scales = 1.5)
  }

  # labs y theme_flow primero; luego suprimir eje derecho (debe ir DESPUÉS de
  # theme_flow para no ser sobreescrito por axis.text.y heredado)
  p <- p +
    labs(title = title, x = NULL, y = spec$y_lab) +
    theme_flow

  if (is_count && use_break) {
    p <- p + theme(
      axis.text.y.right  = element_blank(),
      axis.ticks.y.right = element_blank(),
      axis.line.y.right  = element_blank()
    )
  }

  p
}

# ── Función de guardado ───────────────────────────────────────────────────────
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

# ── Generar todas las figuras ─────────────────────────────────────────────────
act_titles <- c(
  "NO_ACTIVADOS" = "A549+MRC-5 + PBMC + CAR-T",
  "ACTIVADAS"    = "A549+MRC-5 + Activated PBMC + CAR-T"
)
act_titles_short <- c(
  "NO_ACTIVADOS" = "A549+MRC-5+Non-activated PBMC+CAR-T",
  "ACTIVADAS"    = "A549+MRC-5+Activated PBMC+CAR-T"
)
specs_short_title <- c("macrophages_hladr", "macrophages_count", "macrophages_cd11b",
                        "cd4_hladr_pos", "cd8_hladr_pos", "cd3_count")

for (spec in pop_specs) {
  message("\n--- ", spec$label, " ---")
  pop_data <- build_pop_data(spec)

  for (act in c("NO_ACTIVADOS", "ACTIVADAS")) {
    act_suffix <- if (act == "NO_ACTIVADOS") "noact" else "act"
    title <- if (spec$id %in% specs_short_title) {
      act_titles_short[[act]]
    } else {
      paste0(act_titles[[act]], "\n", spec$label)
    }
    p <- make_pop_plot(pop_data, act, spec, title)
    fname <- paste0("05_", spec$id, "_", act_suffix)
    save_fig(p, fname)
  }
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
