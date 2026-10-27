#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - CRITERIO 1: El balanceador distribuye tráfico
# Evidencia: respuestas con identificadores de instancia distintos
# Equipo: Los Rojos  |  21 oct 2026
#
# Ejecutar DESPUÉS de aws-practica08-alb-asg.sh
# Requiere que el ASG tenga al menos 2 instancias sanas (InService)
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ASG_NAME="asg-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  P08 · CRITERIO 1 — Balanceo con identificadores distintos"
echo "  Equipo: Los Rojos"
echo "============================================================"
echo ""

# --- Obtener DNS del ALB ---
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)

echo "DNS del balanceador: http://$ALB_DNS"
echo ""

# --- Estado del Target Group ---
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)

echo "=== Estado de los targets (instancias registradas) ==="
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Puerto:Target.Port,Estado:TargetHealth.State,Descripcion:TargetHealth.Description}" \
  --output table

echo ""
echo "=== Instancias del Auto Scaling Group ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,AZ:AvailabilityZone,Estado:LifecycleState,Salud:HealthStatus}" \
  --output table

# --- Esperar a que haya targets sanos ---
echo ""
echo "=== Verificando targets sanos antes de hacer peticiones... ==="
SANOS=0
INTENTOS=0
MAX_INTENTOS=20

while [ "$SANOS" -lt 2 ] && [ "$INTENTOS" -lt "$MAX_INTENTOS" ]; do
  SANOS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text)
  INTENTOS=$((INTENTOS + 1))
  if [ "$SANOS" -lt 2 ]; then
    echo "  Targets sanos: $SANOS/2 — esperando 15 s... ($INTENTOS/$MAX_INTENTOS)"
    sleep 15
  fi
done

if [ "$SANOS" -lt 2 ]; then
  echo "⚠ Solo $SANOS target(s) sano(s). Revisa el health check y los SG."
  echo "  Consejo: asegúrate de que /health responde 200 en los servidores."
else
  echo "✔ $SANOS targets sanos — listo para demostrar balanceo."
fi

echo ""
echo "============================================================"
echo "  DEMOSTRACIÓN DE BALANCEO — 10 peticiones al ALB"
echo "  Deberías ver al menos 2 Instance IDs distintos"
echo "============================================================"
echo ""

# Hacer 10 peticiones y capturar la línea que contiene el Instance ID
IDS_VISTOS=()
for i in $(seq 1 10); do
  RESPUESTA=$(curl -s --max-time 5 "http://$ALB_DNS/" 2>/dev/null)
  # Extraer el Instance ID del HTML (está entre "Instance ID: " y "<")
  IID=$(echo "$RESPUESTA" | grep -oP 'Instance ID: \K[^<]+' | tr -d ' ')
  AZ_RESP=$(echo "$RESPUESTA" | grep -oP 'Zona: \K[^<]+' | tr -d ' ')
  if [ -z "$IID" ]; then
    echo "  Petición $i: ⚠ sin respuesta o formato inesperado"
  else
    echo "  Petición $i: $IID  [$AZ_RESP]"
    IDS_VISTOS+=("$IID")
  fi
  sleep 1
done

echo ""
# Contar IDs únicos
IDS_UNICOS=$(printf '%s\n' "${IDS_VISTOS[@]}" | sort -u | wc -l)
echo "  Instance IDs únicos observados: $IDS_UNICOS"
printf '%s\n' "${IDS_VISTOS[@]}" | sort -u | while read -r id; do
  echo "    → $id"
done

echo ""
if [ "$IDS_UNICOS" -ge 2 ]; then
  echo "✔ CRITERIO CUMPLIDO: el balanceador distribuyó entre $IDS_UNICOS servidores distintos."
else
  echo "⚠ Solo respondió 1 instancia. Prueba en modo incógnito o desde otro equipo."
  echo "  El navegador puede estar reutilizando conexiones keep-alive."
fi

echo ""
echo "============================================================"
echo "  RESUMEN DEL ALB"
echo "============================================================"
aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].{Nombre:LoadBalancerName,DNS:DNSName,Estado:State.Code,AZs:AvailabilityZones[].ZoneName}" \
  --output table
echo ""
echo "  ➜ URL para captura de pantalla: http://$ALB_DNS"
echo "  Recarga varias veces y toma captura de cada Instance ID distinto."
echo "============================================================"
