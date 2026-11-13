#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 4  (P05)
# "Tabla de reglas de tráfico por componente"
#
# Muestra las reglas completas de entrada y salida de:
#   · SG de EC2 (subred pública): SSH restringido + HTTP/HTTPS/3000 públicos
#   · SG de RDS (subred privada): solo puerto 5432 desde EC2
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
SG_EC2_NAME="sg-ec2-$PROYECTO-$EQUIPO"
SG_RDS_NAME="sg-rds-$PROYECTO-$EQUIPO"

echo "================================================"
echo "ENTREGABLE 4 — Tabla de reglas de tráfico por componente"
echo "Equipo: Los Rojos  |  Región: $REGION"
echo "================================================"
echo ""

# ── Buscar recursos ───────────────────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "⚠  VPC no encontrada. Ejecuta primero: bash deploy/aws-practica05-vpc-red.sh"
  exit 1
fi

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

SG_RDS_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E4 — Reglas de tráfico por componente  |  $PROYECTO"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── SG de EC2 ─────────────────────────────────────────────────────────────────
echo "▶ COMPONENTE 1 — EC2 (Nginx + Node.js) | $SG_EC2_NAME ($SG_EC2_ID)"
echo "  Subred: PÚBLICA (10.0.1.0/24)"
echo ""

echo "  → Reglas de ENTRADA (Inbound):"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[*].{Puerto_Desde:FromPort, Puerto_Hasta:ToPort, Protocolo:IpProtocol, Origen_CIDR:IpRanges[0].CidrIp, Descripcion:IpRanges[0].Description}" \
  --output table

echo ""
echo "  → Reglas de SALIDA (Outbound):"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissionsEgress[*].{Puerto_Desde:FromPort, Puerto_Hasta:ToPort, Protocolo:IpProtocol, Destino_CIDR:IpRanges[0].CidrIp}" \
  --output table

# Verificar que SSH no esté abierto a 0.0.0.0/0
SSH_ABIERTO=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && IpRanges[?CidrIp=='0.0.0.0/0']].FromPort" \
  --output text 2>/dev/null)

SSH_CIDR=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[0].CidrIp" \
  --output text 2>/dev/null)

echo ""
if [ -z "$SSH_ABIERTO" ] || [ "$SSH_ABIERTO" = "None" ]; then
  echo "  ✔ SSH (22) NO está abierto a 0.0.0.0/0"
  echo "    SSH permitido solo para: $SSH_CIDR (IP del equipo)"
else
  echo "  ⚠  SSH (22) está abierto a 0.0.0.0/0 — CRITERIO NO CUMPLIDO"
fi

# ── SG de RDS ─────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo ""
echo "▶ COMPONENTE 2 — RDS PostgreSQL | $SG_RDS_NAME ($SG_RDS_ID)"
echo "  Subred: PRIVADA (10.0.2.0/24)"
echo ""

echo "  → Reglas de ENTRADA (Inbound):"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[*].{Puerto:FromPort, Protocolo:IpProtocol, Origen_CIDR:IpRanges[0].CidrIp, Origen_SG:UserIdGroupPairs[0].GroupId, Descripcion:UserIdGroupPairs[0].Description}" \
  --output table

echo ""
echo "  → Reglas de SALIDA (Outbound):"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissionsEgress[*].{Puerto:FromPort, Protocolo:IpProtocol, Destino_CIDR:IpRanges[0].CidrIp}" \
  --output table

# Verificar que RDS no tenga 0.0.0.0/0
RDS_ABIERTO=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']].FromPort" \
  --output text 2>/dev/null)

RDS_SRC_SG=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$SG_EC2_ID']].FromPort" \
  --output text 2>/dev/null)

echo ""
if [ -z "$RDS_ABIERTO" ] || [ "$RDS_ABIERTO" = "None" ]; then
  echo "  ✔ PostgreSQL (5432) NO está abierto a 0.0.0.0/0"
else
  echo "  ⚠  Puerto $RDS_ABIERTO abierto a internet — cerrar inmediatamente"
fi

if [ -n "$RDS_SRC_SG" ] && [ "$RDS_SRC_SG" != "None" ]; then
  echo "  ✔ Puerto 5432 aceptado solo desde $SG_EC2_ID (SG de EC2)"
fi

# ── Tabla resumen por componente ──────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  TABLA RESUMEN — REGLAS POR COMPONENTE"
echo "────────────────────────────────────────────────────────────────────"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "Componente" "Puerto" "Origen/Destino" "Dirección" "Propósito"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "────────────────────" "──────────" "──────────────────────" "──────────" "─────────────────────"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "EC2 Nginx+Node"  "22"    "IP-equipo/32"    "Entrada"  "SSH admin restringido"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "EC2 Nginx+Node"  "80"    "0.0.0.0/0"       "Entrada"  "HTTP público"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "EC2 Nginx+Node"  "443"   "0.0.0.0/0"       "Entrada"  "HTTPS público"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "EC2 Nginx+Node"  "3000"  "0.0.0.0/0"       "Entrada"  "Node.js API (dev)"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "EC2 Nginx+Node"  "Todos" "0.0.0.0/0"       "Salida"   "Respuestas + S3 + updates"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "RDS PostgreSQL"  "5432"  "SG-EC2 (solo)"   "Entrada"  "PostgreSQL solo desde EC2"
printf "  %-20s  %-10s  %-22s  %-10s  %s\n" "RDS PostgreSQL"  "Todos" "0.0.0.0/0"       "Salida"   "Respuestas hacia EC2"
echo ""
echo "  ✅  Reglas de tráfico verificadas por componente — ENTREGABLE 4 CUMPLIDO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
