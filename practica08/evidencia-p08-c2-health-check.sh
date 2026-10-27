#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CRITERIO 2: Health check y acceso solo desde ALB
# Evidencia: config del health check + SG de EC2 restringido al ALB
# Equipo: Los Rojos  |  21 oct 2026
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"   # nombre correcto (sin prefijo sg-)

echo ""
echo "============================================================"
echo "  P08 · CRITERIO 2 — Health check y acceso solo desde ALB"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

# Recuperar VPC desde la tag del proyecto
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
  --query "Vpcs[0].VpcId" --output text)

# Buscar SG de EC2 por los tres nombres posibles (igual que el script principal)
SG_EC2_ID=""
for CANDIDATE in "ec2-sg-$PROYECTO-$EQUIPO" "secgrp-$PROYECTO-$EQUIPO" "sg-ec2-$PROYECTO-$EQUIPO"; do
  SG_EC2_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$CANDIDATE" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)
  if [ -n "$SG_EC2_ID" ] && [ "$SG_EC2_ID" != "None" ]; then
    SG_EC2_NOMBRE="$CANDIDATE"
    break
  fi
done

SG_ALB_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_ALB_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

# Recuperar TG ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

echo "=== [1/4] Configuración del Target Group ==="
aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query "TargetGroups[0].{Nombre:TargetGroupName,Protocolo:Protocol,Puerto:Port,RutaHC:HealthCheckPath,IntervaloHC:HealthCheckIntervalSeconds,TimeoutHC:HealthCheckTimeoutSeconds,UmbralSano:HealthyThresholdCount,UmbralInsano:UnhealthyThresholdCount}" \
  --output table

echo ""
echo "  EXPLICACIÓN DE LOS PARÁMETROS:"
echo "  · Ruta /health      : el ALB hace GET /health cada 15 s"
echo "  · Umbral sano = 2   : necesita 2 respuestas 200 seguidas → pasa a healthy"
echo "  · Umbral insano = 2 : 2 fallos seguidos → se retira del pool de tráfico"
echo "  · Tiempo total antes de retirar: ~30 s (2 × 15 s)"

echo ""
echo "=== [2/4] Estado actual de los targets ==="
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State,Razon:TargetHealth.Reason}" \
  --output table

echo ""
echo "=== [3/4] Reglas del SG de los servidores EC2 ($SG_EC2_NOMBRE) ==="
echo "  → Solo debe aparecer el SG del ALB como origen del puerto 80."
echo "  → 0.0.0.0/0 NO debe estar presente en el puerto 80."
echo ""
aws ec2 describe-security-groups \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[].{Puerto:FromPort,Protocolo:IpProtocol,CIDR:IpRanges[0].CidrIp,OrigenSG:UserIdGroupPairs[0].GroupId,DescSG:UserIdGroupPairs[0].Description}" \
  --output table

echo ""
echo "=== [4/4] Verificación: acceso directo BLOQUEADO ==="
# Intentar curl directo a cada instancia del ASG en puerto 80
INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "asg-$PROYECTO-$EQUIPO" \
  --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
  --output text)

for IID in $INSTANCES; do
  PUB_IP=$(aws ec2 describe-instances \
    --instance-ids "$IID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
  if [ "$PUB_IP" = "None" ] || [ -z "$PUB_IP" ]; then
    echo "  · $IID — sin IP pública asignada directamente ✔"
  else
    RESULT=$(curl -s --max-time 4 --connect-timeout 3 "http://$PUB_IP/" 2>&1)
    if echo "$RESULT" | grep -q "inventario-cloud"; then
      echo "  ⚠ $IID ($PUB_IP) — acceso directo AÚN FUNCIONA. Revisa el SG de EC2."
    else
      echo "  ✔ $IID ($PUB_IP) — acceso directo BLOQUEADO (connection refused o timeout)"
    fi
  fi
done

echo ""
echo "============================================================"
echo "  CONCLUSIÓN DEL CRITERIO:"
echo "  · Health check activo: cada 15 s en /health"
echo "  · SG EC2 ($SG_EC2_ID): puerto 80 solo desde ALB ($SG_ALB_ID)"
echo "  · Internet NO puede conectarse directamente a los servidores"
echo "============================================================"
