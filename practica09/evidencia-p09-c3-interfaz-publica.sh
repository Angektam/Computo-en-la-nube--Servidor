#!/bin/bash
# =============================================================================
# PRÁCTICA 09 — Evidencia C3 (20 pts): Interfaz pública responde
# Prueba la API Gateway desde curl y muestra la URL para el navegador.
# Ejecutar en CloudShell. TOMAR CAPTURA de la salida completa.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
EQUIPO="los-rojos"
API_NAME="api-inventario-cloud-${EQUIPO}"
FUNCION="fn-movimientos-${EQUIPO}"

echo "════════════════════════════════════════════════════════════════════"
echo "  C3 · Interfaz pública API Gateway — respuesta verificada"
echo "  Práctica 09 · Equipo Los Rojos"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── Obtener URL de la API ─────────────────────────────────────────────────────
API_ID=$(aws apigatewayv2 get-apis \
  --region "${REGION}" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text)

if [ -z "${API_ID}" ] || [ "${API_ID}" = "None" ]; then
  echo "❌ API '${API_NAME}' no encontrada. Ejecuta primero aws-practica09-lambda.sh"
  exit 1
fi

API_URL=$(aws apigatewayv2 get-api \
  --api-id "${API_ID}" \
  --region "${REGION}" \
  --query "ApiEndpoint" --output text)

echo "--- [1/5] Datos de la API Gateway ---"
aws apigatewayv2 get-api \
  --api-id "${API_ID}" \
  --region "${REGION}" \
  --query "{Nombre:Name, ID:ApiId, Protocolo:ProtocolType, URL:ApiEndpoint, Estado:ApiGatewayManaged}" \
  --output table
echo ""

echo "--- [2/5] Rutas configuradas ---"
aws apigatewayv2 get-routes \
  --api-id "${API_ID}" \
  --region "${REGION}" \
  --query "Items[*].{Ruta:RouteKey, Estado:ApiGatewayManaged}" \
  --output table
echo ""

echo "--- [3/5] Prueba GET /movimientos/PROD-0042 ---"
URL_TEST="${API_URL}/movimientos/PROD-0042"
echo "  URL: ${URL_TEST}"
echo ""
echo "  Respuesta HTTP completa:"
curl -s -w "\n  HTTP Status: %{http_code}\n  Tiempo total: %{time_total}s\n" \
  -H "Accept: application/json" \
  "${URL_TEST}" | python3 -m json.tool 2>/dev/null || \
  curl -s "${URL_TEST}"
echo ""

echo "--- [4/5] Prueba GET /movimientos/PROD-0042/stock ---"
URL_STOCK="${API_URL}/movimientos/PROD-0042/stock"
echo "  URL: ${URL_STOCK}"
echo ""
curl -s -w "\n  HTTP Status: %{http_code}\n  Tiempo total: %{time_total}s\n" \
  "${URL_STOCK}" | python3 -m json.tool 2>/dev/null || \
  curl -s "${URL_STOCK}"
echo ""

echo "--- [5/5] Prueba producto inexistente (debe devolver 404) ---"
URL_404="${API_URL}/movimientos/PROD-9999"
echo "  URL: ${URL_404}"
echo ""
curl -s -w "\n  HTTP Status: %{http_code}\n" \
  "${URL_404}" | python3 -m json.tool 2>/dev/null || \
  curl -s "${URL_404}"
echo ""

echo "════════════════════════════════════════════════════════════════════"
echo "  URLs para abrir en el NAVEGADOR (Criterio C3):"
echo ""
echo "  ${URL_TEST}"
echo "  ${URL_STOCK}"
echo ""
echo "  Copia cualquiera de esas URLs y pégala en Chrome/Firefox."
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  *** TOMAR CAPTURA AQUÍ y también del navegador ***"
echo "  *** Criterio C3 completo ***"
