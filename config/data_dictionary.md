# Diccionario de datos — cart_spheroids_flow

## Variables esperadas por tipo de medición

### Viabilidad (esferoides)
| columna | tipo | descripción |
|---------|------|-------------|
| sample_id | string | identificador único (ej: CTR1_24h_rep1) |
| group_id | string | grupo (CTR1…CTR5, TRT1…TRT6) |
| timepoint | string | 24h / 48h / 72h |
| replicate | int | número de réplica |
| live_pct | float | % células vivas |
| dead_pct | float | % células muertas |
| live_count | int | conteo de células vivas |
| dead_count | int | conteo de células muertas |
| total_count | int | conteo total |

### Poblaciones inmunes (panel de anticuerpos)
> COMPLETAR con los marcadores del panel — pendiente confirmar con usuario

| columna | tipo | descripción |
|---------|------|-------------|
| sample_id | string | |
| group_id | string | |
| timepoint | string | |
| replicate | int | |
| CD3_pct | float | % linfocitos T (CD3+) |
| CD4_pct | float | % T helper (CD4+) |
| CD8_pct | float | % T citotóxico (CD8+) |
| CD56_pct | float | % NK (CD56+) |
| CD19_pct | float | % B (CD19+) |
| ... | ... | COMPLETAR según panel |

### Expresión CAR
| columna | tipo | descripción |
|---------|------|-------------|
| sample_id | string | |
| group_id | string | |
| timepoint | string | |
| replicate | int | |
| CAR_pct | float | % células CAR+ (de CD3+CD8+ o según gating) |
| CAR_count | int | conteo células CAR+ |
| CAR_MFI | float | intensidad media de fluorescencia CAR (si disponible) |

## Notas de formato
- Una fila = una muestra/réplica en un timepoint
- Los archivos van en `data/raw/<timepoint>/` (ej: `data/raw/24h/viabilidad_24h.csv`)
- Usar NA para valores faltantes (no dejar celdas vacías)
- sample_id debe ser único en cada tabla
