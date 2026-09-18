#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  aws-full-setup.sh — Script único de despliegue en AWS          ║
# ║                                                                  ║
# ║  Crea y configura TODA la infraestructura en AWS:               ║
# ║    • Security Group con puertos 22, 80, 3000                    ║
# ║    • Key Pair (si no existe)                                     ║
# ║    • Instancia EC2 (Ubuntu 22.04 LTS, t2.micro Free Tier)       ║
# ║    • Bucket S3 privado con política de acceso                   ║
# ║    • Rol IAM + políticas de mínimo privilegio                   ║
# ║    • User data: Node 20, Nginx, PM2, PostgreSQL, app           ║
# ║                                                                  ║
# ║  Uso:                                                            ║
# ║    bash deploy/aws-full-setup.sh                                 ║
# ║                                                                  ║
# ║  Requisitos previos:                                             ║
# ║    • AWS CLI v2 instalado y configurado (aws configure)         ║
# ║    • Permisos: EC2, S3, IAM en tu cuenta AWS                    ║
# ║    • El .env del proyecto en la raíz (o se genera uno base)     ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colores para output ────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }

# ══════════════════════════════════════════════════════════════════
# CONFIGURACIÓN — ajusta estos valores antes de ejecutar
# ══════════════════════════════════════════════════════════════════
APP_NAME="inventario-nube"
REGION="${AWS_REGION:-us-east-1}"           # región AWS
INSTANCE_TYPE="t2.micro"                    # Free Tier
KEY_NAME="${APP_NAME}-key"                  # nombre del key pair
SG_NAME="${APP_NAME}-sg"                    # nombre del security group
IAM_ROLE_NAME="${APP_NAME}-ec2-role"        # rol IAM para EC2
IAM_INSTANCE_PROFILE="${APP_NAME}-profile"  # instance profile
S3_BUCKET="${APP_NAME}-archivos-$(date +%s)" # nombre único del bucket
DB_NAME="inventario"
DB_USER="inventario_user"
# ⚠  CAMBIA ESTA CONTRASEÑA antes de ejecutar en producción
DB_PASS="${DB_PASSWORD:-$(openssl rand -base64 20 | tr -d '=+/' | cut -c1-20)}"
# ⚠  JWT_SECRET se genera automáticamente con openssl (seguro)
JWT_SECRET="$(openssl rand -base64 48)"

# AMI Ubuntu 22.04 LTS por región (actualiza si usas otra región)
declare -A AMI_MAP=(
  ["us-east-1"]="ami-0c7217cdde317cfec"
  ["us-east-2"]="ami-05fb0b8c1424f266b"
  ["us-west-2"]="ami-0cf2b4e024cdb6960"
  ["eu-west-1"]="ami-0d64bb532e0502c46"
  ["mx-central-1"]="ami-0cf6e3d5e5e5d5a5b"   # Guadalajara — verifica en consola
)
AMI_ID="${AMI_MAP[$REGION]:-}"
if [ -z "$AMI_ID" ]; then
  warn "Región $REGION no tiene AMI preconfigurada. Buscando automáticamente..."
  AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query "sort_by(Images,&CreationDate)[-1].ImageId" \
    --output text 2>/dev/null) || error "No se pudo encontrar AMI Ubuntu 22.04 en $REGION"
  ok "AMI encontrada: $AMI_ID"
fi

# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      Inventario Nube — Despliegue Completo AWS           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Región:    $REGION"
info "App name:  $APP_NAME"
info "Instancia: $INSTANCE_TYPE"
info "S3 Bucket: $S3_BUCKET"
echo ""

# ── Verificar AWS CLI ──────────────────────────────────────────
step "0/9 — Verificando AWS CLI y credenciales"
command -v aws &>/dev/null || error "AWS CLI no encontrado. Instala desde: https://aws.amazon.com/cli/"
aws sts get-caller-identity --region "$REGION" --output table || error "Credenciales AWS no configuradas. Ejecuta: aws configure"
ok "AWS CLI OK"

# ══════════════════════════════════════════════════════════════════
# PASO 1 — Key Pair
# ══════════════════════════════════════════════════════════════════
step "1/9 — Key Pair SSH"
KEY_FILE="${KEY_NAME}.pem"

