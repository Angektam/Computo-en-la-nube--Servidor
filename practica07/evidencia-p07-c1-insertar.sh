#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C1: INSERT (put-item)
# Inserta tres elementos con SK compuesta: "ISO-8601#movimiento_id"
# El sufijo #movimiento_id evita colisiones si dos movimientos del mismo
# producto ocurren en el mismo segundo (ambos serán ítems distintos).
#
# TOMAR CAPTURA de la salida completa de este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C1 · INSERT — Insertar elementos"
echo " Tabla  : $TABLE_NAME"
echo " Región : $REGION"
echo " SK     : 'ISO-8601#movimiento_id'"
echo "============================================="
echo ""

# --- Elemento 1 — salida PROD-0042 ----------------------------------------
echo ">>> Insertando MOV-8810 (salida, PROD-0042)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id"   : {"S": "PROD-0042"},
    "fecha"         : {"S": "2026-10-14T09:15:00Z#MOV-8810"},
    "movimiento_id" : {"S": "MOV-8810"},
    "tipo"          : {"S": "salida"},
    "cantidad"      : {"N": "12"},
    "stock_antes"   : {"N": "80"},
    "stock_despues" : {"N": "68"},
    "usuario_id"    : {"S": "USR-003"},
    "motivo"        : {"S": "Venta mostrador"},
    "fecha_dia"     : {"S": "2026-10-14"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8810 insertado  (SK: 2026-10-14T09:15:00Z#MOV-8810)"

# --- Elemento 2 — entrada PROD-0042 ---------------------------------------
echo ""
echo ">>> Insertando MOV-8801 (entrada, PROD-0042)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id"   : {"S": "PROD-0042"},
    "fecha"         : {"S": "2026-10-13T14:30:00Z#MOV-8801"},
    "movimiento_id" : {"S": "MOV-8801"},
    "tipo"          : {"S": "entrada"},
    "cantidad"      : {"N": "50"},
    "stock_antes"   : {"N": "30"},
    "stock_despues" : {"N": "80"},
    "usuario_id"    : {"S": "USR-001"},
    "motivo"        : {"S": "Reposicion proveedor"},
    "fecha_dia"     : {"S": "2026-10-13"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8801 insertado  (SK: 2026-10-13T14:30:00Z#MOV-8801)"

# --- Elemento 3 — ajuste PROD-0017 ----------------------------------------
echo ""
echo ">>> Insertando MOV-8815 (ajuste, PROD-0017)..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "producto_id"   : {"S": "PROD-0017"},
    "fecha"         : {"S": "2026-10-14T11:00:00Z#MOV-8815"},
    "movimiento_id" : {"S": "MOV-8815"},
    "tipo"          : {"S": "ajuste"},
    "cantidad"      : {"N": "-3"},
    "stock_antes"   : {"N": "15"},
    "stock_despues" : {"N": "12"},
    "usuario_id"    : {"S": "USR-001"},
    "motivo"        : {"S": "Merma por caducidad"},
    "fecha_dia"     : {"S": "2026-10-14"}
  }' \
  --region "$REGION"
echo "   ✔ MOV-8815 insertado  (SK: 2026-10-14T11:00:00Z#MOV-8815)"

# --- Verificación: listar PROD-0042 DESC -----------------------------------
echo ""
echo "============================================="
echo " Verificación: Query PROD-0042 (DESC por SK)"
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
echo "   SK compuesta: 'ISO-8601#movimiento_id' en los tres ítems."
echo "   *** TOMAR CAPTURA AQUÍ ***"
