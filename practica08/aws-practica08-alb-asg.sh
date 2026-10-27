#!/bin/bash
# =============================================================================
# PRÁCTICA 08 - Alta disponibilidad: balanceador y escalamiento automático
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  Fecha: 21 oct 2026
# Entregable: P08_LosRojos_21oct2026
#
# Ejecutar en AWS CloudShell (ya tiene credenciales de la cuenta del proyecto)
#
# PREREQUISITOS:
#   - Práctica 03 completada (EC2, SG, rol IAM)
#   - Práctica 05 completada (VPC, subredes públicas/privadas en 2 AZ)
# =============================================================================

# Salir inmediatamente si un comando crítico falla
set -e

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

# --- Nombres de recursos ---
VPC_NAME="vpc-$PROYECTO-$EQUIPO"

# BUG-FIX 1: el SG de EC2 puede tener dos nombres según qué práctica lo creó.
#   p03 → "secgrp-inventario-cloud-los-rojos"
#   p05 → "sg-ec2-inventario-cloud-los-rojos"  ← AWS también rechaza "sg-*"
#   Si ninguno existe, creamos uno con nombre válido: "ec2-sg-..."
SG_EC2_NAME_P05="ec2-sg-$PROYECTO-$EQUIPO"   # nombre válido (sin prefijo sg-)
SG_EC2_NAME_P03="secgrp-$PROYECTO-$EQUIPO"

INSTANCE_PROFILE="ip-rol-ec2-s3-$EQUIPO"
AMI_ID="ami-0453ec754f44f9a4a"   # Amazon Linux 2023 us-east-1
INSTANCE_TYPE="t3.micro"

LT_NAME="lt-$PROYECTO-$EQUIPO"
# BUG-FIX 3: AWS rechaza nombres de SG que empiecen con "sg-".
#   Renombramos a "alb-..." en lugar de "sg-alb-..."
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
TG_NAME="tg-$PROYECTO-$EQUIPO"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
POLICY_NAME="policy-cpu-$PROYECTO-$EQUIPO"

# Zonas de disponibilidad
AZ_1="us-east-1a"
AZ_2="us-east-1b"

# Subred pública AZ-1 (creada en p05)
SUBNET_PUB_1_NAME="subnet-pub-$PROYECTO-$EQUIPO"
# Subred pública AZ-2 (nueva en p08)
SUBNET_PUB_2_NAME="subnet-pub2-$PROYECTO-$EQUIPO"

echo ""
echo "============================================================"
echo "  PRÁCTICA 08 — Alta disponibilidad"
echo "  Balanceador + Escalamiento automático"
echo "  Equipo  : Los Rojos"
echo "  Región  : $REGION"
echo "============================================================"
echo ""

# =============================================================================
# Función auxiliar: abortar con mensaje claro
# =============================================================================
die() { echo ""; echo "❌ ERROR FATAL: $*"; echo "   Solución: $2"; exit 1; }

# =============================================================================
# PASO 0 — Recuperar IDs de recursos existentes
# =============================================================================
echo "=== [0/9] Recuperando recursos existentes ==="

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  die "VPC '$VPC_NAME' no encontrada." "Verifica que la práctica 05 esté completada."
fi
echo "· VPC: $VPC_ID"

# -----------------------------------------------------------------------
# BUG-FIX 1: buscar SG de EC2 por ambos posibles nombres
# -----------------------------------------------------------------------
# Buscar por los tres nombres posibles: p05-válido, p03, y p05-original-inválido
for CANDIDATE in "$SG_EC2_NAME_P05" "$SG_EC2_NAME_P03" "sg-ec2-$PROYECTO-$EQUIPO"; do
  SG_EC2_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$CANDIDATE" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)
  if [ -n "$SG_EC2_ID" ] && [ "$SG_EC2_ID" != "None" ]; then
    echo "· SG EC2 encontrado ($CANDIDATE): $SG_EC2_ID"
    break
  fi
done

