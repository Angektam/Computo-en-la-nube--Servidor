#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  cloudshell-deploy.sh                                           ║
# ║                                                                  ║
# ║  Script para AWS CloudShell — crea toda la infraestructura      ║
# ║  y despliega la app desde GitHub en una instancia EC2.          ║
# ║                                                                  ║
# ║  CÓMO USARLO:                                                    ║
# ║  1. Abre AWS CloudShell (ícono >_ en la barra superior de AWS)  ║
# ║  2. Copia y pega TODO este script                               ║
# ║  3. Presiona Enter                                               ║
# ║                                                                  ║
# ║  No necesitas instalar nada — CloudShell ya tiene AWS CLI.      ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colores ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗${NC}  $*" >&2; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${NC} $2"; }

# ══════════════════════════════════════════════════════════════════
# ▼▼▼  CONFIGURACIÓN — edita esta sección antes de ejecutar  ▼▼▼
# ══════════════════════════════════════════════════════════════════

# ─── Repositorio ──────────────────────────────────────────────
# Si el repo es privado, usa un token: https://tu-token@github.com/...
# Si es público, deja la URL normal.
REPO_URL="https://github.com/TU_USUARIO/TU_REPO.git"   # ← CAMBIA ESTO
REPO_BRANCH="main"

# ─── Infraestructura ──────────────────────────────────────────
REGION="us-east-1"          # región donde ya tienes RDS y S3
INSTANCE_TYPE="t2.micro"    # Free Tier
APP_NAME="inventario-nube"

# ─── Base de datos (tu RDS existente) ─────────────────────────
DB_HOST="inventario-db.citeqg0wepbd.us-east-1.rds.amazonaws.com"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS="PON_TU_PASSWORD_RDS_AQUI"   # ← CAMBIA ESTO (no dejes el real aquí)

# ─── S3 (tu bucket existente) ─────────────────────────────────
S3_BUCKET="inventario-archivos-losrojos"

# ─── JWT — genera uno nuevo seguro ────────────────────────────
JWT_SECRET="$(openssl rand -hex 40)"
JWT_EXPIRES="8h"

# ══════════════════════════════════════════════════════════════════
# ▲▲▲  FIN DE CONFIGURACIÓN  ▲▲▲
# ══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Inventario Nube — Deploy desde CloudShell          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Validar que cambió el repo ─────────────────────────────────
if [[ "$REPO_URL" == *"TU_USUARIO"* ]]; then
  err "Debes cambiar REPO_URL con la URL real de tu repositorio GitHub."
fi
if [[ "$DB_PASS" == "PON_TU_PASSWORD_RDS_AQUI" ]]; then
  err "Debes cambiar DB_PASS con la contraseña real de tu RDS."
fi

# ── Detectar cuenta y región ───────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "Cuenta AWS:  $ACCOUNT_ID"
info "Región:      $REGION"
info "Instancia:   $INSTANCE_TYPE"
info "RDS host:    $DB_HOST"
info "S3 bucket:   $S3_BUCKET"
echo ""

# ══════════════════════════════════════════════════════════════════
step "1/7" "Key Pair SSH"
# ══════════════════════════════════════════════════════════════════
KEY_NAME="${APP_NAME}-key"
KEY_FILE="${HOME}/${KEY_NAME}.pem"

EXISTING=$(aws ec2 describe-key-pairs \
  --region "$REGION" \
  --filters "Name=key-name,Values=${KEY_NAME}" \
  --query "KeyPairs[0].KeyName" --output text 2>/dev/null || true)

if [ "$EXISTING" = "$KEY_NAME" ]; then
  warn "Key pair '${KEY_NAME}' ya existe. Si perdiste el .pem, elimínalo en EC2 → Key Pairs y vuelve a correr."
  ok "Usando key pair existente"
else
  aws ec2 create-key-pair \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  ok "Key pair creado → $KEY_FILE"
  warn "¡Descarga este archivo! En CloudShell: Actions → Download file → ${KEY_FILE}"
fi

# ══════════════════════════════════════════════════════════════════
step "2/7" "Security Group"
# ══════════════════════════════════════════════════════════════════
SG_NAME="${APP_NAME}-sg"

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "SG para ${APP_NAME}" \
    --query 'GroupId' --output text)

  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description=SSH}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP}]" \
      "IpProtocol=tcp,FromPort=3000,ToPort=3000,IpRanges=[{CidrIp=0.0.0.0/0,Description=NodeApp}]" \
    --output text >/dev/null

  ok "Security group creado: $SG_ID  (puertos 22, 80, 3000)"
else
  ok "Security group existente: $SG_ID"
fi

# ══════════════════════════════════════════════════════════════════
step "3/7" "IAM Role (mínimo privilegio — solo S3 del bucket de la app)"
# ══════════════════════════════════════════════════════════════════
IAM_ROLE="${APP_NAME}-ec2-role"
IAM_PROFILE="${APP_NAME}-profile"

