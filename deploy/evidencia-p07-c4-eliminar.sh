#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C4: DELETE (delete-item)
# Elimina MOV-8815 (ajuste de merma, PROD-0017) de la tabla.
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C4 · DELETE — Eliminar elemento"
echo " Tabla  : $TABLE_NAME"
echo " Ítem   : PROD-0017 / 2026-10-14T11:00:00Z"
echo "============================================="

# --- Confirmar existencia antes de borrar --------------------------------
echo ""
echo ">>> Verificando que el ítem existe antes de eliminar..."
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z"}
  }' \
  --region "$REGION" \
  --output table

# --- Eliminar el ítem ----------------------------------------------------
echo ""
echo ">>> Eliminando MOV-8815 (PROD-0017)..."
aws dynamodb delete-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z"}
  }' \
  --return-values ALL_OLD \
  --region "$REGION" \
  --output table

# --- Confirmar eliminación -----------------------------------------------
echo ""
echo ">>> Verificando que el ítem ya NO existe (debe devolver vacío)..."
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z"}
  }' \
  --region "$REGION" \
  --output table

echo ""
echo "✔  C4 completado — ítem eliminado."
echo "   *** TOMAR CAPTURA AQUÍ ***"
