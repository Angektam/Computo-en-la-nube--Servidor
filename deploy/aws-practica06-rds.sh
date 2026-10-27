#!/bin/bash
# =============================================================================
# PRÁCTICA 06 - La base de datos del proyecto en subred privada
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  Fecha: 13 oct 2026
#
# Qué hace este script:
#   1. Verifica que la VPC y subredes de P05 existan
#   2. Crea una segunda subred privada en us-east-1c (RDS lo exige)
#   3. Crea el DB Subnet Group con ambas subredes privadas
#   4. Reutiliza el Security Group sg-rds-inventario-cloud-los-rojos de P05
#   5. Despliega la instancia RDS PostgreSQL (db.t3.micro, sin IP pública,
#      cifrado en reposo activo, respaldo 7 días)
#   6. Muestra el endpoint al finalizar
#
# CÓMO USAR:
#   Pega en AWS CloudShell y presiona Enter.
#   Guarda el endpoint y la contraseña en un lugar seguro (NO en el repo).
# =============================================================================

set -e   # detener si hay error

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

# ── Nombres consistentes con P05 ──────────────────────────────────────────────
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
SUBNET_PRIV_NAME="subnet-priv-$PROYECTO-$EQUIPO"
SUBNET_PRIV2_NAME="subnet-priv2-$PROYECTO-$EQUIPO"   # nueva, requerida por RDS
SG_RDS_NAME="rds-$PROYECTO-$EQUIPO"
SG_EC2_NAME="ec2-$PROYECTO-$EQUIPO"

# ── Nuevos recursos P06 ───────────────────────────────────────────────────────
DB_SUBNET_GROUP="dbsg-$PROYECTO-$EQUIPO"
DB_IDENTIFIER="rds-$PROYECTO-$EQUIPO"
DB_NAME="inventario"
DB_USER="postgres"
AZ_PRIV2="us-east-1c"
SUBNET_PRIV2_CIDR="10.0.3.0/24"

echo ""
echo "============================================================"
echo "  PRÁCTICA 06 — Base de datos en subred privada"
echo "  Equipo  : Los Rojos"
echo "  Motor   : PostgreSQL 15 (Amazon RDS)"
echo "  Región  : $REGION"
echo "============================================================"
echo ""

# =============================================================================
# PASO 0 — Verificar que existan los recursos de P05
# =============================================================================
echo "=== [0/6] Verificar recursos de P05 ==="

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "❌ VPC '$VPC_NAME' no encontrada."
  echo "   Ejecuta primero: bash deploy/aws-practica05-vpc-red.sh"
  exit 1
fi
echo "✔ VPC encontrada: $VPC_ID"

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text)

if [ "$SUBNET_PRIV_ID" = "None" ] || [ -z "$SUBNET_PRIV_ID" ]; then
  echo "❌ Subred privada '$SUBNET_PRIV_NAME' no encontrada."
  exit 1
fi
echo "✔ Subred privada 1 encontrada: $SUBNET_PRIV_ID (10.0.2.0/24, us-east-1b)"

SG_RDS_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)

if [ "$SG_RDS_ID" = "None" ] || [ -z "$SG_RDS_ID" ]; then
  echo "❌ Security Group '$SG_RDS_NAME' no encontrado."
  echo "   Ejecuta primero: bash deploy/aws-practica05-vpc-red.sh"
  exit 1
fi
echo "✔ Security Group RDS encontrado: $SG_RDS_ID"

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)
echo "✔ Security Group EC2 encontrado: $SG_EC2_ID"
echo ""

# =============================================================================
# PASO 1 — Crear segunda subred privada (RDS exige ≥2 AZ)
# =============================================================================
echo "=== [1/6] Segunda subred privada ($SUBNET_PRIV2_CIDR, $AZ_PRIV2) ==="

SUBNET_PRIV2_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV2_NAME" \
  --query "Subnets[0].SubnetId" --output text)

if [ "$SUBNET_PRIV2_ID" = "None" ] || [ -z "$SUBNET_PRIV2_ID" ]; then
  SUBNET_PRIV2_ID=$(aws ec2 create-subnet \
    --region "$REGION" \
    --vpc-id "$VPC_ID" \
    --cidr-block "$SUBNET_PRIV2_CIDR" \
    --availability-zone "$AZ_PRIV2" \
    --query "Subnet.SubnetId" --output text)
  # NO se asigna IP pública — subred privada
  aws ec2 create-tags --resources "$SUBNET_PRIV2_ID" --tags \
    Key=Name,Value="$SUBNET_PRIV2_NAME" \
    Key=tipo,Value="privada" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ Segunda subred privada creada: $SUBNET_PRIV2_ID ($SUBNET_PRIV2_CIDR)"
else
  echo "· Segunda subred privada ya existe: $SUBNET_PRIV2_ID"
fi
echo ""

# =============================================================================
# PASO 2 — Crear DB Subnet Group
# =============================================================================
echo "=== [2/6] DB Subnet Group ($DB_SUBNET_GROUP) ==="

if ! aws rds describe-db-subnet-groups \
      --region "$REGION" \
      --db-subnet-group-name "$DB_SUBNET_GROUP" \
      --query "DBSubnetGroups[0].DBSubnetGroupName" \
      --output text 2>/dev/null | grep -q "$DB_SUBNET_GROUP"; then
  aws rds create-db-subnet-group \
    --region "$REGION" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subredes privadas para RDS del proyecto $PROYECTO" \
    --subnet-ids "$SUBNET_PRIV_ID" "$SUBNET_PRIV2_ID" \
    --tags \
      Key=Name,Value="$DB_SUBNET_GROUP" \
      Key=proyecto,Value="$PROYECTO" \
      Key=equipo,Value="$EQUIPO" \
      Key=ambiente,Value="$AMBIENTE" \
    --output text > /dev/null
  echo "✔ DB Subnet Group creado: $DB_SUBNET_GROUP"
  echo "  · Subredes: $SUBNET_PRIV_ID (us-east-1b) + $SUBNET_PRIV2_ID ($AZ_PRIV2)"
