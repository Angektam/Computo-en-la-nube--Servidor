#!/bin/bash
# =============================================================================
# PRÁCTICA 11 - Ejecutar el contenedor del proyecto sin administrar servidores
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  Fecha: 4 nov 2026
# Entregable: P11_LosRojos_04nov2026
#
# Ejecutar en AWS CloudShell (ya tiene credenciales de la cuenta del proyecto)
#
# PREREQUISITOS:
#   - Práctica 05 completada (VPC, subredes públicas y privadas en 2 AZ)
#   - Práctica 06 completada (RDS PostgreSQL en subred privada)
#   - Práctica 08 completada (ALB + Target Group + SG del ALB)
#   - Práctica 10 completada (imagen publicada en ECR)
#
# QUÉ HACE ESTE SCRIPT:
#   01. Crea el clúster de contenedores (ECS)
#   02. Crea un NAT Gateway para que las tareas en subred privada puedan
#       descargar la imagen del registro ECR
#   03. Crea el grupo de seguridad de las tareas (solo recibe del ALB)
#   04. Autoriza a las tareas a conectarse a la base de datos (RDS)
#   05. Crea el rol de ejecución de la tarea (leer ECR + enviar logs)
#   06. Crea el rol de la tarea con permisos acotados (solo S3 del bucket)
#   07. Define la tarea: imagen, CPU, memoria, puerto y variables de entorno
#   08. Crea un grupo destino tipo ip para el balanceador
#   09. Conecta el servicio al balanceador
#   10. Detiene las instancias EC2 del ASG (para ahorrar y liberar el TG)
#   11. Despliega el servicio en subredes privadas, sin IP pública
#   12. Espera a que las tareas estén sanas
#   13. Imprime el resumen con todos los datos para el reporte
#
# COSTO: El NAT Gateway cobra por hora. Ejecutar parar-p11.sh al terminar
#        para eliminarlo y liberar la IP elástica.
# =============================================================================

set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────────────────
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

# Imagen del registro (P10)
REPO_NAME="inventario-nube-losrojos"
IMAGE_TAG="1.0.0"

# Recursos ECS
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
TASK_FAMILY="td-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"
CONTAINER_NAME="inventario-nube"
CONTAINER_PORT=3000

# Roles IAM
EXEC_ROLE_NAME="rol-ecs-exec-$EQUIPO"
TASK_ROLE_NAME="rol-ecs-task-$EQUIPO"

# Security Groups
SG_ECS_NAME="ecs-sg-$PROYECTO-$EQUIPO"

# Target Group para ECS (tipo ip, distinto al de EC2 que es instance)
TG_ECS_NAME="tg-ecs-$PROYECTO-$EQUIPO"

# NAT Gateway
NAT_NAME="nat-$PROYECTO-$EQUIPO"
EIP_NAME="eip-$PROYECTO-$EQUIPO"

# Recursos existentes (P05/P06/P08)
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
SUBNET_PUB1_NAME="subnet-pub-$PROYECTO-$EQUIPO"
SUBNET_PRIV1_NAME="subnet-priv-$PROYECTO-$EQUIPO"
SUBNET_PRIV2_NAME="subnet-priv2-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"
SG_ALB_NAME="alb-sg-$PROYECTO-$EQUIPO"
ALB_NAME="alb-$PROYECTO-$EQUIPO"
ASG_NAME="asg-$PROYECTO-$EQUIPO"
RDS_ID="rds-$PROYECTO-$EQUIPO"

# Recursos CPU/memoria Fargate
TASK_CPU=256        # 0.25 vCPU
TASK_MEMORY=512     # 512 MB
DESIRED_COUNT=2

# ── Helpers ───────────────────────────────────────────────────────────────────
die() { echo ""; echo "❌ ERROR FATAL: $1"; echo "   $2"; exit 1; }

# Lee un valor del archivo .env del proyecto
# Busca .env en el directorio padre del script (raíz del proyecto)
ENV_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for CANDIDATE in "$SCRIPT_DIR/../.env" "$(pwd)/.env" "$HOME/.env"; do
  if [ -f "$CANDIDATE" ]; then ENV_FILE="$CANDIDATE"; break; fi
done

get_env() {
  local key="$1"
  local default="$2"
  local file="${3:-$ENV_FILE}"
  if [ -n "$file" ] && [ -f "$file" ]; then
    local val
    val=$(grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2-)
    if [ -n "$val" ]; then printf '%s' "$val"; return; fi
  fi
  printf '%s' "$default"
}

