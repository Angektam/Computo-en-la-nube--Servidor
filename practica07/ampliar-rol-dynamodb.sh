#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Ampliar rol de servicio para incluir DynamoDB
# El rol rol-ec2-s3-los-rojos ya existe desde la Práctica 02/03.
# Este script le agrega permisos de DynamoDB para que el código Python
# que corre en la EC2 acceda a movimientos_inventario SIN llaves de acceso.
#
# Se ejecuta en AWS CloudShell o desde el usuario admin.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
EQUIPO="los-rojos"
ROL_SERVICIO="rol-ec2-s3-${EQUIPO}"
TABLE_NAME="movimientos_inventario"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TABLE_ARN="arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}"
TABLE_ARN_INDEX="${TABLE_ARN}/index/*"

echo "============================================="
echo " Ampliando rol: ${ROL_SERVICIO}"
echo " Cuenta : ${ACCOUNT_ID}"
echo " Tabla  : ${TABLE_ARN}"
echo "============================================="

# Verificar que el rol existe
aws iam get-role --role-name "${ROL_SERVICIO}" \
  --query "Role.{Nombre:RoleName, ARN:Arn}" --output table

# Añadir política inline de DynamoDB al rol de servicio
POLITICA_DYNAMO='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DynamoDBMovimientosInventario",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable"
      ],
      "Resource": [
        "'"${TABLE_ARN}"'",
        "'"${TABLE_ARN_INDEX}"'"
      ]
    }
  ]
}'

aws iam put-role-policy \
  --role-name "${ROL_SERVICIO}" \
  --policy-name "pol-inline-dynamodb-${EQUIPO}" \
  --policy-document "${POLITICA_DYNAMO}"

echo ""
echo "✔  Política DynamoDB agregada al rol ${ROL_SERVICIO}."
echo ""

# Verificar políticas inline actuales del rol
echo "--- Políticas inline del rol ${ROL_SERVICIO} ---"
aws iam list-role-policies \
  --role-name "${ROL_SERVICIO}" \
  --query "PolicyNames" \
  --output table

# Mostrar el detalle de la política recién añadida
echo ""
echo "--- Detalle: pol-inline-dynamodb-${EQUIPO} ---"
aws iam get-role-policy \
  --role-name "${ROL_SERVICIO}" \
  --policy-name "pol-inline-dynamodb-${EQUIPO}" \
  --query "PolicyDocument.Statement[*].{Sid:Sid, Effect:Effect, Acciones:Action}" \
  --output table

echo ""
echo "✔  Rol listo. La EC2 (con este Instance Profile) puede:"
echo "   PutItem, GetItem, UpdateItem, DeleteItem, Query, Scan, DescribeTable"
echo "   Solo sobre la tabla '${TABLE_NAME}' y sus índices."
echo "   *** TOMAR CAPTURA AQUÍ — muestra las 2 políticas inline del rol ***"
