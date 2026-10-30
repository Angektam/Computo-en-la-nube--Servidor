#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - PRENDER SERVICIOS
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube
#
# Enciende todos los servicios de P08 que fueron apagados
#
# USO:
#   bash prender-p08.sh
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

ASG_NAME="asg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
LT_NAME="lt-$PROYECTO-$EQUIPO"
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · PRENDER SERVICIOS"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

# =============================================================================
# PASO 1 — Expandir ASG a 2 instancias
# =============================================================================
echo "=== [1/3] Expandir Auto Scaling Group ==="

ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null || true)

if [ -z "$ASG_EXISTS" ] || [ "$ASG_EXISTS" = "None" ]; then
  echo "❌ ASG no encontrado. Ejecuta primero: bash aws-practica08-alb-asg.sh"
  exit 1
fi

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --min-size 2 \
  --desired-capacity 2

echo "✔ ASG expandido: min=2, desired=2"
echo "  Esperando que las instancias arranquen (2-3 min)..."
sleep 60

# =============================================================================
# PASO 2 — Verificar ALB
# =============================================================================
echo ""
echo "=== [2/3] Verificar Application Load Balancer ==="

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || true)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
  echo "⚠ ALB no encontrado. Recreando..."
  # Obtener subredes
  VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
    --query "Vpcs[0].VpcId" --output text)
  
  SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=subnet-pub-$PROYECTO-$EQUIPO" \
    --query "Subnets[0].SubnetId" --output text)
  
  SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=subnet-pub2-$PROYECTO-$EQUIPO" \
    --query "Subnets[0].SubnetId" --output text)
  
  SG_ALB_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_ALB_NAME" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
  
  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$SUBNET_1" "$SUBNET_2" \
    --security-groups "$SG_ALB_ID" \
    --scheme internet-facing \
    --type application \
    --tags Key=Name,Value="$ALB_NAME" Key=proyecto,Value="$PROYECTO" \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)
  
  echo "✔ ALB recreado: $ALB_ARN"
  echo "  Esperando que esté activo (2-3 min)..."
  aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"
else
  echo "✔ ALB ya existe: $ALB_ARN"
fi

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)

echo "  DNS: http://$ALB_DNS"

# =============================================================================
# PASO 3 — Verificar Target Group y Listener
# =============================================================================
echo ""
echo "=== [3/3] Verificar Target Group y Listener ==="

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || true)

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
  echo "⚠ Target Group no encontrado. Recreando..."
  VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
    --query "Vpcs[0].VpcId" --output text)
  
  TG_ARN=$(aws elbv2 create-target-group \
    --name "$TG_NAME" \
    --protocol HTTP --port 80 \
    --vpc-id "$VPC_ID" \
    --health-check-protocol HTTP \
    --health-check-path "/health" \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --query "TargetGroups[0].TargetGroupArn" --output text)
  
  echo "✔ Target Group recreado: $TG_ARN"
else
  echo "✔ Target Group ya existe: $TG_ARN"
fi

# Verificar Listener
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null || true)

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
  echo "⚠ Listener no encontrado. Recreando..."
  LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TG_ARN" \
    --query "Listeners[0].ListenerArn" --output text)
  
  echo "✔ Listener recreado: $LISTENER_ARN"
else
  echo "✔ Listener ya existe: $LISTENER_ARN"
fi

# Registrar instancias del ASG en el Target Group
INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
  --output text)

if [ -n "$INSTANCES" ]; then
  for IID in $INSTANCES; do
    aws elbv2 register-targets \
      --target-group-arn "$TG_ARN" \
      --targets Id="$IID",Port=80 2>/dev/null || true
    echo "  ✔ Instancia registrada: $IID"
  done
fi

echo ""
echo "============================================================"
echo "  RESUMEN — SERVICIOS PRENDIDOS"
echo "============================================================"
echo ""
echo "  ASG              : $ASG_NAME"
echo "  Min/Desired/Max  : 2/2/4"
echo "  ALB              : $ALB_NAME"
echo "  URL              : http://$ALB_DNS"
echo "  Target Group     : $TG_NAME"
echo ""
echo "  Esperando 2-3 minutos a que los targets estén sanos..."
echo ""
echo "  Siguiente paso: bash evidencia-p08-c1-balanceo.sh"
echo "============================================================"