ROLE_EXISTS=$(aws iam get-role --role-name "$IAM_ROLE" \
  --query "Role.RoleName" --output text 2>/dev/null || true)

if [ -z "$ROLE_EXISTS" ]; then
  aws iam create-role \
    --role-name "$IAM_ROLE" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]
    }' \
    --description "EC2 role para ${APP_NAME}" \
    --output text >/dev/null

  # Solo puede leer/escribir en el bucket propio
  aws iam put-role-policy \
    --role-name "$IAM_ROLE" \
    --policy-name "${APP_NAME}-s3-policy" \
    --policy-document "{
      \"Version\":\"2012-10-17\",
      \"Statement\":[{
        \"Effect\":\"Allow\",
        \"Action\":[\"s3:GetObject\",\"s3:PutObject\",\"s3:DeleteObject\",\"s3:ListBucket\"],
        \"Resource\":[
          \"arn:aws:s3:::${S3_BUCKET}\",
          \"arn:aws:s3:::${S3_BUCKET}/*\"
        ]
      }]
    }" \
    --output text >/dev/null

  ok "IAM Role creado: $IAM_ROLE"
else
  ok "IAM Role existente: $IAM_ROLE"
fi

PROFILE_EXISTS=$(aws iam get-instance-profile \
  --instance-profile-name "$IAM_PROFILE" \
  --query "InstanceProfile.InstanceProfileName" --output text 2>/dev/null || true)

if [ -z "$PROFILE_EXISTS" ]; then
  aws iam create-instance-profile \
    --instance-profile-name "$IAM_PROFILE" --output text >/dev/null
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$IAM_PROFILE" \
    --role-name "$IAM_ROLE" --output text >/dev/null
  ok "Instance profile creado: $IAM_PROFILE"
  sleep 8   # IAM tarda ~5s en propagarse
else
  ok "Instance profile existente: $IAM_PROFILE"
fi

# ══════════════════════════════════════════════════════════════════
step "4/7" "Buscando AMI Ubuntu 22.04 LTS más reciente"
# ══════════════════════════════════════════════════════════════════
AMI_ID=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
    "Name=architecture,Values=x86_64" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text)

ok "AMI: $AMI_ID (Ubuntu 22.04 LTS)"

# ══════════════════════════════════════════════════════════════════
step "5/7" "Preparando User Data (todo lo que corre al arrancar la VM)"
# ══════════════════════════════════════════════════════════════════
#
# El User Data:
#   1. Instala Node 20, Nginx, PM2, PostgreSQL-client
#   2. Clona el repo desde GitHub
#   3. Escribe el .env con los valores reales
#   4. Corre npm install, migrate, seed
#   5. Arranca con PM2 detrás de Nginx
#
USER_DATA=$(cat <<USERDATA
#!/bin/bash
set -euo pipefail
LOG=/var/log/inventario-setup.log
exec > >(tee -a \$LOG) 2>&1

echo "======================================"
echo "  Inventario Nube — Setup automatico"
echo "  \$(date)"
echo "======================================"

export DEBIAN_FRONTEND=noninteractive

# ── 1. Sistema base ───────────────────────────────────────────
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef"

# ── 2. Node.js 20 LTS ────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git

# ── 3. Nginx + PM2 ───────────────────────────────────────────
apt-get install -y nginx
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | bash || true

# ── 4. Clonar repositorio ─────────────────────────────────────
mkdir -p /var/www/inventario
chown ubuntu:ubuntu /var/www/inventario

sudo -u ubuntu git clone --branch ${REPO_BRANCH} ${REPO_URL} /var/www/inventario || {
  echo "ERROR: No se pudo clonar el repo."
  echo "Verifica que REPO_URL sea correcto y el repo sea publico (o usa token)."
  exit 1
}

# ── 5. Escribir .env ──────────────────────────────────────────
cat > /var/www/inventario/.env <<'ENVEOF'
PORT=3000
NODE_ENV=production

DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_SSL=true
DB_SSL_REJECT_UNAUTHORIZED=false

AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}

SUPABASE_URL=http://localhost
SUPABASE_SERVICE_KEY=not_used
SUPABASE_BUCKET=not_used

JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=${JWT_EXPIRES}

CORS_ORIGIN=
ENVEOF
chmod 600 /var/www/inventario/.env
chown ubuntu:ubuntu /var/www/inventario/.env

# ── 6. Dependencias ───────────────────────────────────────────
cd /var/www/inventario
sudo -u ubuntu npm install --omit=dev --silent

# ── 7. Migracion y seed ───────────────────────────────────────
sudo -u ubuntu node src/db/migrate.js
sudo -u ubuntu node src/db/seed.js

# ── 8. Nginx ──────────────────────────────────────────────────
VM_IP=\$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print \$1}')

