#!/usr/bin/env Rscript
# 09_esf_cd19_estrategia1.R
# Curvas temporales de células del esferoide (CD3⁻) vivas y CD19⁺
# a partir de la Estrategia 1 de gating (jerarquía exportada desde FlowJo):
#   Singlets → ESFEROIDE → CD3⁻ → Muertas/Vivas → CD19⁺
#
# CD3⁻ Vivas = células tumorales vivas (A549+MRC-5)
# CD19⁺       = fracción de A549 transducida con CD19 (diana del CAR anti-CD19)
#
# Figuras generadas (ACTIVADOS):
#   09_esf_vivas_pct_act.pdf/.png  — % CD3⁻ Vivas (del gate CD3)
#   09_esf_vivas_cnt_act.pdf/.png  — #Células CD3⁻ Vivas
#   09_cd19_pct_act.pdf/.png       — % CD19⁺ (del gate Vivas)
#   09_cd19_cnt_act.pdf/.png       — #Células CD19⁺
#
# Para agregar NO ACTIVADOS: descomentar las secciones marcadas
# con "## NO_ACTIVADOS ##" y proveer el archivo correspondiente.
#
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
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

log_file <- file.path(log_dir,
  paste0("09_esf_cd19_estrategia1_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 09_esf_cd19_estrategia1.R === ", Sys.time())

# ── Archivos fuente ────────────────────────────────────────────────────────────
f_act <- file.path(raw_dir,
  "VIABILIDAD ACTIVADOS ESTRATEGIA 1 TOTAL-CD3-ZOMBIE-CD19+.xlsx")

## NO_ACTIVADOS ## descomentar cuando esté disponible el archivo equivalente:
# f_noact <- file.path(raw_dir,
#   "VIABILIDAD NO ACTIVADOS ESTRATEGIA 1 TOTAL-CD3-ZOMBIE-CD19+.xlsx")

# ── Parser: jerarquía FlowJo → tabla tidy ─────────────────────────────────────
#
# El archivo tiene 3 columnas: Name, Statistic (% del gate padre), #Cells.
# Cada muestra genera 7 filas (una por gate en la jerarquía):
#   MUESTRA_ | MUESTRA_/Singlets | .../ESFEROIDE | .../CD3 |
#   .../CD3/Muertas | .../CD3/Vivas | .../CD3/Vivas/CD19+
#
# Se extraen solo las filas de Vivas y CD19+.
# El grupo, donante y tiempo se infieren del nombre de muestra.
#
# Convención de donante: "D sin número" = D2 (confirmado por el usuario).
# Convención de grupo:
#   SOLO → Sph. only   |   PBMCs (sin CART) → Sph+PBMC
#   CART (sin PBMCs)  → Sph+CAR-T   |   PBMCs + CART → Sph+PBMC+CAR-T

parse_estrategia1 <- function(path, activation) {
  raw <- suppressMessages(
    read_excel(path, col_names = TRUE, na = c("", "-", "NA"))
  )
  colnames(raw) <- c("name", "statistic", "n_cells")
  raw <- raw |>
    mutate(
      name     = trimws(as.character(name)),
      statistic = suppressWarnings(as.numeric(statistic)),
      n_cells  = suppressWarnings(as.numeric(n_cells)),
      gate     = sub(".*/", "", name),      # último componente del path
      sample   = trimws(sub("/.*", "", name)) # todo antes del primer "/"
    ) |>
    filter(gate %in% c("Vivas", "CD19+"))

  # Una fila por muestra con Vivas y CD19+ como columnas
  wide <- raw |>
    select(sample, gate, statistic, n_cells) |>
    pivot_wider(
      names_from  = gate,
      values_from = c(statistic, n_cells),
      names_glue  = "{.value}_{gate}"
    ) |>
    rename(
      vivas_pct = statistic_Vivas,
      vivas_cnt = n_cells_Vivas,
      cd19_pct  = `statistic_CD19+`,
      cd19_cnt  = `n_cells_CD19+`
    )

  wide |>
    mutate(
      activation = activation,
      group = case_when(
        str_detect(sample, regex("SOLO", ignore_case = TRUE))
          ~ "Sph. only",
        str_detect(sample, regex("CART", ignore_case = TRUE)) &
          str_detect(sample, regex("PBMCs?", ignore_case = TRUE))
          ~ "Sph+PBMC+CAR-T",
        str_detect(sample, regex("CART", ignore_case = TRUE))
          ~ "Sph+CAR-T",
        str_detect(sample, regex("PBMCs?", ignore_case = TRUE))
          ~ "Sph+PBMC",
        TRUE ~ NA_character_
      ),
      donor = case_when(
        str_detect(sample, regex("SOLO", ignore_case = TRUE)) ~ "solo",
        str_detect(sample, fixed("D1"))                       ~ "D1",
        TRUE                                                   ~ "D2"
      ),
      # Extrae el número de horas: dígito(s) seguido de espacio opcional + H/h
      # Este tiempo es el de incubación de la condición, no el tiempo total
      # del esferoide. El offset se aplica según cuándo se añade cada condición:
      #   Sph. only       → sin offset (tiempo = tiempo esferoide)
      #   Sph+PBMC        → +24 h (PBMCs añadidas a las 24 h)
      #   Sph+CAR-T       → +48 h (CAR-T añadidas a las 48 h)
      #   Sph+PBMC+CAR-T  → +48 h (ídem, CART es la adición más tardía)
      tiempo_raw = as.numeric(str_extract(sample, "\\d+(?=\\s*[Hh])"))
    ) |>
    filter(!is.na(group), !is.na(tiempo_raw)) |>
    mutate(
      offset = case_when(
        group == "Sph. only"      ~  0L,
        group == "Sph+PBMC"       ~ 24L,
        group == "Sph+CAR-T"      ~ 48L,
        group == "Sph+PBMC+CAR-T" ~ 48L
      ),
      tiempo = tiempo_raw + offset
    )
}

# ── Leer datos ────────────────────────────────────────────────────────────────
df_act <- parse_estrategia1(f_act, "ACTIVADAS")

## NO_ACTIVADOS ## descomentar y reemplazar df_all cuando esté disponible:
# df_noact <- parse_estrategia1(f_noact, "NO_ACTIVADOS")
# df_all   <- bind_rows(df_act, df_noact)
df_all <- df_act

message("Filas ACTIVADAS: ", nrow(df_act))
message("\nResumen de grupos y tiempos:")
print(df_all |> count(activation, group, tiempo))

# ── Preparar datos para graficar ──────────────────────────────────────────────
# Promedia D1 y D2 por grupo y tiempo.
# Aplica baselines compartidos (misma convención que scripts 07/08):
#   • Todos los grupos  @ t=24h ← Sph.only @ t=24h  (antes de añadir PBMCs)
#   • Sph+PBMC+CAR-T   @ t=48h ← Sph+PBMC @ t=48h  (antes de añadir CAR-T)
#   • Sph+CAR-T        @ t=48h ← Sph.only  @ t=48h  (antes de añadir CAR-T)

time_labs <- c(
  "24" = "24 h sph.\n\u2014",
  "48" = "48 h sph\n24 h PBMC",
  "72" = "72 h sph\n48 h PBMC\n24 h CAR-T",
  "96" = "96 h sph\n72 h PBMC\n48 h CAR-T"
)

prep_plot_data <- function(df, act_val, value_col) {
  grp_levels <- c("Sph. only", "Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T")

  avg <- df |>
    filter(activation == act_val) |>
    group_by(group, tiempo) |>
    summarise(value = mean(.data[[value_col]], na.rm = TRUE), .groups = "drop") |>
    filter(!is.na(value))

  # Baseline compartido t=24h: todas las líneas parten del valor Sph.only @ 24h
  b24 <- avg |> filter(group == "Sph. only", tiempo == 24) |> pull(value)
  if (length(b24) == 1) {
    avg <- bind_rows(avg, data.frame(
      group  = c("Sph+CAR-T", "Sph+PBMC", "Sph+PBMC+CAR-T"),
      tiempo = 24L, value = b24
    ))
  }

  # Baseline compartido t=48h
  b48_pbmc <- avg |> filter(group == "Sph+PBMC",  tiempo == 48) |> pull(value)
  b48_solo <- avg |> filter(group == "Sph. only", tiempo == 48) |> pull(value)
  shared_48 <- bind_rows(
    if (length(b48_pbmc) == 1)
      data.frame(group = "Sph+PBMC+CAR-T", tiempo = 48L, value = b48_pbmc) else NULL,
    if (length(b48_solo) == 1)
      data.frame(group = "Sph+CAR-T",      tiempo = 48L, value = b48_solo) else NULL
  )
  avg <- bind_rows(avg, shared_48)

  avg |>
    mutate(
      group    = factor(group, levels = grp_levels),
      tiempo_f = factor(as.character(tiempo),
                        levels = names(time_labs),
                        labels = unname(time_labs))
    ) |>
    filter(!is.na(tiempo_f)) |>
    arrange(group, tiempo)
}

# ── Tema y estética ────────────────────────────────────────────────────────────
theme_flow <- theme_bw(base_size = 13) +
  theme(
    axis.text.x        = element_text(size = 10, hjust = 0.5),
    axis.text.y        = element_text(size = 11),
    axis.title         = element_text(size = 12),
    plot.title         = element_text(size = 10, face = "bold", hjust = 0.5),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 10),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )

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

