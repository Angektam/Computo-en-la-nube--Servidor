from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.enum.dml import MSO_THEME_COLOR


OUT = "docs/presentaciones/E2_LosRojos_presentacion.pptx"

NAVY = RGBColor(10, 20, 38)
BLUE = RGBColor(27, 79, 114)
RED = RGBColor(211, 47, 47)
ORANGE = RGBColor(239, 125, 34)
INK = RGBColor(31, 41, 55)
MUTED = RGBColor(91, 104, 122)
LIGHT = RGBColor(244, 247, 250)
WHITE = RGBColor(255, 255, 255)
GREEN = RGBColor(31, 135, 91)


prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
blank = prs.slide_layouts[6]


def rect(slide, x, y, w, h, fill, radius=False, line=None):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE,
                                   Inches(x), Inches(y), Inches(w), Inches(h))
    shape.fill.solid(); shape.fill.fore_color.rgb = fill
    shape.line.color.rgb = line or fill
    if radius:
        shape.adjustments[0] = 0.08
    return shape


def text(slide, x, y, w, h, value, size=18, color=INK, bold=False, align=None,
         font="Aptos", valign=MSO_ANCHOR.TOP):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame; tf.clear(); tf.word_wrap = True; tf.vertical_anchor = valign
    p = tf.paragraphs[0]; p.text = value
    p.font.name = font; p.font.size = Pt(size); p.font.bold = bold; p.font.color.rgb = color
    if align is not None: p.alignment = align
    return box


def rich(slide, x, y, w, h, runs, size=18, color=INK, align=None):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame; tf.clear(); tf.word_wrap = True
    p = tf.paragraphs[0]
    if align is not None: p.alignment = align
    for value, bold, c in runs:
        r = p.add_run(); r.text = value; r.font.name = "Aptos"; r.font.size = Pt(size)
        r.font.bold = bold; r.font.color.rgb = c
    return box


def title(slide, kicker, heading, number):
    rect(slide, 0, 0, 13.333, 7.5, WHITE)
    rect(slide, 0, 0, 13.333, 0.12, RED)
    text(slide, 0.65, 0.45, 8, 0.3, kicker.upper(), 10, RED, True)
    text(slide, 0.65, 0.78, 11.5, 0.65, heading, 28, NAVY, True)
    text(slide, 12.1, 0.55, 0.55, 0.35, f"{number:02d}", 13, MUTED, True, PP_ALIGN.RIGHT)


def bullet(slide, x, y, w, value, size=16, color=INK, bullet_color=RED, h=0.38):
    rect(slide, x, y+0.09, 0.11, 0.11, bullet_color, True)
    text(slide, x+0.22, y, w-0.22, h, value, size, color)


def card(slide, x, y, w, h, heading, body, accent=BLUE, body_size=14):
    rect(slide, x, y, w, h, LIGHT, True, RGBColor(224, 230, 236))
    rect(slide, x, y, 0.08, h, accent, True)
    text(slide, x+0.22, y+0.18, w-0.4, 0.3, heading, 15, NAVY, True)
    text(slide, x+0.22, y+0.58, w-0.42, h-0.7, body, body_size, INK)


def node(slide, x, y, w, h, heading, body, fill=BLUE, body_color=WHITE):
    rect(slide, x, y, w, h, fill, True)
    text(slide, x+0.08, y+0.12, w-0.16, 0.3, heading, 12, WHITE, True, PP_ALIGN.CENTER)
    text(slide, x+0.1, y+0.48, w-0.2, h-0.56, body, 10, body_color, False, PP_ALIGN.CENTER)


def arrow(slide, x1, y1, x2, y2, color=RED):
    line = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    line.line.color.rgb = color; line.line.width = Pt(2.2); line.line.end_arrowhead = True


