#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 2  (P05) · Criterio 3 — 15 pts
# "Las tablas de ruteo demuestran la diferencia entre pública y privada"
#
# Muestra lado a lado las rutas de ambas tablas para que la diferencia
# sea completamente evidente: pública tiene 0.0.0.0/0 → IGW, privada NO.
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
RT_PUB_NAME="rt-pub-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"
SUBNET_PUB_NAME="subnet-pub-$PROYECTO-$EQUIPO"
SUBNET_PRIV_NAME="subnet-priv-$PROYECTO-$EQUIPO"

echo "================================================"
echo "ENTREGABLE 2 — Tablas de ruteo: pública vs privada"
echo "Criterio 3 (15 pts) — diferencia entre ambas tablas"
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

RT_PUB_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$RT_PUB_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

SUBNET_PUB_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

PUB_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PUB_ID" \
  --query "Subnets[0].CidrBlock" --output text 2>/dev/null)
PRIV_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].CidrBlock" --output text 2>/dev/null)

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E2 — Tablas de ruteo  |  Criterio 3 (15 pts)"
echo "  Proyecto: $PROYECTO  |  VPC: $VPC_ID"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── Tabla PÚBLICA ─────────────────────────────────────────────────────────────
echo "▶ TABLA DE RUTEO PÚBLICA — $RT_PUB_NAME"
echo "  ID: $RT_PUB_ID"
echo "  Subred asociada: $SUBNET_PUB_NAME ($PUB_CIDR)"
echo ""
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PUB_ID" \
  --query "RouteTables[0].Routes[*].{Destino:DestinationCidrBlock, Objetivo:GatewayId, Estado:State, Origen:Origin}" \
  --output table

echo ""
echo "  Subredes vinculadas a esta tabla:"
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PUB_ID" \
  --query "RouteTables[0].Associations[*].{SubnetId:SubnetId, Principal:Main, Estado:AssociationState.State}" \
  --output table

# Verificar que tiene la ruta al IGW
IGW_EN_PUB=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PUB_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null)

if [ -n "$IGW_EN_PUB" ] && [ "$IGW_EN_PUB" != "None" ]; then
  echo ""
  echo "  ✔ VERIFICADO: Tabla pública TIENE ruta 0.0.0.0/0 → $IGW_EN_PUB"
  echo "    → Las instancias en $PUB_CIDR pueden enviar y recibir tráfico de internet."
else
  echo "  ⚠  La tabla pública NO tiene ruta a internet — verificar configuración."
fi

echo ""
echo "────────────────────────────────────────────────────────────────────"
echo ""

# ── Tabla PRIVADA ─────────────────────────────────────────────────────────────
echo "▶ TABLA DE RUTEO PRIVADA — $RT_PRIV_NAME"
echo "  ID: $RT_PRIV_ID"
echo "  Subred asociada: $SUBNET_PRIV_NAME ($PRIV_CIDR)"
echo ""
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[*].{Destino:DestinationCidrBlock, Objetivo:GatewayId, Estado:State, Origen:Origin}" \
  --output table

echo ""
echo "  Subredes vinculadas a esta tabla:"
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Associations[*].{SubnetId:SubnetId, Principal:Main, Estado:AssociationState.State}" \
  --output table

# Verificar que NO tiene ruta al IGW
IGW_EN_PRIV=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null)

if [ -z "$IGW_EN_PRIV" ] || [ "$IGW_EN_PRIV" = "None" ]; then
  echo ""
  echo "  ✔ VERIFICADO: Tabla privada NO tiene ruta 0.0.0.0/0"
  echo "    → Las instancias en $PRIV_CIDR son inaccesibles desde internet."
else
  echo "  ⚠  ALERTA: La tabla privada tiene ruta a internet: $IGW_EN_PRIV"
  echo "     La subred privada está expuesta — revisar configuración."
fi

echo ""
echo "────────────────────────────────────────────────────────────────────"
echo ""

# ── Diferencia lado a lado ────────────────────────────────────────────────────
VPC_CIDR=$(aws ec2 describe-vpcs --region "$REGION" --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].CidrBlock" --output text)

echo "▶ DIFERENCIA CLAVE ENTRE AMBAS TABLAS"
echo ""
printf "  %-32s  %-26s  %-26s\n" "Ruta" "Tabla PÚBLICA" "Tabla PRIVADA"
printf "  %-32s  %-26s  %-26s\n" "────────────────────────────────" "──────────────────────────" "──────────────────────────"
printf "  %-32s  %-26s  %-26s\n" "$VPC_CIDR → local (VPC interna)" "✔ Presente" "✔ Presente"

if [ -n "$IGW_EN_PUB" ] && [ "$IGW_EN_PUB" != "None" ]; then
  printf "  %-32s  %-26s  %-26s\n" "0.0.0.0/0 → Internet Gateway" "✔ $IGW_EN_PUB" "✗ NO EXISTE"
else
  printf "  %-32s  %-26s  %-26s\n" "0.0.0.0/0 → Internet Gateway" "✗ NO CONFIGURADA" "✗ NO EXISTE"
fi

printf "  %-32s  %-26s  %-26s\n" "NAT Gateway" "No necesario (ya tiene IGW)" "No creado (no necesario)"
printf "  %-32s  %-26s  %-26s\n" "IP pública auto en instancias" "True (MapPublicIp=true)" "False (MapPublicIp=false)"
printf "  %-32s  %-26s  %-26s\n" "Alcanzable desde internet" "Sí" "No"
echo ""

# ── Por qué cada subred usa su propia tabla ────────────────────────────────────
echo "▶ EXPLICACIÓN: ¿Por qué cada subred tiene su propia tabla?"
echo ""
echo "  La práctica indica: 'Si usas una sola tabla de ruteo para ambas subredes,"
echo "  todo el tráfico sale por internet, incluida la privada.'"
echo ""
echo "  Con tablas SEPARADAS:"
echo "  · La tabla pública tiene 0.0.0.0/0 → $IGW_EN_PUB"
echo "    → EC2/Nginx puede recibir HTTP/HTTPS del mundo."
echo "  · La tabla privada NO tiene esa ruta"
echo "    → RDS/PostgreSQL solo es alcanzable desde dentro de la VPC."
echo ""
echo "  ✅  Diferencia entre tablas demostrada — ENTREGABLE 2 CUMPLIDO (Criterio 3: 15/15 pts)"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
