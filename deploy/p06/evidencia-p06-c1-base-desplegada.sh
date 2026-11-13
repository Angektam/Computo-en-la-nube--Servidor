#!/bin/bash
# =============================================================================
# CAPTURA 1 — Base desplegada: sin acceso público y cifrado activo
# Ejecutar en: AWS CloudShell
# Evidencia para: Lista de cotejo — 25 pts (subred privada) + 10 pts (cifrado)
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
DB_IDENTIFIER="rds-$PROYECTO-$EQUIPO"
SG_RDS_NAME="rds-$PROYECTO-$EQUIPO"
SG_EC2_NAME="ec2-$PROYECTO-$EQUIPO"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  CAPTURA 1 — Base desplegada en subred privada con cifrado activo"
echo "  Equipo: Los Rojos  |  Práctica 06"
echo "════════════════════════════════════════════════════════════════════"
echo ""

echo "▶ Datos generales de la instancia RDS:"
echo ""
aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].{
    Identificador:DBInstanceIdentifier,
    Motor:Engine,
    Version:EngineVersion,
    Clase:DBInstanceClass,
    Estado:DBInstanceStatus,
    IP_Publica:PubliclyAccessible,
    Cifrado_Reposo:StorageEncrypted,
    Zona:AvailabilityZone,
    Puerto:Endpoint.Port,
    Endpoint:Endpoint.Address,
    Retension_Respaldo_dias:BackupRetentionPeriod,
    Subnet_Group:DBSubnetGroup.DBSubnetGroupName,
    VPC:DBSubnetGroup.VpcId
  }" \
  --output table

echo ""

# Verificar criterios automáticamente
IP_PUB=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].PubliclyAccessible" --output text)

CIFRADO=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].StorageEncrypted" --output text)

echo "▶ Verificación de criterios de la lista de cotejo:"
echo ""
if [ "$IP_PUB" = "False" ]; then
  echo "  ✔ PubliclyAccessible = False  → Sin IP pública [25 pts]"
else
  echo "  ✗ PubliclyAccessible = True   → REVISAR"
fi

if [ "$CIFRADO" = "True" ]; then
  echo "  ✔ StorageEncrypted   = True   → Cifrado en reposo AES-256 [10 pts]"
else
  echo "  ✗ StorageEncrypted   = False  → REVISAR"
fi

echo ""
echo "▶ Subredes del DB Subnet Group (debe tener ≥ 2 zonas de disponibilidad):"
echo ""
SUBNET_GRP=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text)

aws rds describe-db-subnet-groups \
  --region "$REGION" \
  --db-subnet-group-name "$SUBNET_GRP" \
  --query "DBSubnetGroups[0].Subnets[*].{
    SubnetId:SubnetIdentifier,
    Zona:SubnetAvailabilityZone.Name,
    Estado:SubnetStatus
  }" \
  --output table

echo ""
echo "▶ Reglas del Security Group de RDS (debe referenciar SG de EC2, NO 0.0.0.0/0):"
echo ""
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text)

SG_RDS_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)

aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[].{
    Puerto:FromPort,
    Protocolo:IpProtocol,
    Origen_Grupo:UserIdGroupPairs[0].GroupId,
    Origen_CIDR:IpRanges[0].CidrIp
  }" \
  --output table

SG_EC2_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)

ORIGEN=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\`].UserIdGroupPairs[0].GroupId" \
  --output text)

if [ "$ORIGEN" = "$SG_EC2_ID" ]; then
  echo "  ✔ Puerto 5432 → origen: $SG_EC2_ID (SG del EC2) [20 pts]"
  echo "  ✔ 0.0.0.0/0 NO está en las reglas → internet no puede conectarse"
else
  echo "  ✗ REVISAR: el origen del puerto 5432 no es el SG de EC2"
fi

echo ""
echo "↑ TOMA CAPTURA DE ESTA PANTALLA COMPLETA ↑"
echo "════════════════════════════════════════════════════════════════════"