# 1 Cover
s = prs.slides.add_slide(blank); rect(s, 0, 0, 13.333, 7.5, NAVY)
rect(s, 0, 0, 0.22, 7.5, RED)
text(s, 0.85, 0.75, 5, 0.35, "CÓMPUTO EN LA NUBE · GRUPO 503", 13, RGBColor(170, 198, 221), True)
text(s, 0.85, 1.55, 8.6, 1.25, "Sistema de gestión\nde inventarios en la nube", 34, WHITE, True)
text(s, 0.9, 3.08, 7.3, 0.45, "Entregable E2 · Arquitectura y prototipo", 21, RGBColor(231, 238, 246))
rect(s, 0.88, 4.18, 4.85, 0.04, RED)
text(s, 0.9, 4.55, 6.5, 0.8, "Equipo Los Rojos\nKevin Ricardo López Payán · Ángel Gabriel Flores Guevara", 16, WHITE)
text(s, 0.9, 6.55, 6.5, 0.35, "Elizabeth Gaxiola Carrillo · 11 de noviembre de 2026", 12, RGBColor(170, 198, 221))
node(s, 9.15, 1.45, 2.5, 0.85, "ALB", "entrada pública", RED)
node(s, 9.15, 2.7, 2.5, 0.85, "ECS FARGATE", "2 tareas privadas", BLUE)
node(s, 9.15, 3.95, 2.5, 0.85, "RDS", "PostgreSQL", GREEN)
arrow(s, 10.4, 2.3, 10.4, 2.7); arrow(s, 10.4, 3.55, 10.4, 3.95)

# 2 Problem
s = prs.slides.add_slide(blank); title(s, "01 · PROBLEMA", "De registros manuales a decisiones de inventario", 2)
card(s, 0.75, 1.75, 3.75, 3.65, "Problema", "Hojas de cálculo y captura manual producen errores, descuadres y consultas lentas.\n\nEl negocio pierde visibilidad del stock y reacciona tarde ante faltantes.", RED, 16)
card(s, 4.8, 1.75, 3.75, 3.65, "Objetivo", "Automatizar productos, movimientos, alertas de stock mínimo, pedidos sugeridos y reportes para una pequeña empresa.", BLUE, 16)
card(s, 8.85, 1.75, 3.75, 3.65, "Alcance E2", "Arquitectura desplegada, modelo de datos implementado, prototipo accesible, costos preliminares y evidencia de repositorio.", GREEN, 16)
text(s, 0.8, 6.0, 11.8, 0.55, "Cambio desde E1: el prototipo evolucionó de una VM administrada a un contenedor en ECS Fargate detrás de un ALB.", 17, NAVY, True, PP_ALIGN.CENTER)

# 3 Architecture
s = prs.slides.add_slide(blank); title(s, "02 · ARQUITECTURA", "Una entrada pública; aplicación y datos aislados", 3)
text(s, 0.8, 1.48, 11.8, 0.35, "Región us-east-1 · VPC 10.0.0.0/16 · tareas sin IP pública", 13, MUTED, False, PP_ALIGN.CENTER)
rect(s, 0.75, 2.0, 11.85, 4.55, RGBColor(249, 251, 253), True, RGBColor(214, 223, 232))
text(s, 1.0, 2.22, 2.0, 0.3, "SUBREDES PÚBLICAS", 11, RED, True)
text(s, 5.05, 2.22, 2.0, 0.3, "SUBREDES PRIVADAS", 11, BLUE, True)
node(s, 1.0, 3.15, 1.55, 0.95, "INTERNET", "cliente", RED)
node(s, 3.15, 3.15, 2.0, 0.95, "ALB", "puerto 80\nhealth /health", RED)
node(s, 5.8, 3.15, 2.25, 0.95, "ECS FARGATE", "2 tareas · puerto 3000\nSG solo desde ALB", BLUE)
node(s, 9.0, 3.15, 2.25, 0.95, "RDS", "PostgreSQL\npuerto 5432", GREEN)
arrow(s, 2.55, 3.62, 3.12, 3.62); arrow(s, 5.17, 3.62, 5.78, 3.62); arrow(s, 8.08, 3.62, 8.98, 3.62)
node(s, 5.8, 5.15, 2.25, 0.85, "S3", "imágenes y archivos", ORANGE)
node(s, 9.0, 5.15, 2.25, 0.85, "CLOUDWATCH", "logs de tareas", MUTED)
arrow(s, 6.92, 4.13, 6.92, 5.12, ORANGE); arrow(s, 7.8, 3.95, 9.25, 5.12, MUTED)
text(s, 1.0, 6.18, 10.8, 0.3, "NAT Gateway solo durante despliegue/operación requerida; al cierre se reduce desiredCount a 0 para controlar costos.", 12, MUTED, False, PP_ALIGN.CENTER)