echo ""
echo "============================================================"
echo "  PRÁCTICA 11 — Ejecutar el contenedor sin administrar"
echo "  servidores (ECS Fargate + ALB)"
echo "  Equipo  : Los Rojos"
echo "  Región  : $REGION"
echo "============================================================"
echo ""

# =============================================================================
# PASO 0 — Recuperar recursos existentes
# =============================================================================
echo "=== [0/13] Recuperando recursos de prácticas anteriores ==="

# Cuenta AWS y URI de ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
FULL_IMAGE="${ECR_URI}/${REPO_NAME}:${IMAGE_TAG}"

# VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null) || true
[ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ] && die "VPC '$VPC_NAME' no encontrada." "Ejecuta la práctica 05 primero."
echo "· VPC              : $VPC_ID"

# Subred pública 1 (para NAT Gateway)
SUBNET_PUB1_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PUB1_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null) || true
[ -z "$SUBNET_PUB1_ID" ] || [ "$SUBNET_PUB1_ID" = "None" ] && die "Subred pública '$SUBNET_PUB1_NAME' no encontrada." "Ejecuta la práctica 05 primero."
echo "· Subred pública 1  : $SUBNET_PUB1_ID"

# Subred privada 1
SUBNET_PRIV1_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV1_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null) || true
[ -z "$SUBNET_PRIV1_ID" ] || [ "$SUBNET_PRIV1_ID" = "None" ] && die "Subred privada '$SUBNET_PRIV1_NAME' no encontrada." "Ejecuta la práctica 05 primero."
echo "· Subred privada 1  : $SUBNET_PRIV1_ID"

# Subred privada 2
SUBNET_PRIV2_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_PRIV2_NAME" \
  --query "Subnets[0].SubnetId" --output text 2>/dev/null) || true
[ -z "$SUBNET_PRIV2_ID" ] || [ "$SUBNET_PRIV2_ID" = "None" ] && die "Subred privada '$SUBNET_PRIV2_NAME' no encontrada." "Ejecuta la práctica 06 primero."
echo "· Subred privada 2  : $SUBNET_PRIV2_ID"

# Tabla de ruteo privada
RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null) || true
if [ -z "$RT_PRIV_ID" ] || [ "$RT_PRIV_ID" = "None" ]; then
  echo "· Tabla ruteo priv  : no encontrada por nombre, buscando por subred..."
  RT_PRIV_ID=$(aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=$SUBNET_PRIV1_ID" \
    --query "RouteTables[0].RouteTableId" --output text 2>/dev/null) || true
  if [ -z "$RT_PRIV_ID" ] || [ "$RT_PRIV_ID" = "None" ]; then
    # Usar la tabla principal de la VPC
    RT_PRIV_ID=$(aws ec2 describe-route-tables \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
      --query "RouteTables[0].RouteTableId" --output text 2>/dev/null) || true
  fi
fi
echo "· Tabla ruteo priv  : $RT_PRIV_ID"

# SG del ALB
SG_ALB_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_ALB_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null) || true
[ -z "$SG_ALB_ID" ] || [ "$SG_ALB_ID" = "None" ] && die "SG del ALB '$SG_ALB_NAME' no encontrado." "Ejecuta la práctica 08 primero."
echo "· SG del ALB        : $SG_ALB_ID"

# ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null) || true
[ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ] && die "ALB '$ALB_NAME' no encontrado." "Ejecuta la práctica 08 primero."
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" --output text)
echo "· ALB              : $ALB_ARN"
echo "· ALB DNS          : $ALB_DNS"

# RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_ID" \
  --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null) || true
if [ -z "$DB_ENDPOINT" ] || [ "$DB_ENDPOINT" = "None" ]; then
  # Intentar con el endpoint del .env
  DB_ENDPOINT=$(get_env DB_HOST "" )
  [ -z "$DB_ENDPOINT" ] && die "RDS '$RDS_ID' no encontrado." "Verifica que la práctica 06 esté completada y la instancia exista."
fi
echo "· RDS endpoint     : $DB_ENDPOINT"

# SG de RDS (buscar por nombre o por la instancia RDS)
SG_RDS_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=sg-rds-$PROYECTO-$EQUIPO" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null) || true
if [ -z "$SG_RDS_ID" ] || [ "$SG_RDS_ID" = "None" ]; then
  # Buscar como rds-inventario-cloud-los-rojos
  SG_RDS_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=rds-$PROYECTO-$EQUIPO" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null) || true
fi
if [ -z "$SG_RDS_ID" ] || [ "$SG_RDS_ID" = "None" ]; then
  # Buscar por los SG adjuntos a la instancia RDS
  SG_RDS_ID=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_ID" \
    --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" --output text 2>/dev/null) || true
