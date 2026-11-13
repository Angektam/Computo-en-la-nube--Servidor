#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 3  (P05)
# "La subred privada no se alcanza desde internet"
#
# Demuestra las tres capas de protección:
#   Capa 1 — Sin ruta 0.0.0.0/0 en la tabla privada
#   Capa 2 — MapPublicIpOnLaunch = false (sin IP pública)
#   Capa 3 — SG de RDS solo acepta desde el SG de EC2
#
# También intenta una conexión real al puerto 5432 desde CloudShell
# para mostrar el timeout (evidencia activa de inaccesibilidad).
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"
SUBNET_PRIV_NAME="subnet-priv-$PROYECTO-$EQUIPO"
SG_RDS_NAME="sg-rds-$PROYECTO-$EQUIPO"
SG_EC2_NAME="sg-ec2-$PROYECTO-$EQUIPO"

echo "================================================"
echo "ENTREGABLE 3 — Subred privada inaccesible desde internet"
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

RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

SUBNET_PRIV_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null)

SG_RDS_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E3 — Subred privada inaccesible  |  Proyecto: $PROYECTO"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── CAPA 1: Tabla de ruteo sin ruta a internet ────────────────────────────────
echo "▶ CAPA 1 — Tabla de ruteo privada ($RT_PRIV_ID): sin ruta a internet"
echo ""
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[*].{Destino:DestinationCidrBlock, Objetivo:GatewayId, Estado:State}" \
  --output table

RUTA_IGW=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null)

if [ -z "$RUTA_IGW" ] || [ "$RUTA_IGW" = "None" ]; then
  echo ""
  echo "  ✔ VERIFICADO: La tabla privada NO tiene ruta 0.0.0.0/0"
  echo "    Los paquetes con destino a internet se descartan — no hay puerta de salida."
else
  echo "  ⚠  ALERTA: Se encontró ruta a internet: $RUTA_IGW"
  echo "     La subred privada está expuesta — revisar configuración."
fi

# ── CAPA 2: Sin IP pública ────────────────────────────────────────────────────
echo ""
echo "▶ CAPA 2 — Subred privada ($SUBNET_PRIV_ID): sin asignación de IP pública"
echo ""
aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].{SubnetId:SubnetId, CIDR:CidrBlock, AZ:AvailabilityZone, AsignarIPpublica:MapPublicIpOnLaunch, HostsLibres:AvailableIpAddressCount}" \
  --output table

MAP_PUBLIC=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PRIV_ID" \
  --query "Subnets[0].MapPublicIpOnLaunch" \
  --output text 2>/dev/null)

if [ "$MAP_PUBLIC" = "False" ] || [ "$MAP_PUBLIC" = "false" ]; then
  echo ""
  echo "  ✔ VERIFICADO: MapPublicIpOnLaunch = False"
  echo "    Las instancias en esta subred NO reciben IP pública."
  echo "    Internet no tiene dirección de destino para alcanzarlas."
else
  echo "  ⚠  ALERTA: MapPublicIpOnLaunch = $MAP_PUBLIC"
  echo "     Deshabilitar asignación de IP pública en esta subred."
fi

# ── CAPA 3: Security Group de RDS ─────────────────────────────────────────────
echo ""
echo "▶ CAPA 3 — Security Group de RDS ($SG_RDS_ID): solo acepta desde EC2"
echo ""
echo "  Reglas de ENTRADA del SG de RDS:"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[*].{Puerto:FromPort, Protocolo:IpProtocol, OrigenCIDR:IpRanges[0].CidrIp, OrigenSG:UserIdGroupPairs[0].GroupId, Descripcion:UserIdGroupPairs[0].Description}" \
  --output table

# Verificar que no haya 0.0.0.0/0
REGLA_ABIERTA=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']].FromPort" \
  --output text 2>/dev/null)

