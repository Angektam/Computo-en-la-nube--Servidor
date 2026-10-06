#!/bin/bash
# =============================================================================
# PRÁCTICA 05 - La red del proyecto
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  Fecha: 02 oct 2026
# Entregable: P05_LosRojos_02oct2026.pdf
#
# Ejecutar en AWS CloudShell (ya tiene credenciales de la cuenta del proyecto)
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

# Nombre de recursos — mismo esquema de etiquetas que prácticas anteriores
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
SUBNET_PUB_NAME="subnet-pub-$PROYECTO-$EQUIPO"
SUBNET_PRIV_NAME="subnet-priv-$PROYECTO-$EQUIPO"
IGW_NAME="igw-$PROYECTO-$EQUIPO"
RT_PUB_NAME="rt-pub-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"
SG_EC2_NAME="sg-ec2-$PROYECTO-$EQUIPO"
SG_RDS_NAME="sg-rds-$PROYECTO-$EQUIPO"

# CIDRs de direccionamiento (Tarea 7)
VPC_CIDR="10.0.0.0/16"       # 65 534 hosts disponibles
SUBNET_PUB_CIDR="10.0.1.0/24"  # 254 hosts — subred pública (EC2, Nginx)
SUBNET_PRIV_CIDR="10.0.2.0/24" # 254 hosts — subred privada (RDS PostgreSQL)
AZ_PUB="us-east-1a"
AZ_PRIV="us-east-1b"

echo ""
echo "============================================================"
echo "  PRÁCTICA 05 — La red del proyecto"
echo "  Equipo  : Los Rojos"
echo "  Región  : $REGION"
echo "  VPC     : $VPC_CIDR"
echo "  Pública : $SUBNET_PUB_CIDR  ($AZ_PUB)"
echo "  Privada : $SUBNET_PRIV_CIDR ($AZ_PRIV)"
echo "============================================================"
echo ""

# =============================================================================
# SECCIÓN 1 — Crear VPC
# =============================================================================
echo "=== [1/9] Crear VPC ==="

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --query "Vpc.VpcId" --output text)
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
  aws ec2 create-tags --resources "$VPC_ID" --tags \
    Key=Name,Value="$VPC_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ VPC creada: $VPC_ID ($VPC_CIDR)"
else
  echo "· VPC ya existe: $VPC_ID"
fi

# =============================================================================
# SECCIÓN 2 — Crear subredes
# =============================================================================
echo ""
echo "=== [2/9] Crear subred PÚBLICA ($SUBNET_PUB_CIDR) ==="

SUBNET_PUB_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

if [ "$SUBNET_PUB_ID" = "None" ] || [ -z "$SUBNET_PUB_ID" ]; then
  SUBNET_PUB_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$SUBNET_PUB_CIDR" \
    --availability-zone "$AZ_PUB" \
    --query "Subnet.SubnetId" --output text)
  # Auto-asignar IP pública a instancias lanzadas aquí
  aws ec2 modify-subnet-attribute \
    --subnet-id "$SUBNET_PUB_ID" \
    --map-public-ip-on-launch
  aws ec2 create-tags --resources "$SUBNET_PUB_ID" --tags \
    Key=Name,Value="$SUBNET_PUB_NAME" \
    Key=tipo,Value="publica" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ Subred pública creada: $SUBNET_PUB_ID"
else
  echo "· Subred pública ya existe: $SUBNET_PUB_ID"
fi

echo ""
echo "=== [3/9] Crear subred PRIVADA ($SUBNET_PRIV_CIDR) ==="

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

if [ "$SUBNET_PRIV_ID" = "None" ] || [ -z "$SUBNET_PRIV_ID" ]; then
  SUBNET_PRIV_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$SUBNET_PRIV_CIDR" \
    --availability-zone "$AZ_PRIV" \
    --query "Subnet.SubnetId" --output text)
  # NO se auto-asigna IP pública — subred privada
  aws ec2 create-tags --resources "$SUBNET_PRIV_ID" --tags \
    Key=Name,Value="$SUBNET_PRIV_NAME" \
    Key=tipo,Value="privada" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ Subred privada creada: $SUBNET_PRIV_ID"
else
  echo "· Subred privada ya existe: $SUBNET_PRIV_ID"
fi

# =============================================================================
# SECCIÓN 3 — Internet Gateway
# =============================================================================
echo ""
echo "=== [4/9] Crear y adjuntar Internet Gateway ==="

IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=$IGW_NAME" \
  --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)

if [ "$IGW_ID" = "None" ] || [ -z "$IGW_ID" ]; then
  IGW_ID=$(aws ec2 create-internet-gateway \
    --query "InternetGateway.InternetGatewayId" --output text)
  aws ec2 create-tags --resources "$IGW_ID" --tags \
    Key=Name,Value="$IGW_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO"
  aws ec2 attach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID"
  echo "✔ Internet Gateway creado y adjunto: $IGW_ID"
