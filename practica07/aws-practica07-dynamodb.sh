#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — DynamoDB · Equipo Los Rojos
# Crea la tabla movimientos_inventario con:
#   · PK: producto_id (String)
#   · SK: fecha (String) — formato "ISO-8601#movimiento_id"
#         Ej: "2026-10-14T09:15:00Z#MOV-8810"
#         La parte ISO garantiza orden cronológico; el sufijo #movimiento_id
#         evita colisiones cuando dos movimientos del mismo producto ocurren
#         en el mismo segundo.
#   · GSI GSI_fecha — para resolver Q3 (rango de fechas, todos los productos)
#         PK del GSI: fecha_dia  (YYYY-MM-DD, atributo derivado al insertar)
#         SK del GSI: fecha      (timestamp completo — permite rango BETWEEN)
#   · Modo de capacidad: PAY_PER_REQUEST (bajo demanda)
#   · Etiquetas del proyecto
#
# Se ejecuta en AWS CloudShell con el rol de sesión (sin llaves de acceso).
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"
EQUIPO="LosRojos"
PROYECTO="InventarioNube"
CUENTA=$(aws sts get-caller-identity --query Account --output text)

echo "============================================="
echo " P07 · Crear tabla DynamoDB"
echo " Cuenta : $CUENTA"
echo " Región : $REGION"
echo " Tabla  : $TABLE_NAME"
echo " SK     : fecha = 'ISO-8601#movimiento_id'"
echo " GSI    : GSI_fecha (fecha_dia / fecha)"
echo "============================================="

# --- 1. Eliminar si ya existe (para re-crear con la nueva SK) ---------------
TABLE_EXISTS=$(aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --query "Table.TableStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_EXISTS" != "NOT_FOUND" ]; then
  echo ""
  echo "⚠  La tabla ya existe (estado: $TABLE_EXISTS)."
  echo "   Eliminando para recrear con SK compuesta y GSI..."
  aws dynamodb delete-table \
    --table-name "$TABLE_NAME" \
    --region "$REGION" > /dev/null
  echo "   Esperando que se elimine..."
  aws dynamodb wait table-not-exists \
    --table-name "$TABLE_NAME" \
    --region "$REGION"
  echo "   ✔ Tabla eliminada."
fi

# --- 2. Crear la tabla con SK compuesta y GSI --------------------------------
echo ""
echo "Creando tabla con SK compuesta y GSI_fecha..."

aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions \
      AttributeName=producto_id,AttributeType=S \
      AttributeName=fecha,AttributeType=S \
      AttributeName=fecha_dia,AttributeType=S \
  --key-schema \
      AttributeName=producto_id,KeyType=HASH \
      AttributeName=fecha,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[
    {
      "IndexName": "GSI_fecha",
      "KeySchema": [
        {"AttributeName": "fecha_dia", "KeyType": "HASH"},
        {"AttributeName": "fecha",     "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --tags \
      Key=Equipo,Value="$EQUIPO" \
      Key=Proyecto,Value="$PROYECTO" \
      Key=Practica,Value=P07 \
  --region "$REGION"

echo ""
echo "Tabla enviada a crear. Esperando estado ACTIVE..."

aws dynamodb wait table-exists \
  --table-name "$TABLE_NAME" \
  --region "$REGION"

# --- 3. Confirmar estado y estructura ----------------------------------------
echo ""
echo "--- Estado de la tabla ---"
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --query "Table.{
    Nombre:TableName,
    Estado:TableStatus,
    Modo:BillingModeSummary.BillingMode,
    PK:KeySchema[?KeyType=='HASH']|[0].AttributeName,
    SK:KeySchema[?KeyType=='RANGE']|[0].AttributeName
  }" \
  --output table

echo ""
echo "--- Índices secundarios globales ---"
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --query "Table.GlobalSecondaryIndexes[*].{
    Nombre:IndexName,
    Estado:IndexStatus,
    PK:KeySchema[?KeyType=='HASH']|[0].AttributeName,
    SK:KeySchema[?KeyType=='RANGE']|[0].AttributeName,
    Proyeccion:Projection.ProjectionType
  }" \
  --output table

echo ""
echo "✔  Tabla '$TABLE_NAME' lista."
echo ""
echo "DISEÑO DE CLAVE:"
echo "  PK  : producto_id               (String)"
echo "  SK  : fecha                     (String — 'ISO#movimiento_id')"
echo "        Ej: '2026-10-14T09:15:00Z#MOV-8810'"
echo "        El sufijo evita que dos movimientos del mismo producto"
echo "        en el mismo segundo se sobrescriban (son ítems distintos)."
echo ""
echo "  GSI_fecha:"
echo "  PK  : fecha_dia  (YYYY-MM-DD)   — permite corte diario sin Scan"
echo "  SK  : fecha      (ISO#movimiento_id) — permite BETWEEN para rangos"
echo "  Q3 (rango de fechas): iterar fecha_dia = '2026-10-14' con GSI_fecha"
echo ""
echo "  *** TOMAR CAPTURA AQUÍ — muestra tabla ACTIVE + GSI_fecha ***"