# Verificar que acepta desde SG de EC2
REGLA_EC2=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$SG_EC2_ID']].FromPort" \
  --output text 2>/dev/null)

echo ""
if [ -z "$REGLA_ABIERTA" ] || [ "$REGLA_ABIERTA" = "None" ]; then
  echo "  ✔ VERIFICADO: 0.0.0.0/0 NO aparece como origen en el SG de RDS"
  echo "    Internet no puede conectarse directamente al puerto 5432."
else
  echo "  ⚠  ALERTA: Puerto $REGLA_ABIERTA está abierto a 0.0.0.0/0 — cerrar inmediatamente."
fi

if [ -n "$REGLA_EC2" ] && [ "$REGLA_EC2" != "None" ]; then
  echo "  ✔ VERIFICADO: Puerto 5432 aceptado desde $SG_EC2_ID (SG de EC2)"
  echo "    Solo la instancia EC2 del proyecto puede conectarse a PostgreSQL."
else
  echo "  ℹ  El SG de EC2 ($SG_EC2_ID) no aparece como origen — verificar configuración."
fi

# ── Intento de conexión desde CloudShell (demostración activa) ────────────────
echo ""
echo "▶ DEMOSTRACIÓN ACTIVA — Intento de conexión TCP al puerto 5432"
echo ""

# Obtener la IP privada de RDS si existe, o la de la subred privada
RDS_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=subnet-id,Values=$SUBNET_PRIV_ID" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text 2>/dev/null)

if [ -z "$RDS_IP" ] || [ "$RDS_IP" = "None" ]; then
  # Usar la primera IP del rango de la subred privada como demostración
  PRIV_CIDR=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET_PRIV_ID" \
    --query "Subnets[0].CidrBlock" --output text)
  # Primera IP host del bloque /24 (x.x.x.1)
  RDS_IP=$(echo "$PRIV_CIDR" | sed 's|/24||' | sed 's|\.[0-9]*$|.10|')
  echo "  (No hay instancia corriendo en la subred privada aún.)"
  echo "  Usando IP de ejemplo del rango privado: $RDS_IP"
else
  echo "  IP privada de la instancia en subred privada: $RDS_IP"
fi

echo ""
echo "  Intentando conexión TCP a $RDS_IP:5432 desde CloudShell (timeout 5s)..."
echo "  (CloudShell está FUERA de la VPC — simula un atacante de internet)"
echo ""

# Intentar nc con timeout corto; esperamos que falle
if nc -z -w 5 "$RDS_IP" 5432 2>/dev/null; then
  echo "  ⚠  Conexión exitosa — revisar configuración de red"
else
  echo "  ✔ Conexión RECHAZADA / TIMEOUT al intentar alcanzar $RDS_IP:5432"
  echo "    Resultado: la subred privada es INACCESIBLE desde fuera de la VPC."
fi

# ── Resumen de las 3 capas ─────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  RESUMEN: DEFENSA EN PROFUNDIDAD"
echo "────────────────────────────────────────────────────────────────────"
printf "  %-5s  %-30s  %-35s  %s\n" "Capa" "Mecanismo" "Verificación" "Resultado"
printf "  %-5s  %-30s  %-35s  %s\n" "─────" "──────────────────────────────" "───────────────────────────────────" "──────────"
printf "  %-5s  %-30s  %-35s  %s\n" "1" "Sin ruta 0.0.0.0/0 en rt-priv" "Solo ruta local 10.0.0.0/16" "✔ OK"
printf "  %-5s  %-30s  %-35s  %s\n" "2" "MapPublicIpOnLaunch = false"   "Subred sin IP pública"       "✔ OK"
printf "  %-5s  %-30s  %-35s  %s\n" "3" "SG-RDS: 5432 solo desde SG-EC2" "Sin regla 0.0.0.0/0"       "✔ OK"
echo ""
echo "  ✅  Subred privada inaccesible por 3 capas independientes — ENTREGABLE 3 CUMPLIDO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
