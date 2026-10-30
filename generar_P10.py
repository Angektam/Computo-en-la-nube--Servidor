#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_P10.py — Genera P10_LosRojos_29oct2026.docx con capturas reales
Práctica 10: Empaquetar la aplicación del proyecto en un contenedor
Equipo Los Rojos | Cómputo en la Nube | 29 oct 2026
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

OUTPUT  = "P10_LosRojos_29oct2026.docx"
IMG_DIR = r"C:\Users\angek\OneDrive\Imágenes\Practica-10"

# ─── Rutas de capturas ────────────────────────────────────────────────────────
# Reemplaza los nombres de archivo con los que captures durante la práctica.
I = {
    # Criterio 1 & 2 — Construcción con tamaño visible
    "c1_build"       : os.path.join(IMG_DIR, "c1_build.png"),
    "c1_size"        : os.path.join(IMG_DIR, "c1_size.png"),
    # Criterio 3 — .dockerignore y verificación
    "c3_dockerignore": os.path.join(IMG_DIR, "c3_dockerignore.png"),
    "c3_verify"      : os.path.join(IMG_DIR, "c3_verify.png"),
    # Criterio 4 — Aplicación respondiendo desde el contenedor
    "c4_run"         : os.path.join(IMG_DIR, "c4_run.png"),
    "c4_health"      : os.path.join(IMG_DIR, "c4_health.png"),
    # Criterio 5 — Imagen publicada en ECR
    "c5_ecr_repo"    : os.path.join(IMG_DIR, "c5_ecr_repo.png"),
    "c5_ecr_image"   : os.path.join(IMG_DIR, "c5_ecr_image.png"),
    # Criterio 6 — Variables de entorno
    "c6_env"         : os.path.join(IMG_DIR, "c6_env.png"),
}

# ─── Helpers (mismo patrón que P09) ──────────────────────────────────────────

def add_image(doc, path, width=Inches(6.0), caption_text=None):
    if not os.path.exists(path):
        p = doc.add_paragraph(f"[Captura pendiente: {os.path.basename(path)}]")
        p.runs[0].font.color.rgb = RGBColor(180, 0, 0)
        p.runs[0].font.italic = True
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
    shd.set(qn("w:fill"), bg)
    shd.set(qn("w:val"), "clear")
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

# ─── PORTADA ──────────────────────────────────────────────────────────────────
titulo = doc.add_heading("PRÁCTICA 10", level=1)
titulo.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in titulo.runs:
    r.font.size = Pt(20)
    r.font.bold = True
    r.font.color.rgb = RGBColor(31, 56, 100)

sub = doc.add_heading("Empaquetar la aplicación del proyecto en un contenedor", level=2)
sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
for r in sub.runs:
    r.font.size = Pt(14)
    r.font.bold = False
    r.font.color.rgb = RGBColor(60, 60, 60)

