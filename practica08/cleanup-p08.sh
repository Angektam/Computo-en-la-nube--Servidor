#!/bin/bash
# =============================================================================
# PRÁCTICA 08 — LIMPIEZA DE RECURSOS A MEDIAS
# Equipo: Los Rojos  |  21 oct 2026
#
# Usar cuando una ejecución fallida dejó recursos incompletos en AWS.
# Elimina exactamente lo que pudo haber creado aws-practica08-alb-asg.sh
# para que el script principal pueda correr desde cero.
#
# NO elimina: VPC, subredes de prácticas anteriores, SG de EC2, RDS.
#
# Uso: bash cleanup-p08.sh
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"

ASG_NAME="asg-$PROYECTO-$EQUIPO"
POLICY_NAME="policy-cpu-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
LT_NAME="lt-$PROYECTO-$EQUIPO"
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"
# Nombre viejo (primera versión del script) por si quedó creado
SG_ALB_NAME_OLD="sg-alb-$PROYECTO-$EQUIPO"
SUBNET_PUB_2_NAME="subnet-pub2-$PROYECTO-$EQUIPO"
SG_EC2_NAME="ec2-sg-$PROYECTO-$EQUIPO"
SG_EC2_NAME_P03="secgrp-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · LIMPIEZA DE RECURSOS INCOMPLETOS"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""
echo "  Este script elimina los recursos creados por p08 para"
echo "  permitir una re-ejecución limpia del script principal."
echo ""

# =============================================================================
# 1. Eliminar política de escalado
# =============================================================================
echo "=== [1/8] Eliminar política de escalado ==="
POLICY_ARN=$(aws autoscaling describe-policies \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-names "$POLICY_NAME" \
  --query "ScalingPolicies[0].PolicyARN" --output text 2>/dev/null || true)

if [ -n "$POLICY_ARN" ] && [ "$POLICY_ARN" != "None" ]; then
  aws autoscaling delete-policy \
    --auto-scaling-group-name "$ASG_NAME" \
    --policy-name "$POLICY_NAME" 2>/dev/null || true
  echo "✔ Política eliminada"
else
  echo "· Política no encontrada"
fi

# =============================================================================
# 2. Eliminar Auto Scaling Group (fuerza la terminación de instancias)
# =============================================================================
echo ""
echo "=== [2/8] Eliminar Auto Scaling Group ==="
ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null || true)

if [ -n "$ASG_EXISTS" ] && [ "$ASG_EXISTS" != "None" ]; then
  aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --force-delete
  echo "✔ ASG eliminado (instancias se terminan en segundo plano)"
  echo "  Esperando 20 s para que AWS procese la eliminación..."
  sleep 20
else
  echo "· ASG no encontrado"
fi

# =============================================================================
# 3. Eliminar Listener y ALB
# =============================================================================
echo ""
echo "=== [3/8] Eliminar Listener y ALB ==="
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || true)

if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  # Eliminar listeners primero
  LISTENERS=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[].ListenerArn" --output text 2>/dev/null || true)
  for L in $LISTENERS; do
    aws elbv2 delete-listener --listener-arn "$L" 2>/dev/null || true
    echo "  ✔ Listener eliminado: $L"
  done
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
  echo "✔ ALB eliminado — esperando confirmación (30 s)..."
  sleep 30
else
  echo "· ALB no encontrado"
fi

# =============================================================================
# 4. Eliminar Target Group
# =============================================================================
echo ""
echo "=== [4/8] Eliminar Target Group ==="
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || true)

if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
  echo "✔ Target Group eliminado"
else
  echo "· Target Group no encontrado"
fi

# =============================================================================
# 5. Eliminar Launch Template
# =============================================================================
echo ""
echo "=== [5/8] Eliminar Launch Template ==="
LT_ID=$(aws ec2 describe-launch-templates \
  --filters "Name=launch-template-name,Values=$LT_NAME" \
  --query "LaunchTemplates[0].LaunchTemplateId" --output text 2>/dev/null || true)

if [ -n "$LT_ID" ] && [ "$LT_ID" != "None" ]; then
  aws ec2 delete-launch-template --launch-template-id "$LT_ID"
  echo "✔ Launch Template eliminada: $LT_ID"
else
  echo "· Launch Template no encontrada"
fi

# =============================================================================
# 6. Eliminar SG del ALB (ambos nombres posibles)
# =============================================================================
echo ""
echo "=== [6/8] Eliminar SG del ALB ==="

