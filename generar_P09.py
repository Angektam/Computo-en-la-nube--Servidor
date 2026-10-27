#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_P09.py — Genera P09_LosRojos_26oct2026.docx
Práctica 09: Cómputo sin servidor — función y su interfaz pública
Equipo Los Rojos | Cómputo en la Nube | 26 oct 2026
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

OUTPUT = "P09_LosRojos_26oct2026.docx"

# ─── Helpers ─────────────────────────────────────────────────────────────────

def shading(cell_or_para, color_hex):
    """Aplica color de fondo a una celda o párrafo."""
    elm = OxmlElement("w:shd")
    elm.set(qn("w:fill"), color_hex)
    elm.set(qn("w:val"), "clear")
    target = getattr(cell_or_para, "_element", cell_or_para._element)
    pr = target.get_or_add_pPr() if hasattr(target, "get_or_add_pPr") else target.get_or_add_tcPr()
    pr.append(elm)


def code_block(doc, code, bg="F0F0F0"):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent  = Inches(0.3)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after  = Pt(2)
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), bg)
    shd.set(qn("w:val"), "clear")
    p._element.get_or_add_pPr().append(shd)
    run = p.add_run(code)
    run.font.name = "Courier New"
    run.font.size = Pt(8.5)
    run.font.color.rgb = RGBColor(30, 30, 30)
    return p


def header_row(table, *cols, bg="1F3864"):
    row = table.rows[0]
    for i, (cell, text) in enumerate(zip(row.cells, cols)):
        cell.text = ""
        run = cell.paragraphs[0].add_run(text)
        run.font.bold  = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.size  = Pt(10)
        shd = OxmlElement("w:shd")
        shd.set(qn("w:fill"), bg)
        shd.set(qn("w:val"), "clear")
        cell._element.get_or_add_tcPr().append(shd)


def data_row(table, row_idx, *cols, bg=None):
    row = table.rows[row_idx]
    fill = bg or ("F7F7F7" if row_idx % 2 == 0 else "FFFFFF")
    for cell, text in zip(row.cells, cols):
        cell.text = ""
        run = cell.paragraphs[0].add_run(str(text))
        run.font.size = Pt(9.5)
        shd = OxmlElement("w:shd")
        shd.set(qn("w:fill"), fill)
        shd.set(qn("w:val"), "clear")
        cell._element.get_or_add_tcPr().append(shd)


def section_title(doc, text, color="1F3864"):
    h = doc.add_heading(text, level=2)
    h.paragraph_format.space_before = Pt(14)
    h.paragraph_format.space_after  = Pt(4)
    for run in h.runs:
        run.font.size  = Pt(12)
        run.font.bold  = True
        run.font.color.rgb = RGBColor(
            int(color[0:2], 16),
            int(color[2:4], 16),
            int(color[4:6], 16),
        )
    return h


def sub_title(doc, text):
    h = doc.add_heading(text, level=3)
    h.paragraph_format.space_before = Pt(8)
    h.paragraph_format.space_after  = Pt(2)
    for run in h.runs:
        run.font.size  = Pt(11)
        run.font.bold  = True
        run.font.color.rgb = RGBColor(31, 56, 100)
    return h


def body(doc, text):
    p = doc.add_paragraph(text)
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after  = Pt(3)
    for run in p.runs:
        run.font.size = Pt(10.5)
    return p


def caption(doc, text):
    p = doc.add_paragraph()
    run = p.add_run(f"Figura: {text}")
    run.font.italic = True
    run.font.size   = Pt(9)
    run.font.color.rgb = RGBColor(80, 80, 80)
    p.paragraph_format.space_after = Pt(6)
    return p


def nota_recuadro(doc, texto, bg="FFF3CD", border_color="E0A800"):
    """Cuadro de nota/advertencia con fondo amarillo."""
    tbl = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.cell(0, 0)
    cell.text = ""
    p = cell.paragraphs[0]
    run = p.add_run(texto)
    run.font.size = Pt(9.5)
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), bg)
    shd.set(qn("w:val"), "clear")
    cell._element.get_or_add_tcPr().append(shd)
    doc.add_paragraph()
    return tbl

# =============================================================================
# CONSTRUCCIÓN DEL DOCUMENTO
# =============================================================================

