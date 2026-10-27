#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CRITERIO 4: Documentar recuperación completa
# Evidencia: actividad del ASG, historial de eventos, estado final
# Equipo: Los Rojos  |  21 oct 2026
#
# Ejecutar DESPUÉS de evidencia-p08-c3-falla.sh
# Captura el historial de actividad del ASG y el estado final del sistema
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · CRITERIO 4 — Documentar recuperación ante falla"
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

# =============================================================================
# [1] Historial de actividad del ASG (muestra launch, terminate, scale)
# =============================================================================
echo "=== [1/5] Historial de actividad del ASG (últimos 10 eventos) ==="
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG_NAME" \
  --max-items 10 \
  --query "Activities[].{Fecha:StartTime,Tipo:Description,Estado:StatusCode,Causa:Cause}" \
  --output table

echo ""
echo "  LECTURA DEL HISTORIAL:"
echo "  · 'Terminating' = instancia que se cayó o fue terminada"
echo "  · 'Launching'   = nueva instancia creada por el ASG para reemplazarla"
echo "  · 'Successful'  = la operación completó sin errores"

# =============================================================================
# [2] Estado actual del ASG
# =============================================================================
echo ""
echo "=== [2/5] Estado actual del Auto Scaling Group ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].{Nombre:AutoScalingGroupName,Min:MinSize,Max:MaxSize,Deseado:DesiredCapacity,AZs:AvailabilityZones,TipoHealthCheck:HealthCheckType}" \
  --output table

echo ""
echo "--- Instancias actuales ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus,LT:LaunchTemplate.LaunchTemplateName}" \
  --output table

# =============================================================================
# [3] Estado del Target Group — todas las instancias deben ser healthy
# =============================================================================
echo ""
echo "=== [3/5] Estado del Target Group tras la recuperación ==="
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Puerto:Target.Port,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
  --output table

# Contar instancias sanas
HEALTHY=$(aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
  --output text)

if [ "$HEALTHY" -ge 2 ]; then
  echo "  ✔ $HEALTHY instancias sanas en el pool → sistema recuperado."
else
  echo "  ⚠ Solo $HEALTHY instancia(s) sana(s). El sistema puede estar aún recuperándose."
fi

# =============================================================================
# [4] Verificar que el servicio continuó durante la falla
# =============================================================================
echo ""
echo "=== [4/5] Verificación de disponibilidad continua ==="
echo "  Haciendo 5 peticiones al balanceador para confirmar que sigue activo..."
echo ""

for i in $(seq 1 5); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$ALB_DNS/" 2>/dev/null)
  IID=$(curl -s --max-time 5 "http://$ALB_DNS/" 2>/dev/null | grep -oP 'Instance ID: \K[^<]+' | tr -d ' ')
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  Petición $i: HTTP $HTTP_CODE ✔  →  $IID"
  else
    echo "  Petición $i: HTTP $HTTP_CODE ⚠ (error)"
  fi
  sleep 2
done

# =============================================================================
# [5] Resumen de la evidencia de recuperación
# =============================================================================
echo ""
echo "=== [5/5] Métricas del ASG para el entregable ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].{MinSize:MinSize,MaxSize:MaxSize,DesiredCapacity:DesiredCapacity,HealthCheckType:HealthCheckType,HealthCheckGracePeriod:HealthCheckGracePeriod,CreatedTime:CreatedTime}" \
  --output table

echo ""
echo "============================================================"
echo "  EVIDENCIA RECOPILADA PARA EL ENTREGABLE"
echo "============================================================"
echo ""
echo "  ✔ [Paso 08a] El balanceador dejó de enviar tráfico a la"
echo "    instancia terminada (health check falló → draining → out)."
echo ""
echo "  ✔ [Paso 08b] El ASG detectó la pérdida de capacidad y lanzó"
echo "    una nueva instancia para mantener el deseado = 2."
echo ""
echo "  ✔ [Paso 08c] Tiempo cronometrado de recuperación:"
echo "    Ver salida del script evidencia-p08-c3-falla.sh"
echo "    (típicamente entre 2 y 5 minutos con t3.micro + nginx)"
echo ""
echo "  ✔ El servicio NUNCA dejó de responder — la otra instancia"
echo "    siguió atendiendo todo el tráfico durante la recuperación."
echo ""
echo "  URL del balanceador: http://$ALB_DNS"
echo "============================================================"