# ── Función de plot ────────────────────────────────────────────────────────────
make_plot <- function(plot_data, title, y_lab, y_pct) {
  p <- ggplot(plot_data,
              aes(x = tiempo_f, y = value,
                  color = group, group = group, shape = group)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 3.5) +
    scale_color_manual(values = group_colors, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
    scale_shape_manual(values = group_shapes, drop = TRUE,
                       guide = guide_legend(nrow = 2)) +
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
    y_ceil <- max(ceiling(max(plot_data$value, na.rm = TRUE) / 1000) * 1000, 1000)
    p + scale_y_continuous(
      breaks = pretty(c(0, y_ceil), n = 5),
      labels = label_comma(),
      limits = c(0, y_ceil),
      expand = expansion(mult = c(0, 0.03))
    )
  }
}

save_fig <- function(p, name, w = 130, h = 110) {
  ggsave(file.path(fig_dir, paste0(name, ".pdf")), p,
         width = w, height = h, units = "mm",
         device = cairo_pdf, limitsize = FALSE)
  ggsave(file.path(fig_dir, paste0(name, ".png")), p,
         width = w, height = h, units = "mm",
         dpi = 300, limitsize = FALSE)
  message("\u2713 Guardado: ", name)
}

# ── Especificaciones de variables ──────────────────────────────────────────────
plot_specs <- list(
  list(col   = "vivas_pct",
       id    = "esf_vivas_pct",
       y_lab = "Viable CD3\u207B cells (%)",
       y_pct = TRUE),
  list(col   = "vivas_cnt",
       id    = "esf_vivas_cnt",
       y_lab = "Viable CD3\u207B cells (count)",
       y_pct = FALSE),
  list(col   = "cd19_pct",
       id    = "cd19_pct",
       y_lab = "CD19\u207A viable cells (% of CD3\u207B)",
       y_pct = TRUE),
  list(col   = "cd19_cnt",
       id    = "cd19_cnt",
       y_lab = "CD19\u207A viable cells (count)",
       y_pct = FALSE)
)

