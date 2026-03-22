#!/usr/bin/env Rscript
# 13_mfi_cd19.R
# MFI de CD19 en Vivas CD19⁺ a lo largo del tiempo.
#
# Datos: archivos MFI CD19+ (ACTIVADAS y NO ACTIVADOS) en data/raw/.
# Metadata parseada del nombre FCS (col 1): grupo, donante, tiempo.
#
# Figuras:
#   13_mfi_cd19_act/noact       — MFI absoluta
#   13_mfi_cd19_norm_act/noact  — MFI normalizada a UNS A549 CD19 (%)
#
# Tabla:
#   results/tables/13_mfi_cd19_resumen.csv
#
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
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
  paste0("13_mfi_cd19_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
)
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 13_mfi_cd19.R === ", Sys.time())

# ── Lectura y parseo de MFI ─────────────────────────────────────────────────
# Cada archivo tiene 3 columnas: nombre FCS, MFI Zombie Red, MFI CD19.
# Las últimas 2 filas son Mean y SD — se excluyen.
# Metadata se extrae del nombre FCS.

parse_mfi <- function(path, activation) {
  raw <- suppressMessages(
    read_excel(path, col_names = FALSE, na = c("", "-", "NA"))
  )
  # Row 1 = header; últimas 2 filas = Mean/SD
  df <- as.data.frame(raw[-1, ])
  df <- df[!grepl("^(Mean|SD)$", trimws(df[[1]]), ignore.case = TRUE), ]

  out <- data.frame(
    sample_name    = as.character(df[[1]]),
    mfi_zombie_red = suppressWarnings(as.numeric(df[[2]])),
    mfi_cd19       = suppressWarnings(as.numeric(df[[3]])),
    activation     = activation,
    stringsAsFactors = FALSE
  )

  # Parsear metadata del nombre FCS
  # El nombre FCS tiene formato:
  #   "Inmunofenotipo-{date} {experiment}-{sample_desc}_Unmixed.fcs"
  # La metadata está en {sample_desc} = todo después del ÚLTIMO guión,
  # antes de "_Unmixed.fcs". El prefijo contiene el nombre del experimento.
  out <- out |>
    mutate(
      # Extraer desc: quitar "_Unmixed.fcs", luego tomar todo tras último "-"
      desc = sub(".*-", "", sub("_Unmixed\\.fcs$", "", sample_name)),
      desc_upper = toupper(desc),
      # Detectar controles
      is_control = grepl("^UNS ", desc_upper) |
                   grepl("^ESFEROIDE?$", desc_upper),
      control_type = case_when(
        grepl("UNS A549 CD19", desc_upper)  ~ "UNS_A549_CD19",
        grepl("UNS A549 WT", desc_upper)    ~ "UNS_A549_WT",
        grepl("UNS MRC5", desc_upper)       ~ "UNS_MRC5",
        grepl("^ESFEROIDE?$", desc_upper)   ~ "ESFEROIDE_BASELINE",
        TRUE ~ NA_character_
      ),
      # Extraer tiempo bruto del nombre FCS
      # IMPORTANTE: el tiempo en el nombre FCS es relativo al tratamiento, no al esferoide:
      #   Sph. only       → tiempo_raw = tiempo del esferoide (offset 0)
      #   Sph+PBMC        → tiempo_raw = tiempo desde adición de PBMC (offset +24)
      #   Sph+CAR-T       → tiempo_raw = tiempo desde adición de CAR-T (offset +48)
      #   Sph+PBMC+CAR-T  → tiempo_raw = tiempo desde adición de CAR-T (offset +48)
      time_raw = suppressWarnings(as.integer(
        str_match(desc_upper, "(\\d+)\\s*H\\b")[, 2]
      )),
      # Detectar grupo desde desc (no desde el nombre completo)
      has_pbmc = grepl("PBMC", desc_upper),
      has_cart = grepl("CART", desc_upper),
      has_solo = grepl("\\bSOLO\\b", desc_upper),
      group = case_when(
        is_control          ~ NA_character_,
        has_solo            ~ "Sph. only",
        has_pbmc & has_cart ~ "Sph+PBMC+CAR-T",
        has_pbmc            ~ "Sph+PBMC",
        has_cart            ~ "Sph+CAR-T",
        TRUE                ~ NA_character_
      ),
      # Convertir a tiempo del esferoide sumando el offset según grupo
      sph_time = case_when(
        is_control                                       ~ time_raw,
        group == "Sph. only"                             ~ time_raw,
        group == "Sph+PBMC"                              ~ time_raw + 24L,
        group %in% c("Sph+CAR-T", "Sph+PBMC+CAR-T")    ~ time_raw + 48L,
        TRUE                                             ~ time_raw
      ),
      # Detectar donante: D1 o D2 como token aislado (no dentro de CD19)
      donor = case_when(
        is_control ~ NA_character_,
        grepl("\\bD1\\b", desc_upper)  ~ "D1",
        grepl("\\bD2\\b", desc_upper)  ~ "D2",
        grepl("\\bD 1\\b", desc_upper) ~ "D1",
        grepl("\\bD 2\\b", desc_upper) ~ "D2",
        TRUE ~ NA_character_
      )
    ) |>
    select(-desc, -desc_upper, -has_pbmc, -has_cart, -has_solo, -time_raw)

  out
}

