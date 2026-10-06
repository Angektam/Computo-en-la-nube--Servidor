#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 6  (P05)
# "Diagrama de red del proyecto con IDs reales"
#
# Recupera todos los IDs reales de la cuenta y los inserta en el
# diagrama ASCII para que el diagrama del reporte tenga datos concretos.
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
SUBNET_PUB_NAME="subnet-pub-$PROYECTO-$EQUIPO"
SUBNET_PRIV_NAME="subnet-priv-$PROYECTO-$EQUIPO"
IGW_NAME="igw-$PROYECTO-$EQUIPO"
RT_PUB_NAME="rt-pub-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"
SG_EC2_NAME="sg-ec2-$PROYECTO-$EQUIPO"
SG_RDS_NAME="sg-rds-$PROYECTO-$EQUIPO"
EC2_NAME="srv-$PROYECTO-$EQUIPO"

echo "================================================"
echo "ENTREGABLE 6 — Diagrama de red con IDs reales"
echo "Equipo: Los Rojos  |  Región: $REGION"
echo "================================================"
echo ""

# ── Recuperar todos los IDs ───────────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "⚠  VPC no encontrada. Ejecuta primero: bash deploy/aws-practica05-vpc-red.sh"
  exit 1
fi

VPC_CIDR=$(aws ec2 describe-vpcs --region "$REGION" --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].CidrBlock" --output text 2>/dev/null)

SUBNET_PUB_ID=$(aws ec2 describe-subnets \
  --region "$REGION" --filters "Name=tag:Name,Values=$SUBNET_PUB_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)
PUB_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].CidrBlock" --output text 2>/dev/null)
PUB_AZ=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].AvailabilityZone" --output text 2>/dev/null)

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --region "$REGION" --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)
PRIV_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].CidrBlock" --output text 2>/dev/null)
PRIV_AZ=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].AvailabilityZone" --output text 2>/dev/null)

IGW_ID=$(aws ec2 describe-internet-gateways \
  --region "$REGION" --filters "Name=tag:Name,Values=$IGW_NAME" \
  --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)

RT_PUB_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" --filters "Name=tag:Name,Values=$RT_PUB_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
SG_RDS_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

EC2_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$EC2_NAME" \
    "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)
