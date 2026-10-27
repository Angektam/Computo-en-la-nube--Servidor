#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — DynamoDB · Equipo Los Rojos
# Crea la tabla movimientos_inventario con capacidad bajo demanda y etiquetas.
# Se ejecuta en AWS CloudShell con el rol de servicio del proyecto (sin llaves).
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
echo "============================================="

# --- 1. Crear la tabla --------------------------------------------------
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions \
      AttributeName=producto_id,AttributeType=S \
      AttributeName=fecha,AttributeType=S \
  --key-schema \
      AttributeName=producto_id,KeyType=HASH \
      AttributeName=fecha,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags \
      Key=Equipo,Value="$EQUIPO" \
      Key=Proyecto,Value="$PROYECTO" \
      Key=Practica,Value=P07 \
  --region "$REGION"

echo ""
echo "Tabla creada. Esperando estado ACTIVE..."

aws dynamodb wait table-exists \
  --table-name "$TABLE_NAME" \
  --region "$REGION"

# --- 2. Confirmar estado -------------------------------------------------
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --query "Table.{Nombre:TableName, Estado:TableStatus, Modo:BillingModeSummary.BillingMode}" \
  --output table

echo ""
echo "✔  Tabla '$TABLE_NAME' lista."
echo ""
echo "NOTA: PAY_PER_REQUEST (bajo demanda) cobra por operación de lectura/escritura."
echo "      Una tabla en reposo NO genera costo. Ideal para proyectos escolares."
echo "      La capacidad aprovisionada cobra por hora aunque no haya tráfico."