f_act   <- file.path(raw_dir, "MFI CD19+ ACTIVADAS.xls")
f_noact <- file.path(raw_dir, "MFI CD19+ NO ACTIVADOS.xls")

df_act   <- parse_mfi(f_act,   "ACTIVADAS")
df_noact <- parse_mfi(f_noact, "NO_ACTIVADOS")

message("Filas MFI ACTIVADAS:    ", nrow(df_act))
message("Filas MFI NO_ACTIVADOS: ", nrow(df_noact))

df_all <- bind_rows(df_act, df_noact)

# Mostrar parseo para verificación
message("\nParseo de muestras:")
print(df_all |> select(activation, sample_name, group, donor, sph_time,
                        control_type, mfi_cd19) |>
        as.data.frame(), right = FALSE)

# ── Referencia de controles (solo en NO ACTIVADOS) ──────────────────────────
controls <- df_all |>
  filter(is_control, !is.na(control_type))

mfi_ref_a549_cd19 <- controls |>
  filter(control_type == "UNS_A549_CD19") |>
  pull(mfi_cd19) |>
  mean(na.rm = TRUE)

mfi_ref_a549_wt <- controls |>
  filter(control_type == "UNS_A549_WT") |>
  pull(mfi_cd19) |>
  mean(na.rm = TRUE)

message("\nReferencias MFI CD19:")
message("  UNS A549 CD19 (transducida): ", round(mfi_ref_a549_cd19))
message("  UNS A549 WT (background):    ", round(mfi_ref_a549_wt))

# ── Filtrar muestras experimentales ─────────────────────────────────────────
df_exp <- df_all |>
  filter(!is_control, !is.na(group), !is.na(sph_time))

message("\nMuestras experimentales: ", nrow(df_exp))
print(df_exp |> count(activation, group, sph_time))

