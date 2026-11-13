#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C4: Disparar la alarma de forma controlada
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Dos métodos (elige uno):
#   MÉTODO A (recomendado): Forzar el estado de la alarma directamente con
#                            set-alarm-state (sin necesidad de generar carga real)
#   MÉTODO B (alternativo):  Bajar el umbral temporalmente a 5% para que
#                            cualquier actividad lo supere
#
# Después de capturar la evidencia, el script restaura el umbral original.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
ALARM_NAME="Inventario-EC2-CPU-Alta-LosRojos"
APP_TAG="inventario-nube"

# Umbral real del proyecto
THRESHOLD_REAL=70
# Umbral temporal para el Método B
THRESHOLD_TEST=5

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗  ERROR:${NC} $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C4 — Disparar la alarma de forma controlada"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Verificar que la alarma existe ───────────────────────────────
info "Verificando que la alarma '${ALARM_NAME}' existe..."
ALARM_EXISTS=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].AlarmName" \
  --output text 2>/dev/null || true)

[ -z "$ALARM_EXISTS" ] || [ "$ALARM_EXISTS" = "None" ] \
  && err "Alarma '${ALARM_NAME}' no encontrada. Ejecuta primero evidencia-p13-c3-umbral.sh"

CURRENT_STATE=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].StateValue" \
  --output text)

ok "Alarma encontrada. Estado actual: $CURRENT_STATE"
echo ""

# ══════════════════════════════════════════════════════════════════
# MÉTODO A — set-alarm-state (recomendado para evidencia académica)
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  MÉTODO A: Forzar estado ALARM directamente${NC}"
echo "  ─────────────────────────────────────────────────────────"
echo "  Este método usa set-alarm-state para poner la alarma en"
echo "  estado ALARM sin modificar el umbral ni generar carga real."
echo "  Es la forma documentada de probar alarmas en AWS."
echo ""

info "Forzando estado ALARM en '${ALARM_NAME}'..."
aws cloudwatch set-alarm-state \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --state-value "ALARM" \
  --state-reason "Prueba controlada P13 — se fuerza ALARM para verificar notificacion SNS. Umbral real: ${THRESHOLD_REAL}%." \
  --state-reason-data "{\"criterio\":\"prueba_controlada\",\"umbral_real\":${THRESHOLD_REAL},\"practica\":\"P13\"}"

ok "Estado forzado a ALARM"

# Esperar y verificar
sleep 5
STATE_AFTER=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].StateValue" \
  --output text)

STATE_REASON=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query "MetricAlarms[0].StateReason" \
  --output text)

echo ""
echo -e "  Estado actual  : ${BOLD}${RED}${STATE_AFTER}${NC}"
echo "  Motivo         : $STATE_REASON"
echo ""

if [ "$STATE_AFTER" = "ALARM" ]; then
  ok "La alarma está en estado ALARM."
  echo ""
  echo -e "  ${YELLOW}ACCIONES INMEDIATAS:${NC}"
  echo "  1. Revisa el correo del equipo — debe llegar la notificación SNS"
  echo "     (Si no llega, confirma la suscripción desde el correo de AWS)"
  echo "  2. Abre la consola CloudWatch → Alarmas → '${ALARM_NAME}'"
  echo "  3. Toma captura del estado ALARM (recuadro rojo)"
  echo "  4. Toma captura del correo recibido"
  echo ""
  echo -e "  ${YELLOW}URL directa a la alarma:${NC}"
  ALARM_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${ALARM_NAME}', safe=''))" 2>/dev/null || echo "$ALARM_NAME")
  echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:alarm/${ALARM_ENC}"
fi

echo ""
echo "  ─────────────────────────────────────────────────────────"
echo -e "${BOLD}  MÉTODO B: Bajar umbral temporalmente (alternativo)${NC}"
echo "  ─────────────────────────────────────────────────────────"
echo "  Si prefieres que la alarma se dispare por datos reales de CPU:"
echo ""
echo "  PASO 1 — Detectar EC2 y bajar umbral:"
echo "    INSTANCE_ID=\$(aws ec2 describe-instances \\"
echo "      --region ${REGION} \\"
echo "      --filters 'Name=tag:Name,Values=${APP_TAG}' 'Name=instance-state-name,Values=running' \\"
echo "      --query 'Reservations[0].Instances[0].InstanceId' --output text)"
echo ""
echo "    aws cloudwatch put-metric-alarm \\"
echo "      --region ${REGION} \\"
echo "      --alarm-name '${ALARM_NAME}' \\"
echo "      --namespace AWS/EC2 --metric-name CPUUtilization \\"
echo "      --dimensions \"Name=InstanceId,Value=\$INSTANCE_ID\" \\"
echo "      --statistic Average --period 60 --evaluation-periods 1 \\"
echo "      --threshold ${THRESHOLD_TEST} \\"
echo "      --comparison-operator GreaterThanOrEqualToThreshold \\"
echo "      --alarm-actions <ARN_SNS>"
echo ""
echo "  PASO 2 — Generar carga (en la EC2 vía SSH):"
echo "    sudo apt-get install -y stress-ng"
echo "    stress-ng --cpu 2 --timeout 180s"
echo ""
echo "  PASO 3 — Restaurar umbral real:"
echo "    aws cloudwatch put-metric-alarm \\"
echo "      --region ${REGION} \\"
echo "      --alarm-name '${ALARM_NAME}' \\"
echo "      --namespace AWS/EC2 --metric-name CPUUtilization \\"
echo "      --dimensions \"Name=InstanceId,Value=\$INSTANCE_ID\" \\"
echo "      --statistic Average --period 300 --evaluation-periods 2 \\"
echo "      --threshold ${THRESHOLD_REAL} \\"
echo "      --comparison-operator GreaterThanOrEqualToThreshold \\"
echo "      --alarm-actions <ARN_SNS>"

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  Resumen de evidencia requerida"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  ✅ Captura 1: Alarma en estado ALARM (consola CloudWatch)"
echo "  ✅ Captura 2: Correo de notificación SNS recibido"
echo "  ✅ Captura 3: (Opcional) Historial de la alarma en la consola"
echo ""
echo -e "  ${YELLOW}*** TOMAR CAPTURAS ANTES DE CONTINUAR ***${NC}"
echo ""

# ── Instrucción para restaurar estado OK ─────────────────────────
echo "  Para restaurar la alarma a estado OK después de las capturas:"
echo ""
echo "  aws cloudwatch set-alarm-state \\"
echo "    --region ${REGION} \\"
echo "    --alarm-name '${ALARM_NAME}' \\"
echo "    --state-value OK \\"
echo "    --state-reason 'Restaurado después de prueba controlada P13'"
echo ""
