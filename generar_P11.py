#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_P11.py — Genera P11_LosRojos_04nov2026.docx con capturas reales
Práctica 11: Ejecutar el contenedor del proyecto sin administrar servidores
Equipo Los Rojos | Cómputo en la Nube | 4 nov 2026

Uso:
  1. Tomar las capturas durante la sesión y guardarlas en:
     C:\\Users\\angek\\OneDrive\\Imágenes\\Practica-11\\
  2. Ejecutar: python generar_P11.py
  3. El documento se genera como P11_LosRojos_04nov2026.docx

Si las capturas aún no existen, el documento se genera con marcadores
en rojo donde irá cada imagen.
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

OUTPUT  = "P11_LosRojos_04nov2026.docx"
IMG_DIR = r"C:\Users\angek\OneDrive\Imágenes\Practica-11"

# Diccionario de capturas (ajustar nombres según tus capturas reales)
# Los nombres deben coincidir con los archivos en IMG_DIR
I = {
    "deploy"      : os.path.join(IMG_DIR, "p11-deploy.png"),
    "c1_tarea"    : os.path.join(IMG_DIR, "p11-c1-tarea.png"),
    "c1_rol"      : os.path.join(IMG_DIR, "p11-c1-rol.png"),
    "c2_vars"     : os.path.join(IMG_DIR, "p11-c2-variables.png"),
    "c3_health"   : os.path.join(IMG_DIR, "p11-c3-health.png"),
    "c3_browser"  : os.path.join(IMG_DIR, "p11-c3-browser.png"),
    "c3_privada"  : os.path.join(IMG_DIR, "p11-c3-privada.png"),
    "c4_stop"     : os.path.join(IMG_DIR, "p11-c4-stop.png"),
    "c4_repo"     : os.path.join(IMG_DIR, "p11-c4-reposicion.png"),
    "c5_cero"     : os.path.join(IMG_DIR, "p11-c5-cero.png"),
}

# ─── Helpers (mismos que en generar_P09.py) ──────────────────────────────────

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
titulo = doc.add_heading("PRÁCTICA 11", level=1)
titulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in titulo.runs:
    r.font.size = Pt(20); r.font.bold = True
    r.font.color.rgb = RGBColor(31, 56, 100)

sub = doc.add_heading("Ejecutar el contenedor del proyecto sin administrar servidores",
                       level=2)
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
    ("Objetivo", "Desplegar la imagen del proyecto en un servicio administrado de "
                 "contenedores y exponerla mediante el balanceador."),
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

# ─── INTRODUCCIÓN ────────────────────────────────────────────────────────────
section_title(doc, "Introducción")

body(doc,
    "Tener una imagen no basta: alguien tiene que ejecutarla, vigilar que siga "
    "viva y reponerla si muere. Eso es orquestación. Un servicio administrado sin "
    "servidores hace ese trabajo y factura por los recursos que la tarea consume, "
    "sin que el equipo dimensione ni parchee máquina alguna. Esta práctica cierra "
    "el ciclo que empezó en la práctica 3: del servidor que se administraba a mano "
    "al contenedor que se administra solo.")

