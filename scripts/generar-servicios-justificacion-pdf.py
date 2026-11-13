from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

OUT = 'docs/Servicios_AWS_Usos_Justificaciones_LosRojos.pdf'

rows = [
    ('EC2 t3.micro', 'Ejecuta Nginx, Node.js, Express, frontend y API REST.', 'Servidor económico y suficiente para una aplicación pequeña.', 'ECS/Fargate o Elastic Beanstalk.'),
    ('EBS gp3, 20 GB', 'Disco de la instancia EC2.', 'Guarda sistema operativo, código, dependencias y logs.', 'EFS o almacenamiento administrado de contenedores.'),
    ('RDS db.t3.micro PostgreSQL', 'Base de datos principal del inventario.', 'Administra usuarios, productos, movimientos, pedidos y proveedores.', 'Aurora PostgreSQL o PostgreSQL administrado externo.'),
    ('RDS Storage gp2, 20 GB', 'Almacenamiento de la base de datos.', 'Guarda datos operativos e historial de movimientos.', 'Aumentar el volumen RDS o usar almacenamiento escalable.'),
    ('S3 Standard', 'Imágenes, archivos y posible frontend estático.', 'Almacenamiento durable y económico con URLs firmadas.', 'EFS, almacenamiento local o Cloudinary.'),
    ('S3 Standard-IA', 'Archivos con poco acceso después de 30 días.', 'Reduce costos para objetos consultados con poca frecuencia.', 'Glacier Instant Retrieval o conservar todo en Standard.'),
    ('Solicitudes S3', 'Operaciones PUT y GET de archivos.', 'Permiten subir, consultar y descargar imágenes o documentos.', 'Transferencia mediante CDN o almacenamiento alternativo.'),
    ('VPC', 'Red privada de AWS.', 'Aísla y organiza los recursos de la aplicación.', 'Red administrada por otra cuenta cloud o red local.'),
    ('Subred pública', 'Aloja EC2.', 'Permite que los usuarios accedan al servidor mediante Internet.', 'Balanceador público frente a instancias en subredes privadas.'),
    ('Subred privada', 'Aloja RDS.', 'Evita que la base de datos sea accesible directamente desde Internet.', 'Base de datos administrada con acceso privado equivalente.'),
    ('Security Groups', 'Controlan el tráfico de EC2 y RDS.', 'EC2 recibe HTTP/HTTPS; RDS solo acepta PostgreSQL desde EC2.', 'Network ACLs, WAF y firewall del sistema.'),
    ('Internet Gateway', 'Conecta la VPC con Internet.', 'Permite el acceso público hacia EC2.', 'Load Balancer público o CloudFront como entrada.'),
    ('IAM', 'Roles y políticas para EC2 y usuarios.', 'Aplica mínimo privilegio y evita claves permanentes en EC2.', 'Identity Center, SSO o IAM de otro proveedor.'),
    ('CloudWatch', 'Logs y métricas.', 'Permite revisar errores, actividad y estado de los recursos.', 'Grafana, Prometheus o ELK/OpenSearch.'),
    ('Data Transfer Out', 'Tráfico de respuestas, archivos e imágenes.', 'Representa el costo variable por datos enviados a Internet.', 'CDN, compresión y caché para reducir transferencia.'),
    ('NAT Gateway', 'No se utiliza.', 'Se descartó por costo; RDS no necesita salida directa a Internet.', 'NAT Instance o VPC endpoints si se requiere salida privada.'),
    ('Route 53', 'No configurado.', 'Se utiliza directamente la IP pública de EC2.', 'Route 53, Cloudflare DNS o dominio del proveedor.'),
    ('DynamoDB', 'No forma parte de la arquitectura actual.', 'Aparece en la tabla como alternativa NoSQL serverless.', 'RDS PostgreSQL, que es la opción actualmente implementada.'),
    ('Lambda', 'No forma parte de la arquitectura actual.', 'Aparece como alternativa para ejecutar funciones sin servidor.', 'Node.js/Express ejecutándose en EC2.'),
    ('API Gateway', 'No forma parte de la arquitectura actual.', 'Aparece como alternativa para exponer funciones Lambda por HTTP.', 'Nginx + Express en EC2.'),
]

styles = getSampleStyleSheet()
title = ParagraphStyle('title', parent=styles['Title'], fontName='Helvetica-Bold', fontSize=20, leading=24, textColor=colors.HexColor('#17365D'), alignment=TA_CENTER, spaceAfter=6)
subtitle = ParagraphStyle('subtitle', parent=styles['Normal'], fontSize=9, alignment=TA_CENTER, textColor=colors.HexColor('#444444'), spaceAfter=12)
cell = ParagraphStyle('cell', parent=styles['Normal'], fontSize=8.3, leading=10)
cell_bold = ParagraphStyle('cell_bold', parent=cell, fontName='Helvetica-Bold', textColor=colors.HexColor('#17365D'))
note = ParagraphStyle('note', parent=styles['Normal'], fontSize=9, leading=12, spaceBefore=10)

def P(text, style=cell):
    return Paragraph(text, style)

doc = SimpleDocTemplate(OUT, pagesize=landscape(letter), rightMargin=28, leftMargin=28, topMargin=28, bottomMargin=28)
story = [
    Paragraph('Servicios AWS: uso, justificación y alternativa', title),
    Paragraph('Sistema de Gestión de Inventarios en la Nube · Equipo Los Rojos', subtitle),
]

data = [[P('Servicio', cell_bold), P('Uso', cell_bold), P('Justificación', cell_bold), P('Alternativa', cell_bold)]]
data += [[P(service, cell_bold), P(use), P(reason), P(alternative)] for service, use, reason, alternative in rows]

table = Table(data, colWidths=[1.35*inch, 2.55*inch, 3.15*inch, 2.10*inch], repeatRows=1)
table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#17365D')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.35, colors.HexColor('#A6A6A6')),
    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ('LEFTPADDING', (0, 0), (-1, -1), 6),
    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ('TOPPADDING', (0, 0), (-1, -1), 5),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#EAF2F8')]),
]))
story += [table, Spacer(1, 8), Paragraph('<b>Nota:</b> DynamoDB, Lambda y API Gateway aparecen en la tabla original de costos como una alternativa serverless, pero no forman parte de la arquitectura actual basada en EC2 + RDS + S3.', note)]
doc.build(story)
print(OUT)