# ── Promediar D1/D2 ────────────────────────────────────────────────────────
df_avg <- df_exp |>
  group_by(activation, group, sph_time) |>
  summarise(
    mfi_cd19       = mean(mfi_cd19, na.rm = TRUE),
    mfi_zombie_red = mean(mfi_zombie_red, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    mfi_cd19_norm_pct = mfi_cd19 / mfi_ref_a549_cd19 * 100
  )

message("\nMFI promediada:")
print(df_avg)

# ── Tabla resumen con valores por donante ───────────────────────────────────
df_donor_tbl <- df_exp |>
  mutate(
    mfi_cd19_norm_pct = round(mfi_cd19 / mfi_ref_a549_cd19 * 100, 1),
    mfi_cd19          = round(mfi_cd19)
  ) |>
  select(activation, group, sph_time, donor, mfi_cd19, mfi_cd19_norm_pct)

df_mean_tbl <- df_donor_tbl |>
  group_by(activation, group, sph_time) |>
  summarise(
    mfi_cd19          = round(mean(mfi_cd19, na.rm = TRUE)),
    mfi_cd19_norm_pct = round(mean(mfi_cd19_norm_pct, na.rm = TRUE), 1),
    .groups = "drop"
  ) |>
  mutate(donor = "mean")

# Agregar controles como filas de referencia
ctrl_tbl <- controls |>
  filter(!is.na(control_type)) |>
  mutate(
    group             = control_type,
    sph_time          = NA_integer_,
    donor             = NA_character_,
    mfi_cd19_norm_pct = round(mfi_cd19 / mfi_ref_a549_cd19 * 100, 1),
    mfi_cd19          = round(mfi_cd19)
  ) |>
  select(activation, group, sph_time, donor, mfi_cd19, mfi_cd19_norm_pct)

tbl_out <- bind_rows(df_donor_tbl, df_mean_tbl, ctrl_tbl) |>
  arrange(activation, group, sph_time, donor)

tbl_path <- file.path(tbl_dir, "13_mfi_cd19_resumen.csv")
write.csv(tbl_out, tbl_path, row.names = FALSE)
message("\nTabla guardada: ", tbl_path)

# ── Preparar datos para figuras ─────────────────────────────────────────────
# Puntos compartidos (misma convención que scripts 07/12):
#   Todos @ t=24h ← Sph.only @ t=24h (si disponible)
#   Sph+PBMC+CAR-T @ t=48h ← Sph+PBMC @ t=48h
#   Sph+CAR-T @ t=48h ← Sph.only @ t=48h

time_levels <- c("48", "72", "96")
time_labels <- c("48 h sph\n24 h PBMC",
                 "72 h sph\n48 h PBMC\n24 h CAR-T",
                 "96 h sph\n72 h PBMC\n48 h CAR-T")

prep_mfi_data <- function(df_src, act_val, y_col) {
  grp_levels <- c("Sph. only", "Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T")

  src <- df_src |> filter(activation == act_val) |>
    mutate(value = .data[[y_col]]) |>
    select(group, sph_time, value)

  # Punto compartido: Sph+PBMC+CAR-T @ t=72h ← Sph+PBMC @ t=72h
  # (CAR-T se añaden a las 48h del esferoide; primer punto propio es t=72h)
  t0_pbmccart <- src |>
    filter(group == "Sph+PBMC", sph_time == 72) |>
    mutate(group = "Sph+PBMC+CAR-T")

  # Punto compartido: Sph+CAR-T @ t=72h ← Sph.only @ t=72h
  t0_cartsolo <- src |>
    filter(group == "Sph. only", sph_time == 72) |>
    mutate(group = "Sph+CAR-T")

  # Eliminar puntos propios que serán reemplazados
  src <- src |>
    filter(!(group == "Sph+PBMC+CAR-T" & sph_time == 72),
           !(group == "Sph+CAR-T"      & sph_time == 72))

  bind_rows(src, t0_pbmccart, t0_cartsolo) |>
    filter(!is.na(value)) |>
    arrange(group, sph_time) |>
    mutate(
      group = factor(group, levels = grp_levels),
      sph_time_f = factor(as.character(sph_time),
                          levels = time_levels,
                          labels = time_labels)
    ) |>
    # Solo mantener tiempos que existen en los datos
    filter(!is.na(sph_time_f))
}

# ── Colores y formas ────────────────────────────────────────────────────────
group_colors <- c(
  "Sph. only"       = "#999999",
  "Sph+CAR-T"       = "#E69F00",
  "Sph+PBMC"        = "#555555",
  "Sph+PBMC+CAR-T"  = "#009E73"
)
group_shapes <- c(
  "Sph. only"       = 15L,
  "Sph+CAR-T"       = 18L,
  "Sph+PBMC"        = 16L,
  "Sph+PBMC+CAR-T"  = 17L
)

# ── Función de plot (MFI absoluta) ──────────────────────────────────────────
make_mfi_plot <- function(plot_data, title, y_lab, ref_high = NULL,
                          ref_low = NULL) {
  p <- ggplot(plot_data,
              aes(x = sph_time_f, y = value,
                  color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    scale_shape_manual(values = group_shapes, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    scale_y_continuous(labels = scales::label_comma(),
                       limits = c(0, 350000)) +
    labs(title = title, x = NULL, y = y_lab) +
    theme_flow

  # Líneas de referencia de controles (si se proporcionan)
  if (!is.null(ref_high) && !is.na(ref_high)) {
    p <- p + geom_hline(yintercept = ref_high, linetype = "dashed",
                        color = "#0072B2", linewidth = 0.4) +
      annotate("text", x = -Inf, y = ref_high, label = "A549 CD19",
               color = "#0072B2", size = 2.8, hjust = -0.1, vjust = -0.5)
  }
  if (!is.null(ref_low) && !is.na(ref_low)) {
    p <- p + geom_hline(yintercept = ref_low, linetype = "dotted",
                        color = "#D55E00", linewidth = 0.4) +
      annotate("text", x = -Inf, y = ref_low, label = "A549 WT",
               color = "#D55E00", size = 2.8, hjust = -0.1, vjust = -0.5)
  }
  p
}

# ── Generar figuras ─────────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC"),
  list(val = "ACTIVADAS",    suf = "act",   label = "Activated PBMC")
)

for (act in act_meta) {
  message("\n--- MFI absoluta: ", act$val, " ---")

  pd <- prep_mfi_data(df_avg, act$val, "mfi_cd19")
  if (nrow(pd) == 0) {
    message("  SKIP: sin datos")
    next
  }

  message("  ", nrow(pd), " filas, grupos: ",
          paste(unique(pd$group), collapse = ", "))

  title <- paste0("A549+MRC-5+", act$label, "+CAR-T")
  p <- make_mfi_plot(pd, title, "MFI CD19 (Spark Violet 500)",
                     ref_high = mfi_ref_a549_cd19,
                     ref_low  = mfi_ref_a549_wt)
  fname <- paste0("13_mfi_cd19_", act$suf)
  save_fig(p, fname, 130, 110)
}

for (act in act_meta) {
  message("\n--- MFI normalizada: ", act$val, " ---")

  pd <- prep_mfi_data(df_avg, act$val, "mfi_cd19_norm_pct")
  if (nrow(pd) == 0) {
    message("  SKIP: sin datos")
    next
  }

  message("  ", nrow(pd), " filas, grupos: ",
          paste(unique(pd$group), collapse = ", "))

  title <- paste0("A549+MRC-5+", act$label, "+CAR-T")
  p <- ggplot(pd,
              aes(x = sph_time_f, y = value,
                  color = group, group = group, shape = group)) +
    geom_hline(yintercept = 100, linetype = "dashed", color = "#0072B2",
               linewidth = 0.4) +
    annotate("text", x = -Inf, y = 100, label = "A549 CD19 (100%)",
             color = "#0072B2", size = 2.8, hjust = -0.1, vjust = -0.5) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    scale_shape_manual(values = group_shapes, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    labs(title = title, x = NULL,
         y = "Normalized MFI CD19 (% of A549 CD19)") +
    theme_flow

  fname <- paste0("13_mfi_cd19_norm_", act$suf)
  save_fig(p, fname, 130, 110)
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
cat("\u2713 Tabla en: results/tables/13_mfi_cd19_resumen.csv\n")
