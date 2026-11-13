from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()

sections = doc.sections
for section in sections:
    section.top_margin = Inches(0.5)
    section.bottom_margin = Inches(0.5)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)

title = doc.add_heading('TAREA 4: Funcionalidades Serverless', level=1)
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
for run in title.runs:
    run.font.size = Pt(13)
    run.bold = True

meta = doc.add_paragraph('Equipo: Los Rojos  |  Entrega: Lunes 26 de octubre de 2026')
meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
for run in meta.runs:
    run.font.size = Pt(9)

meta2 = doc.add_paragraph('Proyecto: inventario-cloud (Sistema de Gestión de Inventario)')
meta2.alignment = WD_ALIGN_PARAGRAPH.CENTER
for run in meta2.runs:
    run.font.size = Pt(9)
    run.italic = True

doc.add_paragraph()

p = doc.add_heading('Objetivo', level=2)
for run in p.runs:
    run.font.size = Pt(11)

p = doc.add_paragraph('Identificar 3 funcionalidades breves y esporádicas que se ejecuten sin servidor (AWS Lambda).')
for run in p.runs:
    run.font.size = Pt(9)

doc.add_paragraph()

# FUNCIONALIDAD 1
heading = doc.add_heading('Funcionalidad 1: Alerta de Stock Bajo', level=2)
for run in heading.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0, 102, 204)
    run.bold = True

table1 = doc.add_table(rows=4, cols=2)
table1.style = 'Light Grid Accent 1'

data1 = [
    ('Evento', 'Actualización de inventario en DynamoDB (cantidad < umbral mínimo)'),
    ('Acción', 'Lambda dispara email a gerente: "Producto [X] stock bajo: [cantidad] unidades. Requiere reorden"'),
    ('Tiempo', '2-3 segundos'),
    ('Servicio AWS', 'Lambda + DynamoDB Streams + SNS/SES'),
]

for i, (label, value) in enumerate(data1):
    table1.rows[i].cells[0].text = label
    table1.rows[i].cells[1].text = value
    for cell in table1.rows[i].cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# FUNCIONALIDAD 2
heading = doc.add_heading('Funcionalidad 2: Generación de Reporte Diario Automático', level=2)
for run in heading.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0, 153, 76)
    run.bold = True

table2 = doc.add_table(rows=4, cols=2)
table2.style = 'Light Grid Accent 1'

data2 = [
    ('Evento', 'EventBridge cron: Diariamente a las 8 PM (20:00)'),
    ('Acción', 'Lambda ejecuta: Lee tabla RDS → Calcula totales de ventas, stock, ganancias → Genera PDF → Guarda en S3 → Email con archivo adjunto'),
    ('Tiempo', '15-20 segundos'),
    ('Servicio AWS', 'Lambda + RDS + S3 + EventBridge + SES'),
]

for i, (label, value) in enumerate(data2):
    table2.rows[i].cells[0].text = label
    table2.rows[i].cells[1].text = value
    for cell in table2.rows[i].cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# FUNCIONALIDAD 3
heading = doc.add_heading('Funcionalidad 3: Validación y Limpieza de Datos Huérfanos', level=2)
for run in heading.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(204, 0, 0)
    run.bold = True

table3 = doc.add_table(rows=4, cols=2)
table3.style = 'Light Grid Accent 1'

data3 = [
    ('Evento', 'Usuario carga archivo CSV o solicita sincronización (botón "Validar Inventario")'),
    ('Acción', 'Lambda: Verifica duplicados por SKU → Detecta productos sin categoría asignada → Marca registros inválidos → Envía reporte de errores → Sugiere correcciones automáticas'),
    ('Tiempo', '5-8 segundos (hasta 10k registros)'),
    ('Servicio AWS', 'Lambda + S3 (almacena archivo CSV) + RDS (valida) + SNS (notifica resultados)'),
]

for i, (label, value) in enumerate(data3):
    table3.rows[i].cells[0].text = label
    table3.rows[i].cells[1].text = value
    for cell in table3.rows[i].cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# Justificación
p = doc.add_heading('Justificación', level=2)
for run in p.runs:
    run.font.size = Pt(11)

p = doc.add_paragraph('Las 3 funcionalidades son:')
for run in p.runs:
    run.font.size = Pt(9)

items = [
    'Breves: ejecutan en 2-20 segundos máximo',
    'Esporádicas: ocurren por cambio de datos o evento manual, no continuamente',
    'Disparadas por eventos: DynamoDB Streams, EventBridge cron, upload S3',
    'Ideales para Lambda: no requieren estado, se escalan automáticamente, pago por uso',
]
for item in items:
    p = doc.add_paragraph(item, style='List Bullet')
    for run in p.runs:
        run.font.size = Pt(9)

doc.add_paragraph()