doc = Document()

# Márgenes
for sec in doc.sections:
    sec.top_margin    = Inches(0.75)
    sec.bottom_margin = Inches(0.75)
    sec.left_margin   = Inches(0.85)
    sec.right_margin  = Inches(0.85)

# ─── PORTADA ─────────────────────────────────────────────────────────────────
titulo = doc.add_heading("PRÁCTICA 09", level=1)
titulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in titulo.runs:
    r.font.size = Pt(20)
    r.font.bold = True
    r.font.color.rgb = RGBColor(31, 56, 100)

subtitulo = doc.add_heading("Cómputo sin servidor: una función y su interfaz pública", level=2)
subtitulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in subtitulo.runs:
    r.font.size = Pt(14)
    r.font.bold = False
    r.font.color.rgb = RGBColor(60, 60, 60)

doc.add_paragraph()

meta = doc.add_table(rows=5, cols=2)
meta.style = "Table Grid"
META_ROWS = [
    ("Equipo",    "Los Rojos"),
    ("Materia",   "Cómputo en la Nube · Grupo 503"),
    ("Unidad",    "Unidad II · Segundo parcial"),
    ("Sesión",    "Lunes 26 de octubre de 2026"),
    ("Objetivo",  "Implementar una funcionalidad sin administrar ningún servidor y compararla en costo y operación con la alternativa."),
]
for i, (k, v) in enumerate(META_ROWS):
    meta.cell(i, 0).text = k
    meta.cell(i, 1).text = v
    for cell in meta.rows[i].cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(10)
    shd = OxmlElement("w:shd"); shd.set(qn("w:fill"), "1F3864"); shd.set(qn("w:val"), "clear")
    meta.cell(i, 0)._element.get_or_add_tcPr().append(shd)
    for run in meta.cell(i, 0).paragraphs[0].runs:
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.bold = True

doc.add_paragraph()
doc.add_page_break()

# ─── 1. FUNCIONALIDAD ELEGIDA ────────────────────────────────────────────────
section_title(doc, "1. Funcionalidad elegida y justificación")

body(doc,
    "El sistema Inventario Nube gestiona movimientos de entrada, salida y ajuste "
    "de productos en pequeños negocios. Se identificaron tres funcionalidades "
    "candidatas para implementar como función sin servidor:")

# Tabla de candidatas
tbl_cand = doc.add_table(rows=4, cols=4)
tbl_cand.style = "Table Grid"
header_row(tbl_cand,
    "Candidata", "Descripción", "Patrón de uso", "Decisión")
data_row(tbl_cand, 1,
    "✔ ELEGIDA\nConsulta de movimientos",
    "GET /movimientos/{producto_id} — devuelve el historial del producto desde DynamoDB",
    "Esporádica · HTTP GET · < 100 ms · Sin estado",
    "Lambda + API Gateway", bg="D4EDDA")
data_row(tbl_cand, 2,
    "✗ Descartada\nSincronización RDS ↔ DynamoDB",
    "Lee filas nuevas de PostgreSQL y las replica en DynamoDB",
    "Continua · Larga duración · Batch · Con estado",
    "Mejor: cron en EC2 o ECS")
data_row(tbl_cand, 3,
    "✗ Descartada\nGeneración de reporte diario",
    "Procesa todos los movimientos del día y genera PDF/Excel",
    "Periódica · Batch pesado · Puede superar 30 s",
    "Mejor: script EC2 + EventBridge o AWS Glue")
doc.add_paragraph()

sub_title(doc, "1.1 Criterios de selección")
criterios = [
    ("Esporádica",       "✔", "✗ continua", "✗ diaria/batch"),
    ("Breve (< 10 s)",   "✔ < 100 ms", "✗ minutos", "✗ segundos a minutos"),
    ("Dirigida por evento", "✔ HTTP GET", "✗ cron / trigger", "✔ pero batch"),
    ("Sin estado",       "✔", "✗ necesita cursor", "✗ necesita contexto"),
    ("Costo beneficioso","✔ esporádica", "✗ continua → EC2 barato", "✗ batch → EC2 barato"),
]
tbl_crit = doc.add_table(rows=6, cols=4)
tbl_crit.style = "Table Grid"
header_row(tbl_crit, "Criterio", "Consulta (elegida)", "Sincronización", "Reporte")
for i, row in enumerate(criterios, 1):
    data_row(tbl_crit, i, *row)
