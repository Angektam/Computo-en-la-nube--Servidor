#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CRITERIO 3: Provocar una falla (paso 08 de la práctica)
# Evidencia: terminar una instancia y documentar que el ALB la retira
# Equipo: Los Rojos  |  21 oct 2026
#
# ⚠ Este script TERMINA una instancia a propósito.
#   El ASG la reemplazará automáticamente.
#   Ejecutar DESPUÉS de comprobar que hay 2 instancias InService.
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · CRITERIO 3 — Provocar falla y documentar recuperación"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)

echo "=== [ANTES] Estado del ASG y targets ==="
echo ""
echo "--- Instancias del ASG ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
  --output table

echo ""
echo "--- Targets en el balanceador ---"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State}" \
  --output table

# Seleccionar la primera instancia InService para terminar
VICTIM_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId | [0]" \
  --output text)

if [ "$VICTIM_ID" = "None" ] || [ -z "$VICTIM_ID" ]; then
  echo "❌ No se encontró instancia InService para terminar."
  echo "   Espera a que el ASG tenga al menos 1 instancia en servicio."
  exit 1
fi

echo ""
echo "============================================================"
echo "  ⚠ TERMINANDO instancia: $VICTIM_ID"
echo "  El ASG creará una nueva para mantener el mínimo de 2."
echo "============================================================"
echo ""

# Marcar el tiempo de inicio
TIEMPO_INICIO=$(date +%s)
HORA_INICIO=$(date '+%H:%M:%S')
echo "  Hora de la falla: $HORA_INICIO"
echo ""

# Terminar la instancia a través del ASG
# (usar terminate-instance-in-auto-scaling-group para que el ASG lo registre)
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id "$VICTIM_ID" \
  --no-should-decrement-desired-capacity

echo "✔ Comando de terminación enviado."
echo ""
echo "  El ASG detectará que la capacidad cayó por debajo del deseado"
echo "  y lanzará una nueva instancia automáticamente."
echo ""

# -----------------------------------------------------------------------
# Monitoreo en tiempo real: observar el ciclo completo
# Documentar:
#   1. Que el ALB deja de enviar tráfico a la instancia fallida
#   2. Que el ASG crea una nueva instancia
#   3. Tiempo total hasta tener 2 instancias sanas de nuevo
# -----------------------------------------------------------------------
echo "============================================================"
echo "  MONITOREO — actualizando cada 15 s"
echo "  Buscamos: instancia terminada → reemplazada → sana"
echo "============================================================"
echo ""

RECUPERADO=false
MAX_CICLOS=30  # máximo 30 × 15 s = 7.5 minutos de espera

for CICLO in $(seq 1 $MAX_CICLOS); do
  HORA_ACTUAL=$(date '+%H:%M:%S')
  TIEMPO_ACTUAL=$(date +%s)
  TRANSCURRIDO=$((TIEMPO_ACTUAL - TIEMPO_INICIO))

  # Estado de los targets
  HEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text 2>/dev/null)

  UNHEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State!='healthy'])" \
    --output text 2>/dev/null)

  # Estado de las instancias del ASG
  INSTANCES_TOTAL=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "length(AutoScalingGroups[0].Instances)" \
    --output text 2>/dev/null)

  INSERVICE=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "length(AutoScalingGroups[0].Instances[?LifecycleState=='InService'])" \
    --output text 2>/dev/null)

  echo "[$HORA_ACTUAL | +${TRANSCURRIDO}s] Targets sanos: $HEALTHY | Instancias ASG: $INSTANCES_TOTAL | InService: $INSERVICE"

  # Detalle de estado del target víctima
  VICTIM_STATUS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "TargetHealthDescriptions[?Target.Id=='$VICTIM_ID'].TargetHealth.State" \
    --output text 2>/dev/null)
  if [ -n "$VICTIM_STATUS" ] && [ "$VICTIM_STATUS" != "None" ]; then
    echo "  → $VICTIM_ID (víctima): $VICTIM_STATUS"
  else
    echo "  → $VICTIM_ID (víctima): ya retirada del pool ✔"
  fi

  # Comprobar si ya tenemos 2 instancias sanas de nuevo
  if [ "$HEALTHY" -ge 2 ] 2>/dev/null; then
    TIEMPO_FIN=$(date +%s)
    TIEMPO_RECUPERACION=$((TIEMPO_FIN - TIEMPO_INICIO))
    RECUPERADO=true
    echo ""
    echo "============================================================"
    echo "  ✔ RECUPERACIÓN COMPLETA"
    echo "  Hora inicio (falla)     : $HORA_INICIO"
    echo "  Hora fin (2 sanos)      : $(date '+%H:%M:%S')"
    echo "  ⏱ Tiempo de recuperación: ${TIEMPO_RECUPERACION} segundos"
    echo "                           (~$((TIEMPO_RECUPERACION / 60)) min $((TIEMPO_RECUPERACION % 60)) s)"
    echo ""
    echo "  Este es el RTO (Recovery Time Objective) observado del proyecto."
    echo "  Documenta este valor en el apartado 14 del entregable."
    echo "============================================================"
    break
  fi

  sleep 15
done

echo ""
echo "=== [DESPUÉS] Estado final del ASG y targets ==="
echo ""
echo "--- Instancias del ASG ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
  --output table

echo ""
echo "--- Targets sanos en el balanceador ---"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
  --output table

echo ""
if [ "$RECUPERADO" = true ]; then
  echo "  ✔ CRITERIO CUMPLIDO:"
  echo "    1. El ALB dejó de enviar tráfico a $VICTIM_ID al detectarla insana."
  echo "    2. El ASG lanzó una instancia nueva para mantener la capacidad deseada."
  echo "    3. La nueva instancia pasó el health check y entró al pool."
  echo ""
  echo "  ➜ Accede a http://$ALB_DNS — debe seguir respondiendo durante todo el proceso."
else
  echo "  ⚠ Tiempo de espera agotado. Revisa manualmente en la consola:"
  echo "    EC2 → Auto Scaling Groups → $ASG_NAME → Activity"
  echo "    EC2 → Load Balancers → $ALB_NAME → Target Groups"
fi