else
  echo "· Internet Gateway ya existe: $IGW_ID"
fi

# =============================================================================
# SECCIÓN 4 — Tablas de ruteo
# =============================================================================
echo ""
echo "=== [5/9] Tabla de ruteo PÚBLICA (con ruta a IGW) ==="

RT_PUB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_PUB_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

if [ "$RT_PUB_ID" = "None" ] || [ -z "$RT_PUB_ID" ]; then
  RT_PUB_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query "RouteTable.RouteTableId" --output text)
  aws ec2 create-tags --resources "$RT_PUB_ID" --tags \
    Key=Name,Value="$RT_PUB_NAME" \
    Key=tipo,Value="publica" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO"
  # Ruta predeterminada → Internet Gateway
  aws ec2 create-route \
    --route-table-id "$RT_PUB_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$IGW_ID"
  # Asociar con la subred pública
  aws ec2 associate-route-table \
    --route-table-id "$RT_PUB_ID" \
    --subnet-id "$SUBNET_PUB_ID"
  echo "✔ Tabla pública creada: $RT_PUB_ID"
  echo "  · Ruta: 0.0.0.0/0 → $IGW_ID (internet)"
else
  echo "· Tabla de ruteo pública ya existe: $RT_PUB_ID"
fi

echo ""
echo "=== [6/9] Tabla de ruteo PRIVADA (sin ruta a internet) ==="

RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

if [ "$RT_PRIV_ID" = "None" ] || [ -z "$RT_PRIV_ID" ]; then
  RT_PRIV_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query "RouteTable.RouteTableId" --output text)
  aws ec2 create-tags --resources "$RT_PRIV_ID" --tags \
    Key=Name,Value="$RT_PRIV_NAME" \
    Key=tipo,Value="privada" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO"
  # Solo ruta local — NO hay ruta 0.0.0.0/0
  aws ec2 associate-route-table \
    --route-table-id "$RT_PRIV_ID" \
    --subnet-id "$SUBNET_PRIV_ID"
  echo "✔ Tabla privada creada: $RT_PRIV_ID"
  echo "  · Solo ruta local: $VPC_CIDR → local"
  echo "  · SIN ruta a internet (no hay IGW)"
else
  echo "· Tabla de ruteo privada ya existe: $RT_PRIV_ID"
fi

# =============================================================================
# SECCIÓN 5 — Security Groups
# =============================================================================
echo ""
echo "=== [7/9] Security Group para EC2 (subred pública) ==="

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_EC2_ID" = "None" ] || [ -z "$SG_EC2_ID" ]; then
  SG_EC2_ID=$(aws ec2 create-security-group \
    --group-name "$SG_EC2_NAME" \
    --description "EC2 servidor web $PROYECTO — SSH restringido + HTTP/HTTPS público" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)
  MI_IP=$(curl -s https://checkip.amazonaws.com)
  # SSH solo para la IP del equipo
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MI_IP}/32,Description=SSH-equipo-los-rojos}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP-publico}]" \
      "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTPS-publico}]" \
      "IpProtocol=tcp,FromPort=3000,ToPort=3000,IpRanges=[{CidrIp=0.0.0.0/0,Description=NodeApp}]"
  aws ec2 create-tags --resources "$SG_EC2_ID" --tags \
    Key=Name,Value="$SG_EC2_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ SG EC2 creado: $SG_EC2_ID"
  echo "  · SSH  : ${MI_IP}/32 (solo IP del equipo)"
  echo "  · HTTP : 0.0.0.0/0"
  echo "  · HTTPS: 0.0.0.0/0"
  echo "  · 3000 : 0.0.0.0/0 (API Node.js)"
else
  echo "· SG EC2 ya existe: $SG_EC2_ID"
fi

echo ""
echo "=== [8/9] Security Group para RDS (subred privada) ==="

SG_RDS_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_RDS_ID" = "None" ] || [ -z "$SG_RDS_ID" ]; then
  SG_RDS_ID=$(aws ec2 create-security-group \
    --group-name "$SG_RDS_NAME" \
    --description "RDS PostgreSQL $PROYECTO — solo desde EC2" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)
  # PostgreSQL solo desde el SG de EC2 — no desde internet
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_RDS_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=5432,ToPort=5432,UserIdGroupPairs=[{GroupId=$SG_EC2_ID,Description=Solo-desde-EC2}]"
  aws ec2 create-tags --resources "$SG_RDS_ID" --tags \
    Key=Name,Value="$SG_RDS_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ SG RDS creado: $SG_RDS_ID"
  echo "  · Puerto 5432 (PostgreSQL): solo desde $SG_EC2_ID"
  echo "  · SIN acceso desde internet"