if [ -z "$SG_EC2_ID" ] || [ "$SG_EC2_ID" = "None" ]; then
  echo "  · SG de EC2 no encontrado — creándolo con nombre válido: $SG_EC2_NAME_P05"
  MI_IP=$(curl -s https://checkip.amazonaws.com)
  SG_EC2_ID=$(aws ec2 create-security-group \
    --group-name "$SG_EC2_NAME_P05" \
    --description "EC2 servidor web $PROYECTO SSH restringido HTTP publico" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MI_IP}/32,Description=SSH-equipo}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP-publico}]"
  aws ec2 create-tags --resources "$SG_EC2_ID" --tags \
    Key=Name,Value="$SG_EC2_NAME_P05" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ SG EC2 creado: $SG_EC2_ID"
fi

# -----------------------------------------------------------------------
# Subred pública AZ-1
# -----------------------------------------------------------------------
SUBNET_PUB_1_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_1_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)

if [ -z "$SUBNET_PUB_1_ID" ] || [ "$SUBNET_PUB_1_ID" = "None" ]; then
  die "Subred pública '$SUBNET_PUB_1_NAME' no encontrada." \
      "Verifica que la práctica 05 esté completada."
fi
echo "· Subred pública 1 ($AZ_1): $SUBNET_PUB_1_ID"

# -----------------------------------------------------------------------
# BUG-FIX 2: subred pública AZ-2
#   Primero buscarla por nombre de p08; si no existe, buscarla por AZ
#   dentro de la VPC (puede que ya exista con otro nombre); solo si de
#   verdad no hay ninguna en AZ-2, calcular un CIDR libre y crearla.
# -----------------------------------------------------------------------
SUBNET_PUB_2_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PUB_2_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)

if [ -z "$SUBNET_PUB_2_ID" ] || [ "$SUBNET_PUB_2_ID" = "None" ]; then
  # ¿Existe ya alguna subred pública en AZ-2 dentro de esta VPC?
  SUBNET_PUB_2_ID=$(aws ec2 describe-subnets \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=availabilityZone,Values=$AZ_2" \
      "Name=map-public-ip-on-launch,Values=true" \
    --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)
fi

if [ -z "$SUBNET_PUB_2_ID" ] || [ "$SUBNET_PUB_2_ID" = "None" ]; then
  echo "→ No existe subred pública en $AZ_2 — buscando CIDR /24 libre en la VPC..."

  # Obtener todos los CIDRs ya usados en la VPC
  CIDRS_USADOS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].CidrBlock" --output text)

  # Iterar bloques /24 dentro de 10.0.0.0/16 hasta encontrar uno libre
  CIDR_LIBRE=""
  for TERCER_OCTETO in $(seq 4 254); do
    CANDIDATO="10.0.${TERCER_OCTETO}.0/24"
    if ! echo "$CIDRS_USADOS" | grep -q "$CANDIDATO"; then
      CIDR_LIBRE="$CANDIDATO"
      break
    fi
  done

  if [ -z "$CIDR_LIBRE" ]; then
    die "No se encontró CIDR /24 libre en la VPC." "Libera subredes innecesarias."
  fi

  echo "  CIDR libre encontrado: $CIDR_LIBRE"

  # Obtener tabla de ruteo pública para asociar la nueva subred
  RT_PUB_ID=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=rt-pub-$PROYECTO-$EQUIPO" \
    --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || true)

  SUBNET_PUB_2_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$CIDR_LIBRE" \
    --availability-zone "$AZ_2" \
    --query "Subnet.SubnetId" --output text)

  aws ec2 modify-subnet-attribute \
    --subnet-id "$SUBNET_PUB_2_ID" \
    --map-public-ip-on-launch

  aws ec2 create-tags --resources "$SUBNET_PUB_2_ID" --tags \
    Key=Name,Value="$SUBNET_PUB_2_NAME" \
    Key=tipo,Value="publica" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"

  # Asociar a la tabla de ruteo pública (si la encontramos)
  if [ -n "$RT_PUB_ID" ] && [ "$RT_PUB_ID" != "None" ]; then
    aws ec2 associate-route-table \
      --route-table-id "$RT_PUB_ID" \
      --subnet-id "$SUBNET_PUB_2_ID" > /dev/null
    echo "✔ Subred pública 2 creada y asociada a tabla pública:"
  else
    echo "✔ Subred pública 2 creada (asocia manualmente a la tabla pública):"
  fi
  echo "  $SUBNET_PUB_2_ID  ($CIDR_LIBRE, $AZ_2)"
