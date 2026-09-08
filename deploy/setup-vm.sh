#!/bin/bash
# ============================================================
# setup-vm.sh — Configura la máquina virtual Ubuntu para
# servir la API con HTTP y Nginx como proxy inverso.
# Usa la IP pública de la VM (sin dominio, sin HTTPS/Certbot).
#
# Probado en: Ubuntu 22.04 LTS
# Ejecutar como root en la VM:
#   sudo bash deploy/setup-vm.sh
# ============================================================

set -euo pipefail

APP_DIR="/var/www/inventario"
APP_PORT=3000
APP_USER="www-data"

# Detectar la IP pública de la VM automáticamente
VM_IP=$(hostname -I | awk '{print $1}')

echo "──────────────────────────────────────────"
echo " Inventario en la Nube — Configuración VM"
echo " IP detectada: $VM_IP"
echo "──────────────────────────────────────────"

echo "[1/7] Actualizando paquetes..."
apt-get update -y && apt-get upgrade -y

echo "[2/7] Instalando Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "[3/7] Instalando Nginx..."
apt-get install -y nginx

echo "[4/7] Instalando PM2 (gestor de procesos)..."
npm install -g pm2

echo "[5/7] Creando directorio de la aplicación..."
mkdir -p "$APP_DIR"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

echo "[6/7] Configurando Nginx (proxy HTTP → Node.js en puerto $APP_PORT)..."
cat > /etc/nginx/sites-available/inventario <<EOF
server {
    listen 80;
    server_name $VM_IP _;

    # Cabeceras de seguridad básicas
    add_header X-Frame-Options        DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy        "no-referrer-when-downgrade";

    # Logs
    access_log /var/log/nginx/inventario_access.log;
    error_log  /var/log/nginx/inventario_error.log warn;

    # Proxy inverso hacia Node.js
    location / {
        proxy_pass         http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 60s;
    }

    error_page 500 502 503 504 /50x.html;
}
EOF

ln -sf /etc/nginx/sites-available/inventario /etc/nginx/sites-enabled/inventario
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable nginx && systemctl reload nginx

echo "[7/7] Configurando firewall (UFW)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

echo ""
echo "✅ VM configurada correctamente."
echo ""
echo "   Pasos siguientes:"
echo "   1. Copia tu .env a:      $APP_DIR/.env"
echo "   2. Despliega el código:  bash deploy/deploy.sh $APP_USER@$VM_IP"
echo "   3. Crea las tablas:      ssh $APP_USER@$VM_IP 'cd $APP_DIR && node src/db/migrate.js'"
echo "   4. Carga datos prueba:   ssh $APP_USER@$VM_IP 'cd $APP_DIR && node src/db/seed.js'"
echo "   5. Health check:         http://$VM_IP/health"
