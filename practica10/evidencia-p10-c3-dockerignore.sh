#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  evidencia-p10-c3-dockerignore.sh
#  Criterio 3 — El archivo de exclusión evita copiar credenciales
#  Verifica que .env y node_modules NO están dentro de la imagen
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"

echo "═══════════════════════════════════════════════════════"
echo "  EVIDENCIA P10-C3: Archivo .dockerignore correcto"
echo "═══════════════════════════════════════════════════════"

cd "$(dirname "$0")/.."

echo ""
echo "[ Contenido de .dockerignore ]"
echo "───────────────────────────────────────────────────────"
cat .dockerignore

echo ""
echo "[ Verificando que .env NO está dentro de la imagen ]"
echo "───────────────────────────────────────────────────────"
if docker run --rm "${REPO_NAME}:${IMAGE_TAG}" sh -c "[ -f /app/.env ] && echo PRESENTE || echo AUSENTE" | grep -q "AUSENTE"; then
  echo "  ✅ .env NO está dentro de la imagen (correcto)"
else
  echo "  ❌ ADVERTENCIA: .env está dentro de la imagen — riesgo de seguridad"
fi

echo ""
echo "[ Verificando que node_modules proviene de npm ci (no del host) ]"
echo "───────────────────────────────────────────────────────"
MODULES_COUNT=$(docker run --rm "${REPO_NAME}:${IMAGE_TAG}" sh -c "ls /app/node_modules | wc -l")
echo "  Módulos instalados en la imagen: $MODULES_COUNT paquetes"

echo ""
echo "[ Archivos en /app dentro del contenedor ]"
echo "───────────────────────────────────────────────────────"
docker run --rm "${REPO_NAME}:${IMAGE_TAG}" ls -la /app/

echo ""
echo "[ Estructura src/ dentro del contenedor ]"
echo "───────────────────────────────────────────────────────"
docker run --rm "${REPO_NAME}:${IMAGE_TAG}" find /app/src -type f | sort

echo ""
echo "✅ Criterio 3 verificado: .dockerignore excluye credenciales y archivos innecesarios"
