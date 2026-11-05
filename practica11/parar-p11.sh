#!/bin/bash
# =============================================================================
# parar-p11.sh — Detener todo para no acumular consumo
# Equipo: Los Rojos  |  Práctica 11
#
# QUÉ HACE:
#   1. Reduce el servicio ECS a 0 tareas
#   2. Elimina el NAT Gateway (cuesta por hora aunque no haya tráfico)
#   3. Libera la IP elástica del NAT Gateway
#   4. Quita la ruta 0.0.0.0/0 de la tabla de ruteo privada
#   5. Conserva el clúster, la definición de tarea y el servicio (no cuestan)
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"
NAT_NAME="nat-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  PARAR TODO — Práctica 11"
echo "  Reducir a 0 tareas + eliminar NAT Gateway"
echo "============================================================"

# ── 1. Reducir el servicio a 0 tareas ──────────────────────────────────────────
echo ""
echo "=== [1/5] Reducir servicio ECS a 0 tareas ==="
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --desired-count 0 \
  --query "service.serviceName" \
  --output text 2>/dev/null && echo "✔ Servicio reducido a 0 tareas" || echo "· Servicio no encontrado o ya en 0"

echo "  Esperando que las tareas se detengan..."
sleep 10

# ── 2. Eliminar el NAT Gateway ────────────────────────────────────────────────
echo ""
echo "=== [2/5] Eliminar NAT Gateway ==="
NAT_ID=$(aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=$NAT_NAME" "Name=state,Values=available" \
  --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null) || true

if [ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ]; then
  # Obtener la IP elástica asociada antes de eliminar
  EIP_ALLOC=$(aws ec2 describe-nat-gateways \
    --nat-gateway-ids "$NAT_ID" \
    --query "NatGateways[0].NatGatewayAddresses[0].AllocationId" \
    --output text 2>/dev/null) || true

  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID"
  echo "✔ NAT Gateway eliminado: $NAT_ID"
  echo "  Esperando a que se elimine..."
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID" 2>/dev/null || sleep 20

  # ── 3. Liberar la IP elástica ────────────────────────────────────────────────
  echo ""
  echo "=== [3/5] Liberar IP elástica ==="
  if [ -n "$EIP_ALLOC" ] && [ "$EIP_ALLOC" != "None" ]; then
    aws ec2 release-address --allocation-id "$EIP_ALLOC" 2>/dev/null && \
      echo "✔ IP elástica liberada: $EIP_ALLOC" || echo "· La IP ya fue liberada"
  else
    echo "· No se encontró IP elástica asociada"
  fi
else
  echo "· NAT Gateway no encontrado o ya eliminado"
  EIP_ALLOC=""
fi

# ── 4. Quitar la ruta 0.0.0.0/0 de la tabla de ruteo privada ────────────────────
echo ""
echo "=== [4/5] Quitar ruta a internet de la tabla privada ==="
RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null) || true

if [ -n "$RT_PRIV_ID" ] && [ "$RT_PRIV_ID" != "None" ]; then
  aws ec2 delete-route \
    --route-table-id "$RT_PRIV_ID" \
    --destination-cidr-block "0.0.0.0/0" 2>/dev/null && \
    echo "✔ Ruta 0.0.0.0/0 eliminada de $RT_PRIV_ID" || \
    echo "· La ruta no existía o ya fue eliminada"
else
  echo "· Tabla de ruteo privada no encontrada"
fi

# ── 5. Resumen de lo que se conserva ──────────────────────────────────────────
echo ""
echo "=== [5/5] Resumen ==="
echo ""
echo "  ✔ DETENIDO (no cuesta):"
echo "    · Servicio ECS: 0 tareas (desiredCount = 0)"
echo "    · NAT Gateway: eliminado"
echo "    · IP elástica: liberada"
echo "    · Ruta privada a internet: eliminada"
echo ""
echo "  ✔ CONSERVADO (no cuesta sin tareas):"
echo "    · Clúster ECS: $CLUSTER_NAME"
echo "    · Definición de tarea: td-$PROYECTO-$EQUIPO"
echo "    · Servicio: $SERVICE_NAME (en 0)"
echo "    · Target group: tg-ecs-$PROYECTO-$EQUIPO"
echo "    · Security Group: ecs-sg-$PROYECTO-$EQUIPO"
echo "    · Roles IAM: rol-ecs-exec-$EQUIPO, rol-ecs-task-$EQUIPO"
echo ""
echo "  Para reactivar el servicio más tarde:"
echo "    bash practica11/aws-practica11-ecs-fargate.sh"
echo "  (recreará el NAT Gateway y pondrá las tareas en marcha)"
echo ""
echo "============================================================"
echo "  ✔ Todo detenido. No hay consumo acumulándose."
echo "============================================================"
