#!/bin/bash
# =============================================================================
# EVIDENCIA PRÁCTICA 04 — Criterios 1 y 2
# · Criterio 1 (10 pts): Bucket etiquetado conforme al esquema del equipo
# · Criterio 2 (20 pts): Estado inicial del bloqueo y modificación justificada
# =============================================================================

BUCKET_NAME="sitio-inventario-cloud-los-rojos"
REGION="us-east-1"

echo "=============================================="
echo "  P04 · Criterio 1: Bucket y etiquetas"
echo "=============================================="
echo ""
echo "--- Información del bucket ---"
aws s3api get-bucket-location --bucket "$BUCKET_NAME"

echo ""
echo "--- Etiquetas del bucket ---"
aws s3api get-bucket-tagging --bucket "$BUCKET_NAME"

echo ""
echo "=============================================="
echo "  P04 · Criterio 2: Bloqueo de acceso público"
echo "=============================================="
echo ""
echo "--- Configuración actual de bloqueo ---"
aws s3api get-public-access-block --bucket "$BUCKET_NAME"

echo ""
echo "--- JUSTIFICACIÓN POR ESCRITO ---"
echo ""
echo "  BlockPublicAcls=true"
echo "  → Impide crear o asignar ACLs que hagan objetos públicos."
echo "    No usamos ACLs, así que bloquearlo es correcto y más seguro."
echo ""
echo "  IgnorePublicAcls=true"
echo "  → Ignora cualquier ACL pública que ya exista en el bucket."
echo "    Capa adicional de seguridad por si alguien subió un objeto con ACL."
echo ""
echo "  BlockPublicPolicy=false  ← MODIFICADO"
echo "  → Por defecto estaba en true (impedía aplicar cualquier política pública)."
echo "    Lo desactivamos ÚNICAMENTE para poder agregar la bucket policy"
echo "    que otorga s3:GetObject al mundo. Sin este cambio el sitio no funciona."
echo ""
echo "  RestrictPublicBuckets=false  ← MODIFICADO"
echo "  → Por defecto en true: aunque hubiera política pública, la ignoraba."
echo "    Lo desactivamos para que la política de lectura tenga efecto real."
echo ""
echo "  CONCLUSIÓN: solo desactivamos los dos controles que bloquean políticas,"
echo "  no los que protegen contra ACLs. El mínimo necesario para publicar."
