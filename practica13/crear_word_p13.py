from pathlib import Path
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

BASE = Path(__file__).parent
OUT = BASE / "P13_LosRojos_13nov2026_CORREGIDO.docx"

def shade(cell):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "1F4E78")
    tcPr.append(shd)

def table(doc, headers, rows):
    t = doc.add_table(rows=1, cols=len(headers))
    t.style = "Table Grid"
    for i, h in enumerate(headers):
        t.rows[0].cells[i].text = h
        shade(t.rows[0].cells[i])
    for row in rows:
        cells = t.add_row().cells
        for i, value in enumerate(row):
            cells[i].text = str(value)
    doc.add_paragraph()

def capture(doc, name, caption):
    p = BASE / name
    if p.exists():
        q = doc.add_paragraph()
        q.alignment = WD_ALIGN_PARAGRAPH.CENTER
        q.add_run().add_picture(str(p), width=Inches(6.4))
        c = doc.add_paragraph(caption)
        c.alignment = WD_ALIGN_PARAGRAPH.CENTER
        c.runs[0].italic = True

doc = Document()
s = doc.sections[0]
s.top_margin = Inches(.65)
s.bottom_margin = Inches(.65)
s.left_margin = Inches(.75)
s.right_margin = Inches(.75)
doc.styles["Normal"].font.name = "Aptos"
doc.styles["Normal"].font.size = Pt(10)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("PRÁCTICA 13\nMONITOREO Y ALARMAS")
r.bold = True
r.font.size = Pt(24)
p = doc.add_paragraph("Inventario Nube · Equipo Los Rojos\n11 de noviembre de 2026 · AWS us-east-1")
p.alignment = WD_ALIGN_PARAGRAPH.CENTER

doc.add_heading("Resumen de ejecución", level=1)
doc.add_paragraph("La práctica se ejecutó desde AWS CloudShell en us-east-1. La EC2 i-099eccb4405920a1e se encendió temporalmente para C2–C4 y quedó detenida al finalizar.")
table(doc, ["Evidencia", "Resultado"], [
    ["C1 · Tablero", "Inventario-LosRojos-P13 creado/actualizado con métricas EC2 y RDS."],
    ["C2 · Bitácoras", "Log Group /inventario-nube/app configurado; logs encontrados."],
    ["C3 · Umbral", "CPUUtilization ≥70%, 2 periodos de 300 s; SNS pendiente de confirmación."],
    ["C4 · Prueba", "Alarma forzada a ALARM y restaurada a OK."],
    ["C5 · Auditoría", "CloudTrail consultado; eventos de la práctica identificados."],
    ["C6 · Costos", "Cost Explorer consultado; total mostrado $0.00 redondeado."],
])

doc.add_heading("1. Tablero CloudWatch", level=1)
doc.add_paragraph("El tablero contiene CPU y tráfico de EC2; CPU, conexiones activas y almacenamiento libre de RDS. La gráfica de CPU incluye el umbral al 70%.")
capture(doc, "captura-dashboard.png", "Captura 1. Tablero Inventario-LosRojos-P13.")

doc.add_heading("2. Bitácoras de la aplicación", level=1)
doc.add_paragraph("Se configuró /inventario-nube/app con inventario-api-out, inventario-api-error, nginx-access y nginx-error. El script confirmó que existen eventos en CloudWatch Logs.")
capture(doc, "captura-logs.png", "Captura 2. Grupo de logs en CloudWatch.")

doc.add_heading("3. Justificación del umbral", level=1)
doc.add_paragraph("Se eligió AWS/EC2 CPUUtilization ≥70% durante dos periodos consecutivos de cinco minutos. El valor duplica el pico normal observado, evita falsos positivos y conserva margen de diagnóstico.")
table(doc, ["Rango", "Interpretación", "Acción"], [
    ["0–25%", "Normal", "Ninguna"], ["25–50%", "Pico esperado", "Monitorear"],
    ["50–70%", "Presión moderada", "Investigar"], ["≥70%", "Anómalo", "Escalar"],
    ["≥90%", "Crítico", "Reiniciar o escalar"],
])
capture(doc, "captura-alarma.png", "Captura 3. Alarma y configuración del umbral.")

doc.add_heading("4. Alarma y notificación", level=1)
doc.add_paragraph("Alarma: Inventario-EC2-CPU-Alta-LosRojos. Tema SNS: inventario-alarmas-losrojos. La alarma fue creada, probada con set-alarm-state y restaurada a OK. La suscripción quedó pendiente porque usa losrojos@ejemplo.com; debe sustituirse por un correo real.")
capture(doc, "captura-alarma.png", "Captura 4. Estado de la alarma en CloudWatch.")
doc.add_paragraph("Captura 5. No disponible: la suscripción SNS no fue confirmada al usar un correo de ejemplo.")

doc.add_heading("5. Procedimiento de respuesta", level=1)
for x in [
    "Confirmar que la alarma está en ALARM y no en una prueba controlada.",
    "Revisar CPU, tráfico EC2, conexiones RDS y almacenamiento libre.",
    "Consultar logs recientes y buscar respuestas HTTP 5xx o latencias altas.",
    "Conectarse a la EC2 y revisar top, ps, PM2 y logs de Nginx.",
    "Corregir la causa, validar CPU menor a 50% durante 10 minutos y documentar.",
]:
    doc.add_paragraph(x, style="List Number")

doc.add_heading("6. Registro de auditoría CloudTrail", level=1)
doc.add_paragraph("CloudTrail mostró PutMetricAlarm, DescribeAlarms, SendCommand y FilterLogEvents. La creación de la alarma aparece el 2026-11-11T09:10:47Z asociada al usuario root.")
capture(doc, "captura-cloudtrail.png", "Captura 6. Eventos consultados en CloudTrail.")

doc.add_heading("7. Gasto acumulado del mes", level=1)
doc.add_paragraph("Periodo: 2026-11-01 a 2026-11-11. Cost Explorer mostró $0.0000 redondeado; también se observaron ECS $0.0170 y EC2-Other $0.0070.")
table(doc, ["Servicio", "Costo USD"], [
    ["Amazon EC2 / EC2-Other", "$0.0070"], ["Amazon RDS", "$0.0000"],
    ["Amazon S3", "$0.0000"], ["Amazon DynamoDB", "$0.0000"],
    ["AWS Lambda", "$0.0000"], ["Amazon CloudWatch", "$0.0000"],
    ["Total mostrado", "$0.0000 (redondeado)"],
])
capture(doc, "captura-costos.png", "Captura 7. Cost Explorer y desglose de costos.")

doc.add_heading("8. Evidencia de ejecución en CloudShell", level=1)
doc.add_paragraph("La terminal muestra la ejecución de C1–C6 y el apagado posterior de la instancia EC2.")
capture(doc, "captura-cloudshell.png", "Captura 8. Ejecución en AWS CloudShell.")

doc.add_heading("Conclusión", level=1)
doc.add_paragraph("La infraestructura de monitoreo quedó creada y verificada. Para cerrar la evidencia de notificaciones, falta sustituir el correo SNS de ejemplo por una dirección real y confirmar la suscripción.")
doc.save(OUT)
print(OUT)
