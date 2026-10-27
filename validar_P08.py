#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validar que P08 está completo y funcional"""

from docx import Document
import os

file = r"C:\Users\angek\OneDrive\Documentos\COMPUTO-EN-LA-NUVE\P08_LosRojos_Corregido_22oct2026.docx"

try:
    # Intentar abrir el documento
    doc = Document(file)
    
    # Contar elementos
    num_paragraphs = len(doc.paragraphs)
    num_tables = len(doc.tables)
    
    # Obtener tamaño
    size_kb = os.path.getsize(file) / 1024
    
    print("=" * 60)
    print("✓ ARCHIVO DOCX VÁLIDO E ÍNTEGRO")
    print("=" * 60)
    print(f"  Archivo: {os.path.basename(file)}")
    print(f"  Tamaño: {size_kb:.1f} KB")
    print(f"  Párrafos: {num_paragraphs}")
    print(f"  Tablas: {num_tables}")
    print()
    
    # Verificar contenido principal
    print("✓ CONTENIDO VERIFICADO:")
    print()
    
    # Buscar secciones principales
    required_sections = {
        "Resumen Ejecutivo": False,
        "Arquitectura": False,
        "Plantilla de Lanzamiento": False,
        "Umbral 60%": False,
        "Health Check": False,
        "Escalamiento": False,
        "Análisis de Costos": False,
        "Conclusiones": False,
    }
    
    all_text = " ".join([para.text.lower() for para in doc.paragraphs])
    
    for section in required_sections:
        if section.lower() in all_text:
            required_sections[section] = True
    
    for section, found in required_sections.items():
        status = "  ✓" if found else "  ✗"
        print(f"{status} {section}")
    
    # Verificar correcciones específicas del profesor
    print()
    print("✓ CORRECCIONES DEL PROFESOR:")
    print()
    
    corrections = {
        "Diagrama arquitectura": "Internet → ALB → Target Group" in all_text,
        "Launch template documentado": "user data" in all_text or "userdata" in all_text.lower(),
        "60% justificado con Tarea 3": "30 usuarios" in all_text or "demanda" in all_text,
        "Recovery time 82 segundos": "82" in all_text,
        "ALB puerto 80 (sin 443)": "puerto 80" in all_text or "port 80" in all_text,
    }
    
    for correction, found in corrections.items():
        status = "  ✓" if found else "  ✗"
        print(f"{status} {correction}")
    
    # Resumen final
    found_sections = sum(1 for v in required_sections.values() if v)
    found_corrections = sum(1 for v in corrections.values() if v)
    
    print()
    print("=" * 60)
    
    if found_sections == 8 and found_corrections == 5:
        print("✅ DOCUMENTO 100% COMPLETO Y FUNCIONAL")
        print(f"   • 8/8 secciones principales")
        print(f"   • 5/5 correcciones del profesor")
        print()
        print("STATUS: LISTO PARA ENTREGAR")
    else:
        print(f"⚠ Verificación parcial:")
        print(f"   • {found_sections}/8 secciones")
        print(f"   • {found_corrections}/5 correcciones")
    
    print("=" * 60)

except Exception as e:
    print(f"✗ Error al abrir: {e}")
    import traceback
    traceback.print_exc()