fi
[ -z "$SG_RDS_ID" ] || [ "$SG_RDS_ID" = "None" ] && die "SG de RDS no encontrado." "Verifica la práctica 05/06."
echo "· SG de RDS        : $SG_RDS_ID"

# Verificar que la imagen existe en ECR
ECR_CHECK=$(aws ecr describe-images \
  --repository-name "$REPO_NAME" \
  --image-ids imageTag="$IMAGE_TAG" \
  --query "imageDetails[0].imageTags[0]" --output text 2>/dev/null) || true
[ -z "$ECR_CHECK" ] || [ "$ECR_CHECK" = "None" ] && die "Imagen '$REPO_NAME:$IMAGE_TAG' no encontrada en ECR." "Ejecuta la práctica 10 primero."
echo "· Imagen ECR       : $FULL_IMAGE"
echo ""

# =============================================================================
# PASO 1 — Crear el clúster de contenedores
# =============================================================================
echo "=== [1/13] Crear clúster ECS: $CLUSTER_NAME ==="

CLUSTER_ARN=$(aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --query "clusters[0].clusterArn" --output text 2>/dev/null) || true

if [ -z "$CLUSTER_ARN" ] || [ "$CLUSTER_ARN" = "None" ]; then
  aws ecs create-cluster \
    --cluster-name "$CLUSTER_NAME" \
    --tags \
      key=Name,value="$CLUSTER_NAME" \
      key=proyecto,value="$PROYECTO" \
      key=equipo,value="$EQUIPO" \
      key=ambiente,value="$AMBIENTE" \
    > /dev/null
  echo "✔ Clúster creado: $CLUSTER_NAME"
else
  echo "· Clúster ya existe: $CLUSTER_NAME"
fi
echo ""

# =============================================================================
# PASO 2 — Crear NAT Gateway (para que las tareas descarguen la imagen de ECR)
# Las tareas están en subred privada, sin IP pública. Necesitan salir a internet
# para descargar la imagen del registro ECR. El NAT Gateway lo permite.
# =============================================================================
echo "=== [2/13] Crear NAT Gateway para salida a internet desde subred privada ==="

# Verificar si ya existe un NAT Gateway en la VPC
NAT_ID=$(aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=$NAT_NAME" "Name=state,Values=available" \
  --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null) || true

if [ -z "$NAT_ID" ] || [ "$NAT_ID" = "None" ]; then
  # Asignar IP elástica
  EIP_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --query "AllocationId" --output text)
  aws ec2 create-tags --resources "$EIP_ALLOC" --tags \
    Key=Name,Value="$EIP_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO"

  # Crear NAT Gateway en la subred pública
  NAT_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$SUBNET_PUB1_ID" \
    --allocation-id "$EIP_ALLOC" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$NAT_NAME},{Key=proyecto,Value=$PROYECTO},{Key=equipo,Value=$EQUIPO},{Key=ambiente,Value=$AMBIENTE}]" \
    --query "NatGateway.NatGatewayId" --output text)
  echo "✔ NAT Gateway creado: $NAT_ID (IP elástica: $EIP_ALLOC)"
  echo "  Esperando a que esté disponible (1-2 min)..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"
  echo "✔ NAT Gateway disponible."
else
  echo "· NAT Gateway ya existe: $NAT_ID"
fi

# Agregar ruta 0.0.0.0/0 → NAT Gateway en la tabla de ruteo privada
ROUTE_CHECK=$(aws ec2 describe-route-tables \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null) || true

# Verificar si ya existe la ruta al NAT
NAT_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
  --output text 2>/dev/null) || true

if [ -z "$NAT_ROUTE" ] || [ "$NAT_ROUTE" = "None" ]; then
  aws ec2 create-route \
    --route-table-id "$RT_PRIV_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --nat-gateway-id "$NAT_ID" 2>/dev/null || true
  echo "✔ Ruta agregada: 0.0.0.0/0 → $NAT_ID en tabla $RT_PRIV_ID"
else
  echo "· Ruta al NAT ya existe en $RT_PRIV_ID"
fi

# Asociar la segunda subred privada con esta tabla de ruteo
ASSOC2=$(aws ec2 describe-route-tables \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Associations[?SubnetId=='$SUBNET_PRIV2_ID'].RouteTableAssociationId" \
  --output text 2>/dev/null) || true
if [ -z "$ASSOC2" ] || [ "$ASSOC2" = "None" ]; then
  aws ec2 associate-route-table \
    --route-table-id "$RT_PRIV_ID" \
    --subnet-id "$SUBNET_PRIV2_ID" 2>/dev/null || true
  echo "✔ Subred privada 2 asociada a la tabla de ruteo privada."
else
  echo "· Subred privada 2 ya asociada a $RT_PRIV_ID"
fi
echo "  · Las tareas en subred privada ahora pueden descargar de ECR."
echo ""

# =============================================================================
# PASO 3 — Crear grupo de seguridad para las tareas ECS
# Solo recibe tráfico del balanceador en el puerto 3000.
# =============================================================================
echo "=== [3/13] Crear SG para tareas ECS: $SG_ECS_NAME ==="

SG_ECS_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_ECS_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null) || true

