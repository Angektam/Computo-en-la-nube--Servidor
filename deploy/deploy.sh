#!/bin/bash
# ============================================================
# deploy.sh — Despliega una nueva versión de la API en la VM.
#
# Uso desde tu máquina local:
#   bash deploy/deploy.sh usuario@ip-de-la-vm
#
# Requisitos locales: ssh, rsync
# ============================================================

set -euo pipefail

REMOTE="${1:?'Uso: bash deploy/deploy.sh usuario@ip-vm'}"
APP_DIR="/var/www/inventario"

echo "──────────────────────────────────────────"
echo " Desplegando en $REMOTE"
echo "──────────────────────────────────────────"

echo "[1/3] Sincronizando código..."
rsync -az --delete \
  --exclude='node_modules/' \
  --exclude='.env' \
  --exclude='.git/' \
  --exclude='*.log' \
  ./ "$REMOTE:$APP_DIR/"

echo "[2/3] Instalando dependencias de producción..."
ssh "$REMOTE" "cd $APP_DIR && npm install --omit=dev"

echo "[3/3] Reiniciando la aplicación con PM2..."
ssh "$REMOTE" "pm2 restart inventario-api || pm2 start $APP_DIR/src/server.js --name inventario-api && pm2 save"

echo ""
echo "✅ Despliegue completado."
ssh "$REMOTE" "pm2 show inventario-api | grep -E 'status|uptime|restarts'"