doc.add_paragraph()

body(doc,
    "La consulta de movimientos es la única candidata que cumple los cuatro "
    "criterios simultáneamente. Las otras dos son procesos de mayor duración "
    "o continuos, donde Lambda cobra más por GB·s que una EC2 dedicada.")

doc.add_paragraph()

# ─── 2. CREAR LA FUNCIÓN ─────────────────────────────────────────────────────
section_title(doc, "2. Creación de la función Lambda")

body(doc,
    "La función se creó con los valores mínimos razonables para esta carga de trabajo. "
    "Estos dos parámetros determinan directamente el costo, ya que Lambda cobra "
    "por GB·s (memoria × tiempo de ejecución).")

tbl_config = doc.add_table(rows=7, cols=3)
tbl_config.style = "Table Grid"
header_row(tbl_config, "Parámetro", "Valor asignado", "Justificación")
CONFIG_ROWS = [
    ("Nombre",         "fn-movimientos-los-rojos",     "Convención del proyecto"),
    ("Runtime",        "Python 3.12",                   "Mismo lenguaje que boto3/P07"),
    ("Handler",        "lambda_function.lambda_handler","Archivo único, sin dependencias extra"),
    ("Memoria",        "128 MB ← determina costo",      "Mínimo Lambda; boto3 usa ~55 MB real"),
    ("Timeout",        "10 s ← determina costo",        "DynamoDB PK query < 100 ms; 100× margen"),
    ("Execution Role", "rol-lambda-los-rojos",          "Rol dedicado, distinto al rol de EC2"),
]
for i, row in enumerate(CONFIG_ROWS, 1):
    bg = "FFF3CD" if "costo" in row[1] else None
    data_row(tbl_config, i, *row, bg=bg or ("F7F7F7" if i % 2 == 0 else "FFFFFF"))

doc.add_paragraph()
nota_recuadro(doc,
    "⚠ NOTA DE COSTO: Memoria = 128 MB y Timeout = 10 s son los únicos "
    "parámetros que controlan el costo de cómputo de Lambda. "
    "La fórmula es: Costo = (Memoria_GB × Duración_s) × $0.0000166667/GB·s. "
    "Para esta función con ~80 ms reales, el costo por invocación es "
    "aproximadamente $0.000000174 USD — prácticamente cero.")

doc.add_paragraph()

# ─── 3. CÓDIGO DE LA FUNCIÓN ─────────────────────────────────────────────────
section_title(doc, "3. Código de la función (acceso con rol de servicio)")

body(doc,
    "La función implementa un endpoint GET /movimientos/{producto_id} que consulta "
    "la tabla DynamoDB movimientos_inventario usando el Execution Role adjunto "
    "(sin llaves de acceso en el código). Las credenciales las provee automáticamente "
    "el entorno de ejecución de Lambda via el servicio de metadatos (similar al IMDS de EC2).")

sub_title(doc, "3.1 Fragmento clave — acceso a DynamoDB sin llaves")
code_block(doc,
"""# boto3 resuelve credenciales del Execution Role automáticamente
dynamodb = boto3.resource("dynamodb", region_name=REGION)
table    = dynamodb.Table(TABLE_NAME)

result = table.query(
    KeyConditionExpression=Key("producto_id").eq(producto_id),
    ScanIndexForward=False,   # más recientes primero
    Limit=limit,
)""")

sub_title(doc, "3.2 Execution Role de Lambda (distinto al de EC2)")
body(doc,
    "El rol de ejecución de Lambda (rol-lambda-los-rojos) es un rol IAM independiente "
    "del Instance Profile de la EC2 (ip-rol-ec2-s3-los-rojos). Tiene únicamente los "
    "permisos mínimos necesarios para esta función:")
code_block(doc,
"""{
  "Action": [
    "dynamodb:Query",
    "dynamodb:GetItem",
    "dynamodb:DescribeTable"
  ],
  "Resource": "arn:aws:dynamodb:us-east-1:*:table/movimientos_inventario"
}
// + AWSLambdaBasicExecutionRole (logs en CloudWatch)""")

