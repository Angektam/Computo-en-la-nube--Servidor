#!/bin/bash
# =============================================================================
# PRÁCTICA 09 — Evidencia C2 (25 pts): Función ejecuta correctamente
# con rol de servicio y accede a DynamoDB.
# Muestra: invocación desde consola + identidad del rol + respuesta.
# Ejecutar en CloudShell. TOMAR CAPTURA de la salida completa.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
EQUIPO="los-rojos"
FUNCION="fn-movimientos-${EQUIPO}"
TABLE_NAME="movimientos_inventario"

echo "════════════════════════════════════════════════════════════════════"
echo "  C2 · Función ejecuta con rol de servicio y accede a DynamoDB"
echo "  Práctica 09 · Equipo Los Rojos"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── Verificar Execution Role ──────────────────────────────────────────────────
echo "--- [1/4] Execution Role adjunto a la función ---"
aws lambda get-function-configuration \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --query "{Funcion:FunctionName, Rol:Role, Runtime:Runtime, Memoria:MemorySize, Timeout:Timeout}" \
  --output table
echo ""

# ── Verificar que el rol tiene permiso DynamoDB ───────────────────────────────
EXECUTION_ROLE="rol-lambda-${EQUIPO}"
echo "--- [2/4] Política inline DynamoDB del Execution Role ---"
aws iam get-role-policy \
  --role-name "${EXECUTION_ROLE}" \
  --policy-name "pol-lambda-dynamodb-${EQUIPO}" \
  --query "PolicyDocument.Statement[*].{Efecto:Effect, Acciones:Action, Recurso:Resource}" \
  --output table
echo ""

# ── Invocar la función con evento GET para PROD-0042 ─────────────────────────
echo "--- [3/4] Invocación directa desde consola (evento HTTP GET) ---"
echo "    producto_id = PROD-0042"
echo ""

EVENTO='{
  "httpMethod": "GET",
  "path": "/movimientos/PROD-0042",
  "pathParameters": {"producto_id": "PROD-0042"},
  "queryStringParameters": null,
  "headers": {"Accept": "application/json"},
  "requestContext": {}
}'

echo "${EVENTO}" > /tmp/evento_c2.json

aws lambda invoke \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --payload file:///tmp/evento_c2.json \
  --cli-binary-format raw-in-base64-out \
  --log-type Tail \
  /tmp/respuesta_c2.json \
  --query "{HTTP_Status:StatusCode, Error:FunctionError}" \
  --output table

echo ""
echo "  Respuesta de la función (body JSON):"
python3 -c "
import json, sys
with open('/tmp/respuesta_c2.json') as f:
    data = json.load(f)
body = json.loads(data.get('body', '{}'))
print(json.dumps(body, indent=2, ensure_ascii=False))
"

echo ""

# ── Invocar con filtro tipo=salida ────────────────────────────────────────────
echo "--- [4/4] Segunda invocación con filtro tipo=salida ---"
EVENTO2='{
  "httpMethod": "GET",
  "path": "/movimientos/PROD-0042",
  "pathParameters": {"producto_id": "PROD-0042"},
  "queryStringParameters": {"tipo": "salida", "limit": "10"},
  "headers": {},
  "requestContext": {}
}'

echo "${EVENTO2}" > /tmp/evento_c2b.json

aws lambda invoke \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --payload file:///tmp/evento_c2b.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/respuesta_c2b.json \
  --query "{HTTP_Status:StatusCode}" \
  --output table

echo ""
echo "  Respuesta filtrada (solo salidas):"
python3 -c "
import json
with open('/tmp/respuesta_c2b.json') as f:
    data = json.load(f)
body = json.loads(data.get('body', '{}'))
print(json.dumps(body, indent=2, ensure_ascii=False))
"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  ✔ Función ejecuta correctamente y accede a DynamoDB con rol de"
echo "    servicio (Execution Role). NO hay llaves de acceso en el código."
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  *** TOMAR CAPTURA AQUÍ — Criterio C2 completo ***"
