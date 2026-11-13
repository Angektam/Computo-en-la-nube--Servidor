#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_P09.py — Genera P09_LosRojos_26oct2026.docx con capturas reales
Práctica 09: Cómputo sin servidor — función y su interfaz pública
Equipo Los Rojos | Cómputo en la Nube | 26 oct 2026
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

OUTPUT  = "P09_LosRojos_26oct2026.docx"
IMG_DIR = r"C:\Users\angek\OneDrive\Imágenes\Practica-9"

# Rutas absolutas de cada captura (orden cronológico del timestamp)
I = {
    "deploy"     : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213543.png"),
    "c1_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213601.png"),
    "c1_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213615.png"),
    "c2_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213625.png"),
    "c2_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213640.png"),
    "c2_p3"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213655.png"),
    "c3_shell"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 213707.png"),
    "c4_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 215943.png"),
    "c4_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 215955.png"),
    "c5_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 220002.png"),
    "c5_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 220009.png"),
    "c5_p3"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 220029.png"),
    "c3_browser1": os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 220257.png"),
    "c3_browser2": os.path.join(IMG_DIR, "Captura de pantalla 2026-10-26 220324.png"),
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

def add_image(doc, path, width=Inches(6.0), caption_text=None):
    """Inserta imagen centrada con pie de figura opcional."""
    if not os.path.exists(path):
        p = doc.add_paragraph(f"[Imagen no encontrada: {os.path.basename(path)}]")
        p.runs[0].font.color.rgb = RGBColor(200, 0, 0)
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    run.add_picture(path, width=width)
    if caption_text:
        cap = doc.add_paragraph()
        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = cap.add_run(f"Figura: {caption_text}")
        r.font.italic = True
        r.font.size   = Pt(9)
        r.font.color.rgb = RGBColor(80, 80, 80)
        cap.paragraph_format.space_after = Pt(8)


def shading_cell(cell, color_hex):
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), color_hex)
    shd.set(qn("w:val"), "clear")
    cell._element.get_or_add_tcPr().append(shd)


def header_row(table, *cols, bg="1F3864"):
    row = table.rows[0]
    for cell, text in zip(row.cells, cols):
        cell.text = ""
        run = cell.paragraphs[0].add_run(text)
        run.font.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.size = Pt(10)
        shading_cell(cell, bg)


def data_row(table, row_idx, *cols, bg=None):
    fill = bg or ("F7F7F7" if row_idx % 2 == 0 else "FFFFFF")
    row  = table.rows[row_idx]
    for cell, text in zip(row.cells, cols):
        cell.text = ""
        run = cell.paragraphs[0].add_run(str(text))
        run.font.size = Pt(9.5)
        shading_cell(cell, fill)


def section_title(doc, text):
    h = doc.add_heading(text, level=2)
    h.paragraph_format.space_before = Pt(14)
    h.paragraph_format.space_after  = Pt(4)
    for run in h.runs:
        run.font.size = Pt(12)
        run.font.bold = True
        run.font.color.rgb = RGBColor(31, 56, 100)
    return h


def sub_title(doc, text):
    h = doc.add_heading(text, level=3)
    h.paragraph_format.space_before = Pt(8)
    h.paragraph_format.space_after  = Pt(2)
    for run in h.runs:
        run.font.size = Pt(11)
        run.font.bold = True
        run.font.color.rgb = RGBColor(31, 56, 100)
    return h


def body(doc, text):
    p = doc.add_paragraph(text)
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after  = Pt(3)
    for run in p.runs:
        run.font.size = Pt(10.5)
    return p


def code_block(doc, code, bg="F0F0F0"):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent  = Inches(0.3)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after  = Pt(2)
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), bg); shd.set(qn("w:val"), "clear")
    p._element.get_or_add_pPr().append(shd)
    run = p.add_run(code)
    run.font.name  = "Courier New"
    run.font.size  = Pt(8.5)
    run.font.color.rgb = RGBColor(30, 30, 30)
    return p