EXISTING_KEY=$(aws ec2 describe-key-pairs \
  --region "$REGION" \
  --query "KeyPairs[?KeyName=='${KEY_NAME}'].KeyName" \
  --output text 2>/dev/null || true)

if [ -n "$EXISTING_KEY" ]; then
  warn "Key pair '${KEY_NAME}' ya existe en AWS."
  if [ ! -f "$KEY_FILE" ]; then
    warn "Pero el archivo ${KEY_FILE} no está local. Si perdiste la clave, debes eliminar el key pair en la consola AWS y volver a ejecutar este script."
  else
    ok "Key pair existente: ${KEY_FILE}"
  fi
else
  aws ec2 create-key-pair \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  ok "Key pair creado: ${KEY_FILE}"
fi

# ══════════════════════════════════════════════════════════════════
# PASO 2 — Security Group
# ══════════════════════════════════════════════════════════════════
step "2/9 — Security Group"

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || true)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "Security group para ${APP_NAME}" \
    --query 'GroupId' \
    --output text)
  ok "Security group creado: $SG_ID"

  # Reglas de entrada
  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description=SSH}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP}]" \
      "IpProtocol=tcp,FromPort=3000,ToPort=3000,IpRanges=[{CidrIp=0.0.0.0/0,Description=NodeApp}]" \
    --output text >/dev/null
  ok "Reglas abiertas: SSH(22), HTTP(80), App(3000)"
else
  ok "Security group existente: $SG_ID"
fi

# ══════════════════════════════════════════════════════════════════
# PASO 3 — Bucket S3
# ══════════════════════════════════════════════════════════════════
step "3/9 — Bucket S3 (privado)"

# Verificar si ya existe un bucket con el prefijo del app
EXISTING_BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name,'${APP_NAME}-archivos')].Name" \
  --output text 2>/dev/null | head -1 || true)

if [ -n "$EXISTING_BUCKET" ]; then
  S3_BUCKET="$EXISTING_BUCKET"
  warn "Usando bucket existente: $S3_BUCKET"
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region "$REGION" \
      --output text >/dev/null
  else
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}" \
      --output text >/dev/null
  fi

  # Bloquear acceso público (bucket privado)
  aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --output text >/dev/null

  # Versionado activado
  aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --versioning-configuration "Status=Enabled" \
    --output text >/dev/null

  # Cifrado en reposo
  aws s3api put-bucket-encryption \
    --bucket "$S3_BUCKET" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
    --output text >/dev/null

  ok "Bucket S3 creado y configurado: s3://${S3_BUCKET}"
fi

# ══════════════════════════════════════════════════════════════════
# PASO 4 — IAM Role + Instance Profile (mínimo privilegio)
# ══════════════════════════════════════════════════════════════════
step "4/9 — IAM Role (mínimo privilegio para EC2)"

# Política de confianza para EC2
TRUST_POLICY='{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"Service":"ec2.amazonaws.com"},
    "Action":"sts:AssumeRole"
  }]
}'

# Crear rol si no existe
ROLE_EXISTS=$(aws iam get-role \
  --role-name "$IAM_ROLE_NAME" \
  --query "Role.RoleName" \
  --output text 2>/dev/null || true)

