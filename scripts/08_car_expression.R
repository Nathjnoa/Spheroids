#!/usr/bin/env Rscript
# 08_car_expression.R
# Time-course plots for:
#   (1) % viable CD19+ cells          — VIABILIDAD PORCENTAJES, col 12/13
#   (2) CD3+ viable CAR-T count       — EXPRESIÓN CAR CONTEOS, col 6
#   (3) % CAR-T (of viable cells)     — EXPRESIÓN CAR PORCENTAJES, col 6
#   (4) CAR-T CD4+ (% of CAR-T)       — EXPRESIÓN CAR PORCENTAJES, col 7
#   (5) CAR-T CD8+ (% of CAR-T)       — EXPRESIÓN CAR PORCENTAJES, col 8
# One figure per variable per activation state = 10 figures total.
# Ambient: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(here)
})

# ── Paths ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
raw_dir     <- file.path(project_dir, "data", "raw")
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(log_dir, paste0("08_car_expression_",
                        format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 08_car_expression.R === ", Sys.time())

# ── Helper: parse mixed percentage format ─────────────────────────────────────
# Handles "7.67%", "26,5 %", "4.66E-2", 0.145, NA
# Values < 2 are treated as proportions (0-1) and multiplied by 100
parse_pct <- function(x) {
  x       <- trimws(as.character(x))
  had_pct <- grepl("%", x, fixed = TRUE)   # fue almacenado con signo %?
  x <- gsub("%", "", x, fixed = TRUE)
  x <- trimws(x)
  x <- gsub(",", ".", x, fixed = TRUE)
  val <- suppressWarnings(as.numeric(x))
  # Solo multiplicar ×100 si NO tenía signo % (valor guardado como proporción 0-1)
  ifelse(!is.na(val) & !had_pct & val < 2, val * 100, val)
}

# ── 1. VIABILIDAD PORCENTAJES → CD19+ % ──────────────────────────────────────
# ACTIVADAS:   col 12 = "Vivas CD19+"
# NO ACTIVADAS: col 13 = "Vivas CD19+"
read_viab_pct <- function(path, activation) {
  raw <- suppressMessages(read_excel(path, col_names = FALSE, na = c("", "-", "NA")))
  df  <- as.data.frame(raw[-1, ])
  col_cd19 <- if (activation == "ACTIVADAS") 12L else 13L
  data.frame(
    pbmc       = toupper(trimws(as.character(df[[2]]))),
    donor      = as.character(df[[3]]),
    cart       = toupper(trimws(as.character(df[[4]]))),
    tiempo     = suppressWarnings(as.numeric(df[[5]])),
    activation = activation,
    cd19_pct   = parse_pct(df[[col_cd19]]),
    stringsAsFactors = FALSE
  ) |> filter(!is.na(tiempo))
}

df_cd19 <- bind_rows(
  read_viab_pct(
    file.path(raw_dir, "ACTIVADAS PORCENTAJES VIABILIDAD (PBMC+CART).xlsx"),
    "ACTIVADAS"),
  read_viab_pct(
    file.path(raw_dir, "NO ACTIVADOS PORCENTAJES VIABILIDAD-FLAG (PBMC+CART).xlsx"),
    "NO_ACTIVADOS")
) |> mutate(
  group = case_when(
    pbmc == "NO" & cart == "NO" ~ "Sph. only",
    pbmc == "NO" & cart == "SI" ~ "Sph+CAR-T",
    pbmc == "SI" & cart == "NO" ~ "Sph+PBMC",
    pbmc == "SI" & cart == "SI" ~ "Sph+PBMC+CAR-T"
  ),
  group = factor(group, levels = c("Sph. only", "Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"))
)
message("CD19+ pct rows: ", nrow(df_cd19))
print(count(df_cd19, activation, group, tiempo))

# ── 2. VIABILIDAD CONTEOS → CD3+ Vivas ───────────────────────────────────────
# ACTIVADOS col 15 (O): "CD3+ Vivas"
# NO ACTIVADOS col 18 (R): "PBMC's Vivas/CD3+"
read_cd3_viab <- function(path, activation, cd3_col) {
  raw <- suppressMessages(read_excel(path, col_names = FALSE, na = c("", "-", "NA")))
  df  <- as.data.frame(raw[-1, ])
  data.frame(
    pbmc       = toupper(trimws(as.character(df[[2]]))),
    donor      = as.character(df[[3]]),
    cart       = toupper(trimws(as.character(df[[4]]))),
    tiempo     = suppressWarnings(as.numeric(df[[5]])),
    activation = activation,
    cd3_count  = suppressWarnings(as.numeric(df[[cd3_col]])),
    stringsAsFactors = FALSE
  ) |> filter(!is.na(tiempo))
}

df_cd3 <- bind_rows(
  read_cd3_viab(file.path(raw_dir, "ACTIVADOS CONTEOS VIABILIDAD (PBMC+CART).xlsx"),          "ACTIVADAS",    15L),
  read_cd3_viab(file.path(raw_dir, "NO ACTIVADOS CONTEOS VIABILIDAD-FLAG (PBMC+CART).xlsx"), "NO_ACTIVADOS", 18L)
) |> mutate(
  group = case_when(
    pbmc == "NO" & cart == "SI" ~ "Sph+CAR-T",
    pbmc == "SI" & cart == "SI" ~ "Sph+PBMC+CAR-T",
    pbmc == "SI" & cart == "NO" ~ "Sph+PBMC"
  ),
  group = factor(group, levels = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"))
)
message("CD3+ count rows: ", nrow(df_cd3))
print(count(df_cd3, activation, group, tiempo))

# ── 3. EXPRESIÓN CAR PORCENTAJES → % CAR-T, CD4+, CD8+ ──────────────────────
# col 6: % CAR-T of viable cells
# col 7: % CD4+ of CAR-T
# col 8: % CD8+ of CAR-T
read_car_pct <- function(path, activation) {
  raw <- suppressMessages(read_excel(path, col_names = FALSE, na = c("", "-", "NA")))
  df  <- as.data.frame(raw[-1, ])
  data.frame(
    pbmc       = toupper(trimws(as.character(df[[2]]))),
    donor      = as.character(df[[3]]),
    cart       = toupper(trimws(as.character(df[[4]]))),
    tiempo     = suppressWarnings(as.numeric(df[[5]])),
    activation = activation,
    cart_pct   = parse_pct(df[[6]]),
    cd4_pct    = parse_pct(df[[7]]),
    cd8_pct    = parse_pct(df[[8]]),
    stringsAsFactors = FALSE
  ) |> filter(!is.na(tiempo))
}

df_car_pct <- bind_rows(
  read_car_pct(file.path(raw_dir, "EXPRESIÓN CAR PORCENTAJES ACTIVADAS.xlsx"),    "ACTIVADAS"),
  read_car_pct(file.path(raw_dir, "EXPRESIÓN CAR PORCENTAJES NO ACTIVADAS.xlsx"), "NO_ACTIVADOS")
) |> mutate(
  group = case_when(
    pbmc == "NO" & cart == "SI" ~ "Sph+CAR-T",
    pbmc == "SI" & cart == "SI" ~ "Sph+PBMC+CAR-T"
  ),
  group = factor(group, levels = c("Sph+CAR-T", "Sph+PBMC+CAR-T"))
)
message("CAR-T pct rows: ", nrow(df_car_pct))
print(count(df_car_pct, activation, group, tiempo))

# ── Time labels ───────────────────────────────────────────────────────────────
labs_4 <- c(
  "24" = "24 h sph.\n\u2014",
  "48" = "48 h sph\n24 h PBMC",
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)
labs_2 <- c(
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)
labs_3 <- c(
  "48" = "48 h sph\n24 h PBMC",
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)

# ── Colors / shapes ───────────────────────────────────────────────────────────
cols_4 <- c("Sph. only" = "#999999", "Sph+CAR-T" = "#E69F00",
            "Sph+PBMC" = "#555555", "Sph+PBMC+CAR-T" = "#009E73")
shps_4 <- c("Sph. only" = 15L, "Sph+CAR-T" = 18L,
            "Sph+PBMC" = 16L, "Sph+PBMC+CAR-T" = 17L)
cols_2 <- c("Sph+CAR-T" = "#E69F00", "Sph+PBMC+CAR-T" = "#009E73")
shps_2 <- c("Sph+CAR-T" = 18L, "Sph+PBMC+CAR-T" = 17L)

# ── Theme ─────────────────────────────────────────────────────────────────────
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

# ── Prep: average donors, factor time ────────────────────────────────────────
prep_simple <- function(df, act_val, value_col, time_labs) {
  df |>
    filter(activation == act_val) |>
    group_by(group, tiempo) |>
    summarise(value = mean(.data[[value_col]], na.rm = TRUE), .groups = "drop") |>
    filter(!is.na(value)) |>
    mutate(
      tiempo_f = factor(as.character(tiempo),
                        levels = names(time_labs),
                        labels = unname(time_labs))
    ) |>
    filter(!is.na(tiempo_f)) |>
    arrange(group, tiempo)
}

# CD3+ count: 3 timepoints (48, 72, 96h)
# Sph+PBMC+CAR-T @ 48h ← Sph+PBMC @ 48h (baseline before CAR-T addition)
# Sph+CAR-T       @ 48h ← 0 (no PBMCs, no CD3+ T cells)
prep_cd3_count <- function(act_val) {
  avg <- df_cd3 |>
    filter(activation == act_val) |>
    group_by(group, tiempo) |>
    summarise(value = mean(cd3_count, na.rm = TRUE), .groups = "drop") |>
    filter(!is.na(value))

  b48 <- avg |> filter(group == "Sph+PBMC", tiempo == 48) |> pull(value)

  shared_48 <- bind_rows(
    if (length(b48) == 1) data.frame(group = "Sph+PBMC+CAR-T", tiempo = 48L, value = b48,
                                     stringsAsFactors = FALSE) else NULL,
    data.frame(group = "Sph+CAR-T", tiempo = 48L, value = 0, stringsAsFactors = FALSE)
  )

  avg |>
    filter(group %in% c("Sph+CAR-T", "Sph+PBMC+CAR-T")) |>
    bind_rows(shared_48) |>
    mutate(
      group    = factor(group, levels = c("Sph+CAR-T", "Sph+PBMC+CAR-T")),
      tiempo_f = factor(as.character(tiempo),
                        levels = names(labs_3), labels = unname(labs_3))
    ) |>
    filter(!is.na(tiempo_f)) |>
    arrange(group, tiempo)
}

# CD19+: add shared baselines (mirrors script 07 logic)
prep_cd19 <- function(act_val) {
  avg <- df_cd19 |>
    filter(activation == act_val) |>
    group_by(group, tiempo) |>
    summarise(value = mean(cd19_pct, na.rm = TRUE), .groups = "drop") |>
    filter(!is.na(value))

  # All non-Sph groups share Sph.only @ t=24 (pre-PBMC baseline)
  b24 <- avg |> filter(group == "Sph. only", tiempo == 24) |> pull(value)
  if (length(b24) == 1) {
    shared_24 <- data.frame(
      group  = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"),
      tiempo = 24L, value = b24)
    avg <- bind_rows(avg, shared_24)
  }

  # +CAR-T @ t=48 ← -CAR-T @ t=48; CAR-T only @ t=48 ← Sph.only @ t=48
  b48_neg <- avg |> filter(group == "Sph+PBMC", tiempo == 48) |> pull(value)
  b48_sph <- avg |> filter(group == "Sph. only",   tiempo == 48) |> pull(value)
  shared_48 <- bind_rows(
    if (length(b48_neg) == 1) data.frame(group = "Sph+PBMC+CAR-T",    tiempo = 48L, value = b48_neg) else NULL,
    if (length(b48_sph) == 1) data.frame(group = "Sph+CAR-T", tiempo = 48L, value = b48_sph) else NULL
  )
  avg <- avg |>
    filter(!(group == "Sph+PBMC+CAR-T"    & tiempo == 48),
           !(group == "Sph+CAR-T" & tiempo == 48)) |>
    bind_rows(shared_48)

  avg |>
    mutate(
      group    = factor(group, levels = c("Sph. only", "Sph+CAR-T",
                                          "Sph+PBMC", "Sph+PBMC+CAR-T")),
      tiempo_f = factor(as.character(tiempo),
                        levels = names(labs_4), labels = unname(labs_4))
    ) |>
    filter(!is.na(tiempo_f)) |>
    arrange(group, tiempo)
}

# ── Plot function ─────────────────────────────────────────────────────────────
make_plot <- function(plot_data, title, y_lab, colors, shapes, y_pct) {
  p <- ggplot(plot_data,
              aes(x = tiempo_f, y = value,
                  color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = colors, drop = TRUE) +
    scale_shape_manual(values = shapes, drop = TRUE) +
    labs(title = title, x = NULL, y = y_lab) +
    theme_flow

  if (y_pct) {
    p + scale_y_continuous(
      breaks = seq(0, 100, 20),
      labels = label_number(suffix = "%", accuracy = 1),
      limits = c(0, 100),
      expand = expansion(mult = c(0, 0.03))
    )
  } else {
    y_ceil <- max(ceiling(max(plot_data$value, na.rm = TRUE) / 100) * 100, 500)
    p + scale_y_continuous(
      breaks = pretty(c(0, y_ceil), n = 5),
      labels = label_comma(),
      limits = c(0, y_ceil),
      expand = expansion(mult = c(0, 0.03))
    )
  }
}

save_fig <- function(p, name, w = 120, h = 100) {
  ggsave(file.path(fig_dir, paste0(name, ".pdf")), p,
         width = w, height = h, units = "mm", device = cairo_pdf, limitsize = FALSE)
  ggsave(file.path(fig_dir, paste0(name, ".png")), p,
         width = w, height = h, units = "mm", dpi = 300, limitsize = FALSE)
  message("\u2713 Saved: ", name)
}

# ── Generate all figures ──────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC"),
  list(val = "ACTIVADAS",    suf = "act",   label = "Activated PBMC")
)

for (act in act_meta) {
  bt <- paste0("A549+MRC-5 \u00b1 ", act$label, " \u00b1 CAR-T\n")

  # CD19+ % (4 time points, shared baselines)
  message("\n--- CD19+ % | ", act$val, " ---")
  pd <- prep_cd19(act$val)
  message("  rows: ", nrow(pd))
  print(pd)
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, paste0(bt, "Viable CD19\u207A cells"),
                       "Viable CD19\u207A cells (%)", cols_4, shps_4, TRUE),
             paste0("08_cd19_pct_", act$suf))

  # CD3+ count (3 time points: 48h baseline=0, 72h, 96h)
  message("\n--- CD3+ count | ", act$val, " ---")
  pd <- prep_cd3_count(act$val)
  message("  rows: ", nrow(pd))
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, paste0("A549+MRC-5+", act$label, "+CAR-T"),
                       "Viable CD3\u207A cells (count)", cols_2, shps_2, FALSE),
             paste0("08_cd3_count_", act$suf))

  # % CAR-T (2 time points)
  message("\n--- % CAR-T | ", act$val, " ---")
  pd <- prep_simple(df_car_pct, act$val, "cart_pct", labs_2)
  message("  rows: ", nrow(pd))
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, paste0("A549+MRC-5+", act$label, " + CAR-T"),
                       "CAR expression (%)", cols_2, shps_2, TRUE),
             paste0("08_cart_pct_", act$suf))

  # % CAR-T CD4+ (2 time points)
  message("\n--- % CAR-T CD4+ | ", act$val, " ---")
  pd <- prep_simple(df_car_pct, act$val, "cd4_pct", labs_2)
  message("  rows: ", nrow(pd))
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, paste0("A549+MRC-5+", act$label, "+CAR-T"),
                       "% CAR-T CD4\u207A cells", cols_2, shps_2, TRUE),
             paste0("08_cd4_pct_", act$suf))

  # % CAR-T CD8+ (2 time points)
  message("\n--- % CAR-T CD8+ | ", act$val, " ---")
  pd <- prep_simple(df_car_pct, act$val, "cd8_pct", labs_2)
  message("  rows: ", nrow(pd))
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, paste0("A549+MRC-5+", act$label, "+CAR-T"),
                       "% CAR-T CD8\u207A cells", cols_2, shps_2, TRUE),
             paste0("08_cd8_pct_", act$suf))
}

message("\n=== Done: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log:", log_file, "\n")
cat("\u2713 Figures in: results/figures/\n")