if [ -z "$SG_ECS_ID" ] || [ "$SG_ECS_ID" = "None" ]; then
  SG_ECS_ID=$(aws ec2 create-security-group \
    --group-name "$SG_ECS_NAME" \
    --description "Tareas ECS Fargate $PROYECTO - solo del ALB al puerto 3000" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)
  # Inbound: puerto 3000 solo desde el SG del ALB
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ECS_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=$CONTAINER_PORT,ToPort=$CONTAINER_PORT,UserIdGroupPairs=[{GroupId=$SG_ALB_ID,Description=Solo-desde-ALB}]"
  aws ec2 create-tags --resources "$SG_ECS_ID" --tags \
    Key=Name,Value="$SG_ECS_NAME" \
    Key=proyecto,Value="$PROYECTO" \
    Key=equipo,Value="$EQUIPO" \
    Key=ambiente,Value="$AMBIENTE"
  echo "✔ SG ECS creado: $SG_ECS_ID"
  echo "  · Puerto $CONTAINER_PORT: solo desde $SG_ALB_ID (ALB)"
  echo "  · Internet NO puede conectarse directamente a las tareas."
else
  echo "· SG ECS ya existe: $SG_ECS_ID"
fi
echo ""

# =============================================================================
# PASO 4 — Autorizar a las tareas ECS a conectarse a la base de datos
# El SG de RDS solo aceptaba del SG de EC2. Ahora también del SG de ECS.
# =============================================================================
echo "=== [4/13] Autorizar RDS ← tareas ECS (puerto 5432) ==="

# Verificar si la regla ya existe
ECS_RDS_RULE=$(aws ec2 describe-security-groups \
  --group-ids "$SG_RDS_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\`].UserIdGroupPairs[?GroupId=='$SG_ECS_ID']" \
  --output text 2>/dev/null) || true

if [ -z "$ECS_RDS_RULE" ] || [ "$ECS_RDS_RULE" = "None" ]; then
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_RDS_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=5432,ToPort=5432,UserIdGroupPairs=[{GroupId=$SG_ECS_ID,Description=ECS-Fargate}]" 2>/dev/null || true
  echo "✔ Regla agregada: RDS puerto 5432 ← $SG_ECS_ID (tareas ECS)"
else
  echo "· Regla RDS ← ECS ya existe"
fi
echo ""

# =============================================================================
# PASO 5 — Crear rol de ejecución de la tarea
# Este rol lo usa el agente de ECS para descargar la imagen de ECR y enviar logs
# a CloudWatch. Usa la política administrada de AWS.
# =============================================================================
echo "=== [5/13] Crear rol de ejecución de tarea: $EXEC_ROLE_NAME ==="

EXEC_ROLE_ARN=$(aws iam get-role \
  --role-name "$EXEC_ROLE_NAME" \
  --query "Role.Arn" --output text 2>/dev/null) || true

if [ -z "$EXEC_ROLE_ARN" ] || [ "$EXEC_ROLE_ARN" = "None" ]; then
  EXEC_ROLE_ARN=$(aws iam create-role \
    --role-name "$EXEC_ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]
    }' \
    --tags Key=proyecto,Value=$PROYECTO Key=equipo,Value=$EQUIPO \
    --query "Role.Arn" --output text)
  # Política administrada de AWS: permite leer de ECR y escribir a CloudWatch
  aws iam attach-role-policy \
    --role-name "$EXEC_ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  echo "✔ Rol de ejecución creado: $EXEC_ROLE_ARN"
  echo "  · Política: AmazonECSTaskExecutionRolePolicy (ECR + CloudWatch)"
else
  echo "· Rol de ejecución ya existe: $EXEC_ROLE_ARN"
fi
echo ""

# =============================================================================
# PASO 6 — Crear rol de la tarea (permisos acotados de la aplicación)
# La aplicación solo necesita escribir y leer objetos en el bucket S3 del
# proyecto. No necesita acceso a otros servicios ni a otros buckets.
# =============================================================================
echo "=== [6/13] Crear rol de tarea con permisos acotados: $TASK_ROLE_NAME ==="

