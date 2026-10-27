#!/bin/bash
# =============================================================================
# PRÁCTICA 09 — Lambda + API Gateway HTTP API · Equipo Los Rojos
# Sistema: Inventario Nube
#
# Qué hace este script:
#   1. Crea el Execution Role de Lambda (distinto del rol de EC2)
#   2. Agrega permisos DynamoDB al Execution Role
#   3. Empaqueta lambda_function.py en un ZIP
#   4. Crea la función Lambda (128 MB, 10 s, Python 3.12)
#   5. Crea una API Gateway HTTP API (v2) con ruta GET /movimientos/{producto_id}
#   6. Crea la integración Lambda-proxy y la ruta pública
#   7. Despliega la API (stage $default → auto-deploy)
#   8. Muestra la URL pública final
#
# Cómo usar:
#   Pega en AWS CloudShell y presiona Enter.
#   No requiere llaves de acceso: corre con el rol de CloudShell.
# =============================================================================

set -euo pipefail

# ── Variables del proyecto ───────────────────────────────────────────────────
REGION="us-east-1"
EQUIPO="los-rojos"
PROYECTO="inventario-cloud"
TABLE_NAME="movimientos_inventario"
FUNCION="fn-movimientos-${EQUIPO}"
EXECUTION_ROLE="rol-lambda-${EQUIPO}"
POLICY_NAME="pol-lambda-dynamodb-${EQUIPO}"
API_NAME="api-${PROYECTO}-${EQUIPO}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TABLE_ARN="arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  PRÁCTICA 09 — Lambda + API Gateway"
echo "  Equipo  : Los Rojos"
echo "  Función : ${FUNCION}"
echo "  API     : ${API_NAME}"
echo "  Cuenta  : ${ACCOUNT_ID}"
echo "  Región  : ${REGION}"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# =============================================================================
# PASO 1 — Execution Role de Lambda
# IMPORTANTE: El rol de Lambda es DISTINTO al rol de EC2 (ip-rol-ec2-s3-los-rojos).
# Lambda necesita su propio rol de ejecución con permisos específicos.
# =============================================================================
echo "=== [1/8] Execution Role de Lambda ==="

# Trust policy: permite que el servicio Lambda asuma este rol
TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_EXISTS=$(aws iam get-role \
  --role-name "${EXECUTION_ROLE}" \
  --query "Role.RoleName" --output text 2>/dev/null || echo "NO_EXISTE")

if [ "${ROLE_EXISTS}" = "NO_EXISTE" ]; then
  ROLE_ARN=$(aws iam create-role \
    --role-name "${EXECUTION_ROLE}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "Execution role para Lambda P09 - Inventario Nube Los Rojos" \
    --query "Role.Arn" --output text)
  echo "✔ Rol creado: ${ROLE_ARN}"
else
  ROLE_ARN=$(aws iam get-role \
    --role-name "${EXECUTION_ROLE}" \
    --query "Role.Arn" --output text)
  echo "· Rol ya existe: ${ROLE_ARN}"
fi

# Política managed: logs en CloudWatch (requerida para la bitácora del paso 4)
aws iam attach-role-policy \
  --role-name "${EXECUTION_ROLE}" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
  2>/dev/null || echo "· AWSLambdaBasicExecutionRole ya adjunta"

echo "✔ Política de CloudWatch Logs adjunta"
echo ""

# =============================================================================
# PASO 2 — Política inline DynamoDB para Lambda
# =============================================================================
echo "=== [2/8] Permisos DynamoDB para el Execution Role ==="

DYNAMO_POLICY="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"LambdaQueryDynamoDB\",
    \"Effect\": \"Allow\",
    \"Action\": [
      \"dynamodb:Query\",
      \"dynamodb:GetItem\",
      \"dynamodb:DescribeTable\"
    ],
    \"Resource\": [
      \"${TABLE_ARN}\",
      \"${TABLE_ARN}/index/*\"
    ]
  }]
}"

aws iam put-role-policy \
  --role-name "${EXECUTION_ROLE}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document "${DYNAMO_POLICY}"

echo "✔ Política DynamoDB (Query, GetItem, DescribeTable) adjunta al rol Lambda"
echo "  Recurso: ${TABLE_ARN}"
echo ""

# Esperar propagación de IAM (evita error "role not ready" al crear Lambda)
echo "  Esperando propagación IAM (10 s)..."
sleep 10

# =============================================================================
# PASO 3 — Empaquetar la función
# =============================================================================
echo "=== [3/8] Empaquetar lambda_function.py ==="

# El script asume que se ejecuta desde la raíz del repo o desde practica09/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_SRC="${SCRIPT_DIR}/lambda_function.py"

