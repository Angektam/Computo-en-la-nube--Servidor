#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  cloudshell-deploy.sh                                           ║
# ║                                                                  ║
# ║  CÓMO USARLO:                                                    ║
# ║  1. Abre AWS CloudShell (ícono >_ en la barra superior de AWS)  ║
# ║  2. Copia y pega TODO este script en CloudShell                 ║
# ║  3. Presiona Enter                                               ║
# ║                                                                  ║
# ║  ⚠  ANTES DE PEGAR: cambia DB_PASS con tu contraseña real de    ║
# ║     RDS en la sección CONFIGURACIÓN más abajo.                  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colores ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗  ERROR:${NC} $*" >&2; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${NC} $2"; }

# ══════════════════════════════════════════════════════════════════
# CONFIGURACIÓN  ← edita solo esta sección
# ══════════════════════════════════════════════════════════════════

REPO_URL="https://github.com/Angektam/Computo-en-la-nube--Servidor.git"
REPO_BRANCH="main"

REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
APP_NAME="inventario-nube"

# ─── Base de datos RDS existente ──────────────────────────────
DB_HOST="inventario-db.citeqg0wepbd.us-east-1.rds.amazonaws.com"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS="Inventario2026!"        # ← cambia si es diferente

# ─── S3 existente ─────────────────────────────────────────────
S3_BUCKET="inventario-archivos-losrojos"

# ─── JWT (se genera seguro automáticamente) ───────────────────
JWT_SECRET="$(openssl rand -hex 40)"
JWT_EXPIRES="8h"

# ── Nombre del RDS para buscar su Security Group ──────────────
RDS_IDENTIFIER="inventario-db"

# ══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Inventario Nube — Deploy desde AWS CloudShell        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "Cuenta AWS:  $ACCOUNT_ID"
info "Región:      $REGION"
info "Repo:        $REPO_URL"
info "RDS:         $DB_HOST"
info "S3:          $S3_BUCKET"
echo ""

# ══════════════════════════════════════════════════════════════════
step "1/7" "Key Pair SSH"
# ══════════════════════════════════════════════════════════════════
KEY_NAME="${APP_NAME}-key"
KEY_FILE="${HOME}/${KEY_NAME}.pem"

EXISTING_KEY=$(aws ec2 describe-key-pairs \
  --region "$REGION" \
  --filters "Name=key-name,Values=${KEY_NAME}" \
  --query "KeyPairs[0].KeyName" \
  --output text 2>/dev/null || true)

if [ "$EXISTING_KEY" = "$KEY_NAME" ]; then
  warn "Key pair '${KEY_NAME}' ya existe en AWS."
  [ -f "$KEY_FILE" ] && ok "Archivo local encontrado: $KEY_FILE" \
                     || warn "El .pem no está local. Si lo perdiste: elimina el key pair en EC2 → Key Pairs y vuelve a correr."
else
  aws ec2 create-key-pair \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  ok "Key pair creado → $KEY_FILE"
  warn "¡Descárgalo ahora! CloudShell → Actions (arriba derecha) → Download file → ${KEY_FILE}"
fi

# ══════════════════════════════════════════════════════════════════
step "2/7" "Security Group (puertos 22, 80, 3000)"
# ══════════════════════════════════════════════════════════════════
SG_NAME="${APP_NAME}-sg"

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || true)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "SG para ${APP_NAME}" \
    --query 'GroupId' \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description=SSH}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP}]" \
      "IpProtocol=tcp,FromPort=3000,ToPort=3000,IpRanges=[{CidrIp=0.0.0.0/0,Description=NodeApp}]" \
    --output text >/dev/null

  ok "Security group creado: $SG_ID"
else
  ok "Security group existente: $SG_ID"
fi

# ══════════════════════════════════════════════════════════════════
step "3/7" "IAM Role con mínimo privilegio (solo bucket propio)"
# ══════════════════════════════════════════════════════════════════
IAM_ROLE="${APP_NAME}-ec2-role"
IAM_PROFILE="${APP_NAME}-profile"

ROLE_EXISTS=$(aws iam get-role \
  --role-name "$IAM_ROLE" \
  --query "Role.RoleName" \
  --output text 2>/dev/null || true)

if [ -z "$ROLE_EXISTS" ]; then
  # Crear rol
  aws iam create-role \
    --role-name "$IAM_ROLE" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }]
    }' \
    --output text >/dev/null

  # Política: solo leer/escribir en el bucket de la app
  aws iam put-role-policy \
    --role-name "$IAM_ROLE" \
    --policy-name "${APP_NAME}-s3" \
    --policy-document "{
      \"Version\":\"2012-10-17\",
      \"Statement\":[{
        \"Effect\":\"Allow\",
        \"Action\":[
          \"s3:GetObject\",
          \"s3:PutObject\",
          \"s3:DeleteObject\",
          \"s3:ListBucket\"
        ],
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
  --query "InstanceProfile.InstanceProfileName" \
  --output text 2>/dev/null || true)

if [ -z "$PROFILE_EXISTS" ]; then
  aws iam create-instance-profile \
    --instance-profile-name "$IAM_PROFILE" \
    --output text >/dev/null
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$IAM_PROFILE" \
    --role-name "$IAM_ROLE" \
    --output text >/dev/null
  ok "Instance profile creado: $IAM_PROFILE"
  info "Esperando propagación IAM (10s)..."
  sleep 10
