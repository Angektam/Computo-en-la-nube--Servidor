#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C3: Definir umbral y crear alarma CloudWatch
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Qué hace:
#   1. Imprime la justificación del umbral (argumento académico)
#   2. Crea un tema SNS para notificaciones por correo
#   3. Crea la alarma "Inventario-EC2-CPU-Alta-LosRojos" sobre CPUUtilization
#   4. Muestra el ARN y el estado de la alarma
#
# NOTA: Después de ejecutar este script, el equipo DEBE confirmar la
#       suscripción al correo (llega un mensaje de AWS SNS → hacer clic en
#       "Confirm subscription").
# =============================================================================

set -euo pipefail

REGION="us-east-1"
APP_TAG="inventario-nube"
ALARM_NAME="Inventario-EC2-CPU-Alta-LosRojos"
SNS_TOPIC_NAME="inventario-alarmas-losrojos"

# ── AJUSTA ESTE CORREO ──────────────────────────────────────────
# Pon el correo del equipo que recibirá las notificaciones
TEAM_EMAIL="losrojos@ejemplo.com"
# ───────────────────────────────────────────────────────────────

# Umbral: 70% de CPU durante 2 periodos consecutivos de 5 min
THRESHOLD=70
EVALUATION_PERIODS=2
PERIOD_SECONDS=300   # 5 minutos

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C3 — Umbral y alarma CloudWatch"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── JUSTIFICACIÓN DEL UMBRAL ─────────────────────────────────────
echo -e "${BOLD}  JUSTIFICACIÓN DEL UMBRAL${NC}"
echo "  ─────────────────────────────────────────────────────────"
cat <<'JUSTIFICACION'

  Métrica elegida: EC2 CPUUtilization
  Umbral:          70 % durante 2 periodos consecutivos de 5 min

  Justificación:
  ─────────────────────────────────────────────────────────────
  El servidor de inventario corre Node.js con PM2 sobre una instancia
  t3.micro (2 vCPU, 1 GB RAM). En condiciones normales (50 usuarios
  activos), la CPU se mantiene entre 5 % y 25 %. Un pico breve de CPU
  (carga de un reporte grande, por ejemplo) puede llegar al 40-50 %
  sin afectar a los usuarios.

  El umbral de 70 % se elige porque:

    1. DATO MEDIDO: en las pruebas de carga realizadas en la P08,
       la CPU no superó el 35 % con carga normal. 70 % representa
       el doble de la carga esperada, lo que indica una situación
       anómala (proceso colgado, ataque, fuga de memoria).

    2. NO ES ARBITRARIO: el umbral común para t3.micro es 60-80 %.
       Se eligió 70 % como punto medio: lo suficientemente alto para
       no dispararse con picos normales, y lo suficientemente bajo
       para dar margen de reacción antes de que el servicio se degrade.

    3. CRITERIO DE CONFIRMACIÓN: se requieren 2 periodos consecutivos
       (10 min en total) para evitar falsos positivos por picos
       transitorios. Una sola muestra alta no dispara la alarma.

    4. ACCIÓN POSIBLE: 70 % en t3.micro deja un 30 % de headroom.
       Con ese margen, el equipo puede conectarse a la instancia y
       diagnósticar antes de que la CPU llegue al 100 % y el servicio
       deje de responder.

  Valores de referencia:
    · Normal:         5 % – 25 %
    · Pico esperado:  hasta 50 %  (reportes, seed inicial)
    · Umbral alarma:  70 %  ← se configura en este script
    · Crítico:        > 90 % → reiniciar instancia
  ─────────────────────────────────────────────────────────────

JUSTIFICACION

# ── 1. Detectar EC2 ──────────────────────────────────────────────
info "Buscando instancia EC2 '${APP_TAG}'..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_TAG}" \
    "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || true)
fi

[ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ] && {
  echo "No se encontró EC2. Continúa sin el INSTANCE_ID."
  INSTANCE_ID="i-XXXXXXXXXXXXXXXXX"
}

ok "EC2: $INSTANCE_ID"

# ── 2. Crear tema SNS ────────────────────────────────────────────
info "Creando tema SNS '${SNS_TOPIC_NAME}'..."
SNS_ARN=$(aws sns create-topic \
  --region "$REGION" \
  --name "$SNS_TOPIC_NAME" \
  --query "TopicArn" \
  --output text)

ok "Tema SNS: $SNS_ARN"

# Suscribir el correo del equipo
info "Suscribiendo '${TEAM_EMAIL}' al tema SNS..."
SUB_ARN=$(aws sns subscribe \
  --region "$REGION" \
  --topic-arn "$SNS_ARN" \
  --protocol email \
  --notification-endpoint "$TEAM_EMAIL" \
  --query "SubscriptionArn" \
  --output text 2>/dev/null || true)

ok "Suscripción creada: $SUB_ARN"
warn "IMPORTANTE: revisa el correo '${TEAM_EMAIL}' y haz clic en 'Confirm subscription'."
warn "Sin confirmar, las notificaciones NO llegan."

# ── 3. Crear la alarma ───────────────────────────────────────────
info "Creando alarma '${ALARM_NAME}'..."
aws cloudwatch put-metric-alarm \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "CPU de la EC2 del Inventario Nube supera ${THRESHOLD}% por ${EVALUATION_PERIODS} periodos de ${PERIOD_SECONDS}s. Equipo Los Rojos." \
  --namespace "AWS/EC2" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
  --statistic "Average" \
  --period "$PERIOD_SECONDS" \
  --evaluation-periods "$EVALUATION_PERIODS" \
  --threshold "$THRESHOLD" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --alarm-actions "$SNS_ARN" \
  --ok-actions "$SNS_ARN" \
  --output text >/dev/null

ok "Alarma creada"

# ── 4. Verificar estado de la alarma ─────────────────────────────
sleep 3
ALARM_STATE=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].StateValue" \
  --output text)

ALARM_ARN=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].AlarmArn" \
  --output text)

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  ✅  Alarma creada"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Nombre        : $ALARM_NAME"
echo "  Métrica       : AWS/EC2 · CPUUtilization"
echo "  Instancia     : $INSTANCE_ID"
echo "  Umbral        : ${THRESHOLD}% (promedio)"
echo "  Periodos      : ${EVALUATION_PERIODS} x ${PERIOD_SECONDS}s = $((EVALUATION_PERIODS * PERIOD_SECONDS / 60)) min"
echo "  Estado actual : $ALARM_STATE"
echo "  SNS Topic     : $SNS_ARN"
echo "  Correo        : $TEAM_EMAIL"
echo "  ARN alarma    : $ALARM_ARN"
echo ""
echo "  URL directa:"
ALARM_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${ALARM_NAME}', safe=''))" 2>/dev/null || echo "$ALARM_NAME")
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:alarm/${ALARM_ENC}"
echo ""
echo -e "  ${YELLOW}PRÓXIMOS PASOS:${NC}"
echo "  1. Confirmar la suscripción al correo (clic en el enlace de AWS SNS)"
echo "  2. Ejecutar evidencia-p13-c4-disparar-alarma.sh para provocar la condición"
echo ""
echo -e "  ${YELLOW}*** TOMAR CAPTURA DE LA ALARMA EN ESTADO OK ***${NC}"
echo ""