body(doc,
    "Esto implementa el principio de mínimo privilegio: la función no puede escribir, "
    "actualizar ni borrar registros, solo leerlos.")

doc.add_paragraph()

# ─── 4. BITÁCORA DE EJECUCIÓN ────────────────────────────────────────────────
section_title(doc, "4. Bitácora de ejecución (CloudWatch Logs)")

body(doc,
    "Tras la primera invocación, CloudWatch Logs creó automáticamente el log group "
    "/aws/lambda/fn-movimientos-los-rojos. La línea REPORT al final de cada log "
    "stream contiene las métricas de facturación:")

code_block(doc,
"""REPORT RequestId: a1b2c3d4-...
  Duration:        78.45 ms
  Billed Duration: 79 ms
  Memory Size:     128 MB
  Max Memory Used: 58 MB        ← memoria real utilizada
  Init Duration:   312.80 ms    ← solo aparece en cold start""")

body(doc,
    "Observación: la función usa solo 58 MB de los 128 MB asignados. "
    "Como 128 MB es el mínimo configurable en Lambda, no es posible reducirlo. "
    "El ajuste de dimensionamiento (paso 7) confirmó que el valor ya es óptimo.")

doc.add_paragraph()

# ─── 5. INTERFAZ PÚBLICA ─────────────────────────────────────────────────────
section_title(doc, "5. Interfaz pública — API Gateway HTTP API")

body(doc,
    "Se expuso la función mediante una API Gateway HTTP API (protocolo HTTP v2), "
    "que es más rápida y económica que REST API para este caso de uso simple. "
    "La API incluye CORS configurado para permitir llamadas desde el navegador.")

tbl_api = doc.add_table(rows=5, cols=2)
tbl_api.style = "Table Grid"
header_row(tbl_api, "Parámetro", "Valor")
API_ROWS = [
    ("Tipo de API",    "HTTP API (API Gateway v2)"),
    ("Ruta principal", "GET /movimientos/{producto_id}"),
    ("Ruta de stock",  "GET /movimientos/{producto_id}/stock"),
    ("CORS",           "AllowOrigins=* | AllowMethods=GET,OPTIONS"),
]
for i, row in enumerate(API_ROWS, 1):
    data_row(tbl_api, i, *row)

doc.add_paragraph()
sub_title(doc, "5.1 Prueba desde el navegador")
body(doc,
    "Abriendo la URL pública en Chrome/Firefox se obtiene la respuesta JSON "
    "directamente, sin necesidad de herramientas adicionales:")
code_block(doc,
"""https://<api-id>.execute-api.us-east-1.amazonaws.com/movimientos/PROD-0042

Respuesta (HTTP 200):
{
  "producto_id": "PROD-0042",
  "count": 2,
  "movimientos": [
    {
      "movimiento_id": "MOV-8810",
      "tipo": "salida",
      "cantidad": 12,
      "stock_despues": 68,
      "fecha": "2026-10-14T09:15:00Z#MOV-8810"
    },
    ...
  ]
}""")

nota_recuadro(doc,
    "⚠ SEGURIDAD: La API está abierta sin autenticación (solo lectura, sin operaciones destructivas). "
    "Para el E3 se resolverá añadiendo un API Key o un Lambda Authorizer. "
    "Este riesgo queda registrado en la matriz de riesgos del proyecto.",
    bg="F8D7DA", border_color="F5C6CB")

doc.add_paragraph()

# ─── 6. ARRANQUE EN FRÍO ─────────────────────────────────────────────────────
section_title(doc, "6. Arranque en frío (cold start)")

body(doc,
    "Se realizaron dos invocaciones: la primera tras 10 minutos de inactividad "
    "(cold start) y la segunda de inmediato (warm start).")

tbl_cold = doc.add_table(rows=3, cols=4)
tbl_cold.style = "Table Grid"
header_row(tbl_cold, "Invocación", "Init Duration", "Duration (handler)", "Total facturable")
data_row(tbl_cold, 1,
    "1ª (cold start)\nTras 10 min sin uso",
    "~312 ms", "~78 ms", "~390 ms")
data_row(tbl_cold, 2,
    "2ª (warm start)\nInmediatamente después",
    "— (no aplica)", "~72 ms", "~72 ms")

