from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.pdfgen.canvas import Canvas

OUT = 'docs/Arquitectura_Modelo_Datos_LosRojos.pdf'
PAGE = landscape(letter)


def box(c, x, y, w, h, title, body, fill=colors.HexColor('#EAF2F8')):
    c.setFillColor(fill)
    c.setStrokeColor(colors.HexColor('#1F4E79'))
    c.roundRect(x, y, w, h, 8, fill=1, stroke=1)
    c.setFillColor(colors.HexColor('#17365D'))
    c.setFont('Helvetica-Bold', 10)
    c.drawCentredString(x + w / 2, y + h - 17, title)
    c.setFillColor(colors.black)
    c.setFont('Helvetica', 8)
    for i, line in enumerate(body.split('\n')):
        c.drawCentredString(x + w / 2, y + h - 32 - i * 11, line)


def arrow(c, x1, y1, x2, y2, label=None):
    c.setStrokeColor(colors.HexColor('#555555'))
    c.setFillColor(colors.HexColor('#555555'))
    c.line(x1, y1, x2, y2)
    c.line(x2, y2, x2 - 5, y2 + 3)
    c.line(x2, y2, x2 - 5, y2 - 3)
    if label:
        c.setFont('Helvetica', 7)
        c.drawCentredString((x1 + x2) / 2, (y1 + y2) / 2 + 5, label)


def architecture_page(c):
    width, height = PAGE
    c.setTitle('Arquitectura y modelo de datos - Los Rojos')
    c.setFont('Helvetica-Bold', 20)
    c.setFillColor(colors.HexColor('#17365D'))
    c.drawString(38, height - 42, 'Diagrama de arquitectura')
    c.setFont('Helvetica', 9)
    c.setFillColor(colors.black)
    c.drawString(38, height - 58, 'Sistema de Gestión de Inventarios en la Nube · Equipo Los Rojos')

    box(c, 32, 310, 88, 55, 'Usuario', 'Navegador\nHTTPS')
    box(c, 142, 310, 88, 55, 'Internet', 'HTTP/HTTPS\nDNS público', colors.HexColor('#FCE4D6'))
    arrow(c, 120, 337, 142, 337, 'TLS')

    c.setStrokeColor(colors.HexColor('#1F4E79'))
    c.setDash(5, 3)
    c.roundRect(250, 165, 405, 235, 10, fill=0, stroke=1)
    c.setDash()
    c.setFont('Helvetica-Bold', 10)
    c.setFillColor(colors.HexColor('#1F4E79'))
    c.drawString(263, 382, 'VPC de AWS')

    box(c, 275, 295, 120, 62, 'Subred pública', 'Internet Gateway\nSecurity Group EC2')
    box(c, 420, 295, 120, 62, 'EC2 / VM', 'Nginx\nNode.js + Express\nFrontend + API')
    arrow(c, 230, 337, 275, 337, 'IGW')
    arrow(c, 395, 326, 420, 326, 'HTTP interno')

    box(c, 275, 205, 120, 62, 'Subred privada', 'Security Group RDS\nSin IP pública')
    box(c, 420, 205, 120, 62, 'RDS', 'PostgreSQL\nTLS / backups\nDatos operativos')
    arrow(c, 480, 295, 480, 267, '5432')

    box(c, 565, 295, 75, 62, 'IAM', 'Rol EC2\nAcceso S3', colors.HexColor('#E2F0D9'))
    box(c, 565, 205, 75, 62, 'S3', 'Archivos\ne imágenes', colors.HexColor('#FFF2CC'))
    arrow(c, 540, 326, 565, 326, 'Role')
    arrow(c, 540, 236, 565, 236, 'SDK')
    arrow(c, 480, 295, 565, 236, 'HTTPS')

    box(c, 275, 125, 120, 42, 'CloudWatch', 'Logs y métricas', colors.HexColor('#E2F0D9'))
    arrow(c, 420, 295, 335, 167, 'logs')
    c.setFont('Helvetica', 8)
    c.setFillColor(colors.black)
    c.drawString(32, 105, 'Controles de red: EC2 recibe HTTP/HTTPS; RDS solo acepta PostgreSQL desde el Security Group de EC2.')

    c.setFont('Helvetica-Bold', 11)
    c.setFillColor(colors.HexColor('#17365D'))
    c.drawString(38, 82, 'Flujo principal')
    c.setFont('Helvetica', 9)
    c.setFillColor(colors.black)
    flow = [
        '1. El usuario entra por HTTPS a Nginx en EC2.',
        '2. Nginx entrega el frontend y enruta las solicitudes /api a Express.',
        '3. Express valida JWT y permisos por rol.',
        '4. La API consulta RDS mediante PostgreSQL/TLS.',
        '5. Las imágenes se guardan en S3 y se entregan mediante URLs firmadas.',
    ]
    for i, line in enumerate(flow):
        c.drawString(50, 64 - i * 12, line)
    c.setFont('Helvetica-Oblique', 8)
    c.drawString(390, 42, 'Nota: el frontend también puede publicarse en S3 como alternativa de despliegue estático.')
    c.showPage()