else
  echo "· Subred pública 2 ($AZ_2): $SUBNET_PUB_2_ID"
fi

# =============================================================================
# PASO 01 — Preparar la plantilla de lanzamiento (Launch Template)
# El user-data instala nginx y muestra el Instance ID (PASO 02 incluido)
# =============================================================================
echo ""
echo "=== [1/9] Crear plantilla de lanzamiento: $LT_NAME ==="

LT_ID=$(aws ec2 describe-launch-templates \
  --filters "Name=launch-template-name,Values=$LT_NAME" \
  --query "LaunchTemplates[0].LaunchTemplateId" --output text 2>/dev/null || true)

# Script de arranque completo en variable heredoc (sin comillas dentro de JSON)
USER_DATA=$(base64 -w 0 << 'USERDATA_EOF'
#!/bin/bash
dnf install -y nginx
systemctl enable nginx
systemctl start nginx

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /usr/share/nginx/html/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>inventario-cloud</title>
  <style>
    body{font-family:Arial,sans-serif;text-align:center;padding:60px;background:#f0f4f8}
    h1{color:#e53e3e}
    .card{background:white;padding:30px 40px;border-radius:12px;
          display:inline-block;box-shadow:0 4px 12px rgba(0,0,0,.1)}
    .iid{font-size:1.4em;font-weight:bold;color:#2b6cb0;background:#ebf8ff;
         padding:8px 16px;border-radius:6px;margin:12px 0;display:inline-block}
    .az{color:#718096;font-size:.9em}
  </style>
</head>
<body>
  <div class="card">
    <h1>Servidor en línea ✓</h1>
    <p><b>Proyecto:</b> inventario-cloud</p>
    <p><b>Equipo:</b> Los Rojos</p>
    <p class="iid">Instance ID: ${INSTANCE_ID}</p>
    <p class="az">Zona: ${AZ}</p>
    <p style="color:green">EC2 t3.micro · Amazon Linux 2023 · Nginx</p>
    <p style="color:#a0aec0;font-size:.8em">Práctica 08 · Alta disponibilidad · 21 oct 2026</p>
  </div>
</body>
</html>
HTMLEOF

printf 'OK\n' > /usr/share/nginx/html/health

systemctl restart nginx
USERDATA_EOF
)

if [ -z "$LT_ID" ] || [ "$LT_ID" = "None" ]; then
  # Construir JSON de la plantilla en un archivo temporal para evitar
  # problemas de escape al pasar SG_EC2_ID dentro de una cadena shell
  TMP_LT=$(mktemp)
  cat > "$TMP_LT" << LTJSON
{
  "ImageId": "$AMI_ID",
  "InstanceType": "$INSTANCE_TYPE",
  "IamInstanceProfile": { "Name": "$INSTANCE_PROFILE" },
  "SecurityGroupIds": [ "$SG_EC2_ID" ],
  "UserData": "$USER_DATA",
  "TagSpecifications": [{
    "ResourceType": "instance",
    "Tags": [
      { "Key": "Name",      "Value": "srv-asg-$EQUIPO" },
      { "Key": "proyecto",  "Value": "$PROYECTO" },
      { "Key": "equipo",    "Value": "$EQUIPO" },
      { "Key": "ambiente",  "Value": "$AMBIENTE" },
      { "Key": "origen",    "Value": "auto-scaling" }
    ]
  }]
}
LTJSON

  LT_ID=$(aws ec2 create-launch-template \
    --launch-template-name "$LT_NAME" \
    --version-description "v1-p08-alta-disponibilidad" \
    --launch-template-data "file://$TMP_LT" \
    --query "LaunchTemplate.LaunchTemplateId" --output text)
  rm -f "$TMP_LT"

  echo "✔ Launch Template creada: $LT_ID"
  echo "  · AMI        : $AMI_ID"
  echo "  · Tipo       : $INSTANCE_TYPE"
  echo "  · Perfil IAM : $INSTANCE_PROFILE"
  echo "  · SG EC2     : $SG_EC2_ID"
  echo "  · User-data  : instala nginx + muestra Instance ID en la página"
else
  echo "· Launch Template ya existe: $LT_ID"
fi

# =============================================================================
# PASO 03 — Crear SG del balanceador y el ALB
# BUG-FIX 3: nombre sin prefijo "sg-" → "alb-sg-inventario-cloud-los-rojos"
# =============================================================================
echo ""
echo "=== [3/9] Crear SG del balanceador: $SG_ALB_NAME ==="

SG_ALB_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_ALB_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)

if [ -z "$SG_ALB_ID" ] || [ "$SG_ALB_ID" = "None" ]; then
  SG_ALB_ID=$(aws ec2 create-security-group \
    --group-name "$SG_ALB_NAME" \
    --description "ALB $PROYECTO HTTP HTTPS desde internet" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ALB_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP-internet}]" \
      "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTPS-internet}]"
  aws ec2 create-tags --resources "$SG_ALB_ID" --tags \
    Key=Name,Value="$SG_ALB_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ SG ALB creado: $SG_ALB_ID"
  echo "  · Puerto 80  : 0.0.0.0/0"
  echo "  · Puerto 443 : 0.0.0.0/0"