def nota_recuadro(doc, texto, bg="FFF3CD"):
    tbl  = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.cell(0, 0)
    cell.text = ""
    run  = cell.paragraphs[0].add_run(texto)
    run.font.size = Pt(9.5)
    shading_cell(cell, bg)
    doc.add_paragraph()
    return tbl


# =============================================================================
# CONSTRUCCIÓN DEL DOCUMENTO
# =============================================================================
doc = Document()
for sec in doc.sections:
    sec.top_margin    = Inches(0.75)
    sec.bottom_margin = Inches(0.75)
    sec.left_margin   = Inches(0.85)
    sec.right_margin  = Inches(0.85)

# ─── PORTADA ─────────────────────────────────────────────────────────────────
titulo = doc.add_heading("PRÁCTICA 09", level=1)
titulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in titulo.runs:
    r.font.size = Pt(20); r.font.bold = True
    r.font.color.rgb = RGBColor(31, 56, 100)

sub = doc.add_heading("Cómputo sin servidor: una función y su interfaz pública", level=2)
sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in sub.runs:
    r.font.size = Pt(14); r.font.bold = False
    r.font.color.rgb = RGBColor(60, 60, 60)

doc.add_paragraph()
meta = doc.add_table(rows=5, cols=2)
meta.style = "Table Grid"
for i, (k, v) in enumerate([
    ("Equipo",   "Los Rojos"),
    ("Materia",  "Cómputo en la Nube · Grupo 503"),
    ("Unidad",   "Unidad II · Segundo parcial"),
    ("Sesión",   "Lunes 26 de octubre de 2026"),
    ("Objetivo", "Implementar una funcionalidad sin administrar ningún servidor y compararla en costo y operación con la alternativa."),
]):
    meta.cell(i, 0).text = k
    meta.cell(i, 1).text = v
    for p in meta.cell(i, 0).paragraphs:
        for r in p.runs: r.font.bold = True; r.font.color.rgb = RGBColor(255,255,255); r.font.size = Pt(10)
    shading_cell(meta.cell(i, 0), "1F3864")
    for p in meta.cell(i, 1).paragraphs:
        for r in p.runs: r.font.size = Pt(10)

doc.add_paragraph()
doc.add_page_break()

# ─── 1. FUNCIONALIDAD ELEGIDA ────────────────────────────────────────────────
section_title(doc, "1. Funcionalidad elegida y justificación (C1 — 15 pts)")

body(doc, "Se identificaron tres funcionalidades candidatas del sistema Inventario Nube para implementar como función sin servidor. La funcionalidad elegida cumple simultáneamente los cuatro criterios de idoneidad para Lambda: esporádica, breve, dirigida por evento y sin estado.")

# Tabla candidatas
tbl = doc.add_table(rows=4, cols=4)
tbl.style = "Table Grid"
header_row(tbl, "Candidata", "Descripción", "Patrón de uso", "Decisión")
data_row(tbl, 1, "✔ ELEGIDA\nConsulta de movimientos",
    "GET /movimientos/{producto_id} — historial del producto desde DynamoDB",
    "Esporádica · HTTP GET · < 100 ms · Sin estado", "Lambda + API Gateway", bg="D4EDDA")
data_row(tbl, 2, "✗ Descartada\nSincronización RDS ↔ DynamoDB",
    "Lee filas de PostgreSQL y replica en DynamoDB",
    "Continua · Larga duración · Batch", "Mejor: cron en EC2 o ECS")
data_row(tbl, 3, "✗ Descartada\nReporte diario de movimientos",
    "Procesa todos los movimientos del día y genera PDF",
    "Periódica · Batch pesado · > 30 s posibles", "Mejor: EC2 + EventBridge o Glue")
doc.add_paragraph()

body(doc, "Evidencia C1 — Justificación ejecutada en CloudShell:")
add_image(doc, I["c1_p1"], Inches(6.2),
    "C1 (1/2): Funcionalidad elegida — criterios esporádica, breve, dirigida por evento, sin estado")
add_image(doc, I["c1_p2"], Inches(6.2),
    "C1 (2/2): Candidatas descartadas + tabla GetFunctionConfiguration (Active, 128 MB, Python 3.12, 10 s)")
