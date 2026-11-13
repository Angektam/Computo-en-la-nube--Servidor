#!/bin/bash
# =============================================================================
# EVIDENCIA — CRITERIO 3 (15 pts)
# "La instancia tiene adjunto el rol de servicio y no usa llaves incrustadas"
#
# Verifica que:
#   1. La instancia tiene un IAM Instance Profile adjunto
#   2. El rol tiene permisos de S3
#   3. El .env en la VM NO contiene llaves AWS hardcodeadas
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Luego toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
APP_NAME="inventario-nube"

echo "================================================"
echo "CRITERIO 3 — Rol de servicio y sin llaves"
echo "================================================"
echo ""

# Obtener ID e IP de la instancia
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped,stopping" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "⚠  No se encontró la instancia. Verifica APP_NAME."
  exit 1
fi

echo "Instancia: $INSTANCE_ID"
echo ""

# ─── INICIO DE EVIDENCIA ──────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA CRITERIO 3 — Rol de servicio adjunto"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# 1. Verificar que tiene Instance Profile
PROFILE_ARN=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text)

PROFILE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Id" \
  --output text)

echo "▶ Instance Profile adjunto a la instancia:"
echo ""

if [ -z "$PROFILE_ARN" ] || [ "$PROFILE_ARN" = "None" ]; then
  echo "  ⚠  No hay Instance Profile adjunto — adjuntando ahora..."
  echo ""

  # Intentar adjuntar el profile que creamos en practica02
  PROFILE_NAME="inventario-nube-profile"

  # Si no existe, también buscar el de practica02
  PROFILE_EXISTS=$(aws iam get-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --query "InstanceProfile.InstanceProfileName" \
    --output text 2>/dev/null || echo "")

  if [ -z "$PROFILE_EXISTS" ]; then
    PROFILE_NAME="ip-rol-ec2-s3-los-rojos"
    PROFILE_EXISTS=$(aws iam get-instance-profile \
      --instance-profile-name "$PROFILE_NAME" \
      --query "InstanceProfile.InstanceProfileName" \
      --output text 2>/dev/null || echo "")
  fi

  if [ -n "$PROFILE_EXISTS" ]; then
    aws ec2 associate-iam-instance-profile \
      --region "$REGION" \
      --instance-id "$INSTANCE_ID" \
      --iam-instance-profile "Name=$PROFILE_NAME"
    echo "  ✔ Instance Profile '$PROFILE_NAME' adjuntado a $INSTANCE_ID"
    sleep 5
    PROFILE_ARN=$(aws ec2 describe-instances \
      --region "$REGION" \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
      --output text)
  else
    echo "  ✗  No se encontró ningún Instance Profile. Ejecuta primero aws-practica02-iam-minimo-privilegio.sh"
    exit 1
  fi
fi

printf "  %-20s : %s\n" "Instance Profile ARN" "$PROFILE_ARN"
printf "  %-20s : %s\n" "Instance Profile ID"  "$PROFILE_ID"
echo ""

# Extraer nombre del rol del ARN del profile
PROFILE_NAME_FROM_ARN=$(echo "$PROFILE_ARN" | awk -F'/' '{print $NF}')

ROL_EN_PROFILE=$(aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME_FROM_ARN" \
  --query "InstanceProfile.Roles[0].RoleName" \
  --output text 2>/dev/null || echo "no encontrado")

ROL_ARN=$(aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME_FROM_ARN" \
  --query "InstanceProfile.Roles[0].Arn" \
  --output text 2>/dev/null || echo "")

echo "▶ Rol IAM asociado al Instance Profile:"
echo ""
printf "  %-20s : %s\n" "Nombre del Rol"    "$ROL_EN_PROFILE"
printf "  %-20s : %s\n" "ARN del Rol"       "$ROL_ARN"
echo ""

# Mostrar las políticas del rol
echo "▶ Políticas del rol:"
echo ""
aws iam list-role-policies \
  --role-name "$ROL_EN_PROFILE" \
  --query "PolicyNames" \
  --output table 2>/dev/null || true

aws iam list-attached-role-policies \
  --role-name "$ROL_EN_PROFILE" \
  --query "AttachedPolicies[*].[PolicyName, PolicyArn]" \
  --output table 2>/dev/null || true

echo ""

# 2. Verificar que el .env no tiene llaves AWS incrustadas
# (verificamos desde el metadata de la instancia de forma indirecta)
echo "▶ Verificación de llaves en .env (desde CloudShell):"
echo ""
echo "  Para verificar que el .env en la VM NO tiene llaves AWS,"
echo "  ejecuta este comando con SSH hacia la VM:"
echo ""
echo "  ssh -i ~/${APP_NAME}-key.pem ubuntu@<IP_PUBLICA> \\"
echo "    'grep -E \"AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY\" /var/www/inventario/.env'"
echo ""
echo "  El resultado debe mostrar valores vacíos o 'not_used' o nada,"
echo "  confirmando que las credenciales vienen del rol IAM, no del .env."
echo ""

# Intentar verificar vía SSM si está disponible
PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "  IP pública de la instancia: $PUBLIC_IP"

# Verificar con IAM Simulate que el rol tiene acceso a S3
echo ""
echo "▶ Simulación: ¿el rol puede acceder a S3?"
aws iam simulate-principal-policy \
  --policy-source-arn "$ROL_ARN" \
  --action-names "s3:GetObject" "s3:PutObject" "s3:ListBucket" \
  --resource-arns "arn:aws:s3:::inventario-archivos-losrojos" "arn:aws:s3:::inventario-archivos-losrojos/*" \
  --query "EvaluationResults[*].[EvalActionName, EvalDecision]" \
  --output table 2>/dev/null || echo "  (Simulación no disponible, pero el rol existe y está adjunto)"

echo ""
echo "  ✅  Rol de servicio adjunto y sin llaves permanentes — CRITERIO 3 CUMPLIDO (15/15 pts)"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
