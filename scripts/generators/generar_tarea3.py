from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()

# Márgenes más estrechos
sections = doc.sections
for section in sections:
    section.top_margin = Inches(0.5)
    section.bottom_margin = Inches(0.5)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)

# Título
title = doc.add_heading('TAREA 3: Instancias en Pico y Valle', level=1)
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
for run in title.runs:
    run.font.size = Pt(14)

# Metadatos
meta = doc.add_paragraph('Equipo: Los Rojos  |  Fecha: 22 de octubre de 2026')
meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
for run in meta.runs:
    run.font.size = Pt(9)

doc.add_paragraph()

# VALLE
heading_valle = doc.add_heading('¿Cuántos servidores necesito?', level=2)
for run in heading_valle.runs:
    run.font.size = Pt(12)

sub_valle = doc.add_heading('VALLE (2 AM - 6 AM): 1 Instancia', level=3)
for run in sub_valle.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0, 102, 204)

p = doc.add_paragraph('Demanda: 2-3 usuarios concurrentes')
for run in p.runs:
    run.font.size = Pt(10)

p = doc.add_paragraph('Cálculo: Capacidad t3.micro = 8 usuarios/inst  •  3/8 = 0.375  •  Margen 20%: 0.45 → 1 instancia', style='List Bullet')
for run in p.runs:
    run.font.size = Pt(9)

p = doc.add_paragraph('Justificación: Pocos usuarios. Una instancia maneja la demanda. Health check la reemplaza en 60s. Costo: $0.01/h.')
for run in p.runs:
    run.font.size = Pt(9)

doc.add_paragraph()

# PICO
sub_pico = doc.add_heading('PICO (8-10 AM, 4-6 PM): 4 Instancias', level=3)
for run in sub_pico.runs:
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(204, 0, 0)

p = doc.add_paragraph('Demanda: 20-30 usuarios concurrentes')
for run in p.runs:
    run.font.size = Pt(10)

p = doc.add_paragraph('Cálculo: 30/8 = 3.75  •  Margen 25%: 4.68  •  Redundancia 1.5×: 7 → 4 máximo (ASG)', style='List Bullet')
for run in p.runs:
    run.font.size = Pt(9)

p = doc.add_paragraph('Justificación: 4 inst = 32 usuarios máximo. Si falla 1, quedan 3 = 24. La 4ª es colchón. Costo: $0.04/h.')
for run in p.runs:
    run.font.size = Pt(9)

doc.add_paragraph()

# Tabla resumen
p = doc.add_paragraph('Resumen: Escalamiento Automático')
for run in p.runs:
    run.font.size = Pt(10)
    run.bold = True

table = doc.add_table(rows=4, cols=4)
table.style = 'Light Grid Accent 1'
hdr = table.rows[0].cells
hdr[0].text = 'Período'
hdr[1].text = 'Usuarios'
hdr[2].text = 'Instancias'
hdr[3].text = 'Costo/h'

data = [('Valle', '2-3', '1', '$0.01'), ('Normal', '10', '2', '$0.02'), ('Pico', '30', '4', '$0.04')]
for i, (periodo, usuarios, inst, costo) in enumerate(data, 1):
    row = table.rows[i].cells
    row[0].text = periodo
    row[1].text = usuarios
    row[2].text = inst
    row[3].text = costo

for row in table.rows:
    for cell in row.cells:
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)

doc.add_paragraph()

# Regla
p = doc.add_paragraph('Regla de Escalamiento')
for run in p.runs:
    run.font.size = Pt(10)
    run.bold = True
p = doc.add_paragraph('CPU > 60% → agregar (120s)  •  CPU < 30% → quitar (300s)  •  Min: 2 | Max: 4', style='List Bullet')
for run in p.runs:
    run.font.size = Pt(9)

doc.add_paragraph()

# Respuesta final
p = doc.add_paragraph('Respuesta Final')
for run in p.runs:
    run.font.size = Pt(10)
    run.bold = True

p = doc.add_paragraph('¿3 o cuántos? Entre 1 y 4, automáticamente. ASG escala: 1 valle, 2-4 pico. Ahorro: 40% vs 4 fijas. Costo: ~$18/mes.')
for run in p.runs:
    run.font.size = Pt(9)

output = 'C:\\Users\\angek\\OneDrive\\Documentos\\COMPUTO-EN-LA-NUVE\\Tarea03_Escalamiento_MediaCuartilla.docx'
doc.save(output)
print(f'Documento creado: {output}')
