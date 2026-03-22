#!/usr/bin/env Rscript
# 09_cd4_cd8_count_timecourse.R
# Time-course of live CD4+ and CD8+ cell counts (from PBMC populations).
# Three groups: Sph+PBMC, Sph+PBMC+CAR-T, Sph+CAR-T
#   - Sph+PBMC and Sph+PBMC+CAR-T: cd4/cd8 from flow_clean.rds (CONTEOS)
#   - Sph+CAR-T (no PBMC): Vivas/CAR-T CD4+ and CD8+ from EXPRESIÓN CAR CONTEOS
# Shared baselines at PBMC time 24h:
#   - Sph+PBMC+CAR-T @ 24h ← Sph+PBMC @ 24h (pre-CAR-T addition)
#   - Sph+CAR-T @ 24h = 0 (no cells before CAR-T added)
# Output: 4 figures (CD4+ × 2 activation states, CD8+ × 2 activation states)
# Ambient: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(ggplot2)
  library(scales)
})

# ── Paths ─────────────────────────────────────────────────────────────────────
project_dir <- here::here()
raw_dir     <- file.path(project_dir, "data", "raw")
proc_dir    <- file.path(project_dir, "data", "processed")
fig_dir     <- file.path(project_dir, "results", "figures")
log_dir     <- file.path(project_dir, "logs")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

source(file.path(project_dir, "scripts", "00_theme.R"))
theme_flow <- theme_flow + theme(legend.text = element_text(size = 9))