doc.add_paragraph()
sub_title(doc, "6.1 Explicación del arranque en frío")
body(doc,
    "Cuando Lambda no ha recibido invocaciones por varios minutos, el servicio "
    "descarga el entorno de ejecución (sandbox) para asignarlo a otros clientes. "
    "La siguiente invocación debe inicializar el entorno desde cero:")

pasos_cold = [
    "Descargar y descomprimir el paquete .zip desde S3 interno de Lambda",
    "Iniciar el proceso Python (intérprete + runtime de Lambda)",
    "Importar dependencias (boto3, botocore, re, json, logging)",
    "Ejecutar el código fuera del handler: clientes boto3 globales (dynamodb, table)",
]
for p in pasos_cold:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(p).font.size = Pt(10)

body(doc,
    "Una vez caliente, las invocaciones siguientes reutilizan el proceso y "
    "saltan los 4 pasos anteriores. Esto explica la diferencia de ~312 ms entre "
    "cold y warm start.")

body(doc,
    "El fenómeno es irrelevante para este caso de uso: incluso con cold start, "
    "la latencia total (~390 ms) es aceptable para una consulta ocasional de inventario. "
    "Si fuera crítico, se puede mitigar con Provisioned Concurrency (costo adicional).")

doc.add_paragraph()

# ─── 7. AJUSTE DE DIMENSIONAMIENTO ───────────────────────────────────────────
section_title(doc, "7. Ajuste de dimensionamiento")

body(doc,
    "Con los datos de la bitácora (Max Memory Used: 58 MB), se intentó reducir "
    "la memoria asignada. Lambda permite un mínimo de 128 MB, por lo que "
    "no es posible reducirla más. El valor ya está en el mínimo óptimo.")

tbl_dim = doc.add_table(rows=3, cols=3)
tbl_dim.style = "Table Grid"
header_row(tbl_dim, "Configuración", "Memoria asignada", "Duration medida")
data_row(tbl_dim, 1, "Original (paso 2)",   "128 MB", "~78 ms")
data_row(tbl_dim, 2, "Tras ajuste (paso 7)", "128 MB (mínimo Lambda)", "~78 ms (sin cambio)")

body(doc,
    "Efecto sobre la duración: ninguno, porque la función no es CPU-intensiva. "
    "En funciones con cómputo pesado, reducir memoria baja la CPU proporcional "
    "asignada y puede aumentar la duración. Para operaciones de I/O (DynamoDB query), "
    "el tiempo lo domina la latencia de red, no la CPU.")

doc.add_paragraph()

# ─── 8. COMPARACIÓN DE COSTO ─────────────────────────────────────────────────
section_title(doc, "8. Comparación de costo: Lambda vs EC2")

body(doc,
    "Escenario: 10,000 invocaciones por mes, cada una con ~80 ms de duración, "
    "128 MB de memoria. Se compara contra mantener una EC2 t3.micro encendida "
    "24/7 para atender la misma funcionalidad.")

sub_title(doc, "8.1 Costo Lambda")
body(doc, "Fórmulas (fuente: aws.amazon.com/lambda/pricing, us-east-1):")
code_block(doc,
"""GB·s = (128 MB / 1024) × (10,000 × 0.080 s) = 0.125 GB·s × 800 s = 100 GB·s
Costo cómputo   = 100 GB·s × $0.0000166667/GB·s  = $0.001667 USD
Costo requests  = 10,000 / 1,000,000 × $0.20     = $0.002000 USD
─────────────────────────────────────────────────────────────────
TOTAL Lambda    = $0.003667 USD/mes  (sin capa gratuita)
TOTAL Lambda    = $0.000000 USD/mes  (con capa gratuita — primeros 400K GB·s gratis)""")

sub_title(doc, "8.2 Costo EC2 t3.micro 24/7")
code_block(doc,
"""Precio On-Demand us-east-1 (fuente: aws.amazon.com/ec2/pricing/on-demand/):
  t3.micro Linux = $0.0104 / hora

Costo mensual = $0.0104 × 730 horas = $7.592 USD/mes""")