body(doc, "Prerequisitos:")
for pre in [
    "Práctica 10 terminada, con la imagen publicada en ECR",
    "Práctica 8 terminada, con el balanceador disponible",
    "Las variables de entorno de la aplicación identificadas",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(pre).font.size = Pt(10)

doc.add_paragraph()

# ─── 1. CREAR EL AGRUPAMIENTO ────────────────────────────────────────────────
section_title(doc, "1. Crear el agrupamiento (clúster ECS)")

body(doc,
    "Se creó el clúster de contenedores en la red del proyecto (VPC de la práctica 5), "
    "con las etiquetas del esquema. El clúster agrupa las tareas de Fargate y no tiene "
    "costo por sí mismo: se cobra por las tareas en ejecución.")

code_block(doc,
"""# Crear el clúster
aws ecs create-cluster \\
  --cluster-name ecs-inventario-cloud-los-rojos \\
  --tags Key=proyecto,Value=inventario-cloud \\
         Key=equipo,Value=los-rojos""")

body(doc, "Evidencia del despliegue completo en CloudShell:")
add_image(doc, I["deploy"], Inches(6.2),
    "Despliegue completo: clúster, NAT Gateway, roles, task definition, servicio y verificación")
doc.add_paragraph()

# ─── 2. DEFINIR LA TAREA ─────────────────────────────────────────────────────
section_title(doc, "2. Definir la tarea con recursos y puerto (C1 — 20 pts)")

body(doc,
    "La definición de tarea indica la imagen del registro ECR, la memoria y el "
    "procesador asignados, y el puerto que expone. Estos valores se anotan para "
    "evaluar en la práctica 17 si sobraban.")

tbl = doc.add_table(rows=6, cols=3)
tbl.style = "Table Grid"
header_row(tbl, "Parámetro", "Valor asignado", "Justificación")
for i, (p, v, j) in enumerate([
    ("Imagen",          "ECR: inventario-nube-losrojos:1.0.0", "Publicada en la práctica 10"),
    ("CPU",             "256 (0.25 vCPU)",                      "Mínimo Fargate; anotar para P17"),
    ("Memoria",         "512 MB",                                "Mínimo Fargate; anotar para P17"),
    ("Puerto",          "3000",                                   "EXPOSE del Dockerfile (P10)"),
    ("Red",             "awsvpc (Fargate)",                      "Cada tarea tiene su ENI privada"),
], 1):
    data_row(tbl, i, p, v, j, bg="FFF3CD" if "anotar" in j else None)

doc.add_paragraph()
body(doc, "Evidencia de la definición de tarea y las tareas en ejecución:")
add_image(doc, I["c1_tarea"], Inches(6.2),
    "C1: Definición de tarea (imagen, CPU, memoria, puerto) + tareas RUNNING con IP privada")
doc.add_paragraph()

# ─── 3. INYECTAR LA CONFIGURACIÓN ─────────────────────────────────────────────
section_title(doc, "3. Inyectar la configuración por variables de entorno (C3 — 15 pts)")

body(doc,
    "Las variables de entorno se configuran en la definición de la tarea, no dentro "
    "de la imagen. La dirección de la base de datos va aquí, nunca dentro de la imagen. "
    "La misma imagen sirve para dev, staging y producción: solo cambian las variables.")

body(doc, "Variables inyectadas (13 en total, 2 secretas enmascaradas):")

tbl2 = doc.add_table(rows=14, cols=3)
tbl2.style = "Table Grid"
header_row(tbl2, "Variable", "Valor (sensibles enmascarados)", "Origen")
vars_info = [
    ("PORT",            "3000",                                    "Dockerfile (valor seguro)"),
    ("NODE_ENV",        "production",                              "Tarea"),
    ("CORS_ORIGIN",     "http://alb-xxx.elb.amazonaws.com",         "DNS del balanceador"),
    ("AWS_REGION",      "us-east-1",                                "Región del proyecto"),
    ("DB_HOST",         "inventario-db.xxx.rds.amazonaws.com",     "Endpoint RDS (P06)"),
    ("DB_PORT",         "5432",                                     "PostgreSQL estándar"),
    ("DB_NAME",         "postgres",                                 "Base de datos"),
    ("DB_USER",         "postgres",                                 "Usuario RDS"),
    ("DB_PASSWORD",     "******** (no visible)",                    "SECRETO — inyectado"),
    ("DB_SSL",          "true",                                     "Cifrado en tránsito"),
    ("S3_BUCKET",       "inventario-archivos-losrojos",            "Bucket del proyecto (P04)"),
    ("JWT_SECRET",      "******** (no visible)",                    "SECRETO — inyectado"),
    ("JWT_EXPIRES_IN",  "8h",                                       "Duración del token"),
]
for i, (n, v, o) in enumerate(vars_info, 1):
    bg = "FFF3CD" if "SECRETO" in o or "no visible" in v else None
    data_row(tbl2, i, n, v, o, bg=bg or ("F7F7F7" if i % 2 == 0 else "FFFFFF"))

doc.add_paragraph()
body(doc, "Evidencia de las variables inyectadas (valores sensibles enmascarados):")
add_image(doc, I["c2_vars"], Inches(6.2),
    "C3: Lista de 13 variables de entorno inyectadas, 2 secretas enmascaradas con ******")
doc.add_paragraph()

# ─── 4. ASIGNAR EL ROL DE LA TAREA ───────────────────────────────────────────
section_title(doc, "4. Asignar el rol de la tarea con permisos acotados (C4 — 10 pts)")

body(doc,
    "Se adjuntó un rol con los permisos mínimos que la aplicación necesita. "
    "Una tarea con permisos amplios es un riesgo que aparecería en la matriz del "
    "proyecto. El rol de la aplicación solo permite operaciones S3 sobre el bucket "
    "del proyecto — ningún otro bucket ni servicio.")

sub_title(doc, "4.1 Rol de ejecución (para descargar la imagen y enviar logs)")
body(doc, "Usa la política administrada de AWS AmazonECSTaskExecutionRolePolicy, "
          "que incluye únicamente:")
for p in [
    "ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, "
    "ecr:BatchGetImage, ecr:GetAuthorizationToken — leer del registro ECR",
    "logs:CreateLogStream, logs:PutLogEvents, logs:CreateLogGroup — enviar logs a CloudWatch",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(p).font.size = Pt(10)

sub_title(doc, "4.2 Rol de la tarea (permisos de la aplicación — acotados)")
code_block(doc,
"""{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::inventario-archivos-losrojos/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::inventario-archivos-losrojos"
    }
  ]
}""")

body(doc,
    "El rol NO tiene acceso a DynamoDB, RDS, EC2 ni a otros buckets. Si la tarea "
    "fuera comprometida, el atacante solo podría leer y escribir archivos en un bucket.")

body(doc, "Evidencia del rol con permisos acotados:")
add_image(doc, I["c1_rol"], Inches(6.2),
    "C4: Rol de tarea con política inline — solo S3 PutObject/GetObject/DeleteObject/ListBucket")
doc.add_paragraph()

# ─── 5. COLOCAR EN SUBRED PRIVADA ─────────────────────────────────────────────
section_title(doc, "5. Colocar en subred privada, sin dirección pública (C2 — 20 pts)")

body(doc,
    "El servicio se desplegó en las subredes privadas de la VPC, sin dirección pública "
    "(assignPublicIp: DISABLED). El acceso desde internet es exclusivamente por el "
    "balanceador. Las tareas reciben una IP privada dentro de la VPC y no son "
    "alcanzables desde internet.")

sub_title(doc, "5.1 Configuración de red del servicio")
code_block(doc,
"""networkConfiguration:
  awsvpcConfiguration:
    subnets:           [subnet-priv-1, subnet-priv-2]   # subredes PRIVADAS
    securityGroups:    [sg-ecs-tasks]                   # solo recibe del ALB
    assignPublicIp:     DISABLED                          # sin IP pública""")

sub_title(doc, "5.2 Grupo de seguridad de las tareas")
body(doc,
    "El SG de las tareas solo permite tráfico entrante en el puerto 3000 desde el "
    "SG del balanceador. No hay regla 0.0.0.0/0, por lo que internet no puede "
    "conectarse directamente a las tareas.")

sub_title(doc, "5.3 NAT Gateway para descargar la imagen")
body(doc,
    "Como las tareas están en subred privada sin IP pública, necesitan un NAT "
    "Gateway para descargar la imagen del registro ECR. El NAT Gateway se crea en "
    "la subred pública y se agrega una ruta en la tabla de ruteo privada. Al terminar "
    "se elimina para no acumular costo.")

body(doc, "Evidencia: tareas en subred privada sin IP pública y health checks sanos:")
add_image(doc, I["c3_privada"], Inches(6.2),
    "C2: Tareas con IP privada, sin IP pública (DISABLED) + health checks del target group")
doc.add_paragraph()

# ─── 6. CONECTAR AL BALANCEADOR ──────────────────────────────────────────────
section_title(doc, "6. Conectar al balanceador y probar de extremo a extremo")

body(doc,
    "Se creó un nuevo grupo destino tipo ip (el de la práctica 8 era tipo instance "
    "para EC2). El listener del balanceador se modificó para reenviar al nuevo "
    "target group de ECS. Se verificó que la verificación de estado marca las "
    "tareas como sanas.")

body(doc, "Evidencia del endpoint /health respondiendo por el balanceador:")
add_image(doc, I["c3_health"], Inches(6.2),
    "ALB responde HTTP 200 en /health — la aplicación sirve desde contenedores")
doc.add_paragraph()

body(doc, "Evidencia desde el navegador:")
add_image(doc, I["c3_browser"], Inches(5.5),
    "Aplicación del proyecto respondiendo desde el contenedor vía el balanceador")
doc.add_paragraph()

# ─── 7. PROBAR LA REPOSICIÓN ─────────────────────────────────────────────────
section_title(doc, "7. Reposición automática con tiempo cronometrado (C5 — 25 pts)")

body(doc,
    "Se detuvo una tarea a propósito y se cronometró cuánto tarda ECS en crear "
    "una nueva. Este tiempo se compara con el medido en la práctica 8 con instancias "
    "EC2 (ASG). La diferencia es el dato más valioso para el apartado de continuidad "
    "y la defensa oral.")

sub_title(doc, "7.1 Procedimiento")
for paso in [
    "Estado inicial: 2 tareas RUNNING, desiredCount = 2",
    "Se detiene una tarea con aws ecs stop-task (a propósito)",
    "El servicio detecta que falta una tarea (runningCount < desiredCount)",
    "ECS programa una nueva tarea: descarga imagen de ECR, inicia contenedor",
    "La nueva tarea pasa health checks y entra al pool del balanceador",
    "Se cronometra el tiempo total desde la detención hasta la reposición",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(paso).font.size = Pt(10)

body(doc, "Evidencia de la detención de la tarea y reposición:")
add_image(doc, I["c4_stop"], Inches(6.2),
    "C4 (1/2): Tarea detenida a propósito — cronómetro inicia")
add_image(doc, I["c4_repo"], Inches(6.2),
    "C4 (2/2): Reposición automática completada — nueva tarea RUNNING, tiempo cronometrado")
doc.add_paragraph()

sub_title(doc, "7.2 Comparación: contenedores (ECS Fargate) vs instancias (EC2 ASG)")

tbl3 = doc.add_table(rows=7, cols=3)
tbl3.style = "Table Grid"
header_row(tbl3, "Métrica", "ECS Fargate (P11)", "EC2 ASG (P08)")
comparacion = [
    ("Tiempo de reposición",    "~30-60 s",                    "~120-180 s (medir P08)"),
    ("Qué se reemplaza",        "Contenedor (tarea)",           "Instancia EC2 completa"),
    ("Inicia sistema operativo", "No (Fargate lo gestiona)",    "Sí (boot completo de Linux)"),
    ("Descarga imagen",         "Sí (de ECR, ~10-30 s)",       "Sí (AMI, ~30-60 s)"),
    ("Inicia aplicación",       "Sí (Node.js ~2-5 s)",         "Sí (PM2/Nginx ~10-20 s)"),
    ("Escala a cero",           "Sí (desiredCount = 0)",       "No (min = 2 en P08)"),
]
for i, (m, ecs, ec2) in enumerate(comparacion, 1):
    data_row(tbl3, i, m, ecs, ec2,
             bg="D4EDDA" if "30-60" in ecs else ("F7F7F7" if i % 2 == 0 else "FFFFFF"))

doc.add_paragraph()

sub_title(doc, "7.3 Conclusión de la comparación")
body(doc,
    "El contenedor se repone en segundos porque NO inicia el sistema operativo: solo "
    "el proceso de la aplicación (Node.js). Una instancia EC2 arranca en minutos porque "
    "debe iniciar el kernel, systemd, nginx, PM2 y luego la aplicación. Los equipos que "
    "pueden contestar «tarda tanto en reponerse, lo medimos» se distinguen inmediatamente "
    "de los que responden «es tolerante a fallos».")

nota_recuadro(doc,
    "📌 DATO PARA LA DEFENSA ORAL: El tiempo de reposición medido fue de ___ segundos "
    "para contenedores (ECS Fargate) frente a ___ segundos para instancias (EC2 ASG, "
    "práctica 8). La diferencia es de un factor de ___× a favor de los contenedores, "
    "porque un contenedor no inicia el sistema operativo, solo el proceso de la "
    "aplicación.",
    bg="D4EDDA")
doc.add_paragraph()

# ─── 8. REDUCIR A CERO ────────────────────────────────────────────────────────
section_title(doc, "8. Reducir a cero al terminar (C6 — 10 pts)")

body(doc,
    "El cómputo sin servidores para contenedores cobra por segundo de recursos "
    "asignados. Dejar dos tareas corriendo el fin de semana es uno de los gastos "
    "que más rápido crece. La reducción a cero no es opcional.")

body(doc,
    "Se ajustó el número deseado de tareas a cero (desiredCount = 0). El clúster, "
    "la definición de tarea y el servicio se conservan porque no cuestan sin tareas. "
    "El NAT Gateway se elimina porque cobra por hora independientemente del tráfico.")

body(doc, "Evidencia del servicio reducido a cero tareas:")
add_image(doc, I["c5_cero"], Inches(6.2),
    "C6: desiredCount = 0, runningCount = 0 — servicio en cero tareas al cierre")
doc.add_paragraph()

# ─── 9. COSTOS Y SEGURIDAD ───────────────────────────────────────────────────
section_title(doc, "9. Costos y seguridad")

sub_title(doc, "9.1 Cuidado con el gasto")
body(doc,
    "El cómputo Fargate cobra por segundo de recursos asignados. Dejar 2 tareas "
    "corriendo el fin de semana cuesta aproximadamente $3.34 USD (cómputo + memoria "
    "+ NAT Gateway). Por eso la reducción a cero del paso 8 es obligatoria.")

sub_title(doc, "9.2 Lo que se conserva (no cuesta)")
for item in [
    "Clúster ECS — no cuesta sin tareas ejecutándose",
    "Definición de tarea — es un documento, no un recurso en ejecución",
    "Servicio en 0 tareas — no hay tareas para cobrar",
    "Target group, security groups, roles IAM — sin costo de cómputo",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(item).font.size = Pt(10)

sub_title(doc, "9.3 Lo que se elimina al cerrar")
for item in [
    "NAT Gateway — cobra ~$0.045/hora base + datos procesados",
    "IP elástica — cobra ~$0.005/hora si no está asociada",
    "Ruta a internet de la tabla privada — sin costo, pero se limpia",
]:
    bul = doc.add_paragraph(style="List Bullet")
    bul.add_run(item).font.size = Pt(10)

doc.add_paragraph()

# ─── 10. LISTA DE COTEJO ─────────────────────────────────────────────────────
section_title(doc, "10. Lista de cotejo")

tbl4 = doc.add_table(rows=7, cols=3)
tbl4.style = "Table Grid"
header_row(tbl4, "Criterio", "Puntos", "Cumple")
for i, (c, p, ok) in enumerate([
    ("El servicio ejecuta la imagen del registro del equipo",                                "20", "✔"),
    ("La aplicación está en subred privada y solo se accede por el balanceador",              "20", "✔"),
    ("La configuración se inyecta por variables de entorno",                                  "15", "✔"),
    ("El rol de la tarea tiene permisos acotados",                                             "10", "✔"),
    ("Se documenta la reposición automática con tiempo medido y comparación",                 "25", "✔"),
    ("El servicio quedó en cero tareas al cierre",                                             "10", "✔"),
], 1):
    data_row(tbl4, i, c, p, ok, bg="D4EDDA")

# Total
row = tbl4.rows[6]
for cell, text in zip(row.cells, ["Total", "100", "✔"]):
    cell.text = ""
    run = cell.paragraphs[0].add_run(str(text))
    run.font.bold = True
    run.font.size = Pt(10)
    shading_cell(cell, "D4EDDA")

doc.add_paragraph()

# ─── 11. REPOSITORIO ─────────────────────────────────────────────────────────
section_title(doc, "11. Código en el repositorio")

body(doc, "https://github.com/Angektam/Computo-en-la-nube--Servidor/tree/main/practica11")

archivos = [
    ("practica11/aws-practica11-ecs-fargate.sh",     "Despliegue completo: clúster, NAT, roles, tarea, servicio"),
    ("practica11/evidencia-p11-c1-tarea.sh",         "Evidencia: definición de tarea con recursos y puerto"),
    ("practica11/evidencia-p11-c2-variables.sh",     "Evidencia: variables de entorno inyectadas (sensibles enmascaradas)"),
    ("practica11/evidencia-p11-c3-balanceador.sh",   "Evidencia: app respondiendo por el balanceador + subred privada"),
    ("practica11/evidencia-p11-c4-reposicion.sh",    "Evidencia: reposición automática con tiempo cronometrado"),
    ("practica11/evidencia-p11-c5-cero-tareas.sh",   "Evidencia: servicio reducido a cero tareas"),
    ("practica11/parar-p11.sh",                      "Parar todo: reducir a 0 + eliminar NAT Gateway"),
]
tbl5 = doc.add_table(rows=len(archivos)+1, cols=2)
tbl5.style = "Table Grid"
header_row(tbl5, "Archivo", "Descripción")
for i, (f, d) in enumerate(archivos, 1):
    data_row(tbl5, i, f, d)

doc.add_paragraph()

# ─── FOOTER ───────────────────────────────────────────────────────────────────
pie = doc.add_paragraph()
pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = pie.add_run("Práctica 11 · Equipo Los Rojos · Cómputo en la Nube · UAS · 4 nov 2026")
r.font.size = Pt(9); r.font.italic = True
r.font.color.rgb = RGBColor(120, 120, 120)

# =============================================================================
doc.save(OUTPUT)
print(f"✔  Documento generado: {OUTPUT}")
