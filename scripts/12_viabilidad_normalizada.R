#!/usr/bin/env Rscript
# 12_viabilidad_normalizada.R
# Viabilidad normalizada al control (Sph. only) y citotoxicidad específica.
#
# Normaliza conteos de células vivas de cada grupo al Sph. only del mismo
# timepoint: % viab = (Vivas_grupo / Vivas_sph_only) × 100.
# Calcula para esferoide total, Vivas CD19⁺ y Vivas CD19⁻.
#
# Fuente: CONTEOS VIABILIDAD (mismos archivos que script 07).
#
# Figuras:
#   12_viab_total_act/noact    — esferoide total
#   12_viab_cd19pos_act/noact  — Vivas CD19⁺
#   12_viab_cd19neg_act/noact  — Vivas CD19⁻
#
# Tabla:
#   results/tables/12_citotoxicidad_resumen.csv
#
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# ── Rutas ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
raw_dir     <- file.path(project_dir, "data", "raw")
fig_dir     <- file.path(project_dir, "results", "figures")
tbl_dir     <- file.path(project_dir, "results", "tables")
log_dir     <- file.path(project_dir, "logs")

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tbl_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

source(file.path(project_dir, "scripts", "00_theme.R"))
theme_flow <- theme_flow + theme(legend.text = element_text(size = 10))

log_file <- file.path(
  log_dir,
  paste0("12_viabilidad_norm_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
)
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 12_viabilidad_normalizada.R === ", Sys.time())

# ── Índices de columna por archivo ──────────────────────────────────────────
# ACTIVADAS CONTEOS VIABILIDAD (29 cols):
#   col 10 = Esferoide/Vivas,  col 11 = Vivas CD19+,  col 12 = Vivas CD19-
# NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (22 cols):
#   col 11 = Esferoide/Vivas,  col 12 = Vivas CD19-,  col 13 = Vivas CD19+
COL_SPH_ACT      <- 10L; COL_CD19P_ACT   <- 11L; COL_CD19N_ACT   <- 12L
COL_SPH_NOACT    <- 11L; COL_CD19P_NOACT <- 13L; COL_CD19N_NOACT <- 12L

# ── Lectura ─────────────────────────────────────────────────────────────────
read_viab_extended <- function(path, activation) {
  raw <- suppressMessages(
    read_excel(path, col_names = FALSE, na = c("", "-", "NA"))
  )
  df <- as.data.frame(raw[-1, ])

  col_sph   <- if (activation == "ACTIVADAS") COL_SPH_ACT   else COL_SPH_NOACT
  col_cd19p <- if (activation == "ACTIVADAS") COL_CD19P_ACT else COL_CD19P_NOACT
  col_cd19n <- if (activation == "ACTIVADAS") COL_CD19N_ACT else COL_CD19N_NOACT

  data.frame(
    sample_label = as.character(df[[1]]),
    pbmc         = toupper(trimws(as.character(df[[2]]))),
    donor        = as.character(df[[3]]),
    cart         = toupper(trimws(as.character(df[[4]]))),
    tiempo       = suppressWarnings(as.numeric(df[[5]])),
    activation   = activation,
    sph_vivas    = suppressWarnings(as.numeric(df[[col_sph]])),
    cd19pos      = suppressWarnings(as.numeric(df[[col_cd19p]])),
    cd19neg      = suppressWarnings(as.numeric(df[[col_cd19n]])),
    stringsAsFactors = FALSE
  ) |>
    filter(!is.na(tiempo))
}

f_act   <- file.path(raw_dir, "ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx")
f_noact <- file.path(raw_dir, "NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx")

df_act   <- read_viab_extended(f_act,   "ACTIVADAS")
df_noact <- read_viab_extended(f_noact, "NO_ACTIVADOS")

message("Filas ACTIVADAS:    ", nrow(df_act))
message("Filas NO_ACTIVADOS: ", nrow(df_noact))

# ── Asignar grupo y sph_time ───────────────────────────────────────────────
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
                              "Sph+PBMC", "Sph+PBMC+CAR-T")),
    # Asignar D1/D2 cuando donor="/" pero hay filas múltiples (Sph+CAR-T)
    donor = ifelse(donor == "/" | is.na(donor), NA_character_, donor)
  ) |>
  group_by(activation, group, sph_time) |>
  mutate(donor = ifelse(is.na(donor) & n() > 1,
                        as.character(row_number()), donor)) |>
  ungroup()

