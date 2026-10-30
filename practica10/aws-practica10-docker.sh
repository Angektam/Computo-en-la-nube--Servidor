#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
#  aws-practica10-docker.sh — Script principal de la Práctica 10
#  Construye, ejecuta localmente y publica la imagen en Amazon ECR.
#  Equipo Los Rojos · Cómputo en la Nube · UAS · Octubre 2026
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuración ───────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"
IMAGE_NAME="${REPO_NAME}:${IMAGE_TAG}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_URI}/${IMAGE_NAME}"

echo "================================================================"
echo "  PRÁCTICA 10 — Contenerizar inventario-nube"
echo "  Cuenta AWS : $AWS_ACCOUNT_ID"
echo "  Región     : $AWS_REGION"
echo "  Imagen     : $IMAGE_NAME"
echo "================================================================"

# ══════════════════════════════════════════════════════════════════════
# PASO 1 — Verificar prerrequisitos
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 1 ] Verificando prerrequisitos..."

command -v docker  >/dev/null 2>&1 || { echo "ERROR: Docker no está instalado."; exit 1; }
command -v aws     >/dev/null 2>&1 || { echo "ERROR: AWS CLI no está instalado."; exit 1; }

echo "  ✅ Docker   : $(docker --version)"
echo "  ✅ AWS CLI  : $(aws --version)"
echo "  ✅ Prerrequisitos OK"

# ══════════════════════════════════════════════════════════════════════
# PASO 2 — Construir la imagen
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 2 ] Construyendo imagen Docker..."
echo "  Etiqueta: $IMAGE_NAME"

# Nos movemos a la raíz del proyecto donde vive el Dockerfile
cd "$(dirname "$0")/.."

docker build \
  --tag "$IMAGE_NAME" \
  --tag "${REPO_NAME}:latest" \
  --label "maintainer=LosRojos" \
  --label "version=${IMAGE_TAG}" \
  --label "proyecto=inventario-nube" \
  .

echo ""
echo "  ✅ Imagen construida exitosamente"
echo ""
echo "  [ Tamaño de la imagen ]"
docker images "$REPO_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# ══════════════════════════════════════════════════════════════════════
# PASO 3 — Ejecutar localmente para verificar
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 3 ] Ejecutando contenedor localmente..."

# Detener y eliminar si ya existe un contenedor con ese nombre
docker rm -f inventario-test 2>/dev/null || true

docker run \
  --name inventario-test \
  --detach \
  --publish 3000:3000 \
  --env NODE_ENV=production \
  --env PORT=3000 \
  --env-file .env \
  "$IMAGE_NAME"

echo "  ✅ Contenedor iniciado — esperando 3 segundos para que arranque..."
sleep 3

echo ""
echo "  [ Estado del contenedor ]"
docker ps --filter "name=inventario-test" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "  [ Verificando /health ]"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "FALLO")
if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✅ /health respondió HTTP $HTTP_STATUS"
  curl -s http://localhost:3000/health | head -5
else
  echo "  ⚠️  /health respondió HTTP $HTTP_STATUS"
  echo "  [ Logs del contenedor ]"
  docker logs inventario-test --tail 20
fi

echo ""
echo "  [ Logs del contenedor ]"
docker logs inventario-test --tail 10

# ══════════════════════════════════════════════════════════════════════
# PASO 4 — Detener el contenedor de prueba
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 4 ] Deteniendo contenedor de prueba..."
docker stop inventario-test
docker rm   inventario-test
echo "  ✅ Contenedor de prueba eliminado"

# ══════════════════════════════════════════════════════════════════════
# PASO 5 — Crear repositorio ECR (si no existe)
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 5 ] Creando repositorio privado en Amazon ECR..."

if aws ecr describe-repositories --repository-names "$REPO_NAME" \
   --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  ℹ️  El repositorio '$REPO_NAME' ya existe"
else
  aws ecr create-repository \
    --repository-name "$REPO_NAME" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --tags Key=Proyecto,Value=inventario-nube \
           Key=Equipo,Value=LosRojos \
           Key=Practica,Value=P10
  echo "  ✅ Repositorio '$REPO_NAME' creado en ECR"
fi

echo ""
echo "  [ URI del repositorio ]"
aws ecr describe-repositories \
  --repository-names "$REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'repositories[0].repositoryUri' \
  --output text

# ══════════════════════════════════════════════════════════════════════
# PASO 6 — Autenticarse en ECR y publicar la imagen
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "[ PASO 6 ] Autenticándose en ECR y publicando imagen..."

# Obtener token de autenticación (válido 12 horas)
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_URI"

echo "  ✅ Autenticación exitosa"

# Etiquetar la imagen con la URI completa de ECR
docker tag "$IMAGE_NAME"         "$FULL_IMAGE"
docker tag "${REPO_NAME}:latest" "${ECR_URI}/${REPO_NAME}:latest"

# Publicar ambas etiquetas
echo "  Subiendo $FULL_IMAGE ..."
docker push "$FULL_IMAGE"
docker push "${ECR_URI}/${REPO_NAME}:latest"

echo ""
echo "  ✅ Imagen publicada en ECR"
echo ""
echo "  [ Imágenes en el registro ]"
aws ecr list-images \
  --repository-name "$REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'imageIds[*]' \
  --output table

echo ""
echo "================================================================"
echo "  ✅ PRÁCTICA 10 COMPLETADA"
echo "  Imagen : $FULL_IMAGE"
echo "  Para desplegar en ECS (Práctica 11):"
echo "    $FULL_IMAGE"
echo "================================================================"
