# Puntos futuros — cart_spheroids_flow

Ideas y mejoras identificadas durante el análisis. Ordenadas por prioridad sugerida.

---

## Visualización de morfología (script 09)

Las figuras actuales muestran valores absolutos de área, diámetro y circularidad con
notación científica en el eje Y. Se identificaron tres alternativas más informativas:

### Opción A — Normalizar al baseline (% cambio respecto a t=24h) ⭐ recomendada

Mostrar el cambio relativo de cada grupo respecto al punto inicial compartido (esferoide
solo a t=24h). El eje Y pasa a ser **% de cambio** (positivo = crece, negativo = shrinkage).

**Ventajas:**
- Elimina la confusión de que todos los grupos arrancan del mismo punto (t=24h)
- Hace inmediatamente visible cuándo y cuánto se desvía cada grupo del control
- Área, diámetro y circularidad quedan en la misma unidad → posibilidad de multipanel
- Formato estándar en papers de citotoxicidad sobre esferoides 3D

**Implementación:** dividir cada valor por el valor de `Sph. only @ t=24h` y restar 1,
luego multiplicar por 100. El punto t=24h de todos los grupos quedaría en 0%.

---

### Opción B — Multipanel 3 × 2 (una figura por estado de activación)

Combinar las 6 figuras en 2 figuras multipanel con 3 paneles cada una:
- Fila 1: Área
- Fila 2: Diámetro
- Fila 3: Circularidad
- Columna 1: Non-activated PBMC | Columna 2: Activated PBMC

**Ventajas:** más compacto para tesis/paper; permite ver las 3 variables del mismo
experimento en un solo golpe de vista.

**Herramienta:** `patchwork` (ya disponible en `omics-R`).

---

### Opción C — Etiquetas de eje Y más legibles (mejora menor)

Alternativa sin cambiar la estructura conceptual:
- Área: formato con comas (`500,000 µm²`, `1,000,000 µm²`) en lugar de notación científica
- Diámetro: valores directos (`968 µm`, `1,378 µm`) — el rango es legible sin formato especial

**Implementación:** `label_comma()` para área; `label_number(big.mark = ",")` para diámetro.

---

## Scripts pendientes de implementar

### Script 06 — Heatmap ComplexHeatmap

Heatmap anotado con todas las poblaciones inmunes × muestras usando `ComplexHeatmap`.
- **Input:** `data/processed/flow_clean.rds`
- **Objetivo:** visualizar patrones globales de composición inmune en una sola figura
- **Anotaciones sugeridas:** activación, presencia de CAR-T, tiempo, donante

---

## Análisis estadístico

Con n=2 donantes el análisis es puramente descriptivo. Si se añaden más donantes:

- **Curvas temporales (scripts 04/05):** añadir ribbon de ± SD o rango entre D1 y D2
- **Morfología (script 09):** con n≥3 se podrían aplicar tests no paramétricos por tiempo
  (Kruskal-Wallis + post-hoc Dunn) para comparar grupos a cada punto temporal

---

## Datos adicionales posibles

- Imágenes de microscopía de los esferoides para validar visualmente los cambios morfológicos
  detectados en script 09 (caída de área/diámetro en `Sph+PBMC+CAR-T` activadas a 72h)
- Experimento con n≥3 donantes para poder realizar análisis estadístico formal
