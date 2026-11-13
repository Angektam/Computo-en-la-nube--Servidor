from reportlab.lib.pagesizes import landscape, letter
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib import colors

OUT = "docs/presentaciones/E2_LosRojos_presentacion.pdf"
W, H = landscape(letter)
navy=colors.HexColor("#0A1426"); red=colors.HexColor("#D32F2F")
blue=colors.HexColor("#1B4F72"); green=colors.HexColor("#1F875B")
orange=colors.HexColor("#EF7D22"); ink=colors.HexColor("#1F2937")
muted=colors.HexColor("#5B687A"); light=colors.HexColor("#F4F7FA")
c=Canvas(OUT,pagesize=(W,H))

def lines(s, n=86):
    out=[]; cur=""
    for w in s.split():
        if len(cur)+len(w)+1>n: out.append(cur); cur=w
        else: cur=(cur+" "+w).strip()
    if cur: out.append(cur)
    return out

def txt(x,y,s,size=16,col=ink,bold=False,n=86,lead=None):
    c.setFillColor(col); c.setFont("Helvetica-Bold" if bold else "Helvetica",size)
    for line in lines(s,n):
        c.drawString(x,y,line); y-=lead or size*1.3

def head(k,h,num):
    c.setFillColor(colors.white); c.rect(0,0,W,H,fill=1,stroke=0)
    c.setFillColor(red); c.rect(0,H-8,W,8,fill=1,stroke=0)
    txt(40,H-40,k.upper(),9,red,True); txt(40,H-72,h,22,navy,True); txt(W-58,H-48,f"{num:02d}",11,muted,True)

def box(x,y,w,h,hdr,body,accent=blue):
    c.setFillColor(light); c.setStrokeColor(colors.HexColor("#DDE5EC")); c.roundRect(x,y,w,h,9,fill=1,stroke=1)
    c.setFillColor(accent); c.roundRect(x,y,7,h,4,fill=1,stroke=0)
    txt(x+15,y+h-24,hdr,12,navy,True,n=28)
    txt(x+15,y+h-45,body,10,ink,n=max(24,int(w/6)),lead=14)

def page(k,h,num):
    c.showPage(); head(k,h,num)

# 1
c.setFillColor(navy); c.rect(0,0,W,H,fill=1,stroke=0); c.setFillColor(red); c.rect(0,0,13,H,fill=1,stroke=0)
txt(48,H-52,"CÓMPUTO EN LA NUBE · GRUPO 503",10,colors.HexColor("#AAC6DD"),True)
txt(48,H-112,"Sistema de gestión de inventarios en la nube",28,colors.white,True,n=42)
txt(50,H-180,"Entregable E2 · Arquitectura y prototipo",17,colors.HexColor("#E7EEF6"))
txt(50,145,"Equipo Los Rojos\nKevin Ricardo López Payán · Ángel Gabriel Flores Guevara",13,colors.white,n=60,lead=18)
txt(50,52,"Elizabeth Gaxiola Carrillo · 11 de noviembre de 2026",10,colors.HexColor("#AAC6DD"))

page("01 · Problema","De registros manuales a decisiones de inventario",2)
box(42,225,220,210,"Problema","Hojas de cálculo y captura manual producen errores, descuadres y consultas lentas. El negocio pierde visibilidad del stock y reacciona tarde ante faltantes.",red)
box(286,225,220,210,"Objetivo","Automatizar productos, movimientos, alertas de stock mínimo, pedidos sugeridos y reportes para una pequeña empresa.",blue)
box(530,225,220,210,"Alcance E2","Arquitectura desplegada, modelo implementado, prototipo accesible, costos preliminares y evidencia de repositorio.",green)
txt(42,105,"Cambio desde E1: el prototipo evolucionó de una VM administrada a un contenedor en ECS Fargate detrás de un ALB.",14,navy,True,n=90)

page("02 · Arquitectura","Una entrada pública; aplicación y datos aislados",3)
txt(42,485,"Región us-east-1 · VPC 10.0.0.0/16 · tareas sin IP pública",10,muted,n=90)
box(42,270,210,140,"Internet → ALB","Entrada pública única; health check GET /health.",red)
box(286,270,210,140,"ECS Fargate","2 tareas privadas, puerto 3000, SG solo desde ALB.",blue)
box(530,270,210,140,"RDS PostgreSQL","Base relacional privada, puerto 5432.",green)
box(286,100,210,120,"S3 + CloudWatch","Archivos e imágenes en S3; logs de tareas en CloudWatch.",orange)
txt(42,65,"NAT Gateway solo durante despliegue/operación requerida; al cierre desiredCount = 0 para controlar costos.",10,muted,n=90)

page("03 · Decisiones","Servicios elegidos por responsabilidad y costo",4)
box(42,285,220,150,"ECS Fargate","Ejecuta la imagen Docker sin administrar servidores. Se descartó EC2 para reducir parcheo y reposición.",blue)
box(286,285,220,150,"ALB + VPC","Una entrada pública enruta a tareas privadas. No se publican directamente las tareas.",red)
box(530,285,220,150,"RDS PostgreSQL","Base relacional administrada para productos, movimientos, pedidos y usuarios.",green)
box(42,105,220,150,"S3","Archivos e imágenes con permisos mínimos en IAM.",orange)
box(286,105,220,150,"JWT + bcrypt + Helmet","Sesiones con roles, hash de contraseñas y cabeceras de seguridad.",muted)
box(530,105,220,150,"Serverless puntual","Lambda/API Gateway y DynamoDB se evaluaron para consultas aisladas; el núcleo usa PostgreSQL.",red)