def data_page(c):
    width, height = PAGE
    c.setFont('Helvetica-Bold', 20)
    c.setFillColor(colors.HexColor('#17365D'))
    c.drawString(38, height - 42, 'Modelo de datos')
    c.setFont('Helvetica', 9)
    c.setFillColor(colors.black)
    c.drawString(38, height - 58, 'Entidades operativas, relaciones y campos principales')

    tables = [
        ('USUARIOS', 'id PK · nombre · correo UK\npassword · rol · activo · creado_en'),
        ('CATEGORIAS', 'id PK · nombre UK · descripcion\nabreviacion'),
        ('PRODUCTOS', 'id PK · codigo UK · nombre · descripcion\ncategoria_id FK · precio · stock_actual · stock_minimo\nunidad · imagen_url · activo · fechas'),
        ('MOVIMIENTOS', 'id PK · producto_id FK · usuario_id FK\ntipo · cantidad · stock_antes · stock_despues\nmotivo · fecha'),
        ('PEDIDOS', 'id PK · producto_id FK · proveedor_id FK\ncantidad_sugerida · cantidad_recibida · estado\ncosto_unitario · entrega_estimada · fechas'),
        ('PROVEEDORES', 'id PK · nombre UK · contacto · correo\ntelefono · activo · creado_en'),
        ('PEDIDO_EVENTOS', 'id PK · pedido_id FK · usuario_id FK\ntipo · estados · cantidad · detalle · creado_en'),
        ('PEDIDO_RECEPCIONES', 'id PK · pedido_id FK · usuario_id FK\ncantidad · movimiento_id FK · creado_en'),
    ]
    positions = [(38, 305), (215, 305), (392, 305), (38, 170), (215, 170), (392, 170), (130, 55), (350, 55)]
    for (title, body), (x, y) in zip(tables, positions):
        box(c, x, y, 155, 78, title, body, colors.HexColor('#EAF2F8') if 'PEDIDO' not in title else colors.HexColor('#FFF2CC'))

    # Relation labels and connectors.
    c.setFont('Helvetica', 7)
    c.setFillColor(colors.HexColor('#555555'))
    relations = [
        (193, 344, 215, 344, 'categorias 1:N productos'),
        (370, 330, 392, 330, 'productos 1:N movimientos'),
        (193, 318, 215, 318, 'usuarios 1:N movimientos'),
        (370, 305, 392, 305, 'productos 1:N pedidos'),
        (370, 250, 392, 250, 'proveedores 1:N pedidos'),
        (292, 170, 208, 133, 'pedidos 1:N eventos'),
        (370, 170, 428, 133, 'pedidos 1:N recepciones'),
    ]
    for x1, y1, x2, y2, label in relations:
        arrow(c, x1, y1, x2, y2, label)

    c.setFont('Helvetica', 8)
    c.setFillColor(colors.black)
    c.drawString(38, 25, 'Reglas: roles = administrador/bodega/cajero · movimientos = entrada/salida/ajuste · pedidos = pendiente/enviado/recibido/cancelado')
    c.showPage()


def main():
    c = Canvas(OUT, pagesize=PAGE)
    architecture_page(c)
    data_page(c)
    c.save()


if __name__ == '__main__':
    main()