TASK_ROLE_ARN=$(aws iam get-role \
  --role-name "$TASK_ROLE_NAME" \
  --query "Role.Arn" --output text 2>/dev/null) || true

if [ -z "$TASK_ROLE_ARN" ] || [ "$TASK_ROLE_ARN" = "None" ]; then
  TASK_ROLE_ARN=$(aws iam create-role \
    --role-name "$TASK_ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]
    }' \
    --tags Key=proyecto,Value=$PROYECTO Key=equipo,Value=$EQUIPO \
    --query "Role.Arn" --output text)

  # Política inline con permisos MÍNIMOS: solo el bucket del proyecto
  S3_BUCKET=$(get_env S3_BUCKET "inventario-archivos-losrojos" )
  aws iam put-role-policy \
    --role-name "$TASK_ROLE_NAME" \
    --policy-name "pol-s3-minimo-$EQUIPO" \
    --policy-document "{
      \"Version\":\"2012-10-17\",
      \"Statement\":[
        {
          \"Effect\":\"Allow\",
          \"Action\":[\"s3:PutObject\",\"s3:GetObject\",\"s3:DeleteObject\"],
          \"Resource\":\"arn:aws:s3:::${S3_BUCKET}/*\"
        },
        {
          \"Effect\":\"Allow\",
          \"Action\":[\"s3:ListBucket\"],
          \"Resource\":\"arn:aws:s3:::${S3_BUCKET}\"
        }
      ]
    }"
  echo "✔ Rol de tarea creado: $TASK_ROLE_ARN"
  echo "  · Política: solo s3:PutObject/GetObject/DeleteObject + ListBucket"
  echo "  · Bucket: $S3_BUCKET (ningún otro bucket ni servicio)"
else
  echo "· Rol de tarea ya existe: $TASK_ROLE_ARN"
fi
echo ""

# =============================================================================
# PASO 7 — Leer valores de configuración del .env
# Los valores no sensibles se leen del .env. Los sensibles se leen pero no
# se imprimen. La dirección de la base de datos va aquí, nunca en la imagen.
# =============================================================================
echo "=== [7/13] Leyendo variables de entorno ==="
if [ -n "$ENV_FILE" ]; then
  echo "  Archivo .env encontrado: $ENV_FILE"
else
  echo "  ⚠  No se encontró .env. Se usarán valores por defecto."
  echo "     Copia el .env a la raíz del proyecto en CloudShell."
fi

# Valores no sensibles
ENV_PORT=$(get_env PORT "$CONTAINER_PORT")
ENV_NODE_ENV=$(get_env NODE_ENV "production" )
ENV_DB_HOST="$DB_ENDPOINT"
ENV_DB_PORT=$(get_env DB_PORT "5432" )
ENV_DB_NAME=$(get_env DB_NAME "postgres" )
ENV_DB_USER=$(get_env DB_USER "postgres" )
ENV_DB_SSL=$(get_env DB_SSL "true" )
ENV_AWS_REGION="$REGION"
ENV_S3_BUCKET=$(get_env S3_BUCKET "inventario-archivos-losrojos" )
ENV_JWT_EXPIRES=$(get_env JWT_EXPIRES_IN "8h" )
# CORS: el origen permitido es el DNS del balanceador
ENV_CORS_ORIGIN="http://$ALB_DNS"

# Valores sensibles (no se imprimen)
ENV_DB_PASSWORD=$(get_env DB_PASSWORD "" )
ENV_JWT_SECRET=$(get_env JWT_SECRET "" )

if [ -z "$ENV_DB_PASSWORD" ]; then
  echo -n "  Ingresa la contraseña de la base de datos RDS: "
  read -s ENV_DB_PASSWORD
  echo ""
fi
if [ -z "$ENV_JWT_SECRET" ]; then
  echo -n "  Ingresa el secreto JWT de la aplicación: "
  read -s ENV_JWT_SECRET
  echo ""
fi

echo "✔ Variables cargadas (valores sensibles no se muestran)"
echo "  · DB_HOST   : $ENV_DB_HOST"
echo "  · DB_PORT   : $ENV_DB_PORT"
echo "  · DB_NAME   : $ENV_DB_NAME"
echo "  · DB_USER   : $ENV_DB_USER"
echo "  · DB_SSL    : $ENV_DB_SSL"
echo "  · S3_BUCKET : $ENV_S3_BUCKET"
echo "  · JWT_EXP   : $ENV_JWT_EXPIRES"
echo "  · CORS_ORI  : $ENV_CORS_ORIGIN"
echo "  · DB_PASS   : ******** (no visible)"
echo "  · JWT_SEC   : ******** (no visible)"
echo ""

