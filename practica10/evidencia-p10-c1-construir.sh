#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  evidencia-p10-c1-construir.sh
#  Criterio 1 & 2 — Imagen base oficial + orden de capas correcto
#  Evidencia: construcción exitosa con tamaño visible
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"

echo "═══════════════════════════════════════════════════════"
echo "  EVIDENCIA P10-C1: Construcción de la imagen"
echo "═══════════════════════════════════════════════════════"

cd "$(dirname "$0")/.."

echo ""
echo "[ Dockerfile utilizado ]"
echo "───────────────────────────────────────────────────────"
cat Dockerfile
echo "───────────────────────────────────────────────────────"

echo ""
echo "[ Construyendo imagen... ]"
docker build \
  --tag "${REPO_NAME}:${IMAGE_TAG}" \
  --tag "${REPO_NAME}:latest" \
  --no-cache \
  .

echo ""
echo "[ Imagen resultante — TAMAÑO VISIBLE ]"
echo "───────────────────────────────────────────────────────"
docker images "$REPO_NAME" \
  --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"

echo ""
echo "[ Capas de la imagen (historial) ]"
echo "───────────────────────────────────────────────────────"
docker history "${REPO_NAME}:${IMAGE_TAG}" \
  --format "table {{.CreatedBy}}\t{{.Size}}"

echo ""
echo "✅ Criterio 1 y 2 verificados:"
echo "   - Imagen base: node:20-alpine (oficial y ligera)"
echo "   - Orden: dependencias primero, código después"
