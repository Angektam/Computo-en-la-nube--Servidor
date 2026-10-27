#!/bin/bash
# =============================================================================
# PRÁCTICA 09 — Evidencia C4 (20 pts): Arranque en frío vs warm start
# Mide dos invocaciones: una tras un período de inactividad y otra inmediata.
# Lee los logs de CloudWatch para obtener la duración exacta reportada.
# Ejecutar en CloudShell. TOMAR CAPTURA de la salida completa.
#
# INSTRUCCIÓN IMPORTANTE:
#   Este script debe ejecutarse DESPUÉS de que la función haya estado
#   inactiva varios minutos (al menos 5-10 min sin invocar).
#   Si la función acaba de desplegarse, espera antes de correr este script.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
EQUIPO="los-rojos"
FUNCION="fn-movimientos-${EQUIPO}"
LOG_GROUP="/aws/lambda/${FUNCION}"

echo "════════════════════════════════════════════════════════════════════"
echo "  C4 · Arranque en frío vs Warm Start"
echo "  Práctica 09 · Equipo Los Rojos"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  IMPORTANTE: Este script asume que la función lleva varios"
echo "  minutos sin invocarse (cold start probable)."
echo ""

EVENTO='{
  "httpMethod": "GET",
  "path": "/movimientos/PROD-0042",
  "pathParameters": {"producto_id": "PROD-0042"},
  "queryStringParameters": null,
  "headers": {},
  "requestContext": {}
}'
echo "${EVENTO}" > /tmp/evento_cold.json

# ═════════════════════════════════════════════════════════════════════════════
# INVOCACIÓN 1 — Arranque en frío (cold start)
# ═════════════════════════════════════════════════════════════════════════════
echo "━━━ INVOCACIÓN 1: Cold Start ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_COLD=$(date -u +%s%3N)

aws lambda invoke \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --payload file:///tmp/evento_cold.json \
  --cli-binary-format raw-in-base64-out \
  --log-type Tail \
  /tmp/salida_cold.json \
  --query "LogResult" \
  --output text | base64 -d > /tmp/log_cold.txt 2>/dev/null || true

TS_COLD_END=$(date -u +%s%3N)
ELAPSED_COLD=$(( TS_COLD_END - TS_COLD ))

echo ""
echo "  Tiempo total medido externamente: ${ELAPSED_COLD} ms"
echo ""
echo "  Extracto del log de CloudWatch (REPORT line):"
grep "REPORT\|Init Duration" /tmp/log_cold.txt || echo "  (log no disponible en esta llamada)"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# INVOCACIÓN 2 — Warm Start (inmediatamente después)
# ═════════════════════════════════════════════════════════════════════════════
echo "━━━ INVOCACIÓN 2: Warm Start (inmediata) ━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_WARM=$(date -u +%s%3N)

aws lambda invoke \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --payload file:///tmp/evento_cold.json \
  --cli-binary-format raw-in-base64-out \
  --log-type Tail \
  /tmp/salida_warm.json \
  --query "LogResult" \
  --output text | base64 -d > /tmp/log_warm.txt 2>/dev/null || true

TS_WARM_END=$(date -u +%s%3N)
ELAPSED_WARM=$(( TS_WARM_END - TS_WARM ))

echo ""
echo "  Tiempo total medido externamente: ${ELAPSED_WARM} ms"
echo ""
echo "  Extracto del log de CloudWatch (REPORT line):"
grep "REPORT\|Init Duration" /tmp/log_warm.txt || echo "  (log no disponible en esta llamada)"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# LEER LOGS HISTÓRICOS EN CLOUDWATCH
# ═════════════════════════════════════════════════════════════════════════════
echo "━━━ Logs históricos en CloudWatch (/aws/lambda/${FUNCION}) ━━━━━━━━"
echo ""

# Obtener los últimos eventos del log group
SINCE=$(($(date -u +%s) - 300))000   # últimos 5 minutos en ms

LOG_STREAMS=$(aws logs describe-log-streams \
  --log-group-name "${LOG_GROUP}" \
  --region "${REGION}" \
  --order-by LastEventTime \
  --descending \
  --max-items 3 \
  --query "logStreams[*].logStreamName" \
  --output text 2>/dev/null || echo "")

if [ -n "${LOG_STREAMS}" ]; then
  FIRST_STREAM=$(echo "${LOG_STREAMS}" | awk '{print $1}')
  echo "  Log stream más reciente: ${FIRST_STREAM}"
  echo ""
  aws logs get-log-events \
    --log-group-name "${LOG_GROUP}" \
    --log-stream-name "${FIRST_STREAM}" \
    --region "${REGION}" \
    --start-time "${SINCE}" \
    --query "events[*].message" \
    --output text 2>/dev/null | grep -E "REPORT|Init Duration|START|END" | head -20 || \
    echo "  (sin eventos REPORT en los últimos 5 min)"
else
  echo "  (log group aún no tiene streams — espera unos segundos y vuelve a correr)"
fi

echo ""

# ═════════════════════════════════════════════════════════════════════════════
# RESUMEN COMPARATIVO
# ═════════════════════════════════════════════════════════════════════════════
echo "════════════════════════════════════════════════════════════════════"
echo "  RESUMEN: ARRANQUE EN FRÍO vs WARM START"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Invocación 1 (cold start) : ~${ELAPSED_COLD} ms  (medición externa)"
echo "  Invocación 2 (warm start) : ~${ELAPSED_WARM} ms  (medición externa)"
echo ""
echo "  EXPLICACIÓN DEL ARRANQUE EN FRÍO:"
echo ""
echo "  Cuando una función Lambda no ha sido invocada por varios minutos,"
echo "  AWS libera el entorno de ejecución para asignarlo a otros clientes."
echo "  La siguiente invocación debe:"
echo "    1. Descargar y descomprimir el paquete de código (.zip)"
echo "    2. Iniciar el proceso Python (intérprete + runtime de Lambda)"
echo "    3. Importar las dependencias (boto3, re, json, etc.)"
echo "    4. Ejecutar el código fuera del handler (clientes boto3 globales)"
echo "  Todo esto agrega la 'Init Duration' visible en los logs."
echo ""
echo "  Una vez caliente (warm), las invocaciones siguientes reutilizan el"
echo "  proceso y saltan los pasos 1-4 → latencia significativamente menor."
echo ""
echo "  En el log de CloudWatch, la línea 'REPORT' muestra:"
echo "    Duration     : tiempo que tomó el handler (sin Init)"
echo "    Billed Durat.: redondeado al ms siguiente"
echo "    Init Duration: solo aparece en cold starts"
echo "    Max Memory   : memoria realmente utilizada (útil para el paso 7)"
echo ""
echo "  *** TOMAR CAPTURA AQUÍ — Criterio C4 completo ***"
echo "  *** ANOTA las dos duraciones para el documento de entrega ***"