# =============================================================================
# PASO 8 — Definir la tarea (task definition)
# Indica la imagen del registro, la memoria, el procesador y el puerto.
# =============================================================================
echo "=== [8/13] Crear definición de tarea: $TASK_FAMILY ==="

# Construir el JSON de la task definition en un archivo temporal
# Las variables sensibles (DB_PASSWORD, JWT_SECRET) van como environment
# (no secrets) para no requerir Secrets Manager en esta práctica de aula.
# En producción se usarían secrets con ARN de SSM Parameter Store.
TMP_TD=$(mktemp)
cat > "$TMP_TD" << TDJSON
{
  "family": "$TASK_FAMILY",
  "executionRoleArn": "$EXEC_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "$TASK_CPU",
  "memory": "$TASK_MEMORY",
  "tags": [
    {"key":"proyecto","value":"$PROYECTO"},
    {"key":"equipo","value":"$EQUIPO"},
    {"key":"ambiente","value":"$AMBIENTE"}
  ],
  "containerDefinitions": [
    {
      "name": "$CONTAINER_NAME",
      "image": "$FULL_IMAGE",
      "cpu": $TASK_CPU,
      "memory": $TASK_MEMORY,
      "memoryReservation": $TASK_MEMORY,
      "essential": true,
      "portMappings": [
        {"containerPort": $CONTAINER_PORT, "hostPort": $CONTAINER_PORT, "protocol": "tcp"}
      ],
      "environment": [
        {"name":"PORT","value":"$ENV_PORT"},
        {"name":"NODE_ENV","value":"$ENV_NODE_ENV"},
        {"name":"CORS_ORIGIN","value":"$ENV_CORS_ORIGIN"},
        {"name":"AWS_REGION","value":"$ENV_AWS_REGION"},
        {"name":"DB_HOST","value":"$ENV_DB_HOST"},
        {"name":"DB_PORT","value":"$ENV_DB_PORT"},
        {"name":"DB_NAME","value":"$ENV_DB_NAME"},
        {"name":"DB_USER","value":"$ENV_DB_USER"},
        {"name":"DB_SSL","value":"$ENV_DB_SSL"},
        {"name":"S3_BUCKET","value":"$ENV_S3_BUCKET"},
        {"name":"JWT_EXPIRES_IN","value":"$ENV_JWT_EXPIRES"},
        {"name":"DB_PASSWORD","value":"$ENV_DB_PASSWORD"},
        {"name":"JWT_SECRET","value":"$ENV_JWT_SECRET"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/$CLUSTER_NAME",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "fargate"
        }
      }
    }
  ]
}
TDJSON

# Crear el log group si no existe
aws logs create-log-group --log-group-name "/ecs/$CLUSTER_NAME" 2>/dev/null || true

# Registrar la task definition
aws ecs register-task-definition \
  --cli-input-json "file://$TMP_TD" \
  --query "taskDefinition.taskDefinitionArn" --output text > /dev/null
rm -f "$TMP_TD"

TASK_DEF_ARN=$(aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --query "taskDefinition.taskDefinitionArn" --output text)

# Obtener la revisión actual
TASK_REVISION=$(aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --query "taskDefinition.revision" --output text)

echo "✔ Definición de tarea registrada: $TASK_FAMILY (revisión $TASK_REVISION)"
echo "  · Imagen    : $FULL_IMAGE"
echo "  · CPU       : $TASK_CPU (0.25 vCPU) — anotar para la práctica 17"
echo "  · Memoria   : $TASK_MEMORY MB — anotar para la práctica 17"
echo "  · Puerto    : $CONTAINER_PORT"
echo "  · Red       : awsvpc (Fargate)"
echo ""

# =============================================================================
# PASO 9 — Crear grupo destino tipo ip para el balanceador
# El target group de la práctica 8 era tipo instance (para EC2/ASG).
# Fargate usa direcciones IP, por eso se crea uno nuevo tipo ip.
# =============================================================================
echo "=== [9/13] Crear target group tipo ip: $TG_ECS_NAME ==="

TG_ECS_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_ECS_NAME" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null) || true

if [ -z "$TG_ECS_ARN" ] || [ "$TG_ECS_ARN" = "None" ]; then
  TG_ECS_ARN=$(aws elbv2 create-target-group \
    --name "$TG_ECS_NAME" \
    --protocol HTTP \
    --port $CONTAINER_PORT \
    --vpc-id "$VPC_ID" \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-port "traffic-port" \
    --health-check-path "/health" \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --tags \
      Key=Name,Value="$TG_ECS_NAME" \
      Key=proyecto,Value="$PROYECTO" \
      Key=equipo,Value="$EQUIPO" \
    --query "TargetGroups[0].TargetGroupArn" --output text)
  echo "✔ Target group creado: $TG_ECS_ARN"
  echo "  · Tipo            : ip (para Fargate)"
  echo "  · Puerto          : $CONTAINER_PORT"
  echo "  · Health check    : GET /health cada 15 s"
  echo "  · Umbral sano     : 2 checks OK"
  echo "  · Umbral insano   : 2 checks KO"
