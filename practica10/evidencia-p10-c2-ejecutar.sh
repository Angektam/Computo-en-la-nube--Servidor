#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  evidencia-p10-c2-ejecutar.sh
#  Criterio 4 — La aplicación responde desde el contenedor
#  Mapea el puerto y verifica /health
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"
CONTAINER="inventario-p10"
PORT=3000

echo "═══════════════════════════════════════════════════════"
echo "  EVIDENCIA P10-C2: Aplicación respondiendo desde el contenedor"
echo "═══════════════════════════════════════════════════════"

cd "$(dirname "$0")/.."

# Limpiar si ya corre
docker rm -f "$CONTAINER" 2>/dev/null || true

echo ""
echo "[ Iniciando contenedor con variables de entorno ]"
echo "  Imagen    : ${REPO_NAME}:${IMAGE_TAG}"
echo "  Puerto    : $PORT → $PORT"
echo "  .env file : $(pwd)/.env"
echo ""

docker run \
  --name "$CONTAINER" \
  --detach \
  --publish ${PORT}:${PORT} \
  --env NODE_ENV=production \
  --env PORT=${PORT} \
  --env-file .env \
  "${REPO_NAME}:${IMAGE_TAG}"

echo "  Esperando que la aplicación arranque (5 seg)..."
sleep 5

echo ""
echo "[ Estado del contenedor ]"
echo "───────────────────────────────────────────────────────"
docker ps --filter "name=$CONTAINER" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "[ Verificación de /health ]"
echo "───────────────────────────────────────────────────────"
HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" \
  http://localhost:${PORT}/health 2>/dev/null || echo "000")

echo "  HTTP Status : $HTTP_CODE"
echo "  Respuesta   :"
cat /tmp/health_response.json 2>/dev/null || echo "(sin respuesta)"

echo ""
echo "[ Logs del contenedor ]"
echo "───────────────────────────────────────────────────────"
docker logs "$CONTAINER" --tail 15

echo ""
echo "[ Inspección — Variables de entorno activas (sin secretos) ]"
echo "───────────────────────────────────────────────────────"
docker inspect "$CONTAINER" \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -v "PASSWORD\|SECRET\|KEY\|TOKEN" || true

echo ""
if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Criterio 4 verificado: la aplicación responde HTTP 200 desde el contenedor"
else
  echo "⚠️  La aplicación respondió HTTP $HTTP_CODE — revisa los logs arriba"
fi

echo ""
echo "[ Para detener el contenedor ejecuta: ]"
echo "  docker stop $CONTAINER && docker rm $CONTAINER"
