"""
Inserta las dos capturas de CloudShell al final de T6_LosRojos_Costos.docx
"""

from docx import Document
from docx.shared import Pt, Cm, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

DOCX_PATH  = r"c:\Users\angek\OneDrive\Documentos\COMPUTO-EN-LA-NUVE\T6_LosRojos_Costos.docx"
IMG1       = r"C:\Users\angek\OneDrive\Imágenes\tareas-6\Captura de pantalla 2026-11-03 203316.png"
IMG2       = r"C:\Users\angek\OneDrive\Imágenes\tareas-6\Captura de pantalla 2026-11-03 203302.png"

doc = Document(DOCX_PATH)

AWS_DARK  = RGBColor(0x23, 0x2F, 0x3E)
AWS_ORANGE= RGBColor(0xFF, 0x99, 0x00)
WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
GRAY      = RGBColor(0x55, 0x55, 0x55)

def rgb_hex(rgb):
    return f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"

def add_run(para, text, bold=False, size=11, color=None, italic=False):
    run = para.add_run(text)
    run.bold   = bold
    run.italic = italic
    run.font.size = Pt(size)
    if color:
        run.font.color.rgb = color
    return run

def set_cell_bg(cell, rgb):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement("w:shd")
    shd.set(qn("w:val"),   "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"),  rgb_hex(rgb))
    tcPr.append(shd)

# ── Salto de página ───────────────────────────────────────────────
doc.add_page_break()

# ── Barra de sección ─────────────────────────────────────────────
tbl = doc.add_table(rows=1, cols=1)
from docx.enum.table import WD_TABLE_ALIGNMENT
tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
cell = tbl.cell(0, 0)
set_cell_bg(cell, AWS_DARK)
p = cell.paragraphs[0]
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(5)
p.paragraph_format.space_after  = Pt(5)
add_run(p, "6. Evidencia — Ejecución en AWS CloudShell",
        bold=True, size=13, color=WHITE)

doc.add_paragraph()

# ── Descripción ──────────────────────────────────────────────────
p = doc.add_paragraph()
p.paragraph_format.space_after = Pt(8)
add_run(p,
    "Las siguientes capturas muestran la ejecución del script "
    "t6-costos-proyecto.sh en AWS CloudShell (us-east-1) el 4 de noviembre de 2026. "
    "Los precios se obtuvieron directamente de la AWS Price List API mediante boto3.",
    size=10.5, color=RGBColor(0x22, 0x22, 0x22))

# ══════════════════════════════════════════════════════════════════
# CAPTURA 1 — Supuestos
# ══════════════════════════════════════════════════════════════════
p_label1 = doc.add_paragraph()
p_label1.paragraph_format.space_before = Pt(6)
p_label1.paragraph_format.space_after  = Pt(4)
add_run(p_label1, "Captura 1 — Encabezado y supuestos del proyecto",
        bold=True, size=11, color=AWS_ORANGE)

p_img1 = doc.add_paragraph()
p_img1.alignment = WD_ALIGN_PARAGRAPH.CENTER
p_img1.paragraph_format.space_after = Pt(4)
run1 = p_img1.add_run()
run1.add_picture(IMG1, width=Cm(14))

p_pie1 = doc.add_paragraph()
p_pie1.alignment = WD_ALIGN_PARAGRAPH.CENTER
p_pie1.paragraph_format.space_after = Pt(14)
add_run(p_pie1,
    "Figura 1: Script ejecutado en CloudShell — supuestos del sistema Inventario Nube",
    size=9, italic=True, color=GRAY)

# ══════════════════════════════════════════════════════════════════
# CAPTURA 2 — Desglose de costos
# ══════════════════════════════════════════════════════════════════
p_label2 = doc.add_paragraph()
p_label2.paragraph_format.space_before = Pt(6)
p_label2.paragraph_format.space_after  = Pt(4)
add_run(p_label2, "Captura 2 — Desglose de costos por servicio y totales",
        bold=True, size=11, color=AWS_ORANGE)

p_img2 = doc.add_paragraph()
p_img2.alignment = WD_ALIGN_PARAGRAPH.CENTER
p_img2.paragraph_format.space_after = Pt(4)
run2 = p_img2.add_run()
run2.add_picture(IMG2, width=Cm(14))

p_pie2 = doc.add_paragraph()
p_pie2.alignment = WD_ALIGN_PARAGRAPH.CENTER
p_pie2.paragraph_format.space_after = Pt(14)
add_run(p_pie2,
    "Figura 2: Desglose por servicio — Total mensual $34.29 USD · Anual $411.51 USD",
    size=9, italic=True, color=GRAY)

# ── Guardar ───────────────────────────────────────────────────────
doc.save(DOCX_PATH)
print(f"✔ Capturas insertadas en: {DOCX_PATH}")