doc.add_paragraph()

# ─── 2. CREAR LA FUNCIÓN ─────────────────────────────────────────────────────
section_title(doc, "2. Creación de la función Lambda")

body(doc, "La función se creó con los valores mínimos razonables. Estos dos parámetros determinan directamente el costo de Lambda (precio por GB·s):")

tbl2 = doc.add_table(rows=7, cols=3)
tbl2.style = "Table Grid"
header_row(tbl2, "Parámetro", "Valor asignado", "Justificación")
for i, (p, v, j) in enumerate([
    ("Nombre",         "fn-movimientos-los-rojos",     "Convención del proyecto"),
    ("Runtime",        "Python 3.12",                   "Mismo lenguaje que boto3/P07"),
    ("Handler",        "lambda_function.lambda_handler","Archivo único, sin dependencias extra"),
    ("Memoria",        "128 MB  ← determina costo",     "Mínimo Lambda; boto3 usa ~90 MB real (medido)"),
    ("Timeout",        "10 s  ← determina costo",       "DynamoDB PK query < 300 ms; 30× margen"),
    ("Execution Role", "rol-lambda-los-rojos",           "Rol dedicado, distinto al rol de EC2"),
], 1):
    bg = "FFF3CD" if "costo" in v else None
    data_row(tbl2, i, p, v, j, bg=bg or ("F7F7F7" if i%2==0 else "FFFFFF"))

doc.add_paragraph()
body(doc, "Evidencia — Despliegue completo en CloudShell (IAM Role + Lambda + API Gateway):")
add_image(doc, I["deploy"], Inches(6.2),
    "Despliegue completo: git pull + creación de Execution Role, política DynamoDB, empaquetado ZIP y Lambda activa")
doc.add_paragraph()

# ─── 3. CÓDIGO Y ROL DE SERVICIO ─────────────────────────────────────────────
section_title(doc, "3. Código de la función con rol de servicio (C2 — 25 pts)")

body(doc, "La función implementa GET /movimientos/{producto_id} usando el Execution Role adjunto (sin llaves de acceso en el código). boto3 resuelve las credenciales automáticamente del entorno de ejecución de Lambda.")

sub_title(doc, "3.1 Acceso a DynamoDB sin llaves hardcodeadas")
code_block(doc,
"""# boto3 resuelve credenciales del Execution Role automáticamente
dynamodb = boto3.resource("dynamodb", region_name=REGION)
table    = dynamodb.Table(TABLE_NAME)           # movimientos_inventario

result = table.query(
    KeyConditionExpression=Key("producto_id").eq(producto_id),
    ScanIndexForward=False,   # más recientes primero
    Limit=limit,
)""")

sub_title(doc, "3.2 Execution Role — permisos mínimos")
body(doc, "El rol rol-lambda-los-rojos tiene únicamente los permisos necesarios (Query, GetItem, DescribeTable) sobre la tabla movimientos_inventario. No puede escribir ni borrar.")

body(doc, "Evidencia C2 — Invocación con rol de servicio:")
add_image(doc, I["c2_p1"], Inches(6.2),
    "C2 (1/3): Execution Role adjunto + política DynamoDB (Allow Query/GetItem/DescribeTable) + invocación HTTP 200")
add_image(doc, I["c2_p2"], Inches(6.2),
    "C2 (2/3): Respuesta JSON — count:2 movimientos PROD-0042 + filtro tipo=salida (count:1)")
add_image(doc, I["c2_p3"], Inches(6.2),
    "C2 (3/3): Confirmación — función ejecuta correctamente con Execution Role, sin llaves de acceso")
doc.add_paragraph()

# ─── 4. BITÁCORA ─────────────────────────────────────────────────────────────
section_title(doc, "4. Bitácora de ejecución (CloudWatch Logs)")

body(doc, "Tras la primera invocación, CloudWatch Logs generó automáticamente el log group /aws/lambda/fn-movimientos-los-rojos. Las métricas reales medidas:")

