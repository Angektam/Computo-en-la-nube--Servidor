from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "entregables" / "Anexo_Calculadora_Precios_AWS.pdf"

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="TitleAWS", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=16, leading=20, textColor=colors.HexColor("#232F3E"), alignment=TA_CENTER, spaceAfter=8))
styles.add(ParagraphStyle(name="H2AWS", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=12, leading=15, textColor=colors.HexColor("#232F3E"), spaceBefore=8, spaceAfter=5))
styles.add(ParagraphStyle(name="BodyAWS", parent=styles["BodyText"], fontName="Helvetica", fontSize=9, leading=12, spaceAfter=5))
styles.add(ParagraphStyle(name="SmallAWS", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.5, leading=9))

def P(text, style="BodyAWS"):
    return Paragraph(text, styles[style])

def table(data, widths, header=True, small=False):
    t = Table([[P(str(c), "SmallAWS" if small else "BodyAWS") for c in row] for row in data], colWidths=widths, repeatRows=1 if header else 0)
    commands = [["GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B7C1CC")], ["VALIGN", (0, 0), (-1, -1), "TOP"], ["LEFTPADDING", (0, 0), (-1, -1), 4], ["RIGHTPADDING", (0, 0), (-1, -1), 4], ["TOPPADDING", (0, 0), (-1, -1), 4], ["BOTTOMPADDING", (0, 0), (-1, -1), 4]]
    if header:
        commands += [["BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#232F3E")], ["TEXTCOLOR", (0, 0), (-1, 0), colors.white]]
    for row in range(1 if header else 0, len(data)):
        if row % 2 == 0:
            commands += [["BACKGROUND", (0, row), (-1, row), colors.HexColor("#F2F2F2")]]
    t.setStyle(TableStyle(commands))
    return t

story = [
    P("ANEXO — CALCULADORA DE PRECIOS AWS", "TitleAWS"),
    P("Sistema: Inventario Nube · Región: us-east-1 (US East — N. Virginia)"),
    P("Fuente: AWS Pricing Calculator · precios On-Demand, sin Free Tier ni créditos."),
    P("1. Calculadora y evidencia", "H2AWS"),
    P("Calculadora oficial: https://calculator.aws/#/estimate. La captura de la consola AWS utilizada como evidencia corresponde a Cost Explorer y se conserva en practica13/captura-costos.png. El importe se documenta con los parámetros de la calculadora y la misma base de precios del proyecto."),
    P("2. Supuestos de uso", "H2AWS"),
]

sup = [
    ["Variable", "Actual", "×3", "Criterio"],
    ["Usuarios activos", "50", "150", "Se triplica la base de usuarios"],
    ["EC2 t3.micro", "730 h/mes", "730 h/mes", "Encendido 24/7; capacidad fija"],
    ["Disco EBS gp3", "20 GB", "20 GB", "SO, aplicación y logs"],
    ["RDS db.t3.micro PostgreSQL", "730 h/mes", "730 h/mes", "Single-AZ; encendido 24/7"],
    ["Almacenamiento RDS gp2", "20 GB", "20 GB", "Base de datos e historial"],
    ["S3 Standard / Standard-IA", "5 GB / 2 GB", "15 GB / 6 GB", "Archivos y lifecycle; escala ×3"],
    ["Solicitudes S3", "1,000 PUT + 10,000 GET", "3,000 PUT + 30,000 GET", "Escala con actividad"],
    ["DynamoDB", "30,000 writes + 150,000 reads", "90,000 writes + 450,000 reads", "Modo bajo demanda"],
    ["Lambda / API Gateway", "1,000 / 1,000 al mes", "3,000 / 3,000 al mes", "128 MB, 200 ms promedio"],
    ["Transferencia saliente", "10 GB/mes", "30 GB/mes", "Respuestas, imágenes y descargas"],
]
story += [table(sup, [3.6*cm, 3.1*cm, 3.5*cm, 7.0*cm], small=True), P("3. Costo mensual por servicio", "H2AWS")]

cost = [
    ["Servicio", "Actual USD/mes", "×3 USD/mes", "Tratamiento"],
    ["EC2 t3.micro + EBS", "9.59", "9.59", "Fijo"],
    ["RDS db.t3.micro + almacenamiento", "23.58", "23.58", "Fijo"],
    ["S3 Standard + IA + requests", "0.14", "0.42", "Variable, ×3"],
    ["DynamoDB on-demand", "0.07", "0.21", "Variable, ×3"],
    ["Lambda", "0.00", "0.00", "Volumen pequeño"],
    ["API Gateway", "0.00", "0.00", "Volumen pequeño"],
    ["Data Transfer Out", "0.90", "2.70", "Variable, ×3"],
    ["VPC, subredes, SG, IGW e IAM", "0.00", "0.00", "Sin cargo directo"],
    ["TOTAL MENSUAL ESTIMADO", "34.29", "36.59", "USD/mes"],
]
ct = table(cost, [6.4*cm, 3.0*cm, 3.0*cm, 4.8*cm], small=True)
ct.setStyle(TableStyle([["BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#FF9900")], ["TEXTCOLOR", (0, -1), (-1, -1), colors.white], ["FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"]]))
story += [ct, P("4. Interpretación", "H2AWS"), P("El costo no se triplica porque EC2 y RDS son componentes fijos mientras permanecen en el mismo tamaño y encendidos 24/7. Al triplicar usuarios se escalan S3, solicitudes, DynamoDB, invocaciones y transferencia; el estimado pasa de 34.29 USD/mes a 36.59 USD/mes."), P("Estos importes son estimaciones: AWS Pricing Calculator no incluye impuestos y el cobro real depende del uso efectivo y de la tarifa vigente.")]

doc = SimpleDocTemplate(str(OUT), pagesize=letter, rightMargin=1.4*cm, leftMargin=1.4*cm, topMargin=1.3*cm, bottomMargin=1.3*cm, title="Anexo Calculadora de Precios AWS")
doc.build(story)
print(OUT)