# Tabla comparativa
p = doc.add_heading('Resumen Comparativo', level=2)
for run in p.runs:
    run.font.size = Pt(10)

resumen_table = doc.add_table(rows=5, cols=5)
resumen_table.style = 'Light Grid Accent 1'

headers = resumen_table.rows[0].cells
headers[0].text = 'Funcionalidad'
headers[1].text = 'Tipo'
headers[2].text = 'Evento'
headers[3].text = 'Tiempo'
headers[4].text = 'Costo'

resumen_data = [
    ('Alerta Stock', 'Serverless', 'DynamoDB Streams', '2-3 s', 'Muy bajo'),
    ('Reporte Diario', 'Serverless', 'EventBridge cron', '15-20 s', 'Bajo'),
    ('Validación CSV', 'Serverless', 'Upload S3/Manual', '5-8 s', 'Bajo'),
    ('Sincronización Proveedores', 'No-Serverless', 'Cron 5 min', '24/7', 'Bajo ($0.01/h)'),
]

for i, (func, tipo, evento, tiempo, costo) in enumerate(resumen_data, 1):
    row = resumen_table.rows[i].cells
    row[0].text = func
    row[1].text = tipo
    row[2].text = evento
    row[3].text = tiempo
    row[4].text = costo

for row in resumen_table.rows:
    for cell in row.cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# FUNCIONALIDAD 4 - NO SERVERLESS
heading = doc.add_heading('Funcionalidad 4: Sincronización en Tiempo Real con Proveedores (NO SERVERLESS)', level=2)
for run in heading.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(153, 76, 0)
    run.bold = True

table4 = doc.add_table(rows=5, cols=2)
table4.style = 'Light Grid Accent 1'

data4 = [
    ('Descripción', 'Servicio continuo que sincroniza el inventario local con APIs de 3 proveedores externos (cada 5 minutos). Requiere estado persistente y conexiones de larga duración.'),
    ('Evento', 'Cron job cada 5 minutos (sin disparador directo)'),
    ('Acción', 'EC2 t3.micro ejecuta script Python: Se conecta a API proveedores → Obtiene stock remoto → Compara con local → Actualiza RDS → Log cambios en S3'),
    ('Tiempo', 'Continuo (30-60 segundos cada ciclo, 12 ciclos/hora)'),
    ('Infraestructura', 'EC2 t3.micro + RDS + Python script + cron/systemd'),
]

for i, (label, value) in enumerate(data4):
    table4.rows[i].cells[0].text = label
    table4.rows[i].cells[1].text = value
    for cell in table4.rows[i].cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# Comparación
p = doc.add_heading('¿Por Qué NO es Serverless?', level=3)
for run in p.runs:
    run.font.size = Pt(10)

razones = [
    'Ejecución continua: Corre 24/7 en cron cada 5 minutos (no esporádico)',
    'Estado persistente: Mantiene conexiones abiertas a 3 APIs simultáneamente',
    'Latencia crítica: Requiere <10s de respuesta, Lambda tiene cold start',
    'Costo: 12 ejecuciones/hora × 60s = 720,000 ms/día; Lambda sería caro',
    'Mejor solución: EC2 t3.micro ($0.01/h) ejecuta script Python con cron + systemd',
]
for razon in razones:
    p = doc.add_paragraph(razon, style='List Bullet')
    for run in p.runs:
        run.font.size = Pt(9)

doc.add_paragraph()

# Ventajas
p = doc.add_heading('Ventajas de Serverless vs No-Serverless', level=2)
for run in p.runs:
    run.font.size = Pt(10)

para = doc.add_paragraph()
para_run = para.add_run('Serverless (Funcionalidades 1-3): ')
para_run.bold = True
para_run.font.size = Pt(9)
para_run2 = para.add_run('Breves, esporádicas, costo bajo, escalamiento automático. ')
para_run2.font.size = Pt(9)

para2 = doc.add_paragraph()
para2_run = para2.add_run('No-Serverless (Funcionalidad 4): ')
para2_run.bold = True
para2_run.font.size = Pt(9)
para2_run2 = para2.add_run('Continuas, estado persistente, latencia predecible, mejor costo en alta frecuencia.')
para2_run2.font.size = Pt(9)

doc.add_paragraph()

ventajas = [
    '✓ Serverless ideal para: Alertas, reportes, validación (5-20 segundos)',
    '✓ No-Serverless ideal para: Sincronización, polling continuo (24/7 o frecuencia alta)',
]
for ventaja in ventajas:
    p = doc.add_paragraph(ventaja, style='List Bullet')
    for run in p.runs:
        run.font.size = Pt(9)

output = 'C:\\Users\\angek\\OneDrive\\Documentos\\COMPUTO-EN-LA-NUVE\\Tarea04_Serverless_Completada.docx'
doc.save(output)
print(f'✔ Tarea 4 completada: {output}')
