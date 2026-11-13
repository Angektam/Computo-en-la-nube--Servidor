#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C5: Registro de auditoría (CloudTrail)
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Qué hace:
#   1. Busca en CloudTrail quién creó la instancia EC2 del proyecto y cuándo
#   2. Busca quién creó la instancia RDS
#   3. Busca quién creó el tablero de CloudWatch (P13)
#   4. Lista los últimos 10 eventos de la cuenta para mostrar auditoría general
#
# TOMAR CAPTURA de la salida completa.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
APP_TAG="inventario-nube"
RDS_ID="inventario-db"
DASHBOARD_NAME="Inventario-LosRojos-P13"

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C5 — Registro de auditoría (CloudTrail)"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Detectar EC2 ─────────────────────────────────────────────────
info "Detectando instancia EC2 del proyecto..."
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

[ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ] \
  && ok "EC2 encontrada: $INSTANCE_ID" \
  || warn "No se encontró EC2."

echo ""

# ══════════════════════════════════════════════════════════════════
# A — Quién creó la EC2 y cuándo
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  A · Creación de la instancia EC2${NC}"
echo "  ─────────────────────────────────────────────────────────"

if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
  info "Buscando evento RunInstances para $INSTANCE_ID en CloudTrail..."
  aws cloudtrail lookup-events \
    --region "$REGION" \
    --lookup-attributes "AttributeKey=ResourceName,AttributeValue=${INSTANCE_ID}" \
    --max-results 5 \
    --query "Events[?EventName=='RunInstances'].{Fecha:EventTime,Usuario:Username,IP:CloudTrailEvent}" \
    --output table 2>/dev/null \
    || warn "No se encontraron eventos RunInstances para $INSTANCE_ID (puede tardar hasta 15 min en aparecer)"

  # Formato más detallado
  echo ""
  info "Detalle del evento de creación:"
  aws cloudtrail lookup-events \
    --region "$REGION" \
    --lookup-attributes "AttributeKey=ResourceName,AttributeValue=${INSTANCE_ID}" \
    --max-results 1 \
    --query "Events[?EventName=='RunInstances'].{
      Evento:EventName,
      Fecha:EventTime,
      Usuario:Username,
      Origen:SourceIPAddress,
      Region:EventSource
    }" \
    --output json 2>/dev/null | python3 -m json.tool 2>/dev/null \
    || aws cloudtrail lookup-events \
        --region "$REGION" \
        --lookup-attributes "AttributeKey=ResourceName,AttributeValue=${INSTANCE_ID}" \
        --max-results 1 \
        --output json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -40 \
    || warn "Evento no disponible en el historial de los últimos 90 días."
fi

echo ""

# ══════════════════════════════════════════════════════════════════
# B — Quién creó la RDS
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  B · Creación de la instancia RDS${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Buscando evento CreateDBInstance para '${RDS_ID}'..."
aws cloudtrail lookup-events \
  --region "$REGION" \
  --lookup-attributes "AttributeKey=EventName,AttributeValue=CreateDBInstance" \
  --max-results 5 \
  --query "Events[].{Fecha:EventTime,Usuario:Username,Recurso:Resources[0].ResourceName}" \
  --output table 2>/dev/null \
  || warn "No se encontraron eventos CreateDBInstance."

echo ""

# ══════════════════════════════════════════════════════════════════
# C — Quién creó el tablero de CloudWatch (hoy)
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  C · Creación del tablero CloudWatch (P13)${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Buscando evento PutDashboard para '${DASHBOARD_NAME}'..."
aws cloudtrail lookup-events \
  --region "$REGION" \
  --lookup-attributes "AttributeKey=EventName,AttributeValue=PutDashboard" \
  --max-results 5 \
  --query "Events[].{Fecha:EventTime,Usuario:Username,IP:SourceIPAddress}" \
  --output table 2>/dev/null \
  || warn "Evento PutDashboard no encontrado (puede tardar hasta 15 min)."

echo ""

# ══════════════════════════════════════════════════════════════════
# D — Últimos 10 eventos de la cuenta (vista general de auditoría)
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  D · Últimos 10 eventos de la cuenta (auditoría general)${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Consultando los últimos 10 eventos de CloudTrail..."
aws cloudtrail lookup-events \
  --region "$REGION" \
  --max-results 10 \
  --query "Events[].{Fecha:EventTime,Evento:EventName,Usuario:Username,IP:CloudTrailEvent}" \
  --output table 2>/dev/null \
  || warn "No se pudieron obtener eventos."

# Formato más legible con solo los campos relevantes
echo ""
info "Formato compacto (Fecha · Usuario · Acción):"
aws cloudtrail lookup-events \
  --region "$REGION" \
  --max-results 10 \
  --query "Events[].{Fecha:EventTime,Accion:EventName,Usuario:Username,Origen:SourceIPAddress}" \
  --output table 2>/dev/null || true

echo ""

# ══════════════════════════════════════════════════════════════════
# E — Quién creó la alarma P13
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  E · Creación de la alarma P13${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Buscando evento PutMetricAlarm..."
aws cloudtrail lookup-events \
  --region "$REGION" \
  --lookup-attributes "AttributeKey=EventName,AttributeValue=PutMetricAlarm" \
  --max-results 3 \
  --query "Events[].{Fecha:EventTime,Usuario:Username,IP:SourceIPAddress}" \
  --output table 2>/dev/null \
  || warn "Evento PutMetricAlarm no encontrado."

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  ✅  Auditoría CloudTrail consultada"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  URL directa a CloudTrail:"
echo "  https://${REGION}.console.aws.amazon.com/cloudtrail/home?region=${REGION}#/events"
echo ""
echo "  Para buscar manualmente un recurso específico:"
echo "  aws cloudtrail lookup-events \\"
echo "    --region ${REGION} \\"
echo "    --lookup-attributes 'AttributeKey=ResourceName,AttributeValue=<ID>' \\"
echo "    --max-results 10 --output table"
echo ""
echo -e "  ${YELLOW}*** TOMAR CAPTURA DE LA SECCIÓN C (creación del tablero)"
echo -e "      O DE LA SECCIÓN D (últimos eventos) ***${NC}"
echo ""
