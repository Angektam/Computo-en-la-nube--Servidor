#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C1: INSERT (put-item)
# Inserta tres elementos de ejemplo en la tabla movimientos_inventario.
# Se ejecuta en CloudShell; usa el rol de la instancia, SIN llaves de acceso.
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C1 · INSERT — Insertar elementos"
echo " Tabla  : $TABLE_NAME"
echo " Región : $REGION"
echo "============================================="
echo ""

# --- Elemento 1 -----------------------------------------------------------
echo ">>> Insertando MOV-8810 (salida, PROD-0042)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id":   {"S": "PROD-0042"},
    "fecha":         {"S": "2026-10-14T09:15:00Z"},
    "movimiento_id": {"S": "MOV-8810"},
    "tipo":          {"S": "salida"},
    "cantidad":      {"N": "12"},
    "stock_antes":   {"N": "80"},
    "stock_despues": {"N": "68"},
    "usuario_id":    {"S": "USR-003"},
    "motivo":        {"S": "Venta mostrador"},
    "fecha_dia":     {"S": "2026-10-14"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8810 insertado."

# --- Elemento 2 -----------------------------------------------------------
echo ""
echo ">>> Insertando MOV-8801 (entrada, PROD-0042)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id":   {"S": "PROD-0042"},
    "fecha":         {"S": "2026-10-13T14:30:00Z"},
    "movimiento_id": {"S": "MOV-8801"},
    "tipo":          {"S": "entrada"},
    "cantidad":      {"N": "50"},
    "stock_antes":   {"N": "30"},
    "stock_despues": {"N": "80"},
    "usuario_id":    {"S": "USR-001"},
    "motivo":        {"S": "Reposicion proveedor"},
    "fecha_dia":     {"S": "2026-10-13"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8801 insertado."

# --- Elemento 3 -----------------------------------------------------------
echo ""
echo ">>> Insertando MOV-8815 (ajuste, PROD-0017)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id":   {"S": "PROD-0017"},
    "fecha":         {"S": "2026-10-14T11:00:00Z"},
    "movimiento_id": {"S": "MOV-8815"},
    "tipo":          {"S": "ajuste"},
    "cantidad":      {"N": "-3"},
    "stock_antes":   {"N": "15"},
    "stock_despues": {"N": "12"},
    "usuario_id":    {"S": "USR-001"},
    "motivo":        {"S": "Merma por caducidad"},
    "fecha_dia":     {"S": "2026-10-14"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8815 insertado."

echo ""
echo "============================================="
echo " Verificación: listar ítems de PROD-0042"
echo "============================================="
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "producto_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "PROD-0042"}}' \
  --no-scan-index-forward \
  --region "$REGION" \
  --output table

echo ""
echo "✔  C1 completado — 3 elementos insertados."
echo "   *** TOMAR CAPTURA AQUÍ ***"