else
  echo "· Target group ya existe: $TG_ECS_ARN"
fi
echo ""

# =============================================================================
# PASO 10 — Conectar el servicio al balanceador
# Modificar el listener del ALB para que reenvíe al nuevo target group de ECS.
# =============================================================================
echo "=== [10/13] Conectar ALB → target group de ECS ==="

LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null) || true

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
  LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TG_ECS_ARN" \
    --query "Listeners[0].ListenerArn" --output text)
  echo "✔ Listener HTTP:80 creado: $LISTENER_ARN"
else
  # Modificar la acción por defecto del listener existente
  aws elbv2 modify-listener \
    --listener-arn "$LISTENER_ARN" \
    --default-actions "Type=forward,TargetGroupArn=$TG_ECS_ARN" > /dev/null
  echo "✔ Listener modificado: ahora reenvía a $TG_ECS_NAME"
fi
echo "  · El balanceador ahora apunta a las tareas ECS."
echo ""

# =============================================================================
# PASO 11 — Detener el ASG de la práctica 8 (ahorrar y liberar el target group)
# =============================================================================
echo "=== [11/13] Detener instancias EC2 del ASG (práctica 8) ==="

ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null) || true

if [ -n "$ASG_EXISTS" ] && [ "$ASG_EXISTS" != "None" ]; then
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --min-size 0 \
    --desired-capacity 0 2>/dev/null || true
  echo "✔ ASG '$ASG_NAME' reducido a 0 instancias (ahorra costo)"
else
  echo "· ASG '$ASG_NAME' no encontrado (puede que ya esté detenido)"
fi
echo ""

# =============================================================================
# PASO 12 — Crear el servicio ECS Fargate en subredes privadas
# Sin IP pública. El acceso desde internet es exclusivamente por el balanceador.
# =============================================================================
echo "=== [12/13] Crear servicio ECS Fargate: $SERVICE_NAME ==="

# Construir configuración de red en JSON
TMP_NET=$(mktemp)
cat > "$TMP_NET" << NETJSON
{
  "awsvpcConfiguration": {
    "subnets": ["$SUBNET_PRIV1_ID", "$SUBNET_PRIV2_ID"],
    "securityGroups": ["$SG_ECS_ID"],
    "assignPublicIp": "DISABLED"
  }
}
NETJSON

# Construir configuración del balanceador en JSON
TMP_LB=$(mktemp)
cat > "$TMP_LB" << LBJSON
[
  {
    "targetGroupArn": "$TG_ECS_ARN",
    "containerName": "$CONTAINER_NAME",
    "containerPort": $CONTAINER_PORT
  }
]
LBJSON

SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].status" --output text 2>/dev/null) || true

if [ -z "$SERVICE_EXISTS" ] || [ "$SERVICE_EXISTS" = "None" ] || [ "$SERVICE_EXISTS" = "INACTIVE" ]; then
  aws ecs create-service \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --task-definition "$TASK_FAMILY" \
    --desired-count $DESIRED_COUNT \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "file://$TMP_NET" \
    --load-balancers "file://$TMP_LB" \
    --health-check-grace-period 60 \
    --scheduling-strategy REPLICA \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --tags \
      key=Name,value="$SERVICE_NAME" \
      key=proyecto,value="$PROYECTO" \
      key=equipo,value="$EQUIPO" \
      key=ambiente,value="$AMBIENTE" \
    > /dev/null
  echo "✔ Servicio creado: $SERVICE_NAME"
  echo "  · Clúster        : $CLUSTER_NAME"
  echo "  · Tareas deseadas: $DESIRED_COUNT"
  echo "  · Lanzamiento    : FARGATE (sin servidores)"
  echo "  · Subredes       : PRIVADAS ($SUBNET_PRIV1_ID, $SUBNET_PRIV2_ID)"
  echo "  · IP pública    : DISABLED (sin dirección pública)"
  echo "  · SG             : $SG_ECS_ID (solo recibe del ALB)"
  echo "  · Balanceador    : $ALB_NAME → $TG_ECS_NAME"
  echo "  · Grace period   : 60 s"
else
  echo "· Servicio ya existe: $SERVICE_NAME (estado: $SERVICE_EXISTS)"
