#!/bin/bash
# ============================================================
# full-deploy.sh — Despliega TODO el proyecto en la VM:
#   1. Copia el código
#   2. Copia el .env
#   3. Instala dependencias
#   4. Instala PostgreSQL local si no existe
#   5. Crea la base de datos y usuario
#   6. Crea las tablas (migrate)
#   7. Carga datos de prueba (seed)
#   8. Arranca con PM2
#
# Uso desde la raíz del proyecto:
#   bash deploy/full-deploy.sh usuario@ip-vm
#
# Ejemplo:
#   bash deploy/full-deploy.sh ppp@10.0.2.15
# ============================================================

set -euo pipefail

REMOTE="${1:?'Uso: bash deploy/full-deploy.sh usuario@ip-vm'}"
APP_DIR="/var/www/inventario"
DB_NAME="inventario"
DB_USER="inventario_user"
DB_PASS="inventario_pass_2024"

echo "══════════════════════════════════════════"
echo "  Full Deploy → $REMOTE"
echo "══════════════════════════════════════════"

# ── 1. Verificar que existe el .env local ──────────────────────
if [ ! -f ".env" ]; then
  echo "⚠️  No se encontró .env, generando uno con PostgreSQL local..."
  cat > .env <<ENVEOF
# ─── Servidor ────────────────────────────────────────────────
PORT=3000
NODE_ENV=production

# ─── PostgreSQL local (instalado en la VM) ───────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_SSL=false

# ─── AWS — no requerido para pruebas locales ─────────────────
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=fake_key
AWS_SECRET_ACCESS_KEY=fake_secret
S3_BUCKET=inventario-archivos

# ─── Supabase — no requerido para pruebas locales ────────────
SUPABASE_URL=http://localhost
SUPABASE_SERVICE_KEY=fake_key
SUPABASE_BUCKET=inventario-archivos

# ─── JWT ─────────────────────────────────────────────────────
JWT_SECRET=jwt_secreto_local_muy_largo_cambiar_en_prod_$(date +%s)
JWT_EXPIRES_IN=8h
ENVEOF
  echo "   .env generado con PostgreSQL local ✓"
fi

# ── 2. Crear directorio en la VM ───────────────────────────────
echo "[1/8] Preparando directorio en la VM..."
ssh "$REMOTE" "sudo mkdir -p $APP_DIR && sudo chown -R \$(id -un):\$(id -gn) $APP_DIR" 2>/dev/null || \
ssh "$REMOTE" "mkdir -p $APP_DIR"

# ── 3. Sincronizar código ──────────────────────────────────────
echo "[2/8] Copiando código..."
rsync -az --delete \
  --exclude='node_modules/' \
  --exclude='.env' \
  --exclude='.git/' \
  --exclude='*.log' \
  ./ "$REMOTE:$APP_DIR/"

# ── 4. Copiar .env ─────────────────────────────────────────────
echo "[3/8] Copiando .env..."
rsync -az .env "$REMOTE:$APP_DIR/.env"

# ── 5. Instalar dependencias ───────────────────────────────────
echo "[4/8] Instalando dependencias de producción..."
ssh "$REMOTE" "cd $APP_DIR && npm install --omit=dev"

# ── 6. Instalar y configurar PostgreSQL en la VM ──────────────
echo "[5/8] Configurando PostgreSQL local..."
ssh "$REMOTE" bash <<SSHEOF
  # Instalar PostgreSQL si no está instalado
  if ! command -v psql &> /dev/null; then
    echo "  Instalando PostgreSQL..."
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
  else
    echo "  PostgreSQL ya instalado ✓"
  fi

  # Crear usuario y base de datos si no existen
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

  # Permisos en schema public (PostgreSQL 15+)
  sudo -u postgres psql -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" 2>/dev/null || true

  echo "  Base de datos lista ✓"
SSHEOF

# ── 7. Migración y seed ────────────────────────────────────────
echo "[6/8] Creando tablas..."
ssh "$REMOTE" "cd $APP_DIR && node src/db/migrate.js"

echo "[7/8] Cargando datos de prueba..."
ssh "$REMOTE" "cd $APP_DIR && node src/db/seed.js"

# ── 8. Arrancar con PM2 ────────────────────────────────────────
echo "[8/8] Arrancando aplicación con PM2..."
ssh "$REMOTE" "pm2 restart inventario-api --update-env 2>/dev/null || pm2 start $APP_DIR/src/server.js --name inventario-api && pm2 save"

# ── Resultado ──────────────────────────────────────────────────
VM_IP=$(echo "$REMOTE" | cut -d'@' -f2)
echo ""
echo "══════════════════════════════════════════"
echo "  ✅ Despliegue completo"
echo "══════════════════════════════════════════"
echo ""
ssh "$REMOTE" "pm2 show inventario-api | grep -E 'status|uptime|restarts'" || true
echo ""
echo "  🌐 App:          http://$VM_IP"
echo "  🩺 Health check: http://$VM_IP/health"
echo ""
echo "  👤 Usuario admin:  admin@empresa.com"
echo "  🔑 Contraseña:     Admin1234!"
echo ""