cat > /etc/nginx/sites-available/inventario <<EOF
server {
    listen 80;
    server_name \${VM_IP} _;

    add_header X-Frame-Options        DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy        "no-referrer-when-downgrade";

    access_log /var/log/nginx/inventario.access.log;
    error_log  /var/log/nginx/inventario.error.log warn;

    client_max_body_size 10M;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \\\$http_upgrade;
        proxy_set_header   Connection upgrade;
        proxy_set_header   Host \\\$host;
        proxy_set_header   X-Real-IP \\\$remote_addr;
        proxy_set_header   X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \\\$scheme;
        proxy_read_timeout 60s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/inventario /etc/nginx/sites-enabled/inventario
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable nginx && systemctl reload nginx

# ── 9. Firewall ───────────────────────────────────────────────
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

# ── 10. Arrancar app ──────────────────────────────────────────
cd /var/www/inventario
sudo -u ubuntu pm2 start src/server.js --name inventario-api
sudo -u ubuntu pm2 save

echo ""
echo "======================================"
echo "  Setup completo: \$(date)"
echo "  App corriendo en http://\${VM_IP}"
echo "  Log completo: /var/log/inventario-setup.log"
echo "======================================"
USERDATA
)

ok "User Data preparado ($(echo "$USER_DATA" | wc -l) líneas)"

# ══════════════════════════════════════════════════════════════════
step "6/7" "Lanzando instancia EC2"
# ══════════════════════════════════════════════════════════════════

# Verificar si ya existe
EXISTING_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ "$EXISTING_ID" != "None" ] && [ -n "$EXISTING_ID" ]; then
  warn "Ya existe instancia '${APP_NAME}': $EXISTING_ID"
  INSTANCE_ID="$EXISTING_ID"
else
  INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile "Name=${IAM_PROFILE}" \
    --user-data "$USER_DATA" \
    --block-device-mappings '[{
      "DeviceName":"/dev/sda1",
      "Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}
    }]' \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --tag-specifications \
      "ResourceType=instance,Tags=[
        {Key=Name,Value=${APP_NAME}},
        {Key=Proyecto,Value=inventario-nube},
        {Key=Env,Value=production}
      ]" \
    --query 'Instances[0].InstanceId' \
    --output text)

  ok "Instancia lanzada: $INSTANCE_ID"
fi

# ══════════════════════════════════════════════════════════════════
step "7/7" "Esperando IP pública"
# ══════════════════════════════════════════════════════════════════
info "Esperando que la instancia arranque (~60 segundos)..."
aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

ok "Instancia corriendo: $PUBLIC_IP"

# ── Abrir puerto 5432 en el Security Group de RDS ─────────────
# (permite que la nueva EC2 se conecte a RDS)
info "Abriendo puerto 5432 en el Security Group de RDS para la nueva EC2..."
PRIVATE_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

RDS_SG=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "inventario-db" \
  --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" \
  --output text 2>/dev/null || true)

if [ -n "$RDS_SG" ] && [ "$RDS_SG" != "None" ]; then
  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$RDS_SG" \
    --protocol tcp \
    --port 5432 \
    --cidr "${PRIVATE_IP}/32" \
    --output text >/dev/null 2>&1 || \
    warn "Puerto 5432 ya estaba abierto o no se pudo abrir — verifica manualmente en RDS Security Group"
  ok "Puerto 5432 abierto para la EC2 ($PRIVATE_IP)"
else
  warn "No se encontró el SG de RDS 'inventario-db' — abre el puerto 5432 manualmente"
fi

# ══════════════════════════════════════════════════════════════════
# RESUMEN
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║            ✅  Infraestructura lista                     ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Instancia:       $INSTANCE_ID"
echo "  IP pública:      $PUBLIC_IP"
echo "  RDS:             $DB_HOST"
echo "  S3 bucket:       $S3_BUCKET"
echo ""
echo -e "  ${BOLD}La app tardará ~3-5 minutos en estar lista${NC}"
echo "  (el User Data instala Node, clona el repo y arranca la app)"
echo ""
echo "  App →            http://${PUBLIC_IP}"
echo "  Health check →   http://${PUBLIC_IP}/health"
echo ""
echo "  Usuario admin:   admin@empresa.com"
echo "  Contraseña:      Admin1234!"
echo ""
echo -e "  ${BOLD}SSH (cuando esté lista):${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo ""
echo -e "  ${BOLD}Para descargar la clave SSH desde CloudShell:${NC}"
echo "  Actions (botón arriba a la derecha) → Download file"
echo "  Archivo: /root/${KEY_NAME}.pem"
echo ""
echo -e "  ${BOLD}Ver logs del setup en la VM:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'sudo tail -f /var/log/inventario-setup.log'"
echo ""
echo -e "  ${BOLD}Ver logs de la app:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'pm2 logs inventario-api'"
echo ""
