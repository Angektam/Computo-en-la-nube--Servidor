#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C1: Crear tablero CloudWatch con 5 gráficas
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Cubre: cómputo (EC2), base de datos (RDS), tráfico (ALB / peticiones HTTP)
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Uso:
#   bash evidencia-p13-c1-tablero.sh
#
# Qué hace:
#   1. Detecta el ID de la instancia EC2 y el identificador RDS del proyecto
#   2. Crea (o reemplaza) el tablero "Inventario-LosRojos-P13" con 5 widgets:
#      · EC2 CPUUtilization
#      · EC2 NetworkIn + NetworkOut
#      · RDS CPUUtilization
#      · RDS DatabaseConnections
#      · RDS FreeStorageSpace
#   3. Imprime la URL directa al tablero en la consola de AWS
#
# TOMAR CAPTURA del tablero en la consola de CloudWatch.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
DASHBOARD_NAME="Inventario-LosRojos-P13"
APP_TAG="inventario-nube"           # Tag Name de la EC2
RDS_ID="inventario-db"              # Identifier de la instancia RDS

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗  ERROR:${NC} $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C1 — Tablero CloudWatch"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Detectar EC2 ──────────────────────────────────────────────
info "Buscando instancia EC2 con Tag Name='${APP_TAG}'..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_TAG}" \
    "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  warn "No se encontró EC2 con tag Name=${APP_TAG}. Buscando cualquier instancia no-terminada..."
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || true)
fi

[ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ] \
  && err "No se encontró ninguna instancia EC2. Verifica que esté en estado running o stopped."

ok "EC2 encontrada: $INSTANCE_ID"

# ── 2. Detectar RDS ──────────────────────────────────────────────
info "Buscando instancia RDS '${RDS_ID}'..."
RDS_CHECK=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$RDS_ID" \
  --query "DBInstances[0].DBInstanceIdentifier" \
  --output text 2>/dev/null || true)

if [ -z "$RDS_CHECK" ] || [ "$RDS_CHECK" = "None" ]; then
  warn "No se encontró RDS con ID '${RDS_ID}'. Buscando primera instancia disponible..."
  RDS_ID=$(aws rds describe-db-instances \
    --region "$REGION" \
    --query "DBInstances[0].DBInstanceIdentifier" \
    --output text 2>/dev/null || true)
fi

[ -z "$RDS_ID" ] || [ "$RDS_ID" = "None" ] \
  && err "No se encontró ninguna instancia RDS."

ok "RDS encontrada: $RDS_ID"

# ── 3. Construir el JSON del tablero ─────────────────────────────
info "Construyendo JSON del tablero con 5 gráficas..."

DASHBOARD_BODY=$(cat <<JSON
{
  "widgets": [
    {
      "type": "text",
      "x": 0, "y": 0, "width": 24, "height": 2,
      "properties": {
        "markdown": "# Inventario Nube — Equipo Los Rojos\n**Tablero P13** · Sistema de gestión de inventario · Región: ${REGION} · `${INSTANCE_ID}` / `${RDS_ID}`\n\nEstado en 10 s: CPU cómputo · CPU base de datos · Conexiones · Almacenamiento libre · Tráfico de red"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 2, "width": 12, "height": 6,
      "properties": {
        "title": "EC2 · Uso de CPU (%)",
        "view": "timeSeries",
        "stacked": false,
        "stat": "Average",
        "period": 300,
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "InstanceId", "${INSTANCE_ID}",
           {"label": "CPU (%)", "color": "#e07b39"}]
        ],
        "yAxis": {"left": {"min": 0, "max": 100}},
        "annotations": {
          "horizontal": [
            {"label": "Umbral alarma (70%)", "value": 70, "color": "#d62728"}
          ]
        },
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 2, "width": 12, "height": 6,
      "properties": {
        "title": "EC2 · Tráfico de Red (bytes/min)",
        "view": "timeSeries",
        "stacked": false,
        "stat": "Sum",
        "period": 300,
        "metrics": [
          ["AWS/EC2", "NetworkIn",  "InstanceId", "${INSTANCE_ID}",
           {"label": "Entrada", "color": "#2ca02c"}],
          ["AWS/EC2", "NetworkOut", "InstanceId", "${INSTANCE_ID}",
           {"label": "Salida",  "color": "#1f77b4"}]
        ],
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 8, "width": 8, "height": 6,
      "properties": {
        "title": "RDS · Uso de CPU (%)",
        "view": "timeSeries",
        "stacked": false,
        "stat": "Average",
        "period": 300,
        "metrics": [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${RDS_ID}",
           {"label": "CPU RDS (%)", "color": "#9467bd"}]
        ],
        "yAxis": {"left": {"min": 0, "max": 100}},
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 8, "y": 8, "width": 8, "height": 6,
      "properties": {
        "title": "RDS · Conexiones activas",
        "view": "timeSeries",
        "stacked": false,
        "stat": "Average",
        "period": 300,
        "metrics": [
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${RDS_ID}",
           {"label": "Conexiones", "color": "#8c564b"}]
        ],
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 16, "y": 8, "width": 8, "height": 6,
      "properties": {
        "title": "RDS · Almacenamiento libre (bytes)",
        "view": "timeSeries",
        "stacked": false,
        "stat": "Average",
        "period": 300,
        "metrics": [
          ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", "${RDS_ID}",
           {"label": "Espacio libre", "color": "#17becf"}]
        ],
        "region": "${REGION}"
      }
    }
  ]
}
JSON
)

# ── 4. Crear / actualizar el tablero ─────────────────────────────
info "Creando tablero '${DASHBOARD_NAME}'..."
aws cloudwatch put-dashboard \
  --region "$REGION" \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body "$DASHBOARD_BODY" \
  --output text >/dev/null

ok "Tablero creado / actualizado"

# ── 5. Verificar ─────────────────────────────────────────────────
DASH_ARN=$(aws cloudwatch get-dashboard \
  --region "$REGION" \
  --dashboard-name "$DASHBOARD_NAME" \
  --query "DashboardArn" \
  --output text 2>/dev/null || true)

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  ✅  Tablero creado"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Nombre    : $DASHBOARD_NAME"
echo "  EC2       : $INSTANCE_ID"
echo "  RDS       : $RDS_ID"
[ -n "$DASH_ARN" ] && echo "  ARN       : $DASH_ARN"
echo ""
echo "  URL directa:"
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${DASHBOARD_NAME}"
echo ""
echo "  Gráficas incluidas:"
echo "    1. EC2 CPUUtilization (con línea de umbral al 70%)"
echo "    2. EC2 NetworkIn + NetworkOut"
echo "    3. RDS CPUUtilization"
echo "    4. RDS DatabaseConnections"
echo "    5. RDS FreeStorageSpace"
echo ""
echo -e "  ${YELLOW}*** ABRIR URL Y TOMAR CAPTURA DEL TABLERO COMPLETO ***${NC}"
echo ""
