#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  evidencia-p10-c4-ecr-publicar.sh
#  Criterio 5 — Imagen publicada y versionada en ECR (registro privado)
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_URI}/${REPO_NAME}:${IMAGE_TAG}"

echo "═══════════════════════════════════════════════════════"
echo "  EVIDENCIA P10-C4: Imagen publicada en Amazon ECR"
echo "═══════════════════════════════════════════════════════"
echo "  Cuenta  : $AWS_ACCOUNT_ID"
echo "  Región  : $AWS_REGION"
echo "  Imagen  : $FULL_IMAGE"

# ── Crear el repositorio privado si no existe ─────────────────────
echo ""
echo "[ Verificando repositorio privado en ECR ]"
if aws ecr describe-repositories \
   --repository-names "$REPO_NAME" \
   --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  ℹ️  Repositorio '$REPO_NAME' ya existe"
else
  echo "  Creando repositorio '$REPO_NAME'..."
  aws ecr create-repository \
    --repository-name "$REPO_NAME" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --tags Key=Proyecto,Value=inventario-nube \
           Key=Equipo,Value=LosRojos \
           Key=Practica,Value=P10
  echo "  ✅ Repositorio creado"
fi

echo ""
echo "[ URI del repositorio ]"
aws ecr describe-repositories \
  --repository-names "$REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'repositories[0]' \
  --output table

# ── Autenticarse en ECR ───────────────────────────────────────────
echo ""
echo "[ Autenticándose en ECR... ]"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_URI"
echo "  ✅ Login exitoso"

# ── Etiquetar y publicar ──────────────────────────────────────────
echo ""
echo "[ Etiquetando imagen... ]"
docker tag "${REPO_NAME}:${IMAGE_TAG}" "$FULL_IMAGE"
docker tag "${REPO_NAME}:latest"       "${ECR_URI}/${REPO_NAME}:latest"

echo ""
echo "[ Publicando versión $IMAGE_TAG... ]"
docker push "$FULL_IMAGE"

echo ""
echo "[ Publicando etiqueta :latest... ]"
docker push "${ECR_URI}/${REPO_NAME}:latest"

# ── Verificar en ECR ──────────────────────────────────────────────
echo ""
echo "[ IMÁGENES EN EL REGISTRO PRIVADO ]"
echo "───────────────────────────────────────────────────────"
aws ecr describe-images \
  --repository-name "$REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'imageDetails[*].{Tag:imageTags[0],Digest:imageDigest,Pushed:imagePushedAt,SizeMB:imageSizeInBytes}' \
  --output table

echo ""
echo "✅ Criterio 5 verificado: imagen '$IMAGE_TAG' publicada y versionada en ECR"
echo ""
echo "  URI completa para Práctica 11 (ECS):"
echo "  $FULL_IMAGE"
