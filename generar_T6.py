"""
Genera T6_LosRojos_Costos.docx
Estimación de costos AWS · Equipo Los Rojos · Inventario Nube
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

doc = Document()

# ── Márgenes ──────────────────────────────────────────────────────
for section in doc.sections:
    section.top_margin    = Cm(2)
    section.bottom_margin = Cm(2)
    section.left_margin   = Cm(2.5)
    section.right_margin  = Cm(2.5)

# ── Paleta de colores AWS ─────────────────────────────────────────
AWS_ORANGE  = RGBColor(0xFF, 0x99, 0x00)   # #FF9900
AWS_DARK    = RGBColor(0x23, 0x2F, 0x3E)   # #232F3E
AWS_BLUE    = RGBColor(0x14, 0x6E, 0xB4)   # #146EB4
GRAY_BG     = RGBColor(0xF2, 0xF2, 0xF2)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
BLACK       = RGBColor(0x00, 0x00, 0x00)
DARK_GREEN  = RGBColor(0x1A, 0x7A, 0x1A)

# ── Helpers ───────────────────────────────────────────────────────
def rgb_hex(rgb) -> str:
    """RGBColor es una tupla — accede por índice."""
    return f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"

def set_cell_bg(cell, rgb):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement("w:shd")
    shd.set(qn("w:val"),   "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"),  rgb_hex(rgb))
    tcPr.append(shd)

def set_cell_border(cell, top=None, bottom=None, left=None, right=None):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement("w:tcBorders")
    for side, val in [("top", top), ("bottom", bottom),
                      ("left", left), ("right", right)]:
        if val:
            el = OxmlElement(f"w:{side}")
            el.set(qn("w:val"),   val.get("val", "single"))
            el.set(qn("w:sz"),    val.get("sz", "4"))
            el.set(qn("w:color"), val.get("color", "auto"))
            tcBorders.append(el)
    tcPr.append(tcBorders)

def add_run(para, text, bold=False, size=11, color=BLACK, italic=False):
    run = para.add_run(text)
    run.bold   = bold
    run.italic = italic
    run.font.size  = Pt(size)
    run.font.color.rgb = color
    return run

def heading(text, level=1, color=AWS_DARK, size=14):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after  = Pt(4)
    add_run(p, text, bold=True, size=size, color=color)
    return p

def body(text, size=10.5, indent=False):
    p = doc.add_paragraph()
    if indent:
        p.paragraph_format.left_indent = Cm(0.5)
    p.paragraph_format.space_before = Pt(1)
    p.paragraph_format.space_after  = Pt(1)
    add_run(p, text, size=size)
    return p

# ══════════════════════════════════════════════════════════════════
# PORTADA / ENCABEZADO
# ══════════════════════════════════════════════════════════════════

# Barra superior naranja (tabla 1×1 de color)
tbl = doc.add_table(rows=1, cols=1)
tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
cell = tbl.cell(0, 0)
set_cell_bg(cell, AWS_ORANGE)
cell.width = Inches(6.5)
p = cell.paragraphs[0]
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(6)
p.paragraph_format.space_after  = Pt(6)
add_run(p, "T6 · COSTOS DEL PROYECTO", bold=True, size=16, color=WHITE)

doc.add_paragraph()

# Título y datos del equipo
t = doc.add_paragraph()
t.alignment = WD_ALIGN_PARAGRAPH.CENTER
add_run(t, "Estimación de Costos AWS\n", bold=True, size=14, color=AWS_DARK)
add_run(t, "Sistema: Inventario Nube\n", size=11, color=AWS_DARK)
add_run(t, "Equipo Los Rojos  ·  Cómputo en la Nube\n", size=11, color=AWS_DARK)
add_run(t, "Fecha de estimación: 4 de noviembre de 2026\n", size=10, color=RGBColor(0x55,0x55,0x55))
add_run(t, "Región AWS: us-east-1 (US East – N. Virginia)", size=10, color=RGBColor(0x55,0x55,0x55))

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# SECCIÓN 1 — SUPUESTOS
# ══════════════════════════════════════════════════════════════════
heading("1. Supuestos", size=13, color=AWS_DARK)

# Párrafo introductorio
p = doc.add_paragraph()
p.paragraph_format.space_after = Pt(6)
add_run(p,
    "La estimación cubre el costo mensual del sistema Inventario Nube sin "
    "considerar el Free Tier de AWS ni créditos de AWS Educate. "
    "Los precios son OnDemand en us-east-1 al 4 de noviembre de 2026, "
    "obtenidos directamente de la AWS Price List API.",
    size=10.5)

# Tabla de supuestos
supuestos_data = [
    ("Componente",        "Supuesto",                         "Justificación"),
    ("Usuarios activos",  "50 usuarios",                      "Sistema de inventario empresarial pequeño"),
    ("EC2 t3.micro",      "730 hrs/mes (24/7)",               "Servidor web siempre disponible (producción)"),
    ("EC2 – Disco EBS",   "20 GB gp3",                        "SO + aplicación Node.js + logs"),
    ("RDS db.t3.micro",   "730 hrs/mes (24/7)",               "Base de datos PostgreSQL siempre activa"),
    ("RDS – Storage",     "20 GB gp2",                        "Datos del inventario + historial"),
    ("S3 Standard",       "5 GB",                             "Sitio estático + archivos subidos"),
    ("S3 Standard-IA",    "2 GB (lifecycle 30 días)",         "Objetos con acceso infrecuente"),
    ("S3 Requests",       "1,000 PUT + 10,000 GET/mes",       "Subidas y consultas de archivos"),
    ("DynamoDB",          "30,000 writes + 150,000 reads/mes","~1,000 escrituras/día, ~5,000 lecturas/día"),
    ("Lambda",            "1,000 invocaciones · 128 MB · 200ms","Consultas de stock via API Gateway"),
    ("API Gateway",       "1,000 requests/mes",               "HTTP API para fn-movimientos"),
    ("Data Transfer",     "10 GB/mes saliente",               "Respuestas HTTP + archivos + imágenes"),
    ("NAT Gateway",       "NO incluido",                      "Descartado en P05 – subred privada sin internet"),
    ("VPC/SG/IAM",        "Sin costo",                        "Infraestructura de red y gestión de acceso"),
]

tbl2 = doc.add_table(rows=len(supuestos_data), cols=3)
tbl2.style = "Table Grid"
tbl2.alignment = WD_TABLE_ALIGNMENT.CENTER

col_widths = [Cm(3.8), Cm(5.5), Cm(7.2)]

for row_idx, row_data in enumerate(supuestos_data):
    row = tbl2.rows[row_idx]
    for col_idx, text in enumerate(row_data):
        cell = row.cells[col_idx]
        cell.width = col_widths[col_idx]
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after  = Pt(2)
        if row_idx == 0:
            set_cell_bg(cell, AWS_DARK)
            add_run(p, text, bold=True, size=9.5, color=WHITE)
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        else:
            if row_idx % 2 == 0:
                set_cell_bg(cell, GRAY_BG)
            add_run(p, text, size=9.5)

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# SECCIÓN 2 — DESGLOSE DE COSTOS
# ══════════════════════════════════════════════════════════════════
heading("2. Desglose de Costo Mensual por Servicio", size=13, color=AWS_DARK)

p = doc.add_paragraph()
p.paragraph_format.space_after = Pt(6)
add_run(p,
    "Fuente de precios: AWS Price List API (5 precios reales + 9 valores de referencia publicados). "
    "Los cálculos se realizaron con Python/boto3 directamente en AWS CloudShell.",
    size=10.5)

# Datos de costos (basados en la salida real del script)
costos_data = [
    # (Servicio, Precio base, Costo/mes, es_subtotal, es_total)
    ("Servicio",                          "Precio base",                "$  Costo/mes",  True,  False),
    ("EC2 (t3.micro) — subtotal",         "$0.0104/hr × 730 hrs",       "$9.59",         False, False),
    ("   ├ EC2 compute",                  "$0.0104/hr × 730 hrs",       "$7.59",         False, False),
    ("   └ EBS gp3 (20 GB)",              "$0.10/GB-mes",               "$2.00",         False, False),
    ("RDS (db.t3.micro PostgreSQL) — subtotal", "$0.026/hr × 730 hrs", "$23.58",         False, False),
    ("   ├ RDS compute",                  "$0.026/hr × 730 hrs",        "$18.98",        False, False),
    ("   └ RDS storage gp2 (20 GB)",      "$0.115/GB-mes",              "$4.60",         False, False),
    ("S3 Standard (5 GB)",                "$0.023/GB-mes",              "$0.11",         False, False),
    ("S3 Standard-IA (2 GB)",             "$0.0125/GB-mes",             "$0.03",         False, False),
    ("S3 requests (PUT + GET)",           "$0.005/1K + $0.0004/1K",     "$0.00",         False, False),
    ("DynamoDB on-demand — subtotal",     "por request",                "$0.07",         False, False),
    ("   ├ Writes (30,000)",              "$1.25/millón",               "$0.04",         False, False),
    ("   └ Reads (150,000)",              "$0.25/millón",               "$0.04",         False, False),
    ("Lambda (1,000 invoc. · 128 MB)",    "$0.0000167/GB-s",            "$0.00",         False, False),
    ("API Gateway HTTP API",              "$1.00/millón requests",      "$0.00",         False, False),
    ("Data Transfer Out (10 GB)",         "$0.09/GB",                   "$0.90",         False, False),
    ("VPC + Subnets + SG + IGW",          "—",                          "$0.00",         False, False),
    ("IAM (Roles + Policies)",            "—",                          "$0.00",         False, False),
    ("TOTAL MENSUAL",                     "",                           "$34.29",         False, True),
    ("COSTO ANUAL ESTIMADO",              "",                           "$411.51",        False, True),
]

tbl3 = doc.add_table(rows=len(costos_data), cols=3)
tbl3.style = "Table Grid"
tbl3.alignment = WD_TABLE_ALIGNMENT.CENTER

col_widths3 = [Cm(7.5), Cm(5.0), Cm(4.0)]

for row_idx, (svc, base, costo, is_header, is_total) in enumerate(costos_data):
    row = tbl3.rows[row_idx]
    for col_idx, text in enumerate([svc, base, costo]):
        cell = row.cells[col_idx]
        cell.width = col_widths3[col_idx]
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after  = Pt(2)

        if is_header:
            set_cell_bg(cell, AWS_ORANGE)
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            add_run(p, text, bold=True, size=9.5, color=WHITE)
        elif is_total:
            set_cell_bg(cell, AWS_DARK)
            add_run(p, text, bold=True, size=10, color=WHITE)
            if col_idx == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        elif svc.endswith("subtotal") or svc.startswith("RDS (") or svc.startswith("EC2 (") or svc.startswith("DynamoDB"):
            set_cell_bg(cell, RGBColor(0xE8, 0xF4, 0xFF))
            add_run(p, text, bold=True, size=9.5)
            if col_idx == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        else:
            if row_idx % 2 == 0:
                set_cell_bg(cell, GRAY_BG)
            is_indent = text.startswith("   ")
            add_run(p, text, size=9.5,
                    color=RGBColor(0x44,0x44,0x44) if is_indent else BLACK)
            if col_idx == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# SECCIÓN 3 — SERVICIOS SIN COSTO
# ══════════════════════════════════════════════════════════════════
heading("3. Servicios Sin Costo Mensual", size=13, color=AWS_DARK)

sin_costo = [
    "VPC, subredes (pública y privada), tablas de ruteo, Internet Gateway",
    "Security Groups (EC2 y RDS)",
    "IAM: roles, políticas, instance profiles, key pairs",
    "CloudWatch Logs: la capa gratuita cubre el volumen del proyecto",
    "Route 53: no configurado — se usa la IP pública de la instancia EC2",
]
for item in sin_costo:
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_before = Pt(1)
    p.paragraph_format.space_after  = Pt(1)
    add_run(p, item, size=10.5)

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# SECCIÓN 4 — NOTA FREE TIER
# ══════════════════════════════════════════════════════════════════
heading("4. Nota sobre el Free Tier", size=13, color=AWS_DARK)

p = doc.add_paragraph()
p.paragraph_format.space_after = Pt(4)
add_run(p,
    "Todos los precios presentados corresponden a tarifas OnDemand sin Free Tier ni "
    "créditos de AWS Educate. En el Free Tier real:",
    size=10.5)

ft_items = [
    "EC2 t3.micro → 750 hrs/mes gratis durante el primer año ($0 en compute EC2)",
    "RDS db.t3.micro → 750 hrs/mes + 20 GB de almacenamiento gratis el primer año",
    "S3 → 5 GB Standard + 20,000 GET + 2,000 PUT gratis el primer año",
    "Lambda → 1 millón de invocaciones + 400,000 GB-s gratis permanentemente",
    "DynamoDB → 25 GB + 200 millones de solicitudes gratis permanentemente",
]
for item in ft_items:
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_before = Pt(1)
    p.paragraph_format.space_after  = Pt(1)
    add_run(p, item, size=10.5)

p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(6)
add_run(p,
    "Con Free Tier activo, el costo mensual efectivo durante el primer año "
    "se reduciría a aproximadamente ",
    size=10.5)
add_run(p, "$0.97/mes", bold=True, size=10.5, color=DARK_GREEN)
add_run(p,
    " (solo Data Transfer + DynamoDB + S3 IA). "
    "El costo sin ningún beneficio es de ",
    size=10.5)
add_run(p, "$34.29/mes", bold=True, size=10.5, color=RGBColor(0xCC,0x00,0x00))
add_run(p, " ($411.51/año).", size=10.5)

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# SECCIÓN 5 — SUPUESTOS DETALLADOS (media cuartilla)
# ══════════════════════════════════════════════════════════════════
heading("5. Supuestos Detallados", size=13, color=AWS_DARK)

parrafos = [
    ("Usuarios: ",
     "Se asumen 50 usuarios activos que interactúan diariamente con el sistema de "
     "inventario. Cada usuario registra movimientos de entrada/salida de productos, "
     "consulta existencias y sube documentos (facturas, reportes) al almacenamiento S3."),

    ("Horas de encendido: ",
     "El servidor EC2 (t3.micro, Nginx + Node.js) y la base de datos RDS "
     "(db.t3.micro PostgreSQL) se consideran encendidos las 24 horas los 7 días "
     "de la semana (730 hrs/mes), reflejando un entorno de producción siempre "
     "disponible. En la práctica escolar, el equipo detiene las instancias fuera "
     "del horario de clase para minimizar el consumo del Free Tier."),

    ("Almacenamiento: ",
     "EC2 EBS 20 GB para sistema operativo, aplicación Node.js y logs. "
     "RDS 20 GB para la base de datos PostgreSQL del inventario y su historial. "
     "S3 Standard 5 GB para el sitio estático y archivos subidos por los usuarios. "
     "S3 Standard-IA 2 GB para objetos migrados automáticamente por la lifecycle rule "
     "a los 30 días de inactividad. DynamoDB opera en modo on-demand sin costo "
     "de almacenamiento dedicado."),

    ("DynamoDB: ",
     "La tabla movimientos_inventario usa modo PAY_PER_REQUEST. Se estiman "
     "~1,000 escrituras/día (registro de movimientos) y ~5,000 lecturas/día "
     "(consultas de stock), totalizando 30,000 escrituras y 150,000 lecturas/mes. "
     "El costo resultante es marginal (~$0.07/mes)."),

    ("Lambda + API Gateway: ",
     "La función fn-movimientos-los-rojos (128 MB, timeout 10s) se invoca "
     "~1,000 veces/mes para consultas de movimientos vía API Gateway HTTP API. "
     "Con duración promedio de 200ms, el costo de cómputo Lambda es inferior "
     "a $0.01/mes, cubierto por la capa gratuita permanente."),

    ("Data Transfer: ",
     "Se asumen 10 GB/mes de tráfico saliente a internet: respuestas HTTP de la "
     "API Node.js, descargas de archivos del inventario e imágenes del sitio. "
     "Este es el único costo variable significativo fuera de las instancias."),

    ("NAT Gateway: ",
     "No se incluye en la estimación. Durante la Práctica 05 se evaluó el costo "
     "(~$32/mes en horas + $0.045/GB procesado) y se determinó que la subred "
     "privada no requiere acceso a internet, ya que RDS PostgreSQL solo necesita "
     "conectividad con la instancia EC2 dentro de la VPC."),
]

for bold_part, normal_part in parrafos:
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after  = Pt(4)
    p.paragraph_format.left_indent  = Cm(0)
    add_run(p, bold_part,   bold=True,  size=10.5)
    add_run(p, normal_part, bold=False, size=10.5)

doc.add_paragraph()

# ══════════════════════════════════════════════════════════════════
# RESUMEN EJECUTIVO (caja al final)
# ══════════════════════════════════════════════════════════════════
tbl4 = doc.add_table(rows=1, cols=1)
tbl4.alignment = WD_TABLE_ALIGNMENT.CENTER
cell4 = tbl4.cell(0, 0)
set_cell_bg(cell4, RGBColor(0xE8, 0xF4, 0xFF))
set_cell_border(cell4,
    top=    {"val":"single","sz":"8","color":"146EB4"},
    bottom= {"val":"single","sz":"8","color":"146EB4"},
    left=   {"val":"single","sz":"8","color":"146EB4"},
    right=  {"val":"single","sz":"8","color":"146EB4"},
)

p4 = cell4.paragraphs[0]
p4.alignment = WD_ALIGN_PARAGRAPH.CENTER
p4.paragraph_format.space_before = Pt(8)
p4.paragraph_format.space_after  = Pt(8)
add_run(p4, "RESUMEN DE COSTOS\n", bold=True, size=11, color=AWS_DARK)
add_run(p4, "Costo mensual estimado (sin Free Tier):  ", size=11, color=AWS_DARK)
add_run(p4, "$34.29 USD\n", bold=True, size=13, color=RGBColor(0xCC,0x00,0x00))
add_run(p4, "Costo anual estimado:  ", size=11, color=AWS_DARK)
add_run(p4, "$411.51 USD\n", bold=True, size=12, color=RGBColor(0xCC,0x00,0x00))
add_run(p4, "Costo con Free Tier (año 1):  ", size=11, color=AWS_DARK)
add_run(p4, "~$0.97/mes", bold=True, size=12, color=DARK_GREEN)
add_run(p4, "\nFuente: AWS Price List API · us-east-1 · 4 nov 2026", size=9,
        color=RGBColor(0x66,0x66,0x66), italic=True)

# ── Guardar ───────────────────────────────────────────────────────
output = r"c:\Users\angek\OneDrive\Documentos\COMPUTO-EN-LA-NUVE\T6_LosRojos_Costos.docx"
doc.save(output)
print(f"✔ Guardado: {output}")