if [ ! -f "${LAMBDA_SRC}" ]; then
  echo "❌ No se encontró ${LAMBDA_SRC}"
  echo "   Asegúrate de clonar el repositorio antes de ejecutar este script."
  exit 1
fi

ZIP_FILE="/tmp/fn-movimientos-${EQUIPO}.zip"
cd /tmp
cp "${LAMBDA_SRC}" lambda_function.py
zip -j "${ZIP_FILE}" lambda_function.py
rm -f lambda_function.py
cd - > /dev/null

echo "✔ Empaquetado: ${ZIP_FILE} ($(du -h ${ZIP_FILE} | cut -f1))"
echo ""

# =============================================================================
# PASO 4 — Crear o actualizar la función Lambda
# =============================================================================
echo "=== [4/8] Función Lambda (128 MB, 10 s, Python 3.12) ==="

FN_EXISTS=$(aws lambda get-function \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --query "Configuration.FunctionName" --output text 2>/dev/null || echo "NO_EXISTE")

if [ "${FN_EXISTS}" = "NO_EXISTE" ]; then
  aws lambda create-function \
    --function-name "${FUNCION}" \
    --runtime "python3.12" \
    --role "${ROLE_ARN}" \
    --handler "lambda_function.lambda_handler" \
    --zip-file "fileb://${ZIP_FILE}" \
    --timeout 10 \
    --memory-size 128 \
    --environment "Variables={REGION=${REGION},TABLE_NAME=${TABLE_NAME},MAX_ITEMS=50}" \
    --description "P09 Los Rojos: consulta movimientos inventario en DynamoDB" \
    --tags "Equipo=LosRojos,Proyecto=InventarioNube,Practica=P09" \
    --region "${REGION}" \
    --output table \
    --query "Configuration.{Nombre:FunctionName,Rol:Role,Memoria:MemorySize,Timeout:Timeout,Runtime:Runtime}"

  echo ""
  echo "  Esperando que la función esté activa..."
  aws lambda wait function-active \
    --function-name "${FUNCION}" \
    --region "${REGION}"
  echo "✔ Función creada y activa"

else
  echo "· Función ya existe. Actualizando código..."
  aws lambda update-function-code \
    --function-name "${FUNCION}" \
    --zip-file "fileb://${ZIP_FILE}" \
    --region "${REGION}" \
    --query "Configuration.{Nombre:FunctionName,Estado:State}" \
    --output table
  echo "✔ Código actualizado"
fi

# Mostrar configuración actual
echo ""
echo "--- Configuración actual de la función ---"
aws lambda get-function-configuration \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --query "{Nombre:FunctionName,Runtime:Runtime,Memoria:MemorySize,Timeout:Timeout,Rol:Role,Estado:State}" \
  --output table
echo ""
echo "  *** ANOTA: Memoria=128 MB, Timeout=10 s — estos determinan el costo ***"
echo ""

# =============================================================================
# PASO 5 — Prueba directa desde consola (evento de ejemplo)
# =============================================================================
echo "=== [5/8] Prueba directa con evento de ejemplo (PASO 3 DE LA PRÁCTICA) ==="

EVENTO_TEST='{
  "httpMethod": "GET",
  "path": "/movimientos/PROD-0042",
  "pathParameters": {"producto_id": "PROD-0042"},
  "queryStringParameters": null,
  "headers": {},
  "requestContext": {}
}'

echo "${EVENTO_TEST}" > /tmp/test_event.json

RESULTADO=$(aws lambda invoke \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --payload file:///tmp/test_event.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/test_output.json \
  --query "{StatusCode:StatusCode,FunctionError:FunctionError}" \
  --output json)

echo "  Respuesta Lambda: ${RESULTADO}"
echo "  Body de la respuesta:"
cat /tmp/test_output.json | python3 -m json.tool 2>/dev/null || cat /tmp/test_output.json
echo ""
echo "  *** TOMAR CAPTURA AQUÍ — Criterio C2: función ejecuta correctamente ***"
echo ""

# =============================================================================
# PASO 6 — API Gateway HTTP API (v2)
# =============================================================================
echo "=== [6/8] API Gateway HTTP API ==="

API_ID=$(aws apigatewayv2 get-apis \
  --region "${REGION}" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text 2>/dev/null || echo "None")

