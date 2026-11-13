#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_T07.py — Genera T07_LosRojos_MetricasAlarmas.docx
Tarea 7: Métricas a vigilar + alarmas con umbrales y acciones
Equipo Los Rojos · Grupo 503 · Cómputo en la Nube · 5 nov 2026
Formato: media cuartilla (½ página) en tabla.
"""

from docx import Document
from docx.shared import Pt, RGBColor, Cm, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# ── Paleta de colores AWS ─────────────────────────────────────────
AWS_ORANGE = RGBColor(0xFF, 0x99, 0x00)
AWS_DARK   = RGBColor(0x23, 0x2F, 0x3E)
AWS_BLUE   = RGBColor(0x14, 0x6E, 0xB4)
WHITE      = RGBColor(0xFF, 0xFF, 0xFF)
BLACK      = RGBColor(0x00, 0x00, 0x00)
GRAY_BG    = RGBColor(0xF2, 0xF2, 0xF2)
DARK_RED   = RGBColor(0xCC, 0x00, 0x00)
DARK_GREEN = RGBColor(0x1A, 0x7A, 0x1A)

# ── Helpers ──────────────────────────────────────────────────────
def rgb_hex(rgb) -> str:
    return f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"

def set_cell_bg(cell, rgb):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"),   "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"),  rgb_hex(rgb))
    tcPr.append(shd)

def add_run(para, text, bold=False, size=9, color=BLACK, italic=False):
    run = para.add_run(text)
    run.bold = bold
    run.italic = italic
    run.font.size = Pt(size)
    run.font.color.rgb = color
    return run

# ════════════════════════════════════════════════════════════════
# DOCUMENTO
# ════════════════════════════════════════════════════════════════
doc = Document()

# Márgenes estrechos para media cuartilla
for section in doc.sections:
    section.top_margin    = Cm(1.2)
    section.bottom_margin = Cm(1.2)
    section.left_margin   = Cm(1.5)
    section.right_margin  = Cm(1.5)

# ── Encabezado compacto ──────────────────────────────────────────
# Barra naranja
tbl = doc.add_table(rows=1, cols=1)
tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
cell = tbl.cell(0, 0)
set_cell_bg(cell, AWS_ORANGE)
p = cell.paragraphs[0]
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(2)
p.paragraph_format.space_after  = Pt(2)
add_run(p, "T07 · MÉTRICAS Y ALARMAS", bold=True, size=12, color=WHITE)

# Subtítulo y datos del equipo
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(2)
p.paragraph_format.space_after  = Pt(1)
add_run(p, "Proyecto: Inventario Nube  ·  Equipo Los Rojos  ·  Grupo 503", bold=True, size=9, color=AWS_DARK)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(0)
p.paragraph_format.space_after  = Pt(3)
add_run(p, "Cómputo en la Nube  ·  5 de noviembre de 2026  ·  Flores Guevara Ángel G. · López Payán Kevin R.",
       size=7.5, color=RGBColor(0x55, 0x55, 0x55))

# ════════════════════════════════════════════════════════════════
# SECCIÓN 1 — MÉTRICAS (tabla compacta)
# ════════════════════════════════════════════════════════════════
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(2)
p.paragraph_format.space_after  = Pt(1)
add_run(p, "1. Métricas a vigilar", bold=True, size=9.5, color=AWS_DARK)

metricas = [
    ("Métrica", "Servicio AWS", "Por qué vigilarla"),
    ("Uso de CPU de EC2",
     "EC2 t3.micro (API Node.js)",
     "Instancia pequeña (1 vCPU). Si la CPU satura, la API deja de responder y los usuarios no pueden registrar movimientos."),
    ("Errores 5xx de la API",
     "ALB + EC2 (Nginx/Node.js)",
     "Indican fallos del servidor: errores no capturados, caída de la conexión a RDS o timeout. Afectan directamente al negocio."),
    ("Conexiones a la base de datos",
     "RDS db.t3.micro (PostgreSQL)",
     "El límite de conexiones de t3.micro es ~55. Si se agotan, los endpoints que consultan productos o insertan movimientos fallan."),
    ("Espacio usado en S3",
     "S3 (frontend + imágenes de productos)",
     "El bucket almacena el sitio estático y las fotos de productos. Vigilar el crecimiento evita costos por encima del Free Tier (5 GB)."),
    ("Errores y throttles de Lambda",
     "Lambda fn-movimientos-los-rojos",
     "La función consulta el historial de movimientos vía API Gateway. Errores o throttles significan que las consultas dejan de funcionar."),
]

tbl_m = doc.add_table(rows=len(metricas), cols=3)
tbl_m.style = "Table Grid"
tbl_m.alignment = WD_TABLE_ALIGNMENT.CENTER
col_w = [Cm(3.8), Cm(3.8), Cm(9.4)]

for r_idx, row_data in enumerate(metricas):
    row = tbl_m.rows[r_idx]
    for c_idx, text in enumerate(row_data):
        c = row.cells[c_idx]
        c.width = col_w[c_idx]
        c.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        cp = c.paragraphs[0]
        cp.paragraph_format.space_before = Pt(1)
        cp.paragraph_format.space_after  = Pt(1)
        if r_idx == 0:
            set_cell_bg(c, AWS_DARK)
            add_run(cp, text, bold=True, size=8, color=WHITE)
        else:
            if r_idx % 2 == 0:
                set_cell_bg(c, GRAY_BG)
            add_run(cp, text, bold=(c_idx == 0), size=7.5)

# ════════════════════════════════════════════════════════════════
# SECCIÓN 2 — ALARMAS (tabla con umbral, quién y acción)
# ════════════════════════════════════════════════════════════════
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(5)
p.paragraph_format.space_after  = Pt(1)
add_run(p, "2. Alarmas, umbrales y acciones", bold=True, size=9.5, color=AWS_DARK)

alarmas = [
    ("Alarma y umbral", "Quién se entera", "Acción que toma el equipo"),
    ("A1 · CPU de EC2 > 80 %\ndurante 5 min",
     "Flores Guevara (vía SNS → correo)",
     "Revisar CloudWatch Logs en busca de un proceso en bucle o tráfico anómalo. Si la CPU sigue alta, ajustar el ASG o subir a t3.small. Verificar que /health sigue respondiendo."),
    ("A2 · Errores 5xx de la API > 10\nen 5 min",
     "Flores Guevara (vía SNS → correo)",
     "Revisar logs de Node.js en CloudWatch. Verificar conexión a RDS y DynamoDB. Si es un bug conocido, crear issue en GitHub y aplicar hotfix; si es infraestructura, reiniciar el contenedor."),
    ("A3 · Conexiones a RDS > 80 %\ndel máximo (~44/55) por 10 min",
     "López Payán + Flores Guevara\n(vía SNS → correo)",
     "Verificar connection leak en el pool de Node.js (pg-pool). Revisar que cada query cierre su conexión. Si persiste, aumentar max_connections de RDS o reducir el tamaño del pool en la app."),
]

tbl_a = doc.add_table(rows=len(alarmas), cols=3)
tbl_a.style = "Table Grid"
tbl_a.alignment = WD_TABLE_ALIGNMENT.CENTER
col_w2 = [Cm(4.2), Cm(3.8), Cm(9.0)]

for r_idx, row_data in enumerate(alarmas):
    row = tbl_a.rows[r_idx]
    for c_idx, text in enumerate(row_data):
        c = row.cells[c_idx]
        c.width = col_w2[c_idx]
        c.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        cp = c.paragraphs[0]
        cp.paragraph_format.space_before = Pt(1)
        cp.paragraph_format.space_after  = Pt(1)
        if r_idx == 0:
            set_cell_bg(c, AWS_ORANGE)
            add_run(cp, text, bold=True, size=8, color=WHITE)
        else:
            if r_idx % 2 == 0:
                set_cell_bg(c, GRAY_BG)
            is_alarma = (c_idx == 0)
            add_run(cp, text, bold=is_alarma, size=7.5,
                    color=DARK_RED if is_alarma else BLACK)

# Nota final
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(4)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
add_run(p, "Una alarma sin acción no cuenta — estas alarmas se configurarán en la Práctica 13 con CloudWatch + SNS.",
       size=7, italic=True, color=RGBColor(0x66, 0x66, 0x66))

# ── Guardar ──────────────────────────────────────────────────────
output = r"c:\Users\angek\OneDrive\Documentos\COMPUTO-EN-LA-NUVE\T07_LosRojos_MetricasAlarmas.docx"
doc.save(output)
print(f"DOCX guardado: {output}")
