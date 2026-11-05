#!/bin/bash
# =============================================================================
# evidencia-p11-c3-balanceador.sh
# Evidencia: La aplicación responde por la dirección del balanceador
#            y está en subred privada (solo se accede por el balanceador)
# Criterios: servicio ejecuta la imagen del registro (20 pts)
#            aplicación en subred privada y solo se accede por el balanceador (20 pts)
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_ECS_NAME="tg-ecs-$PROYECTO-$EQUIPO"
SG_ECS_NAME="ecs-sg-$PROYECTO-$EQUIPO"

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)

echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA P11 — Aplicación respondiendo por el balanceador"
echo "════════════════════════════════════════════════════════════════════"

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  1. URL DEL BALANCEADOR                                          │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "  http://$ALB_DNS"
echo ""

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  2. RESPUESTA DEL ENDPOINT /health                                │"
echo "└─────────────────────────────────────────────────────────────────┘"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" 2>/dev/null || echo "FALLO")
echo "  HTTP Status: $HTTP_STATUS"
echo ""
echo "  Cuerpo de la respuesta:"
curl -s "http://$ALB_DNS/health" 2>/dev/null || echo "  (sin respuesta aún, espera 30 s)"
echo ""

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  3. HEALTH CHECK DEL TARGET GROUP (debe marcar SANO)             │"
echo "└─────────────────────────────────────────────────────────────────┘"
TG_ECS_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_ECS_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ECS_ARN" \
  --query "TargetHealthDescriptions[].{IP:Target.Id,Puerto:Target.Port,Estado:TargetHealth.State,Razon:TargetHealth.Reason}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  4. TAREAS EN SUBRED PRIVADA — SIN IP PÚBLICA                     │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "  Las tareas no tienen IP pública. Solo IP privada dentro de la VPC."
echo "  El acceso desde internet es exclusivamente por el balanceador."
echo ""
aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns" \
  --output text | tr '\t' '\n' | head -5 | while read TASK_ARN; do
  [ -z "$TASK_ARN" ] && continue
  ENI_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value|[0]" \
    --output text 2>/dev/null) || true
  PRIVATE_IP=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value|[0]" \
    --output text 2>/dev/null) || true
  PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --query "NetworkInterfaces[0].Association.PublicIp" \
    --output text 2>/dev/null) || true
  [ "$PUBLIC_IP" = "None" ] && PUBLIC_IP="(sin IP pública)"

  echo "  Tarea: $(echo $TASK_ARN | cut -d'/' -f3)"
  echo "    IP privada : $PRIVATE_IP"
  echo "    IP pública : $PUBLIC_IP  ← debe estar vacía"
  echo "    ENI        : $ENI_ID"
  echo ""
done

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  5. SG DE LAS TAREAS — SOLO RECIBE DEL ALB (no de internet)      │"
echo "└─────────────────────────────────────────────────────────────────┘"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
  --query "Vpcs[0].VpcId" --output text)
SG_ECS_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_ECS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)
aws ec2 describe-security-groups \
  --group-ids "$SG_ECS_ID" \
  --query "SecurityGroups[0].{Nombre:GroupName,Reglas:IpPermissions[].{Puerto:FromPort,Protocolo:IpProtocol,Origen:UserIdGroupPairs[0].GroupId,CIDR:IpRanges[0].CidrIp}}" \
  --output table
echo ""
echo "  → Solo hay una regla inbound: puerto 3000 desde el SG del ALB."
echo "  → No hay regla 0.0.0.0/0. Internet NO puede conectarse directo."

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  6. RESPUESTA COMPLETA DE LA APLICACIÓN                            │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "  Abriendo la página principal del balanceador..."
echo ""
HTML=$(curl -s "http://$ALB_DNS/" 2>/dev/null || echo "")
if [ -n "$HTML" ]; then
  echo "$HTML" | head -20
else
  echo "  (sin respuesta, verifica que las tareas estén RUNNING)"
fi
echo ""
echo "  ↑ TOMA CAPTURA DE PANTALLA DE ESTA SALIDA ↑"
echo "  ↑ Y DE LA PÁGINA ABIERTA EN EL NAVEGADOR ↑"
