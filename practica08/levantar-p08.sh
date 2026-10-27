#!/bin/bash
# =============================================================================
# levantar-p08.sh — Levanta todos los servicios necesarios para la Práctica 08
# Equipo: Los Rojos  |  Cómputo en la Nube  |  21 oct 2026
#
# Ejecutar en AWS CloudShell al iniciar cada sesión.
#
# QUÉ LEVANTA:
#   1. RDS PostgreSQL  (rds-inventario-cloud-los-rojos)
#   2. EC2 del ASG     (el Auto Scaling Group pone las instancias InService)
#   3. ALB             (verifica que esté activo)
#   4. Espera a que todo esté healthy antes de soltar el control
#
# PRERREQUISITOS:
#   - Prácticas 03, 05, 06 y 08 ya ejecutadas al menos una vez.
#   - Los recursos (ASG, ALB, TG, RDS) ya existen, solo están detenidos/reducidos.
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"

DB_ID="rds-$PROYECTO-$EQUIPO"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  LEVANTAR SERVICIOS — PRÁCTICA 08"
echo "  Equipo : Los Rojos"
echo "  Región : $REGION"
echo "============================================================"
echo ""

# =============================================================================
# PASO 1 — RDS: arrancar si está detenida
# =============================================================================
echo "=== [1/4] RDS PostgreSQL ==="

DB_STATUS=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null)

if [ -z "$DB_STATUS" ] || [ "$DB_STATUS" = "None" ]; then
  echo "  ❌ RDS '$DB_ID' no encontrada."
  echo "     Verifica que la práctica 06 esté completada."
else
  echo "  Estado actual: $DB_STATUS"

  if [ "$DB_STATUS" = "stopped" ]; then
    echo "  → Iniciando RDS..."
    aws rds start-db-instance \
      --region "$REGION" \
      --db-instance-identifier "$DB_ID" \
      --query "DBInstance.{ID:DBInstanceIdentifier,Estado:DBInstanceStatus}" \
      --output table
    echo "  ⏳ RDS tardará 3-5 minutos en quedar 'available'."
    echo "     Continuando con los otros pasos mientras arranca..."
  elif [ "$DB_STATUS" = "available" ]; then
    echo "  ✔ RDS ya está disponible."
  elif [ "$DB_STATUS" = "starting" ]; then
    echo "  ✔ RDS ya está iniciando."
  else
    echo "  ⚠ Estado inesperado: $DB_STATUS — puede estar en transición."
  fi
fi

# =============================================================================
# PASO 2 — ASG: restaurar capacidad a 2 instancias
# =============================================================================
echo ""
echo "=== [2/4] Auto Scaling Group ==="

ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null)

if [ "$ASG_EXISTS" = "None" ] || [ -z "$ASG_EXISTS" ]; then
  echo "  ❌ ASG '$ASG_NAME' no encontrado."
  echo "     Ejecuta primero: bash aws-practica08-alb-asg.sh"
else
  CURRENT_DESIRED=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].DesiredCapacity" --output text)
  CURRENT_MIN=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].MinSize" --output text)

  echo "  Estado actual: min=$CURRENT_MIN, desired=$CURRENT_DESIRED"

  if [ "$CURRENT_DESIRED" -lt 2 ] || [ "$CURRENT_MIN" -lt 2 ]; then
    echo "  → Restaurando a min=2, desired=2, max=4..."
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$ASG_NAME" \
      --min-size 2 \
      --desired-capacity 2 \
      --max-size 4
    echo "  ✔ ASG actualizado: min=2, desired=2, max=4"
  else
    echo "  ✔ ASG ya tiene la configuración correcta."
  fi

  # Mostrar estado de las instancias
  echo ""
  echo "  --- Instancias en el ASG ---"
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
    --output table
fi

# =============================================================================
# PASO 3 — ALB: verificar que está activo
# =============================================================================
echo ""
echo "=== [3/4] Application Load Balancer ==="

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

