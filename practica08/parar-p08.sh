#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CIERRE / LIMPIEZA DE RECURSOS
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  21 oct 2026
#
# Ejecutar al terminar la sesión para controlar el gasto.
#
# QUÉ HACE ESTE SCRIPT:
#   - Reduce el ASG a 1 instancia (mínimo necesario)
#   - Opcionalmente elimina el ALB, el Target Group y el SG del ALB
#
# QUÉ NO ELIMINA:
#   - La Launch Template (se reutiliza en prácticas siguientes)
#   - La política de escalado (queda ligada al ASG)
#   - La VPC, subredes, SG de EC2, RDS (de prácticas anteriores)
#
# USO:
#   bash parar-p08.sh           → solo reduce ASG, conserva ALB
#   bash parar-p08.sh --full    → reduce ASG Y elimina ALB/TG/SG-ALB
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"
SG_EC2_NAME="ec2-sg-$PROYECTO-$EQUIPO"
SG_EC2_NAME_P03="secgrp-$PROYECTO-$EQUIPO"

MODO_FULL=false
if [ "$1" = "--full" ]; then
  MODO_FULL=true
fi

echo ""
echo "============================================================"
if $MODO_FULL; then
  echo "  P08 · CIERRE COMPLETO (--full)"
  echo "  Reduce ASG + elimina ALB, TG y SG del ALB"
else
  echo "  P08 · CIERRE RÁPIDO"
  echo "  Reduce ASG a 1 instancia — conserva el ALB"
fi
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

# =============================================================================
# PASO 1 — Reducir el ASG a 1 instancia
# =============================================================================
echo "=== [1] Reducir Auto Scaling Group a 1 instancia ==="

ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null)

if [ "$ASG_EXISTS" = "None" ] || [ -z "$ASG_EXISTS" ]; then
  echo "· ASG '$ASG_NAME' no encontrado — nada que reducir."
else
  ACTUAL=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].DesiredCapacity" --output text)

  echo "  Capacidad actual: $ACTUAL → reduciendo a 1..."

  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --min-size 1 \
    --desired-capacity 1 \
    --max-size 4

  echo "✔ ASG actualizado: min=1, desired=1, max=4"
  echo ""
  echo "  Esperando que el ASG termine la instancia sobrante (30 s)..."
  sleep 30

  echo ""
  echo "--- Estado del ASG tras la reducción ---"
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
    --output table
fi

# =============================================================================
# PASO 2 — Si --full: eliminar ALB, Listener, Target Group y SG del ALB
# =============================================================================
if $MODO_FULL; then
  echo ""
  echo "=== [2] Eliminar Listener y ALB ==="

  ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

  if [ "$ALB_ARN" = "None" ] || [ -z "$ALB_ARN" ]; then
    echo "· ALB '$ALB_NAME' no encontrado."
  else
    # Eliminar listeners primero
    LISTENERS=$(aws elbv2 describe-listeners \
      --load-balancer-arn "$ALB_ARN" \
      --query "Listeners[].ListenerArn" --output text 2>/dev/null)
    for L in $LISTENERS; do
      aws elbv2 delete-listener --listener-arn "$L"
      echo "✔ Listener eliminado: $L"
    done

    # Eliminar el ALB
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
    echo "✔ ALB eliminado: $ALB_ARN"
    echo "  Esperando confirmación de eliminación (30 s)..."
    sleep 30
  fi

  echo ""
  echo "=== [3] Eliminar Target Group ==="

  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$TG_NAME" \
    --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

  if [ "$TG_ARN" = "None" ] || [ -z "$TG_ARN" ]; then
    echo "· Target Group '$TG_NAME' no encontrado."
  else
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
    echo "✔ Target Group eliminado: $TG_ARN"
  fi

  echo ""
  echo "=== [4] Restaurar reglas del SG de EC2 (reabrir HTTP desde internet) ==="
  # Al eliminar el ALB, los servidores vuelven a necesitar HTTP público
  # para no quedar completamente inaccesibles.

  VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null)

  SG_EC2_ID=""
  for CANDIDATE in "$SG_EC2_NAME" "$SG_EC2_NAME_P03" "sg-ec2-$PROYECTO-$EQUIPO"; do
    SG_EC2_ID=$(aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=$CANDIDATE" "Name=vpc-id,Values=$VPC_ID" \
      --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)
    [ -n "$SG_EC2_ID" ] && [ "$SG_EC2_ID" != "None" ] && break
  done

  SG_ALB_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_ALB_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

  # Revocar regla que solo permitía desde el ALB
  if [ -n "$SG_ALB_ID" ] && [ "$SG_ALB_ID" != "None" ]; then
    aws ec2 revoke-security-group-ingress \
      --group-id "$SG_EC2_ID" \
      --ip-permissions \
        "IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs=[{GroupId=$SG_ALB_ID}]" \
      2>/dev/null && echo "✔ Regla ALB→EC2 revocada del SG de EC2"
  fi

  # Reabrir HTTP público
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --protocol tcp --port 80 --cidr "0.0.0.0/0" \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Description,Value=HTTP-publico-restaurado-post-p08}]" \
    2>/dev/null && echo "✔ HTTP público (0.0.0.0/0:80) restaurado en SG de EC2"

  echo ""
  echo "=== [5] Eliminar SG del ALB ==="

  if [ "$SG_ALB_ID" = "None" ] || [ -z "$SG_ALB_ID" ]; then
    echo "· SG del ALB no encontrado."
  else
    aws ec2 delete-security-group --group-id "$SG_ALB_ID" 2>/dev/null && \
      echo "✔ SG del ALB eliminado: $SG_ALB_ID" || \
      echo "⚠ No se pudo eliminar el SG del ALB (puede tener dependencias aún)."
  fi

else
  # Modo rápido: solo mostrar estado del ALB
  echo ""
  echo "=== [2] Estado del ALB (conservado) ==="

  ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query "LoadBalancers[0].DNSName" --output text 2>/dev/null)

  aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query "LoadBalancers[0].{Nombre:LoadBalancerName,Estado:State.Code,DNS:DNSName}" \
    --output table

  echo ""
  echo "  ⚠ ATENCIÓN — El ALB SIGUE ACTIVO y cobrando (~\$0.016/hora)."
  echo "  El responsable de costos debe revisar el gasto cada 2 días"
  echo "  hasta la práctica 13 (o eliminar con: bash parar-p08.sh --full)"
fi

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "============================================================"
echo "  RESUMEN DE CIERRE — PRÁCTICA 08"
echo "============================================================"
echo ""
echo "  ASG  : min=1, desired=1 — 1 instancia corriendo"

if $MODO_FULL; then
  echo "  ALB  : ELIMINADO ✔"
  echo "  TG   : ELIMINADO ✔"
  echo "  SG-ALB: ELIMINADO ✔"
  echo "  SG-EC2: HTTP público restaurado"
  echo ""
  echo "  Para retomar en la próxima sesión:"
  echo "    bash aws-practica08-alb-asg.sh"
else
  echo "  ALB  : activo — revisar costos cada 2 días"
  echo ""
  echo "  Para eliminar el ALB más tarde:"
  echo "    bash parar-p08.sh --full"
fi

echo ""
echo "  Launch Template conservada para la práctica 12."
echo "  Anota en la bitácora la decisión y el gasto del día."
echo "============================================================"