# ── Estados de activación a graficar ──────────────────────────────────────────
act_meta <- list(
  list(val = "ACTIVADAS", suf = "act", label = "Activated PBMC")
  ## NO_ACTIVADOS ## descomentar cuando esté disponible:
  # , list(val = "NO_ACTIVADOS", suf = "noact", label = "Non-activated PBMC")
)

# ── Generar figuras ────────────────────────────────────────────────────────────
for (act in act_meta) {
  for (pspec in plot_specs) {
    message("\n--- ", pspec$id, " | ", act$val, " ---")
    pd <- prep_plot_data(df_all, act$val, pspec$col)

    if (nrow(pd) == 0 || all(is.na(pd$value))) {
      message("  SKIP: sin datos")
      next
    }
    message("  ", nrow(pd), " filas | grupos: ",
            paste(levels(droplevels(pd$group)), collapse = ", "))
    print(pd)

    title <- paste0("A549+MRC-5 CD19\u207A \u00b1 ", act$label, " \u00b1 CAR-T")
    p     <- make_plot(pd, title, pspec$y_lab, pspec$y_pct)
    save_fig(p, paste0("09_", pspec$id, "_", act$suf))
  }
}

message("\n=== Finalizado: ", Sys.time(), " ===")
sink(type = "message")
sink(type = "output")
close(con)
cat("\u2713 Log guardado en:", log_file, "\n")
cat("\u2713 Figuras en: results/figures/\n")