fi
rm -f "$TMP_NET" "$TMP_LB"
echo ""

# =============================================================================
# PASO 13 — Esperar a que las tareas estén sanas
# =============================================================================
echo "=== [13/13] Esperando a que las tareas arranquen y pasen health check ==="
echo "  (Esto toma 1-3 minutos: descargar imagen + iniciar Node + 2 health checks OK)"
echo ""

# Esperar a que el servicio esté estable
sleep 10
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].runningCount" --output text)

echo "  Tareas en ejecución: $RUNNING_COUNT / $DESIRED_COUNT"

# Esperar a que las tareas estén RUNNING
RETRY=0
MAX_RETRIES=30
while [ "$RUNNING_COUNT" -lt "$DESIRED_COUNT" ] && [ "$RETRY" -lt "$MAX_RETRIES" ]; do
  sleep 10
  RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query "services[0].runningCount" --output text 2>/dev/null) || true
  RETRY=$((RETRY + 1))
  echo "  Esperando... ($RETRY/$MAX_RETRIES) tareas: $RUNNING_COUNT / $DESIRED_COUNT"
done

# Verificar health check del target group
echo ""
echo "  Estado de health checks en el target group:"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ECS_ARN" \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Puerto:Target.Port,Estado:TargetHealth.State}" \
  --output table 2>/dev/null || echo "  (esperando targets...)"

# Probar el endpoint del balanceador
echo ""
echo "  Probando el endpoint del balanceador..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" 2>/dev/null || echo "FALLO")
if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✔ La aplicación responde: HTTP $HTTP_STATUS"
  curl -s "http://$ALB_DNS/health"
else
  echo "  ⚠ Aún no responde (HTTP $HTTP_STATUS). Espera 30 s más y reintenta:"
  echo "    curl http://$ALB_DNS/health"
  echo "  Si no arranca, revisa los logs:"
  echo "    aws logs get-log-events --log-group-name /ecs/$CLUSTER_NAME"
  echo "      --log-stream-name \$(aws logs describe-log-streams"
  echo "      --log-group-name /ecs/$CLUSTER_NAME --query logStreams[0].logStreamName --output text)"
fi

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  RESUMEN — PRÁCTICA 11"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  CLÚSTER"
echo "    Nombre            : $CLUSTER_NAME"
echo ""
echo "  DEFINICIÓN DE TAREA"
echo "    Familia           : $TASK_FAMILY (revisión $TASK_REVISION)"
echo "    Imagen            : $FULL_IMAGE"
echo "    CPU               : $TASK_CPU (0.25 vCPU) ← anotar para P17"
echo "    Memoria           : $TASK_MEMORY MB ← anotar para P17"
echo "    Puerto            : $CONTAINER_PORT"
echo "    Rol ejecución     : $EXEC_ROLE_NAME (ECR + CloudWatch)"
echo "    Rol tarea         : $TASK_ROLE_NAME (solo S3 del bucket)"
echo "    Variables entorno : 13 (ver evidencia-p11-c2-variables.sh)"
echo ""
echo "  SERVICIO"
echo "    Nombre            : $SERVICE_NAME"
echo "    Tareas deseadas   : $DESIRED_COUNT"
echo "    Lanzamiento       : FARGATE (sin servidores)"
echo "    Subredes          : PRIVADAS (sin IP pública)"
echo "    SG tareas          : $SG_ECS_ID (solo recibe del ALB)"
echo ""
echo "  BALANCEADOR"
echo "    ALB               : $ALB_NAME"
echo "    DNS               : http://$ALB_DNS"
echo "    Target group      : $TG_ECS_NAME (tipo ip)"
echo "    Health check      : GET /health cada 15 s"
echo ""
echo "  NAT GATEWAY"
echo "    ID                : $NAT_ID"
echo "    ⚠  Cuesta por hora. Ejecuta parar-p11.sh al terminar."
echo ""
echo "  SIGUIENTES PASOS:"
echo "    1. Probar el endpoint:"
echo "       curl http://$ALB_DNS/health"
echo ""
echo "    2. Generar evidencias:"
echo "       bash practica11/evidencia-p11-c1-tarea.sh"
echo "       bash practica11/evidencia-p11-c2-variables.sh"
echo "       bash practica11/evidencia-p11-c3-balanceador.sh"
echo "       bash practica11/evidencia-p11-c4-reposicion.sh"
echo "       bash practica11/evidencia-p11-c5-cero-tareas.sh"
echo ""
echo "    3. Al terminar (OBLIGATORIO para no acumular consumo):"
echo "       bash practica11/parar-p11.sh"
echo "════════════════════════════════════════════════════════════════════"
