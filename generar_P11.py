#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_P11.py — Genera P11_LosRojos_04nov2026.docx con capturas reales
Práctica 11: Ejecutar el contenedor del proyecto sin administrar servidores
Equipo Los Rojos | Cómputo en la Nube | 4 nov 2026
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

OUTPUT  = "P11_LosRojos_04nov2026.docx"
IMG_DIR = r"C:\Users\angek\OneDrive\Imágenes\practica-11"

# Mapeo de capturas (orden cronológico según timestamp)
I = {
    # Despliegue principal (pasos 0-3: VPC, clúster, NAT, SG)
    "deploy_1"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221336.png"),
    # Despliegue (pasos 3-4: SG ECS creado, RDS autorizado)
    "deploy_2"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221350.png"),
    # Despliegue (pasos 5-8: roles, variables, task definition, TG)
    "deploy_3"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221402.png"),
    # Despliegue (paso 8: variables cargadas + task definition)
    "deploy_4"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221414.png"),
    # Despliegue (pasos 9-13: TG, ALB, servicio creado, tareas arrancando)
    "deploy_5"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221425.png"),
    # Resumen final del despliegue (clúster, tarea, servicio, balanceador)
    "deploy_6"   : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221438.png"),
    # Fix SSL: registrar nueva revisión con DB_SSL_REJECT_UNAUTHORIZED
    "fix_ssl"    : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 221659.png"),
    # psql SELECT 1 → conexión RDS confirmada
    "rds_ok"     : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 222928.png"),

    # Evidencia C1 (tarea): definición, rol ejecución, rol tarea (parte 1)
    "c1_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 224912.png"),
    # Evidencia C1: rol tarea política inline + servicio + tareas RUNNING
    "c1_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 224922.png"),
    # Evidencia C1: tareas RUNNING con IP privada + resumen recursos
    "c1_p3"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 224932.png"),
    # Evidencia C1: resumen CPU/memoria/puerto
    "c1_p4"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 224951.png"),

    # Evidencia C2 (variables): tabla completa con sensibles enmascarados
    "c2_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225054.png"),
    # Evidencia C2: verificación Dockerfile + tipos de variables
    "c2_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225101.png"),
    # Evidencia C2: tipos de variables y su origen (parte 2)
    "c2_p3"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225156.png"),
    # Evidencia C2: total 13 variables
    "c2_p4"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225205.png"),

    # Evidencia C3 (balanceador): HTTP 200 + {"status":"ok","db":"ok"}
    "c3_health"  : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225217.png"),
    # Evidencia C3: URL + health check 200 + error TG (nombre largo)
    "c3_alb"     : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225246.png"),
    # Evidencia C3: health check target group y SG privado
    "c3_sg"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225253.png"),
    # Evidencia C3: curl final HTTP 200 {"status":"ok"}
    "c3_ok"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225313.png"),

    # Evidencia C4 (reposición): estado inicial + detener tarea + cronómetro
    "c4_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225412.png"),
    # Evidencia C4: tiempo 12 s + estado después + tabla comparativa ECS vs EC2
    "c4_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225429.png"),
    # Evidencia C4: tabla comparativa completa + conclusión
    "c4_p3"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225439.png"),

    # Evidencia C5 (cero tareas): antes/reducir/después
    "c5_p1"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225533.png"),
    # Evidencia C5: confirmación 0 tareas + costo recordatorio
    "c5_p2"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225540.png"),

    # parar-p11.sh: eliminar NAT Gateway + resumen
    "parar"      : os.path.join(IMG_DIR, "Captura de pantalla 2026-11-04 225747.png"),
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

def add_image(doc, path, width=Inches(6.0), caption_text=None):
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
        cap.paragraph_format.space_after = Pt(6)


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
titulo = doc.add_heading("PRÁCTICA 11", level=1)
titulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in titulo.runs:
    r.font.size = Pt(20); r.font.bold = True
    r.font.color.rgb = RGBColor(31, 56, 100)

sub = doc.add_heading("Ejecutar el contenedor del proyecto sin administrar servidores", level=2)
sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in sub.runs:
    r.font.size = Pt(14); r.font.bold = False
    r.font.color.rgb = RGBColor(60, 60, 60)

