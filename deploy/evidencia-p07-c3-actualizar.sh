#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C3: UPDATE (update-item)
# Actualiza el campo 'motivo' y 'stock_despues' de MOV-8810.
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C3 · UPDATE — Actualizar elemento"
echo " Tabla  : $TABLE_NAME"
echo " Ítem   : PROD-0042 / 2026-10-14T09:15:00Z"
echo "============================================="

# --- Estado antes del UPDATE ---------------------------------------------
echo ""
echo ">>> Estado ANTES de actualizar:"
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0042"},
    "fecha":       {"S": "2026-10-14T09:15:00Z"}
  }' \
  --region "$REGION" \
  --output table

# --- Ejecutar UPDATE ------------------------------------------------------
echo ""
echo ">>> Actualizando motivo y stock_despues..."
aws dynamodb update-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0042"},
    "fecha":       {"S": "2026-10-14T09:15:00Z"}
  }' \
  --update-expression "SET motivo = :m, stock_despues = :sd" \
  --expression-attribute-values '{
    ":m":  {"S": "Venta mostrador — corregida"},
    ":sd": {"N": "67"}
  }' \
  --return-values ALL_NEW \
  --region "$REGION" \
  --output table

echo ""
echo "✔  C3 completado — ítem actualizado."
echo "   *** TOMAR CAPTURA AQUÍ ***"