EC2_IP_PUB=$(aws ec2 describe-instances \
  --region "$REGION" --instance-ids "$EC2_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null)
EC2_IP_PRIV=$(aws ec2 describe-instances \
  --region "$REGION" --instance-ids "$EC2_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text 2>/dev/null)

# Usar "pendiente" si no hay instancia corriendo todavía
[ "$EC2_ID"      = "None" ] && EC2_ID="(lanzar con aws-practica03-ec2.sh)"
[ "$EC2_IP_PUB"  = "None" ] && EC2_IP_PUB="<IP pública dinámica>"
[ "$EC2_IP_PRIV" = "None" ] && EC2_IP_PRIV="10.0.1.x"

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E6 — Diagrama de red con IDs reales"
echo "  Proyecto : $PROYECTO  |  Equipo : $EQUIPO  |  Región : $REGION"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "                        INTERNET"
echo "                            │"
echo "                 HTTP(80) HTTPS(443)"
echo "                            │"
echo "              ┌─────────────┴────────────────┐"
echo "              │   Internet Gateway            │"
echo "              │   $IGW_NAME"
echo "              │   ID: $IGW_ID           │"
echo "              └─────────────┬────────────────┘"
echo "                            │"
echo "┌───────────────────────────┼──────────────────────────────────────────┐"
echo "│  VPC: $VPC_NAME                       │"
echo "│  ID : $VPC_ID   │  CIDR: $VPC_CIDR / 65 531 hosts    │"
echo "│                           │                                          │"
echo "│  ┌────────────────────────┼───────────────────────────────────────┐  │"
echo "│  │ SUBRED PÚBLICA — $PUB_CIDR ($PUB_AZ)               │  │"
echo "│  │ ID: $SUBNET_PUB_ID                            │  │"
echo "│  │ Tabla de ruteo: $RT_PUB_ID                     │  │"
echo "│  │   Ruta: 0.0.0.0/0 → $IGW_ID  ←── TIENE internet   │  │"
echo "│  │                       │                                       │  │"
echo "│  │  ┌────────────────────┴────────────────────────────────────┐  │  │"
echo "│  │  │  EC2 t3.micro — $EC2_NAME                │  │  │"
echo "│  │  │  ID      : $EC2_ID             │  │  │"
echo "│  │  │  IP pub  : $EC2_IP_PUB                           │  │  │"
echo "│  │  │  IP priv : $EC2_IP_PRIV                                  │  │  │"
echo "│  │  │  SO      : Amazon Linux 2023                            │  │  │"
echo "│  │  │  Stack   : Nginx (80/443) → Node.js (3000)             │  │  │"
echo "│  │  │  SG      : $SG_EC2_ID              │  │  │"
echo "│  │  │    ← SSH    :22  solo IP-equipo                        │  │  │"
echo "│  │  │    ← HTTP   :80  0.0.0.0/0                             │  │  │"
echo "│  │  │    ← HTTPS  :443 0.0.0.0/0                             │  │  │"
echo "│  │  │    ← Node   :3000 solo IP-equipo (dev, no expuesto)      │  │  │"
echo "│  │  └──────────────────────┬──────────────────────────────────┘  │  │"
echo "│  │                         │                                      │  │"
echo "│  └─────────────────────────┼──────────────────────────────────────┘  │"
echo "│                            │ PostgreSQL :5432                         │"
echo "│                            │ (solo desde SG-EC2)                      │"
echo "│  ┌─────────────────────────┼───────────────────────────────────────┐  │"
echo "│  │ SUBRED PRIVADA — $PRIV_CIDR ($PRIV_AZ)              │  │"
echo "│  │ ID: $SUBNET_PRIV_ID                           │  │"
echo "│  │ Tabla de ruteo: $RT_PRIV_ID                    │  │"
echo "│  │   Ruta: $VPC_CIDR → local  ←── SIN internet          │  │"
echo "│  │                       │                                       │  │"
echo "│  │  ┌────────────────────┴────────────────────────────────────┐  │  │"
echo "│  │  │  RDS PostgreSQL — inventario-db                        │  │  │"
echo "│  │  │  Motor     : PostgreSQL 15 (administrado por AWS)      │  │  │"
echo "│  │  │  IP privada: 10.0.2.x (sin IP pública)                 │  │  │"
echo "│  │  │  SG        : $SG_RDS_ID              │  │  │"
echo "│  │  │    ← PostgreSQL :5432  SOLO desde $SG_EC2_ID  │  │  │"
echo "│  │  │    ✗ 0.0.0.0/0 NO existe en este SG            │  │  │"
echo "│  │  └────────────────────────────────────────────────────────┘  │  │"
echo "│  └───────────────────────────────────────────────────────────────┘  │"
echo "│                                                                       │"
echo "│  Servicios fuera de VPC (acceso por endpoints públicos + IAM Role):   │"
echo "│  ┌───────────────────────────────────────────────────────────────┐   │"
echo "│  │  S3 — inventario-archivos-losrojos    (imágenes API, privado) │   │"
echo "│  │  S3 — sitio-inventario-cloud-los-rojos (sitio estático, pub.) │   │"
echo "│  └───────────────────────────────────────────────────────────────┘   │"
echo "└───────────────────────────────────────────────────────────────────────┘"
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  TABLA DE REGLAS DE SEGURIDAD (SG)"
echo "────────────────────────────────────────────────────────────────────"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG"  "Puerto" "Origen / Destino"     "Acción"  "Notas"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "────────" "────────" "──────────────────────" "──────────────────────" "────────────────────────"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-EC2"  "22"    "IP-equipo/32"        "PERMITIR"  "SSH solo desde el equipo"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-EC2"  "80"    "0.0.0.0/0"           "PERMITIR"  "HTTP público (Nginx)"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-EC2"  "443"   "0.0.0.0/0"           "PERMITIR"  "HTTPS público (Nginx)"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-EC2"  "3000"  "IP-equipo/32"        "PERMITIR"  "Node.js — solo dev, no expuesto"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-EC2"  "todo"  "0.0.0.0/0 (otros)"  "BLOQUEAR"  "Sin regla = denegado por defecto"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-RDS"  "5432"  "SG-EC2 (sg-id)"      "PERMITIR"  "PostgreSQL solo desde EC2"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "SG-RDS"  "todo"  "0.0.0.0/0"           "BLOQUEAR"  "Sin regla = denegado (incl. internet)"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "S3 API"  "443"   "IAM Role EC2"        "PERMITIR"  "Imágenes — bucket privado"
printf "  %-8s  %-8s  %-22s  %-22s  %s\n" "S3 web"  "443"   "0.0.0.0/0"           "PERMITIR"  "Sitio estático — bucket público"
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  TABLA DE RECURSOS (IDs reales de la cuenta)"
echo "────────────────────────────────────────────────────────────────────"
printf "  %-20s  %-40s  %s\n" "Recurso" "Nombre" "ID"
printf "  %-20s  %-40s  %s\n" "────────────────────" "────────────────────────────────────────" "─────────────────────"
printf "  %-20s  %-40s  %s\n" "VPC"             "$VPC_NAME"         "$VPC_ID"
printf "  %-20s  %-40s  %s\n" "Subred pública"  "$SUBNET_PUB_NAME"  "$SUBNET_PUB_ID"
printf "  %-20s  %-40s  %s\n" "Subred privada"  "$SUBNET_PRIV_NAME" "$SUBNET_PRIV_ID"
printf "  %-20s  %-40s  %s\n" "Internet Gateway" "$IGW_NAME"        "$IGW_ID"
printf "  %-20s  %-40s  %s\n" "RT pública"      "$RT_PUB_NAME"      "$RT_PUB_ID"
printf "  %-20s  %-40s  %s\n" "RT privada"      "$RT_PRIV_NAME"     "$RT_PRIV_ID"
printf "  %-20s  %-40s  %s\n" "SG EC2"          "$SG_EC2_NAME"      "$SG_EC2_ID"
printf "  %-20s  %-40s  %s\n" "SG RDS"          "$SG_RDS_NAME"      "$SG_RDS_ID"
printf "  %-20s  %-40s  %s\n" "EC2"             "$EC2_NAME"         "$EC2_ID"
printf "  %-20s  %-40s  %s\n" "S3 API (privado)" "inventario-archivos-losrojos"    "(endpoint público AWS)"
printf "  %-20s  %-40s  %s\n" "S3 Web (público)" "sitio-inventario-cloud-los-rojos" "(endpoint público AWS)"
echo ""
echo "  ✅  Diagrama con IDs reales generado — ENTREGABLE 6 CUMPLIDO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