doc.add_paragraph()
meta = doc.add_table(rows=5, cols=2)
meta.style = "Table Grid"
for i, (k, v) in enumerate([
    ("Equipo",   "Los Rojos"),
    ("Materia",  "Cómputo en la Nube"),
    ("Unidad",   "Unidad II · Segundo parcial"),
    ("Sesión",   "Miércoles 4 de noviembre de 2026"),
    ("Objetivo", "Desplegar la imagen del proyecto en ECS Fargate y exponerla "
                 "mediante el balanceador de carga."),
]):
    meta.cell(i, 0).text = k
    meta.cell(i, 1).text = v
    for p in meta.cell(i, 0).paragraphs:
        for r in p.runs:
            r.font.bold = True
            r.font.color.rgb = RGBColor(255, 255, 255)
            r.font.size = Pt(10)
    shading_cell(meta.cell(i, 0), "1F3864")
    for p in meta.cell(i, 1).paragraphs:
        for r in p.runs:
            r.font.size = Pt(10)

doc.add_paragraph()
doc.add_page_break()

# ─── INTRODUCCIÓN ────────────────────────────────────────────────────────────
section_title(doc, "Introducción")
body(doc,
    "Tener una imagen no basta: alguien tiene que ejecutarla, vigilar que siga "
    "viva y reponerla si muere. Un servicio administrado sin servidores hace ese "
    "trabajo y factura por los recursos que la tarea consume, sin que el equipo "
    "dimensione ni parchee máquina alguna. Esta práctica cierra el ciclo iniciado "
    "en la práctica 3: del servidor administrado a mano al contenedor que se "
    "administra solo.")
doc.add_paragraph()

# ─── 1. DESPLIEGUE COMPLETO ───────────────────────────────────────────────────
section_title(doc, "1. Despliegue completo del servicio ECS Fargate")

body(doc,
    "El script aws-practica11-ecs-fargate.sh ejecutó 13 pasos automáticos: "
    "recuperar recursos existentes, crear el clúster, NAT Gateway, security groups, "
    "roles IAM, task definition, target group, conectar el ALB y lanzar el servicio "
    "en subredes privadas.")

add_image(doc, I["deploy_1"], Inches(6.2),
    "Pasos 0-3: recuperación de recursos (VPC, subredes, ALB, RDS, ECR) + "
    "clúster creado + NAT Gateway + SG ECS")
add_image(doc, I["deploy_2"], Inches(6.2),
    "Pasos 3-4: SG ECS creado (puerto 3000 solo desde ALB) + "
    "RDS autorizado para recibir de las tareas ECS")
add_image(doc, I["deploy_3"], Inches(6.2),
    "Pasos 5-8: roles IAM creados + variables de entorno cargadas + "
    "task definition registrada (imagen ECR, CPU 256, memoria 512, puerto 3000)")
add_image(doc, I["deploy_4"], Inches(6.2),
    "Paso 8 ampliado: variables sensibles enmascaradas, DB_HOST inyectado, "
    "target group tipo ip y ALB conectado al servicio ECS")
add_image(doc, I["deploy_5"], Inches(6.2),
    "Pasos 9-13: target group creado, listener modificado, ASG reducido a 0, "
    "servicio Fargate creado en subredes privadas, tareas arrancando (2/2)")
add_image(doc, I["deploy_6"], Inches(6.2),
    "Resumen final del despliegue: clúster, task definition rev 2, "
    "servicio FARGATE con 2 tareas deseadas en subredes privadas, DNS del ALB")

doc.add_paragraph()

# Nota sobre el fix SSL
sub_title(doc, "1.1 Ajuste de configuración: certificado SSL de RDS")
body(doc,
    "Durante el despliegue se detectó que RDS usa un certificado SSL auto-firmado "
    "en cadena. Se agregó la variable DB_SSL_REJECT_UNAUTHORIZED=false a la "
    "task definition (revisión 3) y se actualizó el servicio. Adicionalmente, "
    "se incrementó la memoria a 1024 MB (revisión 7) al detectar que Node.js "
    "necesitaba más que los 512 MB iniciales para arrancar correctamente.")
add_image(doc, I["fix_ssl"], Inches(6.0),
    "Registro de nueva revisión de task definition con DB_SSL_REJECT_UNAUTHORIZED=false")