else
  echo "· SG ALB ya existe: $SG_ALB_ID"
fi

echo ""
echo "=== Crear ALB: $ALB_NAME ==="

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || true)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$SUBNET_PUB_1_ID" "$SUBNET_PUB_2_ID" \
    --security-groups "$SG_ALB_ID" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags \
      Key=Name,Value="$ALB_NAME" \
      Key=proyecto,Value="$PROYECTO" \
      Key=equipo,Value="$EQUIPO" \
      Key=ambiente,Value="$AMBIENTE" \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)
  echo "✔ ALB creado: $ALB_ARN"
  echo "  · Subred AZ-1: $SUBNET_PUB_1_ID"
  echo "  · Subred AZ-2: $SUBNET_PUB_2_ID"
  echo "  · SG: $SG_ALB_ID"
  echo "  Esperando que el ALB esté activo (puede tardar 2-3 min)..."
  aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"
  echo "✔ ALB activo."
else
  echo "· ALB ya existe: $ALB_ARN"
fi

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)
echo "  · DNS: http://$ALB_DNS"

# =============================================================================
# PASO 04 — Target Group y health check
# =============================================================================
echo ""
echo "=== [4/9] Crear Target Group: $TG_NAME ==="

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || true)

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
  TG_ARN=$(aws elbv2 create-target-group \
    --name "$TG_NAME" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPC_ID" \
    --target-type instance \
    --health-check-protocol HTTP \
    --health-check-port traffic-port \
    --health-check-path "/health" \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --tags \
      Key=Name,Value="$TG_NAME" \
      Key=proyecto,Value="$PROYECTO" \
      Key=equipo,Value="$EQUIPO" \
    --query "TargetGroups[0].TargetGroupArn" --output text)
  echo "✔ Target Group creado: $TG_ARN"
  echo "  · Health check : GET /health cada 15 s"
  echo "  · Umbral sano  : 2 checks OK → entra al pool"
  echo "  · Umbral insano: 2 checks KO → sale del pool"
else
  echo "· Target Group ya existe: $TG_ARN"
fi

# Listener HTTP
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null || true)

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
  LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TG_ARN" \
    --query "Listeners[0].ListenerArn" --output text)
  echo "✔ Listener HTTP:80 creado: $LISTENER_ARN"