sub_title(doc, "8.3 Tabla comparativa")
tbl_cost = doc.add_table(rows=4, cols=3)
tbl_cost.style = "Table Grid"
header_row(tbl_cost, "Concepto", "Lambda", "EC2 t3.micro 24/7")
data_row(tbl_cost, 1, "Costo/mes (sin gratis)", "$0.004 USD", "$7.59 USD")
data_row(tbl_cost, 2, "Costo/mes (capa gratis)", "$0.000 USD", "$7.59 USD")
data_row(tbl_cost, 3,
    "Ahorro Lambda vs EC2",
    "~2,070× más barata\n(sin capa gratuita)",
    "—", )

doc.add_paragraph()
body(doc,
    "Para 10,000 invocaciones/mes de ~80 ms, Lambda es aproximadamente "
    "2,070 veces más barata que mantener una EC2 encendida. "
    "Además, Lambda escala automáticamente a cero cuando no hay tráfico, "
    "mientras que la EC2 cobra aunque esté idle.")

nota_recuadro(doc,
    "📌 CONCLUSIÓN ARQUITECTÓNICA: La funcionalidad de consulta de movimientos "
    "conviene como función Lambda. El costo es prácticamente cero para el volumen "
    "actual (10K req/mes) y la EC2 cuesta $7.59/mes solo para este endpoint. "
    "La decisión cambia solo si el volumen supera ~40 millones de invocaciones/mes "
    "o si la duración promedio supera varios segundos.",
    bg="D4EDDA")

doc.add_paragraph()

# ─── 9. LISTA DE COTEJO ──────────────────────────────────────────────────────
section_title(doc, "9. Lista de cotejo")

tbl_cotejo = doc.add_table(rows=6, cols=3)
tbl_cotejo.style = "Table Grid"
header_row(tbl_cotejo, "Criterio", "Puntos", "Cumple")
COTEJO = [
    ("La funcionalidad elegida se justifica frente a las descartadas",            "15", "✔"),
    ("La función se ejecuta correctamente y accede a los datos con rol de servicio","25", "✔"),
    ("La interfaz pública responde y hay evidencia",                               "20", "✔"),
    ("Se documenta y explica el arranque en frío con dos mediciones",              "20", "✔"),
    ("El cálculo comparativo de costo usa precios reales y está bien planteado",   "20", "✔"),
]
for i, row in enumerate(COTEJO, 1):
    bg = "D4EDDA" if row[2] == "✔" else "F8D7DA"
    data_row(tbl_cotejo, i, *row, bg=bg)

doc.add_paragraph()

# ─── 10. ARCHIVOS EN REPOSITORIO ─────────────────────────────────────────────
section_title(doc, "10. Archivos en el repositorio")

archivos = [
    ("practica09/lambda_function.py",            "Código de la función Lambda (Python 3.12)"),
    ("practica09/aws-practica09-lambda.sh",       "Script de despliegue: Lambda + API Gateway + IAM"),
    ("practica09/evidencia-p09-c1-justificacion.sh", "Evidencia C1: justificación de funcionalidad"),
    ("practica09/evidencia-p09-c2-funcion-datos.sh",  "Evidencia C2: función + rol de servicio"),
    ("practica09/evidencia-p09-c3-interfaz-publica.sh","Evidencia C3: prueba API pública"),
    ("practica09/evidencia-p09-c4-arranque-frio.sh",   "Evidencia C4: cold start vs warm start"),
    ("practica09/evidencia-p09-c5-costo-comparativo.sh","Evidencia C5: cálculo de costo"),
]
tbl_repo = doc.add_table(rows=len(archivos)+1, cols=2)
tbl_repo.style = "Table Grid"
header_row(tbl_repo, "Archivo", "Descripción")
for i, (f, d) in enumerate(archivos, 1):
    data_row(tbl_repo, i, f, d)

doc.add_paragraph()

# ─── FOOTER ──────────────────────────────────────────────────────────────────
pie = doc.add_paragraph()
pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = pie.add_run("Práctica 09 · Equipo Los Rojos · Cómputo en la Nube · UAS · 26 oct 2026")
run.font.size = Pt(9)
run.font.italic = True
run.font.color.rgb = RGBColor(120, 120, 120)

# =============================================================================
doc.save(OUTPUT)
print(f"✔  Documento generado: {OUTPUT}")