if [ "$ALB_ARN" = "None" ] || [ -z "$ALB_ARN" ]; then
  echo "  ❌ ALB '$ALB_NAME' no encontrado."
  echo "     Ejecuta primero: bash aws-practica08-alb-asg.sh"
else
  ALB_STATE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query "LoadBalancers[0].State.Code" --output text)
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query "LoadBalancers[0].DNSName" --output text)

  echo "  Estado : $ALB_STATE"
  echo "  DNS    : http://$ALB_DNS"

  if [ "$ALB_STATE" = "active" ]; then
    echo "  ✔ ALB activo y funcionando."
  else
    echo "  ⏳ ALB en estado '$ALB_STATE' — espera 1-2 minutos y revisa de nuevo."
  fi
fi

# =============================================================================
# PASO 4 — Esperar targets healthy
# =============================================================================
echo ""
echo "=== [4/4] Esperando instancias healthy en el Target Group ==="

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

if [ "$TG_ARN" = "None" ] || [ -z "$TG_ARN" ]; then
  echo "  ❌ Target Group '$TG_NAME' no encontrado."
else
  SANOS=0
  INTENTOS=0
  MAX_INTENTOS=24   # 24 × 15 s = 6 minutos máximo

  while [ "$SANOS" -lt 2 ] && [ "$INTENTOS" -lt "$MAX_INTENTOS" ]; do
    SANOS=$(aws elbv2 describe-target-health \
      --target-group-arn "$TG_ARN" \
      --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
      --output text 2>/dev/null)
    SANOS=${SANOS:-0}
    INTENTOS=$((INTENTOS + 1))

    if [ "$SANOS" -lt 2 ]; then
      echo "  Targets healthy: $SANOS/2 — esperando 15 s... ($INTENTOS/$MAX_INTENTOS)"
      sleep 15
    fi
  done

  echo ""
  echo "  --- Estado final del Target Group ---"
  aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
    --output table

  if [ "$SANOS" -ge 2 ]; then
    echo ""
    echo "  ✔ $SANOS instancias healthy — el sistema está listo."
  else
    echo ""
    echo "  ⚠ Solo $SANOS instancia(s) healthy después de esperar."
    echo "  Posibles causas:"
    echo "    · Las EC2 aún están iniciando (espera 1-2 min más)"
    echo "    · El SG de EC2 no permite tráfico desde el ALB"
    echo "    · La página /health no responde 200 (revisa nginx)"
    echo "  Diagnóstico rápido:"
    echo "    aws elbv2 describe-target-health --target-group-arn $TG_ARN"
  fi
fi

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "============================================================"
echo "  RESUMEN — SERVICIOS LEVANTADOS"
echo "============================================================"

# RDS
DB_STATUS_FINAL=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null)
DB_ENDPOINT=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text 2>/dev/null)

echo ""
echo "  RDS  : $DB_STATUS_FINAL"
[ -n "$DB_ENDPOINT" ] && [ "$DB_ENDPOINT" != "None" ] && echo "         Endpoint: $DB_ENDPOINT"

# ALB
echo "  ALB  : $ALB_STATE — http://$ALB_DNS"

# ASG
FINAL_DESIRED=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].DesiredCapacity" --output text 2>/dev/null)
echo "  ASG  : desired=$FINAL_DESIRED instancias"
echo "  TG   : $SANOS healthy"

echo ""
echo "  ➜ Abre en el navegador: http://$ALB_DNS"
echo "  ➜ Recarga varias veces para ver los distintos Instance IDs."
echo ""
echo "  Scripts de evidencia listos para ejecutar:"
echo "    bash evidencia-p08-c1-balanceo.sh"
echo "    bash evidencia-p08-c2-health-check.sh"
echo "    bash evidencia-p08-c3-falla.sh"
echo "    bash evidencia-p08-c4-recuperacion.sh"
echo "    bash evidencia-p08-c5-escalado-cpu.sh"
echo ""
echo "  Al terminar la sesión ejecuta:"
echo "    bash parar-p08.sh"
echo "============================================================"