add_image(doc, I["rds_ok"], Inches(5.5),
    "Verificación de conexión a RDS: psql SELECT 1 responde correctamente")
doc.add_paragraph()

# ─── 2. DEFINICIÓN DE LA TAREA ────────────────────────────────────────────────
section_title(doc, "2. Definición de la tarea con recursos y puerto (C1 — 20 pts)")

body(doc,
    "La definición de tarea especifica la imagen del registro ECR, los recursos "
    "de cómputo asignados y el puerto expuesto. Estos valores se anotan para "
    "evaluar en la práctica 17 si sobraban o eran insuficientes.")

tbl = doc.add_table(rows=6, cols=3)
tbl.style = "Table Grid"
header_row(tbl, "Parámetro", "Valor", "Justificación")
for i, (p, v, j) in enumerate([
    ("Imagen",   "935710521154.dkr.ecr.us-east-1.amazonaws.com/inventario-nube-losrojos:1.0.0",
                 "Publicada en ECR (práctica 10)"),
    ("CPU",      "256 (0.25 vCPU)",   "Mínimo Fargate — anotar para P17"),
    ("Memoria",  "1024 MB",            "Ajustado de 512 a 1024 MB (Node necesitaba más)"),
    ("Puerto",   "3000",               "EXPOSE del Dockerfile (práctica 10)"),
    ("Red",      "awsvpc (Fargate)",   "Cada tarea recibe su propia ENI privada"),
], 1):
    bg = "FFF3CD" if "P17" in j else None
    data_row(tbl, i, p, v, j, bg=bg or ("F7F7F7" if i % 2 == 0 else "FFFFFF"))

doc.add_paragraph()
add_image(doc, I["c1_p1"], Inches(6.2),
    "C1 (1/4): DescribeTaskDefinition — imagen ECR, CPU 256, memoria 1024, "
    "puerto 3000, red awsvpc, revisión 7 + rol de ejecución AmazonECSTaskExecutionRolePolicy")
add_image(doc, I["c1_p2"], Inches(6.2),
    "C1 (2/4): Rol de tarea con política inline pol-s3-minimo-los-rojos "
    "(solo PutObject/GetObject/DeleteObject/ListBucket sobre el bucket del proyecto) + "
    "servicio ACTIVE con 2 tareas corriendo")
add_image(doc, I["c1_p3"], Inches(6.2),
    "C1 (3/4): Dos tareas RUNNING con IP privada (10.0.2.239 y 10.0.2.16), "
    "imagen ECR confirmada en ambas tareas")
add_image(doc, I["c1_p4"], Inches(5.5),
    "C1 (4/4): Resumen de recursos asignados — CPU 256 (0.25 vCPU), "
    "memoria 512 MB, puerto 3000, NAT Gateway activo para descarga de ECR")
doc.add_paragraph()

# ─── 3. VARIABLES DE ENTORNO ──────────────────────────────────────────────────
section_title(doc, "3. Configuración inyectada por variables de entorno (C3 — 15 pts)")

body(doc,
    "Las 13 variables de entorno se configuran en la definición de tarea, no "
    "dentro de la imagen. La dirección de la base de datos va aquí, nunca en la "
    "imagen. Los valores sensibles (DB_PASSWORD y JWT_SECRET) no son visibles en "
    "ninguna captura.")

tbl2 = doc.add_table(rows=14, cols=3)
tbl2.style = "Table Grid"
header_row(tbl2, "Variable", "Valor (sensibles enmascarados)", "Tipo")
vars_list = [
    ("S3_BUCKET",                 "inventario-archivos-losrojos",                    "nombre bucket"),
    ("AWS_REGION",                "us-east-1",                                        "config"),
    ("PORT",                      "3000",                                              "config"),
    ("DB_PORT",                   "5432",                                              "config"),
    ("DB_USER",                   "postgres",                                          "no sensible"),
    ("DB_NAME",                   "postgres",                                          "no sensible"),
    ("JWT_EXPIRES_IN",            "8h",                                                "config"),
    ("DB_HOST",                   "rds-inventario-cloud-los-rojos.xxx.rds.amazonaws.com","endpoint RDS"),
    ("DB_SSL_REJECT_UNAUTHORIZED","false",                                             "config"),
    ("CORS_ORIGIN",               "http://alb-inventario-cloud-los-rojos-xxx.elb.amazonaws.com","config"),
    ("DB_SSL",                    "true",                                              "config"),
    ("JWT_SECRET",                "******** (no visible)",                             "SECRETO"),
    ("DB_PASSWORD",               "******** (no visible)",                             "SECRETO"),
]
for i, (n, v, t) in enumerate(vars_list, 1):
    bg = "FFF3CD" if t == "SECRETO" else ("D4EDDA" if t == "endpoint RDS" else None)
    data_row(tbl2, i, n, v, t, bg=bg or ("F7F7F7" if i % 2 == 0 else "FFFFFF"))