tbl3 = doc.add_table(rows=4, cols=2)
tbl3.style = "Table Grid"
header_row(tbl3, "Métrica (del REPORT)", "Valor real medido")
data_row(tbl3, 1, "Duration (handler)",   "287.72 ms (cold) / 24.42 ms (warm)")
data_row(tbl3, 2, "Billed Duration",      "769 ms (cold) / 25 ms (warm)")
data_row(tbl3, 3, "Max Memory Used",      "90 MB de 128 MB asignados")

doc.add_paragraph()
code_block(doc,
"""# Cold start:
REPORT Duration: 287.72 ms  Billed Duration: 769 ms  Memory Size: 128 MB
       Max Memory Used: 90 MB  Init Duration: 480.88 ms

# Warm start (invocación inmediata):
REPORT Duration: 24.42 ms   Billed Duration: 25 ms   Memory Size: 128 MB
       Max Memory Used: 90 MB""")
doc.add_paragraph()

# ─── 5. INTERFAZ PÚBLICA ─────────────────────────────────────────────────────
section_title(doc, "5. Interfaz pública — API Gateway HTTP API (C3 — 20 pts)")

body(doc, "Se expuso la función mediante una API Gateway HTTP API (v2) con CORS habilitado. La API responde públicamente sin necesidad de credenciales AWS.")

tbl4 = doc.add_table(rows=5, cols=2)
tbl4.style = "Table Grid"
header_row(tbl4, "Parámetro", "Valor")
data_row(tbl4, 1, "API ID",          "1a1takbhs2")
data_row(tbl4, 2, "URL base",        "https://1a1takbhs2.execute-api.us-east-1.amazonaws.com")
data_row(tbl4, 3, "Ruta principal",  "GET /movimientos/{producto_id}")
data_row(tbl4, 4, "Ruta de stock",   "GET /movimientos/{producto_id}/stock")

doc.add_paragraph()
body(doc, "Evidencia C3 — API Gateway y prueba desde CloudShell:")
add_image(doc, I["c3_shell"], Inches(6.2),
    "C3 (1/3): API Gateway — datos (ID, nombre, protocolo, URL), rutas configuradas, pruebas GET 200 y 404")

doc.add_paragraph()
body(doc, "Evidencia C3 — Prueba desde el navegador (Chrome):")
add_image(doc, I["c3_browser1"], Inches(6.2),
    "C3 (2/3): Navegador — respuesta JSON PROD-0042 (count:2, movimientos MOV-8810 y MOV-8801)")
add_image(doc, I["c3_browser2"], Inches(5.5),
    "C3 (3/3): Navegador — ruta /stock: stock_actual=68, último movimiento MOV-8810")

nota_recuadro(doc,
    "⚠ SEGURIDAD: La API está abierta sin autenticación (solo operaciones de lectura, sin acciones destructivas). "
    "Se registra como riesgo en la matriz del proyecto y se resolverá antes del E3 con un API Key o Lambda Authorizer.",
    bg="F8D7DA")
doc.add_paragraph()

# ─── 6. ARRANQUE EN FRÍO ─────────────────────────────────────────────────────
section_title(doc, "6. Arranque en frío (C4 — 20 pts)")

body(doc, "Se realizaron dos invocaciones consecutivas: la primera tras varios minutos de inactividad (cold start) y la segunda inmediatamente después (warm start). Los logs de CloudWatch confirman las cifras:")

tbl5 = doc.add_table(rows=3, cols=5)
tbl5.style = "Table Grid"
header_row(tbl5, "Invocación", "Init Duration", "Duration", "Billed", "Max Memory")
data_row(tbl5, 1, "1ª — Cold Start\n(función inactiva)", "480.88 ms", "287.72 ms", "769 ms", "90 MB")
data_row(tbl5, 2, "2ª — Warm Start\n(inmediata)",        "— (no aplica)", "24.42 ms", "25 ms",  "90 MB")

doc.add_paragraph()
body(doc, "Evidencia C4 — Medición de arranque en frío:")
add_image(doc, I["c4_p1"], Inches(6.2),
    "C4 (1/2): Cold start ~1872 ms externo / Warm start ~879 ms externo — REPORT lines de CloudWatch con Init Duration: 480.88 ms")
