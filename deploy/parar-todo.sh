#!/bin/bash
# =============================================================================
# parar-todo.sh — Detiene todos los recursos que generan costo
# Ejecutar en: AWS CloudShell
# Cuándo usar: Al terminar cada sesión de práctica
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"

echo "============================================================"
echo "  DETENER RECURSOS — Equipo: Los Rojos"
echo "  Región: $REGION"
echo "============================================================"
echo ""

# ── 1. Detener instancias EC2 ─────────────────────────────────────
echo "=== [1/3] EC2 ==="
EC2_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:equipo,Values=$EQUIPO" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$EC2_IDS" ]; then
  echo "  · No hay EC2 corriendo"
else
  aws ec2 stop-instances --region "$REGION" --instance-ids $EC2_IDS \
    --query "StoppingInstances[*].{ID:InstanceId,Estado:CurrentState.Name}" \
    --output table
  echo "  ✔ EC2 detenidas"
fi

echo ""

# ── 2. Detener instancia RDS ──────────────────────────────────────
echo "=== [2/3] RDS ==="
DB_ID="rds-$PROYECTO-$EQUIPO"
DB_STATUS=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "not-found")

if [ "$DB_STATUS" = "available" ]; then
  aws rds stop-db-instance \
    --region "$REGION" \
    --db-instance-identifier "$DB_ID" \
    --query "DBInstance.{ID:DBInstanceIdentifier,Estado:DBInstanceStatus}" \
    --output table
  echo "  ✔ RDS detenida (puede estar hasta 7 días consecutivos)"
elif [ "$DB_STATUS" = "stopping" ]; then
  echo "  · RDS ya se está deteniendo"
elif [ "$DB_STATUS" = "stopped" ]; then
  echo "  · RDS ya está detenida ✔"
else
  echo "  · RDS estado: $DB_STATUS"
fi

echo ""

# ── 3. Resumen de costos activos restantes ────────────────────────
echo "=== [3/3] Recursos que SÍ siguen cobrando aunque estén detenidos ==="
echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │  COSTO FIJO AUNQUE ESTÉN DETENIDOS (no se puede evitar)    │"
echo "  ├──────────────────────────────┬──────────────────────────────┤"
echo "  │  RDS — almacenamiento 20 GB  │  ~\$0.023/día (\$0.69/mes)    │"
echo "  │  EC2 — volumen EBS ~8 GB     │  ~\$0.008/día (\$0.24/mes)    │"
echo "  │  VPC — Internet Gateway      │  \$0.00 (sin tráfico)         │"
echo "  ├──────────────────────────────┴──────────────────────────────┤"
echo "  │  TOTAL DETENIDO              │  ~\$0.93/mes                  │"
echo "  └─────────────────────────────────────────────────────────────┘"
echo ""
echo "  ⚠  RECORDATORIO RDS:"
echo "     Si pasan 7 días detenida, AWS la reinicia automáticamente."
echo "     Cuando se reinicie, detenerla de nuevo con:"
echo "     aws rds stop-db-instance --db-instance-identifier $DB_ID --region $REGION"
echo ""
echo "  ⚠  NAT GATEWAY:"
echo "     Si tienen uno activo cobra \$0.045/hora (~\$32/mes)."

# Verificar si hay NAT Gateway activo
NAT=$(aws ec2 describe-nat-gateways \
  --region "$REGION" \
  --filter "Name=state,Values=available" \
  --query "NatGateways[*].NatGatewayId" \
  --output text)

if [ -n "$NAT" ]; then
  echo "  ✗ HAY NAT GATEWAY ACTIVO: $NAT"
  echo "    Elimínalo con:"
  echo "    aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region $REGION"
else
  echo "  ✔ Sin NAT Gateway activo — \$0.00"
fi

echo ""
echo "============================================================"
echo "  ESTADO FINAL"
echo "============================================================"

# EC2
echo ""
echo "  EC2:"
aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:equipo,Values=$EQUIPO" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,Estado:State.Name,IP:PublicIpAddress}" \
  --output table

# RDS
echo "  RDS:"
aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].{ID:DBInstanceIdentifier,Estado:DBInstanceStatus}" \
  --output table 2>/dev/null

echo ""
echo "  ✔ Script finalizado. Revisa el gasto en:"
echo "    https://console.aws.amazon.com/billing/home#/bills"
echo "============================================================"