doc.add_paragraph()
add_image(doc, I["c2_p1"], Inches(6.2),
    "C3 (1/4): Tabla completa de 13 variables inyectadas — "
    "DB_PASSWORD y JWT_SECRET enmascarados con ********")
add_image(doc, I["c2_p2"], Inches(5.5),
    "C3 (2/4): Verificación — el Dockerfile NO contiene DB_HOST, DB_PASSWORD "
    "ni JWT_SECRET (verificado en práctica 10, criterio C5)")
add_image(doc, I["c2_p3"], Inches(6.2),
    "C3 (3/4): Tipos de variables y su origen — DB_HOST va en la tarea, "
    "no en la imagen; la misma imagen sirve para dev, staging y producción")
add_image(doc, I["c2_p4"], Inches(6.2),
    "C3 (4/4): Total 13 variables de entorno inyectadas, 2 secretas enmascaradas")
doc.add_paragraph()

# ─── 4. ROL DE LA TAREA ────────────────────────────────────────────────────────
section_title(doc, "4. Rol de la tarea con permisos acotados (C4 — 10 pts)")

body(doc,
    "Se adjuntaron dos roles distintos a la tarea:")

sub_title(doc, "4.1 Rol de ejecución (para el agente ECS)")
body(doc,
    "rol-ecs-exec-los-rojos usa la política administrada "
    "AmazonECSTaskExecutionRolePolicy, que permite únicamente leer imágenes de ECR "
    "y enviar logs a CloudWatch. Sin este rol, las tareas no pueden descargar la "
    "imagen del registro.")

sub_title(doc, "4.2 Rol de la tarea (para la aplicación)")
body(doc,
    "rol-ecs-task-los-rojos tiene una política inline pol-s3-minimo-los-rojos "
    "con permisos mínimos: solo s3:PutObject, s3:GetObject, s3:DeleteObject y "
    "s3:ListBucket sobre el bucket inventario-archivos-losrojos. "
    "No puede escribir ni leer en ningún otro bucket ni servicio.")

code_block(doc,
"""{
  "Effect": "Allow",
  "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
  "Resource": "arn:aws:s3:::inventario-archivos-losrojos/*"
},
{
  "Effect": "Allow",
  "Action": ["s3:ListBucket"],
  "Resource": "arn:aws:s3:::inventario-archivos-losrojos"
}""")

nota_recuadro(doc,
    "SEGURIDAD: Una tarea con permisos amplios (ej. AdministratorAccess o S3FullAccess) "
    "es un riesgo que aparecería en la matriz del proyecto. Si la tarea fuera comprometida, "
    "el atacante solo podría leer y escribir archivos en un bucket específico.",
    bg="F8D7DA")
doc.add_paragraph()

# ─── 5. SUBRED PRIVADA Y BALANCEADOR ──────────────────────────────────────────
section_title(doc, "5. Subred privada + balanceador (C2 — 20 pts)")

body(doc,
    "El servicio se desplegó en las subredes privadas de la VPC con "
    "assignPublicIp: DISABLED. El único acceso desde internet es a través del "
    "balanceador. Las tareas tienen IP privada y no son alcanzables directamente.")

tbl3 = doc.add_table(rows=5, cols=2)
tbl3.style = "Table Grid"
header_row(tbl3, "Configuración", "Valor")
for i, (k, v) in enumerate([
    ("Subredes",        "subnet-0b6549d5a7ccc669f (priv-1) + subnet-0aaa291c3653ab724 (priv-2)"),
    ("IP pública",      "DISABLED — sin dirección pública"),
    ("SG de las tareas","sg-01ee91ee9d619b538 — puerto 3000 solo desde SG del ALB"),
    ("Target group",    "tg-ecs-los-rojos — tipo ip (no instance), health GET /health"),
], 1):
    data_row(tbl3, i, k, v)