log_file <- file.path(log_dir, paste0("09_cd4_cd8_count_",
                        format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 09_cd4_cd8_count_timecourse.R === ", Sys.time())

# ── 1. Sph+PBMC and Sph+PBMC+CAR-T from flow_clean.rds ───────────────────────
# tiempo in flow_clean = PBMC time (24, 48, 72h)
# cd4 = col 16 = live CD4+ count; cd8 = col 18 = live CD8+ count
flow <- readRDS(file.path(proc_dir, "flow_clean.rds"))

df_pbmc <- flow |>
  filter(data_type == "CONTEOS", pbmc == "SI") |>
  mutate(
    tiempo = as.numeric(as.character(tiempo)),
    group = case_when(
      cart == "NO" ~ "Sph+PBMC",
      cart == "SI" ~ "Sph+PBMC+CAR-T"
    ),
    group = factor(group, levels = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"))
  ) |>
  select(activation, group, donor, tiempo, cd4, cd8)

message("PBMC populations rows: ", nrow(df_pbmc))
print(count(df_pbmc, activation, group, tiempo))

# ── 2. Sph+CAR-T from EXPRESIÓN CAR CONTEOS (PBMC=NO) ────────────────────────
# TIEMPO in these files = total experiment time (72, 96h)
# PBMC time = total - 24 → 48, 72h
# col 7: Vivas/CAR-T CD4+; col 8: Vivas/CAR-T CD8+
read_car_counts <- function(path, activation) {
  raw <- suppressMessages(read_excel(path, col_names = FALSE,
                                     na = c("", "-", "NA")))
  df  <- as.data.frame(raw[-1, ])
  data.frame(
    activation = activation,
    pbmc       = toupper(trimws(as.character(df[[2]]))),
    cart       = toupper(trimws(as.character(df[[4]]))),
    tiempo     = suppressWarnings(as.numeric(df[[5]])),
    cd4        = suppressWarnings(as.numeric(df[[7]])),
    cd8        = suppressWarnings(as.numeric(df[[8]])),
    stringsAsFactors = FALSE
  ) |>
    filter(!is.na(tiempo), pbmc == "NO", cart == "SI") |>
    mutate(
      tiempo = tiempo - 24L,   # convert total → PBMC time (72→48, 96→72)
      group  = factor("Sph+CAR-T",
                      levels = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"))
    ) |>
    select(activation, group, tiempo, cd4, cd8)
}

df_cart <- bind_rows(
  read_car_counts(
    file.path(raw_dir, "EXPRESI\u00d3N CAR CONTEOS ACTIVADAS.xlsx"), "ACTIVADAS"),
  read_car_counts(
    file.path(raw_dir, "EXPRESI\u00d3N CAR CONTEOS NO ACTIVADAS.xlsx"), "NO_ACTIVADOS")
) |>
  mutate(donor = NA_character_)

message("Sph+CAR-T rows: ", nrow(df_cart), " | tiempos: ",
        paste(sort(unique(df_cart$tiempo)), collapse = ", "))

# ── 3. Combine and compute averages ───────────────────────────────────────────
# Combine donor-level data (PBMC groups have donor; CAR-T group → average only 2 rows)
df_all <- bind_rows(
  df_pbmc,
  df_cart
)

avg_all <- df_all |>
  group_by(activation, group, tiempo) |>
  summarise(
    cd4 = mean(cd4, na.rm = TRUE),
    cd8 = mean(cd8, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(!is.na(cd4) | !is.na(cd8))

message("Averaged rows: ", nrow(avg_all), " | grupos: ",
        paste(unique(avg_all$group), collapse = ", "))

# ── 4. Add shared baselines at PBMC time 24h ─────────────────────────────────
# Convention (same as scripts 05, 07, 08):
#   Sph+PBMC+CAR-T @ 24h ← Sph+PBMC @ 24h
#   Sph+CAR-T       @ 24h ← 0

add_baselines <- function(df_act) {
  b24_cd4 <- df_act |> filter(group == "Sph+PBMC", tiempo == 24) |> pull(cd4)
  b24_cd8 <- df_act |> filter(group == "Sph+PBMC", tiempo == 24) |> pull(cd8)

  shared <- bind_rows(
    if (length(b24_cd4) == 1)
      data.frame(group = "Sph+PBMC+CAR-T", tiempo = 24L,
                 cd4 = b24_cd4, cd8 = b24_cd8, stringsAsFactors = FALSE)
    else NULL,
    data.frame(group = "Sph+CAR-T", tiempo = 24L,
               cd4 = 0, cd8 = 0, stringsAsFactors = FALSE)
  )

  # Remove any pre-existing rows at tiempo=24 for these groups (shouldn't exist, safety check)
  df_act |>
    filter(!(group == "Sph+PBMC+CAR-T" & tiempo == 24),
           !(group == "Sph+CAR-T"       & tiempo == 24)) |>
    bind_rows(shared) |>
    mutate(group = factor(group,
                          levels = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"))) |>
    arrange(group, tiempo)
}

# ── 5. Time labels ────────────────────────────────────────────────────────────
time_labs <- c(
  "24" = "48 h sph\n24 h PBMC",
  "48" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "72" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)

prep_plot <- function(avg_df, act_val, value_col) {
  df_act <- avg_df |> filter(activation == act_val)
  df_act <- add_baselines(df_act)
  df_act |>
    mutate(
      value    = .data[[value_col]],
      tiempo_f = factor(as.character(tiempo),
                        levels = names(time_labs),
                        labels = unname(time_labs))
    ) |>
    filter(!is.na(tiempo_f), !is.na(value)) |>
    arrange(group, tiempo)
}

# ── 6. Colors and shapes ──────────────────────────────────────────────────────
cols_3 <- c("Sph+CAR-T"       = "#E69F00",
            "Sph+PBMC"        = "#555555",
            "Sph+PBMC+CAR-T"  = "#009E73")
shps_3 <- c("Sph+CAR-T"       = 18L,
            "Sph+PBMC"        = 16L,
            "Sph+PBMC+CAR-T"  = 17L)

# ── 7. Plot function ──────────────────────────────────────────────────────────
make_plot <- function(plot_data, title, y_lab) {
  y_ceil <- max(ceiling(max(plot_data$value, na.rm = TRUE) / 100) * 100, 500)
  ggplot(plot_data,
         aes(x = tiempo_f, y = value,
             color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = cols_3, drop = TRUE) +
    scale_shape_manual(values = shps_3, drop = TRUE) +
    scale_y_continuous(
      breaks = pretty(c(0, y_ceil), n = 5),
      labels = label_comma(),
      limits = c(0, y_ceil),
      expand = expansion(mult = c(0, 0.03))
    ) +
    labs(title = title, x = NULL, y = y_lab) +
    guides(color = guide_legend(nrow = 2),
           shape = guide_legend(nrow = 2)) +
    theme_flow
}

# ── 8. Generate figures ───────────────────────────────────────────────────────
act_meta <- list(
  list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC"),
  list(val = "ACTIVADAS",    suf = "act",   label = "Activated PBMC")
)

for (act in act_meta) {
  title_base <- paste0("A549+MRC-5+", act$label, "+CAR-T")

  # CD4+ count
  pd <- prep_plot(avg_all, act$val, "cd4")
  message("\n--- CD4+ count | ", act$val, " | ", nrow(pd), " filas ---")
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, title_base, "Live CD4\u207A cells (count)"),
             paste0("09_cd4_count_", act$suf), 120, 100)

  # CD8+ count
  pd <- prep_plot(avg_all, act$val, "cd8")
  message("\n--- CD8+ count | ", act$val, " | ", nrow(pd), " filas ---")
  if (nrow(pd) > 0)
    save_fig(make_plot(pd, title_base, "Live CD8\u207A cells (count)"),
             paste0("09_cd8_count_", act$suf), 120, 100)
}

message("\n=== Done: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log:", log_file, "\n")
cat("\u2713 Figures in: results/figures/\n")
