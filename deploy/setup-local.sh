#!/bin/bash
# ================================================================
# setup-local.sh — Instala y arranca el proyecto completo
#                  en Ubuntu (VirtualBox carpeta compartida).
#
# Cómo usarlo — abre una terminal en Ubuntu y ejecuta:
#
#   cd /home/ppp/Downloads/COMPUTO-EN-LA-NUVE
#   bash deploy/setup-local.sh
#
# ================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔ $*${NC}"; }
info() { echo -e "${YELLOW}  → $*${NC}"; }
err()  { echo -e "${RED}  ✗ $*${NC}"; exit 1; }

APP_DIR="/home/ppp/Downloads/COMPUTO-EN-LA-NUVE"
DB_NAME="inventario"
DB_USER="inventario_user"
DB_PASS="inventario_pass_2024"
PORT=3000

echo ""
echo "════════════════════════════════════════════════"
echo "   🚀  Setup Inventario Nube — Los Rojos"
echo "════════════════════════════════════════════════"
echo ""

# ── 0. Verificar que estamos en la carpeta correcta ───────────
if [ ! -f "$APP_DIR/package.json" ]; then
  err "No se encontró package.json en $APP_DIR
      Asegúrate de que la carpeta compartida de VirtualBox esté montada."
fi
cd "$APP_DIR"
ok "Carpeta del proyecto encontrada"

# ── 1. Actualizar apt ─────────────────────────────────────────
info "Actualizando lista de paquetes..."
sudo apt-get update -qq
ok "apt actualizado"

# ── 2. Instalar Node.js (v20 LTS) ────────────────────────────
if command -v node &>/dev/null; then
  NODE_VER=$(node -v)
  ok "Node.js ya instalado ($NODE_VER)"
else
  info "Instalando Node.js v20 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - -qq
  sudo apt-get install -y nodejs -qq
  ok "Node.js $(node -v) instalado"
fi

# ── 3. Instalar PostgreSQL ────────────────────────────────────
if command -v psql &>/dev/null; then
  ok "PostgreSQL ya instalado"
else
  info "Instalando PostgreSQL..."
  sudo apt-get install -y postgresql postgresql-contrib -qq
  ok "PostgreSQL instalado"
fi

# Asegurar que está corriendo
sudo systemctl enable postgresql -q
sudo systemctl start  postgresql
ok "PostgreSQL corriendo"

# ── 4. Crear usuario y base de datos ─────────────────────────
info "Configurando base de datos..."

# Crear usuario si no existe
sudo -u postgres psql -tc \
  "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" \
  | grep -q 1 || \
  sudo -u postgres psql -c \
  "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" -q

# Crear base de datos si no existe
sudo -u postgres psql -tc \
  "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
  | grep -q 1 || \
  sudo -u postgres psql -c \
  "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" -q

# Permisos
sudo -u postgres psql -d "${DB_NAME}" -c \
  "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" -q
sudo -u postgres psql -d "${DB_NAME}" -c \
  "GRANT ALL ON SCHEMA public TO ${DB_USER};" -q 2>/dev/null || true

ok "Base de datos '${DB_NAME}' lista"

# ── 5. Crear .env si no existe ────────────────────────────────
if [ -f ".env" ]; then
  ok ".env ya existe — se respeta el existente"
else
  info "Generando archivo .env..."
  JWT_SECRET="jwt_$(openssl rand -hex 32 2>/dev/null || echo 'secreto_local_cambiar_en_produccion_123456789')"
  cat > .env <<ENVEOF
# ─── Servidor ────────────────────────────────────────────────
PORT=${PORT}
NODE_ENV=production

# ─── PostgreSQL local ────────────────────────────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_SSL=false

# ─── AWS / S3 — no requerido para uso local ──────────────────
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=local_fake_key
AWS_SECRET_ACCESS_KEY=local_fake_secret
S3_BUCKET=inventario-archivos

