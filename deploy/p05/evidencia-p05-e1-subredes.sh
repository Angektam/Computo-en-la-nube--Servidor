#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 1  (P05)
# "La red y sus subredes con los rangos visibles"
#
# Muestra:  VPC · subred pública · subred privada · Internet Gateway
#           con CIDRs, AZs, etiquetas y atributos clave
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

echo "================================================"
echo "ENTREGABLE 1 — Direccionamiento privado, coherente y justificado"
echo "Criterio 1 (15 pts) — Red y subredes con rangos visibles"
echo "Equipo: Los Rojos  |  Región: $REGION"
echo "================================================"
echo ""

# ── CRITERIO 1: Justificación del direccionamiento ────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  JUSTIFICACIÓN DEL BLOQUE DE DIRECCIONAMIENTO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Bloque elegido : 10.0.0.0/16  (RFC 1918 — rango privado clase A)"
echo "  Motivo         : Es un bloque privado estándar, no enrutable en"
echo "                   internet público. AWS lo reconoce como VPC válida."
echo ""
echo "  Verificación RFC 1918 (rangos privados permitidos):"
echo "    · 10.0.0.0/8       → 10.0.0.0/16 está dentro ✔"
echo "    · 172.16.0.0/12    → no usado"
echo "    · 192.168.0.0/16   → no usado"
echo ""
echo "  Coherencia del diseño:"
printf "    %-18s  %-18s  %-6s  %s\n" "Subred" "CIDR" "Hosts" "Uso"
printf "    %-18s  %-18s  %-6s  %s\n" "──────────────────" "──────────────────" "──────" "────────────────────────────"
printf "    %-18s  %-18s  %-6s  %s\n" "VPC completa"      "10.0.0.0/16"  "65531" "Espacio total del proyecto"
printf "    %-18s  %-18s  %-6s  %s\n" "Subred pública"    "10.0.1.0/24"  "251"   "EC2: Nginx + Node.js (internet)"
printf "    %-18s  %-18s  %-6s  %s\n" "Subred privada"    "10.0.2.0/24"  "251"   "RDS: PostgreSQL (sin internet)"
printf "    %-18s  %-18s  %-6s  %s\n" "Reserva futura"    "10.0.3-255.x" "~65k"  "Escalamiento futuro"
echo ""
echo "  Nota: AWS reserva 5 IPs por subred (red, router, DNS, reserva y"
echo "  broadcast), por eso cada /24 tiene 251 hosts útiles y no 254."
echo ""
echo "  Las subredes no se traslapan: 10.0.1.x y 10.0.2.x son rangos"
echo "  distintos dentro del /16. Cada componente tiene su espacio propio."
echo ""
echo "  Zonas de disponibilidad distintas (resiliencia):"
echo "    · Subred pública  → us-east-1a"
echo "    · Subred privada  → us-east-1b"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── Buscar recursos ───────────────────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "⚠  VPC '$VPC_NAME' no encontrada."
  echo "   Ejecuta primero: bash deploy/aws-practica05-vpc-red.sh"
  exit 1
fi

SUBNET_PUB_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

IGW_ID=$(aws ec2 describe-internet-gateways \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$IGW_NAME" \
  --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E1 — Red y subredes  |  Proyecto: $PROYECTO"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── VPC ───────────────────────────────────────────────────────────────────────
echo "▶ VPC del proyecto"
echo ""
aws ec2 describe-vpcs \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].{VpcId:VpcId, CIDR:CidrBlock, Estado:State, DNS_Support:EnableDnsSupport, DNS_Hostnames:EnableDnsHostnames}" \
  --output table

echo ""
echo "  Etiquetas de la VPC:"
aws ec2 describe-vpcs \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].Tags" \
  --output table

# ── Subredes ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ Subredes asociadas a la VPC $VPC_ID"
echo ""
aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].{SubnetId:SubnetId, CIDR:CidrBlock, AZ:AvailabilityZone, IPpublica:MapPublicIpOnLaunch, HostsDisponibles:AvailableIpAddressCount, Estado:State}" \
  --output table

# ── Detalle subred pública ─────────────────────────────────────────────────
echo ""
echo "▶ Detalle: SUBRED PÚBLICA ($SUBNET_PUB_NAME)"
aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].Tags" \
  --output table

# ── Detalle subred privada ─────────────────────────────────────────────────
echo ""
echo "▶ Detalle: SUBRED PRIVADA ($SUBNET_PRIV_NAME)"
aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].Tags" \
  --output table

# ── Internet Gateway ──────────────────────────────────────────────────────────
echo ""
echo "▶ Internet Gateway ($IGW_NAME)"
echo ""
aws ec2 describe-internet-gateways \
  --region "$REGION" \
  --internet-gateway-ids "$IGW_ID" \
  --query "InternetGateways[0].{IGW_ID:InternetGatewayId, VPC_Adjunto:Attachments[0].VpcId, Estado:Attachments[0].State}" \
  --output table

# ── Resumen de rangos ─────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  RESUMEN DE RANGOS"
echo "────────────────────────────────────────────────────────────────────"
VPC_CIDR=$(aws ec2 describe-vpcs --region "$REGION" --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].CidrBlock" --output text)
PUB_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].CidrBlock" --output text)
PRIV_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].CidrBlock" --output text)
PUB_AZ=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].AvailabilityZone" --output text)
PRIV_AZ=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].AvailabilityZone" --output text)
printf "  %-16s  %-20s  %-12s  %s\n" "Recurso" "CIDR / Rango" "Zona" "ID"
printf "  %-16s  %-20s  %-12s  %s\n" "────────────────" "────────────────────" "────────────" "─────────────────────"
printf "  %-16s  %-20s  %-12s  %s\n" "VPC"             "$VPC_CIDR"  "us-east-1"  "$VPC_ID"
printf "  %-16s  %-20s  %-12s  %s\n" "Subred pública"  "$PUB_CIDR"  "$PUB_AZ"   "$SUBNET_PUB_ID"
printf "  %-16s  %-20s  %-12s  %s\n" "Subred privada"  "$PRIV_CIDR" "$PRIV_AZ"  "$SUBNET_PRIV_ID"
printf "  %-16s  %-20s  %-12s  %s\n" "Internet GW"     "N/A"        "N/A"        "$IGW_ID"
echo ""
echo "  ✅  VPC con subredes y rangos visibles — ENTREGABLE 1 CUMPLIDO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
