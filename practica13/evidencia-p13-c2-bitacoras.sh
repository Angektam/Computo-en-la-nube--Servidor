#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C2: Enviar bitácoras de la aplicación a CloudWatch
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Qué hace:
#   1. Crea el Log Group /inventario-nube/app (si no existe)
#   2. Agrega permiso de escritura a CloudWatch Logs en el rol de la EC2
#   3. Instala el agente CloudWatch en la EC2 (via SSM Run Command)
#   4. Escribe la config del agente y lo arranca
#   5. Busca una petición concreta en los logs para comprobar que llegan
#
# Requisito: la EC2 debe tener SSM Agent activo (Ubuntu 22.04 lo incluye)
#            y el rol de la EC2 debe permitir SSM.
#            Si SSM no está disponible, el script imprime el comando SSH
#            equivalente para ejecutarlo manualmente.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
APP_TAG="inventario-nube"
LOG_GROUP="/inventario-nube/app"
LOG_STREAM_PREFIX="inventario-api"
IAM_ROLE="inventario-nube-ec2-role"
SSM_TIMEOUT=120   # segundos para esperar el Run Command

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗  ERROR:${NC} $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C2 — Bitácoras de la aplicación → CloudWatch Logs"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Detectar EC2 ──────────────────────────────────────────────
info "Buscando instancia EC2 con Tag Name='${APP_TAG}'..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_TAG}" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || true)
fi

[ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ] \
  && err "No se encontró EC2 en estado running."

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

ok "EC2: $INSTANCE_ID  (IP: $PUBLIC_IP)"

# ── 2. Crear Log Group ───────────────────────────────────────────
info "Creando Log Group '${LOG_GROUP}'..."
aws logs create-log-group \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP" 2>/dev/null \
  && ok "Log Group creado." \
  || ok "Log Group ya existía."

# Retención 30 días (capa gratuita cubre 5 GB)
aws logs put-retention-policy \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 30
ok "Retención ajustada a 30 días."

# ── 3. Agregar política CloudWatch Logs al rol de la EC2 ─────────
info "Verificando permisos CloudWatch Logs en el rol '${IAM_ROLE}'..."

POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}'

aws iam put-role-policy \
  --role-name "$IAM_ROLE" \
  --policy-name "${IAM_ROLE}-cloudwatch-logs" \
  --policy-document "$POLICY_DOC" \
  --output text >/dev/null 2>&1 \
  && ok "Política CloudWatch Logs aplicada al rol." \
  || warn "No se pudo actualizar el rol (puede que no tengas permisos IAM). Continúa manualmente."

# ── 4. Script de instalación del agente CloudWatch ───────────────
# Se intenta vía SSM Run Command; si falla, se imprime el equivalente SSH.
AGENT_INSTALL_SCRIPT=$(cat <<'AGENTSCRIPT'
#!/bin/bash
set -euo pipefail

LOG_GROUP="/inventario-nube/app"
LOG_STREAM_PREFIX="inventario-api"
REGION="us-east-1"

# 4.1 Instalar agente si no existe
if ! /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status 2>/dev/null | grep -q "amazon-cloudwatch-agent"; then
  echo "Instalando Amazon CloudWatch Agent..."
  cd /tmp
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  sudo dpkg -i amazon-cloudwatch-agent.deb
fi

# 4.2 Escribir configuración del agente
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<CWA_EOF
{
  "agent": {
    "run_as_user": "root",
    "region": "${REGION}"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/root/.pm2/logs/inventario-api-out.log",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "${LOG_STREAM_PREFIX}-out",
            "timezone": "UTC",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S"
          },
          {
            "file_path": "/root/.pm2/logs/inventario-api-error.log",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "${LOG_STREAM_PREFIX}-error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/inventario.access.log",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "nginx-access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/inventario.error.log",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "nginx-error",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWA_EOF

# 4.3 Iniciar / reiniciar agente
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Agente CloudWatch configurado y corriendo."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
AGENTSCRIPT
)

# ── 5. Intentar vía SSM Run Command ──────────────────────────────
info "Enviando script de instalación del agente vía SSM Run Command..."
SSM_COMMAND_ID=$(aws ssm send-command \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"${AGENT_INSTALL_SCRIPT//\"/\\\"}\"]" \
  --comment "P13 - Instalar agente CloudWatch" \
  --query "Command.CommandId" \
  --output text 2>/dev/null || true)

if [ -n "$SSM_COMMAND_ID" ] && [ "$SSM_COMMAND_ID" != "None" ]; then
  info "Command ID: $SSM_COMMAND_ID  — esperando resultado (${SSM_TIMEOUT}s)..."
  sleep 15
  SSM_STATUS=$(aws ssm get-command-invocation \
    --region "$REGION" \
    --command-id "$SSM_COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text 2>/dev/null || echo "Pending")

  ok "SSM Run Command estado: $SSM_STATUS"
  aws ssm get-command-invocation \
    --region "$REGION" \
    --command-id "$SSM_COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null | tail -20 || true
else
  warn "SSM no disponible. Ejecuta el script manualmente:"
  echo ""
  echo "  ssh -i ~/inventario-nube-key.pem ubuntu@${PUBLIC_IP} << 'EOF'"
  echo "$AGENT_INSTALL_SCRIPT"
  echo "EOF"
fi

# ── 6. Verificar que llegan logs ─────────────────────────────────
echo ""
info "Esperando 30 s para que el agente comience a enviar logs..."
sleep 30

info "Buscando peticiones recientes en el Log Group '${LOG_GROUP}'..."
aws logs filter-log-events \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name-prefix "$LOG_STREAM_PREFIX" \
  --max-items 10 \
  --output table 2>/dev/null \
  && ok "Logs encontrados en CloudWatch." \
  || warn "Aún no hay logs. Espera 1-2 minutos y ejecuta este comando manualmente:"

echo ""
echo "  aws logs filter-log-events \\"
echo "    --region ${REGION} \\"
echo "    --log-group-name '${LOG_GROUP}' \\"
echo "    --log-stream-name-prefix '${LOG_STREAM_PREFIX}' \\"
echo "    --max-items 10 --output table"

# ── 7. Buscar una petición concreta ──────────────────────────────
echo ""
info "Buscando petición concreta al endpoint /health en los logs..."
aws logs filter-log-events \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name-prefix "nginx-access" \
  --filter-pattern '"GET /health"' \
  --max-items 5 \
  --output table 2>/dev/null || true

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  ✅  Bitácoras configuradas"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Log Group   : $LOG_GROUP"
echo "  Log Streams : ${LOG_STREAM_PREFIX}-out"
echo "                ${LOG_STREAM_PREFIX}-error"
echo "                nginx-access"
echo "                nginx-error"
echo ""
echo "  URL directa a las bitácoras:"
ENCODED_GROUP=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${LOG_GROUP}', safe=''))" 2>/dev/null || echo "%2Finventario-nube%2Fapp")
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/${ENCODED_GROUP}"
echo ""
echo "  Para buscar una petición específica:"
echo "  aws logs filter-log-events \\"
echo "    --region ${REGION} \\"
echo "    --log-group-name '${LOG_GROUP}' \\"
echo "    --log-stream-name-prefix 'nginx-access' \\"
echo "    --filter-pattern '\"GET /api/\"' \\"
echo "    --max-items 5 --output table"
echo ""
echo -e "  ${YELLOW}*** TOMAR CAPTURA DE LOS LOGS EN LA CONSOLA DE CLOUDWATCH ***${NC}"
echo ""