else
  echo "· SG RDS ya existe: $SG_RDS_ID"
fi

# =============================================================================
# SECCIÓN 6 — Evidencia: diferencia entre tablas de ruteo
# =============================================================================
echo ""
echo "=== [9/9] EVIDENCIA — Tablas de ruteo ==="
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  TABLA DE RUTEO PÚBLICA ($RT_PUB_ID)"
echo "  Subred asociada: $SUBNET_PUB_ID ($SUBNET_PUB_CIDR)"
echo "══════════════════════════════════════════════════════════════"
aws ec2 describe-route-tables \
  --route-table-ids "$RT_PUB_ID" \
  --query "RouteTables[0].Routes[].{Destino:DestinationCidrBlock,Objetivo:GatewayId,Estado:State}" \
  --output table

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  TABLA DE RUTEO PRIVADA ($RT_PRIV_ID)"
echo "  Subred asociada: $SUBNET_PRIV_ID ($SUBNET_PRIV_CIDR)"
echo "══════════════════════════════════════════════════════════════"
aws ec2 describe-route-tables \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[].{Destino:DestinationCidrBlock,Objetivo:GatewayId,Estado:State}" \
  --output table

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  DIFERENCIA CLAVE:"
echo "  Pública  → tiene ruta 0.0.0.0/0 → $IGW_ID (sale a internet)"
echo "  Privada  → SOLO ruta local $VPC_CIDR → local (sin internet)"
echo "══════════════════════════════════════════════════════════════"

# =============================================================================
# SECCIÓN 7 — Evidencia de inaccesibilidad de la subred privada
# =============================================================================
echo ""
echo "=== EVIDENCIA — La subred privada NO se alcanza desde internet ==="
echo ""
echo "--- Descripción de la subred privada ---"
aws ec2 describe-subnets \
  --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,MapPublicIp:MapPublicIpOnLaunch}" \
  --output table

echo ""
echo "· MapPublicIpOnLaunch = false → las instancias en esta subred"
echo "  NO reciben IP pública; son inaccesibles desde internet."
echo ""
echo "--- Reglas del SG de RDS (solo acepta desde EC2) ---"
aws ec2 describe-security-groups \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[].{Puerto:FromPort,Protocolo:IpProtocol,OrigenSG:UserIdGroupPairs[0].GroupId,OrigenCIDR:IpRanges[0].CidrIp}" \
  --output table

echo ""
echo "→ Puerto 5432 abierto solo para $SG_EC2_ID (EC2)"
echo "→ 0.0.0.0/0 NO aparece en las reglas de RDS → internet NO puede conectarse directamente"

# =============================================================================
# SECCIÓN 8 — Resumen completo de la red
# =============================================================================
echo ""
echo "============================================================"
echo "  RESUMEN DE LA RED — PRÁCTICA 05"
echo "============================================================"
echo ""
echo "  VPC             : $VPC_ID  ($VPC_CIDR)"
echo "  Subred pública  : $SUBNET_PUB_ID  ($SUBNET_PUB_CIDR, $AZ_PUB)"
echo "  Subred privada  : $SUBNET_PRIV_ID  ($SUBNET_PRIV_CIDR, $AZ_PRIV)"
echo "  Internet GW     : $IGW_ID"
echo "  Tabla ruteo pub : $RT_PUB_ID  (0.0.0.0/0 → $IGW_ID)"
echo "  Tabla ruteo priv: $RT_PRIV_ID  (solo local)"
echo "  SG EC2          : $SG_EC2_ID  (SSH/HTTP/HTTPS/3000)"
echo "  SG RDS          : $SG_RDS_ID  (5432 solo desde $SG_EC2_ID)"
echo ""
echo "  Etiquetas aplicadas a todos los recursos:"
echo "    proyecto=$PROYECTO | equipo=$EQUIPO | ambiente=$AMBIENTE"
echo ""
echo "============================================================"
echo "  CAPTURAS REQUERIDAS PARA EL REPORTE:"
echo "  [1] Esta salida completa"
echo "  [2] Consola VPC → Your VPCs → ver $VPC_ID con CIDR $VPC_CIDR"
echo "  [3] Consola VPC → Subnets → ambas subredes con sus CIDRs"
echo "  [4] Consola VPC → Route Tables → tabla pública (con IGW)"
echo "  [5] Consola VPC → Route Tables → tabla privada (sin IGW)"
echo "  [6] Consola EC2 → Security Groups → reglas de $SG_EC2_NAME"
echo "  [7] Consola EC2 → Security Groups → reglas de $SG_RDS_NAME"
echo "============================================================"