page("04 · Modelo de datos","El inventario gira alrededor de productos y movimientos",5)
txt(42,475,"Modelo relacional implementado en PostgreSQL (RDS)",13,blue,True)
box(42,320,150,90,"usuarios","id · email · password_hash · rol",blue)
box(215,320,150,90,"productos","id · sku · nombre · stock",red)
box(388,320,150,90,"movimientos","producto_id · tipo · cantidad",green)
box(561,320,150,90,"pedidos","estado · proveedor · fecha",orange)
txt(42,260,"Flujo: salida actualiza stock y registra movimiento; stock bajo genera pedido sugerido; los roles limitan operaciones.",12,ink,n=62,lead=20)
box(470,120,270,100,"Consulta de ejemplo","GET /api/reportes/pedidos?estado=pendiente → 200 · lista de pedidos pendientes",navy)

page("05 · Prototipo","Desplegado y verificable desde el balanceador",6)
box(42,430,710,60,"URL pública","http://alb-inventario-cloud-los-rojos-727813269.us-east-1.elb.amazonaws.com/index-1.html",navy)
box(42,205,220,190,"Evidencia de salud","GET /health · HTTP 200 · { status: ok, db: ok }",green)
box(286,205,220,190,"Funcionalidades","Login por rol, productos, categorías, movimientos, pedidos, reportes y CSV.",blue)
box(530,205,220,190,"Pruebas","25/25 verificaciones pasaron el 6 nov. Auditoría previa: 67/74; correcciones locales hechas y pendientes de despliegue.",orange)
txt(42,115,"Demo: iniciar sesión → consultar productos → registrar movimiento → revisar pedido/reportes.",14,navy,True,n=90)

page("06 · Demostración","Guion de 15 minutos para la exposición",7)
box(48,315,210,85,"01 · Problema","1:00",red); box(290,315,210,85,"02 · Arquitectura","3:00",blue); box(532,315,210,85,"03 · Login + productos","3:00",blue)
box(48,190,210,85,"04 · Movimiento y stock","3:00",blue); box(290,190,210,85,"05 · Pedidos / reportes","3:00",blue); box(532,190,210,85,"06 · Costos y cierre","2:00",red)
txt(48,105,"Preguntas del auditor: ¿por qué Fargate y no EC2? ¿Cómo se protege la tarea y qué cambia con el triple de usuarios?",11,muted,n=90)

page("07 · Costos","El costo está dominado por cómputo y base de datos",8)
box(48,220,195,220,"ESCENARIO BASE","$34.29 USD / mes\n50 usuarios activos\n$411.51 USD / año",navy)
box(270,220,220,220,"Desglose principal","EC2 + EBS: $9.59\nRDS + storage: $23.58\nS3 + DynamoDB: $0.21\nTransferencia: $0.90",blue)
box(518,220,232,220,"Triple de usuarios","150 usuarios y 3× actividad/almacenamiento. Estimación lineal: ≈ $36.59 USD/mes. No se triplica porque EC2/RDS son costos fijos.",orange)
txt(48,145,"Supuestos: us-east-1, 730 h/mes, On-Demand, sin Free Tier. Con Free Tier: ≈ $0.97/mes durante el primer año.",10,muted,n=90)

page("08 · Avance","E2 está operativo; E3 completa la experiencia",9)
txt(48,470,"Cumplido para E2",15,green,True); txt(58,420,"• Arquitectura VPC + ALB + ECS + RDS\n• Contenedor en subredes privadas\n• Modelo relacional y API REST\n• Pruebas de roles, salud y pedidos\n• Repositorio privado con commits",13,ink,n=42,lead=24)
txt(405,470,"Pendiente / riesgo para E3",15,orange,True); txt(415,420,"• Desplegar correcciones locales\n• Completar reportes y evidencias\n• Mantener prototipo accesible\n• Revisar credenciales de cajero\n• Cerrar documento y pruebas E3",13,ink,n=42,lead=24)
box(48,100,700,60,"Roles","Kevin — documentación, arquitectura y modelo de datos · Ángel — desarrollo, AWS, seguridad y costos",navy)

page("09 · Cierre","Una base desplegada para llegar al E3",10)
txt(48,470,"El proyecto ya tiene forma técnica: se ejecuta en la nube, protege sus datos y permite demostrar el flujo principal de inventario.",16,navy,True,n=90)
box(48,250,210,135,"Logro","Prototipo accesible por ALB, con tareas Fargate privadas y RDS operativo.",green)
box(290,250,210,135,"Decisión clave","Fargate repone una tarea en 12 s frente a 120–180 s de EC2.",blue)
box(532,250,210,135,"Siguiente paso","Desplegar correcciones, completar reportes y validar E3.",orange)
txt(48,120,"Fuentes: E1 Los Rojos · P11 ECS Fargate · T6 Costos · auditoría y verificación del repositorio (6 nov 2026).",9,muted,n=90)
txt(48,85,"Herramientas declaradas: Kiro, GitHub Copilot y ChatGPT; el equipo revisó y validó los resultados.",9,muted,n=90)
c.save()
print(OUT)