else
  ok "Instance profile existente: $IAM_PROFILE"
fi

# ══════════════════════════════════════════════════════════════════
step "4/7" "AMI Ubuntu 22.04 LTS más reciente"
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

ok "AMI: $AMI_ID  (Ubuntu 22.04 LTS)"

# ══════════════════════════════════════════════════════════════════
step "5/7" "Preparando User Data"
# ══════════════════════════════════════════════════════════════════
#
# Este bloque corre automáticamente dentro de la VM al arrancar:
#   - Instala Node 20, Nginx, PM2
#   - Clona el repo desde GitHub
#   - Escribe el .env con los valores reales
#   - npm install, migrate, seed
#   - Arranca la app con PM2 detrás de Nginx
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

# 1. Actualizar sistema
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 2. Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git

# 3. Nginx + PM2
apt-get install -y nginx
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | bash || true

# 4. Clonar repositorio
mkdir -p /var/www/inventario
chown ubuntu:ubuntu /var/www/inventario
sudo -u ubuntu git clone --branch ${REPO_BRANCH} ${REPO_URL} /var/www/inventario

# 5. Escribir .env
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

# 6. Dependencias
cd /var/www/inventario
sudo -u ubuntu npm install --omit=dev --silent

# 7. Migración y seed
sudo -u ubuntu node src/db/migrate.js
sudo -u ubuntu node src/db/seed.js

# 8. Nginx — proxy inverso
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

# 9. Firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

# 10. Arrancar app con PM2
cd /var/www/inventario
sudo -u ubuntu pm2 delete inventario-api 2>/dev/null || true
sudo -u ubuntu pm2 start src/server.js --name inventario-api
sudo -u ubuntu pm2 save

echo ""
echo "======================================"
echo "  Setup completo: \$(date)"
echo "  App en: http://\${VM_IP}"
echo "  Log:    /var/log/inventario-setup.log"
echo "======================================"
USERDATA
)

ok "User Data listo"

# ══════════════════════════════════════════════════════════════════
step "6/7" "Lanzando instancia EC2 ($INSTANCE_TYPE)"
# ══════════════════════════════════════════════════════════════════

# Verificar si ya existe una instancia con este nombre
EXISTING_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ "$EXISTING_ID" != "None" ] && [ -n "$EXISTING_ID" ]; then
  warn "Ya existe instancia '${APP_NAME}': $EXISTING_ID — se omite la creación."
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
step "7/7" "Esperando IP pública y conectando RDS"
# ══════════════════════════════════════════════════════════════════
info "Esperando que la instancia arranque (~60s)..."
aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

PRIVATE_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

ok "Instancia corriendo"
ok "IP pública:  $PUBLIC_IP"
ok "IP privada:  $PRIVATE_IP"

# Abrir puerto 5432 en el SG de RDS para que la EC2 acceda a la base
RDS_SG=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$RDS_IDENTIFIER" \
  --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" \
  --output text 2>/dev/null || true)

if [ -n "$RDS_SG" ] && [ "$RDS_SG" != "None" ]; then
  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$RDS_SG" \
    --protocol tcp \
    --port 5432 \
    --cidr "${PRIVATE_IP}/32" \
    --output text >/dev/null 2>&1 \
    && ok "Puerto 5432 abierto en SG de RDS para la EC2 ($PRIVATE_IP)" \
    || warn "Puerto 5432 ya estaba abierto o no se pudo — verifica en RDS → Security Group"
else
  warn "No se encontró el SG del RDS '${RDS_IDENTIFIER}' — abre el puerto 5432 manualmente"
fi

# ══════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║              ✅  Despliegue completado                   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Instancia:       $INSTANCE_ID"
echo "  IP pública:      $PUBLIC_IP"
echo "  Tipo:            $INSTANCE_TYPE  (Free Tier)"
echo "  RDS:             $DB_HOST"
echo "  S3 bucket:       $S3_BUCKET"
echo ""
echo -e "  ${BOLD}⏳  La app tarda ~3-5 min en estar lista${NC}"
echo "  (Node, Nginx, clonación del repo y migrate corren en segundo plano)"
echo ""
echo "  🌐  App:           http://${PUBLIC_IP}"
echo "  🩺  Health check:  http://${PUBLIC_IP}/health"
echo "  🔌  API:           http://${PUBLIC_IP}/api/"
echo ""
echo "  👤  admin@empresa.com  /  Admin1234!"
echo "  👤  bodega@empresa.com /  Admin1234!"
echo "  👤  cajero@empresa.com /  Admin1234!"
echo ""
echo -e "  ${BOLD}SSH:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo ""
echo -e "  ${BOLD}Descargar clave SSH desde CloudShell:${NC}"
echo "  Actions (botón arriba derecha) → Download file → /root/${KEY_NAME}.pem"
echo ""
echo -e "  ${BOLD}Ver log del setup en la VM:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'sudo tail -50 /var/log/inventario-setup.log'"
echo ""
echo -e "  ${BOLD}Ver logs de la app:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'pm2 logs inventario-api --lines 30'"
echo ""
echo -e "  ${BOLD}Redeploy futuro:${NC}"
echo "  ssh -i ~/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} \\"
echo "    'cd /var/www/inventario && git pull && npm install --omit=dev && pm2 restart inventario-api'"
echo ""
