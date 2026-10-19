#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C2: QUERY
# Q1: dado producto_id → movimientos ordenados por fecha descendente.
# Q2: dado producto_id → movimientos tipo "salida" (pedidos pendientes).
# Q3: dado un día → todos los movimientos de ese día via GSI_fecha.
#
# SK compuesta: "ISO-8601#movimiento_id"
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"
PRODUCTO="PROD-0042"
DIA="2026-10-14"

echo "============================================="
echo " C2 · QUERY — Consultas principales"
echo " Tabla    : $TABLE_NAME"
echo " Producto : $PRODUCTO"
echo "============================================="

# --- Q1: todos los movimientos de PROD-0042, más recientes primero ----------
echo ""
echo ">>> Q1: todos los movimientos de $PRODUCTO (DESC por fecha)..."
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "producto_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "'"$PRODUCTO"'"}}' \
  --no-scan-index-forward \
  --region "$REGION" \
  --output table

# --- Q2: solo salidas (filtro sobre la misma partición) ---------------------
echo ""
echo ">>> Q2: movimientos tipo=salida de $PRODUCTO..."
echo "    (KeyCondition usa PK; FilterExpression aplica sobre el resultado)"
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
echo "    NOTA: ScannedCount > Count en Q2 porque DynamoDB lee toda"
echo "    la partición y después aplica el FilterExpression."
echo "    Solución de escala: GSI adicional con tipo como PK."

# --- Q3: rango de fechas via GSI_fecha ------------------------------------
echo ""
echo ">>> Q3: todos los movimientos del día $DIA via GSI_fecha..."
echo "    (Usa GSI_fecha: PK=fecha_dia — sin Scan, sin recorrer toda la tabla)"
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --index-name "GSI_fecha" \
  --key-condition-expression "fecha_dia = :dia" \
  --expression-attribute-values '{":dia": {"S": "'"$DIA"'"}}' \
  --region "$REGION" \
  --output table

echo ""
echo "    NOTA: GSI_fecha resuelve Q3 con una Query, no con Scan."
echo "    Para un rango (ej. 14-oct al 15-oct), se itera por día:"
echo "      fecha_dia = '2026-10-14'  +  fecha_dia = '2026-10-15'"

echo ""
echo "✔  C2 completado — Q1, Q2 y Q3 ejecutadas."
echo "   *** TOMAR CAPTURA AQUÍ ***"