# 4 services
s = prs.slides.add_slide(blank); title(s, "03 · DECISIONES", "Servicios elegidos por responsabilidad y costo", 4)
card(s, 0.75, 1.55, 3.85, 2.15, "ECS Fargate", "Ejecuta la imagen Docker sin administrar servidores. Alternativa descartada: EC2 para reducir parcheo y tiempo de reposición.", BLUE, 13)
card(s, 4.75, 1.55, 3.85, 2.15, "ALB + VPC", "Expone una sola entrada y enruta a tareas privadas. Alternativa descartada: publicar directamente cada instancia/tarea.", RED, 13)
card(s, 8.75, 1.55, 3.85, 2.15, "RDS PostgreSQL", "Base relacional administrada para productos, movimientos, pedidos y usuarios. Alternativa descartada: BD dentro del contenedor.", GREEN, 13)
card(s, 0.75, 4.05, 3.85, 2.15, "S3", "Archivos e imágenes con permisos mínimos en IAM. Alternativa descartada: almacenar binarios en PostgreSQL.", ORANGE, 13)
card(s, 4.75, 4.05, 3.85, 2.15, "JWT + bcrypt + Helmet", "Sesiones con roles, contraseñas con hash y cabeceras de seguridad. Sin secretos dentro de la imagen.", MUTED, 13)
card(s, 8.75, 4.05, 3.85, 2.15, "Serverless puntual", "Lambda/API Gateway y DynamoDB se evaluaron para consultas aisladas; el núcleo usa PostgreSQL por consistencia relacional.", RED, 13)

# 5 data model
s = prs.slides.add_slide(blank); title(s, "04 · MODELO DE DATOS", "El inventario gira alrededor de productos y movimientos", 5)
text(s, 0.78, 1.48, 5.6, 0.3, "Modelo relacional implementado en PostgreSQL (RDS)", 15, BLUE, True)
card(s, 0.8, 2.05, 2.5, 1.45, "usuarios", "id · email · password_hash\nrol", BLUE, 12)
card(s, 3.65, 2.05, 2.5, 1.45, "productos", "id · sku · nombre\nstock · stock_minimo", RED, 12)
card(s, 6.5, 2.05, 2.5, 1.45, "movimientos", "id · producto_id · tipo\ncantidad · usuario_id", GREEN, 12)
card(s, 9.35, 2.05, 2.5, 1.45, "pedidos", "id · estado · proveedor\nfecha · total", ORANGE, 12)
arrow(s, 3.3, 2.76, 3.63, 2.76, MUTED); arrow(s, 6.15, 2.76, 6.48, 2.76, MUTED); arrow(s, 9.0, 2.76, 9.33, 2.76, MUTED)
text(s, 0.8, 4.15, 5.7, 0.3, "Flujo de negocio demostrado", 15, NAVY, True)
bullet(s, 0.95, 4.72, 5.5, "Salida de producto actualiza stock y registra movimiento", 15)
bullet(s, 0.95, 5.25, 5.5, "Stock bajo genera pedido sugerido sin duplicar pendientes", 15)
bullet(s, 0.95, 5.78, 5.5, "Roles limitan operaciones de administrador y bodega", 15)
rect(s, 7.0, 4.1, 5.05, 1.75, NAVY, True)
text(s, 7.28, 4.36, 4.5, 0.3, "Consulta de ejemplo", 14, RGBColor(170, 198, 221), True)
text(s, 7.28, 4.82, 4.45, 0.75, "GET /api/reportes/pedidos?estado=pendiente\n→ 200 · lista de pedidos pendientes", 16, WHITE, False)