message("\nResumen de datos crudos:")
print(df_all |> count(activation, group, sph_time))

# ── Calcular viabilidad normalizada ─────────────────────────────────────────
# Promediar D1 y D2 por grupo y tiempo (Sph.only tiene un solo valor por tp)
df_avg <- df_all |>
  group_by(activation, group, sph_time) |>
  summarise(
    sph_vivas = mean(sph_vivas, na.rm = TRUE),
    cd19pos   = mean(cd19pos,   na.rm = TRUE),
    cd19neg   = mean(cd19neg,   na.rm = TRUE),
    .groups   = "drop"
  )

# Referencia: Sph. only por activation × sph_time
ref <- df_avg |>
  filter(group == "Sph. only") |>
  select(activation, sph_time,
         ref_total = sph_vivas,
         ref_cd19p = cd19pos,
         ref_cd19n = cd19neg)

df_norm <- df_avg |>
  filter(group != "Sph. only") |>
  left_join(ref, by = c("activation", "sph_time")) |>
  mutate(
    viab_total_pct    = sph_vivas / ref_total * 100,
    viab_cd19pos_pct  = cd19pos   / ref_cd19p * 100,
    viab_cd19neg_pct  = cd19neg   / ref_cd19n * 100,
    citotox_total_pct = 100 - viab_total_pct,
    citotox_cd19pos_pct = 100 - viab_cd19pos_pct
  )

message("\nViabilidad normalizada (resumen):")
print(df_norm |> select(activation, group, sph_time,
                         viab_total_pct, viab_cd19pos_pct, viab_cd19neg_pct))

# ── Tabla resumen con valores por donante ───────────────────────────────────
# Calcular también por donante individual para la tabla del manuscrito
df_donor <- df_all |>
  filter(group != "Sph. only")

ref_raw <- df_all |>
  filter(group == "Sph. only") |>
  select(activation, sph_time,
         ref_total = sph_vivas,
         ref_cd19p = cd19pos,
         ref_cd19n = cd19neg)

df_donor_norm <- df_donor |>
  left_join(ref_raw, by = c("activation", "sph_time")) |>
  mutate(
    viab_total_pct      = round(sph_vivas / ref_total * 100, 1),
    viab_cd19pos_pct    = round(cd19pos   / ref_cd19p * 100, 1),
    viab_cd19neg_pct    = round(cd19neg   / ref_cd19n * 100, 1),
    citotox_total_pct   = round(100 - viab_total_pct, 1),
    citotox_cd19pos_pct = round(100 - viab_cd19pos_pct, 1),
    donor_label         = ifelse(donor == "/" | is.na(donor), NA_character_,
                                 paste0("D", donor))
  ) |>
  filter(!is.na(donor_label)) |>
  select(activation, group, sph_time, donor = donor_label,
         viab_total_pct, viab_cd19pos_pct, viab_cd19neg_pct,
         citotox_total_pct, citotox_cd19pos_pct)

# Agregar fila "mean" por grupo × activation × sph_time
df_mean <- df_donor_norm |>
  group_by(activation, group, sph_time) |>
  summarise(across(where(is.numeric), ~ round(mean(.x, na.rm = TRUE), 1)),
            .groups = "drop") |>
  mutate(donor = "mean")

tbl_out <- bind_rows(df_donor_norm, df_mean) |>
  arrange(activation, group, sph_time, donor)

tbl_path <- file.path(tbl_dir, "12_citotoxicidad_resumen.csv")
write.csv(tbl_out, tbl_path, row.names = FALSE)
message("\nTabla guardada: ", tbl_path)

# ── Preparar datos para figuras ─────────────────────────────────────────────
# Puntos compartidos (igual que script 07):
#   Todos los grupos @ t=24h ← Sph. only baseline → viab = 100%
#   Sph+PBMC+CAR-T @ t=48h ← Sph+PBMC @ t=48h
#   Sph+CAR-T @ t=48h ← Sph. only @ t=48h → viab = 100%

time_levels <- c("24", "48", "72", "96")
time_labels <- c("24 h sph.\n\u2014",
                 "48 h sph\n24 h PBMC",
                 "72 h sph\n48 h PBMC\n24 h CAR-T",
                 "96 h sph\n72 h PBMC\n48 h CAR-T")