add_image(doc, I["c4_p2"], Inches(6.2),
    "C4 (2/2): Explicación del fenómeno cold start — 4 pasos de inicialización + resumen comparativo")

doc.add_paragraph()
sub_title(doc, "6.1 Explicación del arranque en frío")
body(doc,
    "Cuando Lambda no recibe invocaciones por varios minutos, AWS libera el entorno de ejecución. "
    "La siguiente invocación inicializa desde cero:")
for paso in [
    "Descargar y descomprimir el paquete .zip",
    "Iniciar el proceso Python (intérprete + runtime de Lambda)",
    "Importar dependencias: boto3, botocore, re, json, logging",
    "Ejecutar código fuera del handler: clientes boto3 globales (dynamodb, table)",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(paso).font.size = Pt(10)

body(doc,
    "La Init Duration (480.88 ms) es el tiempo de estos 4 pasos. "
    "El warm start saltea todo eso y ejecuta solo el handler: 24.42 ms. "
    "La diferencia es 11× más rápido en warm que en cold.")
doc.add_paragraph()

# ─── 7. AJUSTE DE DIMENSIONAMIENTO ───────────────────────────────────────────
section_title(doc, "7. Ajuste de dimensionamiento")

body(doc,
    "La bitácora reveló que la función usa 90 MB de los 128 MB asignados. "
    "128 MB es el mínimo configurable en Lambda — no es posible reducirlo. "
    "El dimensionamiento ya está en su valor óptimo.")

tbl6 = doc.add_table(rows=3, cols=3)
tbl6.style = "Table Grid"
header_row(tbl6, "Configuración", "Memoria", "Duration medida")
data_row(tbl6, 1, "Original (paso 2)",    "128 MB", "287 ms cold / 24 ms warm")
data_row(tbl6, 2, "Tras ajuste (paso 7)", "128 MB  (mínimo Lambda)", "Sin cambio — I/O bound, no CPU bound")

doc.add_paragraph()
body(doc, "Evidencia — ajuste de dimensionamiento y verificación:")
add_image(doc, I["c5_p1"], Inches(6.2),
    "Paso 7: configuración actual confirmada (128 MB / 10 s) e inicio del cálculo comparativo de costo")
doc.add_paragraph()

# ─── 8. COMPARACIÓN DE COSTO ─────────────────────────────────────────────────
section_title(doc, "8. Comparación de costo: Lambda vs EC2 (C5 — 20 pts)")

body(doc,
    "Escenario: 10,000 invocaciones por mes. Duración medida: ~80 ms warm (promedio ponderado "
    "considerando 5% cold starts). Comparado contra EC2 t3.micro On-Demand 24/7.")

sub_title(doc, "8.1 Cálculo Lambda")
code_block(doc,
"""GB·s totales  = (128 MB / 1024) × (10,000 × 0.080 s)  = 121.875 GB·s
Costo cómputo = 121.875 × $0.0000166667/GB·s           = $0.002031 USD
Costo requests= (10,000 / 1,000,000) × $0.20           = $0.002000 USD
─────────────────────────────────────────────────────────────────────
TOTAL Lambda  = $0.004031 USD/mes  (sin capa gratuita)
TOTAL Lambda  = $0.000000 USD/mes  (con capa gratuita — 400K GB·s gratis)

Fuente: https://aws.amazon.com/lambda/pricing/  (us-east-1, oct 2026)""")

sub_title(doc, "8.2 Cálculo EC2 t3.micro")
code_block(doc,
"""Precio On-Demand us-east-1 Linux: $0.0104/hora
Costo mensual = $0.0104 × 730 horas = $7.592 USD/mes

Fuente: https://aws.amazon.com/ec2/pricing/on-demand/  (us-east-1, oct 2026)""")

sub_title(doc, "8.3 Tabla comparativa")
tbl7 = doc.add_table(rows=4, cols=3)
tbl7.style = "Table Grid"
header_row(tbl7, "Concepto", "Lambda", "EC2 t3.micro 24/7")
data_row(tbl7, 1, "Costo/mes (sin capa gratuita)", "$0.004031 USD", "$7.5920 USD")
data_row(tbl7, 2, "Costo/mes (con capa gratuita)", "$0.000000 USD", "$7.5920 USD")
data_row(tbl7, 3, "Lambda vs EC2", "~1,883× más barata", "—")

doc.add_paragraph()
body(doc, "Evidencia C5 — Cálculo comparativo ejecutado en CloudShell:")
add_image(doc, I["c5_p2"], Inches(6.2),
    "C5 (1/2): Tabla de cálculo completa — GB·s=121.875, Lambda=$0.004031/mes, EC2=$7.592/mes")
add_image(doc, I["c5_p3"], Inches(6.2),
    "C5 (2/2): Conclusión — Lambda es ~1,883× más barata para 10,000 invocaciones/mes, con fuentes de precio")

nota_recuadro(doc,
    "📌 CONCLUSIÓN ARQUITECTÓNICA: La funcionalidad de consulta de movimientos conviene como función Lambda. "
    "Para 10,000 req/mes el costo es $0.004 USD vs $7.59 USD de EC2. "
    "La decisión cambiaría solo si el volumen superara ~40 millones de invocaciones/mes con duración prolongada.",
    bg="D4EDDA")
doc.add_paragraph()

# ─── 9. LISTA DE COTEJO ──────────────────────────────────────────────────────
section_title(doc, "9. Lista de cotejo")

tbl8 = doc.add_table(rows=6, cols=3)
tbl8.style = "Table Grid"
header_row(tbl8, "Criterio", "Puntos", "Cumple")
for i, (c, p, ok) in enumerate([
    ("La funcionalidad elegida se justifica frente a las descartadas",             "15", "✔"),
    ("La función se ejecuta correctamente y accede a los datos con rol de servicio","25", "✔"),
    ("La interfaz pública responde y hay evidencia",                                "20", "✔"),
    ("Se documenta y explica el arranque en frío con dos mediciones",               "20", "✔"),
    ("El cálculo comparativo de costo usa precios reales y está bien planteado",    "20", "✔"),
], 1):
    data_row(tbl8, i, c, p, ok, bg="D4EDDA")

doc.add_paragraph()

# ─── 10. REPOSITORIO ─────────────────────────────────────────────────────────
section_title(doc, "10. Código en el repositorio")

body(doc, "https://github.com/Angektam/Computo-en-la-nube--Servidor/tree/main/practica09")

archivos = [
    ("practica09/lambda_function.py",              "Código de la función Lambda (Python 3.12)"),
    ("practica09/aws-practica09-lambda.sh",         "Despliegue completo: IAM + Lambda + API Gateway"),
    ("practica09/evidencia-p09-c1-justificacion.sh","Evidencia C1 — justificación"),
    ("practica09/evidencia-p09-c2-funcion-datos.sh","Evidencia C2 — función + rol"),
    ("practica09/evidencia-p09-c3-interfaz-publica.sh","Evidencia C3 — API pública"),
    ("practica09/evidencia-p09-c4-arranque-frio.sh","Evidencia C4 — cold start"),
    ("practica09/evidencia-p09-c5-costo-comparativo.sh","Evidencia C5 — comparativa costo"),
]
tbl9 = doc.add_table(rows=len(archivos)+1, cols=2)
tbl9.style = "Table Grid"
header_row(tbl9, "Archivo", "Descripción")
for i, (f, d) in enumerate(archivos, 1):
    data_row(tbl9, i, f, d)

doc.add_paragraph()

# ─── FOOTER ──────────────────────────────────────────────────────────────────
pie = doc.add_paragraph()
pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = pie.add_run("Práctica 09 · Equipo Los Rojos · Cómputo en la Nube · UAS · 26 oct 2026")
r.font.size = Pt(9); r.font.italic = True
r.font.color.rgb = RGBColor(120, 120, 120)

# =============================================================================
doc.save(OUTPUT)
print(f"✔  Documento generado: {OUTPUT}")