# Obtener VPC_ID para filtrar
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)

for SG_NAME_CANDIDATE in "$SG_ALB_NAME" "$SG_ALB_NAME_OLD"; do
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME_CANDIDATE" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)
  if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null && \
      echo "✔ SG eliminado: $SG_ID ($SG_NAME_CANDIDATE)" || \
      echo "⚠ No se pudo eliminar $SG_ID (puede tener dependencias; espera más y reintenta)"
  else
    echo "· SG '$SG_NAME_CANDIDATE' no encontrado"
  fi
done

# =============================================================================
# 7. Restaurar acceso HTTP público en el SG de EC2
#    (si el script lo revocó, el servidor quedaría inaccesible sin ALB)
# =============================================================================
echo ""
echo "=== [7/8] Restaurar HTTP público en SG de EC2 (si fue revocado) ==="

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)

if [ -z "$SG_EC2_ID" ] || [ "$SG_EC2_ID" = "None" ]; then
  SG_EC2_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_EC2_NAME_P03" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)
fi

if [ -n "$SG_EC2_ID" ] && [ "$SG_EC2_ID" != "None" ]; then
  HTTP_PUB=$(aws ec2 describe-security-groups \
    --group-ids "$SG_EC2_ID" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && contains(IpRanges[].CidrIp,'0.0.0.0/0')]" \
    --output text 2>/dev/null || true)
  if [ -z "$HTTP_PUB" ] || [ "$HTTP_PUB" = "None" ]; then
    aws ec2 authorize-security-group-ingress \
      --group-id "$SG_EC2_ID" \
      --protocol tcp --port 80 --cidr "0.0.0.0/0" 2>/dev/null || true
    echo "✔ HTTP público restaurado en $SG_EC2_ID"
  else
    echo "· HTTP público ya presente en SG de EC2"
  fi
else
  echo "· SG de EC2 no encontrado"
fi

# =============================================================================
# 8. Eliminar subred pública 2 si fue creada por este script
#    (solo si no tiene instancias activas)
# =============================================================================
echo ""
echo "=== [8/8] Eliminar subred pública 2 (si fue creada en p08) ==="
SUBNET_PUB_2_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_2_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)

if [ -n "$SUBNET_PUB_2_ID" ] && [ "$SUBNET_PUB_2_ID" != "None" ]; then
  # Verificar que no haya interfaces de red activas antes de borrar
  ENI_COUNT=$(aws ec2 describe-network-interfaces \
    --filters "Name=subnet-id,Values=$SUBNET_PUB_2_ID" \
    --query "length(NetworkInterfaces)" --output text 2>/dev/null || echo "0")
  if [ "$ENI_COUNT" = "0" ] || [ "$ENI_COUNT" = "None" ]; then
    aws ec2 delete-subnet --subnet-id "$SUBNET_PUB_2_ID" 2>/dev/null && \
      echo "✔ Subred pública 2 eliminada: $SUBNET_PUB_2_ID" || \
      echo "⚠ No se pudo eliminar la subred (espera a que las instancias terminen)"
  else
    echo "⚠ La subred tiene $ENI_COUNT interfaz(es) activa(s) — no se elimina."
    echo "  Espera a que las instancias del ASG terminen y ejecuta de nuevo."
  fi
else
  echo "· Subred pública 2 no encontrada"
fi

# =============================================================================
# Resumen
# =============================================================================
echo ""
echo "============================================================"
echo "  LIMPIEZA COMPLETADA"
echo "============================================================"
echo ""
echo "  Recursos eliminados de la práctica 08:"
echo "  · Política de escalado"
echo "  · Auto Scaling Group (instancias terminadas)"
echo "  · Listener + ALB"
echo "  · Target Group"
echo "  · Launch Template"
echo "  · SG del ALB"
echo "  · Subred pública AZ-2 (si estaba vacía)"
echo ""
echo "  Recursos conservados (de prácticas anteriores):"
echo "  · VPC, subredes, tablas de ruteo"
echo "  · SG de EC2 (HTTP público restaurado)"
echo "  · SG de RDS, instancia RDS"
echo "  · Rol IAM, instancia EC2 de p03"
echo ""
echo "  Ya puedes re-ejecutar:"
echo "    bash aws-practica08-alb-asg.sh"
echo "============================================================"
