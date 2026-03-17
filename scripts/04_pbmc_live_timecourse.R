#!/usr/bin/env Rscript
# 04_pbmc_live_timecourse.R
# Evolución temporal de PBMCs vivas (conteo promedio D1+D2)
# Dos líneas por gráfica: - CAR-T y + CAR-T
# La línea + CAR-T comparte el punto t=24h con - CAR-T (antes de añadir CAR-T)
# Genera 2 figuras separadas: PBMCs no activadas y PBMCs activadas
# Salida: results/figures/04_pbmc_live_noact.pdf/.png
#         results/figures/04_pbmc_live_act.pdf/.png
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(log_dir, paste0("04_pbmc_live_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 04_pbmc_live_timecourse.R === ", Sys.time())

# ── Cargar datos ──────────────────────────────────────────────────────────────
flow <- readRDS(file.path(project_dir, "data", "processed", "flow_clean.rds"))

# Solo condiciones con PBMCs, datos de conteos
df_base <- flow |>
  filter(pbmc == "SI", data_type == "CONTEOS")

# ── Preparar línea "- CAR-T" ──────────────────────────────────────────────────
# cart == NO, los 3 tiempos, promedio D1+D2
df_no_cart <- df_base |>
  filter(cart == "NO") |>
  group_by(activation, tiempo) |>
  summarise(pbmcs_live = mean(pbmcs_live, na.rm = TRUE), .groups = "drop") |>
  mutate(line = "- CAR-T")

# ── Preparar línea "+ CAR-T" ──────────────────────────────────────────────────
# t=24h: tomar el mismo punto que - CAR-T (antes de añadir CAR-T)
df_cart_t0 <- df_base |>
  filter(cart == "NO", tiempo == 24) |>
  group_by(activation, tiempo) |>
  summarise(pbmcs_live = mean(pbmcs_live, na.rm = TRUE), .groups = "drop") |>
  mutate(line = "+ CAR-T")

# t=48h y t=72h: datos reales de condiciones con CAR-T
df_cart_rest <- df_base |>
  filter(cart == "SI") |>
  group_by(activation, tiempo) |>
  summarise(pbmcs_live = mean(pbmcs_live, na.rm = TRUE), .groups = "drop") |>
  mutate(line = "+ CAR-T")

df_cart <- bind_rows(df_cart_t0, df_cart_rest)

# ── Combinar y preparar factores ──────────────────────────────────────────────
tiempo_labels <- c(
  "24" = "48 h esf\n24 h PBMC",
  "48" = "72 h esf\n48 h PBMC\n24 h CAR-T",
  "72" = "96 h esf\n72 h PBMC\n48 h CAR-T"
)

df_plot <- bind_rows(df_no_cart, df_cart) |>
  mutate(
    tiempo_f = factor(as.character(tiempo), levels = c("24", "48", "72"),
                      labels = tiempo_labels),
    line = factor(line, levels = c("- CAR-T", "+ CAR-T"))
  )

message("Filas en df_plot: ", nrow(df_plot))
print(df_plot)

# ── Colores y estéticas ────────────────────────────────────────────────────────
line_colors <- c("- CAR-T" = "#555555", "+ CAR-T" = "#D55E00")
line_types  <- c("- CAR-T" = "solid",   "+ CAR-T" = "solid")
line_shapes <- c("- CAR-T" = 16,        "+ CAR-T" = 17)   # círculo vs triángulo

# ── Tema ──────────────────────────────────────────────────────────────────────
theme_flow <- theme_bw(base_size = 13) +
  theme(
    axis.text.x        = element_text(size = 10, hjust = 0.5, lineheight = 0.9),
    axis.text.y        = element_text(size = 11),
    axis.title         = element_text(size = 12),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 11),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )

# ── Función de plot ───────────────────────────────────────────────────────────
make_line_plot <- function(data, act_val, title) {
  plot_data <- data |> filter(activation == act_val)

  ggplot(plot_data, aes(x = tiempo_f, y = pbmcs_live,
                        color = line, group = line,
                        shape = line, linetype = line)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = line_colors) +
    scale_shape_manual(values = line_shapes) +
    scale_linetype_manual(values = line_types) +
    scale_y_continuous(
      breaks = seq(0, 7000, 500),
      labels = function(x) ifelse(x %% 1000 == 0,
                                  format(x, big.mark = ",", scientific = FALSE), ""),
      limits = c(0, 7000),
      expand = expansion(mult = c(0, 0.03))
    ) +
    labs(
      title = title,
      x     = NULL,
      y     = "Live PBMCs (count)"
    ) +
    theme_flow
}

# ── Generar figuras ───────────────────────────────────────────────────────────
p_noact <- make_line_plot(df_plot, "NO_ACTIVADOS",
                          "A549+MRC-5 + PBMC + CAR-T")
p_act   <- make_line_plot(df_plot, "ACTIVADAS",
                          "A549+MRC-5 + Activated PBMC + CAR-T")

# ── Guardar ───────────────────────────────────────────────────────────────────
save_fig <- function(p, name, w = 110, h = 100) {
  pdf_path <- file.path(fig_dir, paste0(name, ".pdf"))
  png_path <- file.path(fig_dir, paste0(name, ".png"))
  ggsave(pdf_path, p, width = w, height = h, units = "mm",
         device = cairo_pdf, limitsize = FALSE)
  ggsave(png_path, p, width = w, height = h, units = "mm",
         dpi = 300, device = "png", limitsize = FALSE)
  message("\u2713 Guardado: ", basename(pdf_path),
          sprintf("  (%.0f\u00d7%.0f mm)", w, h))
}

save_fig(p_noact, "04_pbmc_live_noact")
save_fig(p_act,   "04_pbmc_live_act")

message("=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