# 6 prototype
s = prs.slides.add_slide(blank); title(s, "05 · PROTOTIPO", "Desplegado y verificable desde el balanceador", 6)
rect(s, 0.8, 1.55, 11.75, 0.9, NAVY, True)
text(s, 1.1, 1.82, 11.15, 0.35, "http://alb-inventario-cloud-los-rojos-727813269.us-east-1.elb.amazonaws.com/index-1.html", 15, WHITE, True, PP_ALIGN.CENTER)
card(s, 0.8, 2.95, 3.65, 2.6, "Evidencia de salud", "GET /health\nHTTP 200\n{ status: ok, db: ok }\n\nLa aplicación y la base responden desde Fargate.", GREEN, 16)
card(s, 4.85, 2.95, 3.65, 2.6, "Funcionalidades", "Login por rol\nProductos y categorías\nMovimientos paginados\nPedidos y reportes\nExportaciones CSV", BLUE, 15)
card(s, 8.9, 2.95, 3.65, 2.6, "Pruebas", "25/25 comprobaciones de verificación pasaron el 6 nov.\n\nAuditoría previa: 67/74; correcciones locales ya hechas y pendientes de despliegue.", ORANGE, 14)
text(s, 0.8, 6.15, 11.75, 0.42, "Demostración en vivo: iniciar sesión → consultar productos → registrar movimiento → revisar pedido/reportes.", 17, NAVY, True, PP_ALIGN.CENTER)