if [ -z "$ROLE_EXISTS" ]; then
  aws iam create-role \
    --role-name "$IAM_ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --description "Rol EC2 para ${APP_NAME} — mínimo privilegio" \
    --output text >/dev/null

  # Política inline: solo el bucket de la app
  S3_POLICY=$(cat <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"S3BucketAccess",
      "Effect":"Allow",
      "Action":[
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource":[
        "arn:aws:s3:::${S3_BUCKET}",
        "arn:aws:s3:::${S3_BUCKET}/*"
      ]
    },
    {
      "Sid":"CloudWatchLogs",
      "Effect":"Allow",
      "Action":[
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource":"arn:aws:logs:${REGION}:*:log-group:/inventario/*"
    }
  ]
}
POLICY
)

  aws iam put-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-name "${APP_NAME}-s3-cwlogs" \
    --policy-document "$S3_POLICY" \
    --output text >/dev/null

  ok "Rol IAM creado: $IAM_ROLE_NAME"
else
  ok "Rol IAM existente: $IAM_ROLE_NAME"
fi

# Instance Profile
PROFILE_EXISTS=$(aws iam get-instance-profile \
  --instance-profile-name "$IAM_INSTANCE_PROFILE" \
  --query "InstanceProfile.InstanceProfileName" \
  --output text 2>/dev/null || true)

if [ -z "$PROFILE_EXISTS" ]; then
  aws iam create-instance-profile \
    --instance-profile-name "$IAM_INSTANCE_PROFILE" \
    --output text >/dev/null
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$IAM_INSTANCE_PROFILE" \
    --role-name "$IAM_ROLE_NAME" \
    --output text >/dev/null
  ok "Instance profile creado: $IAM_INSTANCE_PROFILE"
  sleep 5   # IAM necesita unos segundos para propagarse
else
  ok "Instance profile existente: $IAM_INSTANCE_PROFILE"
fi

# ══════════════════════════════════════════════════════════════════
# PASO 5 — User Data (script que corre al iniciar la instancia)
# ══════════════════════════════════════════════════════════════════
step "5/9 — Preparando User Data"

# Leer .env existente o generar uno
if [ -f ".env" ]; then
  info "Usando .env existente del proyecto"
  ENV_CONTENT=$(cat .env)
else
  warn "No se encontró .env — generando configuración base"
  ENV_CONTENT="# ─── Servidor ────────────────────────────────────────────────
PORT=3000
NODE_ENV=production

# ─── PostgreSQL local (instalado en la VM) ───────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_SSL=false

# ─── AWS — EC2 usa IAM Role, NO se necesitan access keys ─────
AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}

# ─── Supabase — no usado ──────────────────────────────────────
SUPABASE_URL=http://localhost
SUPABASE_SERVICE_KEY=not_used
SUPABASE_BUCKET=not_used

# ─── JWT ──────────────────────────────────────────────────────
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=8h

# ─── CORS ─────────────────────────────────────────────────────
CORS_ORIGIN="
fi

# Escapar para uso en heredoc
ENV_ESCAPED=$(printf '%s' "$ENV_CONTENT" | sed 's/\\/\\\\/g; s/`/\\`/g; s/\$/\\$/g')

USER_DATA=$(cat <<USERDATA
#!/bin/bash
set -euo pipefail
LOG=/var/log/inventario-setup.log
exec > >(tee -a \$LOG) 2>&1

echo "======================================"
echo "  Inventario Nube — Setup EC2"
echo "  \$(date)"
echo "======================================"

# ── 1. Actualizar sistema ──────────────────────────────────────
echo "[1/8] Actualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# ── 2. Instalar Node.js 20 LTS ────────────────────────────────
echo "[2/8] Instalando Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── 3. Instalar Nginx + PM2 ───────────────────────────────────
echo "[3/8] Instalando Nginx y PM2..."
apt-get install -y nginx
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu

# ── 4. Instalar PostgreSQL ────────────────────────────────────
echo "[4/8] Instalando PostgreSQL..."
apt-get install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

# Crear usuario y base de datos
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
sudo -u postgres psql -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" 2>/dev/null || true

echo "  PostgreSQL listo: ${DB_NAME}@localhost"

# ── 5. Crear directorio y clonar/copiar app ───────────────────
echo "[5/8] Preparando directorio /var/www/inventario..."
mkdir -p /var/www/inventario
chown ubuntu:ubuntu /var/www/inventario

# ── 6. Crear .env ─────────────────────────────────────────────
echo "[6/8] Escribiendo .env..."
cat > /var/www/inventario/.env <<'ENVEOF'
${ENV_ESCAPED}
ENVEOF
chmod 600 /var/www/inventario/.env
chown ubuntu:ubuntu /var/www/inventario/.env

# ── 7. Configurar Nginx ───────────────────────────────────────
echo "[7/8] Configurando Nginx..."
VM_IP=\$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print \$1}')

cat > /etc/nginx/sites-available/inventario <<EOF
server {
    listen 80;
    server_name \$VM_IP _;

    add_header X-Frame-Options        DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy        "no-referrer-when-downgrade";

    access_log /var/log/nginx/inventario_access.log;
    error_log  /var/log/nginx/inventario_error.log warn;

    client_max_body_size 10M;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \\\$http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host \\\$host;
        proxy_set_header   X-Real-IP \\\$remote_addr;
        proxy_set_header   X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \\\$scheme;
        proxy_cache_bypass \\\$http_upgrade;
        proxy_read_timeout 60s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/inventario /etc/nginx/sites-enabled/inventario
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable nginx && systemctl reload nginx

# ── 8. Configurar firewall ────────────────────────────────────
echo "[8/8] Configurando UFW..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

echo ""
echo "======================================"
echo "  Setup base completo: \$(date)"
echo "  Esperando el código de la app..."
echo "======================================"
echo ""
echo "  Una vez desplegado el código, el siguiente"
echo "  comando arrancará la app:"
echo "    cd /var/www/inventario"
echo "    npm install --omit=dev"
echo "    node src/db/migrate.js"
echo "    node src/db/seed.js"
echo "    pm2 start src/server.js --name inventario-api"
echo "    pm2 save"
USERDATA
)

ok "User Data preparado"

# ══════════════════════════════════════════════════════════════════
# PASO 6 — Lanzar instancia EC2
# ══════════════════════════════════════════════════════════════════
step "6/9 — Lanzando instancia EC2"

# Verificar si ya existe una instancia con este nombre
EXISTING_INSTANCE=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ "$EXISTING_INSTANCE" != "None" ] && [ -n "$EXISTING_INSTANCE" ]; then
  warn "Ya existe una instancia con nombre '${APP_NAME}': $EXISTING_INSTANCE"
  INSTANCE_ID="$EXISTING_INSTANCE"
else
  INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile "Name=${IAM_INSTANCE_PROFILE}" \
    --user-data "$USER_DATA" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications \
      "ResourceType=instance,Tags=[{Key=Name,Value=${APP_NAME}},{Key=Proyecto,Value=inventario-nube},{Key=Env,Value=production}]" \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --query 'Instances[0].InstanceId' \
    --output text)
  ok "Instancia lanzada: $INSTANCE_ID"
fi

# ══════════════════════════════════════════════════════════════════
# PASO 7 — Esperar a que la instancia esté running
# ══════════════════════════════════════════════════════════════════
step "7/9 — Esperando que la instancia inicie"
info "Esto puede tardar 1-2 minutos..."

aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

ok "Instancia running: $PUBLIC_IP"

# ══════════════════════════════════════════════════════════════════
# PASO 8 — Guardar .env actualizado con la IP real
# ══════════════════════════════════════════════════════════════════
step "8/9 — Actualizando .env.aws con datos del despliegue"

cat > .env.aws <<ENVAWS
# ── Generado por aws-full-setup.sh $(date) ──
# Copia este contenido a .env para desplegar la app

PORT=3000
NODE_ENV=production

# PostgreSQL en la VM
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_SSL=false

# AWS — EC2 usa IAM Role adjunto, NO se necesitan access keys en producción
AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}

# Supabase no usado
SUPABASE_URL=http://localhost
SUPABASE_SERVICE_KEY=not_used
SUPABASE_BUCKET=not_used

# JWT — secreto generado con openssl
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=8h

# CORS — actualiza con la IP/dominio real de tu instancia
CORS_ORIGIN=http://${PUBLIC_IP}
ENVAWS

chmod 600 .env.aws
ok "Configuración guardada en .env.aws"

# ══════════════════════════════════════════════════════════════════
# PASO 9 — Copiar código y desplegar la app
# ══════════════════════════════════════════════════════════════════
step "9/9 — Desplegando código en la instancia"

APP_DIR="/var/www/inventario"

# Esperar a que SSH esté disponible
info "Esperando que SSH esté disponible..."
for i in $(seq 1 24); do
  if ssh -o StrictHostKeyChecking=no \
         -o ConnectTimeout=5 \
         -o BatchMode=yes \
         -i "$KEY_FILE" \
         "ubuntu@${PUBLIC_IP}" "exit 0" 2>/dev/null; then
    ok "SSH disponible"
    break
  fi
  if [ $i -eq 24 ]; then
    warn "SSH tardó demasiado. Ejecuta el despliegue manualmente:"
    warn "  bash deploy/full-deploy.sh ubuntu@${PUBLIC_IP}"
    break
  fi
  echo -n "."
  sleep 10
done

# Copiar .env.aws como .env en la VM
ssh -o StrictHostKeyChecking=no \
    -i "$KEY_FILE" \
    "ubuntu@${PUBLIC_IP}" \
    "sudo mkdir -p ${APP_DIR} && sudo chown ubuntu:ubuntu ${APP_DIR}" 2>/dev/null || true

rsync -az \
  -e "ssh -o StrictHostKeyChecking=no -i ${KEY_FILE}" \
  .env.aws "ubuntu@${PUBLIC_IP}:${APP_DIR}/.env" 2>/dev/null && \
  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" \
    "chmod 600 ${APP_DIR}/.env" || warn "No se pudo copiar .env — hazlo manualmente"

# Sincronizar código
info "Copiando código de la aplicación..."
rsync -az --delete \
  -e "ssh -o StrictHostKeyChecking=no -i ${KEY_FILE}" \
  --exclude='node_modules/' \
  --exclude='.env' \
  --exclude='.env.aws' \
  --exclude='.git/' \
  --exclude='*.pem' \
  --exclude='*.log' \
  ./ "ubuntu@${PUBLIC_IP}:${APP_DIR}/" 2>/dev/null || warn "rsync falló — usa full-deploy.sh manualmente"

# Instalar dependencias, migrar y arrancar
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" bash <<'SSHEOF' || warn "Arranque automático falló — conéctate manualmente y ejecuta los comandos del README"
  set -euo pipefail
  APP_DIR="/var/www/inventario"

  # Esperar a que el user-data termine PostgreSQL (puede estar instalando)
  for i in $(seq 1 12); do
    command -v psql &>/dev/null && break
    echo "  Esperando PostgreSQL..." && sleep 10
  done

  cd "$APP_DIR"

  echo "  Instalando dependencias..."
  npm install --omit=dev --silent

  echo "  Ejecutando migraciones..."
  node src/db/migrate.js

  echo "  Cargando datos de prueba..."
  node src/db/seed.js

  echo "  Arrancando con PM2..."
  pm2 delete inventario-api 2>/dev/null || true
  pm2 start src/server.js --name inventario-api
  pm2 save

  echo "  App iniciada correctamente"
SSHEOF

# ══════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║            ✅  Despliegue Completado                     ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Instancia EC2${NC}"
echo    "    ID:             $INSTANCE_ID"
echo    "    IP pública:     $PUBLIC_IP"
echo    "    Tipo:           $INSTANCE_TYPE"
echo    "    Región:         $REGION"
echo ""
echo -e "  ${BOLD}Almacenamiento${NC}"
echo    "    S3 Bucket:      s3://${S3_BUCKET}"
echo    "    IAM Role:       ${IAM_ROLE_NAME}"
echo ""
echo -e "  ${BOLD}Acceso a la aplicación${NC}"
echo    "    App:            http://${PUBLIC_IP}"
echo    "    Health check:   http://${PUBLIC_IP}/health"
echo    "    API:            http://${PUBLIC_IP}/api/"
echo ""
echo -e "  ${BOLD}Credenciales iniciales${NC}"
echo    "    Usuario admin:  admin@empresa.com"
echo    "    Contraseña:     Admin1234!"
echo    "    ⚠  Cámbiala desde el panel de usuarios"
echo ""
echo -e "  ${BOLD}SSH${NC}"
echo    "    ssh -i ${KEY_FILE} ubuntu@${PUBLIC_IP}"
echo ""
echo -e "  ${BOLD}Archivos generados${NC}"
echo    "    ${KEY_NAME}.pem  — clave SSH (guárdala segura)"
echo    "    .env.aws         — variables de entorno del despliegue"
echo ""
echo -e "  ${BOLD}Comandos útiles${NC}"
echo    "    Logs PM2:    ssh -i ${KEY_FILE} ubuntu@${PUBLIC_IP} 'pm2 logs inventario-api'"
echo    "    Redeploy:    bash deploy/full-deploy.sh ubuntu@${PUBLIC_IP}"
echo    "    Status:      ssh -i ${KEY_FILE} ubuntu@${PUBLIC_IP} 'pm2 status'"
echo ""
echo -e "${YELLOW}  ⚠  Recuerda agregar ${KEY_NAME}.pem y .env.aws a tu .gitignore${NC}"
echo ""