doc.add_paragraph()
add_image(doc, I["c3_alb"], Inches(6.2),
    "C2 (1/3): URL del balanceador + health check HTTP 200 + "
    "respuesta {status:ok, db:ok} desde el contenedor")
add_image(doc, I["c3_health"], Inches(6.2),
    "C2 (2/3): Endpoint /health respondiendo HTTP 200 con status:ok y db:ok — "
    "la aplicación sirve desde los contenedores Fargate")
add_image(doc, I["c3_sg"], Inches(6.2),
    "C2 (3/3): SG de las tareas — solo puerto 3000 desde el SG del ALB, "
    "sin regla 0.0.0.0/0; internet no puede conectarse directamente")
add_image(doc, I["c3_ok"], Inches(6.2),
    "Confirmación final: curl al ALB retorna {status:ok, db:ok} — "
    "la base de datos responde correctamente desde el contenedor")
doc.add_paragraph()

# ─── 6. REPOSICIÓN AUTOMÁTICA ─────────────────────────────────────────────────
section_title(doc, "6. Reposición automática con tiempo cronometrado (C5 — 25 pts)")

body(doc,
    "Se detuvo una tarea a propósito con aws ecs stop-task y se cronometró el tiempo "
    "hasta que ECS repuso una nueva. El resultado se compara con el tiempo medido "
    "en la práctica 8 con instancias EC2.")

add_image(doc, I["c4_p1"], Inches(6.0),
    "C5 (1/3): Estado inicial (3 tareas RUNNING) + tarea detenida a propósito "
    "+ cronómetro iniciado a las 05:53:29")
add_image(doc, I["c4_p2"], Inches(5.5),
    "C5 (2/3): Reposición completada en 12 segundos (05:53:29 → 05:53:41) — "
    "estado después: 2 tareas RUNNING + tabla comparativa ECS vs EC2")
add_image(doc, I["c4_p3"], Inches(5.5),
    "C5 (3/3): Tabla comparativa completa + conclusión: el contenedor se repone "
    "en 12 s frente a los ~120-180 s de una instancia EC2 (factor ~10-15x)")

doc.add_paragraph()

tbl4 = doc.add_table(rows=7, cols=3)
tbl4.style = "Table Grid"
header_row(tbl4, "Métrica", "ECS Fargate (P11)", "EC2 ASG (P08)")
comparacion = [
    ("Tiempo de reposición",     "12 segundos",              "~120-180 s (arranque del SO)"),
    ("Que se reemplaza",         "Contenedor (tarea)",        "Instancia EC2 completa"),
    ("Inicia sistema operativo", "No (Fargate lo gestiona)",  "Si (boot completo de Linux)"),
    ("Descarga imagen",          "Si (de ECR, ~5-10 s)",     "Si (AMI de EBS, ~30-60 s)"),
    ("Inicia aplicacion",        "Si (Node ~2 s)",            "Si (PM2/Nginx ~10-20 s)"),
    ("Escala a cero",            "Si (desiredCount = 0)",    "No (min = 2 en P08)"),
]
for i, (m, ecs, ec2) in enumerate(comparacion, 1):
    bg = "D4EDDA" if i == 1 else ("F7F7F7" if i % 2 == 0 else "FFFFFF")
    data_row(tbl4, i, m, ecs, ec2, bg=bg)

doc.add_paragraph()
nota_recuadro(doc,
    "DATO PARA LA DEFENSA ORAL: El contenedor se repone en 12 segundos, frente a "
    "los ~120-180 segundos que tarda una instancia EC2 (practica 8). "
    "La diferencia es de un factor de ~10-15x a favor de los contenedores, "
    "porque un contenedor no inicia el sistema operativo — solo el proceso Node.js.",
    bg="D4EDDA")
doc.add_paragraph()

# ─── 7. REDUCIR A CERO ────────────────────────────────────────────────────────
section_title(doc, "7. Servicio reducido a cero tareas al cierre (C6 — 10 pts)")

body(doc,
    "Al terminar la sesión se ajustó el desiredCount a 0 y se eliminó el NAT "
    "Gateway para no acumular consumo. El clúster, la definición de tarea y el "
    "servicio se conservan porque no cuestan sin tareas.")

