#!/usr/bin/env Rscript
# 01_load_and_clean.R
# Carga y limpia los 4 archivos XLS de citometría de flujo.
# Salida: data/processed/flow_clean.rds y flow_clean.csv
# Ambiente: omics-R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(stringr)
})

# ── Rutas ────────────────────────────────────────────────────────────────────
project_dir <- here::here()  # raíz del proyecto (donde está este script)
raw_dir     <- file.path(project_dir, "data", "raw")
out_dir     <- file.path(project_dir, "data", "processed")
log_dir     <- file.path(project_dir, "logs")

dir.create(out_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(log_dir,  showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(log_dir, paste0("01_load_clean_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
con <- file(log_file, open = "wt")
sink(con, type = "message")
sink(con, type = "output", append = TRUE)
message("=== 01_load_and_clean.R === ", Sys.time())

# ── Constantes de estructura XLS ─────────────────────────────────────────────
N_ROWS_PER_FILE <- 10L   # filas de datos por archivo (10 muestras, excl. header)
POP_COL_RANGE   <- 6:27  # columnas de poblaciones en canonical_names

# ── Nombres canónicos (por posición, cols 1–27) ───────────────────────────────
# Col 1–5: metadatos | Col 6–27: poblaciones (orden fijo en todos los archivos)
canonical_names <- c(
  "sample_label",    # 1  — nombre de la muestra (fila)
  "pbmc",            # 2  — PBMC (SI/NO)
  "donor",           # 3  — donante (1 / 2)
  "cart",            # 4  — CAR-T (SI/NO)
  "tiempo",          # 5  — tiempo en horas (24/48/72)
  "singlets",        # 6
  "singlets_dead",   # 7  — Singlets/Muertas
  "pbmcs_dead",      # 8  — PBMC's Muertas (total dead)
  "dead_cd3neg",     # 9  — Muertas/CD3-
  "dead_cd3",        # 10 — Linfocitos Muertos CD3+
  "dead_cd4",        # 11 — Muertos CD4+
  "dead_cd8",        # 12 — Muertos CD8+
  "singlets_live",   # 13 — Singlets/Vivas
  "pbmcs_live",      # 14 — PBMC's vivas
  "cd3",             # 15 — vivas/CD3+
  "cd4",             # 16 — vivas/CD4+
  "cd4_hladr",       # 17 — CD4+/HLA-DR+
  "cd8",             # 18 — vivas/CD8+
  "cd8_hladr",       # 19 — CD8+/HLA-DR+
  "cd3neg",          # 20 — vivas/CD3-
  "cd3neg_cd19neg",  # 21 — CD3-/CD19- (innate)
  "monocytes",       # 22 — Monocitos
  "macrophages",     # 23 — Macrófagos vivos
  "macrophages_cd11b", # 24 — Macrófagos CD11b+
  "macrophages_hladr", # 25 — Macrófagos HLA-DR+
  "nk",              # 26 — NK's
  "b_cells"          # 27 — Linfocitos B
)

# ── Función: limpiar columna de porcentaje ────────────────────────────────────
clean_pct <- function(x) {
  x <- as.character(x)
  x <- str_remove(x, "%")          # quitar símbolo %
  x <- str_replace_all(x, ",", ".") # coma → punto (formato europeo)
  x <- str_trim(x)
  as.numeric(x)
}

# ── Función: leer un archivo XLS ─────────────────────────────────────────────
read_flow_xls <- function(path, activation, data_type) {
  message("Leyendo: ", basename(path))

  # Leer todo como texto para manejar mezcla char/num en porcentajes
  df <- read_xls(
    path,
    col_names = FALSE,
    skip      = 1,                  # saltar fila de encabezados originales
    n_max     = N_ROWS_PER_FILE,   # excluir filas vacías al final
    col_types = "text"
  )

  # Verificar que tiene 27 columnas
  if (ncol(df) != 27) {
    stop("Se esperaban 27 columnas en ", basename(path), " pero hay ", ncol(df))
  }

  colnames(df) <- canonical_names

  # Convertir metadatos numéricos
  df$donor  <- as.integer(df$donor)
  df$tiempo <- as.integer(df$tiempo)

  # Convertir columnas de población según tipo
  pop_cols <- canonical_names[POP_COL_RANGE]
  if (data_type == "PORCENTAJES") {
    df[pop_cols] <- lapply(df[pop_cols], clean_pct)
  } else {
    df[pop_cols] <- lapply(df[pop_cols], as.numeric)
  }

  # Agregar columnas de contexto
  df$activation <- activation
  df$data_type  <- data_type

  df
}

# ── Leer los 4 archivos ───────────────────────────────────────────────────────
files <- list(
  list(
    path       = file.path(raw_dir, "ACTIVADAS CONTEOS POBLACIONES (PBMC+CART).xls"),
    activation = "ACTIVADAS",
    data_type  = "CONTEOS"
  ),
  list(
    path       = file.path(raw_dir, "ACTIVADAS PORCENTAJES POBLACIONES (PBMC+CART).xls"),
    activation = "ACTIVADAS",
    data_type  = "PORCENTAJES"
  ),
  list(
    path       = file.path(raw_dir, "NO ACTIVADOS CONTEOS POBLACIONES (PBMC+CART).xls"),
    activation = "NO_ACTIVADOS",
    data_type  = "CONTEOS"
  ),
  list(
    path       = file.path(raw_dir, "NO ACTIVADOS PORCENTAJES POBLACIONES (PBMC+CART).xls"),
    activation = "NO_ACTIVADOS",
    data_type  = "PORCENTAJES"
  )
)

flow_list <- lapply(files, function(f) {
  read_flow_xls(f$path, f$activation, f$data_type)
})

flow <- bind_rows(flow_list)

# ── Estandarizar variables categóricas ────────────────────────────────────────
flow <- flow |>
  mutate(
    cart       = toupper(str_trim(cart)),        # "SI" / "NO"
    pbmc       = toupper(str_trim(pbmc)),
    activation = factor(activation, levels = c("ACTIVADAS", "NO_ACTIVADOS")),
    data_type  = factor(data_type,  levels = c("CONTEOS", "PORCENTAJES")),
    donor      = factor(donor),
    cart       = factor(cart, levels = c("NO", "SI")),
    tiempo     = factor(tiempo, levels = c(24, 48, 72))
  )

# ── Validaciones ─────────────────────────────────────────────────────────────
message("\n--- Dimensiones: ", nrow(flow), " filas × ", ncol(flow), " columnas ---")
message("Filas esperadas: 40 (4 archivos × 10 muestras)")

# Contar NAs en columnas de población (porcentajes)
pct_df  <- filter(flow, data_type == "PORCENTAJES")
pop_nas <- colSums(is.na(pct_df[, canonical_names[POP_COL_RANGE]]))
if (any(pop_nas > 0)) {
  message("\n⚠ NAs en columnas de porcentaje:")
  print(pop_nas[pop_nas > 0])
} else {
  message("✓ Sin NAs en columnas de porcentaje")
}

# Rango de porcentajes (debe ser 0-100 aproximadamente)
pct_range <- sapply(pct_df[, canonical_names[POP_COL_RANGE]], range, na.rm = TRUE)
out_of_range <- colnames(pct_range)[pct_range[1,] < 0 | pct_range[2,] > 100]
if (length(out_of_range) > 0) {
  message("⚠ Columnas fuera del rango 0-100: ", paste(out_of_range, collapse = ", "))
} else {
  message("✓ Todos los porcentajes en rango 0-100")
}

message("\nResumen por activation × data_type × cart × tiempo:")
print(count(flow, activation, data_type, cart, tiempo))

# ── Exportar ─────────────────────────────────────────────────────────────────
saveRDS(flow, file.path(out_dir, "flow_clean.rds"))
write.csv(flow, file.path(out_dir, "flow_clean.csv"), row.names = FALSE, fileEncoding = "UTF-8")
message("\n✓ Exportado: data/processed/flow_clean.rds")
message("✓ Exportado: data/processed/flow_clean.csv")
message("=== Finalizado: ", Sys.time(), " ===")

sink(type = "message")
sink(type = "output")
close(con)
cat("✓ Log guardado en:", log_file, "\n")
