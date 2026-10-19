#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C4: DELETE (delete-item)
# Elimina MOV-8815 (ajuste de merma, PROD-0017).
# SK compuesta: "2026-10-14T11:00:00Z#MOV-8815"
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C4 · DELETE — Eliminar elemento"
echo " Tabla  : $TABLE_NAME"
echo " PK     : PROD-0017"
echo " SK     : 2026-10-14T11:00:00Z#MOV-8815"
echo "============================================="

# --- Confirmar existencia ANTES de borrar ----------------------------------
echo ""
echo ">>> [ANTES] Verificando que MOV-8815 existe:"
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z#MOV-8815"}
  }' \
  --region "$REGION" \
  --output table

# --- Eliminar el ítem (devolver ALL_OLD) -----------------------------------
echo ""
echo ">>> Ejecutando DeleteItem (ReturnValues=ALL_OLD)..."
aws dynamodb delete-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z#MOV-8815"}
  }' \
  --return-values ALL_OLD \
  --region "$REGION" \
  --output table

# --- Confirmar que ya NO existe --------------------------------------------
echo ""
echo ">>> [DESPUÉS] Confirmando que MOV-8815 ya no existe:"
RESULTADO=$(aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "producto_id": {"S": "PROD-0017"},
    "fecha":       {"S": "2026-10-14T11:00:00Z#MOV-8815"}
  }' \
  --region "$REGION" \
  --output json)

if echo "$RESULTADO" | grep -q '"Item"'; then
  echo "  ⚠  El ítem todavía existe — verificar."
  echo "$RESULTADO"
else
  echo "  ✔ GetItem devuelve vacío — ítem eliminado exitosamente."
  echo "  (DynamoDB responde {} cuando el ítem no existe)"
fi

echo ""
echo "✔  C4 completado — ítem eliminado y confirmado."
echo "   *** TOMAR CAPTURA AQUÍ (muestra GetItem vacío) ***"