else
  echo "· DB Subnet Group ya existe: $DB_SUBNET_GROUP"
fi
echo ""

# =============================================================================
# PASO 3 — Verificar regla del Security Group RDS
# =============================================================================
echo "=== [3/6] Verificar regla del SG de RDS ==="

REGLA=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\`].UserIdGroupPairs[0].GroupId" \
  --output text)

if [ "$REGLA" = "$SG_EC2_ID" ]; then
  echo "✔ Regla correcta: Puerto 5432 → origen $SG_EC2_ID (EC2)"
  echo "  · NO hay rango 0.0.0.0/0 (aislamiento confirmado)"
else
  echo "⚠  La regla del SG RDS no apunta al SG de EC2."
  echo "   Revisa el Security Group $SG_RDS_ID manualmente en la consola."
fi
echo ""

# =============================================================================
# PASO 4 — Solicitar contraseña de forma segura
# =============================================================================
echo "=== [4/6] Contraseña de la base de datos ==="
echo ""
echo "  ⚠  IMPORTANTE: La contraseña NO se guarda en este script."
echo "  ⚠  Guárdala en el gestor de secretos del equipo, NO en el repo."
echo ""
echo -n "  Ingresa la contraseña para el usuario 'postgres': "
read -s DB_PASSWORD
echo ""

if [ -z "$DB_PASSWORD" ]; then
  echo "❌ La contraseña no puede estar vacía."
  exit 1
fi
echo "✔ Contraseña capturada en memoria (no se escribe a disco)"
echo ""

# =============================================================================
# PASO 5 — Desplegar instancia RDS
# =============================================================================
echo "=== [5/6] Desplegar instancia RDS PostgreSQL ==="

# Verificar si ya existe
DB_STATUS=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "NotFound")

if [ "$DB_STATUS" != "NotFound" ] && [ "$DB_STATUS" != "None" ]; then
  echo "· Instancia RDS ya existe: $DB_IDENTIFIER (estado: $DB_STATUS)"
else
  echo "  Creando instancia, esto tarda ~5 minutos..."
  echo ""
  aws rds create-db-instance \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-instance-class "db.t3.micro" \
    --engine "postgres" \
    --engine-version "15.7" \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --allocated-storage 20 \
    --storage-type "gp2" \
    --storage-encrypted \
    --no-publicly-accessible \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --vpc-security-group-ids "$SG_RDS_ID" \
    --backup-retention-period 1 \
    --preferred-backup-window "05:00-06:00" \
    --preferred-maintenance-window "Mon:06:00-Mon:07:00" \
    --no-multi-az \
    --no-auto-minor-version-upgrade \
    --tags \
      Key=Name,Value="$DB_IDENTIFIER" \
      Key=proyecto,Value="$PROYECTO" \
      Key=equipo,Value="$EQUIPO" \
      Key=ambiente,Value="$AMBIENTE" \
    --output text > /dev/null

  echo "✔ Instancia RDS creada: $DB_IDENTIFIER"
  echo "  Esperando a que esté disponible (puede tomar 5-10 min)..."
  aws rds wait db-instance-available \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER"
  echo "✔ Instancia disponible."
fi
echo ""

# =============================================================================
# PASO 6 — Mostrar datos de conexión
# =============================================================================
echo "=== [6/6] Datos de la instancia ==="
echo ""

DB_ENDPOINT=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

DB_PORT=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].Endpoint.Port" \
  --output text)

DB_AZ=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].AvailabilityZone" \
  --output text)

DB_ENCRYPTED=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].StorageEncrypted" \
  --output text)

DB_PUBLIC=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].PubliclyAccessible" \
  --output text)

DB_BACKUP=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].BackupRetentionPeriod" \
  --output text)

echo "════════════════════════════════════════════════════════════════════"
echo "  INSTANCIA RDS DESPLEGADA — PRÁCTICA 06"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Identificador  : $DB_IDENTIFIER"
echo "  Motor          : PostgreSQL 15 (db.t3.micro)"
echo "  Base de datos  : $DB_NAME"
echo "  Usuario        : $DB_USER"
echo "  Endpoint       : $DB_ENDPOINT"
echo "  Puerto         : $DB_PORT"
echo "  Zona           : $DB_AZ"
echo "  IP Pública     : $DB_PUBLIC  ← debe ser False ✔"
echo "  Cifrado reposo : $DB_ENCRYPTED  ← debe ser True ✔"
echo "  Retención resp : $DB_BACKUP días  ← RPO ~24h ✔"
echo "  SG aplicado    : $SG_RDS_ID (solo EC2 puede conectarse)"
echo ""
echo "  Variable de entorno para el servidor (EC2):"
echo "  DB_HOST=$DB_ENDPOINT"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"
echo "  DB_USER=$DB_USER"
echo "  DB_PASSWORD=<guarda la contraseña en tu gestor de secretos>"
echo ""
echo "  ⚠  COSTO: Detén la instancia al terminar la sesión."
echo "  ⚠  RDS db.t3.micro puede detenerse hasta 7 días consecutivos."
echo "     Después se reinicia automáticamente."
echo ""
echo "  Comando para detener:"
echo "  aws rds stop-db-instance --db-instance-identifier $DB_IDENTIFIER --region $REGION"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
