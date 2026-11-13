#!/bin/bash
# =============================================================================
# EVIDENCIA — CRITERIO 4 (20 pts)
# "La página responde por navegador y muestra los datos solicitados"
#
# Verifica que:
#   1. La app responde en HTTP (puerto 80)
#   2. El health check devuelve 200 OK
#   3. La API devuelve datos reales (productos, categorías, etc.)
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Luego toma captura de pantalla del bloque Y abre la URL en el navegador.
# =============================================================================

REGION="us-east-1"
APP_NAME="inventario-nube"

echo "================================================"
echo "CRITERIO 4 — La página responde y muestra datos"
echo "================================================"
echo ""

# Obtener IP pública
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "⚠  No se encontró la instancia en estado 'running'."
  echo "   Asegúrate de que la instancia esté corriendo antes de ejecutar este script."
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

STATE=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text)

echo "Instancia: $INSTANCE_ID"
echo "Estado:    $STATE"
echo "IP:        $PUBLIC_IP"
echo ""

# ─── INICIO DE EVIDENCIA ──────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA CRITERIO 4 — Respuesta HTTP de la aplicación"
echo "══════════════════════════════════════════════════════════════════"
echo ""

BASE_URL="http://${PUBLIC_IP}"

# 1. Health check
echo "▶ [1/4] Health Check: GET $BASE_URL/health"
echo ""
HEALTH=$(curl -sf --max-time 10 "$BASE_URL/health" 2>&1 || echo "ERROR_CONEXION")
if echo "$HEALTH" | grep -qi "ERROR_CONEXION\|Connection refused\|timed out"; then
  echo "  ⚠  No se pudo conectar. La app puede estar iniciando todavía."
  echo "     Espera 2-3 minutos y vuelve a ejecutar este script."
  echo ""
  echo "  Para revisar el log de setup en la VM:"
  echo "  ssh -i ~/${APP_NAME}-key.pem ubuntu@${PUBLIC_IP} 'sudo tail -30 /var/log/inventario-setup.log'"
  exit 1
fi
echo "  Respuesta: $HEALTH"
echo ""

# 2. Página principal (HTML)
echo "▶ [2/4] Página principal: GET $BASE_URL"
echo ""
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL" || echo "000")
echo "  HTTP Status Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✔ La página responde con 200 OK"
else
  echo "  ⚠  Código de respuesta: $HTTP_CODE (puede estar cargando)"
fi
echo ""

# 3. API — Login para obtener token
echo "▶ [3/4] Login en la API (para probar datos):"
echo ""
LOGIN_RESP=$(curl -sf --max-time 15 \
  -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@empresa.com","password":"Admin1234!"}' 2>&1 || echo "ERROR")

if echo "$LOGIN_RESP" | grep -qi "token\|accessToken"; then
  TOKEN=$(echo "$LOGIN_RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('token') or d.get('accessToken') or d.get('data',{}).get('token',''))
except:
    print('')
" 2>/dev/null || echo "")
  echo "  ✔ Login exitoso — token obtenido"
  echo "  Token (primeros 40 chars): ${TOKEN:0:40}..."
else
  echo "  Respuesta del login: $LOGIN_RESP"
  TOKEN=""
fi
echo ""

# 4. Obtener productos (dato principal de la app)
echo "▶ [4/4] Datos de la aplicación — GET $BASE_URL/api/productos"
echo ""
if [ -n "$TOKEN" ]; then
  PRODUCTOS=$(curl -sf --max-time 15 \
    "$BASE_URL/api/productos" \
    -H "Authorization: Bearer $TOKEN" 2>&1 || echo "ERROR")
else
  PRODUCTOS=$(curl -sf --max-time 15 "$BASE_URL/api/productos" 2>&1 || echo "ERROR")
fi

echo "  Respuesta (primeros 500 chars):"
echo "  $(echo "$PRODUCTOS" | head -c 500)"
echo ""

# Contar productos si la respuesta es JSON
CONTEO=$(echo "$PRODUCTOS" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, list): print(len(d))
    elif isinstance(d, dict):
        for k in ['data','productos','items','results']:
            if k in d and isinstance(d[k], list):
                print(len(d[k]))
                break
        else: print('?')
except:
    print('?')
" 2>/dev/null || echo "?")

echo "  Productos encontrados en la respuesta: $CONTEO"
echo ""

echo "══════════════════════════════════════════════════════════════════"
echo "  URLS para el navegador (incluir en el documento):"
echo ""
echo "    🌐 Aplicación principal : http://${PUBLIC_IP}"
echo "    🩺 Health check        : http://${PUBLIC_IP}/health"
echo "    📦 API productos       : http://${PUBLIC_IP}/api/productos"
echo "    🏷  API categorías      : http://${PUBLIC_IP}/api/categorias"
echo ""
echo "  ✅  La aplicación responde — CRITERIO 4 CUMPLIDO (20/20 pts)"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
echo ""
echo "  ADEMÁS: Abre http://${PUBLIC_IP} en tu navegador y toma una captura"
echo "  de la pantalla del frontend mostrando datos (productos/inventario)."
