#!/usr/bin/env Rscript
# 00_theme.R
# Tema ggplot2 y utilidad save_fig() compartidos por todos los scripts de
# cart_spheroids_flow. No ejecutar directamente; se carga via source().
#
# Requisito: ggplot2 ya debe estar cargado en el script que llame a source().
# Requisito: fig_dir debe estar definido antes de llamar a save_fig().

# ── Tema base ─────────────────────────────────────────────────────────────────
# Scripts que necesiten sobreescribir propiedades (e.g. legend.text size o
# legend.position) deben hacerlo DESPUÉS del source() con:
#   theme_flow <- theme_flow + theme(legend.text = element_text(size = 10))
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

# ── Exportar figura como PDF + PNG ────────────────────────────────────────────
# out_dir se resuelve perezosamente en el entorno del llamador (fig_dir).
save_fig <- function(p, name, w = 120, h = 100, out_dir = fig_dir) {
  pdf_path <- file.path(out_dir, paste0(name, ".pdf"))
  png_path <- file.path(out_dir, paste0(name, ".png"))
  ggplot2::ggsave(pdf_path, p, width = w, height = h, units = "mm",
                  device = cairo_pdf, limitsize = FALSE)
  ggplot2::ggsave(png_path, p, width = w, height = h, units = "mm",
                  dpi = 300, device = "png", limitsize = FALSE)
  message("\u2713 Guardado: ", basename(pdf_path),
          sprintf("  (%.0f\u00d7%.0f mm)", w, h))
}