# 7 demo
s = prs.slides.add_slide(blank); title(s, "06 · DEMOSTRACIÓN", "Guion de 15 minutos para la exposición", 7)
steps = [("01", "Problema y objetivo", "1:00"), ("02", "Arquitectura y seguridad", "3:00"), ("03", "Login + productos", "3:00"), ("04", "Movimiento y stock", "3:00"), ("05", "Pedidos / reportes", "3:00"), ("06", "Costos y cierre", "2:00")]
for i, (n, h, t) in enumerate(steps):
    x = 0.85 + (i % 3) * 4.05; y = 1.7 + (i // 3) * 2.05
    rect(s, x, y, 3.55, 1.45, LIGHT, True, RGBColor(224, 230, 236))
    rect(s, x, y, 0.62, 1.45, RED if i in (0,5) else BLUE, True)
    text(s, x+0.08, y+0.48, 0.45, 0.35, n, 17, WHITE, True, PP_ALIGN.CENTER)
    text(s, x+0.82, y+0.26, 2.5, 0.4, h, 15, NAVY, True)
    text(s, x+0.82, y+0.82, 2.2, 0.3, t, 13, RED, True)
text(s, 0.85, 6.25, 11.5, 0.45, "Preguntas del auditor: ¿por qué Fargate y no EC2? ¿Cómo se protege la tarea y qué cambia con el triple de usuarios?", 15, MUTED, False, PP_ALIGN.CENTER)

# 8 costs
s = prs.slides.add_slide(blank); title(s, "07 · COSTOS", "El costo está dominado por cómputo y base de datos", 8)
rect(s, 0.85, 1.55, 3.25, 3.55, NAVY, True)
text(s, 1.1, 1.95, 2.75, 0.3, "ESCENARIO BASE", 12, RGBColor(170, 198, 221), True, PP_ALIGN.CENTER)
text(s, 1.1, 2.45, 2.75, 0.75, "$34.29", 38, WHITE, True, PP_ALIGN.CENTER)
text(s, 1.1, 3.38, 2.75, 0.45, "USD / mes\n50 usuarios activos", 16, RGBColor(231, 238, 246), False, PP_ALIGN.CENTER)
text(s, 1.1, 4.4, 2.75, 0.35, "$411.51 USD / año", 14, RGBColor(170, 198, 221), True, PP_ALIGN.CENTER)
card(s, 4.55, 1.55, 3.55, 3.55, "Desglose principal", "EC2 + EBS (referencia): $9.59\nRDS + storage: $23.58\nS3 + DynamoDB: $0.21\nTransferencia: $0.90\nVPC / IAM: $0.00", BLUE, 15)
card(s, 8.5, 1.55, 3.95, 3.55, "Triple de usuarios", "150 usuarios y 3× actividad/almacenamiento.\n\nEstimación lineal de componentes variables: ≈ $36.59 USD/mes.\n\nEl costo no se triplica porque EC2/RDS son costos fijos del escenario.", ORANGE, 15)
text(s, 0.85, 5.75, 11.6, 0.5, "Supuestos: us-east-1, 730 h/mes, On-Demand, sin Free Tier ni créditos. Con Free Tier del primer año: ≈ $0.97/mes según T6.", 13, MUTED, False, PP_ALIGN.CENTER)

# 9 progress
s = prs.slides.add_slide(blank); title(s, "08 · AVANCE", "E2 está operativo; E3 completa la experiencia", 9)
text(s, 0.85, 1.5, 5.2, 0.35, "Cumplido para E2", 18, GREEN, True)
for i, v in enumerate(["Arquitectura VPC + ALB + ECS + RDS", "Contenedor en subredes privadas", "Modelo relacional y API REST", "Pruebas de roles, salud y pedidos", "Repositorio privado con commits"]):
    bullet(s, 0.95, 2.0+i*0.55, 5.6, v, 15, INK, GREEN)
text(s, 6.85, 1.5, 5.2, 0.35, "Pendiente / riesgo para E3", 18, ORANGE, True)
for i, v in enumerate(["Desplegar las correcciones locales de validación", "Completar reportes y evidencias finales", "Mantener el prototipo accesible hasta revisión", "Revisar credenciales de usuario cajero", "Cerrar documento final y pruebas E3"]):
    bullet(s, 6.95, 2.0+i*0.55, 5.45, v, 15, INK, ORANGE)
rect(s, 0.85, 5.35, 11.6, 0.85, LIGHT, True, RGBColor(224, 230, 236))
text(s, 1.1, 5.58, 11.05, 0.38, "Roles: Kevin — documentación, arquitectura y modelo de datos · Ángel — desarrollo, AWS, seguridad y costos", 15, NAVY, True, PP_ALIGN.CENTER)

# 10 close
s = prs.slides.add_slide(blank); title(s, "09 · CIERRE", "Una base desplegada para llegar al E3", 10)
text(s, 0.9, 1.55, 11.5, 0.7, "El proyecto ya tiene forma técnica: se ejecuta en la nube, protege sus datos y permite demostrar el flujo principal de inventario.", 22, NAVY, True, PP_ALIGN.CENTER)
card(s, 0.9, 2.8, 3.55, 2.2, "Logro", "Prototipo accesible por ALB, con tareas Fargate privadas y RDS operativo.", GREEN, 16)
card(s, 4.9, 2.8, 3.55, 2.2, "Decisión clave", "Fargate reduce administración y repone una tarea en 12 s frente a 120–180 s de EC2.", BLUE, 16)
card(s, 8.9, 2.8, 3.55, 2.2, "Siguiente paso", "Desplegar correcciones, completar reportes y validar la entrega final E3.", ORANGE, 16)
text(s, 0.9, 5.75, 11.5, 0.38, "Fuentes: E1 Los Rojos · P11 ECS Fargate · T6 Costos · auditoría y verificación del repositorio (6 nov 2026).", 12, MUTED, False, PP_ALIGN.CENTER)
text(s, 0.9, 6.35, 11.5, 0.35, "Herramientas de apoyo declaradas: Kiro, GitHub Copilot y ChatGPT; el equipo revisó y validó los resultados.", 11, MUTED, False, PP_ALIGN.CENTER)

prs.save(OUT)
print(OUT)