else
  echo "· Listener ya existe: $LISTENER_ARN"
fi

# =============================================================================
# PASO 05 — Cerrar acceso directo: EC2 solo acepta HTTP desde el ALB
# =============================================================================
echo ""
echo "=== [5/9] Cerrar acceso directo — EC2 solo acepta desde ALB ==="

# Revocar HTTP público (0.0.0.0/0) si existe
HTTP_PUB=$(aws ec2 describe-security-groups \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && contains(IpRanges[].CidrIp, '0.0.0.0/0')]" \
  --output text 2>/dev/null || true)
if [ -n "$HTTP_PUB" ] && [ "$HTTP_PUB" != "None" ]; then
  aws ec2 revoke-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --protocol tcp --port 80 --cidr "0.0.0.0/0" 2>/dev/null || true
  echo "✔ Regla HTTP 0.0.0.0/0:80 revocada del SG de EC2"
fi

# Revocar HTTPS y 3000 públicos si existen
aws ec2 revoke-security-group-ingress \
  --group-id "$SG_EC2_ID" --protocol tcp --port 443 --cidr "0.0.0.0/0" 2>/dev/null || true
aws ec2 revoke-security-group-ingress \
  --group-id "$SG_EC2_ID" --protocol tcp --port 3000 --cidr "0.0.0.0/0" 2>/dev/null || true

# Agregar regla HTTP solo desde el SG del ALB (si aún no existe)
ALB_RULE=$(aws ec2 describe-security-groups \
  --group-ids "$SG_EC2_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && UserIdGroupPairs[0].GroupId=='$SG_ALB_ID']" \
  --output text 2>/dev/null || true)
if [ -z "$ALB_RULE" ] || [ "$ALB_RULE" = "None" ]; then
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs=[{GroupId=$SG_ALB_ID,Description=Solo-desde-ALB}]"
  echo "✔ Regla añadida: puerto 80 solo desde ALB ($SG_ALB_ID)"
else
  echo "· Regla ALB→EC2 ya existe"
fi
echo "  → Internet NO puede conectarse directamente a los servidores."

# =============================================================================
# PASO 06 — Auto Scaling Group
# min=2  desired=2  max=4  distribuido en 2 AZ
# =============================================================================
echo ""
echo "=== [6/9] Crear Auto Scaling Group: $ASG_NAME ==="

ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null || true)

if [ -z "$ASG_EXISTS" ] || [ "$ASG_EXISTS" = "None" ]; then
  aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template "LaunchTemplateId=$LT_ID,Version=\$Latest" \
    --min-size 2 \
    --max-size 4 \
    --desired-capacity 2 \
    --vpc-zone-identifier "$SUBNET_PUB_1_ID,$SUBNET_PUB_2_ID" \
    --target-group-arns "$TG_ARN" \
    --health-check-type ELB \
    --health-check-grace-period 60 \
    --default-cooldown 120 \
    --tags \
      "Key=Name,Value=srv-asg-$EQUIPO,PropagateAtLaunch=true" \
      "Key=proyecto,Value=$PROYECTO,PropagateAtLaunch=true" \
      "Key=equipo,Value=$EQUIPO,PropagateAtLaunch=true" \
      "Key=ambiente,Value=$AMBIENTE,PropagateAtLaunch=true"
  echo "✔ Auto Scaling Group creado: $ASG_NAME"
  echo "  · Mínimo   : 2 instancias"
  echo "  · Deseado  : 2 instancias"
  echo "  · Máximo   : 4 instancias"
  echo "  · AZ 1     : $AZ_1 ($SUBNET_PUB_1_ID)"
  echo "  · AZ 2     : $AZ_2 ($SUBNET_PUB_2_ID)"
  echo "  · HC type  : ELB (usa /health del Target Group)"
  echo "  · Cooldown : 120 s"
  echo ""
  echo "  Esperando que las instancias arranquen (30 s)..."
  sleep 30
