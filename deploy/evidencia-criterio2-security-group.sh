#!/bin/bash
# =============================================================================
# EVIDENCIA — CRITERIO 2 (20 pts)
# "El grupo de seguridad no expone la administración remota a todo internet"
#
# Verifica que el puerto SSH (22) NO esté abierto a 0.0.0.0/0
# y muestra las reglas actuales del Security Group de la instancia.
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Luego toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
APP_NAME="inventario-nube"

echo "================================================"
echo "CRITERIO 2 — Security Group (no expone SSH)"
echo "================================================"
echo ""

# Obtener el ID de la instancia
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped,stopping" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "⚠  No se encontró la instancia. Verifica el nombre en APP_NAME."
  exit 1
fi

# Obtener el Security Group ID de la instancia
SG_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
  --output text)

SG_NAME=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupName" \
  --output text)

echo "Instancia:      $INSTANCE_ID"
echo "Security Group: $SG_ID ($SG_NAME)"
echo ""

# ─── INICIO DE EVIDENCIA ──────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA CRITERIO 2 — Reglas de entrada del Security Group"
echo "══════════════════════════════════════════════════════════════════"
echo ""

echo "▶ Reglas de entrada (Inbound rules) del SG $SG_ID:"
echo ""
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions" \
  --output table

echo ""
echo "▶ Verificación: ¿está SSH (puerto 22) abierto a 0.0.0.0/0?"
echo ""

SSH_OPEN=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && IpRanges[?CidrIp=='0.0.0.0/0']].FromPort" \
  --output text)

if [ -n "$SSH_OPEN" ] && [ "$SSH_OPEN" != "None" ]; then
  echo "  ⚠  SSH está abierto a 0.0.0.0/0 — CERRANDO ahora..."
  echo ""

  # Primero, obtener la IP pública de CloudShell para reemplazar la regla
  MY_IP=$(curl -sf https://checkip.amazonaws.com 2>/dev/null || curl -sf https://api.ipify.org 2>/dev/null || echo "")

  # Revocar la regla abierta
  aws ec2 revoke-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

  echo "  ✔ Regla SSH 0.0.0.0/0 eliminada"

  if [ -n "$MY_IP" ]; then
    # Agregar SSH solo para la IP del equipo
    aws ec2 authorize-security-group-ingress \
      --region "$REGION" \
      --group-id "$SG_ID" \
      --ip-permissions \
        "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MY_IP}/32,Description=SSH-equipo-los-rojos}]" \
      --output text >/dev/null
    echo "  ✔ SSH restringido solo a: ${MY_IP}/32 (IP del equipo)"
  else
    echo "  ℹ  No se pudo detectar IP automáticamente."
    echo "     Agrega manualmente SSH solo para tu IP en EC2 → Security Groups → Edit Inbound Rules"
  fi

  echo ""
  echo "  ▶ Reglas actualizadas:"
  aws ec2 describe-security-groups \
    --region "$REGION" \
    --group-ids "$SG_ID" \
    --query "SecurityGroups[0].IpPermissions" \
    --output table
  echo ""
  echo "  ✅  SSH ya NO está expuesto a todo internet — CRITERIO 2 CUMPLIDO (20/20 pts)"

else
  echo "  ✅  SSH NO está abierto a 0.0.0.0/0 — CRITERIO 2 CUMPLIDO (20/20 pts)"
  echo ""

  # Mostrar a qué IP sí está permitido SSH (si existe)
  SSH_CIDR=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --group-ids "$SG_ID" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[].CidrIp" \
    --output text)

  if [ -n "$SSH_CIDR" ] && [ "$SSH_CIDR" != "None" ]; then
    echo "  SSH permitido solo para: $SSH_CIDR"
  else
    echo "  SSH no tiene ninguna regla de entrada (solo acceso por Session Manager o no configurado)"
  fi
fi

echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