add_image(doc, I["c5_p1"], Inches(6.0),
    "C6 (1/2): Estado antes (2/2 corriendo) + reduccion a desiredCount=0 "
    "+ estado despues: 0 corriendo, 0 deseadas, 0 pendientes")
add_image(doc, I["c5_p2"], Inches(5.5),
    "C6 (2/2): Confirmacion sin tareas en ejecucion + calculo de costo "
    "del fin de semana (~$3.34 USD) si se deja corriendo")
add_image(doc, I["parar"], Inches(5.5),
    "parar-p11.sh: NAT Gateway eliminado, IP elastica liberada, "
    "ruta privada quitada — resumen de lo detenido vs conservado")

doc.add_paragraph()
nota_recuadro(doc,
    "COSTO: Fargate cobra por segundo de recursos asignados. "
    "Dejar 2 tareas corriendo el fin de semana cuesta ~$3.34 USD "
    "(computo + memoria + NAT Gateway). La reduccion a cero NO es opcional.",
    bg="F8D7DA")
doc.add_paragraph()

# ─── 8. LISTA DE COTEJO ────────────────────────────────────────────────────────
section_title(doc, "8. Lista de cotejo")

tbl5 = doc.add_table(rows=7, cols=3)
tbl5.style = "Table Grid"
header_row(tbl5, "Criterio", "Puntos", "Cumple")
criterios = [
    ("El servicio ejecuta la imagen del registro del equipo",                        "20", "si"),
    ("La aplicacion esta en subred privada y solo se accede por el balanceador",     "20", "si"),
    ("La configuracion se inyecta por variables de entorno",                          "15", "si"),
    ("El rol de la tarea tiene permisos acotados",                                    "10", "si"),
    ("Se documenta la reposicion automatica con tiempo medido y comparacion",        "25", "si"),
    ("El servicio quedo en cero tareas al cierre",                                    "10", "si"),
]
for i, (c, p, ok) in enumerate(criterios, 1):
    data_row(tbl5, i, c, p, ok, bg="D4EDDA")
row = tbl5.rows[6]
for cell, text in zip(row.cells, ["Total", "100", "si"]):
    cell.text = ""
    run = cell.paragraphs[0].add_run(text)
    run.font.bold = True; run.font.size = Pt(10)
    shading_cell(cell, "D4EDDA")

doc.add_paragraph()

# ─── 9. REPOSITORIO ────────────────────────────────────────────────────────────
section_title(doc, "9. Codigo en el repositorio")
body(doc, "https://github.com/Angektam/Computo-en-la-nube--Servidor/tree/main/practica11")

archivos = [
    ("practica11/aws-practica11-ecs-fargate.sh",   "Despliegue completo (13 pasos)"),
    ("practica11/evidencia-p11-c1-tarea.sh",        "Evidencia: task definition, roles, tareas"),
    ("practica11/evidencia-p11-c2-variables.sh",    "Evidencia: variables inyectadas (sensibles enmascarados)"),
    ("practica11/evidencia-p11-c3-balanceador.sh",  "Evidencia: app respondiendo por el ALB"),
    ("practica11/evidencia-p11-c4-reposicion.sh",   "Evidencia: reposicion con tiempo cronometrado"),
    ("practica11/evidencia-p11-c5-cero-tareas.sh",  "Evidencia: servicio en 0 tareas"),
    ("practica11/parar-p11.sh",                      "Parar todo: 0 tareas + eliminar NAT Gateway"),
]
tbl6 = doc.add_table(rows=len(archivos)+1, cols=2)
tbl6.style = "Table Grid"
header_row(tbl6, "Archivo", "Descripcion")
for i, (f, d) in enumerate(archivos, 1):
    data_row(tbl6, i, f, d)

doc.add_paragraph()

# ─── FOOTER ────────────────────────────────────────────────────────────────────
pie = doc.add_paragraph()
pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = pie.add_run("Practica 11 · Equipo Los Rojos · Computo en la Nube · UAS · 4 nov 2026")
r.font.size = Pt(9); r.font.italic = True
r.font.color.rgb = RGBColor(120, 120, 120)

# =============================================================================
doc.save(OUTPUT)
print(f"Documento generado: {OUTPUT}")