prep_norm_data <- function(df_norm_src, act_val, y_col) {
  grp_levels <- c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T")

  src <- df_norm_src |> filter(activation == act_val)

  # Baseline: todos los grupos a t=24h = 100%
  baseline_24 <- lapply(grp_levels, function(g) {
    data.frame(group = g, sph_time = 24L, value = 100,
               stringsAsFactors = FALSE)
  }) |> bind_rows()

  # Datos existentes (t >= 48)
  df_plot <- src |>
    mutate(value = .data[[y_col]]) |>
    select(group, sph_time, value) |>
    filter(!is.na(value))

  # Punto compartido: Sph+PBMC+CAR-T @ t=48 ← Sph+PBMC @ t=48
  t0_pbmccart <- df_plot |>
    filter(group == "Sph+PBMC", sph_time == 48) |>
    mutate(group = "Sph+PBMC+CAR-T")

  # Punto compartido: Sph+CAR-T @ t=48 ← Sph. only @ t=48 → 100%
  t0_cartsolo <- data.frame(
    group = "Sph+CAR-T", sph_time = 48L, value = 100,
    stringsAsFactors = FALSE
  )

  # Eliminar puntos t=48 propios de grupos con valor compartido
  df_plot <- df_plot |>
    filter(!(group == "Sph+PBMC+CAR-T" & sph_time == 48),
           !(group == "Sph+CAR-T"      & sph_time == 48))

  bind_rows(baseline_24, df_plot, t0_pbmccart, t0_cartsolo) |>
    arrange(group, sph_time) |>
    mutate(
      group = factor(group, levels = grp_levels),
      sph_time_f = factor(as.character(sph_time),
                          levels = time_levels,
                          labels = time_labels)
    )
}

# ── Colores y formas ────────────────────────────────────────────────────────
group_colors <- c(
  "Sph+CAR-T"       = "#E69F00",
  "Sph+PBMC"        = "#555555",
  "Sph+PBMC+CAR-T"  = "#009E73"
)
group_shapes <- c(
  "Sph+CAR-T"       = 18L,
  "Sph+PBMC"        = 16L,
  "Sph+PBMC+CAR-T"  = 17L
)

# ── Función de plot ─────────────────────────────────────────────────────────
make_norm_plot <- function(plot_data, title, y_lab) {
  ggplot(plot_data,
         aes(x = sph_time_f, y = value,
             color = group, group = group, shape = group)) +
    geom_hline(yintercept = 100, linetype = "dashed", color = "grey50",
               linewidth = 0.5) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors,
                       guide = guide_legend(nrow = 1)) +
    scale_shape_manual(values = group_shapes,
                       guide = guide_legend(nrow = 1)) +
    labs(title = title, x = NULL, y = y_lab) +
    theme_flow
}

# ── Generar figuras ─────────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC"),
  list(val = "ACTIVADAS",    suf = "act",   label = "Activated PBMC")
)

plot_vars <- list(
  list(col = "viab_total_pct",   id = "viab_total",
       y_lab = "Normalized viability (%)",
       title_suf = "Spheroid total"),
  list(col = "viab_cd19pos_pct", id = "viab_cd19pos",
       y_lab = "Normalized viability CD19\u207a (%)",
       title_suf = "Viable CD19\u207a cells"),
  list(col = "viab_cd19neg_pct", id = "viab_cd19neg",
       y_lab = "Normalized viability CD19\u207b (%)",
       title_suf = "Viable CD19\u207b cells")
)

for (pvar in plot_vars) {
  message("\n--- Variable: ", pvar$col, " ---")
  for (act in act_meta) {
    pd <- prep_norm_data(df_norm, act$val, pvar$col)

    if (nrow(pd) == 0) {
      message("  SKIP: sin datos para ", act$val)
      next
    }

    message("  ", act$val, ": ", nrow(pd), " filas, grupos: ",
            paste(unique(pd$group), collapse = ", "))

    title <- paste0("A549+MRC-5+", act$label, "+CAR-T")
    p     <- make_norm_plot(pd, title, pvar$y_lab)
    fname <- paste0("12_", pvar$id, "_", act$suf)
    save_fig(p, fname, 130, 110)
  }
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
cat("\u2713 Tabla en: results/tables/12_citotoxicidad_resumen.csv\n")