else
  echo "· ASG ya existe: $ASG_NAME"
fi

# =============================================================================
# PASO 09 — Política de escalado por CPU al 60 %
# BUG-FIX 4: TargetTrackingScaling NO acepta ScaleInCooldown ni
#   ScaleOutCooldown dentro de TargetTrackingConfiguration.
#   El cooldown se maneja con --default-cooldown en el ASG (ya aplicado
#   arriba) o con EstimatedInstanceWarmup dentro de la configuración.
# =============================================================================
echo ""
echo "=== [9/9] Política de escalado por CPU: umbral 60 % ==="

POLICY_ARN=$(aws autoscaling describe-policies \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-names "$POLICY_NAME" \
  --query "ScalingPolicies[0].PolicyARN" --output text 2>/dev/null || true)

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "None" ]; then
  # JSON de configuración en archivo temporal para evitar errores de escape
  TMP_TTC=$(mktemp)
  # TargetTrackingConfiguration solo acepta estos tres campos.
  # El warmup se controla con --health-check-grace-period en el ASG (ya aplicado).
  cat > "$TMP_TTC" << TTCJSON
{
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  },
  "TargetValue": 60.0,
  "DisableScaleIn": false
}
TTCJSON

  POLICY_ARN=$(aws autoscaling put-scaling-policy \
    --auto-scaling-group-name "$ASG_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-type TargetTrackingScaling \
    --estimated-instance-warmup 120 \
    --target-tracking-configuration "file://$TMP_TTC" \
    --query "PolicyARN" --output text)
  rm -f "$TMP_TTC"

  echo "✔ Política de escalado creada: $POLICY_ARN"
  echo "  · Métrica              : CPU promedio del ASG"
  echo "  · Umbral               : 60 %"
  echo "  · Warm-up instancia    : 120 s (tiempo hasta que el nginx responde)"
  echo "  · Scale-in desactivado : no (se permite reducir)"
  echo ""
  echo "  JUSTIFICACIÓN DEL UMBRAL:"
  echo "  · 60 % = servidor comprometido pero no saturado."
  echo "  · Da ~120 s para que la nueva instancia arranque antes"
  echo "    de que la carga llegue a degradar la experiencia."
  echo "  · Por encima de 80 % el usuario ya nota latencia alta;"
  echo "    por debajo de 40 % escalaría ante cargas normales (costo extra)."
else
  echo "· Política ya existe: $POLICY_ARN"
fi

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "============================================================"
echo "  RESUMEN — PRÁCTICA 08"
echo "============================================================"
echo ""
echo "  VPC             : $VPC_ID"
echo "  Subred pub AZ-1 : $SUBNET_PUB_1_ID ($AZ_1)"
echo "  Subred pub AZ-2 : $SUBNET_PUB_2_ID ($AZ_2)"
echo ""
echo "  SG del ALB      : $SG_ALB_ID  ($SG_ALB_NAME)"
echo "  SG de EC2       : $SG_EC2_ID  (HTTP solo desde ALB)"
echo ""
echo "  Launch Template : $LT_ID  ($LT_NAME)"
echo "  Target Group    : $TG_ARN"
echo "  Load Balancer   : $ALB_ARN"
echo "  Auto Scaling G. : $ASG_NAME"
echo "  Política CPU    : $POLICY_ARN"
echo ""
echo "  ➜  URL del balanceador:"
echo "     http://$ALB_DNS"
echo ""
echo "  SIGUIENTE PASO — espera 2-3 min y ejecuta los scripts de evidencia:"
echo "    bash evidencia-p08-c1-balanceo.sh"
echo "    bash evidencia-p08-c2-health-check.sh"
echo "    bash evidencia-p08-c3-falla.sh"
echo "    bash evidencia-p08-c4-recuperacion.sh"
echo "    bash evidencia-p08-c5-escalado-cpu.sh"
echo "============================================================"
