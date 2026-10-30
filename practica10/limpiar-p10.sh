#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  limpiar-p10.sh
#  Elimina contenedores e imágenes de prueba locales.
#  Conserva la imagen final taggeada con la versión.
#  NO elimina imágenes en ECR.
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
REPO_NAME="inventario-nube-losrojos"

echo "═══════════════════════════════════════════════════════"
echo "  LIMPIEZA P10 — Imágenes y contenedores locales"
echo "═══════════════════════════════════════════════════════"

# Detener y eliminar contenedores de prueba
echo ""
echo "[ Deteniendo contenedores de práctica... ]"
for c in inventario-test inventario-p10; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    docker stop "$c" 2>/dev/null || true
    docker rm   "$c" 2>/dev/null || true
    echo "  ✅ Eliminado: $c"
  fi
done

# Mostrar imágenes locales antes de limpiar
echo ""
echo "[ Imágenes locales actuales ]"
docker images "$REPO_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

echo ""
echo "[ Para eliminar TODAS las imágenes locales del proyecto: ]"
echo "  docker rmi \$(docker images '$REPO_NAME' -q) --force"
echo ""
echo "[ Para eliminar solo imágenes colgantes (sin tag): ]"
echo "  docker image prune -f"
echo ""
echo "NOTA: La imagen en ECR NO se elimina con este script."
echo "      Para borrar versiones de prueba en ECR usa:"
echo "  aws ecr batch-delete-image --repository-name $REPO_NAME \\"
echo "    --image-ids imageTag=<tag-a-borrar> --region us-east-1"