doc.add_paragraph()
meta = doc.add_table(rows=5, cols=2)
meta.style = "Table Grid"
for i, (k, v) in enumerate([
    ("Equipo",     "Los Rojos"),
    ("Materia",    "Cómputo en la Nube · Grupo 503"),
    ("Unidad",     "Unidad II · Segundo parcial"),
    ("Sesión",     "Jueves 29 de octubre de 2026"),
    ("Objetivo",   "Construir la imagen de contenedor de la aplicación del proyecto "
                   "y publicarla en un registro privado."),
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

# ─── 1. IMAGEN BASE Y JUSTIFICACIÓN (Criterio 1 — 15 pts) ────────────────────
section_title(doc, "1. Imagen base oficial y justificación (C1 — 15 pts)")

body(doc,
    "Se eligió node:20-alpine como imagen base. La siguiente tabla compara "
    "las alternativas consideradas:")

tbl1 = doc.add_table(rows=4, cols=4)
tbl1.style = "Table Grid"
header_row(tbl1, "Imagen", "Tamaño comprimido", "Ventaja", "Decisión")
data_row(tbl1, 1,
    "✔ ELEGIDA\nnode:20-alpine",
    "~55 MB",
    "Alpine Linux (~5 MB). Imagen oficial. Node 20 LTS (soporte activo). "
    "Incluye las herramientas mínimas necesarias (npm, node).",
    "USADA",
    bg="D4EDDA")
data_row(tbl1, 2,
    "✗ Descartada\nnode:20",
    "~350 MB",
    "Debian completo — herramientas de compilación y shells que no se usan "
    "en producción.",
    "Muy pesada")
data_row(tbl1, 3,
    "✗ Descartada\nubuntu:22.04 + node manual",
    "~180 MB",
    "Imagen genérica no oficial para Node. Requiere instalar Node manualmente "
    "con pasos adicionales.",
    "No oficial para Node")

doc.add_paragraph()

sub_title(doc, "1.1 Dockerfile completo comentado línea por línea")

body(doc,
    "Cada instrucción está comentada explicando su propósito, la justificación "
    "del orden y las decisiones de seguridad:")

code_block(doc,
"""# Imagen base: node:20-alpine
# Alpine Linux (~5 MB) + Node 20 LTS — oficial en Docker Hub, auditada.
# Mucho más ligera que node:20-debian (~350 MB) o ubuntu + node manual.
FROM node:20-alpine

# Directorio de trabajo dentro del contenedor.
# Docker lo crea si no existe. Todos los COPY y RUN siguientes operan aquí.
WORKDIR /app

# Copiar SOLO los manifiestos de dependencias ANTES que el código.
# Motivo: Docker cachea cada instrucción como capa. Si package.json no
# cambia, la capa de "npm ci" se reutiliza aunque el código cambie.
# → Construcciones muchísimo más rápidas en desarrollo y CI/CD.
COPY package.json package-lock.json ./

# Instalar únicamente dependencias de producción.
# "npm ci" respeta el package-lock.json exactamente (reproducibilidad).
# "--omit=dev" excluye nodemon y docx, que no se necesitan en producción.
RUN npm ci --omit=dev

# Ahora sí se copia el código fuente y el frontend.
# Al estar DESPUÉS de npm ci, cambiar código no invalida la caché de deps.
COPY src/ ./src/
COPY public/ ./public/

# Variables de entorno con valores por defecto seguros (sin secretos).
# Los secretos (DB_PASSWORD, JWT_SECRET, AWS_*) se inyectan en runtime.
ENV NODE_ENV=production \\
    PORT=3000

# Documentar el puerto expuesto (no lo publica; es documentación).
EXPOSE 3000

# Cambiar al usuario "node" (uid 1000, incluido en alpine).
# Ejecutar como root dentro del contenedor es un riesgo de seguridad.
USER node

# Comando de inicio en forma EXEC (array JSON).
# Recibe señales SIGTERM/SIGINT directamente → apagado limpio del contenedor.
# Más eficiente que "npm run start" (no crea proceso shell intermedio).
CMD ["node", "src/server.js"]""")

doc.add_paragraph()
body(doc, "Evidencia C1 — Construcción exitosa con tamaño de imagen visible:")
add_image(doc, I["c1_build"], Inches(6.2),
    "C1 (1/2): docker build — construcción paso a paso, capas en orden correcto")
add_image(doc, I["c1_size"], Inches(6.2),
    "C1 (2/2): docker images — imagen inventario-nube-losrojos:1.0.0 con tamaño visible")
doc.add_paragraph()

# ─── 2. ORDEN DE CAPAS (Criterio 2 — 15 pts) ─────────────────────────────────
section_title(doc, "2. Orden de capas correcto (C2 — 15 pts)")

body(doc,
    "El orden de instrucciones en el Dockerfile sigue la regla fundamental: "
    "lo que cambia menos frecuentemente va primero. Esto maximiza el uso "
    "de la caché de Docker y acelera las construcciones incrementales.")

tbl2 = doc.add_table(rows=7, cols=3)
tbl2.style = "Table Grid"
header_row(tbl2, "Capa", "Instrucción", "¿Por qué en ese orden?")
for i, (capa, instr, razon) in enumerate([
    ("1 — Base",         "FROM node:20-alpine",
     "Descargada una sola vez. Nunca cambia entre builds del proyecto."),
    ("2 — Workdir",      "WORKDIR /app",
     "Sin archivos propios; solo declara el directorio. Capa trivial."),
    ("3 — Manifiestos",  "COPY package.json package-lock.json ./",
     "Cambian solo cuando se agregan/eliminan dependencias (poco frecuente)."),
    ("4 — Dependencias", "RUN npm ci --omit=dev",
     "La instalación (~30 s) se cachea mientras los manifiestos no cambien. "
     "Colocarla ANTES que el código es la optimización más importante."),
    ("5 — Código",       "COPY src/ ./src/",
     "Cambia con cada commit, por eso va AL FINAL. Al estar después de npm ci, "
     "no invalida la caché de dependencias."),
    ("6 — Frontend",     "COPY public/ ./public/",
     "Similar al código; cambia frecuentemente. Va junto al código."),
    ("7 — Runtime",      "ENV / EXPOSE / USER / CMD",
     "Metadatos y configuración de ejecución. Sin impacto en el tamaño."),
], 1):
    data_row(tbl2, i, capa, instr, razon)

doc.add_paragraph()
nota_recuadro(doc,
    "⚠ SI SE INVIERTE EL ORDEN: colocar COPY src/ antes de RUN npm ci hace que "
    "cualquier cambio de código —incluso un solo carácter— invalide la caché de "
    "instalación de dependencias. La construcción tarda ~30 s adicionales cada vez. "
    "En un equipo de 4 personas que hace 10 builds al día, eso son 20 minutos "
    "de espera extra por día evitables.",
    bg="F8D7DA")
doc.add_paragraph()

# ─── 3. ARCHIVO DE EXCLUSIÓN (Criterio 3 — 15 pts) ───────────────────────────
section_title(doc, "3. Archivo .dockerignore (C3 — 15 pts)")

body(doc,
    "El archivo .dockerignore impide que Docker envíe al daemon archivos "
    "innecesarios o peligrosos al contexto de construcción. "
    "Funciona exactamente igual que .gitignore pero para docker build.")

sub_title(doc, "3.1 Contenido del .dockerignore")
code_block(doc,
"""# Credenciales — NUNCA deben entrar a la imagen
.env
.env.*
!.env.example

# Dependencias del host (se reinstalan con npm ci dentro del contenedor)
node_modules/
.venv/

# Control de versiones y configuración del editor
.git/
.gitignore
.vscode/
.kiro/

# Carpetas de prácticas anteriores (scripts AWS, no parte de la app)
practica07/
practica08/
practica09/
practica10/
deploy/

# Archivos de prueba y scripts auxiliares
test-local/
scripts/
*.sh
*.py

# Documentos entregables
*.docx
*.pdf

# Logs y temporales
logs/
*.log
uploads/
tmp/""")

doc.add_paragraph()
body(doc,
    "Evidencia C3 — .dockerignore en uso y verificación de que .env NO "
    "está dentro de la imagen:")
add_image(doc, I["c3_dockerignore"], Inches(6.2),
    "C3 (1/2): Contenido del .dockerignore — credenciales, node_modules y carpetas de práctica excluidos")
add_image(doc, I["c3_verify"], Inches(6.2),
    "C3 (2/2): Verificación — .env AUSENTE dentro de la imagen; node_modules instalados por npm ci")
doc.add_paragraph()

nota_recuadro(doc,
    "🔐 SEGURIDAD: Si .env entrara en la imagen, cualquier persona que descargue la imagen "
    "desde ECR tendría acceso a DB_PASSWORD, JWT_SECRET y AWS_SECRET_ACCESS_KEY. "
    "El .dockerignore es la primera línea de defensa contra este riesgo.",
    bg="FFF3CD")
doc.add_paragraph()

# ─── 4. APLICACIÓN RESPONDIENDO (Criterio 4 — 20 pts) ────────────────────────
section_title(doc, "4. Aplicación respondiendo desde el contenedor (C4 — 20 pts)")

body(doc,
    "Se ejecutó el contenedor mapeando el puerto 3000 del host al 3000 del "
    "contenedor e inyectando las variables de entorno desde el archivo .env. "
    "La aplicación arranca en segundos y responde correctamente en /health.")

sub_title(doc, "4.1 Comando de ejecución")
code_block(doc,
"""docker run \\
  --name inventario-p10 \\
  --detach \\
  --publish 3000:3000 \\
  --env NODE_ENV=production \\
  --env PORT=3000 \\
  --env-file .env \\
  inventario-nube-losrojos:1.0.0""")

sub_title(doc, "4.2 Verificación con /health")
body(doc,
    "El endpoint GET /health responde HTTP 200 con el estado del servidor. "
    "Esto confirma que la aplicación arrancó correctamente y escucha "
    "en el puerto mapeado.")

doc.add_paragraph()
body(doc, "Evidencia C4 — Contenedor corriendo y endpoint respondiendo:")
add_image(doc, I["c4_run"], Inches(6.2),
    "C4 (1/2): docker ps — contenedor inventario-p10 en estado Up, puerto 0.0.0.0:3000->3000/tcp")
add_image(doc, I["c4_health"], Inches(6.2),
    "C4 (2/2): curl http://localhost:3000/health — respuesta HTTP 200 desde el contenedor")
doc.add_paragraph()

nota_recuadro(doc,
    "💡 ERRORES COMUNES:\n"
    "• Contenedor arranca y muere → el proceso principal terminó; "
    "verificar con 'docker logs <nombre>' y asegurar que CMD apunta al proceso correcto.\n"
    "• La aplicación no responde → falta '--publish' o la app escucha en 127.0.0.1 "
    "dentro del contenedor. La app debe escuchar en 0.0.0.0 (Express lo hace por defecto).",
    bg="FFF3CD")
doc.add_paragraph()

# ─── 5. REGISTRO PRIVADO EN ECR (Criterio 5 — 20 pts) ────────────────────────
section_title(doc, "5. Imagen publicada en Amazon ECR (C5 — 20 pts)")

body(doc,
    "Se creó un repositorio privado en Amazon ECR con escaneo automático de "
    "vulnerabilidades activado. La imagen se publicó con las etiquetas 1.0.0 "
    "y latest.")

tbl3 = doc.add_table(rows=6, cols=2)
tbl3.style = "Table Grid"
header_row(tbl3, "Parámetro", "Valor")
data_row(tbl3, 1, "Nombre del repositorio", "inventario-nube-losrojos")
data_row(tbl3, 2, "Versión publicada",       "1.0.0")
data_row(tbl3, 3, "Etiqueta adicional",      "latest")
data_row(tbl3, 4, "Región",                  "us-east-1")
data_row(tbl3, 5, "Escaneo al publicar",     "Activado (scanOnPush=true)")

doc.add_paragraph()

sub_title(doc, "5.1 Pasos de publicación")
code_block(doc,
"""# 1. Obtener URI de la cuenta
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"

# 2. Crear repositorio privado con escaneo automático
aws ecr create-repository \\
  --repository-name inventario-nube-losrojos \\
  --image-scanning-configuration scanOnPush=true \\
  --encryption-configuration encryptionType=AES256 \\
  --tags Key=Equipo,Value=LosRojos Key=Practica,Value=P10

# 3. Autenticarse (token válido 12 horas)
aws ecr get-login-password --region us-east-1 \\
  | docker login --username AWS --password-stdin "$ECR_URI"

# 4. Etiquetar con URI completa de ECR
docker tag inventario-nube-losrojos:1.0.0 \\
  ${ECR_URI}/inventario-nube-losrojos:1.0.0

# 5. Publicar
docker push ${ECR_URI}/inventario-nube-losrojos:1.0.0
docker push ${ECR_URI}/inventario-nube-losrojos:latest""")

doc.add_paragraph()
body(doc, "Evidencia C5 — Repositorio creado e imagen publicada en ECR:")
add_image(doc, I["c5_ecr_repo"], Inches(6.2),
    "C5 (1/2): Repositorio privado inventario-nube-losrojos en Amazon ECR — escaneo activo")
add_image(doc, I["c5_ecr_image"], Inches(6.2),
    "C5 (2/2): Imagen inventario-nube-losrojos:1.0.0 publicada en ECR con tamaño y versión visibles")
doc.add_paragraph()

nota_recuadro(doc,
    "💰 COSTO: ECR cobra por almacenamiento (~$0.10/GB/mes). Una imagen Node alpine comprimida "
    "ocupa ~30-40 MB → costo < $0.005/mes. Aun así, se eliminaron las versiones de prueba "
    "del registro antes de salir de la sesión para no acumular capas.",
    bg="D4EDDA")
doc.add_paragraph()

# ─── 6. CONFIGURACIÓN PARAMETRIZADA (Criterio 6 — 15 pts) ────────────────────
section_title(doc, "6. Configuración parametrizada por variables de entorno (C6 — 15 pts)")

body(doc,
    "Toda configuración que cambia entre ambientes (base de datos, JWT, AWS, CORS) "
    "se inyecta en tiempo de ejecución mediante variables de entorno. "
    "La imagen no contiene ningún valor hardcodeado.")

sub_title(doc, "6.1 Lista completa de variables de entorno requeridas")

tbl4 = doc.add_table(rows=14, cols=3)
tbl4.style = "Table Grid"
header_row(tbl4, "Variable", "Descripción", "Ejemplo / Nota")
for i, (var, desc, ej) in enumerate([
    # Servidor
    ("PORT",                        "Puerto de escucha",                "3000"),
    ("NODE_ENV",                    "Ambiente de ejecución",            "production | development"),
    # CORS
    ("CORS_ORIGIN",                 "Dominios permitidos",              "https://mi-app.com"),
    # RDS
    ("DB_HOST",                     "Endpoint del servidor RDS",        "xxx.rds.amazonaws.com"),
    ("DB_PORT",                     "Puerto PostgreSQL",                "5432"),
    ("DB_NAME",                     "Nombre de la base de datos",       "inventario"),
    ("DB_USER",                     "Usuario de la base de datos",      "postgres"),
    ("DB_PASSWORD",                 "Contraseña RDS",                   "🔒 usar Secrets Manager"),
    ("DB_SSL",                      "Activar SSL en la conexión",       "true"),
    ("DB_SSL_REJECT_UNAUTHORIZED",  "Verificar certificado del servidor","false solo con self-signed"),
    # AWS
    ("AWS_REGION",                  "Región AWS",                       "us-east-1"),
    ("S3_BUCKET",                   "Bucket de imágenes de productos",  "inventario-archivos-losrojos"),
    # JWT
    ("JWT_SECRET",                  "Clave para firmar tokens",         "🔒 usar Secrets Manager"),
    ("JWT_EXPIRES_IN",              "Duración de sesión",               "8h"),
], 1):
    bg = "FFF3CD" if "Secrets" in ej else None
    data_row(tbl4, i, var, desc, ej, bg=bg or ("F7F7F7" if i%2==0 else "FFFFFF"))

doc.add_paragraph()
body(doc, "Evidencia C6 — Variables de entorno activas en el contenedor:")
add_image(doc, I["c6_env"], Inches(6.2),
    "C6: Variables de entorno del contenedor (sin valores de secretos) — configuración 100% externalizada")
doc.add_paragraph()

# ─── 7. PROPUESTA DE REDUCCIÓN DE TAMAÑO ─────────────────────────────────────
section_title(doc, "7. Propuesta de reducción de tamaño (Paso 9)")

body(doc,
    "Se identificaron tres estrategias para reducir el tamaño de la imagen, "
    "ordenadas de mayor a menor impacto:")

tbl5 = doc.add_table(rows=4, cols=3)
tbl5.style = "Table Grid"
header_row(tbl5, "Estrategia", "Reducción estimada", "Descripción")
data_row(tbl5, 1,
    "1. Multi-stage build",
    "~40-60 MB adicionales",
    "Etapa 'builder' instala deps y compila. Etapa 'runner' copia solo "
    "/app/node_modules y el código — descarta npm, git y herramientas de build.")
data_row(tbl5, 2,
    "2. Imagen Distroless\n(gcr.io/distroless/nodejs20)",
    "~30-40 MB adicionales",
    "Sin shell, sin apt, sin usuarios — solo el runtime de Node. "
    "Elimina superficie de ataque. Combina bien con multi-stage.")
data_row(tbl5, 3,
    "3. --omit=dev (ya implementado)",
    "~50 MB (nodemon + docx)",
    "Ya excluye las devDependencies del build final. "
    "Contribución inmediata sin rediseñar el Dockerfile.")

doc.add_paragraph()

sub_title(doc, "7.1 Ejemplo de Dockerfile multi-stage (no implementado hoy)")
code_block(doc,
"""# ── Etapa builder: solo para instalar dependencias ──────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ── Etapa runner: imagen final sin herramientas de build ─────────
FROM node:20-alpine AS runner
WORKDIR /app
# Copiar SOLO lo necesario del builder (no npm, no caché)
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY public/ ./public/
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
USER node
CMD ["node", "src/server.js"]

# Resultado esperado: imagen ~15-20% más pequeña que la versión simple""")

nota_recuadro(doc,
    "📌 CONCLUSIÓN: La imagen actual (node:20-alpine + --omit=dev) ya es razonablemente ligera. "
    "El multi-stage build es la mejora con mejor relación esfuerzo/beneficio para la "
    "siguiente iteración antes de la Práctica 11.",
    bg="D4EDDA")
doc.add_paragraph()

# ─── 8. CONEXIÓN CON EL PROYECTO ─────────────────────────────────────────────
section_title(doc, "8. Conexión con el proyecto y prácticas siguientes")

body(doc,
    "Esta imagen es la unidad de despliegue del proyecto de aquí en adelante:")

tbl6 = doc.add_table(rows=4, cols=2)
tbl6.style = "Table Grid"
header_row(tbl6, "Práctica", "Uso de esta imagen")
data_row(tbl6, 1, "P11 — Servicio administrado",
    "La imagen se ejecuta en ECS Fargate sin gestionar servidores")
data_row(tbl6, 2, "P12 — Infraestructura como código",
    "La imagen se declara en Terraform/CDK con su URI de ECR")
data_row(tbl6, 3, "P16 — Integración continua",
    "La imagen se reconstruye automáticamente en cada push al repositorio")

doc.add_paragraph()
nota_recuadro(doc,
    "📌 REPRODUCIBILIDAD (criterio de los estatutos): "
    "Gracias a la parametrización del paso 6, la misma imagen puede desplegarse "
    "en desarrollo (con .env local), en staging y en producción (con Secrets Manager) "
    "sin modificar el Dockerfile. Esto cumple el criterio de reproducibilidad "
    "exigido en la rúbrica del proyecto.",
    bg="D1ECF1")
doc.add_paragraph()

# ─── 9. LISTA DE COTEJO ───────────────────────────────────────────────────────
section_title(doc, "9. Lista de cotejo")

tbl7 = doc.add_table(rows=6, cols=3)
tbl7.style = "Table Grid"
header_row(tbl7, "Criterio", "Puntos", "Cumple")
for i, (c, p, ok) in enumerate([
    ("El archivo parte de una imagen base oficial y justificada",           "15", "✔"),
    ("El orden de capas es correcto y está explicado",                      "15", "✔"),
    ("El archivo de exclusión existe y evita copiar credenciales",          "15", "✔"),
    ("La aplicación responde desde el contenedor",                          "20", "✔"),
    ("La imagen está publicada y versionada en el registro del equipo",     "20", "✔"),
    ("La configuración está parametrizada, no incrustada",                  "15", "✔"),
], 1):
    data_row(tbl7, i, c, p, ok, bg="D4EDDA")

doc.add_paragraph()

# ─── 10. REPOSITORIO ──────────────────────────────────────────────────────────
section_title(doc, "10. Código en el repositorio")

body(doc, "https://github.com/Angektam/Computo-en-la-nube--Servidor/tree/main/practica10")

archivos = [
    ("Dockerfile",                               "Archivo de definición de la imagen (comentado línea por línea)"),
    (".dockerignore",                            "Exclusiones del contexto de construcción (credenciales, node_modules, etc.)"),
    ("practica10/aws-practica10-docker.sh",      "Script principal: build + run local + ECR"),
    ("practica10/evidencia-p10-c1-construir.sh", "Evidencia C1 y C2 — construcción y tamaño"),
    ("practica10/evidencia-p10-c2-ejecutar.sh",  "Evidencia C4 — app respondiendo desde el contenedor"),
    ("practica10/evidencia-p10-c3-dockerignore.sh","Evidencia C3 — .dockerignore correcto"),
    ("practica10/evidencia-p10-c4-ecr-publicar.sh","Evidencia C5 — imagen publicada en ECR"),
    ("practica10/evidencia-p10-c5-env-vars.sh",  "Evidencia C6 — lista de variables de entorno"),
    ("practica10/limpiar-p10.sh",                "Limpieza de contenedores e imágenes de prueba locales"),
]
tbl8 = doc.add_table(rows=len(archivos)+1, cols=2)
tbl8.style = "Table Grid"
header_row(tbl8, "Archivo", "Descripción")
for i, (f, d) in enumerate(archivos, 1):
    data_row(tbl8, i, f, d)

doc.add_paragraph()

# ─── FOOTER ───────────────────────────────────────────────────────────────────
pie = doc.add_paragraph()
pie.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = pie.add_run(
    "Práctica 10 · Equipo Los Rojos · Cómputo en la Nube · UAS · 29 oct 2026"
)
r.font.size = Pt(9)
r.font.italic = True
r.font.color.rgb = RGBColor(120, 120, 120)

# =============================================================================
doc.save(OUTPUT)
print(f"✔  Documento generado: {OUTPUT}")