if [ "${API_ID}" = "None" ] || [ -z "${API_ID}" ]; then
  API_ID=$(aws apigatewayv2 create-api \
    --name "${API_NAME}" \
    --protocol-type HTTP \
    --cors-configuration \
        AllowOrigins="*" \
        AllowMethods="GET,OPTIONS" \
        AllowHeaders="Content-Type,Authorization" \
    --description "P09 Los Rojos: API pública para consulta de inventario" \
    --region "${REGION}" \
    --query "ApiId" --output text)
  echo "✔ API creada: ${API_ID}"
else
  echo "· API ya existe: ${API_ID}"
fi

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --query "Configuration.FunctionArn" --output text)

# =============================================================================
# PASO 7 — Integración y rutas
# =============================================================================
echo ""
echo "=== [7/8] Integración Lambda-proxy y ruta GET /movimientos/{producto_id} ==="

INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "${API_ID}" \
  --integration-type AWS_PROXY \
  --integration-uri "${LAMBDA_ARN}" \
  --payload-format-version "2.0" \
  --region "${REGION}" \
  --query "IntegrationId" --output text)
echo "✔ Integración creada: ${INTEGRATION_ID}"

# Ruta principal: GET /movimientos/{producto_id}
aws apigatewayv2 create-route \
  --api-id "${API_ID}" \
  --route-key "GET /movimientos/{producto_id}" \
  --target "integrations/${INTEGRATION_ID}" \
  --region "${REGION}" \
  --query "RouteId" --output text > /dev/null
echo "✔ Ruta creada: GET /movimientos/{producto_id}"

# Ruta de stock: GET /movimientos/{producto_id}/stock
aws apigatewayv2 create-route \
  --api-id "${API_ID}" \
  --route-key "GET /movimientos/{producto_id}/stock" \
  --target "integrations/${INTEGRATION_ID}" \
  --region "${REGION}" \
  --query "RouteId" --output text > /dev/null
echo "✔ Ruta creada: GET /movimientos/{producto_id}/stock"

# Stage $default con auto-deploy
aws apigatewayv2 create-stage \
  --api-id "${API_ID}" \
  --stage-name '$default' \
  --auto-deploy \
  --region "${REGION}" \
  --query "StageName" --output text > /dev/null 2>&1 || \
  echo "· Stage \$default ya existe"
echo "✔ Stage \$default con auto-deploy activo"

# Permiso para que API Gateway invoque la Lambda
aws lambda add-permission \
  --function-name "${FUNCION}" \
  --statement-id "apigw-invoke-${EQUIPO}" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
  --region "${REGION}" \
  --output text > /dev/null 2>&1 || echo "· Permiso InvokeFunction ya existe"
echo "✔ Permiso lambda:InvokeFunction concedido a API Gateway"
echo ""

# =============================================================================
# PASO 8 — URL final y prueba pública
# =============================================================================
echo "=== [8/8] URL pública y prueba final ==="

API_URL=$(aws apigatewayv2 get-api \
  --api-id "${API_ID}" \
  --region "${REGION}" \
  --query "ApiEndpoint" --output text)

URL_PROD0042="${API_URL}/movimientos/PROD-0042"
URL_PROD0042_STOCK="${API_URL}/movimientos/PROD-0042/stock"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  PRÁCTICA 09 — DESPLIEGUE COMPLETADO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Función Lambda : ${FUNCION}"
echo "  Memoria        : 128 MB"
echo "  Timeout        : 10 s"
echo "  Execution Role : ${EXECUTION_ROLE}"
echo "  API Gateway    : ${API_NAME} (${API_ID})"
echo ""
echo "  ── URLs públicas ──────────────────────────────────────────────"
echo "  Movimientos  : ${URL_PROD0042}"
echo "  Stock actual : ${URL_PROD0042_STOCK}"
echo ""
echo "  ── Prueba rápida con curl ──────────────────────────────────────"
echo "  curl -s '${URL_PROD0042}' | python3 -m json.tool"
echo ""
echo "  ── Prueba desde navegador ──────────────────────────────────────"
echo "  Abre: ${URL_PROD0042}"
echo ""

# Prueba automática con curl
echo "  Probando URL pública (Criterio C3)..."
sleep 3  # esperar propagación del deploy
curl -s "${URL_PROD0042}" | python3 -m json.tool 2>/dev/null \
  || echo "  (respuesta raw)"; curl -s "${URL_PROD0042}"

echo ""
echo "  *** TOMAR CAPTURA AQUÍ — Criterio C3: interfaz pública responde ***"
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  GUARDA ESTOS VALORES PARA LAS EVIDENCIAS:"
echo "  API_ID=${API_ID}"
echo "  API_URL=${API_URL}"
echo "  FUNCION=${FUNCION}"
echo "  ROLE_ARN=${ROLE_ARN}"
echo "════════════════════════════════════════════════════════════════════"