# ─── Supabase — no requerido para uso local ──────────────────
SUPABASE_URL=http://localhost
SUPABASE_SERVICE_KEY=local_fake_key
SUPABASE_BUCKET=inventario-archivos

# ─── JWT ─────────────────────────────────────────────────────
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=8h
ENVEOF
  ok ".env generado"
fi

# ── 6. Instalar dependencias npm ──────────────────────────────
info "Instalando dependencias npm..."

# La carpeta compartida de VirtualBox no soporta enlaces simbólicos,
# por eso instalamos node_modules fuera de la carpeta compartida
# y creamos un enlace hacia allá.
NODE_MODULES_REAL="/tmp/inventario_node_modules"

if [ ! -d "$NODE_MODULES_REAL" ]; then
  mkdir -p "$NODE_MODULES_REAL"
fi

# Copiar package.json al directorio temporal para instalar ahí
cp package.json "$NODE_MODULES_REAL/"
cp package-lock.json "$NODE_MODULES_REAL/" 2>/dev/null || true

# Instalar en el directorio real
(cd "$NODE_MODULES_REAL" && npm install --omit=dev --silent)

# Si ya existe node_modules en el proyecto, borrarlo
if [ -d "$APP_DIR/node_modules" ] && [ ! -L "$APP_DIR/node_modules" ]; then
  rm -rf "$APP_DIR/node_modules"
fi

# Crear enlace simbólico si no existe
if [ ! -L "$APP_DIR/node_modules" ]; then
  ln -s "$NODE_MODULES_REAL/node_modules" "$APP_DIR/node_modules"
fi

ok "Dependencias instaladas"

# ── 7. Crear tablas ───────────────────────────────────────────
info "Creando tablas en la base de datos..."
node src/db/migrate.js
ok "Tablas creadas"

# ── 8. Cargar datos de prueba ─────────────────────────────────
info "Cargando datos de prueba..."
node src/db/seed.js
ok "Datos de prueba cargados"

# ── 9. Instalar PM2 y arrancar ────────────────────────────────
if ! command -v pm2 &>/dev/null; then
  info "Instalando PM2..."
  sudo npm install -g pm2 --silent
  ok "PM2 instalado"
fi

info "Arrancando aplicación con PM2..."
pm2 stop inventario-api 2>/dev/null || true
pm2 start src/server.js \
  --name inventario-api \
  --cwd "$APP_DIR" \
  --update-env

# Guardar proceso para que reinicie con el sistema
pm2 save
# Configurar autostart al boot
pm2 startup systemd -u ppp --hp /home/ppp 2>/dev/null | tail -1 | bash 2>/dev/null || true

ok "Aplicación corriendo con PM2"

# ── 10. Verificar que responde ────────────────────────────────
info "Verificando servidor..."
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" 2>/dev/null || echo "000")

echo ""
echo "════════════════════════════════════════════════"
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "  ${GREEN}✅  ¡Instalación completada con éxito!${NC}"
else
  echo -e "  ${YELLOW}⚠️  Instalación lista. Verifica manualmente.${NC}"
fi
echo "════════════════════════════════════════════════"
echo ""
echo "  🌐  Abrir en el navegador:"
echo "      http://localhost:${PORT}"
echo ""
echo "  👤  Usuarios de prueba:"
echo "      admin@empresa.com   →  Admin1234!  (administrador)"
echo "      bodega@empresa.com  →  Admin1234!  (bodega)"
echo "      cajero@empresa.com  →  Admin1234!  (cajero)"
echo ""
echo "  🔧  Comandos útiles:"
echo "      pm2 status                  — ver estado"
echo "      pm2 logs inventario-api     — ver logs en vivo"
echo "      pm2 restart inventario-api  — reiniciar"
echo "      pm2 stop inventario-api     — detener"
echo ""
echo "  📁  Proyecto en: $APP_DIR"
echo ""
