#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C2: QUERY (consulta principal)
# Q1: dado producto_id → obtener movimientos ordenados por fecha descendente.
# Q2: dado producto_id → movimientos de tipo "salida" (pedidos pendientes).
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"
PRODUCTO="PROD-0042"

echo "============================================="
echo " C2 · QUERY — Consulta principal"
echo " Tabla    : $TABLE_NAME"
echo " Producto : $PRODUCTO"
echo "============================================="

# --- Q1: todos los movimientos de PROD-0042, más recientes primero ---------
echo ""
echo ">>> Q1: todos los movimientos de $PRODUCTO (DESC por fecha)..."
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "producto_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "'"$PRODUCTO"'"}}' \
  --no-scan-index-forward \
  --region "$REGION" \
  --output table

# --- Q2: solo las salidas (filtro sobre la misma partición) ----------------
echo ""
echo ">>> Q2: solo movimientos tipo=salida de $PRODUCTO..."
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "producto_id = :pid" \
  --filter-expression "#t = :tipo" \
  --expression-attribute-names '{"#t": "tipo"}' \
  --expression-attribute-values '{
    ":pid":  {"S": "'"$PRODUCTO"'"},
    ":tipo": {"S": "salida"}
  }' \
  --no-scan-index-forward \
  --region "$REGION" \
  --output table

echo ""
echo "✔  C2 completado."
echo "   *** TOMAR CAPTURA AQUÍ ***"
echo ""
echo "NOTA: ambas consultas usan la clave de partición (producto_id)."
echo "      DynamoDB localiza la partición directamente → costo mínimo."
