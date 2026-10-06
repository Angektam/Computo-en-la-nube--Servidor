#!/bin/bash
# =============================================================================
# PRÁCTICA 03 - Primer servidor del proyecto: cómputo elástico
# =============================================================================
# VALORES FIJOS (resultado de lo que se ejecutó)
# Instance ID : i-0ab6dbe715f440427
# IP pública  : 52.90.172.64 (cambia al reiniciar)
# SG ID       : sg-0d189f861f8d98cc4
# Key Name    : llave-inventario-cloud-los-rojos
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"
INSTANCE_PROFILE="ip-rol-ec2-s3-$EQUIPO"
KEY_NAME="llave-$PROYECTO-$EQUIPO"
SG_NAME="secgrp-$PROYECTO-$EQUIPO"
INSTANCE_NAME="srv-$PROYECTO-$EQUIPO"
AMI_ID="ami-0453ec754f44f9a4a"
INSTANCE_TYPE="t3.micro"   # t2.micro NO es free tier en esta cuenta

# =============================================================================
# SCRIPT 1 - AWS CLOUDSHELL
# Lanzar instancia desde cero (si no existe)
# =============================================================================

echo "=== Verificando par de llaves ==="
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" &>/dev/null; then
  echo "· Par de llaves ya existe: $KEY_NAME"
else
  aws ec2 create-key-pair --key-name "$KEY_NAME" \
    --query "KeyMaterial" --output text > ~/${KEY_NAME}.pem
  chmod 400 ~/${KEY_NAME}.pem
  echo "✔ Llave creada: ~/${KEY_NAME}.pem"
  echo "⚠ Descárgala: CloudShell → Actions → Download file → ${KEY_NAME}.pem"
fi

echo ""
echo "=== Verificando grupo de seguridad ==="
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Servidor $PROYECTO - SSH restringido + HTTP publico" \
    --query "GroupId" --output text)
  MI_IP=$(curl -s https://checkip.amazonaws.com)
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 22 --cidr "${MI_IP}/32"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 80 --cidr "0.0.0.0/0"
  aws ec2 create-tags --resources "$SG_ID" --tags \
    Key=Name,Value="$SG_NAME" Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" Key=ambiente,Value="$AMBIENTE"
  echo "✔ Security Group creado: $SG_ID"
else
  echo "· Security Group ya existe: $SG_ID"
fi

echo ""
echo "=== Lanzando instancia ==="
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
    "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$INSTANCE_PROFILE" \
    --user-data '#!/bin/bash
dnf install -y nginx
systemctl enable nginx
systemctl start nginx
cat > /usr/share/nginx/html/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>inventario-cloud</title>
<style>body{font-family:Arial,sans-serif;text-align:center;padding:60px;background:#f0f4f8}h1{color:#e53e3e}.info{background:white;padding:30px;border-radius:12px;display:inline-block}</style>
</head>
<body><div class="info">
<h1>Servidor en linea</h1>
<p><b>Proyecto:</b> inventario-cloud</p>
<p><b>Equipo:</b> Los Rojos</p>
<p><b>Fecha:</b> 23 de septiembre de 2026</p>
<p><b>Ambiente:</b> dev - us-east-1</p>
<p style="color:green">EC2 t3.micro - Amazon Linux 2023</p>
</div></body></html>
HTMLEOF' \
    --tag-specifications \
      "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=proyecto,Value=$PROYECTO},{Key=equipo,Value=$EQUIPO},{Key=ambiente,Value=$AMBIENTE}]" \
    --query "Instances[0].InstanceId" --output text)
  echo "✔ Instancia lanzada: $INSTANCE_ID"
  echo "Esperando ejecución..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
else
  echo "· Instancia ya existe: $INSTANCE_ID"
  # Si está detenida, arrancarla
  ESTADO=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].State.Name" --output text)
  if [ "$ESTADO" = "stopped" ]; then
    aws ec2 start-instances --instance-ids "$INSTANCE_ID"
    echo "✔ Instancia iniciada"
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  fi
fi

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo ""
echo "=== EVIDENCIA: Instancia con etiquetas y rol ==="
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,Tipo:InstanceType,Estado:State.Name,IP:PublicIpAddress,Rol:IamInstanceProfile.Arn,Nombre:Tags[?Key=='Name']|[0].Value,Proyecto:Tags[?Key=='proyecto']|[0].Value,Equipo:Tags[?Key=='equipo']|[0].Value,Ambiente:Tags[?Key=='ambiente']|[0].Value}" \
  --output table

echo ""
echo "=== EVIDENCIA: Reglas del grupo de seguridad ==="
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[].{Puerto:FromPort,Protocolo:IpProtocol,Origen:IpRanges[0].CidrIp}" \
  --output table

echo ""
echo "========================================"
echo "  ID  : $INSTANCE_ID"
echo "  IP  : $PUBLIC_IP"
echo "  Web : http://${PUBLIC_IP}  (espera 2-3 min)"
echo "  SSH : ssh -i ~/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "========================================"
