#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CRITERIO 5: Política de escalado + cierre de sesión
# Evidencia: política CPU al 60 %, justificación, reducir a 1 instancia
# Equipo: Los Rojos  |  21 oct 2026
#
# PASOS QUE CUBRE:
#   paso 09a — Mostrar la política de escalado configurada y justificarla
#   paso 09b — Reducir el ASG a 1 instancia al cierre de la sesión
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
POLICY_NAME="policy-cpu-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · CRITERIO 5 — Política de escalado y cierre de sesión"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

# =============================================================================
# [1] Mostrar la política de escalado configurada
# =============================================================================
echo "=== [1/4] Política de escalado por CPU ==="
aws autoscaling describe-policies \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-names "$POLICY_NAME" \
  --query "ScalingPolicies[0].{Nombre:PolicyName,Tipo:PolicyType,MetricaTarget:TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType,Umbral:TargetTrackingConfiguration.TargetValue,CooldownScaleOut:TargetTrackingConfiguration.ScaleOutCooldown,CooldownScaleIn:TargetTrackingConfiguration.ScaleInCooldown}" \
  --output table

echo ""
echo "  JUSTIFICACIÓN DEL UMBRAL (60 % de CPU):"
echo "  ─────────────────────────────────────────────────────────"
echo "  · Por qué NO 80 %: a 80 % el servidor ya está saturado;"
echo "    el escalado tardaría ~2 min y los usuarios ya estarían"
echo "    experimentando latencia alta."
echo ""
echo "  · Por qué NO 40 %: escalaría ante cargas normales, creando"
echo "    instancias innecesarias que incrementan el costo."
echo ""
echo "  · Por qué 60 %: punto de equilibrio. El servidor está"
echo "    comprometido pero no degradado. Hay tiempo suficiente"
echo "    para que la nueva instancia arranque (~60 s) antes de"
echo "    llegar a saturación. Alineado con recomendaciones AWS."
echo ""
echo "  · Cooldown scale-out 120 s: evita crear múltiples instancias"
echo "    en ráfagas cortas antes de que las nuevas estén activas."
echo ""
echo "  · Cooldown scale-in 300 s: no destruye instancias ante"
echo "    bajadas momentáneas de carga; espera 5 min para confirmar."
echo "  ─────────────────────────────────────────────────────────"

# =============================================================================
# [2] Estado actual antes de reducir
# =============================================================================
echo ""
echo "=== [2/4] Estado ANTES de reducir el grupo ==="
echo ""
echo "--- ASG ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].{Min:MinSize,Deseado:DesiredCapacity,Max:MaxSize}" \
  --output table

echo ""
echo "--- Instancias activas ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState}" \
  --output table

echo ""
echo "--- Targets en el balanceador ---"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State}" \
  --output table

# =============================================================================
# [3] Reducir el ASG a 1 instancia (cierre de sesión — criterio 6)
# =============================================================================
echo ""
echo "=== [3/4] Reducir el ASG a 1 instancia (cierre de sesión) ==="
echo ""
echo "  ⚠ Reduciendo min=1, desired=1 para ahorrar costos."
echo "    El balanceador seguirá activo (cobra por hora)."
echo "    Ver sección 6 del PDF para la decisión de costo."
echo ""

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --min-size 1 \
  --desired-capacity 1

echo "✔ ASG actualizado: min=1, desired=1, max=4"
echo "  El ASG terminará una instancia automáticamente."
echo ""
echo "  Esperando confirmación (30 s)..."
sleep 30

# =============================================================================
# [4] Estado DESPUÉS de reducir
# =============================================================================
echo ""
echo "=== [4/4] Estado DESPUÉS de reducir — captura para el entregable ==="
echo ""
echo "--- ASG reducido ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].{Nombre:AutoScalingGroupName,Min:MinSize,Deseado:DesiredCapacity,Max:MaxSize}" \
  --output table

echo ""
echo "--- Instancias restantes ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
  --output table

echo ""
echo "--- Target Group (debe quedar 1 instancia sana) ---"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Estado:TargetHealth.State}" \
  --output table

echo ""
echo "============================================================"
echo "  RESUMEN DE COSTOS — DECISIÓN DE CIERRE"
echo "============================================================"
echo ""
echo "  · ASG reducido a 1 instancia → ahorra ~50 % en EC2."
echo "  · El ALB SIGUE corriendo y cobra por hora (~\$0.016/h)."
echo ""
echo "  Opciones para el equipo:"
echo "  a) Mantener el ALB hasta la práctica 13 (más cómodo)"
echo "     → Responsable de costos revisa el gasto cada 2 días."
echo "  b) Eliminar el ALB hoy y recrearlo en la siguiente sesión"
echo "     → Ejecutar: parar-p08.sh  (elimina ALB + reduce ASG)"
echo ""
echo "  Anota en la bitácora la decisión y el gasto del día."
echo "============================================================"
